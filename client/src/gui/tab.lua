local tab = {}

-- screens table
local screens = {}
local currentScreen = "main"

screens.main = {}
screens.loading = {}
screens.chat = {}
screens.settings = {}

local clickables = {}
clickables.textBars = {}
clickables.other = {}

function screens.main.start()
    table.insert(clickables, textBar(0,0,width))
end


function tab.setScreen(screen)
    clickables = {}
    clickables.textBars = {}
    clickables.other = {}
    currentScreen = screen
end

function tab.draw()

end

tab.setScreen("main")

return tab