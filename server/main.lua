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

local SERVER_PORT = 22123

local activeUsers = {}

LovmeServer = sock.newServer("localhost", SERVER_PORT)
local test_client
local test_client2


-- generate a new session id
local function request_session_id()
    local new_session_id = zen.randombytes(8)
    for _,activeUser in ipairs(activeUsers) do
        if activeUser.sessionID == new_session_id then
            return request_session_id()
        end
    end
    return new_session_id
end

local function emptyPong(data, client)
    local id = client.sessionID
    print(id)
    --data = crypto.decrypt(data, id)
    activeUsers[data.sessionID]:updateActive() -- updates user's last active time
end

local function userConnect(data, client)
    local ServerSecKey = zen.randombytes(32)
    local ServerPubKey = zen.x25519_public_key(ServerSecKey)
    local shared = crypto.shared_key(ServerSecKey, data.upk)
    local sessionID = request_session_id()
    activeUsers[sessionID] = user(sessionID, shared)
end

local function loadServerCallbacks()
    LovmeServer:on("pong", emptyPong)
    -- LovmeServer:on("connect", function() end) -- empty connect function
    LovmeServer:on("connected", userConnect)
    LovmeServer:on("greeting", function() print("greet") end)
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

        test_client:on("ping", function() test_client:send("pong") print("ping") end )

    end

end

function ClientUpdate(id, activeUser)

    local time = love.timer.getTime()
    local removeTable = {}

    if time > (activeUser.lastActive+3) and (not activeUser.waitingForPing) then
        activeUser.waitingForPing = true
        local clientObject = LovmeServer:getClientByConnectId(id)
        if clientObject == nil then print("id missing") return end
        clientObject:send("ping")
    elseif time > (activeUser.lastActive+10) then
        table.insert(removeTable, activeUser.sessionID)
    end
end


function love.update()
    -- update server
    test_client:update()
    LovmeServer:update()

    for id,activeUser in pairs(activeUsers) do
        ClientUpdate(id, activeUser)
        
    end

end