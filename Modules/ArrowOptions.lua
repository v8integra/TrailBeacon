local ADDON_NAME, TB = ...

local PREVIEW_SIZE = 96
local THUMB_SIZE = 28
local THUMB_SPACING = 4
local SWATCH_SIZE = 20
local SWATCH_SPACING = 4
local SWATCH_COLUMNS = 5

-- Preset swatches instead of Blizzard's ColorPickerFrame, which opens as a
-- separate system popup disconnected from this window - keeping everything
-- in one panel per feedback.
local ARROW_COLORS = {
    { r = 1, g = 1, b = 1 },
    { r = 1, g = 0.2, b = 0.2 },
    { r = 1, g = 0.55, b = 0.15 },
    { r = 1, g = 0.9, b = 0.2 },
    { r = 0.3, g = 1, b = 0.3 },
    { r = 0.3, g = 1, b = 1 },
    { r = 0.35, g = 0.55, b = 1 },
    { r = 0.7, g = 0.35, b = 1 },
    { r = 1, g = 0.4, b = 0.75 },
    { r = 0.35, g = 0.35, b = 0.35 },
}

local panel = CreateFrame("Frame", "TrailBeaconArrowOptions", UIParent, "BackdropTemplate")
panel:SetSize(240, 350)
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 11, top = 11, bottom = 11 },
})
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetFrameStrata("DIALOG")
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", panel, "TOP", 0, -16)
title:SetText("Arrow Options")

local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

local previewBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
previewBg:SetSize(PREVIEW_SIZE + 12, PREVIEW_SIZE + 12)
previewBg:SetPoint("TOP", title, "BOTTOM", 0, -10)
previewBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})

local previewTexture = previewBg:CreateTexture(nil, "ARTWORK")
previewTexture:SetPoint("CENTER")

local styleRowWidth = (#TB.ARROW_STYLES * THUMB_SIZE) + ((#TB.ARROW_STYLES - 1) * THUMB_SPACING)
local styleRow = CreateFrame("Frame", nil, panel)
styleRow:SetSize(styleRowWidth, THUMB_SIZE)
styleRow:SetPoint("TOP", previewBg, "BOTTOM", 0, -10)

local styleButtons = {}
local sizeLabel

local function RefreshPreview()
    local style = TB:GetArrowStyleInfo(TB.db.settings.arrow.style)
    local color = TB.db.settings.arrow.color
    previewTexture:SetTexture(style.file)
    previewTexture:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
    previewTexture:SetVertexColor(color.r, color.g, color.b)
    previewTexture:SetDesaturated(TB.db.settings.arrow.grayscale)

    for _, entry in ipairs(styleButtons) do
        if entry.key == TB.db.settings.arrow.style then
            entry.highlight:Show()
        else
            entry.highlight:Hide()
        end
    end

    sizeLabel:SetText("Size: " .. tostring(TB.db.settings.arrow.size))
end

for index, style in ipairs(TB.ARROW_STYLES) do
    local btn = CreateFrame("Button", nil, styleRow)
    btn:SetSize(THUMB_SIZE, THUMB_SIZE)
    btn:SetPoint("LEFT", styleRow, "LEFT", (index - 1) * (THUMB_SIZE + THUMB_SPACING), 0)

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")
    tex:SetSize(THUMB_SIZE, THUMB_SIZE)
    tex:SetTexture(style.file)

    local highlight = btn:CreateTexture(nil, "OVERLAY")
    highlight:SetPoint("TOPLEFT", -3, 3)
    highlight:SetPoint("BOTTOMRIGHT", 3, -3)
    highlight:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    highlight:SetBlendMode("ADD")
    highlight:Hide()

    btn:SetScript("OnClick", function()
        TB.db.settings.arrow.style = style.key
        TB.ApplyArrowStyle()
        RefreshPreview()
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(style.label)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    styleButtons[index] = { key = style.key, highlight = highlight }
end

local sizeRow = CreateFrame("Frame", nil, panel)
sizeRow:SetSize(140, 22)
sizeRow:SetPoint("TOP", styleRow, "BOTTOM", 0, -12)

local decreaseBtn = CreateFrame("Button", nil, sizeRow, "UIPanelButtonTemplate")
decreaseBtn:SetSize(24, 22)
decreaseBtn:SetText("-")
decreaseBtn:SetPoint("LEFT", sizeRow, "LEFT", 0, 0)
decreaseBtn:SetScript("OnClick", function()
    TB:AdjustArrowSize(-TB.ARROW_SIZE_STEP)
    RefreshPreview()
end)

sizeLabel = sizeRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sizeLabel:SetPoint("CENTER", sizeRow, "CENTER", 0, 0)

local increaseBtn = CreateFrame("Button", nil, sizeRow, "UIPanelButtonTemplate")
increaseBtn:SetSize(24, 22)
increaseBtn:SetText("+")
increaseBtn:SetPoint("RIGHT", sizeRow, "RIGHT", 0, 0)
increaseBtn:SetScript("OnClick", function()
    TB:AdjustArrowSize(TB.ARROW_SIZE_STEP)
    RefreshPreview()
end)

local swatchGridWidth = (SWATCH_COLUMNS * SWATCH_SIZE) + ((SWATCH_COLUMNS - 1) * SWATCH_SPACING)
local swatchGrid = CreateFrame("Frame", nil, panel)
swatchGrid:SetSize(swatchGridWidth, 1)
swatchGrid:SetPoint("TOP", sizeRow, "BOTTOM", 0, -12)

for index, colorInfo in ipairs(ARROW_COLORS) do
    local column = (index - 1) % SWATCH_COLUMNS
    local rowNum = math.floor((index - 1) / SWATCH_COLUMNS)

    local swatch = CreateFrame("Button", nil, swatchGrid, "BackdropTemplate")
    swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
    swatch:SetPoint("TOPLEFT", column * (SWATCH_SIZE + SWATCH_SPACING), -rowNum * (SWATCH_SIZE + SWATCH_SPACING))
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    swatch:SetBackdropColor(colorInfo.r, colorInfo.g, colorInfo.b)

    swatch:SetScript("OnClick", function()
        local c = TB.db.settings.arrow.color
        c.r, c.g, c.b = colorInfo.r, colorInfo.g, colorInfo.b
        TB.ApplyArrowStyle()
        RefreshPreview()
    end)

    if rowNum == math.floor((#ARROW_COLORS - 1) / SWATCH_COLUMNS) then
        swatchGrid:SetHeight((rowNum + 1) * SWATCH_SIZE + rowNum * SWATCH_SPACING)
    end
end

local grayscaleCheck = CreateFrame("CheckButton", "TrailBeaconArrowGrayscaleCheck", panel, "UICheckButtonTemplate")
grayscaleCheck:SetSize(24, 24)
grayscaleCheck:SetPoint("TOP", swatchGrid, "BOTTOM", -40, -10)
grayscaleCheck:SetScript("OnClick", function(self)
    TB.db.settings.arrow.grayscale = self:GetChecked() and true or false
    TB.ApplyArrowStyle()
    RefreshPreview()
end)

local grayscaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
grayscaleLabel:SetPoint("LEFT", grayscaleCheck, "RIGHT", 2, 0)
grayscaleLabel:SetText("Grayscale")

function TB:ToggleArrowOptions()
    if panel:IsShown() then
        panel:Hide()
        return
    end
    panel:ClearAllPoints()
    panel:SetPoint("LEFT", TB.trackingArrow, "RIGHT", 12, -10)
    grayscaleCheck:SetChecked(TB.db.settings.arrow.grayscale)
    RefreshPreview()
    panel:Show()
end

TB.arrowOptionsPanel = panel
