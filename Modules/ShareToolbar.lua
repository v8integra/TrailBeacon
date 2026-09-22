local ADDON_NAME, TB = ...

function TB:ToggleMarkerSelected(id)
    TB.selectedMarkerIDs = TB.selectedMarkerIDs or {}
    if TB.selectedMarkerIDs[id] then
        TB.selectedMarkerIDs[id] = nil
    else
        TB.selectedMarkerIDs[id] = true
    end
    TB:RefreshMapPins()
end

function TB:SelectAllVisibleMarkers()
    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    TB.selectedMarkerIDs = TB.selectedMarkerIDs or {}
    for _, marker in ipairs(TB:GetMarkersForMap(mapID)) do
        if TB:IsMarkerVisible(marker) then
            TB.selectedMarkerIDs[marker.id] = true
        end
    end
    TB:RefreshMapPins()
end

function TB:DeselectAllMarkers()
    TB.selectedMarkerIDs = {}
    TB:RefreshMapPins()
end

StaticPopupDialogs["TRAILBEACON_EXPORT"] = {
    text = "TrailBeacon export string (Ctrl+C to copy):",
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 350,
    -- This build exposes the dialog's edit box through dialog:GetEditBox()
    -- (the field is EditBox, not the older lowercase editBox).
    --
    -- The popup edit boxes are shared between dialogs, and GameDialog only
    -- calls SetMaxLetters when a dialog specifies maxLetters - 22 Blizzard
    -- dialogs set one (24, 31, ...) and nothing resets it. Without this, an
    -- earlier dialog's limit could silently truncate the export string.
    OnShow = function(dialog)
        local editBox = dialog:GetEditBox()
        editBox:SetMaxLetters(0)
        editBox:SetText(TB.pendingExportString or "")
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["TRAILBEACON_IMPORT"] = {
    text = "Paste a TrailBeacon export string or a /way line:",
    button1 = "Import",
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(dialog)
        dialog:GetEditBox():SetMaxLetters(0)
    end,
    OnAccept = function(dialog)
        TB:ImportString(dialog:GetEditBoxText())
    end,
    EditBoxOnEnterPressed = function(editBox)
        TB:ImportString(editBox:GetText())
        editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local shareBar = CreateFrame("Frame", "TrailBeaconShareToolbar", WorldMapFrame.ScrollContainer, "BackdropTemplate")
shareBar:SetHeight(28)
shareBar:SetFrameStrata("HIGH")
shareBar:SetPoint("TOPLEFT", WorldMapFrame.ScrollContainer, "TOPLEFT", 70, -8)
shareBar:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -70, -8)
shareBar:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})

local function CreateBarButton(text, width)
    local btn = CreateFrame("Button", nil, shareBar, "UIPanelButtonTemplate")
    btn:SetSize(width or 90, 20)
    btn:SetText(text)
    return btn
end

local selectAllBtn = CreateBarButton("Select All", 80)
selectAllBtn:SetPoint("LEFT", shareBar, "LEFT", 8, 0)
selectAllBtn:SetScript("OnClick", function()
    TB:SelectAllVisibleMarkers()
end)

local deselectAllBtn = CreateBarButton("Deselect All", 90)
deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 4, 0)
deselectAllBtn:SetScript("OnClick", function()
    TB:DeselectAllMarkers()
end)

local manualSelectBtn

local function SetManualSelectActive(active)
    TB.manualSelectActive = active
    if active then
        manualSelectBtn:LockHighlight()
    else
        manualSelectBtn:UnlockHighlight()
    end
end

manualSelectBtn = CreateBarButton("Manual Select", 95)
manualSelectBtn:SetPoint("LEFT", deselectAllBtn, "RIGHT", 4, 0)
manualSelectBtn:SetScript("OnClick", function()
    SetManualSelectActive(not TB.manualSelectActive)
end)

local copyBtn = CreateBarButton("Copy", 70)
copyBtn:SetPoint("LEFT", manualSelectBtn, "RIGHT", 12, 0)
copyBtn:SetScript("OnClick", function()
    TB:ExportSelected()
end)

local importBtn = CreateBarButton("Import", 70)
importBtn:SetPoint("LEFT", copyBtn, "RIGHT", 4, 0)
importBtn:SetScript("OnClick", function()
    StaticPopup_Show("TRAILBEACON_IMPORT")
end)

WorldMapFrame:HookScript("OnHide", function()
    SetManualSelectActive(false)
end)

-- Also covers the toolbars being collapsed while the map stays open.
shareBar:HookScript("OnHide", function()
    SetManualSelectActive(false)
end)

TB.shareToolbar = shareBar
TB.shareToolbarButtons = {
    selectAll = selectAllBtn,
    deselectAll = deselectAllBtn,
    manualSelect = manualSelectBtn,
    copy = copyBtn,
    import = importBtn,
}
