local ADDON_NAME, TB = ...

-- Media/Arrows/*.tga are square (content centered, transparent-padded to
-- match width/height), so no aspect ratio bookkeeping is needed here.
TB.ARROW_STYLES = {
    { key = "Basic", label = "Basic", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\BasicArrow.tga" },
    { key = "Dragon", label = "Dragon", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\DragonArrow.tga" },
    { key = "Gold", label = "Gold", file = "Interface\\AddOns\\TrailBeacon\\Media\\Arrows\\GoldArrow.tga" },
}

function TB:GetArrowStyleInfo(key)
    for _, info in ipairs(TB.ARROW_STYLES) do
        if info.key == key then
            return info
        end
    end
    return TB.ARROW_STYLES[1]
end

local ARROW_DEFAULT_SIZE = 48
local ARROW_MIN_SIZE = 24
local ARROW_MAX_SIZE = 96
local ARROW_SIZE_STEP = 8
local UPDATE_INTERVAL = 0.2

-- Bezel frame size as a multiple of the arrow size. Measured, not guessed:
-- Media/Bezel/Bezel.tga's black center is 84% of its width, and the widest
-- arrow (BasicArrow, whose bottom corners sweep furthest as it rotates)
-- reaches 1.11x the arrow texture's half-size from center. Fitting that
-- inside the black disc at every rotation needs at least ~1.32x; 1.4 leaves
-- a little margin. A fixed pixel padding didn't hold across the 24-96 size
-- range (too roomy small, too tight large).
local BEZEL_SCALE = 1.4
local BEZEL_TEXTURE = "Interface\\AddOns\\TrailBeacon\\Media\\Bezel\\Bezel.tga"

-- GetPlayerFacing() and Texture:SetRotation() are both confirmed (via
-- warcraft.wiki.gg) to use 0 = north/no-rotation with positive values
-- increasing counter-clockwise - the same handedness, so no sign flip is
-- needed between them.
--
-- The remaining piece - WoW's world-position axis convention - went through
-- two wrong guesses (a "south/west" legacy convention, then an "east/north"
-- one reverse-engineered from HereBeDragons, which turned out to apply its
-- own internal coordinate normalization before the formula copied from it -
-- so its raw deltas weren't the same shape as the raw deltas here).
--
-- Solved directly instead from an in-game debug capture (dx, dy, and
-- GetPlayerFacing() while standing still facing straight at a tracked
-- marker, so true bearing = facing): bearing = atan2(dy, dx), with NO axis
-- relabeling or sign flips at all. Confirmed correct in-game.
local ROTATION_SIGN = 1
local ROTATION_OFFSET = 0

local arrow = CreateFrame("Button", "TrailBeaconTrackingArrow", UIParent)
arrow:SetMovable(true)
arrow:EnableMouse(true)
arrow:SetClampedToScreen(true)
arrow:RegisterForDrag("LeftButton")
arrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
arrow:Hide()

local bezel = arrow:CreateTexture(nil, "BACKGROUND")
bezel:SetAllPoints()
bezel:SetTexture(BEZEL_TEXTURE)

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

arrow:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Tracking Arrow", 1, 1, 1)
    GameTooltip:AddLine("Shift + Right-click to open options", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)

arrow:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function ApplyStyle()
    local style = TB:GetArrowStyleInfo(TB.db.settings.arrow.style)
    TB.db.settings.arrow.style = style.key
    local color = TB.db.settings.arrow.color
    local size = TB.db.settings.arrow.size or ARROW_DEFAULT_SIZE
    texture:SetTexture(style.file)
    texture:SetSize(size, size)
    texture:SetVertexColor(color.r, color.g, color.b)
    texture:SetDesaturated(TB.db.settings.arrow.grayscale)
    arrow:SetSize(size * BEZEL_SCALE, size * BEZEL_SCALE)
end
TB.ApplyArrowStyle = ApplyStyle

function TB:AdjustArrowSize(delta)
    local size = Clamp((TB.db.settings.arrow.size or ARROW_DEFAULT_SIZE) + delta, ARROW_MIN_SIZE, ARROW_MAX_SIZE)
    TB.db.settings.arrow.size = size
    ApplyStyle()
end

TB.ARROW_MIN_SIZE = ARROW_MIN_SIZE
TB.ARROW_MAX_SIZE = ARROW_MAX_SIZE
TB.ARROW_SIZE_STEP = ARROW_SIZE_STEP

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

    local bearing = math.atan2(dy, dx)
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
