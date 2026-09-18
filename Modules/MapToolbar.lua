local ADDON_NAME, TB = ...

local ICON_BUTTON_SIZE = 28
local BUTTON_SPACING = 12

local toolbar = CreateFrame("Frame", "TrailBeaconMapToolbar", WorldMapFrame.ScrollContainer, "BackdropTemplate")
toolbar:SetHeight(56)
toolbar:SetFrameStrata("HIGH")
toolbar:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOMLEFT", 8, 34)
toolbar:SetPoint("BOTTOMRIGHT", WorldMapFrame.ScrollContainer, "BOTTOMRIGHT", -8, 34)
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

local totalWidth = (#TB.ICON_TYPES * ICON_BUTTON_SIZE) + ((#TB.ICON_TYPES - 1) * BUTTON_SPACING)
local row = CreateFrame("Frame", nil, toolbar)
row:SetSize(totalWidth, ICON_BUTTON_SIZE)
row:SetPoint("BOTTOM", toolbar, "BOTTOM", 0, 8)

local iconButtons = {}
local armedIconType = nil

local function SetArmedIconType(key)
    armedIconType = (armedIconType == key) and nil or key
    for _, entry in ipairs(iconButtons) do
        if entry.key == armedIconType then
            entry.button.SelectedTexture:Show()
        else
            entry.button.SelectedTexture:Hide()
        end
    end
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

    btn:SetScript("OnClick", function()
        SetArmedIconType(iconInfo.key)
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(iconInfo.label)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    table.insert(iconButtons, { key = iconInfo.key, button = btn })
end

toolbar:SetScript("OnHide", function()
    SetArmedIconType(nil)
end)

WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function(_, mouseButton)
    if not armedIconType then return end

    if mouseButton == "RightButton" then
        SetArmedIconType(nil)
        return
    end

    if mouseButton ~= "LeftButton" then return end
    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    local x, y = WorldMapFrame:GetNormalizedCursorPosition()
    if not x or x < 0 or x > 1 or not y or y < 0 or y > 1 then return end
    TB:CreateMarker(mapID, x, y, armedIconType)
end)

TB.mapToolbar = toolbar
