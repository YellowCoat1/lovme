---@diagnostic disable: duplicate-set-field
-- configure library paths
local libPath = "libs"
package.cpath = package.cpath .. ';./' .. libPath .. '/?.so'
package.path = package.path .. ';./' .. libPath .. '/?.lua'

local connection
local gui = require 'gui'


function love.load(args)
    ARGS = args
    if not ARGS[1] then ARGS[1] = "user1" end
    if not ARGS[2] then ARGS[2] = "password" end
    connection = require 'connection'
end

function love.update()
    connection.update()
end