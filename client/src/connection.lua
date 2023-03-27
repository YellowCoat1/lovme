local connection = {}
local eventQueue = {}

-- libraries
local sock = require 'sock'
local zen = require 'luazen'
local crypto = require 'crypto'
local cached = require 'cached'

local getTime = love.timer.getTime

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
local session_id
local shared_key
local last_server_active = getTime()

-- user message cryptography
local database_shared_keys = {}
local database_salt
local database_secret

local temp_username_store = ""
local temp_password_store = ""


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
    if not username or not password then return false end
    temp_username_store, temp_password_store = "", ""

    local database_salt = cached.getValue("database_salt")
    if not database_salt then 
        temp_username_store, temp_password_store = username, password
        local salt_status = self.request_database_salt(username)
        if salt_status then
            return true, "salt_req"
        else
            return false, "server send failed"
        end
    end
    
    database_secret = zen.argon2i(password, database_salt, ARGON_KB, ARGON_I)
    database_public = zen.x25519_public_key(database_secret)

    sendTable = {}
    sendTable.user = username
    sendTable.pass = password
    local status = sendToServer("login", sendTable)
    if not status then return false, "server send failed" end

    login_username = username
    return true
end

function connection.registerUser(username, password)

    if not username or not password or
        type(username) ~= "string" or
        type(password) ~= "string" then
            return false, "input invalid"
    end
 
    -- generate salt and create keys based off the salt and password
    local databaseSalt = zen.randombytes(32)
    local databasePrivateKey = zen.argon2i(password, databaseSalt, ARGON_KB, ARGON_I)
    local databasePublicKey = zen.x25519_public_key(databasePrivateKey)

    local sendTable = {}
    sendTable.user = username
    sendTable.pass = password
    sendTable.dbSalt = databaseSalt
    sendTable.dbPubKey = databasePublicKey

    local status = sendToServer("register", sendTable)
    if not status then return false, "server send failed" end
    return true
end

function connection:logout()
    database_secret = nil
    database_public = nil
    loginUsername = nil
    loggedIn = false
    database_shared_keys = {}
end

-- purely for testing purposes, logs you in immediately
function connection:forceLogin()
    loggedIn = true
    loginUsername = "testUser"
    connection.loginResponse()
end

function connection:setAddress(address)
    sock_client = sock.newClient(address, SERVER_PORT)
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

function connection.request_database_salt(username)
    if not connection.connectionEstablished then return false, "connection not established" end
    local sendTable = {}
    sendTable.user = username
    local status = sendToServer("database_salt_req", sendTable)
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

function connection.request_contact_list()
    if not loggedIn then return false, "not_logged_in" end
    local sendTable = {}
    sendToServer("request_contact_list", sendTable)
end

function connection.contactAdd(contactName)
    if not loggedIn then return false, "not_logged_in" end
    local sendTable = {}
    sendTable.contact = contactName
    sendToServer("request_add_contact", sendTable)
end

function connection.registerResponse() end
function connection:setRegisterResponse(registerResponseFunction)
    if type(registerResponseFunction) ~= "function" then return false end
    self.registerResponse = registerResponseFunction
    return true
end
function connection.registerFailResponse() end
function connection:setRegisterFailResponse(registerFailResponseFunction)
    if type(registerFailResponseFunction) ~= "function" then return false end
    self.registerFailResponse = registerFailResponseFunction
    return true
end

function connection.loginResponse() end
function connection:setLoginResponse(loginResponseFunction)
    if type(loginResponseFunction) ~= "function" then return false end
    self.loginResponse = loginResponseFunction
    return true
end
function connection:setLoginFailResponse(loginFailResponse)
    if type(loginFailResponse) ~= "function" then return false end
    self.loginFailResponse = loginFailResponse
    return true
end



function connection.messageResponse(data) end
function connection:setMessageResponse(messageResponseFunction)
    if type(messageResponseFunction) ~= "function" then return false end
    self.messageResponse = messageResponseFunction
    return true
end

local function keyResponse(key, username) end
function connection.setKeyResponse(keyResponseFunction)
    if type(keyResponseFunction) ~= "function" then return false end
    keyResponse = keyResponseFunction
    return true
end

local function contactListResponse() end
local function contactListFailResponse() end
function connection.setContactListResponse(setResponseFunction, setFailFunction)
    if type(setResponseFunction) ~= "function" then 
        return false 
    end
    contactListResponse = setResponseFunction
    if setFailFunction then
        contactListFailResponse = setFailFunction
    end
    return true
end

local function contactAddResponse() end
function connection.setContactAddResponse(contactResponseFunction)
    if type(contactResponseFunction) ~= "function" then return false end
    contactAddResponse = contactResponseFunction
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

sock_client:on("reg-success", function(data)
    status, data = messageFromServer(data)
    if not data then
        connection.registerFailResponse()
        return
    -- elseif #data == 0 then
    --     connection.registerFailResponse()
    end
    connection.registerResponse(data.username)
end)
sock_client:on("reg-fail", function(data)
    local status, data = messageFromServer(data)
    local errorCode
    if status then
        errorCode = data.errorCode
    end
    connection.registerFailResponse(errorCode)
end)

sock_client:on("login-success", function(data)
    status, data = messageFromServer(data)
    if not status then
        connection.loginFailResonse()
        return
    end
    connection.loggedIn = true
    login_username = data.username
    database_salt = data.salt 
    connection.loginResponse()
end)

sock_client:on("login-fail", function()
    messageFromServer()
    temp_username_store, temp_password_store = "", ""
    connection.loginFailResponse()
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

sock_client:on("db_salt", function(data) 
    local status, data = messageFromServer(data)
    if not status or not data then return end
    local salt = data.salt
    lstatus = cached.setValue("database_salt", salt)
    connection:login(temp_username_store, temp_password_store)


end)

sock_client:on("message_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, shared_key)
    if not status or not data then --[[print(data)--]] return end

    
    local databaseSharedKey = database_shared_keys[data.other]
    if not databaseSharedKey then print("WARN: ".."no_shared_key") return end
    local serializedMessage = zen.decrypt(databaseSharedKey, data.message.nonce, data.message.data)
    
    print(databaseSharedKey, data.message.nonce, data.message.data, type(serializedMessage))
    local status, message = pcall(bitser.loads, serializedMessage)
    if not status then return print("ERROR: invalid_message_key") end
    connection.messageResponse(message)
end)

sock_client:on("contact_list_reply", function(data) 
    local status, contact_list = messageFromServer(data)
    if status and contact_list then 
        contactListResponse(contact_list)
    else
        contactListFailResponse()
        return 
    end
end)

sock_client:on("contact_add_reply", function(data)
    local status, contactResponse = messageFromServer(data)
    if status and contactResponse then
        contactAddResponse()
    end
end)

sock_client:on("ping", function()
    messageFromServer()
    local session_id = sock_client.test_id
    sendToServer("pong", {})
end)

sock_client:on("pong", function ()
    messageFromServer()
end)

sock_client:on("disconnect", function()
    sendToServer("ping", {})
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
        sendToServer("ping", {})
    end
end

return connection