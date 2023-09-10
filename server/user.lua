-- user object file
local user = Object:extend()

-- user object to be stored in ActiveUsers table
function user:new(sessionID, sharedKey, client)
    self.client = client
    self.sessionID = sessionID
    self.sharedKey = sharedKey
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
    self.loggedInUsername = nil
end

-- called whenever a user is seen active
function user:updateActive()
    self.lastActive = love.timer.getTime()
    self.waitingForPing = false
end

return user