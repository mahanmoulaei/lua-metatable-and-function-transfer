local function stringsplit(inputString, separator)
    if not separator then
        separator = "%s"
    end
    local t, i = {}, 1
    for str in string.gmatch(inputString, "([^" .. separator .. "]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

-- Defining a function to write the passed function's definition, parameters, and body into a file (**removes the function reference**)
local function writeFunction(func)
    local info = debug.getinfo(func, "Sn")
    local functionResource = GetCurrentResourceName()

    local sourcePath = info.source:sub(3) -- Remove the '@@' at the beginning
    local sourceFileContent = LoadResourceFile(functionResource, sourcePath:sub(#functionResource + 1))
    local sourceFileContentTable = stringsplit(sourceFileContent, "\n")

    local desiredFunctionContentTable, desiredFunctionContentTableCount = {}, 0

    local firstLine = sourceFileContentTable[info.linedefined]
    desiredFunctionContentTableCount += 1
    desiredFunctionContentTable[desiredFunctionContentTableCount] = ("function%s"):format(firstLine:match(".*(%b())"))

    for i = info.linedefined + 1, info.lastlinedefined do
        desiredFunctionContentTableCount += 1
        desiredFunctionContentTable[desiredFunctionContentTableCount] = sourceFileContentTable[i]
    end

    local desiredFunctionContent = table.concat(desiredFunctionContentTable, "\n")
    local key = ""

    repeat
        key = key .. string.char(math.random(65, 90))
    until key and #key == 5

    local fileName = ("func_%s.lua"):format(key)
    local outputFileContents = string.format([[
return {
    ["%s"] = %s
}
    ]], fileName:sub(1, -5), desiredFunctionContent)

    SaveResourceFile(functionResource, ("exports/%s"):format(fileName), outputFileContents, -1) -- Use your environment's file saving function

    return fileName
end

local function loadFunction(fileName)
    local filePath = ("exports/%s"):format(fileName)
    local chunk = LoadResourceFile(GetCurrentResourceName(), filePath)

    if not chunk then return error(("file %s doesn't exist!"):format(filePath)) end

    local fn, _ = load(chunk, ('@@%s/%s'):format(GetCurrentResourceName(), filePath))

    if fn then return fn()?[fileName:sub(1, -5)] end

    error("Could not load function from " .. fileName)
end
exports("loadFunction", loadFunction)

-- Defining the function to be passed
local function sum(x, y)
    return x + y
end

-- Calling the write function to save the passed function to a lua file
-- do writeFunction(sum) end

----------------------------------------------------------------------------------------------------------------------------

-- Defining a function to write the passed metatable into a file
local function writeMetatable(metatable)
    local serializedTable = ""

    serializedTable = serializedTable .. "-- Metamethods\n"
    for key, value in pairs(metatable) do
        if type(value) == "function" then
            local fileName = writeFunction(value)
            serializedTable = serializedTable .. string.format('local __metamethod_%s = LoadResourceFile("x-test", "%s")\n', key, ("exports/%s"):format(fileName))
        end
    end

    serializedTable = serializedTable .. 'return getmetatable(setmetatable({}, {\n'
    for key, _ in pairs(metatable) do
        serializedTable = serializedTable .. string.format('["%s"] = __metamethod_%s,\n', key, key)
    end
    serializedTable = serializedTable .. string.format('["mahanIndex"] = "mahanValue",\n')
    serializedTable = serializedTable .. '}))\n'

    local key = ""

    repeat
        key = key .. string.char(math.random(65, 90))
    until key and #key == 5

    local fileName = ("meta_%s.lua"):format(key)

    SaveResourceFile(GetCurrentResourceName(), ("exports/%s"):format(fileName), serializedTable, -1) -- Use your environment's file saving function

    return fileName
end

local function loadMetatable(fileName)
    local metatable = {}
    local filePath = ("exports/%s"):format(fileName)
    local chunk = LoadResourceFile(GetCurrentResourceName(), filePath)

    if not chunk then return error(("file %s doesn't exist!"):format(filePath)) end

    local fn, err = load(chunk, ('@@%s/%s'):format(GetCurrentResourceName(), filePath))

    if fn and not err then
        local savedTable = fn()

        for key, value in pairs(savedTable) do
            -- print(key, value)
            if key:find("__") then
                local _type = type(value)

                if _type == "string" then
                    local _fn, _err = load(value)

                    if _fn and not _err then
                        local mt = _fn()
                        local _, func = next(mt)
                        metatable[key] = func
                    end
                elseif _type == "function" then
                    metatable[key] = value
                elseif _type == "table" then
                    local mt = getmetatable(value)
                    mt.__index = nil
                    mt.__newindex = nil
                    metatable[key] = setmetatable(value, mt)
                end

                if not metatable[key] then
                    error("Could not import " .. key .. " from " .. fileName)
                end
            end
        end
    end

    -- print(ESX.DumpTable(metatable))

    return metatable
end

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
    local obj = setmetatable({}, meta)
    local fileName = writeMetatable(getmetatable(obj))

    local meta2 = loadMetatable(fileName)
    local obj2 = setmetatable({}, meta2)

    print(obj.sayMyName)  -- prints Mahan
    print(obj2.sayMyName) -- prints Mahan

    obj2.kaftar = "25M"

    print(ESX.DumpTable(obj2))

    -- loadMetatable("meta_LHNQX.lua")
end)
