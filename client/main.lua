---@diagnostic disable: duplicate-set-field
-- configure library paths
local libPath = "libs"
package.cpath = package.cpath .. ';./' .. libPath .. '/?.so'
package.path = package.path .. ';./' .. libPath .. '/?.lua'

local connection = require 'connection'
local gui = require 'gui'

local timerState = 0
local dtimer = 0


function love.load(args)
    connection.setLoginResponse(function()
        print("login has been responsed")
    end)
end

function love.update(dt)
    connection.update()
    dtimer = dtimer + dt

    if dtimer > 3 and timerState == 0 then
        timerState = 1
        print("login", connection:login("user1", "password"))
    elseif dtimer > 5 and timerState == 1 then
        timerState = 2
        print("last", connection.request_message("user2"))
    end
end