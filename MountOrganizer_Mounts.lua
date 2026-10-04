local _, ns = ...

local Mounts = {}
ns.Mounts = Mounts

local mountCache = {}
local mountByID = {}
local iconMounts = {}

function Mounts:Refresh()
    wipe(mountCache)
    wipe(mountByID)
    wipe(iconMounts)
    local seenIcons = {}

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, spellID, icon, _, isUsable, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and spellID and name then
            local usable, useError = C_MountJournal.GetMountUsabilityByID(mountID, false)
            local mount = {
                id = mountID,
                spellID = spellID,
                name = name,
                icon = icon or ns.Constants.DEFAULT_ICON,
                usable = usable == nil and isUsable or usable,
                useError = useError,
                collected = true,
            }
            mountCache[#mountCache + 1] = mount
            mountByID[mountID] = mount
        end
    end

    table.sort(mountCache, function(left, right)
        return left.name:lower() < right.name:lower()
    end)
    for _, mount in ipairs(mountCache) do
        if not seenIcons[mount.icon] and #iconMounts < 100 then
            seenIcons[mount.icon] = true
            iconMounts[#iconMounts + 1] = mount
        end
    end
end

function Mounts:GetAll()
    return mountCache
end

function Mounts:GetByID(mountID)
    return mountByID[mountID]
end

function Mounts:GetIconMounts()
    return iconMounts
end

function Mounts:GetUsableCategoryMounts(category)
    local selectedMounts = {}
    for _, mount in ipairs(mountCache) do
        if category.mounts[mount.id] and mount.usable then
            selectedMounts[#selectedMounts + 1] = mount
        end
    end
    return selectedMounts
end

function Mounts:SummonRandom(category)
    if IsMounted() then
        C_MountJournal.Dismiss()
        return
    end
    local selectedMounts = self:GetUsableCategoryMounts(category)
    if #selectedMounts > 0 then
        local mount = selectedMounts[math.random(#selectedMounts)]
        C_MountJournal.SummonByID(mount.id)
    end
end

function Mounts:EnsureCategoryActionButton(category)
    local buttonName = "MountOrganizerCategoryAction_" .. category.id
    local button = _G[buttonName]
    if not button then
        button = CreateFrame("Button", buttonName, UIParent)
        button:SetSize(1, 1)
        button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -2, -2)
        button:SetAlpha(0)
        button:RegisterForClicks("AnyUp")
        button:SetScript("OnClick", function(self)
            local selectedCategory = ns.Storage:FindCategory(self.categoryID)
            if selectedCategory then
                Mounts:SummonRandom(selectedCategory)
            end
        end)
        button:Show()
    end
    button.categoryID = category.id
    return buttonName
end
