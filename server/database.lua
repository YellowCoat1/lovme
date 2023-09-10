local database = {}

local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

love.filesystem.setIdentity("LOVME_server")


local users_dir_info = love.filesystem.getInfo("users")
if not users_dir_info then
    love.filesystem.createDirectory("users")
elseif not users_dir_info.type == "directory" then
    error("users file found; not directory.")
end

local function test_username(username)
    assert(type(username) == "string", "invalid username in test_username")
    -- banned characters: spaces, [, ], (, ), :, ;, %
    if username:find("[%s%[%]%(%)%.%:%;%%]") then
        return false
    end
    return true
        
end



-- print(status, err)

return database