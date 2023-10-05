---@diagnostic disable: duplicate-set-field
-- configure library paths
local libPath = "libs"
package.cpath = package.cpath .. ';./' .. libPath .. '/?.so'
package.path = package.path .. ';./' .. libPath .. '/?.lua'

local connection = require 'connection'
-- local gui = require 'gui'

local getTime = love.timer.getTime


local timerState = 0
local timerOffset = getTime()
local dtimer = 0

function love.load()
    connection.setLoginResponse(function()
        print("login has been responsed")
    end)
    connection.setMessageResponse(function(message)
        print(message.data)
    end)
    connection.setKeyResponse(function(data, user)
        print("key response from user "..user)
    end)

end


function love.update()
    connection.update()
    dtimer = getTime() - timerOffset

    if dtimer > 1 and timerState == 0 then
        timerState = 1
        -- print("register", connection.registerUser("user1", "password"))
        -- print("register", connection.registerUser("user2", "password"))
    elseif dtimer > 1.5 and timerState == 1 then
        timerState = timerState + 1
        print("login", connection:login("user1", "password"))
    elseif dtimer > 2 and timerState == 2 then
        timerState = timerState + 1
        print("key", connection.request_database_public_key("user2"))
    elseif dtimer > 2.5 and timerState == 3 then
        timerState = timerState + 1
        print("send", connection.request_message("user2"))
    -- elseif dtimer > 3 and timerState == 4 then
        -- timerState = timerState + 1
        -- print("request", connection.request_message("user2"))
    -- elseif dtimer > 3.5 and timerState == 5 then
    --     timerState = timerState + 1
    --     connection:logout()
    --     print("login", connection:login("user2", "password"))
    -- elseif dtimer > 4 and timerState == 6 then
    --     timerState = timerState + 1
    --     print("key", connection.request_database_public_key("user1"))
    -- elseif dtimer > 4.5 and timerState == 7 then
    --     timerState = timerState + 1
    --     print("request", connection.request_message("user1"))
    end
end

-- function love.update(dt)
--     connection.update()
-- end

-- function love.draw()
--     gui.draw()
-- end