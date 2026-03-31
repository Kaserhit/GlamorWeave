local _, NS = ...

NS.Apply = NS.Apply or {}

local Apply = NS.Apply
local Template = NS.Template
local UI = NS.UI

local function WaitForPickerTexture(targetTexture, attempts, delay, done)
    attempts = attempts or 12
    delay = delay or 0.12

    local function Step(remaining)
        local current = UI.GetSelectedPickerTextureID()
        NS.DebugTrace(
            "WaitForPickerTexture current=" .. tostring(current) ..
            " target=" .. tostring(targetTexture) ..
            " remaining=" .. tostring(remaining)
        )

        if tonumber(current) == tonumber(targetTexture) then
            if done then done(true) end
            return
        end

        if remaining <= 0 then
            if done then done(false) end
            return
        end

        C_Timer.After(delay, function()
            Step(remaining - 1)
        end)
    end

    Step(attempts)
end

local function TrySelectIconByIndex(index, expectedPickerTexture, onDone)
    if not index then
        if expectedPickerTexture then
            local derivedIndex = UI.GetPopupIndexForTexture and UI.GetPopupIndexForTexture(expectedPickerTexture) or nil
            if derivedIndex then
                NS.TechPrint(
                    "pickerSelectedIndex derivado desde texture" ..
                    " texture=" .. tostring(expectedPickerTexture) ..
                    " index=" .. tostring(derivedIndex)
                )
                index = derivedIndex
            else
                local selected = UI.SetSelectedPickerTextureID(expectedPickerTexture)
                local popupSet = UI.SetPopupOutfitDataIcon(expectedPickerTexture)
                UI.RefreshSelectedIconText()
                NS.TechPrint(
                    "Fallback de icono sin pickerSelectedIndex" ..
                    " texture=" .. tostring(expectedPickerTexture) ..
                    " selected=" .. tostring(selected) ..
                    " popupSet=" .. tostring(popupSet)
                )
                C_Timer.After(0.20, function()
                    if onDone then onDone(selected or popupSet) end
                end)
                return
            end
        end

        if not index then
            NS.TechPrint("No hay pickerSelectedIndex para seleccionar")
            if onDone then onDone(false) end
            return
        end
    end

    local selector = UI.GetIconSelector()
    if not selector then
        NS.TechPrint("No encontre IconSelector")
        if onDone then onDone(false) end
        return
    end

    local ok = false
    if selector.SetSelectedIndex then
        local okSet = NS.SafeCall("SetSelectedIndex", selector.SetSelectedIndex, selector, index)
        if okSet then
            ok = true
        end
    end

    if not ok then
        NS.TechPrint("No pude seleccionar pickerSelectedIndex " .. tostring(index))
        if onDone then onDone(false) end
        return
    end

    UI.ScrollToSelectedIcon()

    local indexTexture = UI.GetPopupIconByIndex(index)
    local resolvedTexture = expectedPickerTexture or indexTexture
    NS.Debug(
        "Resolved picker icon index=" .. tostring(index) ..
        " indexTexture=" .. tostring(indexTexture) ..
        " resolvedTexture=" .. tostring(resolvedTexture) ..
        " expectedPickerTexture=" .. tostring(expectedPickerTexture)
    )

    if resolvedTexture then
        UI.SetSelectedPickerTextureID(resolvedTexture)
        UI.SetPopupOutfitDataIcon(resolvedTexture)
        UI.RefreshSelectedIconText()
    end

    NS.TechPrint("Indice de icono seleccionado: " .. tostring(index))
    if resolvedTexture or expectedPickerTexture then
        WaitForPickerTexture(resolvedTexture or expectedPickerTexture, 14, 0.15, function(applied)
            NS.Debug("picker texture applied = " .. tostring(applied))
            if onDone then onDone(applied) end
        end)
        return
    end

    C_Timer.After(0.20, function()
        if onDone then onDone(true) end
    end)
end

local function VerifySavedIcon(templateIndex, expectedTexture, onDone)
    local function Step(remaining)
        local actual = UI.GetCurrentRowVisualTexture(templateIndex)
        NS.DebugTrace(
            "VerifySavedIcon slot=" .. tostring(templateIndex) ..
            " expected=" .. tostring(expectedTexture) ..
            " actual=" .. tostring(actual) ..
            " remaining=" .. tostring(remaining)
        )

        if tonumber(actual) == tonumber(expectedTexture) then
            if onDone then onDone(true) end
            return
        end

        if remaining <= 0 then
            if onDone then onDone(false) end
            return
        end

        C_Timer.After(0.25, function()
            Step(remaining - 1)
        end)
    end

    C_Timer.After(0.35, function()
        Step(6)
    end)
end

local function FindOkayButton()
    local found
    local seen = {}

    local function Visit(prefix, object, depth)
        if found or depth > 5 or type(object) ~= "table" or seen[object] then
            return
        end
        seen[object] = true

        local keyLower = string.lower(prefix)
        if keyLower:find("okay") or keyLower:find("okbutton") then
            found = { path = prefix, object = object }
            return
        end

        if object.GetText then
            local ok, text = pcall(function()
                return object:GetText()
            end)
            if ok and text == "Okay" then
                found = { path = prefix, object = object }
                return
            end
        end

        for key, value in pairs(object) do
            if type(value) == "table" then
                Visit(prefix .. "." .. tostring(key), value, depth + 1)
            end
        end
    end

    if _G.TransmogFrame then
        Visit("TransmogFrame", _G.TransmogFrame, 0)
    end

    return found
end

local function TryConfirm()
    local buttonInfo = FindOkayButton()
    if not buttonInfo or not buttonInfo.object then
        NS.TechPrint("No encontre boton Okay")
        return false
    end

    NS.Debug("Okay button = " .. tostring(buttonInfo.path))

    local button = buttonInfo.object
    if button.GetScript then
        local ok, onClick = pcall(function()
            return button:GetScript("OnClick")
        end)
        if ok and onClick then
            local okClick = NS.SafeCall("Okay OnClick", onClick, button, "LeftButton")
            if okClick then
                NS.TechPrint("Confirmacion enviada")
                return true
            end
        end
    end

    if button.Click then
        local okClick = NS.SafeCall("Okay Click", button.Click, button, "LeftButton")
        if okClick then
            NS.TechPrint("Confirmacion enviada")
            return true
        end
    end

    NS.TechPrint("No pude confirmar automaticamente")
    return false
end

function Apply.ApplyOne(templateIndex, onDone)
    return Apply.ApplyOneWithOptions(templateIndex, onDone, nil)
end

function Apply.ApplyOneWithOptions(templateIndex, onDone, options)
    options = options or {}
    local batchMode = options.batchMode == true

    local row = NS.GetTemplateRow(templateIndex)
    if not row then
        NS.TechPrint("No existe template slot " .. tostring(templateIndex))
        NS.Print(NS.L("APPLY_SLOT_FAILED", tonumber(templateIndex) or 0))
        if onDone then onDone(false) end
        return
    end

    NS.Debug(
        "Apply slot=" .. tostring(templateIndex) ..
        " rawIcon=" .. tostring(row.iconFileDataID) ..
        " uiTexture=" .. tostring(row.uiTexture) ..
        " pickerTexture=" .. tostring(row.pickerSelectedTexture) ..
        " targetTexture=" .. tostring(row.targetTexture)
    )
    if not batchMode then
        NS.Print(NS.L("APPLY_PROGRESS"))
    end

    local currentTargetRow = UI.GetCurrentRow(templateIndex)
    local targetOutfitID = currentTargetRow and currentTargetRow.outfitID or nil

    if OutfitSyncDB.settings.dryRunApply then
        NS.Print(NS.L("APPLY_DRYRUN"))
        if onDone then onDone(true) end
        return
    end

    if not UI.OpenEditorForTemplateIndex(templateIndex) then
        NS.Print(NS.L("APPLY_SLOT_FAILED", templateIndex))
        if onDone then onDone(false) end
        return
    end

    C_Timer.After(0.25, function()
        UI.SetEditorName(row.name, true)
        UI.SelectRowForTemplateIndex(templateIndex)

        C_Timer.After(0.30, function()
            local function ContinueAfterIcon(iconOk)
                NS.Debug("iconOk = " .. tostring(iconOk))

                C_Timer.After(0.30, function()
                    if not OutfitSyncDB.settings.autoConfirm then
                        NS.Print(NS.L("APPLY_CONFIRM_MANUAL"))
                        if onDone then onDone(true) end
                        return
                    end

                    local confirmOk = TryConfirm()
                    NS.Debug("confirmOk = " .. tostring(confirmOk))
                    if not confirmOk then
                        NS.Print(NS.L("APPLY_CONFIRM_MANUAL"))
                        if onDone then
                            C_Timer.After(0.40, function()
                                onDone(false)
                            end)
                        end
                        return
                    end

                    local expectedSavedTexture = Template.GetExpectedSavedTexture(row)
                    local function FinishAfterSituations(baseOk)
                        if not targetOutfitID or row.situationsCaptured ~= true then
                            if onDone then
                                C_Timer.After(0.40, function()
                                    onDone(baseOk)
                                end)
                            end
                            return
                        end

                        local situationOptions = row.situationState and row.situationState.enabled == true and row.situationState.options or nil
                        local situationsEnabled = row.situationState and row.situationState.enabled == true
                        UI.ApplySituationState(targetOutfitID, situationOptions, situationsEnabled, function(situationsOk)
                            NS.Debug(
                                "situationsOk = " .. tostring(situationsOk) ..
                                " targetOutfitID=" .. tostring(targetOutfitID) ..
                                " enabled=" .. tostring(situationsEnabled) ..
                                " count=" .. tostring(type(situationOptions) == "table" and #situationOptions or 0)
                            )
                            if not situationsOk then
                                NS.Print(NS.L("APPLY_SLOT_SITUATIONS_FAILED", templateIndex))
                            end

                            if onDone then
                                C_Timer.After(0.40, function()
                                    onDone(baseOk and situationsOk)
                                end)
                            end
                        end)
                    end

                    if not expectedSavedTexture then
                        NS.Debug("Sin expectedSavedTexture; omito validacion final de icono")
                        if not batchMode then
                            NS.Print(NS.L("APPLY_SLOT_DONE", templateIndex))
                        end
                        FinishAfterSituations(true)
                        return
                    end

                    VerifySavedIcon(templateIndex, expectedSavedTexture, function(savedOk)
                        NS.Debug("savedIconOk = " .. tostring(savedOk))

                        if not savedOk then
                            NS.TechPrint("Slot " .. tostring(templateIndex) .. " guardo nombre, pero no pude verificar el icono en la UI")
                        end

                        if not batchMode then
                            NS.Print(NS.L("APPLY_SLOT_DONE", templateIndex))
                        end

                        FinishAfterSituations(savedOk)
                    end)
                end)
            end

            local pickerIndex = row.pickerSelectedIndex
            local expectedPickerTexture = Template.GetExpectedPickerTexture(row)

            if OutfitSyncDB.settings.autoTryIcon and (pickerIndex or expectedPickerTexture) then
                TrySelectIconByIndex(pickerIndex, expectedPickerTexture, ContinueAfterIcon)
            else
                ContinueAfterIcon(false)
            end
        end)
    end)
end

function Apply.ApplyAll()
    local rows = NS.GetTemplateRows()
    if not rows or #rows == 0 then
        NS.Print("No hay template guardado")
        return
    end

    NS.Print(NS.L("APPLY_ALL_STARTED"))

    local total = #rows
    local index = 1
    local appliedCount = 0
    local failedCount = 0

    local function Step()
        if index > total then
            if failedCount > 0 then
                NS.Print(NS.L("APPLY_ALL_SUMMARY_ERRORS", appliedCount, total, failedCount))
            else
                NS.Print(NS.L("APPLY_ALL_SUMMARY", appliedCount, total))
            end
            return
        end

        Apply.ApplyOneWithOptions(index, function(ok)
            if ok then
                appliedCount = appliedCount + 1
            else
                failedCount = failedCount + 1
            end
            index = index + 1
            C_Timer.After(0.60, Step)
        end, { batchMode = true })
    end

    Step()
end

function Apply.TryConfirm()
    return TryConfirm()
end
