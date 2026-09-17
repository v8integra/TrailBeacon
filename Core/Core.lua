local ADDON_NAME, TB = ...

TB.DEFAULTS = {
    markers = {},
    settings = {
        minimap = {
            angle = 215,
        },
        arrow = {
            point = "CENTER",
            x = 0,
            y = 0,
            style = "Basic",
            color = { r = 1, g = 1, b = 1 },
            grayscale = false,
        },
        filters = {},
        autoShare = false,
    },
}

local function ApplyDefaults(defaults, target)
    target = target or {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = ApplyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

TB.readyCallbacks = {}

function TB:OnDBReady(callback)
    if TB.db then
        callback()
    else
        table.insert(TB.readyCallbacks, callback)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")

    TrailBeaconDB = ApplyDefaults(TB.DEFAULTS, TrailBeaconDB)
    TB.db = TrailBeaconDB

    for _, callback in ipairs(TB.readyCallbacks) do
        callback()
    end
    TB.readyCallbacks = {}
end)

_G[ADDON_NAME] = TB
