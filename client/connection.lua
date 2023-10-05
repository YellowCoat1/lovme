local connection = {}
local eventQueue = {}

-- libraries
local sock = require 'sock'
local zen = require 'luazen'
local luatz = require 'luatz'
local crypto = require 'crypto'

local getTime = luatz.time

-- connection to server
local SERVER_PORT = 22123
local sock_client = sock.newClient("localhost", SERVER_PORT)
sock_client:connect()

-- general conversation cryptography
local client_secret_key, client_public_key = crypto.gen_keys()
connection.public_keys = {}
connection.connectionEstablished = false

-- pre-set argon arguments
local ARGON_KB = 5000
local ARGON_I = 15

-- connection state
connection.loggedIn = false
local login_username
local session_id = nil
local shared_key = nil
local last_server_active = getTime()

-- user message cryptography
local database_shared_keys = {}
local database_salt = zen.b64decode("AAAAAAAAAAAAAAAAAAAAAA==")
local database_secret = nil
local database_public = nil


local function messageFromServer(data)
    if not shared_key then return false end
    last_server_active = getTime()
    if data then 
        local status, result = pcall(function()
            local status, data = crypto.decrypt(data, shared_key)
            if not status or not data then error() end
            return data
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
    local status
    status, sendTable.data = crypto.encrypt(sendData, shared_key)
    if not status then return false end
    
    sock_client:send(message, sendTable)
    return true
end

function connection:login(username, password)
    
    if username == "user1" then database_salt = zen.b64decode("AAAAAAAAAAAAAAAAAAAAAA==")
    elseif username == "user2" then database_salt = zen.b64decode("BBBBBBBBBBBBBBBBBBBBBA==") end
    database_secret = zen.argon2i(password, database_salt, ARGON_KB, ARGON_I)
    database_public = zen.x25519_public_key(database_secret)

    sendTable = {}
    sendTable.user = username
    sendTable.pass = password
    local status = sendToServer("login", sendTable)
    print(status)
    if not status then return false, "server send failed" end

    login_username = username
    return true
end

function connection.registerUser(username, password)
    local sendTable = {}
    if username == "user1" then database_salt = zen.b64decode("AAAAAAAAAAAAAAAAAAAAAA==")
    elseif username == "user2" then database_salt = zen.b64decode("BBBBBBBBBBBBBBBBBBBBBA==") end
    sendTable.username = username
    sendTable.password = password
    sendTable.databaseSalt = database_salt
    sendToServer("register", sendTable)
end

function connection:logout()
    database_secret = nil
    database_public = nil
    loginUsername = nil
    loggedIn = false
    database_shared_keys = {}
end

function connection.request_database_public_key(username)
    if not connection.connectionEstablished then return false, "connection not established" end
    if not connection.loggedIn then return false, "not loggedIn" end
    local sendTable = {}
    sendTable.requestedUsername = username
    local status = sendToServer("database_public_key_req", sendTable)
    if not status then return false, "server send failed" end
    return true
end

function connection.request_message(reciever)
    if not connection.connectionEstablished then return false, "connection not established" end
    if not connection.loggedIn then return false, "not loggedIn" end
    if not login_username then return false, "no username" end
    if not reciever then return false, "invalid arguments" end
    local sendTable = {}
    sendTable.messageType = "last_both"
    sendTable.sender = login_username
    sendTable.reciever = reciever
    sendToServer("message_req", sendTable)
    return true
end

function connection.request_message_next(reciever, messageID)
    if not connection.connectionEstablished then return false, "connection not established" end
    if not connection.loggedIn then return false, "not loggedIn" end
    if not login_username then return false, "no username" end
    if not reciever then return false, "invalid arguments" end
    local sendTable = {}
    sendTable.messageType = "next_id"
    sendTable.sender = login_username
    sendTable.reciever = reciever
    sendTable.messageID = messageID
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

local function keyResponse(key, username) end
function connection.setKeyResponse(keyResponseFunction)
    if type(keyResponseFunction) ~= "function" then return false end
    keyResponse = keyResponseFunction
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
    connection.loggedIn = true
    status, data = messageFromServer(data)
    login_username = data.username
    database_salt = data.salt 
    loginResponse()
end)

sock_client:on("db_key_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, shared_key)
    if not status or not data then return end
    if not data.returnKey or not data.replyUsername then return end

    local reciever_database_public_key = data.returnKey

    
    local database_shared_key = zen.key_exchange(database_secret, reciever_database_public_key)

    database_shared_keys[data.replyUsername] = database_shared_key

    keyResponse(database_shared_key, data.replyUsername)

    return true
end)

sock_client:on("message_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, shared_key)
    if not status or not data then print(data) return end

    
    local databaseSharedKey = database_shared_keys[data.other]
    if not databaseSharedKey then print("WARN: ".."no_shared_key") return end
    local serializedMessage = zen.decrypt(databaseSharedKey, data.message.nonce, data.message.data)
    
    print(databaseSharedKey, data.message.nonce, data.message.data, type(serializedMessage))
    local status, message = pcall(bitser.loads, serializedMessage)
    if not status then return print("ERROR: invalid_message_key") end
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



function connection:update()

    sock_client:update()

    local time = getTime()
    local roundTripTime = 0.03 --sock_client:getRoundTripTime() / 1000
    local timeout = roundTripTime + 5
    if last_server_active + timeout < time then
        sendToServer("ping", {})
    elseif last_server_active + 10 < time then
        softDisconnect()
    elseif last_server_active + 20 < time then
        self.connectionEstablished = false
        hardDisconnect()
    end
end

return connection