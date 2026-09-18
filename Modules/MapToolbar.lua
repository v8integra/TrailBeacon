local ADDON_NAME, TB = ...

local ICON_BUTTON_SIZE = 28
local BUTTON_SPACING = 12
local TOOLBAR_HEIGHT = 56
local TOOLBAR_BOTTOM = 34
local TOOLBAR_INSET = 8
local RIGHT_BUTTON_Y = 8
local COLLAPSE_BUTTON_WIDTH = 26

local toolbar = CreateFrame("Frame", "TrailBeaconMapToolbar", WorldMapFrame.ScrollContainer, "BackdropTemplate")
toolbar:SetHeight(TOOLBAR_HEIGHT)
toolbar:SetFrameStrata("HIGH")
toolbar:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOMLEFT", TOOLBAR_INSET, TOOLBAR_BOTTOM)
toolbar:SetPoint("BOTTOMRIGHT", WorldMapFrame.ScrollContainer, "BOTTOMRIGHT", -TOOLBAR_INSET, TOOLBAR_BOTTOM)
toolbar:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})

local instructions = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
instructions:SetPoint("TOP", toolbar, "TOP", 0, -6)
instructions:SetText("Click an icon, then click on the map to place it.")

StaticPopupDialogs["TRAILBEACON_DELETE_ALL_MARKERS"] = {
    text = "Delete all markers on this map?",
    button1 = "Delete All",
    button2 = CANCEL,
    OnAccept = function()
        local mapID = WorldMapFrame:GetMapID()
        if mapID then
            TB:DeleteAllMarkersForMap(mapID)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local collapseBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
collapseBtn:SetSize(COLLAPSE_BUTTON_WIDTH, 20)
collapseBtn:SetText(">>")
collapseBtn:SetPoint("RIGHT", toolbar, "RIGHT", -TOOLBAR_INSET, RIGHT_BUTTON_Y)
collapseBtn:SetScript("OnClick", function()
    TB:SetToolbarsCollapsed(true)
end)
collapseBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Collapse toolbars")
    GameTooltip:Show()
end)
collapseBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local deleteAllBtn = CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
deleteAllBtn:SetSize(80, 20)
deleteAllBtn:SetText("Delete All")
deleteAllBtn:SetPoint("RIGHT", collapseBtn, "LEFT", -4, 0)
deleteAllBtn:SetScript("OnClick", function()
    StaticPopup_Show("TRAILBEACON_DELETE_ALL_MARKERS")
end)

local totalWidth = (#TB.ICON_TYPES * ICON_BUTTON_SIZE) + ((#TB.ICON_TYPES - 1) * BUTTON_SPACING)
local row = CreateFrame("Frame", nil, toolbar)
row:SetSize(totalWidth, ICON_BUTTON_SIZE)
row:SetPoint("BOTTOM", toolbar, "BOTTOM", 0, 8)

local iconButtons = {}
local armedIconType = nil

local function RefreshSelectedTextures()
    for _, entry in ipairs(iconButtons) do
        if entry.key == armedIconType then
            entry.button.SelectedTexture:Show()
        else
            entry.button.SelectedTexture:Hide()
        end
    end
end

local function ArmIconType(key)
    armedIconType = key
    RefreshSelectedTextures()
end

local function DisarmIconType()
    armedIconType = nil
    RefreshSelectedTextures()
end

function TB:GetArmedIconType()
    return armedIconType
end

for index, iconInfo in ipairs(TB.ICON_TYPES) do
    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
    btn:SetPoint("LEFT", row, "LEFT", (index - 1) * (ICON_BUTTON_SIZE + BUTTON_SPACING), 0)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconInfo.icon)

    local selected = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    selected:SetAllPoints()
    selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    selected:SetBlendMode("ADD")
    selected:Hide()
    btn.SelectedTexture = selected

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            DisarmIconType()
        else
            ArmIconType(iconInfo.key)
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(iconInfo.label)
        if armedIconType == iconInfo.key then
            GameTooltip:AddLine("Right-click to deselect icon", 0.6, 0.6, 0.6)
        else
            GameTooltip:AddLine("Click to select", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    table.insert(iconButtons, { key = iconInfo.key, button = btn })
end

toolbar:SetScript("OnHide", function()
    DisarmIconType()
end)

WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function(_, mouseButton)
    if not armedIconType then return end

    if mouseButton == "RightButton" then
        DisarmIconType()
        return
    end

    if mouseButton ~= "LeftButton" then return end
    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    local x, y = WorldMapFrame:GetNormalizedCursorPosition()
    if not x or x < 0 or x > 1 or not y or y < 0 or y > 1 then return end
    TB:CreateMarker(mapID, x, y, armedIconType)
end)

-- Collapsed state is a single icon docked where the ">>" button was, so the
-- two read as one control. Centered on that button's exact position (derived
-- from the same constants that place it) rather than anchored to it, since
-- the button is hidden along with the toolbar while collapsed.
local expandBtn = CreateFrame("Button", nil, WorldMapFrame.ScrollContainer)
expandBtn:SetSize(28, 28)
expandBtn:SetFrameStrata("HIGH")
expandBtn:SetPoint(
    "CENTER",
    WorldMapFrame.ScrollContainer,
    "BOTTOMRIGHT",
    -(TOOLBAR_INSET * 2 + COLLAPSE_BUTTON_WIDTH / 2),
    TOOLBAR_BOTTOM + TOOLBAR_HEIGHT / 2 + RIGHT_BUTTON_Y
)
expandBtn:SetNormalTexture("Interface\\AddOns\\TrailBeacon\\Media\\Icon\\TrailBeaconIcon.tga")
expandBtn:SetHighlightTexture("Interface\\Buttons\\CheckButtonHilight")
expandBtn:GetHighlightTexture():SetBlendMode("ADD")
expandBtn:Hide()
expandBtn:SetScript("OnClick", function()
    TB:SetToolbarsCollapsed(false)
end)
expandBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("TrailBeacon")
    GameTooltip:AddLine("Click to show toolbars", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
expandBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Hiding the toolbars runs their existing OnHide cleanup: the marker toolbar
-- disarms any armed placement icon (so a click on the map can't drop a
-- marker with no visible sign of it), and the share toolbar closes the
-- filter panel and turns Manual Select off (see ShareToolbar.lua).
function TB:SetToolbarsCollapsed(collapsed)
    TB.db.settings.toolbarsCollapsed = collapsed
    toolbar:SetShown(not collapsed)
    TB.shareToolbar:SetShown(not collapsed)
    expandBtn:SetShown(collapsed)
end

TB:OnDBReady(function()
    TB:SetToolbarsCollapsed(TB.db.settings.toolbarsCollapsed)
end)

TB.mapToolbar = toolbar
