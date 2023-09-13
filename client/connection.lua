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



sock_client:on("connect", function()
    local sendTable = {}
    sendTable.upk = client_public_key
    sock_client:send("connected", sendTable)
end)

sock_client:on("key_response", function(data)
    sock_client.test_id = data.sessionID
    sock_client.shared_key = zen.key_exchange(client_secret_key, data.spk)

    -- login
    local sendTable = {}
    sendTable.SID = sock_client.test_id
    sendTable.data = {}
    sendTable.data.user = "user1"
    sendTable.data.pass = "password"

    local bytes16Salt = zen.b64decode("ABCDEFGHIJKLMNOPQRSTUV")
    sock_client.database_secret = zen.argon2i(sendTable.data.pass, bytes16Salt, 200, 15)
    sock_client.database_public = zen.x25519_public_key(sock_client.database_secret)

    _, sendTable.data = crypto.encrypt(sendTable.data, sock_client.shared_key)
    sock_client:send("login", sendTable)
end)

sock_client:on("login-success", function(data)
    local sendTable = {}
    sendTable.SID = sock_client.test_id
    sendTable.data = {}
    sendTable.data.requestedUsername = "user2"
    _, sendTable.data = crypto.encrypt(sendTable.data, sock_client.shared_key)
    sock_client:send("database_public_key_req", sendTable)
end)

sock_client:on("key_req_response", function(data)
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
    local status, data = crypto.decrypt(data, sock_client.shared_key)
    if not data then return end
    print(data[1])
end)

function connection.update()
    sock_client:update()
end

return connection