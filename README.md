# WIP
### libraries
[bitser,](https://github.com/gvx/bitser)  
[sock.lua,](https://github.com/camchenry/sock.lua)  
[classic,](https://github.com/rxi/classic)  
and [luazen](https://github.com/philanc/luazen)  

### info
a cool little incomplete messaging app made entirely in the game engine love2d. Why is it in love2d, a game making engine? because i started this when i was crazy for lua and there's no other lua application frameworks that do networking well.

so far ive done pretty much everything for the underlying encryption, server structure, and the actual messaging. now for the hardest part: UI. (PLEASE never make me program a text box again i spent 4 hours programming the cursor to go up and down from scratch. it turned out good but AAAAAAA)

everything sent through it absolutely can not be read by whoever owns the server. i don't mean like "oh i scrambled the storage with a hardcoded key thats easy to get if you somewhat know lua" i mean it's full actual end to end encryption.

also added an initial key exchange and general transmission encryption. enet probably already does this but why not.

### to compile
go figure out [how to use love2d](https://love2d.org/wiki/Getting_Started) first. the server and client folders are both love projects

#### completed parts
- message database
- full database encrpytion
- transmission encription
- pretty much everything server-side

#### uncompleted parts
- client side message & card display
- server card storage
- pretty much most of the client side ui
