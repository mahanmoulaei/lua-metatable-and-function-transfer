local generatedKeys = {}
local action = setmetatable({}, {
    __newindex = function(self, index, value)
        rawset(self, index, value)
        return exports(index, value)
    end
})

local mathLibrary = math
local stringLibrary = string

---@return string
function action:generateKey()
    local key = ""

    repeat
        key = key .. stringLibrary.char(mathLibrary.random(65, 90))
    until #key == 5

    if generatedKeys[key] then
        return self:generateKey()
    end

    generatedKeys[key] = true

    return key
end

--[[
local function loadFunction(fileName)
    local filePath = ("exports/%s"):format(fileName)
    local chunk = LoadResourceFile(GetCurrentResourceName(), filePath)

    if not chunk then return error(("file %s doesn't exist!"):format(filePath)) end

    local fn, _ = load(chunk, ('@@%s/%s'):format(GetCurrentResourceName(), filePath))

    if fn then return fn()?[fileName:sub(1, -5)] end

    error("Could not load function from " .. fileName)
end
exports("loadFunction", loadFunction)
]]

-- Defining the function to be passed
-- local function sum(x, y)
--     return x + y
-- end

-- Calling the write function to save the passed function to a lua file
-- do writeFunction(sum) end

----------------------------------------------------------------------------------------------------------------------------

local meta = {
    __index = function(_, index)
        print("__index", index, value)
        return index == "sayMyName" and "Mahan"
    end,
    __newindex = function(self, index, value)
        print(("__newindex on (%s %s=%s) is triggered but won't affect anything"):format(self, index, value))
        return
    end,
}

CreateThread(function()
    local api = lib.require("server.api")

    local obj = setmetatable({}, meta)
    local fileName = api.writeMetatable(getmetatable(obj))

    local meta2 = api.loadMetatable(fileName)
    local obj2 = setmetatable({}, meta2)

    print(obj.sayMyName)  -- prints Mahan
    print(obj2.sayMyName) -- prints Mahan

    obj2.kaftar = "25M"   -- prints the meta.__newindex's content
end)
