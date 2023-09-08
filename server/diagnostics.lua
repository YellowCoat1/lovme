local bitser = require 'bitser' -- serialization
local sock = require 'sock' -- networking
local zen = require 'luazen' -- cryptography

local key_exchange_test, signature_test = true, true

--* also served well in testing how luazen worked

--* x25519 key_exchange test
local oSk = zen.randombytes(32)
local oPk = zen.x25519_public_key(oSk)
local tSk = zen.randombytes(32)
local tPk = zen.x25519_public_key(tSk)
local oKe = zen.key_exchange(oSk, tPk)
local tKe = zen.key_exchange(tSk, oPk)
if oKe ~= tKe then
    print "x25519 key exchange broke"
    key_exchange_test = false
end

--* ed25519 signature test
-- initial key and message
local edSk = zen.randombytes(32)
local edPk = zen.ed25519_public_key(edSk)
local message = "hey, you, you're finally awake. walked right into that imperial ambush, same as us, and that horse thief over there."

-- false negative test
local signedMessage = zen.ed25519_sign(edSk, edPk, message)
local isCorrect = zen.ed25519_check(signedMessage, edPk, message) -- checks if signed message is a signed verison of message
if not isCorrect then
    print "ed25519 signature false negative"
    signature_test = false
end

-- false positive test
local wrongSignedMessage = zen.ed25519_sign(edSk, edPk, message.."the spanish inquisition")
local isCorrect = zen.ed25519_check(wrongSignedMessage, edPk, message)
if isCorrect then
    print "ed25519 signature false positive"
    signature_test = false
end

if not key_exchange_test or not signature_test then
    print "tests failed"
    love.event.quit(1)
end