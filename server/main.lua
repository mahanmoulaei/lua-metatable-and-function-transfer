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
