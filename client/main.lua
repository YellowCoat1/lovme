---@diagnostic disable: duplicate-set-field
-- configure library paths
local libPath = "libs"
package.cpath = package.cpath .. ';./' .. libPath .. '/?.so'
package.path = package.path .. ';./' .. libPath .. '/?.lua'

local connection
local gui = require 'gui'


function love.load(args)

    
    connection = require 'connection'
end

function love.update()
    connection.update()
end