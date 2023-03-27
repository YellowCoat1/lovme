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

local ARGON_KB = 5000
local ARGON_I = 15


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

--[[
    The following fields are in every userdata:
        passHash: the hashed version of the password to be checked against.
        salt: salt for the hashed pass, so same passwords don't have the same hash.
        databasePublicKey: The database public key, used for a database key exchange, for individual message encryption
        databaseSalt: The salt for the database public key
--]]

-- create a profile for a user in the database
function database.createUserProfile(username, pass, databaseSalt, database_public)
    if not username then return false, "absent username" end
    if not pass then return false, "absent password" end
    
    -- username and password should be correct
    if not test_username(username) then return false, "invalid username" end
    if not test_username(pass) then return false, "invalid password" end

    -- gen salt and hashed pass
    local salt = zen.randombytes(16)
    local hashed_pass = zen.argon2i(pass, salt, ARGON_KB, ARGON_I)
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
    saveTable.DatabaseSalt = databaseSalt
    saveTable.DatabasePublicKey = databasePublicKey

    local savedUserData = bitser.dumps(saveTable)
    local status, err = fs.write(userpath.."/userdata", savedUserData)
    if not status then io.write(err..'\n') return false, "failed to write user object" end

    local returnTable = {}
    returnTable.pk = databasePublicKey

    return true, returnTable
end

-- same as rm -r 
local function recursiveRemove(path, dontRemoveRoot)
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

    if not dontRemoveRoot then
        return fs.remove(path)
    else
        return true
    end
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

function database.getDatabaseSalt(username)
    local userpath = "users/"..username
    if not fs.getInfo(userpath.."/userdata") then return false, "failed to load user data" end
    local rawUserData = fs.read(userpath.."/userdata")
    if not rawUserData then return false, "failed to read userdata" end
    local status, result = pcall( function() return bitser.loads(rawUserData) end)
    if status == false or not result then
        return false, "deserialization fail"
    end
    local salt = result.DatabaseSalt
    if not salt then
        return false, "no salt found"
    end
    
    return true, salt
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
    local hashed_pass = zen.argon2i(pass, salt, ARGON_KB, ARGON_I)
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

function database:addMessage(sender, reciever, message, nonce)
    self.openUserChat(sender, reciever, true)
    local senderMessagePath = "users/"..sender.."/chats/"..reciever.."/messages"

    -- message is a table with the format
    -- type: string     type of the message (text|image)
    -- data: any        the message itself     

    if not fs.getInfo(senderMessagePath) then return false, "failed to get messages directory." end

    -- generate id of message
    local messageID = math.floor((self.epochOffset + love.timer.getTime())*100) --ms since epoch
    local messagePath = senderMessagePath.."/"..messageID

    -- error checking
    if fs.getInfo(messagePath) then return false, "message with id already exists" end

    -- generate directory
    local status = fs.createDirectory(messagePath)
    if not status then return false, "failed to create message directory" end

    -- set data
    local messageData = {}
    messageData.nonce = nonce
    messageData.type = "text"
    messageData.data = message
    
    local serializedMessageData = bitser.dumps(messageData)
    status = fs.write(messagePath.."/messageData", serializedMessageData)
    if not status then return false, "failed to write message data" end
    return true, tostring(messageID)
end

database.getMessage = {}

function database.getMessage:Last(sender, reciever, both)
    local senderPath = "users/"..sender.."/"
    local senderMessagePath = senderPath .."chats/"..reciever.."/messages/"

    if not fs.getInfo(senderPath) then return false, "failed to get sender user directory" end 
    if not fs.getInfo(senderMessagePath) then return false, "failed to get sender messages directory" end


    if both then
        local recieverPath = "users/".. reciever .."/"
        local recieverMessagePath = recieverPath .."chats/"..sender.."/messages/"

        if not fs.getInfo(recieverPath) then return false, "failed to get reciever user directory" end 
        if not fs.getInfo(recieverMessagePath) then return false, "failed to get reciever messages directory" end


        local senderMessages = fs.getDirectoryItems(senderMessagePath)
        local recieverMessages = fs.getDirectoryItems(recieverMessagePath)

        if not senderMessages or not recieverMessages then return false, "messages dir not found" end

        --checks for empty directories
        if #recieverMessages == 0 then
            if #senderMessages == 0 then
                return false, "no last message"
            else
                return self:Last(sender, reciever)
            end
        elseif #senderMessages == 0 then
            return self:Last(reciever, sender)
        end



        -- set lastSenderMessage to the largest number in senderMessages
        local lastSenderMessage = tonumber(senderMessages[1])
        for i,v in pairs(senderMessages) do
            local messageTime = tonumber(v)
            if lastSenderMessage < messageTime then
                lastSenderMessage = messageTime
            end
        end

        -- set lastRecieverMessage to the largest number in recieverMessages
        local lastRecieverMessage = tonumber(recieverMessages[1])
        for i,v in pairs(recieverMessages) do
            local messageTime = tonumber(v)
            if lastRecieverMessage < messageTime then
                lastRecieverMessage = messageTime
            end
        end

        if lastRecieverMessage > lastSenderMessage then
            return self.fromID(reciever, sender, lastRecieverMessage)
        else
            return self.fromID(sender, reciever, lastSenderMessage)
        end

    else

        local senderMessages = fs.getDirectoryItems(senderMessagePath)

        if not senderMessages then return false, "messages dir not found" end
        if #senderMessages == 0 then return false, "no messages found" end

        -- set lastSenderMessage to the largest number in senderMessages
        local lastSenderMessage = tonumber(senderMessages[1])
        for i,v in pairs(senderMessages) do
            local messageTime = tonumber(v)
            if lastSenderMessage < messageTime then
                lastSenderMessage = messageTime
            end
        end

        return self.fromID(sender, reciever, lastSenderMessage)

    end

end

function database.getMessage:next(sender, reciever, messageID, before, both)

    -- paths and checks
    local senderPath = "users/"..sender.."/"
    local senderMessagePath = senderPath .."chats/"..reciever.."/messages/"
    if not fs.getInfo(senderPath) then return false, "failed to get sender user directory" end 

    if not fs.getInfo(senderMessagePath) then return false, "failed to get sender messages directory" end
    
    local messagePath = senderMessagePath .. messageID
    if not fs.getInfo(messagePath) then return false, "failed to get message path" end 

    messageID = tonumber(messageID)
    local foundMessage
    local foundMessageSource

    -- find next message in sender message dir
    local message
    local senderMessageList = fs.getDirectoryItems(senderMessagePath)
    for i,v in pairs(senderMessageList) do
        message = tonumber(v)
        if (message > messageID and not before) or (message < messageID and before) then
            foundMessage = message
            foundMessageSource = "sender"
            break
        end
    end


    -- if we're checking both, check the next dir too.
    if both then


        -- paths and checks for reciever
        local recieverPath = "users/"..reciever.."/"
        local recieverMessagePath = recieverPath .."chats/"..sender.."/messages/"
        if not fs.getInfo(recieverPath) then return false, "failed to get sender user directory" end 
        if not fs.getInfo(recieverMessagePath) then return false, "failed to get sender messages directory" end


        local recieverMessageList = fs.getDirectoryItems(recieverMessagePath)
        for i,v in pairs(recieverMessageList) do
            message = tonumber(v)
            if (message > messageID and not before) or (message < messageID and before) then
                if (foundMessage < message and not before) or (message > messageID and before) then
                    foundMessage = message
                    foundMessageSource = "reciever"
                end
                break
            end
        end
    end

    if foundMessage then
        if foundMessageSource == "sender" then
            return self.fromID(sender, reciever, foundMessage)
        elseif foundMessageSource == "Reciever" then
            return self.fromID(reciever, sender, foundMessage)
        else
            return false
        end
    else
        return false
    end
end

function database.getMessage.fromID(sender, reciever, messageID, both)
    local messagePath = "users/"..sender .. "/chats/" .. reciever .. "/messages/"..messageID.."/messageData"
    if not fs.getInfo(messagePath) then return false, "could not find message path" end
    local serializedMessage = fs.read(messagePath)
    local message = bitser.loads(serializedMessage)
    local returnTable = {}
    returnTable.message = message
    returnTable.sender = sender
    return returnTable
end

-- database location: ~/.local/share/love/LOVME_server
return database