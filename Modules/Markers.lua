local ADDON_NAME, TB = ...

TB.ICON_TYPES = {
    { key = "herb", icon = "Interface\\Icons\\INV_Misc_Herb_02", label = "Herb" },
    { key = "ore", icon = "Interface\\Icons\\INV_Misc_Ore_02", label = "Ore" },
    { key = "quest", icon = "Interface\\Icons\\INV_Misc_QuestionMark", label = "Quest" },
    { key = "custom", icon = "Interface\\Icons\\INV_Misc_Map_02", label = "Custom" },
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

function TB:GetMarkersForMap(mapID)
    local results = {}
    for _, marker in ipairs(TB.db.markers) do
        if marker.mapID == mapID then
            table.insert(results, marker)
        end
    end
    return results
end
