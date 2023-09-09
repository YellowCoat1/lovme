local crypto = {}

local bitser = require 'bitser' -- serialization
-- local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

-- local user = require 'user' -- user class

-- key generation
function crypto.gen_keys()
    local dh_sk = zen.randombytes(32)
    local dh_pk = zen.x25519_public_key(crypto.dh_sk)
    return dh_sk, dh_pk
end


function crypto.encrypt(data, key)
    local emptyNonce = zen.b64decode("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    data = bitser.dumps(data) -- serialize 
    data = zen.encrypt(key, emptyNonce, data) -- encrypt
    data = zen.lzma(data) -- compress
    return data
end

-- TODO
function crypto.decrypt(data, key)
    local emptyNonce = zen.b64decode("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    data = zen.unlzma(data)
    data = zen.decrpyt(key, emptyNonce, data)
    data = bitser.loads(data)
    return data
end

function crypto.shared_key(oSk, tPk)
    -- print(self, tPk)
    return zen.key_exchange(oSk, tPk)
    -- return 3
end

return crypto