local cached = {}

local bitser = require 'bitser'
local fs = love.filesystem

fs.setIdentity("lovme_cache")

local user_data_info = fs.getInfo("userdata")
if not user_data_info then
    fs.createDirectory("userdata")
end

function cached.setValue(name, value)
    local status, err = fs.write("userdata/"..name, bitser:dumps(value))
    return status, err
end

function cached.getValue(name)
    if not fs.getInfo("userdata/"..name) then return false, "failed to load data: "..name end
    local rawData = fs.read(userpath.."/userdata")
    
    local status, result = pcall( function() return bitser.loads(rawUserData) end)
    if status then return result 
    else return false, "deserialization fail" end
end

return cached