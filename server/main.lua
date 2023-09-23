---@diagnostic disable: duplicate-set-field
-- configure library paths
local libPath = "libs"
package.cpath = package.cpath .. ';./' .. libPath .. '/?.so'
package.path = package.path .. ';./' .. libPath .. '/?.lua'

Object = require 'classic' -- oo
local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

-- server modules
local crypto = require 'crypto'
local database = require 'database'

-- class user
local user = require 'user'

UpdateFunctions = {}

local SERVER_PORT = 22123

ActiveUsers = {}

LovmeServer = sock.newServer("localhost", SERVER_PORT)
local test_client


-- generate a new random session id
local function request_session_id()
    local new_session_id = zen.randombytes(8)
    for _, activeUser in ipairs(ActiveUsers) do
        if activeUser.sessionID == new_session_id then
            return request_session_id()
        end
    end
    return new_session_id
end

-- processes a message from the user, decrypting and returning data (plus the session id)
local function user_message(data, client)
    local sessionID = data.SID
    if not data.SID or not data.data then
        client:send("usr_error_de", "malformed_req")
        return false, "malformed_req"
    end
    if ActiveUsers[sessionID] == nil then
        client:send("usr_error_de", "unconnected")
        return false, "client not found"
    end
    local key = ActiveUsers[sessionID].sharedKey
    ActiveUsers[sessionID]:updateActive()
    local status, decryptedData = crypto.decrypt(data.data, key)
    if status == true then return true, decryptedData, sessionID
    else client:send("usr_error_de", "malformed_req") end
end

local function userSendError(client, activeUser, message)
    if not client or not activeUser or type(message) ~= "string" then return false end
    local status, result = crypto.encrypt({message}, activeUser.sharedKey)
    if status then client:send("usr_error", result)
    else client:send("usr_error_de", message) end
    return true
end

local function emptyPing(data, client)
    user_message(data, client)
    client:send("pong")
end

-- user connect, handles filing user key and user object creation
local function userConnect(data, client)
    local ServerSecKey = zen.randombytes(32)
    local ServerPubKey = zen.x25519_public_key(ServerSecKey)
    local shared = crypto.shared_key(ServerSecKey, data.upk)
    local sessionID = request_session_id()
    ActiveUsers[sessionID] = user(sessionID, shared, client)
    local sendTable = {}
    sendTable.spk = ServerPubKey
    sendTable.sessionID = sessionID
    client:send("key_response", sendTable)
end

-- user attempting to login with a username and password
local function userLogin(data, client)
    local sessionID, status, result
    status, data, sessionID = user_message(data, client)
    if not status or not data then
        return false
    end
    local activeUser = ActiveUsers[sessionID]

    status, result = database:checkPassEquality(data.user, data.pass)
    if status and result then
        activeUser.loggedInUsername = data.user
    else
        userSendError(client, activeUser, "rejected_pass")
        return false
    end

    client:send("login-success")

    return true
end

local function message_send(data, client)
    local sessionID, status, result
    status, data, sessionID = user_message(data, client)
    if not status or not data then return false end
    local activeUser = ActiveUsers[sessionID]
    local username = activeUser.loggedInUsername

    if username == nil then
        userSendError(client, activeUser, "not_logged_in")
        return
    elseif not database.doesUserExist(username) then
        userSendError(client, activeUser, "credentials_invalid")
        return
    end

    if data.reciever == username then
        userSendError(client, activeUser, "send_to_self")
    end

    local status, messageID = database:addMessage(username, data.reciever, data.message, data.nonce)
    if not status then
        userSendError(client, activeUser, "message_send_fail")
        return
    end

    local sendTable = {}
    sendTable.messageID = messageID
    local encryptedSendTable = crypto.encrypt(sendTable, activeUser.sharedKey)
    client:send("message_send_success", encryptedSendTable)
end

local function database_public_key_request(data, client)
    local sessionID, status, result
    status, data, sessionID = user_message(data, client)
    if not status or not data then return false end
    local activeUser = ActiveUsers[sessionID]

    status, result = database.getPublicKey(data.requestedUsername)
    if not status then
        userSendError(client, activeUser, "key_req_fail")
        return false
    end
    
    local sendTable = {}
    sendTable.returnKey = result
    sendTable.replyUsername = data.requestedUsername
    local status, encryptedSendTable = crypto.encrypt(sendTable, activeUser.sharedKey)
    if not status then
        print(encryptedSendTable)
        return
    end
    client:send("key_req_response", encryptedSendTable)
end

local function message_request(data, client)
    local sessionID, status, result
    status, data, sessionID = user_message(data, client)
    if not status or not data then return false end
    local activeUser = ActiveUsers[sessionID]

    local username = activeUser.loggedInUsername
    if username == nil then
        userSendError(client, activeUser, "not_logged_in")
        return
    elseif not database.doesUserExist(username) then
        userSendError(client, activeUser, "credentials_invalid")
        return
    end

    local status, err
    if not data.messageType then 
        userSendError(client, activeUser, "malformed_message")
    end

    if not data.reciever then userSendError(client, activeUser, "malformed_message") return end

    if data.messageType == "last_both" then
        status, err = database.getMessage:Last(username, data.reciever, true)
    elseif data.messageType == "last_one" then
        status, err = database.getMessage:Last(username, data.reciever)
    elseif data.messageType == "from_id" then
        if not data.messageID then userSendError(client, activeUser, "malformed_message") return end
        status, err = database.getMessage.fromID(username, data.reciever, data.messageID)
    elseif data.messageType == "next_id" then
        if not data.messageID then userSendError(client, activeUser, "malformed_message") return end
        status, err = database.getMessage.nextID(username, data.reciever, data.messageID)
    end

    if not status then userSendError(client, activeUser, "message_err: "..err) return end

    local sendTable = {}
    sendTable.message = status.message
    sendTable.sender = status.sender
    sendTable.other = data.reciever
    sendTable.askType = data.messageType

    status, result = crypto.encrypt(sendTable, activeUser.sharedKey)
    if not status then return end
    client:send("message_response", result)

end

local function registerUser(data, client)
    local sessionID, status, result
    status, data, sessionID = user_message(data, client)
    if not status or not data then return false end
    local activeUser = ActiveUsers[sessionID]

    local loginUsername, loginPass, loginDatabasePublicKey = data.username, data.password, data.dbPk

    if not loginUsername or not loginPass or not loginDatabasePublicKey then 
        userSendError(client, activeUser, "malformed_message")
        return
    end

    status, result = database.createUserProfile(loginUsername, loginPass, loginDatabasePublicKey)
    if not status then userSendError(client, activeUser, "reg_fail") end

    client:send("register_sucess")
    return
end

-- connect user functions to sock.lua callbacks
local function loadServerCallbacks()
    LovmeServer:on("ping", emptyPing)
    LovmeServer:on("connect", function() end) -- empty connect function, purely to suppress errors
    LovmeServer:on("disconnect", function() end) -- empty disconnect function, purely to suppress errors
    LovmeServer:on("connected", userConnect)
    LovmeServer:on("login", userLogin)
    LovmeServer:on("message_send", message_send)
    LovmeServer:on("database_public_key_req", database_public_key_request)
    LovmeServer:on("message_req", message_request)
    LovmeServer:on("register", registerUser)
end

-- -- on load
function love.load(arg)

    -- diagnostics
    local status, err = loadfile("diagnostics.lua")
    if status == nil then io.write(err..'\n') else status() end

    loadServerCallbacks()

    -- testing client connection
    
end

function ClientUpdate(id, activeUser, time)
    -- table for users to be removed
    local removeTable = {}

    -- if inactive for >10 seconds, kill.
    if time > (activeUser.lastActive + 10) then
        table.insert(removeTable, activeUser.sessionID)
    end

    -- iter through remove table and remove users
    for i, v in pairs(removeTable) do
        ActiveUsers[v] = nil
    end
end

function love.update()
    -- update server
    LovmeServer:update()

    local time = love.timer.getTime()
    local removeTable = {}

    -- if inactive for >10 seconds, kill.

    for _,activeUser in pairs(ActiveUsers) do
        if time > (activeUser.lastActive + 10) then
            table.insert(removeTable, activeUser.sessionID)
        end
    end

    -- iter through remove table and remove users
    for _, v in pairs(removeTable) do
        ActiveUsers[v] = nil
    end

    -- updates active clients

end
