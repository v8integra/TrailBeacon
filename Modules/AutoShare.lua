local ADDON_NAME, TB = ...

local ADDON_PREFIX = "TrailBeacon"

C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

local function GetShareChannel()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return nil
end

function TB:BroadcastMarker(marker)
    if not TB.db.settings.autoShare then return end
    local channel = GetShareChannel()
    if not channel then return end
    local payload = TB:ExportMarkers({ marker })
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, payload, channel)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end
    if sender == UnitName("player") then return end

    local markers = TB:DecodeExportString(message)
    if #markers == 0 then return end

    for _, marker in ipairs(markers) do
        TB:AddImportedMarker(marker)
    end
    print(string.format("|cff33ff99TrailBeacon|r: received %d marker(s) from %s.", #markers, sender))
end)
