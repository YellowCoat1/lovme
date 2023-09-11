local database = {}

local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

love.filesystem.setIdentity("LOVME_server")


local users_dir_info = love.filesystem.getInfo("users")
if not users_dir_info then
    love.filesystem.createDirectory("users")
elseif users_dir_info.type ~= "directory" then
    error("users file found; not directory.")
end

-- test if a username has only valid characters
local function test_username(username)
    assert(type(username) == "string", "invalid type in test_username. type: " .. type(username))
    -- banned characters: spaces, [, ], (, ), :, ;, %
    if username:find("[%s%[%]%(%)%.%:%;%%]") then
        return false
    end
    return true
        
end

-- create a profile for a user in the database
function database.createUserProfile(username, pass)
    if not username then return false, "absent username" end
    if not pass then return false, "absent password" end
    
    -- username and password should be correct
    if not test_username(username) then return false, "invalid username" end
    if not test_username(pass) then return false, "invalid password" end

    -- gen salt and hashed pass
    local salt = zen.randombytes(16)
    local hashed_pass = zen.argon2i(pass, salt, 1000, 10)
    -- error if no users dir or if theres already a user profile
    local userpath = "users/"..username
    assert(love.filesystem.getInfo("users"), "user creation without users folder")
    if love.filesystem.getInfo(userpath) then return false, "user already exists" end

    -- make user directory
    local status = love.filesystem.createDirectory(userpath)
    if status == false then return false, "failed to create user directory" end
    local status = love.filesystem.createDirectory(userpath.."/messages")
    if status == false then return false, "failed to create messages directory" end
    
    -- save data in database (filesystem)
    local saveTable = {}
    saveTable.passHash = hashed_pass
    saveTable.salt = salt
    local savedUserData = bitser.dumps(saveTable)
    local status, err = love.filesystem.write(userpath.."/userdata", savedUserData)
    if not status then io.write(err..'\n') return false, "failed to write user object" end
    return true
end

-- same as rm -r 
local function recursiveRemove(path)
    local pathInfo = love.filesystem.getInfo(path)
    if not pathInfo then return false, "path does not exist" end
    if pathInfo.type == "file" then
        love.filesystem.remove(path)
        return nil
    end
    local files = love.filesystem.getDirectoryItems(path)
    for i,v in ipairs(files) do
        recursiveRemove(path.."/"..v)
    end
    return love.filesystem.remove(path)
end


-- removes a user profile from the database
function database.removeUserProfile(username)
    local userpath = "users/"..username
    if not love.filesystem.getInfo(userpath) then return false, "user does not exist" end
    local status = recursiveRemove(userpath)
    if status == false then return false, "failed to remove user" end
    return true
end


-- returns the data associated with a user profile
function database.loadUserProfile(username)
    local userpath = "users/"..username
    if not love.filesystem.getInfo(userpath.."/userdata") then return false, "failed to load user data" end
    local rawUserData = love.filesystem.read(userpath.."/userdata")
    if not rawUserData then return false, "failed to read userdata" end

    -- calls bitser.loads in a protected call
    local status, result = pcall( function() return bitser.loads(rawUserData) end)
    if status == false then result = "deserialization fail" end
    return status, result
end

-- checks if a password is correct for a user
function database:checkPassEquality(username, pass)
    local status, userData = self.loadUserProfile(username)
    if not love.filesystem.getInfo("users/"..username) then return false, "user does not exist" end
    if not userData or status == false then return false, "failed to load user profile: " .. userData end
    local salt = userData.salt
    local hashed_pass = zen.argon2i(pass, salt, 1000, 10)
    if hashed_pass == userData.passHash then return true, true
    else return true, false end
end

function database.addMessage(username, message)
    -- message is a table with the format
    -- type: string     type of the message (text|image)
    -- data: any        the message itself     

end

-- database location: ~/.local/share/love/LOVME_server
return database