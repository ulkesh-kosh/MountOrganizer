local _, ns = ...

local Macros = {}
ns.Macros = Macros

local tooltipHookInstalled

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

function Macros:InstallTooltipHook()
    if tooltipHookInstalled or not GameTooltip or not GameTooltip.SetAction or not GameTooltip.HookScript then
        return
    end
    tooltipHookInstalled = true

    local function SetCategoryTooltip(tooltip, actionSlot)
        if not actionSlot then
            return
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
            tooltip:Show()
        end
    end

    hooksecurefunc(GameTooltip, "SetAction", SetCategoryTooltip)
    GameTooltip:HookScript("OnTooltipSetAction", function(tooltip)
        local owner = tooltip:GetOwner()
        SetCategoryTooltip(tooltip, owner and owner.action)
    end)
end
