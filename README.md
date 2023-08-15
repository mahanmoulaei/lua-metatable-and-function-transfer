# lua-metatable-and-function-transfer

Writes functions and metatables in a file so an external resource could read/use them.

Still very janky, but hey it's a basic working solution in FiveM to bypass the `msgpack` limitation of transferring Lua's metadata.

Also, it can be used to transfer actual functions(not function reference) to another resource and make use of it! Useful in cases when the function is being repeatedly used so having it as a function reference is more expensive to call...

See https://gist.github.com/mahanmoulaei/e4165ff8218c483990508c775d4fc9e7

For an example, you can head over to [`server/example.lua`](https://github.com/mahanmoulaei/lua-metatable-and-function-transfer/blob/main/server/example.lua)
