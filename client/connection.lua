local connection = {}

local sock = require 'sock'
local zen = require 'luazen'

local crypto = require 'crypto'

local SERVER_PORT = 22123

local sock_client = sock.newClient("localhost", SERVER_PORT)
local client_secret_key = zen.randombytes(32)
local client_public_key = zen.x25519_public_key(client_secret_key)
local database_public_keys = {}
sock_client:connect()

local USERNAME = ARGS[1]
local PASSWORD = ARGS[2]

local ARGON_KB = 5000
local ARGON_I = 15

local last_server_active = love.timer.getTime()

local function messageFromServer(data)
    last_server_active = love.timer.getTime()
    if data then
        local status, data = crypto.decrypt(data, sock_client.shared_key)
        if not status or not data then return false end
        return true, data
    end
end

local function sendToServer(message, sendData)
    messageFromServer()
    if not sock_client then print("sock_client not found\n") return false end
    if not sock_client.shared_key then print("shared key not found") return false end
    local sesh_id = sock_client.test_id
    if not sesh_id then print("SID not found") return false end
    local sendTable = {}
    sendTable.SID = sesh_id
    sendTable.data = {}
    local status
    status, sendTable.data = crypto.encrypt(sendData, sock_client.shared_key)
    if not status then return false end
    sock_client:send(message, sendTable)
    return true
end


sock_client:on("connect", function()
    messageFromServer()
    local sendTable = {}
    sendTable.upk = client_public_key
    sock_client:send("connected", sendTable)
end)

sock_client:on("key_response", function(data)
    messageFromServer()

    sock_client.test_id = data.sessionID
    sock_client.shared_key = zen.key_exchange(client_secret_key, data.spk)


    local sendTable = {}
    sendTable.user = USERNAME
    sendTable.pass = PASSWORD

    -- gen database keys
    local bytes16Salt = zen.b64decode("ABCDEFGHIJKLMNOPQRSTUV")
    sock_client.database_secret = zen.argon2i(sendTable.pass, bytes16Salt, ARGON_KB, ARGON_I)
    sock_client.database_public = zen.x25519_public_key(sock_client.database_secret)

    -- login


    local status = sendToServer("login", sendTable)
    if not status then print("server send failed") end
end)

sock_client:on("login-success", function(data)
    messageFromServer()
    data = crypto.decrypt(data)
    local sendTable = {}
    sendTable.requestedUsername = "user2"
    sendToServer("database_public_key_req", sendTable)
end)

sock_client:on("key_req_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, sock_client.shared_key)
    if not status or not data then print(data) return end
    database_public_keys["user2"] = data.returnKey

    local sendTable = {}
    sendTable.sender = "user1"
    sendTable.reciever = "user2"
    sendToServer("message_req", sendTable)


--     database_public_keys["user2"] = data.returnKey
--     local database_shared_key = zen.key_exchange(sock_client.database_secret, database_public_keys["user2"])
--     local sendTable = {}
--     sendTable.reciever =  "user2"
--     sendTable.nonce = zen.randombytes(24)
--     sendTable.message = {}
--     sendTable.message.type = "text"
--     sendTable.message.data = "hello there!"
--     sendTable.message = bitser.dumps(sendTable.message)
--     sendTable.message = zen.encrypt(database_shared_key, sendTable.nonce, sendTable.message)
--     sendToServer("message_send", sendTable)
end)

sock_client:on("message_response", function(data)
    messageFromServer()
    local status, data = crypto.decrypt(data, sock_client.shared_key)
    --if not status or not data then print(data) return end

    local database_shared_key = zen.key_exchange(sock_client.database_secret, database_public_keys["user2"])

    local EEE = bitser.loads(zen.decrypt(database_shared_key, data.nonce, data.data))

    print(EEE.data)

end)

sock_client:on("ping", function()
    messageFromServer()
    local sesh_id = sock_client.test_id
    sendToServer("pong", {})
end)

sock_client:on("pong", function()
    messageFromServer()
end)

-- for debugging
sock_client:on("usr_error", function(data)
    messageFromServer()
    local status, result = crypto.decrypt(data, sock_client.shared_key)
    if not status or not result then return end
    print("usr_error: ".. result[1])
end)


sock_client:on("usr_error_de", function(data)
    messageFromServer()
    print("usr_error_de: " .. data)
end)



function connection.update()
    sock_client:update()
    if last_server_active > love.timer.getTime() then
        sendToServer("ping", {})
    end
end

return connection