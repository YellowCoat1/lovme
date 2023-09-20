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
local database_secret = nil
local database_public = nil

local last_server_active = love.timer.getTime()

local function messageFromServer(data)
    if not shared_key then return false end
    last_server_active = love.timer.getTime()
    if data then
        local status, data = crypto.decrypt(data, shared_key)
        if not status or not data then return false end
        return true, data
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
    
    local bytes16Salt = zen.randombytes(16)
    database_secret = zen.argon2i(sendTable.pass, bytes16Salt, ARGON_KB, ARGON_I)
    database_public = zen.x25519_public_key(database_secret)

    sendTable.database_key_salt = bytes16Salt
    
    local status = sendToServer("login", sendTable)
    if not status then return false, "server send failed" end

    return true
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

function connection.request_message()
    local sendTable = {}
    sendTable.messageType = "last_both"
    sendTable.sender = "user1"
    sendTable.reciever = "user2"
    sendToServer("message_req", sendTable)
end

function connection.sendStringMessage(recipiant)
    if not loggedIn then return false, "not_logged_in" end
    local database_shared_key = database_shared_keys[recipiant]
    if not database_shared_key then return false, "key not found" end
    local sendTable = {}
    sendTable.reciever =  recipiant
    sendTable.nonce = zen.randombytes(24)
    sendTable.message = {}
    sendTable.message.type = "text"
    sendTable.message.data = "hello there!"
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

sock_client:on("login-success", function()
    messageFromServer()
    loginResponse()
end)

sock_client:on("key_req_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, shared_key)
    if not status or not data then return false, "decryption failed" end

    local database_public_key = data.returnKey
    local database_shared_key = zen.key_exchange(sock_client.database_secret, database_public_key)
    connection.shared_keys[data.replyUsername] = database_shared_key

    return true
end)

sock_client:on("message_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, shared_key)
    if not status or not data then print(data) return end
    connection.message_response(data)
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

    local roundTripTime = 0.03 --sock_client:getRoundTripTime() / 1000
    local timeout = roundTripTime + 1
    if last_server_active + timeout < love.timer.getTime() then
        sendToServer("ping", {})
    end
end

return connection