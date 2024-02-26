---@diagnostic disable: duplicate-set-field
-- configure library paths
local libPath = "libs"
package.cpath = package.cpath .. ';./' .. libPath .. '/?.so'
package.path = package.path .. ';./' .. libPath .. '/?.lua'
local srcPath = "src"
package.cpath = package.cpath .. ';./' .. srcPath .. '/?.so'
package.path = package.path .. ';./' .. srcPath .. '/?.lua'

Object = require 'classic'
local connection = require 'connection'
local gui = require 'gui.init'

local getTime = love.timer.getTime

local timerState = 0
local timerOffset = getTime()
local dtimer = 0

function love.load()
    connection.setMessageResponse(function(message)
        print(message.data)
    end)
    connection.setKeyResponse(function(data, user)
        print("key response from user "..user)
    end)
end


function love.update(dt)
    connection.update()
    dtimer = getTime() - timerOffset
    -- if dtimer > 1 and timerState == 0 then
    --     timerState = 1
    --     -- print("register", connection.registerUser("user1", "password"))
    --     -- print("register", connection.registerUser("user2", "password"))
    -- elseif dtimer > 1.5 and timerState == 1 then
    --     timerState = timerState + 1
    --     print("login", connection:login("user1", "password"))
    -- elseif dtimer > 2 and timerState == 2 then
    --     timerState = timerState + 1
    --     print("key", connection.request_database_public_key("user2"))
    -- elseif dtimer > 2.5 and timerState == 3 then
    --     timerState = timerState + 1
    --     print("send", connection.request_message("user2"))
    -- end
end

function love.draw()
    gui.draw()
end

function love.keypressed(key)
    gui.keypressed(key)
end

function love.mousepressed(x, y, button)
    gui.mousePressed(x,y,button)
end