-- SOLELY FOR TESTING
---@diagnostic disable: unbalanced-assignments

local meta = {
    __index = function(s, index)
        print("__index", GetCurrentResourceName(), GetInvokingResource(), index)

        return index == "sayMyName" and "Mahan" or rawget(s, index)
    end,
    __newindex = function(self, index, value)
        print("__newindex", GetCurrentResourceName(), GetInvokingResource(), index, value)

        local _type = type(value)

        if _type == "function" or (_type == "table" and value?.__cfx_functionReference) then
            return rawset(self, index, value)
        end

        return print(("__newindex on (%s %s=%s) is triggered but won't affect anything"):format(self, index, value))
    end,
}

CreateThread(function()
    local apiFileName = "api.lua"
    local currentResource = GetCurrentResourceName()
    local apiContent = LoadResourceFile(currentResource, apiFileName)
    local apiChunk, err = apiContent and load(apiContent, ("@@%s/%s"):format(currentResource, apiFileName))
    local api = apiChunk and not err and apiChunk()

    if not api then return error(("Could not load %s/%s"):format(currentResource, apiFileName)) end



    local obj = setmetatable({}, meta)
    local fileName = api.writeMetatable(getmetatable(obj))

    local meta2 = api.loadMetatable(fileName)
    local obj2 = setmetatable({
        uid = 1,
        getUid = function(self)
            -- print("getUid", self, GetCurrentResourceName(), GetInvokingResource())
            return self.uid
        end,
    }, meta)

    function obj2:setUid(index)
        self = setmetatable(self, getmetatable(self))
        -- print(ESX.DumpTable(self))
        print("setUid", self, index, GetCurrentResourceName(), GetInvokingResource())
        self.uid = index
        -- print(json.encode(self, { indent = true }))
    end

    -- print(obj.sayMyName)  -- prints Mahan
    print(obj2.sayMyName) -- prints Mahan

    obj2.kaftar = "25M"   -- prints the meta.__newindex's content

    exports("getObj2", function()
        local alal = setmetatable(obj2, meta2)
        for key, func in pairs(getmetatable(alal)) do
            alal[key] = func
        end

        return obj2, getmetatable(obj2), alal
    end)
end)

exports("getMt", function()
    return meta
end)
