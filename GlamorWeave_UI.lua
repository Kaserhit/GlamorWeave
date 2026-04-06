local _, NS = ...

NS.UI = NS.UI or {}

local UI = NS.UI

function UI.GetOutfitScrollBox()
    return TransmogFrame
        and TransmogFrame.OutfitCollection
        and TransmogFrame.OutfitCollection.OutfitList
        and TransmogFrame.OutfitCollection.OutfitList.ScrollBox
end

function UI.GetDataProvider()
    local scrollBox = UI.GetOutfitScrollBox()
    if not scrollBox then
        return nil, "ScrollBox no encontrado"
    end
    if not scrollBox.GetDataProvider then
        return nil, "ScrollBox sin GetDataProvider"
    end

    local ok, dataProvider = NS.SafeCall("GetDataProvider", function()
        return scrollBox:GetDataProvider()
    end)

    if not ok or not dataProvider then
        return nil, "DataProvider no encontrado"
    end

    return dataProvider
end

function UI.EnumerateRows()
    local dataProvider, err = UI.GetDataProvider()
    if not dataProvider then
        return nil, err
    end
    if not dataProvider.Enumerate then
        return nil, "DataProvider sin Enumerate"
    end

    local rows = {}
    local ok, enumErr = pcall(function()
        for rowIndex, elementData in dataProvider:Enumerate() do
            rows[#rows + 1] = {
                rowIndex = rowIndex,
                elementData = elementData,
            }
        end
    end)

    if not ok then
        return nil, enumErr
    end

    return rows
end

function UI.EnumerateVisibleFrames()
    local scrollBox = UI.GetOutfitScrollBox()
    if not scrollBox then
        return nil, "ScrollBox no encontrado"
    end
    if not scrollBox.EnumerateFrames then
        return nil, "ScrollBox sin EnumerateFrames"
    end

    local frames = {}
    local ok, err = pcall(function()
        for frameIndex, frame in scrollBox:EnumerateFrames() do
            frames[#frames + 1] = {
                frameIndex = frameIndex,
                frame = frame,
            }
        end
    end)

    if not ok then
        return nil, err
    end

    return frames
end

local function ReadFrameVisual(frame)
    if type(frame) ~= "table" then
        return nil
    end

    local visualName
    local uiTexture

    if frame.OutfitButton
        and frame.OutfitButton.TextContent
        and frame.OutfitButton.TextContent.Name
        and frame.OutfitButton.TextContent.Name.GetText then
        visualName = frame.OutfitButton.TextContent.Name:GetText()
    end

    if frame.OutfitIcon
        and frame.OutfitIcon.GetIconTexture then
        uiTexture = frame.OutfitIcon:GetIconTexture()
    elseif frame.OutfitIcon
        and frame.OutfitIcon.Icon
        and frame.OutfitIcon.Icon.GetTexture then
        uiTexture = frame.OutfitIcon.Icon:GetTexture()
    end

    return {
        visualName = visualName,
        uiTexture = uiTexture,
    }
end

function UI.BuildSnapshot()
    local rows, err = UI.EnumerateRows()
    if not rows then
        return nil, err
    end

    local visibleFrames = UI.EnumerateVisibleFrames()
    local visualsByOrder = {}
    if visibleFrames then
        for _, info in ipairs(visibleFrames) do
            local visual = ReadFrameVisual(info.frame)
            if visual and visual.visualName then
                visualsByOrder[#visualsByOrder + 1] = visual
            end
        end
    end

    local snapshot = {}
    for i, row in ipairs(rows) do
        local elementData = row.elementData or {}
        local visual = visualsByOrder[i]

        snapshot[#snapshot + 1] = {
            rowIndex = row.rowIndex,
            outfitID = elementData.outfitID,
            isEventOutfit = elementData.isEventOutfit == true,
            name = elementData.name,
            iconFileDataID = elementData.icon,
            situationCategories = elementData.situationCategories,
            onEditCallback = elementData.onEditCallback,
            onClickCallback = elementData.onClickCallback,
            visualName = visual and visual.visualName or nil,
            uiTexture = visual and visual.uiTexture or nil,
        }
    end

    return snapshot
end

function UI.GetEditableRows()
    local snapshot, err = UI.BuildSnapshot()
    if not snapshot then
        return nil, err
    end

    local rows = {}
    for _, row in ipairs(snapshot) do
        if not (OutfitSyncDB.settings.skipEventOutfits and row.isEventOutfit) then
            rows[#rows + 1] = row
        end
    end

    return rows
end

function UI.DumpCurrentRows()
    local rows, err = UI.GetEditableRows()
    if not rows then
        NS.Print("rows error: " .. tostring(err))
        return
    end

    NS.Print("Rows actuales:")
    for _, row in ipairs(rows) do
        NS.Print(string.format(
            "row=%s | outfitID=%s | name=%s | visual=%s | icon=%s | uiTexture=%s",
            tostring(row.rowIndex),
            tostring(row.outfitID),
            tostring(row.name),
            tostring(row.visualName),
            tostring(row.iconFileDataID),
            tostring(row.uiTexture)
        ))
    end
end

function UI.GetCurrentRow(templateIndex)
    local rows, err = UI.GetEditableRows()
    if not rows then
        return nil, err
    end

    return rows[templateIndex], nil
end

function UI.GetCurrentRowByOutfitID(outfitID)
    local rows, err = UI.GetEditableRows()
    if not rows then
        return nil, err
    end

    for _, row in ipairs(rows) do
        if tonumber(row.outfitID) == tonumber(outfitID) then
            return row, nil
        end
    end

    return nil, "No existe row actual para outfitID " .. tostring(outfitID)
end

function UI.OpenEditorForTemplateIndex(templateIndex)
    local row, err = UI.GetCurrentRow(templateIndex)
    if not row then
        NS.TechPrint("open error: " .. tostring(err or ("No existe row actual para template index " .. tostring(templateIndex))))
        return false
    end
    if not row.onEditCallback then
        NS.TechPrint("Row " .. tostring(templateIndex) .. " sin onEditCallback")
        return false
    end

    NS.Debug("Abriendo editor para current row " .. tostring(templateIndex) .. " (" .. tostring(row.name) .. ")")
    local ok = NS.SafeCall("onEditCallback", row.onEditCallback)
    return ok and true or false
end

local function TrySelectRow(row, label)
    if not row then
        return false
    end

    if not row.onClickCallback then
        NS.Debug("Row sin onClickCallback para " .. tostring(label))
        return false
    end

    NS.Debug("Seleccionando row actual " .. tostring(label))
    local ok = NS.SafeCall("onClickCallback", row.onClickCallback)
    return ok and true or false
end

function UI.SelectRowForTemplateIndex(templateIndex)
    local row, err = UI.GetCurrentRow(templateIndex)
    if not row then
        NS.TechPrint("select error: " .. tostring(err or ("No existe row actual para template index " .. tostring(templateIndex))))
        return false
    end

    return TrySelectRow(row, tostring(templateIndex) .. " (" .. tostring(row.name) .. ")")
end

function UI.SelectRowByOutfitID(outfitID)
    local row, err = UI.GetCurrentRowByOutfitID(outfitID)
    if not row then
        NS.TechPrint("select error: " .. tostring(err))
        return false
    end

    return TrySelectRow(row, "outfitID " .. tostring(outfitID) .. " (" .. tostring(row.name) .. ")")
end

function UI.TryActivateOutfit(outfitID)
    if not outfitID
        or not C_TransmogOutfitInfo
        or not C_TransmogOutfitInfo.ChangeDisplayedOutfit
        or not Enum
        or not Enum.TransmogSituationTrigger
        or not Enum.TransmogSituationTrigger.Manual then
        return false
    end

    local ok = NS.SafeCall(
        "ChangeDisplayedOutfit",
        C_TransmogOutfitInfo.ChangeDisplayedOutfit,
        outfitID,
        Enum.TransmogSituationTrigger.Manual,
        false,
        true
    )
    return ok and true or false
end

function UI.FindVisibleEditBox()
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() or nil
    if focus and focus.SetText and focus.IsShown and focus:IsShown() then
        return focus
    end
    return nil
end

function UI.SetEditorName(newName, keepFocus)
    local editBox = UI.FindVisibleEditBox()
    if not editBox then
        NS.TechPrint("No encontre EditBox visible")
        return false
    end

    local ok = NS.SafeCall("SetEditorName", function()
        editBox:SetText(newName or "")
        if keepFocus and editBox.SetFocus then
            editBox:SetFocus()
        elseif editBox.ClearFocus then
            editBox:ClearFocus()
        end
    end)

    if ok then
        NS.Debug("Nombre escrito en EditBox = " .. tostring(newName))
    end

    return ok and true or false
end

function UI.GetOutfitPopup()
    if _G.TransmogFrame and _G.TransmogFrame.OutfitPopup then
        return _G.TransmogFrame.OutfitPopup
    end
    return nil
end

function UI.GetIconSelector()
    local popup = UI.GetOutfitPopup()
    return popup and popup.IconSelector or nil
end

function UI.GetSelectedPickerTextureID()
    local popup = UI.GetOutfitPopup()
    if not popup
        or not popup.BorderBox
        or not popup.BorderBox.SelectedIconArea
        or not popup.BorderBox.SelectedIconArea.SelectedIconButton then
        return nil
    end

    local button = popup.BorderBox.SelectedIconArea.SelectedIconButton
    if button.GetIconTexture then
        local ok, texture = pcall(function()
            return button:GetIconTexture()
        end)
        if ok then
            return texture
        end
    end

    if button.Icon and button.Icon.GetTexture then
        local ok, texture = pcall(function()
            return button.Icon:GetTexture()
        end)
        if ok then
            return texture
        end
    end

    return nil
end

function UI.SetSelectedPickerTextureID(texture)
    local popup = UI.GetOutfitPopup()
    if not popup
        or not popup.BorderBox
        or not popup.BorderBox.SelectedIconArea
        or not popup.BorderBox.SelectedIconArea.SelectedIconButton then
        return false
    end

    local button = popup.BorderBox.SelectedIconArea.SelectedIconButton
    if button.SetIconTexture then
        local ok = NS.SafeCall("SetIconTexture", button.SetIconTexture, button, texture)
        if ok then
            return true
        end
    end

    if button.Icon and button.Icon.SetTexture then
        local ok = NS.SafeCall("SetTexture", button.Icon.SetTexture, button.Icon, texture)
        if ok then
            return true
        end
    end

    return false
end

function UI.GetPopupIconByIndex(index)
    local popup = UI.GetOutfitPopup()
    if not popup or not popup.GetIconByIndex then
        return nil
    end

    local ok, texture = pcall(function()
        return popup:GetIconByIndex(index)
    end)
    if ok then
        return texture
    end

    return nil
end

function UI.GetPopupIndexForTexture(texture)
    local popup = UI.GetOutfitPopup()
    if not popup or not popup.GetIndexOfIcon or not texture then
        return nil
    end

    local ok, index = pcall(function()
        return popup:GetIndexOfIcon(texture)
    end)
    if ok then
        return index
    end

    return nil
end

function UI.ScrollToSelectedIcon()
    local selector = UI.GetIconSelector()
    if selector and selector.ScrollToSelectedIndex then
        NS.SafeCall("ScrollToSelectedIndex", selector.ScrollToSelectedIndex, selector)
    end
end

function UI.RefreshSelectedIconText()
    local popup = UI.GetOutfitPopup()
    if popup and popup.SetSelectedIconText then
        NS.SafeCall("SetSelectedIconText", popup.SetSelectedIconText, popup)
    end
end

function UI.SetPopupSelectedIcon(index, texture)
    local selector = UI.GetIconSelector()
    if selector and index then
        selector.selectedIndex = index
    end

    local popup = UI.GetOutfitPopup()
    if not popup then
        return false
    end

    if index and popup.selectedIndex ~= nil then
        popup.selectedIndex = index
    end

    if popup.outfitData then
        if texture then
            popup.outfitData.icon = texture
            popup.outfitData.iconFileDataID = texture
            popup.outfitData.iconTexture = texture
        end
        if index then
            popup.outfitData.iconIndex = index
            popup.outfitData.selectedIconIndex = index
        end
    end

    return true
end

function UI.SetPopupOutfitDataIcon(texture)
    local popup = UI.GetOutfitPopup()
    if popup and popup.outfitData then
        popup.outfitData.icon = texture
        return true
    end

    return false
end

function UI.GetPopupOkayButton()
    local popup = UI.GetOutfitPopup()
    if not popup then
        return nil
    end

    if popup.BorderBox and popup.BorderBox.OkayButton then
        return popup.BorderBox.OkayButton
    end

    local seen = {}
    local found

    local function ReadText(object)
        if type(object) ~= "table" then
            return nil
        end

        if object.GetText then
            local ok, text = pcall(function()
                return object:GetText()
            end)
            if ok and text and text ~= "" then
                return text
            end
        end

        if object.Text and object.Text.GetText then
            local ok, text = pcall(function()
                return object.Text:GetText()
            end)
            if ok and text and text ~= "" then
                return text
            end
        end

        return nil
    end

    local function Visit(object, depth, keyName)
        if found or depth > 5 or type(object) ~= "table" or seen[object] then
            return
        end
        seen[object] = true

        local text = ReadText(object)
        local lowerKey = type(keyName) == "string" and string.lower(keyName) or ""
        local isOkayName = lowerKey:find("okay", 1, true) or lowerKey:find("accept", 1, true) or lowerKey:find("confirm", 1, true)
        local isOkayText = text == "Okay" or text == "OK"

        if (object.Click or object.GetScript) and (isOkayName or isOkayText) then
            found = object
            return
        end

        for key, value in pairs(object) do
            if type(value) == "table" then
                Visit(value, depth + 1, tostring(key))
                if found then
                    return
                end
            end
        end
    end

    Visit(popup, 0, "popup")
    if found then
        return found
    end

    return nil
end

function UI.ClickPopupOkay()
    local button = UI.GetPopupOkayButton()
    if button then
        local buttonName = button.GetName and button:GetName() or "nil"
        local buttonText = button.GetText and button:GetText() or (button.Text and button.Text.GetText and button.Text:GetText()) or "nil"
        local enabled = "unknown"
        if button.IsEnabled then
            local okEnabled, value = pcall(function()
                return button:IsEnabled()
            end)
            if okEnabled then
                enabled = tostring(value)
            end
        end
        NS.TechPrint("Popup Okay encontrado name=" .. tostring(buttonName) .. " text=" .. tostring(buttonText) .. " enabled=" .. tostring(enabled))

        if button.Click then
            local ok = NS.SafeCall("Popup Okay Click", button.Click, button)
            if ok then
                return true
            end

            ok = NS.SafeCall("Popup Okay Click LeftButton", button.Click, button, "LeftButton")
            if ok then
                return true
            end
        end

        if button.GetScript then
            local ok, onClick = pcall(function()
                return button:GetScript("OnClick")
            end)
            if ok and onClick then
                local okClick = NS.SafeCall("Popup Okay OnClick", onClick, button, "LeftButton")
                if okClick then
                    return true
                end
            end
        end
    end

    if UI.ClickVisibleButtonByText then
        NS.TechPrint("Intentando fallback de Popup Okay por texto visible")
        if UI.ClickVisibleButtonByText("Okay", 8) then
            return true
        end
        if UI.ClickVisibleButtonByText("OK", 8) then
            return true
        end
    end

    NS.TechPrint("No pude confirmar el popup del icono")
    return false
end

function UI.IsPopupShown()
    local popup = UI.GetOutfitPopup()
    if not popup or not popup.IsShown then
        return false
    end

    local ok, shown = pcall(function()
        return popup:IsShown()
    end)
    return ok and shown == true
end

local function ReadObjectIconTexture(object)
    if type(object) ~= "table" then
        return nil
    end

    if object.GetIconTexture then
        local ok, texture = pcall(function()
            return object:GetIconTexture()
        end)
        if ok and texture then
            return texture
        end
    end

    if object.Icon and object.Icon.GetTexture then
        local ok, texture = pcall(function()
            return object.Icon:GetTexture()
        end)
        if ok and texture then
            return texture
        end
    end

    if object.icon and object.icon.GetTexture then
        local ok, texture = pcall(function()
            return object.icon:GetTexture()
        end)
        if ok and texture then
            return texture
        end
    end

    if object.Texture and object.Texture.GetTexture then
        local ok, texture = pcall(function()
            return object.Texture:GetTexture()
        end)
        if ok and texture then
            return texture
        end
    end

    return nil
end

function UI.FindPopupIconButton(index, texture)
    local selector = UI.GetIconSelector()
    if not selector then
        return nil
    end

    local seen = {}
    local found

    local function Matches(object)
        if type(object) ~= "table" then
            return false
        end

        if object.IsShown then
            local ok, shown = pcall(function()
                return object:IsShown()
            end)
            if ok and shown ~= true then
                return false
            end
        end

        local objectTexture = ReadObjectIconTexture(object)
        if texture and tonumber(objectTexture) == tonumber(texture) then
            return true
        end

        if index and tonumber(object.index) == tonumber(index) then
            return true
        end

        if object.GetElementData then
            local ok, elementData = pcall(function()
                return object:GetElementData()
            end)
            if ok and type(elementData) == "table" then
                if index and tonumber(elementData.index) == tonumber(index) then
                    return true
                end
                if texture and tonumber(elementData.icon) == tonumber(texture) then
                    return true
                end
            end
        end

        return false
    end

    local function Visit(object, depth)
        if found or depth > 5 or type(object) ~= "table" or seen[object] then
            return
        end
        seen[object] = true

        local canClick = object.Click or (object.GetScript and object:GetScript("OnClick"))
        if canClick and Matches(object) then
            found = object
            return
        end

        for _, value in pairs(object) do
            if type(value) == "table" then
                Visit(value, depth + 1)
                if found then
                    return
                end
            end
        end
    end

    Visit(selector, 0)
    return found
end

function UI.ClickPopupIcon(index, texture)
    local button = UI.FindPopupIconButton(index, texture)
    if not button then
        return false
    end

    if button.Click then
        local ok = NS.SafeCall("PopupIcon Click", button.Click, button, "LeftButton")
        if ok then
            return true
        end
    end

    if button.GetScript then
        local ok, onClick = pcall(function()
            return button:GetScript("OnClick")
        end)
        if ok and onClick then
            local okClick = NS.SafeCall("PopupIcon OnClick", onClick, button, "LeftButton")
            if okClick then
                return true
            end
        end
    end

    return false
end

local function ReadObjectText(object)
    if type(object) ~= "table" then
        return nil
    end

    if object.GetText then
        local ok, text = pcall(function()
            return object:GetText()
        end)
        if ok and text and text ~= "" then
            return text
        end
    end

    if object.Text and object.Text.GetText then
        local ok, text = pcall(function()
            return object.Text:GetText()
        end)
        if ok and text and text ~= "" then
            return text
        end
    end

    if object.Label and object.Label.GetText then
        local ok, text = pcall(function()
            return object.Label:GetText()
        end)
        if ok and text and text ~= "" then
            return text
        end
    end

    return nil
end

local function IsObjectShown(object)
    if type(object) ~= "table" or not object.IsShown then
        return false
    end

    local ok, shown = pcall(function()
        return object:IsShown()
    end)
    return ok and shown == true
end

local function MatchesTarget(object, targetText)
    local text = ReadObjectText(object)
    if text == targetText then
        return true
    end

    if object.GetName then
        local ok, name = pcall(function()
            return object:GetName()
        end)
        if ok and type(name) == "string" then
            local lowerName = string.lower(name)
            local lowerTarget = string.lower(targetText):gsub("%s+", "")
            if lowerName:find(lowerTarget, 1, true) then
                return true
            end
        end
    end

    return false
end

local function FindVisibleFrameByText(targetText)
    if not EnumerateFrames then
        return nil
    end

    local frame = EnumerateFrames()
    while frame do
        if IsObjectShown(frame) and MatchesTarget(frame, targetText) then
            return frame
        end
        frame = EnumerateFrames(frame)
    end

    return nil
end

local function FindButtonByText(root, targetText, maxDepth, requireShown)
    local found
    local seen = {}

    local function Visit(object, depth)
        if found or depth > (maxDepth or 6) or type(object) ~= "table" or seen[object] then
            return
        end
        seen[object] = true

        if MatchesTarget(object, targetText) then
            if requireShown and object.IsShown then
                local okShown, shown = pcall(function()
                    return object:IsShown()
                end)
                if okShown and shown then
                    found = object
                    return
                end
            elseif not requireShown then
                found = object
                return
            end
        end

        for _, value in pairs(object) do
            if type(value) == "table" then
                Visit(value, depth + 1)
            end
        end
    end

    Visit(root, 0)
    return found
end

function UI.ClickVisibleButtonByText(targetText, maxDepth)
    local root = UIParent or _G.UIParent or _G.TransmogFrame
    local button = root and FindButtonByText(root, targetText, maxDepth or 7, true) or nil
    if not button then
        button = FindVisibleFrameByText(targetText)
    end
    if not button then
        NS.Debug("No encontré botón visible con texto = " .. tostring(targetText))
        return false
    end

    local buttonName = button.GetName and button:GetName() or nil
    local buttonType = button.GetObjectType and button:GetObjectType() or type(button)
    NS.Debug(
        "Botón visible encontrado text=" .. tostring(targetText) ..
        " name=" .. tostring(buttonName) ..
        " type=" .. tostring(buttonType)
    )

    if button.IsEnabled then
        local ok, enabled = pcall(function()
            return button:IsEnabled()
        end)
        if ok and not enabled then
            return false
        end
    end

    if button.Click then
        local ok = NS.SafeCall(targetText .. " Click", button.Click, button, "LeftButton")
        if ok then
            return true
        end
    end

    if button.GetScript then
        local ok, onClick = pcall(function()
            return button:GetScript("OnClick")
        end)
        if ok and onClick then
            return NS.SafeCall(targetText .. " OnClick", onClick, button, "LeftButton")
        end
    end

    return false
end

function UI.ClickApplyChangesButton()
    return UI.ClickVisibleButtonByText(NS.L("UI_TEXT_APPLY_CHANGES"), 8)
        or UI.ClickVisibleButtonByText(NS.L("UI_TEXT_APPLY_CHANGES_ES"), 8)
end

function UI.OpenSituationsTab()
    return UI.ClickVisibleButtonByText(NS.L("UI_TEXT_SITUATIONS"), 10)
        or UI.ClickVisibleButtonByText(NS.L("UI_TEXT_SITUATIONS_ES"), 10)
end

function UI.HasPendingOutfitSituations()
    if not C_TransmogOutfitInfo or not C_TransmogOutfitInfo.HasPendingOutfitSituations then
        return nil
    end

    local ok, hasPending = pcall(C_TransmogOutfitInfo.HasPendingOutfitSituations)
    if ok then
        return hasPending
    end

    return nil
end

function UI.GetOutfitSituationsEnabled()
    if not C_TransmogOutfitInfo or not C_TransmogOutfitInfo.GetOutfitSituationsEnabled then
        return nil
    end

    local ok, enabled = pcall(C_TransmogOutfitInfo.GetOutfitSituationsEnabled)
    if ok then
        return enabled == true
    end

    return nil
end

function UI.GetCurrentPickerSelectedIndex()
    local selector = UI.GetIconSelector()
    if not selector then
        NS.TechPrint("No encontre IconSelector")
        return nil
    end

    if selector.GetSelectedIndex then
        local ok, index = pcall(function()
            return selector:GetSelectedIndex()
        end)
        if ok then
            return index
        end
    end

    return selector.selectedIndex
end

function UI.GetCurrentRowVisualTexture(templateIndex)
    local row = UI.GetCurrentRow(templateIndex)
    return row and row.uiTexture or nil
end

local function CopySituationOption(option)
    option = option or {}
    return {
        situationID = tonumber(option.situationID) or 0,
        specID = tonumber(option.specID) or 0,
        loadoutID = tonumber(option.loadoutID) or 0,
        equipmentSetID = tonumber(option.equipmentSetID) or 0,
    }
end

function UI.CaptureSituationState(outfitID)
    if not C_TransmogOutfitInfo
        or not C_TransmogOutfitInfo.ChangeViewedOutfit
        or not C_TransmogOutfitInfo.GetOutfitSituationsEnabled
        or not C_TransmogOutfitInfo.GetOutfitSituation
        or not C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions then
        return nil
    end

    NS.SafeCall("ChangeViewedOutfit", C_TransmogOutfitInfo.ChangeViewedOutfit, outfitID)

    local enabledOk, situationsEnabled = pcall(C_TransmogOutfitInfo.GetOutfitSituationsEnabled)
    if not enabledOk then
        situationsEnabled = nil
    end

    local ok, categoryData = pcall(C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions)
    if not ok or type(categoryData) ~= "table" then
        return nil
    end

    local state = {}
    for _, category in ipairs(categoryData) do
        local groups = category.groupData or {}
        for _, group in ipairs(groups) do
            local options = group.optionData or {}
            for _, optionData in ipairs(options) do
                if optionData.option then
                    local valueOk, isSelected = pcall(C_TransmogOutfitInfo.GetOutfitSituation, optionData.option)
                    if not valueOk then
                        isSelected = optionData.value == true
                    end

                    if isSelected == true then
                    state[#state + 1] = {
                        categoryName = category.name,
                        optionName = optionData.name,
                        value = true,
                        option = CopySituationOption(optionData.option),
                    }
                    end
                end
            end
        end
    end

    NS.DebugTrace(
        "CaptureSituationState outfitID=" .. tostring(outfitID) ..
        " enabled=" .. tostring(situationsEnabled == true) ..
        " activeOptions=" .. tostring(#state)
    )

    return {
        enabled = situationsEnabled == true,
        options = state,
    }
end

function UI.ApplySituationState(outfitID, state, enabled, onDone)
    if not C_TransmogOutfitInfo
        or not C_TransmogOutfitInfo.ChangeViewedOutfit
        or not C_TransmogOutfitInfo.ClearAllPendingSituations
        or not C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions
        or not C_TransmogOutfitInfo.CommitAndApplyAllPending
        or not C_TransmogOutfitInfo.SetOutfitSituationsEnabled
        or not C_TransmogOutfitInfo.UpdatePendingSituation
        or not C_TransmogOutfitInfo.CommitPendingSituations then
        if onDone then onDone(false) end
        return
    end

    local wantsEnabled = enabled == true
    local optionCount = type(state) == "table" and #state or 0
    local isDisableOnly = not wantsEnabled and optionCount == 0

    NS.SafeCall("ChangeViewedOutfit", C_TransmogOutfitInfo.ChangeViewedOutfit, outfitID)

    local function CommitDesiredState(categoryData)
        NS.SafeCall("ClearAllPendingSituations", C_TransmogOutfitInfo.ClearAllPendingSituations)

        if isDisableOnly and C_TransmogOutfitInfo.ResetOutfitSituations then
            NS.SafeCall("ResetOutfitSituations", C_TransmogOutfitInfo.ResetOutfitSituations)
            NS.SafeCall("ClearAllPendingSituations", C_TransmogOutfitInfo.ClearAllPendingSituations)
        end

        if type(categoryData) == "table" then
            for _, category in ipairs(categoryData) do
                local groups = category.groupData or {}
                for _, group in ipairs(groups) do
                    local options = group.optionData or {}
                    for _, optionData in ipairs(options) do
                        if optionData.option then
                            NS.SafeCall(
                                "UpdatePendingSituation clear",
                                C_TransmogOutfitInfo.UpdatePendingSituation,
                                optionData.option,
                                false
                            )
                        end
                    end
                end
            end
        end

        if not isDisableOnly then
            for _, entry in ipairs(state or {}) do
                if entry.option then
                    NS.SafeCall(
                        "UpdatePendingSituation",
                        C_TransmogOutfitInfo.UpdatePendingSituation,
                        entry.option,
                        entry.value == true
                    )
                end
            end
        end

        NS.SafeCall("SetOutfitSituationsEnabled", C_TransmogOutfitInfo.SetOutfitSituationsEnabled, wantsEnabled)
        NS.SafeCall("CommitPendingSituations", C_TransmogOutfitInfo.CommitPendingSituations)
    end

    local ok, categoryData = pcall(C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions)
    if not ok or type(categoryData) ~= "table" then
        if onDone then onDone(false) end
        return
    end

    CommitDesiredState(categoryData)

    local function Finish(okResult)
        if onDone then
            onDone(okResult)
        end
    end

    local function PollPending(attemptsRemaining)
        local hasPending = UI.HasPendingOutfitSituations()
        local actualEnabled = UI.GetOutfitSituationsEnabled()
        local enabledMatches = actualEnabled == nil or actualEnabled == wantsEnabled
        NS.DebugTrace(
            "HasPendingOutfitSituations = " .. tostring(hasPending) ..
            " enabled=" .. tostring(actualEnabled) ..
            " wantsEnabled=" .. tostring(wantsEnabled) ..
            " enabledMatches=" .. tostring(enabledMatches) ..
            " remaining=" .. tostring(attemptsRemaining)
        )

        if hasPending == false and enabledMatches then
            Finish(true)
            return
        end

        if attemptsRemaining <= 0 then
            Finish(hasPending == false and enabledMatches)
            return
        end

        CommitDesiredState(categoryData)
        local recommitted = NS.SafeCall("CommitAndApplyAllPending", C_TransmogOutfitInfo.CommitAndApplyAllPending, false)
        NS.DebugTrace("CommitAndApplyAllPending retry = " .. tostring(recommitted))
        local reClicked = UI.ClickApplyChangesButton()
        NS.DebugTrace("ApplyChangesButton retry = " .. tostring(reClicked))

        C_Timer.After(0.25, function()
            PollPending(attemptsRemaining - 1)
        end)
    end

    C_Timer.After(0.25, function()
        local hasPending = UI.HasPendingOutfitSituations()
        local actualEnabled = UI.GetOutfitSituationsEnabled()
        local enabledMatches = actualEnabled == nil or actualEnabled == wantsEnabled
        NS.DebugTrace(
            "HasPendingOutfitSituations after initial commit = " .. tostring(hasPending) ..
            " enabled=" .. tostring(actualEnabled) ..
            " wantsEnabled=" .. tostring(wantsEnabled) ..
            " enabledMatches=" .. tostring(enabledMatches)
        )

        if hasPending or not enabledMatches then
            local opened = UI.OpenSituationsTab()
            NS.Debug("OpenSituationsTab clicked = " .. tostring(opened))

            C_Timer.After(0.30, function()
                CommitDesiredState(categoryData)
                local committed = NS.SafeCall("CommitAndApplyAllPending", C_TransmogOutfitInfo.CommitAndApplyAllPending, false)
                NS.Debug("CommitAndApplyAllPending called = " .. tostring(committed))
                local clicked = UI.ClickApplyChangesButton()
                NS.Debug("ApplyChangesButton clicked = " .. tostring(clicked))

                C_Timer.After(0.40, function()
                    PollPending(12)
                end)
            end)
            return
        end

        Finish((hasPending == false or hasPending == nil) and enabledMatches)
    end)
end
