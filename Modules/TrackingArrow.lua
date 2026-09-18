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

local ARROW_DEFAULT_SIZE = 48
local ARROW_MIN_SIZE = 24
local ARROW_MAX_SIZE = 96
local ARROW_SIZE_STEP = 8
local BEZEL_PADDING = 10
local UPDATE_INTERVAL = 0.2

-- GetPlayerFacing() and Texture:SetRotation() are both confirmed (via
-- warcraft.wiki.gg) to use 0 = north/no-rotation with positive values
-- increasing counter-clockwise - the same handedness, so no sign flip is
-- needed between them.
--
-- The remaining piece - WoW's world-position axis convention - was wrong,
-- not just imprecise: assumed +X = south, +Y = west (an old "instance
-- coordinate" convention), patched with a constant ROTATION_OFFSET across
-- two rounds of testing (11-15 degrees). That never fully converged because
-- the real error wasn't a constant rotation - a wrong axis mapping produces
-- an error that varies by bearing/facing geometry, small at some angles and
-- large (~90 degrees, per a "standing still facing directly at the target"
-- test) at others, which is exactly the inconsistent behavior seen.
--
-- Reverse-engineered the correct convention from HereBeDragons
-- (github.com/Nevcairiel/HereBeDragons), a widely-used open-source library
-- many navigation addons rely on for this exact calculation: its
-- GetWorldVector uses atan2(-deltaX, deltaY) as the raw bearing before
-- converting to a clockwise compass value, which only produces a correct
-- compass bearing if +Y = north and +X = east directly (a plain, standard
-- map convention) - not the south/west assumption used here before.
local ROTATION_SIGN = 1
local ROTATION_OFFSET = 0

local arrow = CreateFrame("Button", "TrailBeaconTrackingArrow", UIParent, "BackdropTemplate")
arrow:SetMovable(true)
arrow:EnableMouse(true)
arrow:SetClampedToScreen(true)
arrow:RegisterForDrag("LeftButton")
arrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
arrow:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
arrow:SetBackdropColor(0, 0, 0, 0.6)
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
    local size = TB.db.settings.arrow.size or ARROW_DEFAULT_SIZE
    texture:SetTexture(style.file)
    texture:SetSize(size, size)
    texture:SetVertexColor(color.r, color.g, color.b)
    texture:SetDesaturated(TB.db.settings.arrow.grayscale)
    arrow:SetSize(size + BEZEL_PADDING * 2, size + BEZEL_PADDING * 2)
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

    local northComponent = dy
    local westComponent = -dx
    local bearing = math.atan2(westComponent, northComponent)
    local facing = GetPlayerFacing() or 0
    local relative = ROTATION_SIGN * (bearing - facing) + ROTATION_OFFSET

    -- Temporary diagnostic: two rounds of derivation both disagreed with
    -- in-game testing, so capturing exact numbers instead of continuing to
    -- guess. Read with: /run local d=TB.debugArrow print(d.dx,d.dy,d.bearingDeg,d.facingDeg,d.relativeDeg)
    TB.debugArrow = {
        dx = dx,
        dy = dy,
        bearingDeg = math.deg(bearing),
        facingDeg = math.deg(facing),
        relativeDeg = math.deg(relative),
    }

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
