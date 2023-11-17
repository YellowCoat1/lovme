local textBar = require 'gui.textBar'

-- effectively a module with access to 'clickables'
return function(clickables)

    local chat = {}

    function chat.start()
        -- table.insert(clickables.textBars, textBar(0,0,100))
    end

    function chat.draw()
        -- love.graphics.rectangle("fill", 0, 0, 100, 50)
    end

    return chat

end