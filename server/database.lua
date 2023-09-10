local database = {}

local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

love.filesystem.setIdentity("LOVME_server")


local user_dir_info = love.filesystem.getInfo("users")
if not user_dir_info then
    love.filesystem.createDirectory("users")
elseif not user_dir_info.type == "directory" then
    error("users file found; not directory.")
end




-- print(status, err)

return database