local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

local user = require 'user'

-- generate keys 
LOVME.dh_sk = zen.randombytes(32)
LOVME.dh_pk = zen.x25519_public_key(LOVME.dh_sk)


function LOVME.shared_key(tPk)
    return zen.key_exchange(LOVME.dh_sk, tPk)
end


LOVME.lovmServer:on("dh_key_exchange", key_request) -- diffie hellman key exchange
