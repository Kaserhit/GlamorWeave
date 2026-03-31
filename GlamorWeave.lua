local ADDON_NAME, NS = ...
NS = NS or {}

NS.ADDON_NAME = ADDON_NAME
NS.DISPLAY_NAME = "GlamorWeave"
NS.PREFIX = "|cffd7b96eGlamorWeave|r: "
NS.VERSION = "0.11.1"
NS.MAX_OUTFIT_SLOTS = 20

local frame = CreateFrame("Frame")

local function GetFrameText(frameObject)
    if not frameObject then
        return nil
    end

    if frameObject.GetText then
        local text = frameObject:GetText()
        if text and text ~= "" then
            return text
        end
    end

    if frameObject.Text and frameObject.Text.GetText then
        local text = frameObject.Text:GetText()
        if text and text ~= "" then
            return text
        end
    end

    if frameObject.Label and frameObject.Label.GetText then
        local text = frameObject.Label:GetText()
        if text and text ~= "" then
            return text
        end
    end

    return nil
end

local function GetFrameName(frameObject)
    if not frameObject or not frameObject.GetName then
        return nil
    end

    local ok, name = pcall(frameObject.GetName, frameObject)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end

    return nil
end

local function FindDescendant(root, predicate, maxDepth)
    local seen = {}

    local function Visit(object, depth)
        if type(object) ~= "table" or seen[object] or depth > (maxDepth or 6) then
            return nil
        end
        seen[object] = true

        if predicate(object) then
            return object
        end

        if object.GetChildren then
            for _, child in ipairs({ object:GetChildren() }) do
                local found = Visit(child, depth + 1)
                if found then
                    return found
                end
            end
        end

        for _, value in pairs(object) do
            if type(value) == "table" then
                local found = Visit(value, depth + 1)
                if found then
                    return found
                end
            end
        end

        return nil
    end

    return Visit(root, 0)
end

local function FrameContainsDisplayName(frameObject)
    return FindDescendant(frameObject, function(candidate)
        return GetFrameText(candidate) == NS.DISPLAY_NAME
    end, 3) ~= nil
end

local function FindKeybindingSearchBox()
    if not SettingsPanel then
        return nil
    end

    local candidate = SettingsPanel.SearchBox
    if candidate and candidate.SetText then
        return candidate
    end

    candidate = SettingsPanel.Container and SettingsPanel.Container.SearchBox
    if candidate and candidate.SetText then
        return candidate
    end

    candidate = SettingsPanel.Container and SettingsPanel.Container.SettingsList and SettingsPanel.Container.SettingsList.SearchBox
    if candidate and candidate.SetText then
        return candidate
    end

    candidate = SettingsPanel.Container and SettingsPanel.Container.SettingsList and SettingsPanel.Container.SettingsList.Header and SettingsPanel.Container.SettingsList.Header.SearchBox
    if candidate and candidate.SetText then
        return candidate
    end

    return FindDescendant(SettingsPanel, function(object)
        if not object or not object.SetText then
            return false
        end

        local name = GetFrameName(object)
        return type(name) == "string" and string.find(string.lower(name), "search", 1, true) ~= nil
    end, 7)
end

local function ClearKeybindingSearchText()
    local searchBox = FindKeybindingSearchBox()
    if not searchBox or not searchBox.SetText then
        return false
    end

    local ok = NS.SafeCall("KeybindingSearch Clear", searchBox.SetText, searchBox, "")
    if not ok then
        return false
    end

    if searchBox.HighlightText then
        NS.SafeCall("KeybindingSearch HighlightText", searchBox.HighlightText, searchBox)
    end

    return true
end

local function ExpandKeybindingSection()
    if not SettingsPanel or not SettingsPanel.Container or not SettingsPanel.Container.SettingsList then
        return false
    end

    local scrollTarget = SettingsPanel.Container.SettingsList.ScrollBox and SettingsPanel.Container.SettingsList.ScrollBox.ScrollTarget
    if not scrollTarget then
        return false
    end

    for _, child in ipairs({ scrollTarget:GetChildren() }) do
        for _, grandChild in ipairs({ child:GetChildren() }) do
            if grandChild.Text and grandChild.Text.GetText and grandChild.Text:GetText() == NS.DISPLAY_NAME then
                local initializer = child.GetElementData and child:GetElementData()
                local data = initializer and initializer.data
                if data then
                    data.expanded = true
                end
                if child.CalculateHeight and child.SetHeight then
                    child:SetHeight(child:CalculateHeight())
                end
                if child.OnExpandedChanged then
                    child:OnExpandedChanged(true)
                end
                return true
            end
        end
    end

    for _, child in ipairs({ scrollTarget:GetChildren() }) do
        local label = GetFrameText(child)
        if label == NS.DISPLAY_NAME or FrameContainsDisplayName(child) then
            local initializer = child.GetElementData and child:GetElementData()
            local data = initializer and initializer.data
            if data then
                data.expanded = true
            end
            if child.CalculateHeight and child.SetHeight then
                child:SetHeight(child:CalculateHeight())
            end
            if child.OnExpandedChanged then
                child:OnExpandedChanged(true)
            end
            return true
        end
    end

    return false
end

local function NormalizeTemplateRow(row, index)
    row = row or {}
    row.templateIndex = tonumber(row.templateIndex) or index
    row.rowIndex = tonumber(row.rowIndex)
    row.outfitID = tonumber(row.outfitID)
    row.name = tostring(row.name or "")
    row.iconFileDataID = tonumber(row.iconFileDataID)
    row.uiTexture = tonumber(row.uiTexture or row.visualTexture)
    row.pickerSelectedIndex = tonumber(row.pickerSelectedIndex)
    row.pickerSelectedTexture = tonumber(row.pickerSelectedTexture)
    row.targetTexture = tonumber(row.targetTexture or row.pickerSelectedTexture or row.uiTexture or row.visualTexture)
    row.visualTexture = nil
    return row
end

function NS.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(NS.PREFIX .. tostring(msg))
end

function NS.TechPrint(msg)
    if OutfitSyncDB and OutfitSyncDB.settings and OutfitSyncDB.settings.debug then
        NS.Print(msg)
    end
end

local function FormatBindingKey(key)
    if not key then
        return nil
    end

    if GetBindingText then
        local text = GetBindingText(key, "KEY_")
        if text and text ~= "" then
            return text
        end
    end

    return key
end

function NS.GetQuickAccessBindingText()
    local key1, key2
    if GetBindingKey then
        key1, key2 = GetBindingKey("GLAMORWEAVE_TOGGLE_QUICK_ACCESS")
    end

    local parts = {}
    if key1 then
        parts[#parts + 1] = FormatBindingKey(key1)
    end
    if key2 then
        parts[#parts + 1] = FormatBindingKey(key2)
    end

    if #parts == 0 then
        return NS.L("MAIN_KEYBINDS_UNBOUND")
    end

    return table.concat(parts, " / ")
end

function NS.OpenQuickAccessKeybinding()
    if InCombatLockdown and InCombatLockdown() then
        NS.Print(NS.L("KEYBIND_COMBAT"))
        return false
    end

    if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
        local ok = NS.SafeCall(
            "Settings.OpenToCategory KEYBINDINGS",
            Settings.OpenToCategory,
            Settings.KEYBINDINGS_CATEGORY_ID,
            NS.DISPLAY_NAME
        )
        if ok then
            if C_Timer and C_Timer.After then
                for _, delay in ipairs({ 0, 0.1, 0.35, 0.8 }) do
                    C_Timer.After(delay, function()
                        ClearKeybindingSearchText()
                        ExpandKeybindingSection()
                    end)
                end
            else
                ClearKeybindingSearchText()
                ExpandKeybindingSection()
            end
            NS.Print(NS.L("KEYBIND_OPENED"))
            return true
        end
    end

    NS.Print(NS.L("KEYBIND_FALLBACK"))
    return false
end

function NS.DebugTrace(msg)
    if OutfitSyncDB and OutfitSyncDB.settings and OutfitSyncDB.settings.debug and OutfitSyncDB.settings.debugTrace then
        NS.Print(msg)
    end
end

function NS.Debug(msg)
    if OutfitSyncDB and OutfitSyncDB.settings and OutfitSyncDB.settings.debug then
        NS.Print(msg)
    end
end

function NS.SafeCall(label, fn, ...)
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then
        NS.TechPrint(label .. " error: " .. tostring(a))
        return false
    end
    return true, a, b, c, d, e
end

function NS.GetTemplateRows()
    return OutfitSyncDB and OutfitSyncDB.template and OutfitSyncDB.template.rows or nil
end

function NS.GetTemplateRow(templateIndex)
    local rows = NS.GetTemplateRows()
    return rows and rows[templateIndex] or nil
end

function NS.RefreshUIState()
    if NS.MainUI and NS.MainUI.Refresh then
        NS.MainUI.Refresh()
    end
    if NS.DevUI and NS.DevUI.Refresh then
        NS.DevUI.Refresh()
    end
    if NS.QuickAccess and NS.QuickAccess.Refresh then
        NS.QuickAccess.Refresh()
    end
    if NS.Minimap and NS.Minimap.Refresh then
        NS.Minimap.Refresh()
    end
end

function NS.NormalizeTemplateRows()
    local rows = NS.GetTemplateRows()
    if not rows then
        return
    end

    for i, row in ipairs(rows) do
        rows[i] = NormalizeTemplateRow(row, i)
    end
end

function NS.InitDB()
    OutfitSyncDB = OutfitSyncDB or {}
    OutfitSyncDB.settings = OutfitSyncDB.settings or {}

    local settings = OutfitSyncDB.settings
    if settings.debug == nil then settings.debug = false end
    if settings.debugTrace == nil then settings.debugTrace = false end
    if settings.skipEventOutfits == nil then settings.skipEventOutfits = true end
    if settings.dryRunApply == nil then settings.dryRunApply = false end
    if settings.autoConfirm == nil then settings.autoConfirm = true end
    if settings.autoTryIcon == nil then settings.autoTryIcon = true end
    settings.minimap = settings.minimap or {}
    if settings.minimap.hide == nil then settings.minimap.hide = false end
    if settings.minimap.angle == nil then settings.minimap.angle = 220 end

    OutfitSyncDB.template = OutfitSyncDB.template or {}
    OutfitSyncDB.template.version = 8
    OutfitSyncDB.template.rows = OutfitSyncDB.template.rows or {}
    OutfitSyncDB.template.exported = OutfitSyncDB.template.exported or ""

    NS.NormalizeTemplateRows()
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= ADDON_NAME then
        return
    end

    NS.InitDB()
    if NS.MainUI and NS.MainUI.Create then
        NS.MainUI.Create()
    end
    if NS.DevUI and NS.DevUI.Create then
        NS.DevUI.Create()
    end
    if NS.QuickAccess and NS.QuickAccess.Create then
        NS.QuickAccess.Create()
    end
    if NS.Minimap and NS.Minimap.Create then
        NS.Minimap.Create()
    end
    NS.Print(NS.L and NS.L("ADDON_LOADED") or "Cargado")
    if NS.PrintHelp then
        NS.PrintHelp()
    end
end)
