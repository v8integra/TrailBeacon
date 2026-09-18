local ADDON_NAME, TB = ...

function TB:IsCategoryVisible(key)
    return TB.db.settings.filters[key] ~= false
end

function TB:SetCategoryVisible(key, visible)
    TB.db.settings.filters[key] = visible and true or false
    TB:RefreshMapPins()
end

function TB:SetAllCategoriesVisible(visible)
    for _, iconInfo in ipairs(TB.ICON_TYPES) do
        TB.db.settings.filters[iconInfo.key] = visible
    end
    TB:RefreshMapPins()
end

function TB:IsMarkerVisible(marker)
    local category = marker.category
    if not category or next(category) == nil then
        return true
    end
    for key in pairs(category) do
        if TB:IsCategoryVisible(key) then
            return true
        end
    end
    return false
end

local BUTTON_ROW_HEIGHT = 26

local panel = CreateFrame("Frame", "TrailBeaconFilterPanel", TB.shareToolbar, "BackdropTemplate")
panel:SetSize(176, 12 + BUTTON_ROW_HEIGHT + (#TB.ICON_TYPES * 20))
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetFrameStrata("DIALOG")
panel:Hide()

local checkButtons = {}

for index, iconInfo in ipairs(TB.ICON_TYPES) do
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("TOPLEFT", 6, -6 - BUTTON_ROW_HEIGHT - (index - 1) * 20)

    local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText(iconInfo.label)

    check:SetScript("OnClick", function(self)
        TB:SetCategoryVisible(iconInfo.key, self:GetChecked())
    end)

    checkButtons[iconInfo.key] = check
end

local function RefreshCheckButtons()
    for key, check in pairs(checkButtons) do
        check:SetChecked(TB:IsCategoryVisible(key))
    end
end

local selectAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
selectAllBtn:SetSize(74, 20)
selectAllBtn:SetText("Select All")
selectAllBtn:SetPoint("TOPLEFT", 8, -8)
selectAllBtn:SetScript("OnClick", function()
    TB:SetAllCategoriesVisible(true)
    RefreshCheckButtons()
end)

local deselectAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
deselectAllBtn:SetSize(84, 20)
deselectAllBtn:SetText("Deselect All")
deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 4, 0)
deselectAllBtn:SetScript("OnClick", function()
    TB:SetAllCategoriesVisible(false)
    RefreshCheckButtons()
end)

local filterBtn = CreateFrame("Button", "TrailBeaconFilterButton", TB.shareToolbar, "UIPanelButtonTemplate")
filterBtn:SetSize(70, 20)
filterBtn:SetText("Filters")
filterBtn:SetPoint("LEFT", TB.shareToolbarButtons.import, "RIGHT", 12, 0)
filterBtn:SetScript("OnClick", function()
    if panel:IsShown() then
        panel:Hide()
    else
        RefreshCheckButtons()
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", filterBtn, "BOTTOMLEFT", 0, -2)
        panel:Show()
    end
end)

TB.shareToolbar:HookScript("OnHide", function()
    panel:Hide()
end)

TB.filterButton = filterBtn
TB.filterPanel = panel
