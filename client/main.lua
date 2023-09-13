-- configure library paths
local libPath = "libs"
package.cpath = package.cpath .. ';./' .. libPath .. '/?.so'
package.path = package.path .. ';./' .. libPath .. '/?.lua'

local connection = require 'connection'



---@diagnostic disable-next-line: duplicate-set-field
function love.update()
    connection.update()
end