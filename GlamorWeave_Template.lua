local _, NS = ...

NS.Template = NS.Template or {}

local Template = NS.Template
local UI = NS.UI

local function NormalizeSituationState(state)
    if type(state) ~= "table" then
        return nil
    end

    local normalized = {
        enabled = state.enabled == true,
        options = {},
    }

    if normalized.enabled and type(state.options) == "table" then
        for _, entry in ipairs(state.options) do
            if type(entry) == "table" and entry.option then
                normalized.options[#normalized.options + 1] = entry
            end
        end
    end

    return normalized
end

local function DescribeSituationState(state)
    state = NormalizeSituationState(state)
    if not state then
        return "n/a"
    end
    if not state.enabled then
        return "disabled"
    end
    if #state.options == 0 then
        return "enabled: none"
    end

    local labels = {}
    for _, entry in ipairs(state.options) do
        local categoryName = tostring(entry.categoryName or "category")
        local optionName = entry.optionName
        if not optionName and entry.option then
            optionName = string.format(
                "%s/%s/%s/%s",
                tostring(entry.option.situationID or 0),
                tostring(entry.option.specID or 0),
                tostring(entry.option.loadoutID or 0),
                tostring(entry.option.equipmentSetID or 0)
            )
        end
        labels[#labels + 1] = categoryName .. "=" .. tostring(optionName or "?")
    end

    return table.concat(labels, ", ")
end

local function EncodeSituationState(state)
    state = NormalizeSituationState(state)
    if type(state) ~= "table" or type(state.options) ~= "table" or #state.options == 0 then
        return ""
    end

    local parts = {}
    for _, entry in ipairs(state.options) do
        local option = entry.option or {}
        parts[#parts + 1] = table.concat({
            tostring(tonumber(option.situationID) or 0),
            tostring(tonumber(option.specID) or 0),
            tostring(tonumber(option.loadoutID) or 0),
            tostring(tonumber(option.equipmentSetID) or 0),
            entry.value == true and "1" or "0",
        }, "~")
    end

    return table.concat(parts, ";")
end

local function DecodeSituationState(raw)
    if type(raw) ~= "string" or raw == "" then
        return nil
    end

    local state = {}
    for situationID, specID, loadoutID, equipmentSetID, value in raw:gmatch("([^~;]+)~([^~;]+)~([^~;]+)~([^~;]+)~([^~;]+)") do
        state[#state + 1] = {
            value = value == "1",
            option = {
                situationID = tonumber(situationID) or 0,
                specID = tonumber(specID) or 0,
                loadoutID = tonumber(loadoutID) or 0,
                equipmentSetID = tonumber(equipmentSetID) or 0,
            },
        }
    end

    if #state == 0 then
        return nil
    end

    return {
        enabled = true,
        options = state,
    }
end

local function EscapeString(value)
    value = tostring(value or "")
    return (value:gsub("([%%%c\\\"])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function BuildTemplateRow(currentRow, previousRow, templateIndex)
    previousRow = previousRow or {}

    local pickerSelectedIndex = previousRow.pickerSelectedIndex
    local pickerSelectedTexture = tonumber(previousRow.pickerSelectedTexture or currentRow.iconFileDataID or currentRow.uiTexture)
    local uiTexture = tonumber(currentRow.uiTexture)
    local targetTexture = pickerSelectedTexture or uiTexture
    local capturedSituationState = UI.CaptureSituationState(currentRow.outfitID)
    local situationState = NormalizeSituationState(capturedSituationState or previousRow.situationState)
    local situationsCaptured = capturedSituationState ~= nil or previousRow.situationsCaptured == true

    return {
        templateIndex = templateIndex,
        rowIndex = currentRow.rowIndex,
        outfitID = currentRow.outfitID,
        name = currentRow.visualName or currentRow.name,
        iconFileDataID = currentRow.iconFileDataID,
        uiTexture = uiTexture,
        targetTexture = targetTexture,
        pickerSelectedIndex = pickerSelectedIndex,
        pickerSelectedTexture = pickerSelectedTexture,
        situationCategories = currentRow.situationCategories,
        situationState = situationState,
        situationsCaptured = situationsCaptured,
    }
end

function Template.SaveFromCurrentUI()
    local rows, err = UI.GetEditableRows()
    if not rows then
        NS.Print("saveui error: " .. tostring(err))
        return
    end

    local previousRows = {}
    for i, row in ipairs(NS.GetTemplateRows() or {}) do
        previousRows[i] = row
    end

    wipe(OutfitSyncDB.template.rows)
    for i, row in ipairs(rows) do
        if i > (NS.MAX_OUTFIT_SLOTS or 20) then
            break
        end
        OutfitSyncDB.template.rows[i] = BuildTemplateRow(row, previousRows[i], i)
    end

    NS.NormalizeTemplateRows()
    if NS.RefreshUIState then
        NS.RefreshUIState()
    end
    NS.Print("Template guardado: " .. tostring(#OutfitSyncDB.template.rows) .. " rows")
end

function Template.Dump()
    local rows = NS.GetTemplateRows()
    if not rows or #rows == 0 then
        NS.Print("No hay template guardado")
        return
    end

    NS.Print("Template actual:")
    for i, row in ipairs(rows) do
        NS.Print(string.format(
            "  %d) %s | outfitID=%s | icon=%s | uiTex=%s | targetTex=%s | pickerIndex=%s | pickerTex=%s | situations=%s | situationsEnabled=%s | situationsCaptured=%s | situationNames=%s",
            i,
            tostring(row.name),
            tostring(row.outfitID),
            tostring(row.iconFileDataID),
            tostring(row.uiTexture),
            tostring(row.targetTexture),
            tostring(row.pickerSelectedIndex),
            tostring(row.pickerSelectedTexture),
            tostring(row.situationState and row.situationState.options and #row.situationState.options or 0),
            tostring(row.situationState and row.situationState.enabled == true),
            tostring(row.situationsCaptured == true),
            DescribeSituationState(row.situationState)
        ))
    end
end

function Template.Export()
    local rows = NS.GetTemplateRows()
    if not rows or #rows == 0 then
        NS.Print("No hay template guardado")
        return
    end

    local parts = {
        "{",
        "\"version\":8,",
        "\"rows\":[",
    }

    for i, row in ipairs(rows) do
        parts[#parts + 1] = string.format(
            "{\"templateIndex\":%d,\"name\":\"%s\",\"iconFileDataID\":%s,\"uiTexture\":%s,\"targetTexture\":%s,\"pickerSelectedIndex\":%s,\"pickerSelectedTexture\":%s,\"situationsCaptured\":%s,\"situationsEnabled\":%s,\"situationState\":\"%s\",\"outfitID\":%s}",
            tonumber(row.templateIndex) or i,
            EscapeString(row.name),
            tostring(tonumber(row.iconFileDataID) or "null"),
            tostring(tonumber(row.uiTexture) or "null"),
            tostring(tonumber(row.targetTexture) or "null"),
            tostring(tonumber(row.pickerSelectedIndex) or "null"),
            tostring(tonumber(row.pickerSelectedTexture) or "null"),
            row.situationsCaptured == true and "true" or "false",
            row.situationState and row.situationState.enabled == true and "true" or "false",
            EscapeString(EncodeSituationState(row.situationState)),
            tostring(tonumber(row.outfitID) or "null")
        )
        if i < #rows then
            parts[#parts + 1] = ","
        end
    end

    parts[#parts + 1] = "]}"
    OutfitSyncDB.template.exported = table.concat(parts)

    NS.Print("Export generado:")
    NS.Print(OutfitSyncDB.template.exported)
end

local function UnescapeName(name)
    name = tostring(name or "")
    name = name:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    name = name:gsub("\\n", "\n")
    name = name:gsub("\\\"", "\"")
    name = name:gsub("\\\\", "\\")
    return name
end

function Template.Import(raw)
    if type(raw) ~= "string" or raw == "" then
        NS.Print("import error: string vacia")
        return
    end

    raw = raw:match("^%s*(.-)%s*$")

    local rows = {}

    for templateIndex, name, iconFileDataID, uiTexture, targetTexture, pickerSelectedIndex, pickerSelectedTexture, situationsCaptured, situationsEnabled, situationState, outfitID in raw:gmatch(
        "{\"templateIndex\":(%d+),\"name\":\"(.-)\",\"iconFileDataID\":(.-),\"uiTexture\":(.-),\"targetTexture\":(.-),\"pickerSelectedIndex\":(.-),\"pickerSelectedTexture\":(.-),\"situationsCaptured\":(.-),\"situationsEnabled\":(.-),\"situationState\":\"(.-)\",\"outfitID\":(.-)}"
    ) do
        local decodedSituationState = DecodeSituationState(UnescapeName(situationState))
        if situationsCaptured == "true" and not decodedSituationState then
            decodedSituationState = {
                enabled = situationsEnabled == "true",
                options = {},
            }
        elseif decodedSituationState then
            decodedSituationState.enabled = situationsEnabled == "true"
        end

        rows[#rows + 1] = {
            templateIndex = tonumber(templateIndex),
            name = UnescapeName(name),
            iconFileDataID = tonumber(iconFileDataID),
            uiTexture = tonumber(uiTexture),
            targetTexture = tonumber(targetTexture),
            pickerSelectedIndex = tonumber(pickerSelectedIndex),
            pickerSelectedTexture = tonumber(pickerSelectedTexture),
            situationsCaptured = situationsCaptured == "true",
            situationState = decodedSituationState,
            outfitID = tonumber(outfitID),
        }
    end

    if #rows == 0 then
        for templateIndex, name, iconFileDataID, visualTexture, pickerSelectedIndex, pickerSelectedTexture, outfitID in raw:gmatch(
            "{\"templateIndex\":(%d+),\"name\":\"(.-)\",\"iconFileDataID\":(.-),\"visualTexture\":(.-),\"pickerSelectedIndex\":(.-),\"pickerSelectedTexture\":(.-),\"outfitID\":(.-)}"
        ) do
            local resolvedPickerTexture = tonumber(pickerSelectedTexture)
            local resolvedUITexture = tonumber(visualTexture)
            rows[#rows + 1] = {
                templateIndex = tonumber(templateIndex),
                name = UnescapeName(name),
                iconFileDataID = tonumber(iconFileDataID),
                uiTexture = resolvedUITexture,
                targetTexture = resolvedPickerTexture or resolvedUITexture,
                pickerSelectedIndex = tonumber(pickerSelectedIndex),
                pickerSelectedTexture = resolvedPickerTexture,
                situationsCaptured = false,
                situationState = nil,
                outfitID = tonumber(outfitID),
            }
        end
    end

    if #rows == 0 then
        for templateIndex, name, iconFileDataID, pickerSelectedIndex, outfitID in raw:gmatch(
            "{\"templateIndex\":(%d+),\"name\":\"(.-)\",\"iconFileDataID\":(.-),\"pickerSelectedIndex\":(.-),\"outfitID\":(.-)}"
        ) do
            rows[#rows + 1] = {
                templateIndex = tonumber(templateIndex),
                name = UnescapeName(name),
                iconFileDataID = tonumber(iconFileDataID),
                pickerSelectedIndex = tonumber(pickerSelectedIndex),
                situationsCaptured = false,
                situationState = nil,
                outfitID = tonumber(outfitID),
            }
        end
    end

    if #rows == 0 then
        for templateIndex, name, iconFileDataID, outfitID in raw:gmatch(
            "{\"templateIndex\":(%d+),\"name\":\"(.-)\",\"iconFileDataID\":(.-),\"outfitID\":(.-)}"
        ) do
            rows[#rows + 1] = {
                templateIndex = tonumber(templateIndex),
                name = UnescapeName(name),
                iconFileDataID = tonumber(iconFileDataID),
                situationsCaptured = false,
                situationState = nil,
                outfitID = tonumber(outfitID),
            }
        end
    end

    if #rows == 0 then
        NS.Print("import error: no pude parsear rows")
        return
    end

    OutfitSyncDB.template.version = 8
    OutfitSyncDB.template.rows = rows
    OutfitSyncDB.template.exported = raw
    NS.NormalizeTemplateRows()
    if NS.RefreshUIState then
        NS.RefreshUIState()
    end

    NS.Print("Import completado: " .. tostring(#rows) .. " rows")
end

function Template.CapturePicker(templateIndex)
    local row = NS.GetTemplateRow(templateIndex)
    if not row then
        NS.Print("No existe template slot " .. tostring(templateIndex))
        return
    end

    local pickerIndex = UI.GetCurrentPickerSelectedIndex()
    if not pickerIndex then
        NS.Print("No pude capturar pickerSelectedIndex")
        return
    end

    local pickerTexture = tonumber(UI.GetSelectedPickerTextureID())
    local currentListTexture = tonumber(UI.GetCurrentRowVisualTexture(templateIndex))

    row.pickerSelectedIndex = pickerIndex
    row.pickerSelectedTexture = pickerTexture
    if currentListTexture then
        row.uiTexture = currentListTexture
    end
    row.targetTexture = pickerTexture or currentListTexture or row.targetTexture or row.uiTexture

    NS.Print(
        "Slot " .. tostring(templateIndex) ..
        " pickerIndex=" .. tostring(row.pickerSelectedIndex) ..
        " | pickerTexture=" .. tostring(row.pickerSelectedTexture) ..
        " | targetTexture=" .. tostring(row.targetTexture)
    )
    if NS.RefreshUIState then
        NS.RefreshUIState()
    end
end

function Template.GetExpectedPickerTexture(row)
    if not row then
        return nil
    end

    return row.pickerSelectedTexture or row.targetTexture or row.uiTexture or nil
end

function Template.GetExpectedSavedTexture(row)
    if not row then
        return nil
    end

    return row.targetTexture or row.pickerSelectedTexture or row.uiTexture or nil
end
