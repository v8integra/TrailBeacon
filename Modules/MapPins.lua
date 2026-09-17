local ADDON_NAME, TB = ...

local PIN_TEMPLATE = "TrailBeaconMarkerPinTemplate"

TrailBeaconPinMixin = {}

function TrailBeaconPinMixin:OnAcquired(marker)
    self.marker = marker
    self:RefreshVisuals()
    self:SetPosition(marker.x, marker.y)
end

function TrailBeaconPinMixin:RefreshVisuals()
    local marker = self.marker
    local iconInfo = TB:GetIconTypeInfo(marker.iconType)
    self.Texture:SetTexture(iconInfo and iconInfo.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    self.Texture:SetVertexColor(marker.color.r, marker.color.g, marker.color.b)
    local size = marker.size or TB.MARKER_DEFAULT_SIZE
    self:SetSize(size, size)
    self:RefreshSelectionState()
end

function TrailBeaconPinMixin:RefreshSelectionState()
    if not self.SelectionGlow then
        local glow = self:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        glow:SetBlendMode("ADD")
        glow:SetPoint("TOPLEFT", -4, 4)
        glow:SetPoint("BOTTOMRIGHT", 4, -4)
        self.SelectionGlow = glow
    end
    if TB.selectedMarkerIDs and TB.selectedMarkerIDs[self.marker.id] then
        self.SelectionGlow:Show()
    else
        self.SelectionGlow:Hide()
    end
end

function TrailBeaconPinMixin:OnMouseUp(mouseButton)
    TB:OnMarkerPinClicked(self.marker, mouseButton)
end

function TrailBeaconPinMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TB:GetMarkerDisplayName(self.marker), 1, 1, 1)
    if self.marker.locked then
        GameTooltip:AddLine("Locked", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

function TrailBeaconPinMixin:OnLeave()
    GameTooltip:Hide()
end

local dataProvider = CreateFromMixins(MapCanvasDataProviderMixin)

function dataProvider:RefreshAllData(fromOnShow)
    self:RemoveAllData()
    local mapID = self:GetMap():GetMapID()
    if not mapID then return end
    for _, marker in ipairs(TB:GetMarkersForMap(mapID)) do
        self:GetMap():AcquirePin(PIN_TEMPLATE, marker)
    end
end

TB.mapDataProvider = dataProvider
WorldMapFrame:AddDataProvider(dataProvider)

function TB:RefreshMapPins()
    if dataProvider:GetMap() then
        dataProvider:RefreshAllData()
    end
end

local contextMenuFrame = CreateFrame("Frame", "TrailBeaconMarkerContextMenu", UIParent, "UIDropDownMenuTemplate")

local function BuildContextMenu(marker)
    return {
        {
            text = "Increase Size",
            notCheckable = true,
            disabled = marker.locked,
            func = function()
                marker.size = math.min((marker.size or TB.MARKER_DEFAULT_SIZE) + 2, TB.MARKER_MAX_SIZE)
                TB:RefreshMapPins()
            end,
        },
        {
            text = "Decrease Size",
            notCheckable = true,
            disabled = marker.locked,
            func = function()
                marker.size = math.max((marker.size or TB.MARKER_DEFAULT_SIZE) - 2, TB.MARKER_MIN_SIZE)
                TB:RefreshMapPins()
            end,
        },
        {
            text = "Change Color",
            notCheckable = true,
            disabled = marker.locked,
            func = function()
                TB:OpenColorPickerForMarker(marker)
            end,
        },
        {
            text = marker.locked and "Unlock" or "Lock",
            notCheckable = true,
            func = function()
                marker.locked = not marker.locked
            end,
        },
        {
            text = "Delete",
            notCheckable = true,
            disabled = marker.locked,
            func = function()
                TB:DeleteMarker(marker.id)
            end,
        },
    }
end

function TB:OpenMarkerContextMenu(marker)
    EasyMenu(BuildContextMenu(marker), contextMenuFrame, "cursor", 0, 0, "MENU")
end

function TB:OpenColorPickerForMarker(marker)
    local function OnColorChanged()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        marker.color.r, marker.color.g, marker.color.b = r, g, b
        TB:RefreshMapPins()
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = marker.color.r,
        g = marker.color.g,
        b = marker.color.b,
        swatchFunc = OnColorChanged,
        cancelFunc = function(previousValues)
            marker.color.r = previousValues.r
            marker.color.g = previousValues.g
            marker.color.b = previousValues.b
            TB:RefreshMapPins()
        end,
    })
end

function TB:OnMarkerPinClicked(marker, mouseButton)
    if mouseButton ~= "LeftButton" then return end
    if TB.manualSelectActive then
        TB:ToggleMarkerSelected(marker.id)
    else
        TB:OpenMarkerContextMenu(marker)
    end
end
