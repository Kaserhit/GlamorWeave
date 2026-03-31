local _, NS = ...

NS.QuickAccess = NS.QuickAccess or {}

local QuickAccess = NS.QuickAccess
local UI = NS.UI

local function IsTransmogUIOpen()
    return _G.TransmogFrame and _G.TransmogFrame.IsShown and _G.TransmogFrame:IsShown()
end

local function IsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function EnsureTransmogLoaded()
    if _G.TransmogFrame then
        return true
    end

    if _G.Transmog_LoadUI then
        NS.SafeCall("Transmog_LoadUI", _G.Transmog_LoadUI)
    end

    return _G.TransmogFrame ~= nil
end

local function EnsureTransmogVisible()
    if not EnsureTransmogLoaded() or not _G.TransmogFrame then
        return false
    end

    if _G.TransmogFrame.IsShown and _G.TransmogFrame:IsShown() then
        return true
    end

    if _G.TransmogFrame.ClearAllPoints then
        _G.TransmogFrame:ClearAllPoints()
        _G.TransmogFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local ok = NS.SafeCall("TransmogFrame Show", _G.TransmogFrame.Show, _G.TransmogFrame)
    return ok and _G.TransmogFrame.IsShown and _G.TransmogFrame:IsShown()
end

local function GetTemplateRowForEntry(entry)
    if not entry then
        return nil
    end

    local rows = NS.GetTemplateRows() or {}
    if entry.outfitID then
        for index, row in ipairs(rows) do
            if tonumber(row.outfitID) == tonumber(entry.outfitID) then
                return row, index
            end
        end
    end

    if entry.templateIndex and rows[entry.templateIndex] then
        return rows[entry.templateIndex], entry.templateIndex
    end

    return nil
end

local function TrySelectOutfit(entry)
    if not entry then
        return false
    end

    if IsCombatLocked() then
        NS.Print(NS.L("QUICK_SELECT_COMBAT"))
        return false
    end

    if not IsTransmogUIOpen() then
        NS.Print(NS.L("QUICK_SELECT_NEED_TRANSMOG"))
        return false
    end

    local _, templateIndex = GetTemplateRowForEntry(entry)
    local activated = false
    local usedFallback = false

    if entry.outfitID and UI.SelectRowByOutfitID then
        activated = UI.SelectRowByOutfitID(entry.outfitID)
        usedFallback = false
    end

    if not activated and templateIndex and UI.SelectRowForTemplateIndex then
        activated = UI.SelectRowForTemplateIndex(templateIndex)
        usedFallback = false
    end

    if not activated and entry.outfitID and UI.TryActivateOutfit then
        activated = UI.TryActivateOutfit(entry.outfitID)
        usedFallback = activated
    end

    if activated then
        if usedFallback then
            NS.Print(NS.L("QUICK_SELECT_FALLBACK", tostring(entry.name or "?")))
        else
            NS.Print(NS.L("QUICK_SELECT_SUCCESS", tostring(entry.name or "?")))
        end
        return true
    end

    if templateIndex or entry.outfitID then
        NS.Print(NS.L("QUICK_SELECT_FAILED", tostring(entry.name or "?")))
    else
        NS.Print(NS.L("QUICK_ACCESS_BLOCKED"))
    end

    return false
end

local function TrySelectOutfitWithRetries(entry, attemptsRemaining)
    if TrySelectOutfit(entry) then
        return
    end

    if attemptsRemaining <= 0 then
        return
    end

    C_Timer.After(0.20, function()
        TrySelectOutfitWithRetries(entry, attemptsRemaining - 1)
    end)
end

local function HandleEntryClick(entry)
    if not entry then
        return
    end

    if IsCombatLocked() then
        NS.Print(NS.L("QUICK_SELECT_COMBAT"))
        return
    end

    if not IsTransmogUIOpen() then
        local shown = EnsureTransmogVisible()
        if not shown then
            NS.Print(NS.L("QUICK_SELECT_NEED_TRANSMOG"))
            return
        end
    end

    TrySelectOutfitWithRetries(entry, 8)
end

local function GetStatusSummaryText()
    local bindingText = NS.GetQuickAccessBindingText and NS.GetQuickAccessBindingText() or NS.L("MAIN_KEYBINDS_UNBOUND")
    local transmogText = NS.L(IsTransmogUIOpen() and "QUICK_TRANSMOG_READY" or "QUICK_TRANSMOG_CLOSED")
    return NS.L("QUICK_STATUS_SUMMARY", bindingText, transmogText)
end

local function GetApiRows()
    if not C_TransmogOutfitInfo or not C_TransmogOutfitInfo.GetOutfitsInfo then
        return nil
    end

    local ok, outfits = pcall(C_TransmogOutfitInfo.GetOutfitsInfo)
    if not ok or type(outfits) ~= "table" or #outfits == 0 then
        return nil
    end

    local rows = {}
    local maxSlots = NS.MAX_OUTFIT_SLOTS or 20
    local templateRows = NS.GetTemplateRows() or {}

    local templateByOutfitID = {}
    for _, templateRow in ipairs(templateRows) do
        if templateRow and templateRow.outfitID then
            templateByOutfitID[tonumber(templateRow.outfitID)] = templateRow
        end
    end

    local function GetOutfitInfoByID(outfitID)
        if not outfitID or not C_TransmogOutfitInfo or not C_TransmogOutfitInfo.GetOutfitInfo then
            return nil
        end

        local ok, info = pcall(C_TransmogOutfitInfo.GetOutfitInfo, outfitID)
        if ok and type(info) == "table" then
            return info
        end

        return nil
    end

    for i, outfit in ipairs(outfits) do
        if i > maxSlots then
            break
        end

        local outfitID = tonumber(outfit.outfitID)
        local outfitInfo = GetOutfitInfoByID(outfitID)
        local templateRow = templateByOutfitID[outfitID] or templateRows[i]
        local icon = outfit.icon
            or (outfitInfo and (outfitInfo.icon or outfitInfo.iconFileDataID))
            or (templateRow and (templateRow.targetTexture or templateRow.uiTexture or templateRow.iconFileDataID))
            or 134400
        local name = outfit.name
            or (outfitInfo and outfitInfo.name)
            or (templateRow and templateRow.name)
            or ("Outfit " .. tostring(i))

        rows[#rows + 1] = {
            templateIndex = i,
            name = name,
            icon = icon,
            source = "api",
            outfitID = outfitID,
        }
    end

    return rows, "api"
end

local function GetRows()
    local rows = {}
    local source = "template"
    local maxSlots = NS.MAX_OUTFIT_SLOTS or 20

    local apiRows, apiSource = GetApiRows()
    if apiRows then
        return apiRows, apiSource
    end

    if IsTransmogUIOpen() then
        local currentRows = UI.GetEditableRows()
        if type(currentRows) == "table" and #currentRows > 0 then
            source = "ui"
            for i, row in ipairs(currentRows) do
                if i > maxSlots then
                    break
                end
                rows[#rows + 1] = {
                    templateIndex = i,
                    name = row.visualName or row.name or ("Outfit " .. tostring(i)),
                    icon = row.uiTexture or row.iconFileDataID,
                    source = source,
                    onClickCallback = row.onClickCallback,
                    outfitID = row.outfitID,
                }
            end
            return rows, source
        end
    end

    for i = 1, maxSlots do
        local row = (NS.GetTemplateRows() or {})[i]
        if row then
            rows[#rows + 1] = {
                templateIndex = i,
                name = row.name or ("Outfit " .. tostring(i)),
                icon = row.targetTexture or row.uiTexture or row.iconFileDataID,
                source = source,
                outfitID = row.outfitID,
            }
        end
    end

    return rows, source
end

local function CreateEntryButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(248, 38)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 0.85)
    button.background = background

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0, 0.12)

    local actionButton = CreateFrame("Frame", nil, button)
    actionButton:SetSize(28, 28)
    actionButton:SetPoint("LEFT", 8, 0)

    local actionBackground = actionButton:CreateTexture(nil, "BACKGROUND")
    actionBackground:SetAllPoints()
    actionBackground:SetColorTexture(0.18, 0.14, 0.05, 0.95)

    local actionBorder = actionButton:CreateTexture(nil, "BORDER")
    actionBorder:SetPoint("TOPLEFT", -1, 1)
    actionBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    actionBorder:SetColorTexture(1, 0.82, 0, 0.16)

    local icon = actionButton:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    actionButton.icon = icon
    button.icon = icon
    button.actionButton = actionButton

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", actionButton, "RIGHT", 10, 0)
    name:SetWidth(160)
    name:SetJustifyH("LEFT")
    button.name = name

    local slot = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slot:SetPoint("RIGHT", -8, 0)
    slot:SetJustifyH("RIGHT")
    button.slot = slot

    return button
end

function QuickAccess.Refresh()
    if not QuickAccess.frame then
        return
    end

    local rows, source = GetRows()
    local statusKey = "QUICK_STATUS_TEMPLATE"
    if source == "api" then
        statusKey = "QUICK_STATUS_API"
    elseif source == "ui" then
        statusKey = "QUICK_STATUS_UI"
    end
    QuickAccess.status:SetText(NS.L("QUICK_STATUS_WITH_COUNT", NS.L(statusKey), rows and #rows or 0))
    QuickAccess.summary:SetText(GetStatusSummaryText())

    if not rows or #rows == 0 then
        QuickAccess.emptyText:Show()
        QuickAccess.emptyText:SetText(NS.L("QUICK_EMPTY"))
    else
        QuickAccess.emptyText:Hide()
    end

    for _, button in ipairs(QuickAccess.buttons) do
        button:Hide()
    end

    local previous
    for i, entry in ipairs(rows) do
        local button = QuickAccess.buttons[i]
        if not button then
            button = CreateEntryButton(QuickAccess.content)
            QuickAccess.buttons[i] = button
        end

        button.entry = entry
        button.icon:SetTexture(entry.icon or 134400)
        button.name:SetText(entry.name or "?")
        button.slot:SetText(NS.L("QUICK_SLOT", entry.templateIndex or i))
        button:SetScript("OnClick", function(self)
            HandleEntryClick(self.entry)
        end)

        button:ClearAllPoints()
        if previous then
            button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -6)
        else
            button:SetPoint("TOPLEFT", 0, 0)
        end
        button:Show()
        previous = button
    end

    local height = rows and #rows > 0 and (#rows * 44) or 44
    QuickAccess.content:SetSize(248, height)
end

function QuickAccess.Toggle()
    if not QuickAccess.frame then
        return
    end

    if QuickAccess.frame:IsShown() then
        QuickAccess.frame:Hide()
    else
        QuickAccess.Refresh()
        QuickAccess.frame:Show()
    end

    if NS.RefreshUIState then
        NS.RefreshUIState()
    end
end

function QuickAccess.Create()
    if QuickAccess.frame then
        return
    end

    local frame = CreateFrame("Frame", "GlamorWeaveQuickAccessFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(298, 560)
    frame:SetPoint("LEFT", UIParent, "LEFT", 18, 0)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.TitleText:SetText(NS.L("QUICK_TITLE"))

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 16, -34)
    status:SetWidth(258)
    status:SetJustifyH("LEFT")

    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    summary:SetPoint("TOPLEFT", 16, -50)
    summary:SetWidth(258)
    summary:SetJustifyH("LEFT")

    local keybindBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    keybindBtn:SetSize(124, 22)
    keybindBtn:SetPoint("TOPLEFT", 16, -72)
    keybindBtn:SetText(NS.L("QUICK_OPEN_KEYBINDS"))
    keybindBtn:SetScript("OnClick", function()
        NS.OpenQuickAccessKeybinding()
    end)

    local panelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    panelBtn:SetSize(124, 22)
    panelBtn:SetPoint("LEFT", keybindBtn, "RIGHT", 10, 0)
    panelBtn:SetText(NS.L("QUICK_OPEN_MAIN"))
    panelBtn:SetScript("OnClick", function()
        if NS.MainUI and NS.MainUI.Toggle then
            NS.MainUI.Toggle()
        end
    end)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", keybindBtn, "BOTTOMLEFT", 0, -8)
    hint:SetWidth(258)
    hint:SetJustifyH("LEFT")
    hint:SetText(NS.L("QUICK_HINT_ROW"))

    local scrollFrame = CreateFrame("ScrollFrame", "GlamorWeaveQuickAccessScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -122)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(248, 1)
    scrollFrame:SetScrollChild(content)

    local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", 4, -4)
    emptyText:SetWidth(238)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(NS.L("QUICK_EMPTY"))

    QuickAccess.frame = frame
    QuickAccess.status = status
    QuickAccess.summary = summary
    QuickAccess.content = content
    QuickAccess.emptyText = emptyText
    QuickAccess.buttons = {}

    QuickAccess.Refresh()
end
