local ADDON_NAME, TB = ...

local EXPORT_PREFIX = "TBM1:"

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_REVERSE = {}
for i = 1, #B64_CHARS do
    B64_REVERSE[B64_CHARS:sub(i, i)] = i - 1
end

local function Base64Encode(data)
    local result = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        b = b or 0
        c = c or 0
        local n = a * 65536 + b * 256 + c
        local i1 = math.floor(n / 262144) % 64
        local i2 = math.floor(n / 4096) % 64
        local i3 = math.floor(n / 64) % 64
        local i4 = n % 64
        local out3 = (i + 1 <= #data) and B64_CHARS:sub(i3 + 1, i3 + 1) or "="
        local out4 = (i + 2 <= #data) and B64_CHARS:sub(i4 + 1, i4 + 1) or "="
        table.insert(result, B64_CHARS:sub(i1 + 1, i1 + 1) .. B64_CHARS:sub(i2 + 1, i2 + 1) .. out3 .. out4)
    end
    return table.concat(result)
end

local function Base64Decode(data)
    data = data:gsub("[^%w%+%/%=]", "")
    local result = {}
    for i = 1, #data, 4 do
        local c1 = B64_REVERSE[data:sub(i, i)] or 0
        local c2 = B64_REVERSE[data:sub(i + 1, i + 1)] or 0
        local s3 = data:sub(i + 2, i + 2)
        local s4 = data:sub(i + 3, i + 3)
        local c3 = B64_REVERSE[s3]
        local c4 = B64_REVERSE[s4]
        local n = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
        table.insert(result, string.char(math.floor(n / 65536) % 256))
        if s3 ~= "" and s3 ~= "=" then
            table.insert(result, string.char(math.floor(n / 256) % 256))
        end
        if s4 ~= "" and s4 ~= "=" then
            table.insert(result, string.char(n % 256))
        end
    end
    return table.concat(result)
end

local function SerializeMarker(marker)
    local categories = {}
    for key, enabled in pairs(marker.category or {}) do
        if enabled then
            table.insert(categories, key)
        end
    end
    return table.concat({
        marker.mapID,
        string.format("%.4f", marker.x),
        string.format("%.4f", marker.y),
        marker.iconType,
        marker.size,
        string.format("%.2f", marker.color.r),
        string.format("%.2f", marker.color.g),
        string.format("%.2f", marker.color.b),
        marker.locked and 1 or 0,
        table.concat(categories, ";"),
    }, ",")
end

local function DeserializeMarker(record)
    local parts = { strsplit(",", record) }
    if #parts < 9 then return nil end

    local mapID = tonumber(parts[1])
    local x = tonumber(parts[2])
    local y = tonumber(parts[3])
    local iconType = parts[4]
    local size = tonumber(parts[5])
    local r = tonumber(parts[6])
    local g = tonumber(parts[7])
    local b = tonumber(parts[8])
    local locked = parts[9] == "1"
    local categoryStr = parts[10] or ""

    if not (mapID and x and y and size and r and g and b) then
        return nil
    end

    local category = {}
    for _, key in ipairs({ strsplit(";", categoryStr) }) do
        if key ~= "" then
            category[key] = true
        end
    end

    return {
        mapID = mapID,
        x = x,
        y = y,
        iconType = iconType,
        size = size,
        color = { r = r, g = g, b = b },
        locked = locked,
        category = category,
    }
end

local function ParseWayLine(text)
    text = strtrim(text)
    text = text:gsub("^/way%s+", "")

    local mapID
    local hashID, rest = text:match("^#(%d+)%s+(.*)$")
    if hashID then
        mapID = tonumber(hashID)
        text = rest
    end

    local x, y = text:match("^(%d+%.?%d*)%s*,?%s*(%d+%.?%d*)")
    if not x or not y then
        return nil
    end

    if not mapID then
        mapID = WorldMapFrame:GetMapID() or C_Map.GetBestMapForUnit("player")
    end
    if not mapID then
        return nil
    end

    return {
        mapID = mapID,
        x = tonumber(x) / 100,
        y = tonumber(y) / 100,
        iconType = "custom",
        size = TB.MARKER_DEFAULT_SIZE,
        color = { r = 1, g = 1, b = 1 },
        locked = false,
        category = { custom = true },
    }
end

function TB:ExportMarkers(markerList)
    local records = {}
    for _, marker in ipairs(markerList) do
        table.insert(records, SerializeMarker(marker))
    end
    return EXPORT_PREFIX .. Base64Encode(table.concat(records, "|"))
end

function TB:ExportSelected()
    local markers = {}
    for id in pairs(TB.selectedMarkerIDs or {}) do
        local marker = TB:GetMarkerByID(id)
        if marker then
            table.insert(markers, marker)
        end
    end
    if #markers == 0 then
        print("|cff33ff99TrailBeacon|r: no markers selected to export.")
        return
    end
    TB.pendingExportString = TB:ExportMarkers(markers)
    StaticPopup_Show("TRAILBEACON_EXPORT")
end

function TB:DecodeExportString(text)
    if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return {}
    end
    local payload = Base64Decode(text:sub(#EXPORT_PREFIX + 1))
    local markers = {}
    for _, record in ipairs({ strsplit("|", payload) }) do
        local marker = DeserializeMarker(record)
        if marker then
            table.insert(markers, marker)
        end
    end
    return markers
end

function TB:ImportString(text)
    text = text and strtrim(text) or ""
    if text == "" then
        return
    end

    if text:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
        local markers = TB:DecodeExportString(text)
        for _, marker in ipairs(markers) do
            TB:AddImportedMarker(marker)
        end
        print(string.format("|cff33ff99TrailBeacon|r: imported %d marker(s).", #markers))
        return
    end

    if text:match("^/way") or text:match("^#?%d") then
        local marker = ParseWayLine(text)
        if marker then
            TB:AddImportedMarker(marker)
            print("|cff33ff99TrailBeacon|r: imported 1 marker from /way.")
        else
            print("|cff33ff99TrailBeacon|r: couldn't parse that /way line.")
        end
        return
    end

    print("|cff33ff99TrailBeacon|r: unrecognized import format.")
end
