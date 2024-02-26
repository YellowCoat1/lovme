local tab = {}

local cached = require 'cached'
local connection = require 'connection'

local clickable = require 'gui.clickable'
local textBar = require 'gui.textBar'


require 'gui.screen'

-- tabs table
local tabs = {}
local currentTab

tabs.main =         require 'gui.screens.mainScreen' ()
tabs.settings =     require 'gui.screens.settings' ()
-- tabs.chat =      require 'gui.screens.chat' ()



function tab.setScreen(screen)
    currentScreen = screen
    tabs[screen]:start()
end

function tab.draw()
    tabs[currentScreen]:draw()
end

function tab.mouseClick(x,y)
    tabs[currentScreen]:mouseClick(x, y)
end

function tab.keypressed(key)
    tabs[currentScreen]:keyPressed(key)
end

tab.setScreen("main")

return tab