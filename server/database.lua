local database = {}

local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

love.filesystem.setIdentity("LOVME_server")


local users_dir_info = love.filesystem.getInfo("users")
if not users_dir_info then
    love.filesystem.createDirectory("users")
elseif not users_dir_info.type == "directory" then
    error("users file found; not directory.")
end

local function test_username(username)
    assert(type(username) == "string", "invalid username in test_username")
    -- banned characters: spaces, [, ], (, ), :, ;, %
    if username:find("[%s%[%]%(%)%.%:%;%%]") then
        return false
    end
    return true
        
end


function database.createUserProfile(username, pass)

    -- username and password should be correct
    if not test_username(username) then io.write(err..'\n') return false, "invalid username" end
    if not test_username(pass) then io.write(err..'\n') return false, "invalid password" end
    -- gen salt and hashed pass
    local salt = zen.randombytes(16)
    local hashed_pass = zen.argon2i(pass, salt, 5000, 10)
    -- error if no users dir or if theres already a user profile
    local userpath = "users/"..username
    assert(love.filesystem.getInfo("users"), "user creation without users folder")
    if love.filesystem.getInfo(userpath) then return false, "user already exists" end
    
    -- save data in database (filesystem)
    local saveTable = {}
    saveTable.passHash = hashed_pass
    saveTable.salt = salt
    local savedUserData = bitser.dumps(saveTable)
    local status, err = love.filesystem.write(userpath.."/", savedUserData)
    if not status then io.write(err..'\n') return false, "failed to write user object" end
    return true
end



-- print(status, err)

return database