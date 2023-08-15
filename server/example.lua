-- SOLELY FOR TESTING
---@diagnostic disable: unbalanced-assignments

CreateThread(function()
    local apiFileName = "api.lua"
    local currentResource = GetCurrentResourceName()
    local apiContent = LoadResourceFile(currentResource, apiFileName)
    local apiChunk, err = apiContent and load(apiContent, ("@@%s/%s"):format(currentResource, apiFileName))
    local api = apiChunk and not err and apiChunk()

    if not api then return error(("Could not load %s/%s"):format(currentResource, apiFileName)) end

    local meta = {
        __index = function(_, index)
            return index == "sayMyName" and "Mahan"
        end,
        __newindex = function(self, index, value)
            print(("__newindex on (%s %s=%s) is triggered but won't affect anything"):format(self, index, value))
            return
        end,
    }

    local obj = setmetatable({}, meta)
    local fileName = api.writeMetatable(getmetatable(obj))

    local meta2 = api.loadMetatable(fileName)
    local obj2 = setmetatable({}, meta2)

    print(obj.sayMyName)  -- prints Mahan
    print(obj2.sayMyName) -- prints Mahan

    obj2.kaftar = "25M"   -- prints the meta.__newindex's content
end)
