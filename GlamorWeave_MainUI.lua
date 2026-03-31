local _, NS = ...

NS.MainUI = NS.MainUI or {}

local MainUI = NS.MainUI

local function GetSettings()
    OutfitSyncDB = OutfitSyncDB or {}
    OutfitSyncDB.settings = OutfitSyncDB.settings or {}
    OutfitSyncDB.settings.minimap = OutfitSyncDB.settings.minimap or {}
    return OutfitSyncDB.settings
end

local function IsTransmogUIOpen()
    return _G.TransmogFrame and _G.TransmogFrame.IsShown and _G.TransmogFrame:IsShown()
end

local function GetStatusText()
    local rows = NS.GetTemplateRows() or {}
    return string.format(NS.L("MAIN_STATUS"), #rows)
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

local function GetQuickAccessBindingText()
    if NS.GetQuickAccessBindingText then
        return NS.GetQuickAccessBindingText()
    end

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

local function CreateButton(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 140, 24)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreatePanel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(width, height)

    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()
    panel.bg:SetColorTexture(0, 0, 0, 0.18)

    panel.border = panel:CreateTexture(nil, "BORDER")
    panel.border:SetPoint("TOPLEFT")
    panel.border:SetPoint("BOTTOMRIGHT")
    panel.border:SetColorTexture(1, 0.82, 0, 0.08)

    return panel
end

local function SetCheckboxLabel(checkbox, label)
    if checkbox.text and checkbox.text.SetText then
        checkbox.text:SetText(label)
    elseif checkbox.Text and checkbox.Text.SetText then
        checkbox.Text:SetText(label)
    end
end

local function CreateCheckbox(parent, label, initialValue, onClick)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    SetCheckboxLabel(checkbox, label)
    checkbox:SetChecked(initialValue == true)
    checkbox:SetScript("OnClick", function(self)
        onClick(self:GetChecked() == true)
    end)
    return checkbox
end

local function CreateSectionTitle(parent, label)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetJustifyH("LEFT")
    title:SetText(label)
    return title
end

local function ToggleHelpPopup()
    if not MainUI.helpPopup then
        return
    end

    if MainUI.helpPopup:IsShown() then
        MainUI.helpPopup:Hide()
    else
        MainUI.helpPopup:Show()
    end
end

local function EnsureDataPopup()
    if MainUI.dataPopup or not MainUI.frame then
        return
    end

    local popup = CreateFrame("Frame", "GlamorWeaveDataPopup", MainUI.frame, "BasicFrameTemplateWithInset")
    popup:SetSize(500, 360)
    popup:SetPoint("CENTER", MainUI.frame, "CENTER", 0, 0)
    popup:SetFrameStrata("DIALOG")
    popup:Hide()
    popup.TitleText:SetText(NS.L("MAIN_DATA_TITLE"))

    local desc = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 14, -32)
    desc:SetPoint("TOPRIGHT", -14, -32)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")

    local editorPanel = CreatePanel(popup, 452, 230)
    editorPanel:SetPoint("TOPLEFT", 14, -58)

    local scrollFrame = CreateFrame("ScrollFrame", nil, editorPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)
    scrollFrame:EnableMouse(true)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(410)
    editBox:SetHeight(210)
    editBox:SetMaxLetters(0)
    editBox:EnableMouse(true)
    editBox:SetTextInsets(6, 6, 6, 6)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnMouseUp", function(self)
        self:SetFocus()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        local height = math.max(210, math.ceil((self:GetStringHeight() or 0) + 24))
        self:SetHeight(height)
        scrollFrame:UpdateScrollChildRect()
    end)
    scrollFrame:SetScrollChild(editBox)

    local actionBtn = CreateButton(popup, NS.L("MAIN_DATA_IMPORT"), 110, function()
        if popup.mode == "import" then
            local text = editBox:GetText()
            if not text or text == "" then
                NS.Print(NS.L("MAIN_IMPORT_EMPTY"))
                return
            end
            if NS.Template and NS.Template.Import then
                NS.Template.Import(text)
            end
            popup:Hide()
        elseif popup.mode == "export" then
            if NS.Template and NS.Template.Export then
                NS.Template.Export()
            end
            editBox:SetText((OutfitSyncDB and OutfitSyncDB.template and OutfitSyncDB.template.exported) or "")
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end)
    actionBtn:SetPoint("BOTTOMLEFT", 14, 12)

    local closeBtn = CreateButton(popup, NS.L("MAIN_DATA_CLOSE"), 110, function()
        popup:Hide()
    end)
    closeBtn:SetPoint("BOTTOMRIGHT", -14, 12)

    MainUI.dataPopup = popup
    MainUI.dataPopupDesc = desc
    MainUI.dataPopupEditBox = editBox
    MainUI.dataPopupAction = actionBtn
end

local function OpenExportPopup()
    EnsureDataPopup()
    if not MainUI.dataPopup then
        return
    end

    if NS.Template and NS.Template.Export then
        NS.Template.Export()
    end

    MainUI.dataPopup.mode = "export"
    MainUI.dataPopup.TitleText:SetText(NS.L("MAIN_EXPORT_POPUP_TITLE"))
    MainUI.dataPopupDesc:SetText(NS.L("MAIN_EXPORT_POPUP_DESC"))
    MainUI.dataPopupAction:SetText(NS.L("MAIN_DATA_EXPORT"))
    MainUI.dataPopupEditBox:SetText((OutfitSyncDB and OutfitSyncDB.template and OutfitSyncDB.template.exported) or "")
    MainUI.dataPopup:Show()
    MainUI.dataPopupEditBox:SetFocus()
    MainUI.dataPopupEditBox:HighlightText()
    MainUI.dataPopupEditBox:SetCursorPosition(0)
end

local function OpenImportPopup()
    EnsureDataPopup()
    if not MainUI.dataPopup then
        return
    end

    MainUI.dataPopup.mode = "import"
    MainUI.dataPopup.TitleText:SetText(NS.L("MAIN_IMPORT_POPUP_TITLE"))
    MainUI.dataPopupDesc:SetText(NS.L("MAIN_IMPORT_POPUP_DESC"))
    MainUI.dataPopupAction:SetText(NS.L("MAIN_DATA_IMPORT"))
    MainUI.dataPopupEditBox:SetText("")
    MainUI.dataPopup:Show()
    MainUI.dataPopupEditBox:SetFocus()
    MainUI.dataPopupEditBox:SetCursorPosition(0)
end

function MainUI.Refresh()
    if not MainUI.frame then
        return
    end

    local settings = GetSettings()
    local transmogOpen = IsTransmogUIOpen()
    MainUI.status:SetText(GetStatusText())
    MainUI.statusHint:SetText(NS.L(transmogOpen and "MAIN_STATUS_HINT_READY" or "MAIN_STATUS_HINT_NEED_TRANSMOG"))
    MainUI.minimapCheck:SetChecked(not (settings.minimap and settings.minimap.hide == true))
    MainUI.saveBtn:SetEnabled(transmogOpen)
    MainUI.applyAllBtn:SetEnabled(transmogOpen)
    MainUI.applyOneBtn:SetEnabled(transmogOpen)
    MainUI.keybindStatus:SetText(NS.L("MAIN_KEYBINDS_CURRENT", GetQuickAccessBindingText()))
end

function MainUI.Toggle()
    if not MainUI.frame then
        return
    end

    if MainUI.frame:IsShown() then
        if MainUI.helpPopup then
            MainUI.helpPopup:Hide()
        end
        MainUI.frame:Hide()
    else
        MainUI.Refresh()
        MainUI.frame:Show()
    end

    if NS.RefreshUIState then
        NS.RefreshUIState()
    end
end

function MainUI.Create()
    if MainUI.frame then
        return
    end

    local frame = CreateFrame("Frame", "GlamorWeaveMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(620, 486)
    frame:SetPoint("CENTER", 0, 40)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self._refreshElapsed = (self._refreshElapsed or 0) + elapsed
        if self._refreshElapsed < 0.20 then
            return
        end

        self._refreshElapsed = 0
        if self:IsShown() then
            MainUI.Refresh()
        end
    end)
    frame:Hide()

    frame.TitleText:SetText(NS.L("MAIN_TITLE"))

    local statusPanel = CreatePanel(frame, 588, 68)
    statusPanel:SetPoint("TOPLEFT", 16, -34)

    local status = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", 12, -10)
    status:SetPoint("TOPRIGHT", -12, -10)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")

    local statusHint = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusHint:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -6)
    statusHint:SetPoint("TOPRIGHT", -12, -30)
    statusHint:SetJustifyH("LEFT")
    statusHint:SetJustifyV("TOP")

    local actionsPanel = CreatePanel(frame, 588, 210)
    actionsPanel:SetPoint("TOPLEFT", statusPanel, "BOTTOMLEFT", 0, -16)

    local actionsTitle = CreateSectionTitle(actionsPanel, NS.L("MAIN_ACTIONS_TITLE"))
    actionsTitle:SetPoint("TOPLEFT", 12, -10)

    local quickBtn = CreateButton(actionsPanel, NS.L("MAIN_QUICK"), 273, function()
        if NS.QuickAccess and NS.QuickAccess.Toggle then
            NS.QuickAccess.Toggle()
        end
    end)
    quickBtn:SetPoint("TOPLEFT", 12, -32)

    local saveBtn = CreateButton(actionsPanel, NS.L("MAIN_SAVE"), 273, function()
        if NS.Template and NS.Template.SaveFromCurrentUI then
            NS.Template.SaveFromCurrentUI()
            MainUI.Refresh()
            if NS.QuickAccess and NS.QuickAccess.Refresh then
                NS.QuickAccess.Refresh()
            end
        end
    end)
    saveBtn:SetPoint("LEFT", quickBtn, "RIGHT", 18, 0)

    local applyAllBtn = CreateButton(actionsPanel, NS.L("MAIN_APPLY_ALL"), 273, function()
        if NS.Apply and NS.Apply.ApplyAll then
            NS.Apply.ApplyAll()
        end
    end)
    applyAllBtn:SetPoint("TOPLEFT", quickBtn, "BOTTOMLEFT", 0, -10)

    local keybindBtn = CreateButton(actionsPanel, NS.L("MAIN_KEYBINDS"), 273, function()
        NS.OpenQuickAccessKeybinding()
    end)
    keybindBtn:SetPoint("LEFT", applyAllBtn, "RIGHT", 18, 0)

    local slotLabel = actionsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slotLabel:SetPoint("TOPLEFT", applyAllBtn, "BOTTOMLEFT", 4, -16)
    slotLabel:SetText(NS.L("MAIN_APPLY_SLOT_LABEL"))

    local slotEdit = CreateFrame("EditBox", nil, actionsPanel, "InputBoxTemplate")
    slotEdit:SetSize(42, 20)
    slotEdit:SetPoint("LEFT", slotLabel, "RIGHT", 8, 0)
    slotEdit:SetAutoFocus(false)
    slotEdit:SetNumeric(true)
    slotEdit:SetMaxLetters(2)
    slotEdit:SetText("1")

    local applyOneBtn = CreateButton(actionsPanel, NS.L("MAIN_APPLY_ONE"), 142, function()
        local slot = tonumber(slotEdit:GetText())
        local maxSlots = NS.MAX_OUTFIT_SLOTS or 20
        if not slot or slot < 1 or slot > maxSlots then
            NS.Print(NS.L("MAIN_APPLY_SLOT_INVALID", maxSlots))
            return
        end

        if NS.Apply and NS.Apply.ApplyOne then
            NS.Apply.ApplyOne(slot)
        end
    end)
    applyOneBtn:SetPoint("LEFT", slotEdit, "RIGHT", 10, 0)

    local keybindStatus = actionsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    keybindStatus:SetPoint("TOPRIGHT", keybindBtn, "BOTTOMRIGHT", -2, -10)
    keybindStatus:SetWidth(270)
    keybindStatus:SetJustifyH("RIGHT")

    local exportBtn = CreateButton(actionsPanel, NS.L("MAIN_EXPORT"), 273, function()
        OpenExportPopup()
    end)
    exportBtn:SetPoint("TOPLEFT", 12, -130)

    local importBtn = CreateButton(actionsPanel, NS.L("MAIN_IMPORT"), 273, function()
        OpenImportPopup()
    end)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 18, 0)

    local helpBtn = CreateButton(actionsPanel, NS.L("MAIN_HELP_BUTTON"), 564, function()
        ToggleHelpPopup()
    end)
    helpBtn:SetPoint("TOPLEFT", exportBtn, "BOTTOMLEFT", 0, -16)

    local settings = GetSettings()

    local optionsPanel = CreatePanel(frame, 588, 58)
    optionsPanel:SetPoint("TOPLEFT", actionsPanel, "BOTTOMLEFT", 0, -16)

    local optionsTitle = CreateSectionTitle(optionsPanel, NS.L("MAIN_OPTIONS_TITLE"))
    optionsTitle:SetPoint("TOPLEFT", 12, -10)

    local minimapCheck = CreateCheckbox(optionsPanel, NS.L("MAIN_MINIMAP"), not (settings.minimap and settings.minimap.hide == true), function(value)
        settings.minimap.hide = not value
        MainUI.Refresh()
        if NS.Minimap and NS.Minimap.Refresh then
            NS.Minimap.Refresh()
        end
    end)
    minimapCheck:SetPoint("TOPLEFT", 6, -30)

    local footerPanel = CreatePanel(frame, 588, 44)
    footerPanel:SetPoint("TOPLEFT", optionsPanel, "BOTTOMLEFT", 0, -16)

    local footerLabel = footerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footerLabel:SetPoint("TOPLEFT", 12, -8)
    footerLabel:SetText(NS.L("MAIN_DEVTOOLS_LABEL"))

    local footerHint = footerPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerHint:SetPoint("TOPLEFT", footerLabel, "BOTTOMLEFT", 0, -2)
    footerHint:SetWidth(360)
    footerHint:SetJustifyH("LEFT")
    footerHint:SetText(NS.L("MAIN_DEVTOOLS_HINT"))

    local devBtn = CreateButton(footerPanel, NS.L("MAIN_DEVTOOLS"), 150, function()
        if NS.DevUI and NS.DevUI.Toggle then
            NS.DevUI.Toggle()
        end
    end)
    devBtn:SetPoint("RIGHT", -12, 0)

    local helpPopup = CreateFrame("Frame", "GlamorWeaveHelpPopup", frame, "BasicFrameTemplateWithInset")
    helpPopup:SetSize(352, 248)
    helpPopup:SetPoint("CENTER", frame, "CENTER", 0, 0)
    helpPopup:SetFrameStrata("DIALOG")
    helpPopup:Hide()
    helpPopup.TitleText:SetText(NS.L("MAIN_HELP_TITLE"))

    local helpIntro = helpPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpIntro:SetPoint("TOPLEFT", 14, -32)
    helpIntro:SetPoint("TOPRIGHT", -14, -32)
    helpIntro:SetJustifyH("LEFT")
    helpIntro:SetJustifyV("TOP")
    helpIntro:SetText(NS.L("MAIN_HELP_INTRO"))

    local helpBody = helpPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpBody:SetPoint("TOPLEFT", helpIntro, "BOTTOMLEFT", 0, -12)
    helpBody:SetPoint("TOPRIGHT", helpIntro, "BOTTOMRIGHT", 0, -12)
    helpBody:SetJustifyH("LEFT")
    helpBody:SetJustifyV("TOP")
    helpBody:SetText(table.concat({
        NS.L("MAIN_HELP_STEP1"),
        NS.L("MAIN_HELP_STEP2"),
        NS.L("MAIN_HELP_STEP3"),
        NS.L("MAIN_HELP_STEP4"),
        NS.L("MAIN_HELP_STEP5"),
    }, "\n"))

    local helpFooter = helpPopup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    helpFooter:SetPoint("BOTTOMLEFT", 14, 44)
    helpFooter:SetPoint("BOTTOMRIGHT", -14, 44)
    helpFooter:SetJustifyH("LEFT")
    helpFooter:SetJustifyV("TOP")
    helpFooter:SetText(NS.L("MAIN_HELP_FOOTER"))

    local helpClose = CreateButton(helpPopup, NS.L("MAIN_HELP_CLOSE"), 110, function()
        helpPopup:Hide()
    end)
    helpClose:SetPoint("BOTTOM", 0, 12)

    MainUI.frame = frame
    MainUI.status = status
    MainUI.statusHint = statusHint
    MainUI.minimapCheck = minimapCheck
    MainUI.keybindBtn = keybindBtn
    MainUI.keybindStatus = keybindStatus
    MainUI.saveBtn = saveBtn
    MainUI.applyAllBtn = applyAllBtn
    MainUI.applyOneBtn = applyOneBtn
    MainUI.exportBtn = exportBtn
    MainUI.importBtn = importBtn
    MainUI.helpPopup = helpPopup
    MainUI.OpenExportPopup = OpenExportPopup
    MainUI.OpenImportPopup = OpenImportPopup

    MainUI.Refresh()
end
