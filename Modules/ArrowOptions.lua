local ADDON_NAME, TB = ...

local PREVIEW_SIZE = 96
local THUMB_SIZE = 28
local THUMB_SPACING = 4

local panel = CreateFrame("Frame", "TrailBeaconArrowOptions", UIParent, "BackdropTemplate")
panel:SetSize(240, 220)
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

local colorBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
colorBtn:SetSize(120, 22)
colorBtn:SetText("Change Color")
colorBtn:SetPoint("TOP", styleRow, "BOTTOM", 0, -12)
colorBtn:SetScript("OnClick", function()
    local c = TB.db.settings.arrow.color
    ColorPickerFrame:SetupColorPickerAndShow({
        r = c.r,
        g = c.g,
        b = c.b,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            c.r, c.g, c.b = r, g, b
            TB.ApplyArrowStyle()
            RefreshPreview()
        end,
        cancelFunc = function(previousValues)
            c.r, c.g, c.b = previousValues.r, previousValues.g, previousValues.b
            TB.ApplyArrowStyle()
            RefreshPreview()
        end,
    })
end)

local grayscaleCheck = CreateFrame("CheckButton", "TrailBeaconArrowGrayscaleCheck", panel, "UICheckButtonTemplate")
grayscaleCheck:SetSize(24, 24)
grayscaleCheck:SetPoint("TOP", colorBtn, "BOTTOM", -40, -6)
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
