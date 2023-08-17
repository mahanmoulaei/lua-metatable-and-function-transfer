local api                         = {}
local internalApi                 = {}

internalApi.math                  = math
internalApi.debug                 = debug
internalApi.table                 = table
internalApi.string                = string
internalApi.handlerResource       = "x-test"
internalApi.currentResource       = GetCurrentResourceName()
internalApi.loadResourceFile      = LoadResourceFile
internalApi.saveResourceFile      = SaveResourceFile
internalApi.refreshHandlerExports = function()
    internalApi.exportsMetadata = exports[internalApi.handlerResource]
    return internalApi.exportsMetadata
end

do internalApi.refreshHandlerExports() end

---Splits a string content into a table based on the specified separator
---@param inputString string
---@param separator? string
---@return string[]
local function splitString(inputString, separator)
    local tbl, tblCount = {}, 0

    if type(separator) ~= "string" then separator = "%s" end

    for str in internalApi.string.gmatch(inputString, "([^" .. separator .. "]+)") do
        tblCount += 1
        tbl[tblCount] = str
    end

    return tbl
end

---Reloads the handler resource's exports metadata and caches it
---@param resource string
local function onResourceStart(resource)
    return resource == internalApi.handlerResource and internalApi.refreshHandlerExports()
end

AddEventHandler("onResourceStart", onResourceStart)
AddEventHandler("onServerResourceStart", onResourceStart)

---Writes the passed function's definition, parameters, and body into a file for usage in external resources (**removes the function reference**)
---@param func function
---@return string?
function api.writeFunction(func)
    if type(func) ~= "function" then return error("The passed parameter is not a function type!") end

    local info = internalApi.debug.getinfo(func, "Sn")
    local functionResource = internalApi.currentResource

    local sourcePath = info.source:sub(3) -- Remove the '@@' at the beginning
    local sourceFileContent = internalApi.loadResourceFile(functionResource, sourcePath:sub(#functionResource + 1))
    local sourceFileContentTable = splitString(sourceFileContent, "\n")

    local desiredFunctionContentTable, desiredFunctionContentTableCount = {}, 0

    local firstLine = sourceFileContentTable[info.linedefined]
    desiredFunctionContentTableCount += 1
    desiredFunctionContentTable[desiredFunctionContentTableCount] = ("function%s"):format(firstLine:match(".*(%b())"))

    for i = info.linedefined + 1, info.lastlinedefined do
        desiredFunctionContentTableCount += 1
        desiredFunctionContentTable[desiredFunctionContentTableCount] = sourceFileContentTable[i]
    end

    local desiredFunctionContent = internalApi.table.concat(desiredFunctionContentTable, "\n")
    local key = internalApi.exportsMetadata:generateKey()

    local fileName = ("func_%s"):format(key)
    local fullFileName = ("%s.lua"):format(fileName)
    local outputFileContents = internalApi.string.format([[
return {
    ["%s"] = %s
}
    ]], fileName, desiredFunctionContent)

    internalApi.saveResourceFile(internalApi.handlerResource, ("exports/%s"):format(fullFileName), outputFileContents, -1)

    return fullFileName
end

---Loads the function from the specified file
---@param fileName string
---@return function?
function api.loadFunction(fileName)
    local filePath = ("exports/%s"):format(fileName)
    local chunk = internalApi.loadResourceFile(internalApi.handlerResource, filePath)

    if not chunk then return error(("file %s doesn't exist!"):format(filePath)) end

    local fn, _ = load(chunk, ("@@%s/%s"):format(internalApi.handlerResource, filePath))

    if fn then return fn()?[fileName:sub(1, -5)] end

    error("Could not load function from " .. fileName)
end

---Writes the passed metatable's metamethods into a file for usage in external resources
---@param metatable table
---@return string?
function api.writeMetatable(metatable)
    if type(metatable) ~= "table" then return error("The passed parameter is not a table type!") end

    local serializedTable = "-- Metatable\n"

    for key, value in pairs(metatable) do
        if type(value) == "function" then
            local fileName = api.writeFunction(value)
            serializedTable = serializedTable .. internalApi.string.format("local __metamethod_%s = \"%s\"\n", key, fileName)
        end
    end

    serializedTable = serializedTable .. "return getmetatable(setmetatable({}, {\n"
    for key in pairs(metatable) do
        serializedTable = serializedTable .. internalApi.string.format("[\"%s\"] = __metamethod_%s,\n", key, key)
    end
    serializedTable = serializedTable .. "}))\n"

    local key = internalApi.exportsMetadata:generateKey()

    local fileName = ("meta_%s"):format(key)
    local fullFileName = ("%s.lua"):format(fileName)

    internalApi.saveResourceFile(internalApi.handlerResource, ("exports/%s"):format(fullFileName), serializedTable, -1)

    return fullFileName
end

---Loads the metatable from the specified file
---@param fileName string
---@return table?
function api.loadMetatable(fileName)
    local metatable = {}
    local filePath = ("exports/%s"):format(fileName)
    local chunk = internalApi.loadResourceFile(internalApi.handlerResource, filePath)

    if not chunk then return error(("file %s doesn't exist!"):format(filePath)) end

    local fn, err = load(chunk, ("@@%s/%s"):format(internalApi.handlerResource, filePath))

    if fn and not err then
        local savedTable = fn()

        for key, value in pairs(savedTable) do
            -- print(key, value)
            if key:find("__") then
                local _type = type(value)

                if _type == "string" and value:sub(-4) == ".lua" then
                    metatable[key] = api.loadFunction(value)
                elseif _type == "function" then
                    metatable[key] = value
                end

                if not metatable[key] then
                    error("Could not import " .. key .. " from " .. fileName)
                end
            end
        end
    end

    return metatable
end

local function modifyMt(mt)
    -- WORKING
    -- rawset(mt, "__index", function(t, k, ...)
    --     local funcRef = rawget(t, "__cfx_functionReference") and rawget(getmetatable(t), "__call")

    --     print("funcRef", funcRef)
    --     if funcRef then
    --         return t(mt, k, ...)
    --     end

    --     return error('Cannot index a funcref shakilaa', 2)
    -- end)

    local og_gc = rawget(mt, "__gc")
    local og_call = rawget(mt, "__call")
    local og_pack = rawget(mt, "__pack")
    local og_unpack = rawget(mt, "__unpack")

    for metaKey, metaValue in pairs(mt) do
        local _type = type(metaValue)
        -- print(metaKey, metaValue, _type)

        local funcRef


        --[[if _type == "table" and rawget(metaValue, "__cfx_functionReference") then
            funcRef = function(self, ...)
                return rawget(self, "__cfx_functionReference") and rawget(getmetatable(self), "__call")(self, ...)
            end
        else]]
        if _type == "function" then
            funcRef = true
        end

        if funcRef then
            rawset(mt, metaKey, function(self, ...)
                self(metaValue, ...)
            end)
        end
    end

    rawset(mt, "__gc", og_gc)
    rawset(mt, "__call", og_call)
    rawset(mt, "__pack", og_pack)
    rawset(mt, "__unpack", function(...)
        local tbl = og_unpack(...)
        -- rawset(tbl, "__obj_metatable", mt)
        return setmetatable(tbl, mt)
    end)


    return mt
end

local EXT_FUNCREF = 10
local EXT_LOCALFUNCREF = 11

local EXT_FUNCREF_MT = msgpack.extend_get(EXT_FUNCREF)
local EXT_LOCALFUNCREF_MT = msgpack.extend_get(EXT_LOCALFUNCREF)

---@diagnostic disable-next-line: param-type-mismatch
-- msgpack.extend_clear(EXT_FUNCREF, EXT_LOCALFUNCREF)

EXT_FUNCREF_MT = modifyMt(EXT_FUNCREF_MT)
EXT_LOCALFUNCREF_MT = modifyMt(EXT_LOCALFUNCREF_MT)

msgpack.extend(EXT_FUNCREF_MT)
msgpack.extend(EXT_LOCALFUNCREF_MT)

return api
