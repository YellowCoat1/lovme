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
    connection.setMessageResponse(function(message) 
        print(message.data)
    end)
end

function love.update(dt)
    connection.update()
    dtimer = dtimer + dt

    if dtimer > 3 and timerState == 0 then
        timerState = 1
        print("login", connection:login("user1", "password"))
    elseif dtimer > 4 and timerState == 1 then
        timerState = timerState + 1
        print("key", connection.request_database_public_key("user2"))
    elseif dtimer > 5 and timerState == 2 then
        timerState = timerState + 1
        print("send", connection.sendStringMessage("user2", "hello."))
    elseif dtimer > 6 and timerState == 3 then
        timerState = timerState + 1
        print("request", connection.request_message("user2"))
    end
end