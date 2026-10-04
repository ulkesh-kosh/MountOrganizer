local addonName, ns = ...
local eventFrame = CreateFrame("Frame")

-- Build the UI if both the storage is initialized and the Blizzard_Collections addon is loaded
local function BuildUIIfReady()
    if ns.Storage.db and C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
        ns.UI:Build()
    end
end

-- Event handlers
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("NEW_MOUNT_ADDED")
eventFrame:RegisterEvent("COMPANION_UPDATE")
eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        ns.Storage:Initialize()
        ns.Macros:EnsureActionButtons()
        if C_AddOns.IsAddOnLoaded("Blizzard_ActionBar") then
            ns.Macros:InstallTooltipHook()
        end
        BuildUIIfReady()
    elseif event == "ADDON_LOADED" and loadedAddon == "Blizzard_ActionBar" then
        ns.Macros:InstallTooltipHook()
    elseif event == "ADDON_LOADED" and loadedAddon == "Blizzard_Collections" then
        BuildUIIfReady()
    elseif event == "ADDON_LOADED" and ns.UI.panel then
        ns.Layout:RefreshRegisteredPanels(MountJournal)
    elseif event == "PLAYER_LOGIN" then
        ns.Mounts:Refresh()
        ns.Macros:EnsureActionButtons()
        if C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
            ns.Macros:InstallTooltipHook()
            BuildUIIfReady()
        end
    elseif event == "PLAYER_REGEN_ENABLED" and ns.UI.panel then
        ns.Macros:SyncAll()
        ns.UI:RefreshSelectedCategory()
        ns.Layout:Schedule(MountJournal)
    elseif (event == "NEW_MOUNT_ADDED" or event == "COMPANION_UPDATE" or event == "MOUNT_JOURNAL_USABILITY_CHANGED" or event == "PLAYER_ENTERING_WORLD") and ns.UI.panel then
        ns.Mounts:Refresh()
        ns.Macros:SyncAll()
        ns.UI:RefreshAll()
    end
end)
