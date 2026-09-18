local ADDON_NAME, TB = ...

local PIN_TEMPLATE = "TrailBeaconMarkerPinTemplate"

-- Built from MapCanvasPinMixin (SetPosition and the rest of the pin/canvas
-- integration) rather than inheriting an XML base template by name, since
-- that name couldn't be resolved reliably. This global table must exist
-- before Modules/MapPins.xml is parsed - see the TOC load order.
--
-- AcquirePin wires up OnMouseUp/OnEnter/OnLeave scripts itself (see
-- MapCanvas_DataProviderBase.lua) whenever the XML template has
-- enableMouseClicks/enableMouseMotion set - it asserts those script slots
-- are still empty before claiming them, so this mixin must NOT hook them
-- via XML <Scripts>. The actual override points are OnClick (called on a
-- mouse-up that lands back inside the pin) and OnMouseEnter/OnMouseLeave.
TrailBeaconPinMixin = CreateFromMixins(MapCanvasPinMixin)

-- MAP_CANVAS_PIN_FRAME_LEVEL_DEFAULT (2000, in MapCanvas_PinFrameLevelsManager.lua)
-- is a fixed baseline that other map content (explored-terrain detail layers,
-- other data providers) can register frame levels above. Without setting one
-- ourselves, markers were getting visually covered in explored areas.
-- PIN_FRAME_LEVEL_TOPMOST is a reserved keyword that always resolves to
-- whatever is currently the highest-registered level, guaranteeing markers
-- render above everything else regardless of what else is on the map.
function TrailBeaconPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
end

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
    self:RefreshIndicators()
end

function TrailBeaconPinMixin:RefreshIndicators()
    if not self.SelectionGlow then
        local glow = self:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        glow:SetBlendMode("ADD")
        glow:SetPoint("TOPLEFT", -4, 4)
        glow:SetPoint("BOTTOMRIGHT", 4, -4)
        self.SelectionGlow = glow
    end
    if TB.selectedMarkerIDs and TB.selectedMarkerIDs[self.marker.id] then
        self.SelectionGlow:SetVertexColor(1, 1, 1)
        self.SelectionGlow:Show()
    elseif self.marker.tracked then
        self.SelectionGlow:SetVertexColor(1, 0.82, 0)
        self.SelectionGlow:Show()
    else
        self.SelectionGlow:Hide()
    end
end

function TrailBeaconPinMixin:OnClick(mouseButton)
    if mouseButton == "RightButton" and IsControlKeyDown() then
        if not self.marker.locked then
            TB:DeleteMarker(self.marker.id)
        end
        return
    end
    TB:OnMarkerPinClicked(self.marker, mouseButton, self)
end

function TrailBeaconPinMixin:OnMouseEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TB:GetMarkerDisplayName(self.marker), 1, 1, 1)
    if self.marker.locked then
        GameTooltip:AddLine("Locked", 0.6, 0.6, 0.6)
    end
    if self.marker.tracked then
        GameTooltip:AddLine("Tracked", 1, 0.82, 0)
    end
    GameTooltip:AddLine("Shift-click to track/untrack", 0.6, 0.6, 0.6)
    if not self.marker.locked then
        GameTooltip:AddLine("Ctrl + Right-click to delete", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

function TrailBeaconPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

local dataProvider = CreateFromMixins(MapCanvasDataProviderMixin)

-- RemoveAllData is a no-op stub on the base mixin (see
-- MapCanvas_DataProviderBase.lua) - consumers are expected to override it.
-- Without this, old pins were never released back to the pool: every
-- RefreshAllData (map change, select/deselect, filter toggle, etc.) just
-- acquired *more* pins on top of the stale ones, which is why markers
-- appeared to "follow" between different maps and why clicks/selection
-- looked unresponsive (landing on the wrong stacked duplicate).
function dataProvider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE)
end

function dataProvider:RefreshAllData(fromOnShow)
    self:RemoveAllData()
    local mapID = self:GetMap():GetMapID()
    if not mapID then return end
    for _, marker in ipairs(TB:GetMarkersForMap(mapID)) do
        if TB:IsMarkerVisible(marker) then
            self:GetMap():AcquirePin(PIN_TEMPLATE, marker)
        end
    end
end

TB.mapDataProvider = dataProvider
WorldMapFrame:AddDataProvider(dataProvider)

function TB:RefreshMapPins()
    if dataProvider:GetMap() then
        dataProvider:RefreshAllData()
    end
end

-- EasyMenu/UIDropDownMenu don't exist in this build - Blizzard_Menu's
-- MenuUtil is the current API (verified against MenuUtil.lua). CreateButton
-- returns the new button's element description, which is what SetEnabled
-- needs to be chained onto for the locked-marker disabled state.
function TB:OpenMarkerContextMenu(marker, ownerRegion)
    MenuUtil.CreateContextMenu(ownerRegion, function(owner, rootDescription)
        rootDescription:CreateButton("Increase Size", function()
            marker.size = math.min((marker.size or TB.MARKER_DEFAULT_SIZE) + 2, TB.MARKER_MAX_SIZE)
            TB:RefreshMapPins()
        end):SetEnabled(not marker.locked)

        rootDescription:CreateButton("Decrease Size", function()
            marker.size = math.max((marker.size or TB.MARKER_DEFAULT_SIZE) - 2, TB.MARKER_MIN_SIZE)
            TB:RefreshMapPins()
        end):SetEnabled(not marker.locked)

        rootDescription:CreateButton("Change Color", function()
            TB:OpenColorPickerForMarker(marker)
        end):SetEnabled(not marker.locked)

        rootDescription:CreateButton(marker.locked and "Unlock" or "Lock", function()
            marker.locked = not marker.locked
        end)

        rootDescription:CreateButton("Delete", function()
            TB:DeleteMarker(marker.id)
        end):SetEnabled(not marker.locked)
    end)
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

function TB:OnMarkerPinClicked(marker, mouseButton, pin)
    if mouseButton ~= "LeftButton" then return end
    if IsShiftKeyDown() then
        TB:ToggleTrackedMarker(marker.id)
    elseif TB.manualSelectActive then
        TB:ToggleMarkerSelected(marker.id)
    else
        TB:OpenMarkerContextMenu(marker, pin)
    end
end
