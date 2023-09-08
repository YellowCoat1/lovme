-- configure library paths
local libPath = "libs"
package.cpath  = package.cpath .. ';./' .. libPath .. '/?.so'
package.path  = package.path .. ';./' .. libPath .. '/?.lua'

Object = require 'classic' -- oo
local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

-- class user
local user = require 'user'

UpdateFunctions = {}

local SERVER_PORT = 45751

LOVME = {}
LOVME.activeUsers = {}
LOVME.lovmServer = sock.newServer("*", SERVER_PORT)


local function request_session_id()
    local session_id = zen.randombytes(8)
    for i,activeUser in LOVME.activeUsers do 
        if activeUser.session_id == session_id then
            return request_session_id()
        end
    end
    return session_id
end

local function emptyPong(data, client)
    LOVME.activeUsers[data.sessionID]:updateTimeout() -- updates user's last active time
end

local function userConnect(data, client)
    local shared = LOVME.shared_key(data.upk)
    local session_id = request_session_id()
    LOVME.activeUsers[session_id] = user(client:getConnectId(), shared, session_id)
end

local function userReconnect(data, client)
    local shared = LOVME.shared_key(data.upk)
    data = LOVME.decrypt(data.data, shared)
end

local function loadServerCallbacks()
    LOVME.lovmServer:on("ping", function(data, client) client:send("pong") end) -- recieve ping and reply with a pong
    LOVME.lovmServer:on("pong", emptyPong)
    LOVME.lovmServer:on("connected", userConnect)
    LOVME.lovmServer:on("reconnect", userReconnect)
end

-- -- on load
function love.load()
    --* diagnostics
    local status, err = loadfile("diagnostics.lua")
    if status == nil then print(err) else status() end

    --* cryptography
    local status, err = loadfile("crypto.lua")
    if status == nil then print(err) else status() end

    loadServerCallbacks()

    do
        local userSk = zen.randombytes(32)
        local userPk = zen.x25519_public_key(userSk)
        userConnect(userPk, nil)
    end

end

function love.update()
    
    -- update server
    LOVME.lovmServer:update()

    -- etc vars
    local time = love.timer.getTime()
    local removeTable = {}

    --* iter through active users
    for index,activeUser in pairs(LOVME.activeUsers) do
        if time > activeUser.lastActive + 2 and not activeUser.waitingForPing then -- if the user has been inactive for more than 2 seconds,
            user.client:send("ping") -- ping them.
            user.waitingForPing = true
        elseif time > activeUser.lastActive + 30 then -- if they've been unresponsive for a full 30 seconds,
            assert(not activeUser.waitingForPing, "timed out user without ping flag")
            removeTable[#removeTable+1] = index -- cut them off.
        end
    end
    -- remove flagged users
    for _,v in ipairs(removeTable) do
        LOVME.activeUsers[v] = nil
    end

    -- update functions (currently empty)
    for _,v in ipairs(UpdateFunctions) do
        v()
    end

end