local ADDON_NAME, TB = ...

local ROW_HEIGHT = 40

local browser = CreateFrame("Frame", "TrailBeaconMarkerBrowser", UIParent, "BasicFrameTemplateWithInset")
browser:SetSize(360, 420)
browser:SetPoint("CENTER")
browser:SetMovable(true)
browser:EnableMouse(true)
browser:RegisterForDrag("LeftButton")
browser:SetScript("OnDragStart", browser.StartMoving)
browser:SetScript("OnDragStop", browser.StopMovingOrSizing)
browser:Hide()

local title = browser:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", browser, "TOP", 0, -6)
title:SetText("TrailBeacon Markers")

local scrollFrame = CreateFrame("ScrollFrame", "TrailBeaconMarkerBrowserScroll", browser, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", browser.Inset, "TOPLEFT", 4, -4)
scrollFrame:SetPoint("BOTTOMRIGHT", browser.Inset, "BOTTOMRIGHT", -26, 4)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

local rows = {}

local function GetRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", 4, 0)
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 2)
    nameText:SetPoint("RIGHT", row, "RIGHT", -28, 0)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    local detailText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    detailText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, -2)
    detailText:SetPoint("RIGHT", row, "RIGHT", -28, 0)
    detailText:SetJustifyH("LEFT")
    row.detailText = detailText

    local deleteBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    deleteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Delete marker")
        GameTooltip:Show()
    end)
    deleteBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.deleteBtn = deleteBtn

    rows[index] = row
    return row
end

local function RefreshList()
    local markers = TB.db.markers
    for index, marker in ipairs(markers) do
        local row = GetRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

        local iconInfo = TB:GetIconTypeInfo(marker.iconType)
        row.icon:SetTexture(iconInfo and iconInfo.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        row.nameText:SetText(TB:GetMarkerDisplayName(marker))

        local mapInfo = C_Map.GetMapInfo(marker.mapID)
        local zoneName = mapInfo and mapInfo.name or ("Map " .. tostring(marker.mapID))
        row.detailText:SetFormattedText(
            "%s (%.1f, %.1f)%s",
            zoneName,
            marker.x * 100,
            marker.y * 100,
            marker.locked and "  [Locked]" or ""
        )

        row:SetScript("OnClick", function()
            TB:FocusMarkerOnMap(marker)
        end)
        row.deleteBtn:SetScript("OnClick", function()
            TB:DeleteMarker(marker.id)
            RefreshList()
        end)

        row:Show()
    end

    for index = #markers + 1, #rows do
        rows[index]:Hide()
    end

    content:SetSize(1, math.max(#markers * ROW_HEIGHT, 1))
end

function TB:FocusMarkerOnMap(marker)
    ShowUIPanel(WorldMapFrame)
    WorldMapFrame:SetMapID(marker.mapID)
end

function TB:ToggleMarkerBrowser()
    if browser:IsShown() then
        browser:Hide()
    else
        RefreshList()
        browser:Show()
    end
end

TB.markerBrowser = browser
