local crypto = {}

-- local bitser = require 'bitser' -- serialization
-- local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

-- local user = require 'user' -- user class

-- generate keys 
crypto.dh_sk = zen.randombytes(32)
crypto.dh_pk = zen.x25519_public_key(crypto.dh_sk)

function crypto:regen_keys()
    self.dh_sk = zen.randombytes(32)
    self.dh_pk = zen.x25519_public_key(crypto.dh_sk)
end

function crypto:shared_key(tPk)
    return zen.key_exchange(self.dh_sk, tPk)
end

return crypto