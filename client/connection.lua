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


local function sendToServer(message, sendData)
    if not sock_client then print("sock_client not found") return false end
    local sesh_id = sock_client.test_id
    if not sesh_id then print("SID not found") return false end
    local sendTable = {}
    sendTable.SID = sesh_id
    sendTable.data = {}
    _, sendTable.data = crypto.encrypt(sendData, sock_client.shared_key)
    sock_client:send(message, sendData)
end


sock_client:on("connect", function()
    local sendTable = {}
    sendTable.upk = client_public_key
    sock_client:send("connected", sendTable)
end)

sock_client:on("key_response", function(data)

    sock_client.test_id = data.sessionID
    sock_client.shared_key = zen.key_exchange(client_secret_key, data.spk)

    -- gen database keys
    local bytes16Salt = zen.b64decode("ABCDEFGHIJKLMNOPQRSTUV")
    sock_client.database_secret = zen.argon2i(sendTable.data.pass, bytes16Salt, 200, 15)
    sock_client.database_public = zen.x25519_public_key(sock_client.database_secret)

    -- login
    local sendTable = {}
    sendTable.user = "user1"
    sendTable.pass = "password"


    local status = sendToServer("login", sendTable)
    if not status then print("server send failed") end
end)

sock_client:on("login-success", function(data)
    data = crypto.decrypt(data)
    local sendTable = {}
    sendTable.SID = sock_client.test_id
    sendTable.data = {}
    sendTable.data.requestedUsername = "user2"
    _, sendTable.data = crypto.encrypt(sendTable.data, sock_client.shared_key)
    sock_client:send("database_public_key_req", sendTable)
end)

sock_client:on("key_req_response", function(data)
    local status, data = crypto.decrypt(data, sock_client.shared_key)
    database_public_keys["user2"] = data.returnKey
end)


sock_client:on("ping", function()
    local sendTable = {}
    local sesh_id = sock_client.test_id
    sendTable.SID = sesh_id
    sendTable.data = {}
    _, sendTable.data = crypto.encrypt(sendTable.data, sock_client.shared_key)
    sock_client:send("pong", sendTable)
end)

-- for debugging
sock_client:on("usr_error", function(data)
    local status, result = crypto.decrypt(data, sock_client.shared_key)
    if not result then return end
    print(result[1])
end)

function connection.update()
    sock_client:update()
end

return connection