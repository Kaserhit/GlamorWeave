local _, NS = ...

NS.DevUI = NS.DevUI or {}

local DevUI = NS.DevUI

local function GetSettings()
    OutfitSyncDB = OutfitSyncDB or {}
    OutfitSyncDB.settings = OutfitSyncDB.settings or {}
    return OutfitSyncDB.settings
end

local function BoolLabel(value)
    return NS.L(value and "DEV_BOOL_ON" or "DEV_BOOL_OFF")
end

local function GetStatusText()
    local rows = NS.GetTemplateRows() or {}
    local settings = GetSettings()
    return string.format(
        NS.L("DEV_STATUS"),
        #rows,
        BoolLabel(settings.debug == true),
        BoolLabel(settings.debugTrace == true),
        BoolLabel(settings.autoConfirm == true),
        BoolLabel(settings.autoTryIcon == true),
        BoolLabel(settings.dryRunApply == true)
    )
end

local function CreateButton(parent, label, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, height or 22)
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

function DevUI.Refresh()
    if not DevUI.frame then
        return
    end

    local settings = GetSettings()
    DevUI.status:SetText(GetStatusText())
    DevUI.debugCheck:SetChecked(settings.debug == true)
    DevUI.traceCheck:SetChecked(settings.debugTrace == true)
    DevUI.confirmCheck:SetChecked(settings.autoConfirm == true)
    DevUI.iconCheck:SetChecked(settings.autoTryIcon == true)
    DevUI.dryRunCheck:SetChecked(settings.dryRunApply == true)
end

function DevUI.Toggle()
    if not DevUI.frame then
        return
    end

    if DevUI.frame:IsShown() then
        DevUI.frame:Hide()
    else
        DevUI.Refresh()
        DevUI.frame:Show()
    end
end

function DevUI.Create()
    if DevUI.frame then
        return
    end

    local frame = CreateFrame("Frame", "GlamorWeaveDevFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(438, 406)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.TitleText:SetText(NS.L("DEV_TITLE"))

    local statusPanel = CreatePanel(frame, 406, 60)
    statusPanel:SetPoint("TOPLEFT", 16, -32)

    local status = statusPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 10, -8)
    status:SetWidth(386)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")

    local actionsPanel = CreatePanel(frame, 406, 90)
    actionsPanel:SetPoint("TOPLEFT", statusPanel, "BOTTOMLEFT", 0, -14)

    local saveBtn = CreateButton(actionsPanel, NS.L("DEV_SAVE_UI"), 122, 22, function()
        NS.Template.SaveFromCurrentUI()
        DevUI.Refresh()
    end)
    saveBtn:SetPoint("TOPLEFT", 10, -12)

    local dumpBtn = CreateButton(actionsPanel, NS.L("DEV_DUMP_UI"), 122, 22, function()
        NS.Template.Dump()
        DevUI.Refresh()
    end)
    dumpBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)

    local applyAllBtn = CreateButton(actionsPanel, NS.L("DEV_APPLY_ALL"), 122, 22, function()
        NS.Apply.ApplyAll()
    end)
    applyAllBtn:SetPoint("LEFT", dumpBtn, "RIGHT", 10, 0)

    local exportBtn = CreateButton(actionsPanel, NS.L("DEV_EXPORT"), 122, 22, function()
        if NS.MainUI and NS.MainUI.OpenExportPopup then
            if NS.MainUI.frame and not NS.MainUI.frame:IsShown() then
                NS.MainUI.Toggle()
            end
            NS.MainUI.OpenExportPopup()
        else
            NS.Template.Export()
        end
    end)
    exportBtn:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 0, -12)

    local importBtn = CreateButton(actionsPanel, NS.L("DEV_IMPORT"), 122, 22, function()
        if NS.MainUI and NS.MainUI.OpenImportPopup then
            if NS.MainUI.frame and not NS.MainUI.frame:IsShown() then
                NS.MainUI.Toggle()
            end
            NS.MainUI.OpenImportPopup()
        end
    end)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 10, 0)

    local slotEdit = CreateFrame("EditBox", nil, actionsPanel, "InputBoxTemplate")
    slotEdit:SetSize(38, 20)
    slotEdit:SetPoint("LEFT", importBtn, "RIGHT", 12, 0)
    slotEdit:SetAutoFocus(false)
    slotEdit:SetNumeric(true)
    slotEdit:SetMaxLetters(2)
    slotEdit:SetText("1")

    local applySlotBtn = CreateButton(actionsPanel, NS.L("DEV_APPLY_SLOT"), 72, 22, function()
        local slot = tonumber(slotEdit:GetText())
        if slot then
            NS.Apply.ApplyOne(slot, function()
                DevUI.Refresh()
            end)
        end
    end)
    applySlotBtn:SetPoint("LEFT", slotEdit, "RIGHT", 10, 0)

    local settings = GetSettings()

    local togglesPanel = CreatePanel(frame, 406, 126)
    togglesPanel:SetPoint("TOPLEFT", actionsPanel, "BOTTOMLEFT", 0, -14)

    local debugCheck = CreateCheckbox(togglesPanel, NS.L("DEV_DEBUG"), settings.debug, function(value)
        settings.debug = value
        DevUI.Refresh()
    end)
    debugCheck:SetPoint("TOPLEFT", 4, -12)

    local traceCheck = CreateCheckbox(togglesPanel, NS.L("DEV_TRACE"), settings.debugTrace, function(value)
        settings.debugTrace = value
        DevUI.Refresh()
    end)
    traceCheck:SetPoint("TOPLEFT", 300, -12)

    local confirmCheck = CreateCheckbox(togglesPanel, NS.L("DEV_AUTOCONFIRM"), settings.autoConfirm, function(value)
        settings.autoConfirm = value
        DevUI.Refresh()
    end)
    confirmCheck:SetPoint("TOPLEFT", 4, -46)

    local iconCheck = CreateCheckbox(togglesPanel, NS.L("DEV_AUTOICON"), settings.autoTryIcon, function(value)
        settings.autoTryIcon = value
        DevUI.Refresh()
    end)
    iconCheck:SetPoint("TOPLEFT", 4, -80)

    local dryRunCheck = CreateCheckbox(togglesPanel, NS.L("DEV_DRYRUN"), settings.dryRunApply, function(value)
        settings.dryRunApply = value
        DevUI.Refresh()
    end)
    dryRunCheck:SetPoint("TOPLEFT", 300, -46)

    local help = togglesPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOMRIGHT", -16, 16)
    help:SetWidth(170)
    help:SetJustifyH("RIGHT")
    help:SetText(NS.L("DEV_HELP"))

    DevUI.frame = frame
    DevUI.status = status
    DevUI.debugCheck = debugCheck
    DevUI.traceCheck = traceCheck
    DevUI.confirmCheck = confirmCheck
    DevUI.iconCheck = iconCheck
    DevUI.dryRunCheck = dryRunCheck
    DevUI.exportBtn = exportBtn
    DevUI.importBtn = importBtn

    DevUI.Refresh()
end
