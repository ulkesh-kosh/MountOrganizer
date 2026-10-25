local _, ns = ...

local Macros = {}
ns.Macros = Macros

local tooltipHookInstalled
local actionButtonHooksInstalled = {}
local trackedActionButtons = {}
local SetCategoryTooltip

local actionButtonPrefixes = {
    "ActionButton",
    "MainMenuBarActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
}

function Macros:GetBody(category)
    return "/cancelform\n/click " .. ns.Mounts:EnsureCategoryActionButton(category)
end

function Macros:GetCategoryMacroIndex(category, body)
    local expectedName = "MountOrg" .. category.id
    local actionButtonName = "MountOrganizerCategoryAction_" .. category.id
    local accountCount = GetNumMacros()
    for macroIndex = 1, accountCount do
        local macroName, _, macroBody = GetMacroInfo(macroIndex)
        if (macroBody and macroBody:find(actionButtonName, 1, true)) or macroName == expectedName then
            return macroIndex, expectedName
        end
    end
    return nil, " "
end

function Macros:SyncCategory(category, createIfMissing)
    local body = self:GetBody(category)
    if #body > 255 then
        return nil, "This category exceeds WoW's 255-character macro limit."
    end
    if InCombatLockdown() then
        return nil, "Macro updates are available after combat."
    end

    local macroIndex, macroName = self:GetCategoryMacroIndex(category, body)
    if macroIndex then
        EditMacro(macroIndex, " ", category.icon or ns.Constants.DEFAULT_ICON, body)
    elseif createIfMissing then
        local created, result = pcall(CreateMacro, " ", category.icon or ns.Constants.DEFAULT_ICON, body, false)
        if created then
            macroIndex = result
        end
    else
        return nil, "No account-wide macro has been created for this category yet."
    end
    if not macroIndex then
        return nil, "No account-wide macro slots are available."
    end
    return macroIndex
end

function Macros:SyncAll()
    for _, category in ipairs(ns.Storage:GetCategories()) do
        self:SyncCategory(category, false)
    end
end

function Macros:EnsureActionButtons()
    for _, category in ipairs(ns.Storage:GetCategories()) do
        ns.Mounts:EnsureCategoryActionButton(category)
    end
end

function Macros:DeleteCategory(category)
    if InCombatLockdown() then
        return false, "Categories can be deleted after combat."
    end
    local body = self:GetBody(category)
    local macroIndex = self:GetCategoryMacroIndex(category, body)
    if macroIndex then
        DeleteMacro(macroIndex)
    end
    return true
end

function Macros:UpdateActionButton(button)
    if not button.icon then
        return
    end

    local function ResetIcon()
        button.icon:SetAlpha(1)
        button.mountOrganizerCategoryAction = nil
        button.mountOrganizerCategoryDimmed = nil
    end

    local actionSlot = button.action or (button.GetAttribute and button:GetAttribute("action"))
    if not actionSlot then
        if button.mountOrganizerCategoryAction then
            ResetIcon()
        end
        return
    end

    local actionType, macroIndex = GetActionInfo(actionSlot)
    if actionType ~= "macro" then
        if button.mountOrganizerCategoryAction then
            ResetIcon()
        end
        return
    end

    local _, _, body = GetMacroInfo(macroIndex)
    local categoryID = body and body:match("MountOrganizerCategoryAction_([A-Za-z0-9]+)")
    local category = categoryID and ns.Storage:FindCategory(categoryID)
    if not category then
        if button.mountOrganizerCategoryAction then
            ResetIcon()
        end
        return
    end

    local usable = ns.Mounts:CanUseCategory(category)
    button.mountOrganizerCategoryAction = true
    button.mountOrganizerCategoryDimmed = not usable
    button.icon:SetAlpha(usable and 1 or 0.4)
end

function Macros:RefreshActionButtons(discoverFrames)
    local refreshedButtons = {}
    local function RefreshButton(button)
        if not button or refreshedButtons[button] then
            return
        end
        refreshedButtons[button] = true
        trackedActionButtons[button] = true
        if not button.mountOrganizerTooltipHooked and button.HookScript then
            button.mountOrganizerTooltipHooked = true
            button:HookScript("OnEnter", function(self)
                local actionSlot = self.action or (self.GetAttribute and self:GetAttribute("action"))
                SetCategoryTooltip(GameTooltip, actionSlot)
            end)
        end
        self:UpdateActionButton(button)
    end

    for button in pairs(trackedActionButtons) do
        RefreshButton(button)
    end

    for _, prefix in ipairs(actionButtonPrefixes) do
        for buttonIndex = 1, 12 do
            RefreshButton(_G[prefix .. buttonIndex])
        end
    end

    if discoverFrames then
        local enumerateFrames = _G["EnumerateFrames"]
        if type(enumerateFrames) == "function" then
            local button = enumerateFrames()
            while button do
                local actionSlot = button["action"] or (button.GetAttribute and button:GetAttribute("action"))
                if button["icon"] and actionSlot then
                    RefreshButton(button)
                end
                button = enumerateFrames(button)
            end
        end
    end
end

SetCategoryTooltip = function(tooltip, actionSlot)
    if not actionSlot then
        return
    end
    local owner = tooltip:GetOwner()
    if owner and owner.icon then
        trackedActionButtons[owner] = true
        Macros:UpdateActionButton(owner)
    end

    local actionType, macroIndex = GetActionInfo(actionSlot)
    if actionType ~= "macro" then
        return
    end
    local _, _, body = GetMacroInfo(macroIndex)
    local categoryID = body and body:match("MountOrganizerCategoryAction_([A-Za-z0-9]+)")
    local category = categoryID and ns.Storage:FindCategory(categoryID)
    if category then
        tooltip:ClearLines()
        tooltip:AddLine("Random Mount", 1, 1, 1)
        tooltip:AddLine("Randomly spawn a mount from category: " .. category.name, 1, 0.82, 0.25)
        if not ns.Mounts:CanUseCategory(category) then
            tooltip:AddLine("Can only use outside", 1, 0, 0)
        end
        tooltip:Show()
    end
end

function Macros:InstallTooltipHook()
    if not tooltipHookInstalled and GameTooltip and GameTooltip.SetAction and GameTooltip.HookScript then
        tooltipHookInstalled = true
        hooksecurefunc(GameTooltip, "SetAction", SetCategoryTooltip)
        GameTooltip:HookScript("OnTooltipSetAction", function(tooltip)
            local owner = tooltip:GetOwner()
            SetCategoryTooltip(tooltip, owner and owner.action)
        end)
    end

    for _, updateFunction in ipairs({ "ActionButton_Update", "ActionButton_UpdateUsable" }) do
        if not actionButtonHooksInstalled[updateFunction] and type(_G[updateFunction]) == "function" then
            actionButtonHooksInstalled[updateFunction] = true
            hooksecurefunc(updateFunction, function(button)
                self:UpdateActionButton(button)
            end)
        end
    end
    self:RefreshActionButtons(true)
end
