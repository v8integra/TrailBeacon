local ADDON_NAME, TB = ...

TB.ICON_TYPES = {
    { key = "herb", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\leaf.tga", label = "Herb" },
    { key = "ore", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\pickaxe.tga", label = "Ore" },
    { key = "quest", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\star.tga", label = "Quest" },
    { key = "danger", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\skull-crossbones.tga", label = "Danger" },
    { key = "trashmob", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\trash.tga", label = "Trash Mob" },
    { key = "heal", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\bandage-wound.tga", label = "Heal" },
    { key = "food", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\hamburger-soda.tga", label = "Food" },
    { key = "cooking", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\knife-kitchen.tga", label = "Cooking" },
    { key = "home", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\home.tga", label = "Home" },
    { key = "marker", icon = "Interface\\AddOns\\TrailBeacon\\Media\\Icons\\marker.tga", label = "Marker" },
}

TB.MARKER_DEFAULT_SIZE = 16
TB.MARKER_MIN_SIZE = 8
TB.MARKER_MAX_SIZE = 32

local nextMarkerSerial = 0
local function GenerateMarkerID()
    nextMarkerSerial = nextMarkerSerial + 1
    return string.format("%d-%d", time(), nextMarkerSerial)
end

function TB:GetIconTypeInfo(key)
    for _, info in ipairs(TB.ICON_TYPES) do
        if info.key == key then
            return info
        end
    end
end

function TB:GetMarkerDisplayName(marker)
    local info = TB:GetIconTypeInfo(marker.iconType)
    return info and info.label or "Marker"
end

function TB:CreateMarker(mapID, x, y, iconType)
    local marker = {
        id = GenerateMarkerID(),
        mapID = mapID,
        x = x,
        y = y,
        iconType = iconType,
        size = TB.MARKER_DEFAULT_SIZE,
        color = { r = 1, g = 1, b = 1 },
        category = { [iconType] = true },
        locked = false,
        tracked = false,
    }
    table.insert(TB.db.markers, marker)
    TB:RefreshMapPins()
    return marker
end

function TB:AddImportedMarker(data)
    data.id = GenerateMarkerID()
    data.tracked = false
    table.insert(TB.db.markers, data)
    TB:RefreshMapPins()
    return data
end

function TB:GetMarkerByID(id)
    for _, marker in ipairs(TB.db.markers) do
        if marker.id == id then
            return marker
        end
    end
end

function TB:DeleteMarker(id)
    for index, marker in ipairs(TB.db.markers) do
        if marker.id == id then
            table.remove(TB.db.markers, index)
            TB:RefreshMapPins()
            return
        end
    end
end

function TB:DeleteAllMarkersForMap(mapID)
    for index = #TB.db.markers, 1, -1 do
        if TB.db.markers[index].mapID == mapID then
            table.remove(TB.db.markers, index)
        end
    end
    TB:RefreshMapPins()
end

function TB:GetTrackedMarker()
    for _, marker in ipairs(TB.db.markers) do
        if marker.tracked then
            return marker
        end
    end
end

function TB:ToggleTrackedMarker(id)
    local marker = TB:GetMarkerByID(id)
    if not marker then return end
    local wasTracked = marker.tracked
    for _, m in ipairs(TB.db.markers) do
        m.tracked = false
    end
    marker.tracked = not wasTracked
    TB:RefreshMapPins()
end

function TB:GetMarkersForMap(mapID)
    local results = {}
    for _, marker in ipairs(TB.db.markers) do
        if marker.mapID == mapID then
            table.insert(results, marker)
        end
    end
    return results
end
