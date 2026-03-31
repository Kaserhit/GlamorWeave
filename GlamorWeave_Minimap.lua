local _, NS = ...

NS.Minimap = NS.Minimap or {}

local MinimapButton = NS.Minimap
local ICON_TEXTURE = "Interface\\AddOns\\GlamorWeave\\wow_icon"

local function GetSettings()
    OutfitSyncDB = OutfitSyncDB or {}
    OutfitSyncDB.settings = OutfitSyncDB.settings or {}
    OutfitSyncDB.settings.minimap = OutfitSyncDB.settings.minimap or {}

    local settings = OutfitSyncDB.settings.minimap
    if settings.hide == nil then settings.hide = false end
    if settings.angle == nil then settings.angle = 220 end
    return settings
end

local function UpdatePosition()
    if not MinimapButton.button then
        return
    end

    local settings = GetSettings()
    local angle = math.rad(settings.angle or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    MinimapButton.button:ClearAllPoints()
    MinimapButton.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function GetAngleDegrees(mx, my, px, py)
    if math.atan2 then
        return math.deg(math.atan2(py - my, px - mx))
    end
    return math.deg(math.atan(py - my, px - mx))
end

function MinimapButton.Refresh()
    if not MinimapButton.button then
        return
    end

    if GetSettings().hide then
        MinimapButton.button:Hide()
    else
        MinimapButton.button:Show()
        UpdatePosition()
    end
end

function MinimapButton.Toggle()
    local settings = GetSettings()
    settings.hide = not settings.hide
    MinimapButton.Refresh()
    NS.Print(settings.hide and NS.L("MINIMAP_HIDDEN") or NS.L("MINIMAP_SHOWN"))
end

function MinimapButton.Create()
    if MinimapButton.button or not Minimap then
        return
    end

    local button = CreateFrame("Button", "GlamorWeaveMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetTexCoord(0, 1, 0, 1)

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetVertexColor(0, 0, 0, 0.6)

    button.icon = icon

    button:SetScript("OnDragStart", function(self)
        self.dragging = true
    end)

    button:SetScript("OnDragStop", function(self)
        self.dragging = nil
    end)

    button:SetScript("OnUpdate", function(self)
        if not self.dragging then
            return
        end

        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        px = px / scale
        py = py / scale

        local angle = GetAngleDegrees(mx, my, px, py)
        GetSettings().angle = angle
        UpdatePosition()
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "MiddleButton" then
            if NS.DevUI and NS.DevUI.Toggle then
                NS.DevUI.Toggle()
            end
            return
        end

        if mouseButton == "RightButton" then
            if NS.MainUI and NS.MainUI.Toggle then
                NS.MainUI.Toggle()
            end
            return
        end

        if NS.QuickAccess and NS.QuickAccess.Toggle then
            NS.QuickAccess.Toggle()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(NS.L("MINIMAP_TITLE"))
        GameTooltip:AddLine(NS.L("MINIMAP_LEFT"), 1, 1, 1)
        GameTooltip:AddLine(NS.L("MINIMAP_RIGHT"), 1, 1, 1)
        GameTooltip:AddLine(NS.L("MINIMAP_MIDDLE"), 1, 1, 1)
        GameTooltip:AddLine(NS.L("MINIMAP_DRAG"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    MinimapButton.button = button
    MinimapButton.Refresh()
end
