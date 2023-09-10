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


-- generate a new session id
local function request_session_id()
    local new_session_id = zen.randombytes(8)
    for _, activeUser in ipairs(ActiveUsers) do
        if activeUser.sessionID == new_session_id then
            return request_session_id()
        end
    end
    return new_session_id
end

local function user_message(data, client)
    local sessionID = data.SID
    local key = ActiveUsers[sessionID].sharedKey
    ActiveUsers[sessionID]:updateActive()
    return crypto.decrypt(data.data, key)
end

local function emptyPong(data, client)
    user_message(data, client)
end

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

local function loadServerCallbacks()
    LovmeServer:on("pong", emptyPong)
    LovmeServer:on("connect", function() end) -- empty connect function
    LovmeServer:on("connected", userConnect)
end

-- -- on load
function love.load()
    --* diagnostics
    local status, err = loadfile("diagnostics.lua")
    if status == nil then print(err) else status() end

    loadServerCallbacks()

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
        end)

        test_client:on("ping", function()
            local sendTable = {}
            local sesh_id = test_client.test_id
            sendTable.SID = sesh_id
            sendTable.data = {}
            sendTable.data = crypto.encrypt(sendTable.data, test_client.shared_key)
            test_client:send("pong", sendTable)
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

    end
end

function love.update()
    -- update server
    test_client:update()
    LovmeServer:update()

    local time = love.timer.getTime()
    for id, activeUser in pairs(ActiveUsers) do
        ClientUpdate(id, activeUser, time)
    end
end
