local connection = {}

local eventQueue = {}

local sock = require 'sock'
local zen = require 'luazen'

local crypto = require 'crypto'

local SERVER_PORT = 22123

local sock_client = sock.newClient("localhost", SERVER_PORT)
sock_client:connect()

local client_secret_key, client_public_key = crypto.gen_keys()
connection.public_keys = {}

connection.connectionEstablished = false

local loggedIn
local login_username

local ARGON_KB = 5000
local ARGON_I = 15

local session_id = nil
local shared_key = nil
local database_shared_keys = {}
local database_salt = zen.b64decode("AAAAAAAAAAAAAAAAAAAAAA==")

local database_secret = nil
local database_public = nil

local last_server_active = love.timer.getTime()

local function messageFromServer(data)
    if not shared_key then return false end
    last_server_active = love.timer.getTime()
    if data then 
        local status, result = pcall(function()
            local status, data = crypto.decrypt(data, shared_key)
            if not status or not data then return false end
            return true, data
        end)
        if not status then return false end
        return true, result
    end
    return true
end

local function sendToServer(message, sendData)
    messageFromServer()
    if not sock_client then return false, "sock_client not found" end
    if not shared_key then return false, "shared key not found" end
    if not session_id then return false, "SID not found" end

    local sendTable = {}
    sendTable.SID = session_id
    sendTable.data = {}
    local status
    status, sendTable.data = crypto.encrypt(sendData, shared_key)
    if not status then return false end
    sock_client:send(message, sendTable)
    return true
end

function connection:login(username, password)
    if not connection.connectionEstablished then return false, "connection not established" end
    local sendTable = {}
    sendTable.user = username
    sendTable.pass = password

    database_secret = zen.argon2i(password, database_salt, ARGON_KB, ARGON_I)
    database_public = zen.x25519_public_key(database_secret)
    

    local status = sendToServer("login", sendTable)
    if not status then return false, "server send failed" end

    login_username = username
    loggedIn = true
    return true
end

function connection.registerUser(username, password)
    local sendTable = {}
    sendTable.username = username
    sendTable.password = password
    sendTable.databaseSalt = database_salt
    sendToServer("register", sendTable)
end

-- function connection:logout()
--     database_secret = nil
--     database_public = nil
-- end

function connection.request_database_public_key(username)
    if not connection.connectionEstablished then return false, "connection not established" end
    if not loggedIn then return false, "not logged in" end
    local sendTable = {}
    sendTable.requestedUsername = username
    local status = sendToServer("database_public_key_req", sendTable)
    if not status then return false, "server send failed" end
    return true
end

function connection.request_message(reciever)
    if not connection.connectionEstablished then return false, "connection not established" end
    if not login_username then return false, "no username" end
    if not reciever then return false, "invalid arguments" end
    local sendTable = {}
    sendTable.messageType = "last_both"
    sendTable.sender = login_username
    sendTable.reciever = reciever
    sendToServer("message_req", sendTable)
    return true
end

function connection.sendStringMessage(recipiant, message)
    if not loggedIn then return false, "not_logged_in" end
    local database_shared_key = database_shared_keys[recipiant]
    if not database_shared_key then return false, "database key not found" end
    local sendTable = {}
    sendTable.reciever =  recipiant
    sendTable.nonce = zen.randombytes(24)
    sendTable.message = {}
    sendTable.message.type = "text"
    sendTable.message.data = message
    sendTable.message = bitser.dumps(sendTable.message)
    sendTable.message = zen.encrypt(database_shared_key, sendTable.nonce, sendTable.message)
    local status = sendToServer("message_send", sendTable)
    if not status then return false, "server send failed" end
end


local function loginResponse() end
function connection.setLoginResponse(loginResponseFunction)
    if type(loginResponseFunction) ~= "function" then return false end
    loginResponse = loginResponseFunction
    return true
end
local function messageResponse(data) end
function connection.setMessageResponse(messageResponseFunction)
    if type(messageResponseFunction) ~= "function" then return false end
    messageResponse = messageResponseFunction
    return true
end

local function softDisconnect() end
function connection.setSoftDisconnect(softDisconnectFunction)
    if type(softDisconnectFunction) ~= "function" then return false end
    softDisconnect = softDisconnectFunction
    return true
end
local function hardDisconnect() end
function connection.hardDisconnect(hardDisconnectFunction)
    if type(hardDisconnectFunction) ~= "function" then return false end
    hardDisconnect = hardDisconnectFunction
    return true
end


sock_client:on("connect", function()
    messageFromServer()
    local sendTable = {}
    sendTable.upk = client_public_key
    sock_client:send("connected", sendTable)
end)

sock_client:on("key_response", function(data)
    messageFromServer()
    session_id = data.sessionID
    shared_key = zen.key_exchange(client_secret_key, data.spk)
    connection.connectionEstablished = true
end)

sock_client:on("login-success", function(data)
    data = messageFromServer(data)
    loginResponse()
end)

sock_client:on("key_req_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, shared_key)
    if not status or not data then return end
    if not data.returnKey or not data.replyUsername then return end

    local database_public_key = data.returnKey
    local database_shared_key = zen.key_exchange(database_secret, database_public_key)
    database_shared_keys[data.replyUsername] = database_shared_key

    return true
end)

sock_client:on("message_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, shared_key)
    if not status or not data then print(data) return end

    local databaseSharedKey = database_shared_keys[data.other]
    local serializedMessage = zen.decrypt(databaseSharedKey, data.message.nonce, data.message.data)
    print(databaseSharedKey)
    local status, message = pcall(bitser.loads, serializedMessage)
    if not status then return print("o no") end
    messageResponse(message)
end)

sock_client:on("ping", function()
    messageFromServer()
    local session_id = sock_client.test_id
    sendToServer("pong", {})
end)

sock_client:on("pong", function ()
    messageFromServer()
end)


-- for debugging
sock_client:on("usr_error", function(data)
    messageFromServer()
    local status, result = crypto.decrypt(data, shared_key)
    if not status or not result then return end
    print("usr_error: ".. result[1])
end)


sock_client:on("usr_error_de", function(data)
    messageFromServer()
    print("usr_error_de: " .. data)
end)



function connection.update()

    sock_client:update()

    local time = love.timer.getTime()
    local roundTripTime = 0.03 --sock_client:getRoundTripTime() / 1000
    local timeout = roundTripTime + 1
    if last_server_active + timeout < time then
        sendToServer("ping", {})
    elseif last_server_active + 10 < time then
        softDisconnect()
    elseif last_server_active + 20 < time then
        hardDisconnect()
    end
end

return connection