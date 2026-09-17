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
    OnShow = function(self)
        self.editBox:SetText(TB.pendingExportString or "")
        self.editBox:HighlightText()
        self.editBox:SetFocus()
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
    OnAccept = function(self)
        TB:ImportString(self.editBox:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        TB:ImportString(parent.editBox:GetText())
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local shareBar = CreateFrame("Frame", "TrailBeaconShareToolbar", WorldMapFrame, "BackdropTemplate")
shareBar:SetHeight(32)
shareBar:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 8, -8)
shareBar:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -8, -8)
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
        manualSelectBtn:SetText("Manual Select: On")
    else
        manualSelectBtn:UnlockHighlight()
        manualSelectBtn:SetText("Manual Select")
    end
end

manualSelectBtn = CreateBarButton("Manual Select", 110)
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

local autoShareCheck = CreateFrame("CheckButton", "TrailBeaconAutoShareCheck", shareBar, "UICheckButtonTemplate")
autoShareCheck:SetSize(20, 20)
autoShareCheck:SetPoint("RIGHT", shareBar, "RIGHT", -8, 0)
autoShareCheck:SetScript("OnClick", function(self)
    TB.db.settings.autoShare = self:GetChecked() and true or false
end)

local autoShareLabel = shareBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
autoShareLabel:SetPoint("RIGHT", autoShareCheck, "LEFT", -4, 0)
autoShareLabel:SetText("Auto-Share")

TB:OnDBReady(function()
    autoShareCheck:SetChecked(TB.db.settings.autoShare)
end)

WorldMapFrame:HookScript("OnHide", function()
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
