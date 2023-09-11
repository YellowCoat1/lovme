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

local function emptyPong(data, client)
    user_message(data, client)
end

-- user connect, handles filing user key and user object creation
local function userConnect(data, client)
    local ServerSecKey = zen.randombytes(32)
    local ServerPubKey = zen.x25519_public_key(ServerSecKey)
    local shared = crypto.shared_key(ServerSecKey, data.upk)
    local sessionID = request_session_id()
    ActiveUsers[sessionID] = user(sessionID, shared, client)
    local returnTable = {}
    returnTable.spk = ServerPubKey
    returnTable.sessionID = sessionID
    client:send("key_response", returnTable)
end

-- user attempting to login with a username and password
local function userLogin(data, client)
    local sessionID, status
    status, data, sessionID = user_message(data, client)
    if not status or not data then
        return false
    end
    local activeUser = ActiveUsers[sessionID]

    status = database:checkPassEquality(data.user, data.pass)
    if status then
        activeUser.loggedInUsername = data.user
    else
        userSendError(client, activeUser, "rejected_pass")
        return false
    end

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

    local status, err = database:addStringMessage(username, data.reciever, data.message)
    if not status then
        userSendError(client, activeUser, "message_send_fail")
        return
    end

end

-- connect user functions to sock.lua callbacks
local function loadServerCallbacks()
    LovmeServer:on("pong", emptyPong)
    LovmeServer:on("connect", function() end) -- empty connect function, purely to suppress errors
    LovmeServer:on("connected", userConnect)
    LovmeServer:on("login", userLogin)
    LovmeServer:on("message_send", message_send)
end

-- -- on load
function love.load()

    -- diagnostics
    local status, err = loadfile("diagnostics.lua")
    if status == nil then io.write(err..'\n') else status() end

    loadServerCallbacks()

    -- testing client connection
    do
        test_client = sock.newClient("localhost", SERVER_PORT)
        local test_csk = zen.randombytes(32)
        local test_cpk = zen.x25519_public_key(test_csk)
        test_client:connect()


        test_client:on("connect", function()
            local sendTable = {}
            sendTable.upk = test_cpk
            test_client:send("connected", sendTable)
        end)

        test_client:on("key_response", function(data)
            test_client.test_id = data.sessionID
            test_client.shared_key = zen.key_exchange(test_csk, data.spk)

            -- login
            local sendTable = {}
            sendTable.SID = test_client.test_id
            sendTable.data = {}
            sendTable.data.user = "user1"
            sendTable.data.pass = "password"
            _, sendTable.data = crypto.encrypt(sendTable.data, test_client.shared_key)
            test_client:send("login", sendTable)
        end)

        test_client:on("ping", function()
            local sendTable = {}
            local sesh_id = test_client.test_id
            sendTable.SID = sesh_id
            sendTable.data = {}
            _, sendTable.data = crypto.encrypt(sendTable.data, test_client.shared_key)
            test_client:send("pong", sendTable)
        end)
        test_client:on("usr_error", function(data)
            status, data = crypto.decrypt(data, test_client.shared_key)
            print(data[1])
        end)
    end
end

function ClientUpdate(id, activeUser, time)
    -- table for users to be removed
    local removeTable = {}

    -- if inactive for >3 seconds, ping.
    if time > (activeUser.lastActive + 3) and (not activeUser.waitingForPing) then
        activeUser.waitingForPing = true
        activeUser.client:send("ping")
        -- if inactive for >10 seconds, kill.
    elseif time > (activeUser.lastActive + 10) then
        table.insert(removeTable, activeUser.sessionID)
    end

    -- iter through remove table and remove users
    for i, v in pairs(removeTable) do
        ActiveUsers[v] = nil
    end
end

function love.update()
    -- update server
    test_client:update()
    LovmeServer:update()

    -- updates active clients
    local time = love.timer.getTime()
    for id, activeUser in pairs(ActiveUsers) do
        ClientUpdate(id, activeUser, time)
    end
end
