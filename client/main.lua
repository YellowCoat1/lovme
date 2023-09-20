---@diagnostic disable: duplicate-set-field
-- configure library paths
local libPath = "libs"
package.cpath = package.cpath .. ';./' .. libPath .. '/?.so'
package.path = package.path .. ';./' .. libPath .. '/?.lua'

local connection = require 'connection'
local gui = require 'gui'


function love.load(args)

end

function love.update()
    connection.update()
end