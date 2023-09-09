local crypto = {}

local bitser = require 'bitser' -- serialization
-- local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

-- local user = require 'user' -- user class


crypto.emptyNonce = zen.b64decode("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")

-- key generation
function crypto:gen_keys()
    local dh_sk = zen.randombytes(32)
    local dh_pk = zen.x25519_public_key(crypto.dh_sk)
    return dh_sk, dh_pk
end


function crypto:encrypt(data, key)
    data = bitser.dumps(data) -- serialize 
    data = zen.encrypt(key, self.emptyNonce, data) -- encrypt
    data = zen.lzma(data) -- compress
    return data
end

-- TODO
function crypto:decrypt(data, key)
    data = zen.unlzma(data)
    data = zen.decrpyt(key, self.emptyNonce, data)
    data = bitser.loads(data)
    return data
end

function crypto:shared_key(tPk)
    return zen.key_exchange(self.dh_sk, tPk)
end

return crypto