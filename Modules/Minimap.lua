local ADDON_NAME, TB = ...

local RAD_PER_DEG = math.pi / 180

local button = CreateFrame("Button", "TrailBeaconMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:Hide()

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local coordText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
coordText:SetPoint("TOP", button, "BOTTOM", 0, -2)
coordText:Hide()

local function GetMinimapRadius()
    return (Minimap:GetWidth() / 2) + 5
end

local function UpdatePosition()
    local angle = TB.db.settings.minimap.angle
    local radius = GetMinimapRadius()
    local x = math.cos(angle * RAD_PER_DEG) * radius
    local y = math.sin(angle * RAD_PER_DEG) * radius
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateCoordText()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        coordText:SetText("")
        return
    end
    local x, y = pos:GetXY()
    coordText:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
end

local function ApplyExpandedState()
    if TB.db.settings.minimap.expanded then
        coordText:Show()
        UpdateCoordText()
    else
        coordText:Hide()
    end
end

local dragging = false
local coordElapsed = 0

button:SetScript("OnDragStart", function()
    dragging = true
end)

button:SetScript("OnDragStop", function()
    dragging = false
end)

button:SetScript("OnUpdate", function(self, elapsed)
    if dragging then
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        TB.db.settings.minimap.angle = math.deg(math.atan2(py - my, px - mx))
        UpdatePosition()
        return
    end

    if TB.db.settings.minimap.expanded then
        coordElapsed = coordElapsed + elapsed
        if coordElapsed >= 0.2 then
            coordElapsed = 0
            UpdateCoordText()
        end
    end
end)

button:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" and IsShiftKeyDown() then
        TB.db.settings.minimap.expanded = not TB.db.settings.minimap.expanded
        ApplyExpandedState()
    elseif mouseButton == "LeftButton" then
        if TB.OpenMapInterface then
            TB:OpenMapInterface()
        else
            print("|cff33ff99TrailBeacon|r: the map interface isn't built yet.")
        end
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("TrailBeacon", 1, 1, 1)
    GameTooltip:AddLine("Left-click to open the marker map.", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Shift + Right-click to toggle coordinates.", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Drag to move around the minimap.", 0.9, 0.9, 0.9)
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

TB:OnDBReady(function()
    UpdatePosition()
    ApplyExpandedState()
    button:Show()
end)

TB.minimapButton = button
