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

---Writes the passed metatable's metamethods into a file for usage in external resources
---@param metatable table
---@return string?
function api.writeMetatable(metatable)
    if type(metatable) ~= "table" then return error("The passed parameter is not a table type!") end

    local serializedTable = "-- Metatable\n"

    for key, value in pairs(metatable) do
        if type(value) == "function" then
            local fileName = api.writeFunction(value)
            serializedTable = serializedTable .. internalApi.string.format("local __metamethod_%s = LoadResourceFile(\"x-test\", \"%s\")\n", key, ("exports/%s"):format(fileName))
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

    return metatable
end

return api
