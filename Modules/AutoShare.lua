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

-- SendAddonMessage returns a SendAddonMessageResult (Success = 0), per
-- ChatConstantsDocumentation.lua. Without checking it, a failed share looked
-- identical to a successful one from the sender's side.
local SEND_SUCCESS = 0
local SEND_FAILURE_REASONS = {
    [3] = "sending too fast, try again in a moment",
    [5] = "you're not in a group that supports this",
    [8] = "sending too fast, try again in a moment",
    [11] = "addon messaging is locked down right now (combat or an instance)",
}

function TB:BroadcastMarker(marker)
    if not TB.db.settings.autoShare then return end
    local channel = GetShareChannel()
    if not channel then return end
    local payload = TB:ExportMarkers({ marker })
    local result = C_ChatInfo.SendAddonMessage(ADDON_PREFIX, payload, channel)
    if type(result) == "number" and result ~= SEND_SUCCESS then
        local reason = SEND_FAILURE_REASONS[result] or ("error code " .. result)
        print("|cff33ff99TrailBeacon|r: couldn't share that marker with your group (" .. reason .. ").")
    end
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
