local ADDON_NAME, TB = ...

-- Media/Arrows/*.tga are square (content centered, transparent-padded to
-- match width/height), so no aspect ratio bookkeeping is needed here.
TB.ARROW_STYLES = {
    { key = "Basic", label = "Basic", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\BasicArrow.tga" },
    { key = "Dwarf", label = "Dwarf", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\DwarfArrow.tga" },
    { key = "Elf", label = "Elf", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\ElfArrow.tga" },
    { key = "Gnome", label = "Gnome", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\GnomeArrow.tga" },
    { key = "Goblin", label = "Goblin", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\GoblinArrow.tga" },
    { key = "Orc", label = "Orc", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\OrcArrow.tga" },
    { key = "Troll", label = "Troll", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\TrollArrow.tga" },
}

function TB:GetArrowStyleInfo(key)
    for _, info in ipairs(TB.ARROW_STYLES) do
        if info.key == key then
            return info
        end
    end
    return TB.ARROW_STYLES[1]
end

local ARROW_HEIGHT = 48
local UPDATE_INTERVAL = 0.2

-- WoW's world-position convention (as returned by C_Map.GetWorldPosFromMapPos)
-- has +X = south and +Y = west. GetPlayerFacing() is a compass bearing in
-- radians (0 = north, increasing clockwise toward east). Both of those are
-- best-effort from documentation/convention, not verified against a running
-- client. If the arrow spins the wrong way or sits rotated by a fixed amount
-- once tested in-game, adjust ROTATION_SIGN (flip to -1) and/or
-- ROTATION_OFFSET (radians) below rather than reworking the bearing math.
local ROTATION_SIGN = 1
local ROTATION_OFFSET = 0

local arrow = CreateFrame("Button", "TrailBeaconTrackingArrow", UIParent)
arrow:SetSize(ARROW_HEIGHT, ARROW_HEIGHT)
arrow:SetMovable(true)
arrow:EnableMouse(true)
arrow:SetClampedToScreen(true)
arrow:RegisterForDrag("LeftButton")
arrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
arrow:Hide()

local texture = arrow:CreateTexture(nil, "ARTWORK")
texture:SetPoint("CENTER")
arrow.texture = texture

local distanceText = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
distanceText:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
arrow.distanceText = distanceText

arrow:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

arrow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    TB.db.settings.arrow.point = point
    TB.db.settings.arrow.x = x
    TB.db.settings.arrow.y = y
end)

arrow:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" and IsShiftKeyDown() then
        TB:ToggleArrowOptions()
    end
end)

local function ApplyStyle()
    local style = TB:GetArrowStyleInfo(TB.db.settings.arrow.style)
    local color = TB.db.settings.arrow.color
    texture:SetTexture(style.file)
    texture:SetSize(ARROW_HEIGHT, ARROW_HEIGHT)
    texture:SetVertexColor(color.r, color.g, color.b)
    texture:SetDesaturated(TB.db.settings.arrow.grayscale)
end
TB.ApplyArrowStyle = ApplyStyle

local function UpdateArrow()
    if IsInInstance() then
        arrow:Hide()
        return
    end

    local marker = TB:GetTrackedMarker()
    if not marker then
        arrow:Hide()
        return
    end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then
        arrow:Hide()
        return
    end

    if not arrow:IsShown() then
        arrow:Show()
    end

    if marker.mapID ~= playerMapID then
        texture:SetDesaturated(true)
        texture:SetRotation(0)
        distanceText:SetText("Different Zone")
        return
    end

    local playerMapPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerMapPos then
        return
    end

    local _, playerWorldPos = C_Map.GetWorldPosFromMapPos(playerMapID, playerMapPos)
    local _, markerWorldPos = C_Map.GetWorldPosFromMapPos(marker.mapID, CreateVector2D(marker.x, marker.y))
    if not playerWorldPos or not markerWorldPos then
        return
    end

    local dx = markerWorldPos.x - playerWorldPos.x
    local dy = markerWorldPos.y - playerWorldPos.y
    local distance = math.sqrt(dx * dx + dy * dy)

    local northComponent = -dx
    local eastComponent = -dy
    local bearing = math.atan2(eastComponent, northComponent)
    local facing = GetPlayerFacing() or 0
    local relative = ROTATION_SIGN * (bearing - facing) + ROTATION_OFFSET

    texture:SetDesaturated(TB.db.settings.arrow.grayscale)
    texture:SetRotation(relative)
    distanceText:SetFormattedText("%.0f", distance)
end

local driver = CreateFrame("Frame")
local elapsedAcc = 0

TB:OnDBReady(function()
    local s = TB.db.settings.arrow
    arrow:ClearAllPoints()
    arrow:SetPoint(s.point or "CENTER", UIParent, s.point or "CENTER", s.x or 0, s.y or 0)
    ApplyStyle()

    driver:SetScript("OnUpdate", function(self, elapsed)
        elapsedAcc = elapsedAcc + elapsed
        if elapsedAcc < UPDATE_INTERVAL then return end
        elapsedAcc = 0
        UpdateArrow()
    end)
end)

TB.trackingArrow = arrow
