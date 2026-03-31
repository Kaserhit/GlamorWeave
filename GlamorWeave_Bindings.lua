local _, NS = ...

_G.BINDING_HEADER_GLAMORWEAVE = NS.L("BINDING_HEADER")
_G.BINDING_NAME_GLAMORWEAVE_TOGGLE_QUICK_ACCESS = NS.L("BINDING_TOGGLE_QUICK_ACCESS")

function GlamorWeave_ToggleQuickAccess()
    if NS and NS.QuickAccess and NS.QuickAccess.Toggle then
        NS.QuickAccess.Toggle()
    end
end

OutfitSync_ToggleQuickAccess = GlamorWeave_ToggleQuickAccess
