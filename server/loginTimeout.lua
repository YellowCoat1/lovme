-- stores a timeout of login or register attempts per ip
local loginTimeout = {}

local IPs = {}

local function createIpProfile(ip)
    IPs[ip] = {}
    local ipEntry = IPs[ip]
    ipEntry.loginAttempts = {}
    ipEntry.registerAttempts = {}
end

function loginTimeout.registerAttempt(client)
    local ip = client:getAddress()
    print(ip)
end

return loginTimeout