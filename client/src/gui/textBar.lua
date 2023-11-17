local clickable = require 'gui.clickable'
local textBar = clickable:extend()

local capitals = require 'capitals'
local isDown = love.keyboard.isDown
-- preset height for textbars
local HEIGHT = Font:getHeight("i") * 0.75

function textBar:new(x, y, width, wraparound, text, defaultActive, limit, typeable)
    if not (x or y or width) then print("no.") love.event.exit(1) return end
    
    self.super:new(x, y, width, HEIGHT, function() self.active = true end, function() self.active = false end)
    
    self.x = x
    self.y = y
    self.width = width
    
    self.active = defaultActive or false
    self.superActiveTimer = os.time()
    
    self.text = text or ""
    self.selected = #self.text

    if typeable == false then 
        self.typeable = false
    else
        self.typeable = true
    end

    self.wraparound = wraparound
    self.fragments = {}
    self.limit = limit or 0
    self.wrapCursorPosX, self.wrapCursorPosY = 0, 0

    if wraparound then
        self:remapFragments()
        self:findWrappedCursorPosition()
    end 

    local function clickedFunction()
        self.active = true
    end

    local function notClickedFunction()
        self.active = false
    end



end

function textBar:remapFragments()
    if not self.wraparound then return end
    local lastFragment = 0
    self.fragments = {}
    for i=1,#self.text do
        local fragmentExeedsWidth = Font:getWidth(self.text:sub(lastFragment+1,i+1)) > self.width
        local atTheFinalCharacter = i == #self.text
        local charachterIsANewline = self.text:sub(i,i) == string.char(10) 
        if fragmentExeedsWidth or atTheFinalCharacter or charachterIsANewline then
            table.insert(self.fragments, self.text:sub(lastFragment+1, i))
            lastFragment = i
        end
    end
end

-- find the cursor position in wrapped text
function textBar:findWrappedCursorPosition()
    local cursorPosCounter = self.selected
    self.wrapCursorPosX, self.wrapCursorPosY = 0, 0
    for _,fragment in ipairs(self.fragments) do
        if cursorPosCounter - #fragment > 0 then
            cursorPosCounter = cursorPosCounter - #fragment
            self.wrapCursorPosY = self.wrapCursorPosY + HEIGHT
        else
            self.wrapCursorPosX = Font:getWidth(fragment:sub(0, cursorPosCounter))
            break
        end
    end

end

function textBar:drawText()
    if not self.wraparound then
        love.graphics.print(self.text, self.x, self.y-13, nil, 1, 1)
    else
        for i,v in ipairs(self.fragments) do
            love.graphics.print(v, self.x, self.y-13 + (i-1)*HEIGHT, nil, 1, 1)
        end
    end
end

function textBar:drawCursor()
    if self.typeable == false then return end

    if not self.wraparound then 
        -- set cursor offset to the width of the text until the selected
        local cursorOffset = Font:getWidth(self.text:sub(1, self.selected))
        love.graphics.rectangle("fill", cursorOffset, self.y, 5, HEIGHT)
    else
        love.graphics.rectangle("fill", self.x+self.wrapCursorPosX, self.y+self.wrapCursorPosY, 5, HEIGHT)
    end
end

function textBar:draw()

    self:drawText()
    if not self.active then return end
    self:drawCursor()
end

function textBar:typeKey(key)

    -- quit if limit has been reached
    if self.limit ~= 0 and #self.text >= self.limit then return end
    -- set the text to (the text before marker) + the key + (the text after marker)
    self.text = self.text:sub(1, self.selected) .. key .. self.text:sub(self.selected+1, #self.text)
    -- increment marker by key length
    self.selected = self.selected + #key
    self:remapFragments()
end

function textBar:removeKey()
    -- set the text to (the text before one spot before the marker) + (the text after the marker)
    self.text = self.text:sub(1, self.selected-1) .. self.text:sub(self.selected + 1, #self.text)
    -- decrement marker
    self.selected = self.selected - 1 
    self:remapFragments()
end

function textBar:keypress(key)
    if not self.active or not self.typeable then return end

    if #key == 1 then
        if isDown("lshift") or isDown("rshift") then
            self:typeKey(capitals[key])
        else
            self:typeKey(key)
        end
    elseif key == "space" then 
        self:typeKey(" ")
    elseif key == "tab" then
        self:typeKey("    ")
    elseif key == "backspace" and #self.text > 0 and self.selected > 0 then
        self:removeKey()
    elseif key == "return" and self.wraparound then
        self:typeKey(string.char(10))
    elseif key == "left" and self.selected > 0 then
        self.selected = self.selected - 1
    elseif key == "right" and self.selected < #self.text then
        self.selected = self.selected + 1
    end

    if self.wraparound then
        self:findWrappedCursorPosition()
    end


end

return textBar