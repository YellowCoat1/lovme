local clickable = require 'gui.clickable'
local textBar = clickable:extend()

local capitals = require 'capitals'
local isDown = love.keyboard.isDown
-- preset height for textbars
local HEIGHT = Font:getHeight("iTLE| $!`")
local abs = math.abs

-- x and y for the coordinates of the top left of the text bar
-- width is for how wide (x-direction wise) the text box is.
-- wraparound is for if text should wrap.
-- default active is setting it to be selected when initialized
-- typeable is if the user can type in it
-- text color is a table containing three values, representing the color of the text
function textBar:new(x, y, width, wraparound, defaultActive, typeable, textColor)
    if not (x or y or width) then print("no.") love.event.exit(1) return end
    self.super.new(self, x, y, width, HEIGHT, 
        function() self.active = true end,
        function() self.active = false end)
    
    self.x = x
    self.y = y
    self.width = width
    self.textColor = textColor
    
    self.active = defaultActive or false
    self.superActiveTimer = os.time()
    
    self.text = text or ""
    self.selected = #self.text

    self.enterFunction = function() end

    if typeable == false then 
        self.typeable = false
    else
        self.typeable = true
    end

    self.wraparound = wraparound
    self.fragments = {}
    self.limit = 0
    self.lineLimit = 0
    self.wrapCursorPosX, self.wrapCursorPosY = 0, 0

    if wraparound then
        self:remapFragments()
        self:findWrappedCursorPosition()
    end

end

-- re-calculate fragments of a wrapped text
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
    if self.text:sub(#self.text, #self.text) == string.char(10) or #self.fragments == 0 then
        table.insert(self.fragments, "")
    end

    self:setInteractHeight(HEIGHT * #self.fragments)
end

-- find the cursor position in wrapped text
-- returns the fragment index and charachter offset
function textBar:findWrappedCursorPosition()
    if self.selected == 0 then return 1,0 end
    
    if self.selected > #self.text then
        print("INVALID CURSOR POSITION")
        self.selected = #self.text
    end

    local cursorPosCounter = self.selected
    self.wrapCursorPosX, self.wrapCursorPosY = 0, 0
    for index,fragment in ipairs(self.fragments) do
        if cursorPosCounter - #fragment > 0 then
            cursorPosCounter = cursorPosCounter - #fragment
        elseif fragment:sub(cursorPosCounter,cursorPosCounter) == string.char(10) then
            return index+1, 0
        else
            return index, cursorPosCounter
        end
    end
end

-- finds the cursor's x and y in wrapped text 
function textBar:findWrappedCursorXY()
    local fragmentIndex, charOffset = self:findWrappedCursorPosition() 
    local fragment = self.fragments[fragmentIndex] or ""
    self.wrapCursorPosX = Font:getWidth(fragment:sub(0, charOffset))
    self.wrapCursorPosY = HEIGHT * (fragmentIndex-1)
end

-- in response to an up arrow, move the cursor up
function textBar:cursorUp()
    
    -- if you're at the first line then set cursor to the start
    if fragmentIndex == 1 then self.selected = 0 return end

    local fragmentIndex, charOffset = self:findWrappedCursorPosition()
    
    -- finds the width of the charachters up until the cursor
    local charWidth
    if charOffset == 0 then
        charWidth = 0 -- if you're at the beginning of the line the width is 0
    else 
        charWidth = Font:getWidth(self.fragments[fragmentIndex]:sub(1, charOffset))
    end

    local lastLine = self.fragments[fragmentIndex-1]

    -- if we're at the first line, just go to the start.
    if fragmentIndex == 1 then 
        self.selected = 0
        return
    end

    -- if the width of the last line is less than the needed width then we just go to the end of that
    local lastLineShort = Font:getWidth(lastLine) < charWidth
    -- if the width of the current line is zero
    local nothingAtCurrentLine = charWidth == 0
    local goingToLastLine = false
    if lastLineShort then
        -- sets the cursor to the end of the last line by subtracting the char offset 
        self.selected = self.selected - charOffset
        goingToLastLine = true
    elseif nothingAtCurrentLine then
        self.selected = self.selected - #lastLine
    else

        for i=0,#lastLine do
            if Font:getWidth(lastLine:sub(1,i+1)) >= charWidth then
                local neededChar
                if abs(Font:getWidth(lastLine:sub(1,i)) - charWidth) < abs(Font:getWidth(lastLine:sub(1,i+1)) - charWidth) then
                    self.selected = self.selected - (charOffset + (#lastLine - i))
                else
                    self.selected = self.selected - (charOffset + (#lastLine - i) - 1)
                end
                -- goingToLastLine = true
                break
            end
        end
    end

    if goingToLastLine and lastLine:sub(#lastLine, #lastLine) == string.char(10) then
        self.selected = self.selected - 1
    end

end
 
-- in response to a down arrow, move the cursor down
function textBar:cursorDown()
        
    local fragmentIndex, charOffset = self:findWrappedCursorPosition()
    
    if fragmentIndex >= #self.fragments then 
        self.selected = #self.text
        return
    end

    local thisLine = self.fragments[fragmentIndex]
    local nextLine = self.fragments[fragmentIndex+1]
    
    -- finds the width of the charachters up until the cursor
    local charWidth
    if charOffset == 0 then
        charWidth = 0 -- if you're at the beginning of the line the width is 0
    else 
        charWidth = Font:getWidth(thisLine:sub(1, charOffset))
    end


    -- if the width of the last line is less than the needed width then we just go to the end of that
    local nextLineShort = Font:getWidth(nextLine) < charWidth
    -- if the width of the current line is zero
    local nothingAtCurrentLine = charWidth == 0
    
    local goingToNextLine = false
    if #nextLine == 0 then
        -- print("AAAAAAAAAAA")
        self.selected = self.selected + (#thisLine - charOffset)
        goingToNextLine = true
    elseif nextLineShort then
        -- sets the cursor to the end of the next line by adding the remaining charachter
        self.selected = self.selected + (#thisLine - charOffset) + #nextLine
        if nextLine:sub(#nextLine, #nextLine) == string.char(10) then
            self.selected = self.selected - 1
        end
        -- goingToLastLine = true
    elseif nothingAtCurrentLine then
        self.selected = self.selected + (#thisLine - charOffset)
    else
        for i=1,#nextLine do
            if Font:getWidth(nextLine:sub(1,i)) >= charWidth then
                local neededChar
                if abs(Font:getWidth(nextLine:sub(1,i-1)) - charWidth) < abs(Font:getWidth(nextLine:sub(1,i+1)) - charWidth) then
                    self.selected = self.selected +  (#thisLine - charOffset) + (i - 1)
                else
                    self.selected = self.selected + (#thisLine - charOffset) + i
                end
                break
            end
        end
    end

    if goingToLastLine and thisLine:sub(#thisLine, #thisLine) == string.char(10) then
        self.selected = self.selected + 1
    end

end

-- draws the text (and only the text)
function textBar:drawText()
    if not self.wraparound then
        -- if text is not wrapped, it can just be printed.
        love.graphics.print(self.text, self.x, self.y, nil, 1, 1)
    else
        -- if text is wrapped, every fragment must be printed
        for i,v in ipairs(self.fragments) do
            love.graphics.print(v, self.x, self.y + (i-1)*HEIGHT, nil, 1, 1)
        end
    end
end

-- draws the cursor on the screen
function textBar:drawCursor()
    if self.typeable == false then return end

    if not self.wraparound then 
        -- set cursor offset to the width of the text until the selected
        local cursorOffset = Font:getWidth(self.text:sub(1, self.selected))
        love.graphics.rectangle("fill", self.x+cursorOffset, self.y, 5, HEIGHT)
    else
        love.graphics.rectangle("fill", self.x+self.wrapCursorPosX, self.y+self.wrapCursorPosY, 5, HEIGHT)
    end
end

-- draws the text bar on the screen
function textBar:draw()
    self:drawText()
    if not self.active then return end
    self:drawCursor()
end

-- add a key to the text bar
function textBar:typeKey(key)

    -- quit if limit has been reached
    if self.limit ~= 0 and #self.text >= self.limit then return end
    -- set the text to (the text before marker) + the key + (the text after marker)
    self.text = self.text:sub(1, self.selected) .. key .. self.text:sub(self.selected+1, #self.text)
    -- increment marker by key length
    self.selected = self.selected + #key
    self:remapFragments()
end

-- removes a key from the text bar
function textBar:removeKey()
    -- set the text to (the text before one spot before the marker) + (the text after the marker)
    self.text = self.text:sub(1, self.selected-1) .. self.text:sub(self.selected + 1, #self.text)
    -- decrement marker
    self.selected = self.selected - 1 
    self:remapFragments()
end

-- handle when a key is pressed and add a letter if applicable 
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
    elseif key == "return" then
        self.enterFunction()
        if self.wraparound then
            self:typeKey(string.char(10))
        end
    elseif key == "left" and self.selected > 0 then
        self.selected = self.selected - 1
    elseif key == "right" and self.selected < #self.text then
        self.selected = self.selected + 1
    elseif key == "up" and self.wraparound then
        self:cursorUp()
    elseif key == "down" and self.wraparound then
        self:cursorDown()
    end

    if #self.fragments > self.lineLimit and self.lineLimit ~= 0 then
        self:removeKey()
    end
    
    if self.wraparound then
        self:findWrappedCursorXY()
    end

end

function textBar:setEnterFunction(enterFunction)
    self.enterFunction = enterFunction
end

function textBar:getHeight()
    return #self.fragments * HEIGHT
end

function textBar:setLimit(limit)
    self.limit = limit
end

function textBar:setLineLimit(lineLimit)
    self.lineLimit = lineLimit
end

-- set the text of the text bar
function textBar:setText(text, setCursor)
    if setCursor ~= false then setCursor = true end

    self.text = text

    local textLowerThanCursor = self.selected > #text

    if setCursor or textLowerThanCursor then 
        self.selected = #text 
    end 
    
    if self.wraparound then
        self:remapFragments()
        self:findWrappedCursorXY()
    end
end

return textBar