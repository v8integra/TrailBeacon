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
icon:SetTexture("Interface\\AddOns\\TrailBeacon\\Media\\Icon\\TrailBeaconIcon.tga")

local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

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

local dragging = false

button:SetScript("OnDragStart", function()
    dragging = true
end)

button:SetScript("OnDragStop", function()
    dragging = false
end)

button:SetScript("OnUpdate", function()
    if not dragging then return end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    TB.db.settings.minimap.angle = math.deg(math.atan2(py - my, px - mx))
    UpdatePosition()
end)

button:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" then
        TB:ToggleMarkerBrowser()
    elseif mouseButton == "LeftButton" then
        ToggleWorldMap()
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("TrailBeacon", 1, 1, 1)
    GameTooltip:AddLine("Left-click to open the marker map.", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Right-click to open the marker list.", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Drag to move around the minimap.", 0.9, 0.9, 0.9)
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

TB:OnDBReady(function()
    UpdatePosition()
    button:Show()
end)

TB.minimapButton = button
