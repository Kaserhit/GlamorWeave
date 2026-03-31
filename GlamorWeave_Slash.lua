local _, NS = ...

local Apply = NS.Apply
local Template = NS.Template
local UI = NS.UI

local function GetSettingLabel(key)
    local labels = {
        debug = "STATE_DEBUG",
        debugTrace = "STATE_TRACE",
        dryRunApply = "STATE_DRYRUN",
        autoConfirm = "STATE_AUTOCONFIRM",
        autoTryIcon = "STATE_AUTOICON",
    }
    return NS.L(labels[key] or key)
end

local function ToggleSetting(key)
    OutfitSyncDB.settings[key] = not OutfitSyncDB.settings[key]
    NS.Print(NS.L("STATE_CHANGED", GetSettingLabel(key), tostring(OutfitSyncDB.settings[key])))
    if NS.RefreshUIState then
        NS.RefreshUIState()
    end
end

function NS.PrintHelp()
    NS.Print(NS.L("HELP_SAVEUI"))
    NS.Print(NS.L("HELP_DUMPUI"))
    NS.Print(NS.L("HELP_ROWS"))
    NS.Print(NS.L("HELP_EXPORT"))
    NS.Print(NS.L("HELP_IMPORT"))
    NS.Print(NS.L("HELP_APPLY"))
    NS.Print(NS.L("HELP_APPLYALL"))
    NS.Print(NS.L("HELP_CONFIRM"))
    NS.Print(NS.L("HELP_SAVEINDEX"))
    NS.Print(NS.L("HELP_DEBUG"))
    NS.Print(NS.L("HELP_TRACE"))
    NS.Print(NS.L("HELP_DRYRUN"))
    NS.Print(NS.L("HELP_AUTOCONFIRM"))
    NS.Print(NS.L("HELP_AUTOICON"))
    NS.Print(NS.L("HELP_UI"))
    NS.Print(NS.L("HELP_DEV"))
    NS.Print(NS.L("HELP_QUICK"))
    NS.Print(NS.L("HELP_MINIMAP"))
end

local function HandleApply(lower)
    local slot = tonumber(lower:match("^apply(%d+)$"))
    if not slot then
        return false
    end

    Apply.ApplyOne(slot)
    return true
end

local function HandleSaveIndex(lower)
    local slot = tonumber(lower:match("^saveindex(%d+)$"))
    if not slot then
        return false
    end

    Template.CapturePicker(slot)
    return true
end

SLASH_GLAMORWEAVE1 = "/gw"
SLASH_GLAMORWEAVE2 = "/glamorweave"
SLASH_GLAMORWEAVE3 = "/osync"
SlashCmdList.GLAMORWEAVE = function(msg)
    msg = tostring(msg or "")
    local lower = string.lower(msg)

    if lower == "saveui" then
        Template.SaveFromCurrentUI()
    elseif lower == "dumpui" then
        Template.Dump()
    elseif lower == "rows" then
        UI.DumpCurrentRows()
    elseif lower == "export" then
        Template.Export()
    elseif lower:match("^import%s+") then
        local payload = msg:match("^import%s+(.+)$")
        Template.Import(payload)
    elseif HandleApply(lower) then
    elseif lower == "applyall" then
        Apply.ApplyAll()
    elseif lower == "confirm" then
        Apply.TryConfirm()
    elseif lower == "debug" then
        ToggleSetting("debug")
    elseif lower == "trace" then
        ToggleSetting("debugTrace")
    elseif lower == "dryrun" then
        ToggleSetting("dryRunApply")
    elseif lower == "autoconfirm" then
        ToggleSetting("autoConfirm")
    elseif lower == "autoicon" then
        ToggleSetting("autoTryIcon")
    elseif lower == "ui" then
        if NS.MainUI and NS.MainUI.Toggle then
            NS.MainUI.Toggle()
        end
    elseif lower == "dev" then
        if NS.DevUI and NS.DevUI.Toggle then
            NS.DevUI.Toggle()
        end
    elseif lower == "quick" then
        if NS.QuickAccess and NS.QuickAccess.Toggle then
            NS.QuickAccess.Toggle()
        end
    elseif lower == "minimap" then
        if NS.Minimap and NS.Minimap.Toggle then
            NS.Minimap.Toggle()
        end
    elseif HandleSaveIndex(lower) then
    else
        NS.PrintHelp()
    end
end
