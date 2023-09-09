-- configure library paths
local libPath = "libs"
package.cpath  = package.cpath .. ';./' .. libPath .. '/?.so'
package.path  = package.path .. ';./' .. libPath .. '/?.lua'

Object = require 'classic' -- oo
local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

local crypto = require 'crypto'

-- class user
local user = require 'user'

UpdateFunctions = {}

local SERVER_PORT = 22122

local activeUsers = {}

local LovmeServer = sock.newServer("localhost", SERVER_PORT)
local test_client
local test_csk
local test_cpk


local function request_session_id()
    local new_session_id = zen.randombytes(8)
    for _,activeUser in ipairs(activeUsers) do
        if activeUser.session_id == new_session_id then
            return request_session_id()
        end
    end
    return new_session_id
end

local function emptyPong(data, client)
    local id = client.session_id
    data = crypto.decrypt(data, id)
    activeUsers[data.sessionID]:updateTimeout() -- updates user's last active time
end

local function userConnect(data, client)
    local shared = crypto.shared_key(data.upk)
    local session_id = request_session_id()
    print("test")
    local client_id = tostring(client.connectId)
    activeUsers[client_id] = user(client_id, session_id, shared)
    print("test2", #activeUsers)

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
        test_csk = zen.randombytes(32)
        test_cpk = zen.x25519_public_key(test_csk)
        test_client:connect()
        test_client:send("connected", {test_cpk})
    end

end

function love.update()
    
    -- update server
    test_client:update()
    LovmeServer:update()

    local time = love.timer.getTime()
    for id,activeClient in pairs(activeUsers) do
        if time + 3 > activeClient.lastActive and not activeClient.waitingForPing then
            activeClient.waitingForPing = true
            local clientObject = LovmeServer:getClientByConnectId(id)
            clientObject:send("ping")
        end
    end

end