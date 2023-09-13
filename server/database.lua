local database = {}

local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

local fs = love.filesystem
fs.setIdentity("LOVME_server")


local users_dir_info = fs.getInfo("users")
if not users_dir_info then
    fs.createDirectory("users")
elseif users_dir_info.type ~= "directory" then
    error("users file found; not directory.")
end


database.epochOffset = os.time() - math.floor(love.timer.getTime())


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
function database.createUserProfile(username, pass, database_salt)
    if not username then return false, "absent username" end
    if not pass then return false, "absent password" end
    
    -- username and password should be correct
    if not test_username(username) then return false, "invalid username" end
    if not test_username(pass) then return false, "invalid password" end

    -- gen salt and hashed pass
    local salt = zen.randombytes(16)
    local hashed_pass = zen.argon2i(pass, salt, 500, 10)
    -- error if no users dir or if theres already a user profile
    local userpath = "users/"..username
    assert(fs.getInfo("users"), "user creation without users folder")
    if fs.getInfo(userpath) then return false, "user already exists" end

    -- make user directory
    local status = fs.createDirectory(userpath)
    if status == false then return false, "failed to create user directory" end
    local status = fs.createDirectory(userpath.."/chats")
    if status == false then return false, "failed to create messages directory" end
    
    -- save data in database (filesystem)
    local saveTable = {}
    saveTable.passHash = hashed_pass
    saveTable.salt = salt

    -- database public key for the user
    -- used for decrpyting conversations
    if not database_salt then return false, "database_salt not found" end
    if type(database_salt) ~= "string" then return false, "database_salt not a string" end
    if #database_salt ~= 16 then return false, "database_salt invalid size" end
    local bytes16Salt = database_salt
    local databasePrivateKey = zen.argon2i(pass, bytes16Salt, 200, 15)
    saveTable.DatabasePublicKey = zen.x25519_public_key(databasePrivateKey)

    local savedUserData = bitser.dumps(saveTable)
    local status, err = fs.write(userpath.."/userdata", savedUserData)
    if not status then io.write(err..'\n') return false, "failed to write user object" end
    return true
end

-- same as rm -r 
local function recursiveRemove(path)
    local pathInfo = fs.getInfo(path)
    if not pathInfo then return false, "path does not exist" end
    if pathInfo.type == "file" then
        fs.remove(path)
        return nil
    end
    local files = fs.getDirectoryItems(path)
    for i,v in ipairs(files) do
        recursiveRemove(path.."/"..v)
    end
    return fs.remove(path)
end


-- removes a user profile from the database
function database.removeUserProfile(username)
    local userpath = "users/"..username
    if not fs.getInfo(userpath) then return false, "user does not exist" end
    local status = recursiveRemove(userpath)
    if status == false then return false, "failed to remove user" end
    return true
end


-- returns the data associated with a user profile
function database.loadUserProfile(username)
    local userpath = "users/"..username
    if not fs.getInfo(userpath.."/userdata") then return false, "failed to load user data" end
    local rawUserData = fs.read(userpath.."/userdata")
    if not rawUserData then return false, "failed to read userdata" end

    -- calls bitser.loads in a protected call
    local status, result = pcall( function() return bitser.loads(rawUserData) end)
    if status == false then result = "deserialization fail" end
    return status, result
end

function database.getPublicKey(username)
    local userpath = "users/"..username
    if not fs.getInfo(userpath.."/userdata") then return false, "failed to load user data" end
    local rawUserData = fs.read(userpath.."/userdata")
    if not rawUserData then return false, "failed to read userdata" end

    local status, result = pcall( function() return bitser.loads(rawUserData) end)
    if status == false or not result then
        return false, "deserialization fail"
    end
    local pubKey = result.DatabasePublicKey
    if not pubKey then
        return false, "no public database key found"
    end

    return true, pubKey
end

-- checks if a user exists in the database
function database.doesUserExist(username)
    if fs.getInfo("/users/"..username) then return true
    else return false end
end

-- checks if a password is correct for a user
function database:checkPassEquality(username, pass)
    local status, userData = self.loadUserProfile(username)
    if not fs.getInfo("users/"..username) then return false, "user does not exist" end
    if not userData or status == false then return false, "failed to load user profile: " .. userData end
    local salt = userData.salt
    local hashed_pass = zen.argon2i(pass, salt, 10000, 10)
    if hashed_pass == userData.passHash then return true, true
    else return true, false end
end

function database.openUserChat(username1, username2, bypass)
    local user1ChatsPath = "users/"..username1.."/chats"
    local user2ChatsPath = "users/"..username2.."/chats"

    -- error checking
    if not fs.getInfo(user1ChatsPath) then return false, "can't find user 1 chat directory" end
    if not fs.getInfo(user2ChatsPath) then return false, "can't find user 2 chat directory" end

    -- create chat directories
    local status
    status = fs.createDirectory(user1ChatsPath.."/" .. username2)
    if status == false and not bypass then return false, "failed to create user1 chat directory" end
    status = fs.createDirectory(user2ChatsPath.."/" .. username1)
    if status == false and not bypass then return false, "failed to create user2 chat directory" end

    -- create chat message directories
    status = fs.createDirectory(user1ChatsPath.."/" .. username2 .. "/messages")
    if status == false and not bypass then return false, "failed to create user1 messages directory" end
    status = fs.createDirectory(user2ChatsPath.."/" .. username1 .. "/messages")
    if status == false and not bypass then return false, "failed to create user2 messages directory" end

    return true

end

function database:addStringMessage(sender, reciever, message)
    self.openUserChat(sender, reciever, true)
    local senderMessagePath = "users/"..sender.."/chats/"..reciever.."/messages"

    -- message is a table with the format
    -- type: string     type of the message (text|image)
    -- data: any        the message itself     

    if not fs.getInfo(senderMessagePath) then return false, "failed to get messages directory" end

    local messageID = math.floor((self.epochOffset + love.timer.getTime())*100)
    local messagePath = senderMessagePath.."/"..messageID

    -- error checking
    if type(message) ~= "string" then return false, "messsage is not a string" end
    if fs.getInfo(messagePath) then return false, "message with id already exists" end
    local status = fs.createDirectory(messagePath)
    if not status then return false, "failed to create message directory" end

    local messageData = {}
    messageData.type = "text"
    messageData.data = message
    local serializedMessageData = bitser.dumps(messageData)
    status = fs.write(messagePath.."/messageData", serializedMessageData)
    if not status then return false, "failed to write message data" end
    return true, tostring(messageID)
end

-- only used as a testing function, quick n' dirty approach
local function getLastMessage(username, username2)
    local messagePath = "users/"..username.."/chats/"..username2.."/messages"
    local messages = fs.getDirectoryItems(messagePath)
    local messagesTemp = {}
    for i,v in pairs(messages) do table.insert(messagesTemp, tonumber(v)) end
    table.sort(messagesTemp)
    local messageID = messagesTemp[1]
    local serializedMessage, err = fs.read(messagePath.."/"..messageID.."/".."messageData")

    local rawMessage = bitser.loads(serializedMessage)
    if not rawMessage then return end
    return(rawMessage.data)
end

database.createUserProfile("user1", "password", zen.b64decode("AAAAAAAAAAAAAAAAAAAAAA"))
database.createUserProfile("user2", "password1", zen.b64decode("AAAAAAAAAAAAAAAAAAAAAA"))

-- database location: ~/.local/share/love/LOVME_server
return database