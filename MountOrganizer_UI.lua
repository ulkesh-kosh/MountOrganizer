local _, ns = ...

local UI = {}
ns.UI = UI

local panel
local categoryScroll
local categoryContent
local memberScroll
local memberContent
local nameInput
local iconButton
local iconPicker
local actionButton
local actionStatus
local memberStatus
local categorySaveButton
local iconPickerCloseButton
local editingCategory
local selectedCategory
local currentIcon
local categoryRows = {}
local memberRows = {}
local iconButtons = {}

local RefreshCategoryMembers
local RefreshSelectedCategory
local SelectCategory

local function ScrollFrameByWheel(scroll, delta)
    local maxScroll = math.max(0, scroll:GetScrollChild():GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, scroll:GetVerticalScroll() - delta * 26)))
end

local function CreateScroll(parent, top, bottom)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, top)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -28, bottom)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self)
        content:SetWidth(self:GetWidth())
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        ScrollFrameByWheel(self, delta)
    end)
    content:EnableMouseWheel(true)
    content:SetScript("OnMouseWheel", function(_, delta)
        ScrollFrameByWheel(scroll, delta)
    end)
    return scroll, content
end

local function RefreshCategoryRows()
    local categories = ns.Storage:GetCategories()
    for index, category in ipairs(categories) do
        local row = categoryRows[index]
        if not row then
            row = CreateFrame("Button", nil, categoryContent)
            row:SetHeight(28)
            row.selection = row:CreateTexture(nil, "BACKGROUND")
            row.selection:SetAllPoints(row)
            row.selection:SetColorTexture(0.12, 0.36, 0.30, 0.8)
            row.selection:Hide()
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            row.label:SetJustifyH("LEFT")
            row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta)
                ScrollFrameByWheel(categoryScroll, delta)
            end)
            row:SetScript("OnClick", function(self)
                SelectCategory(self.category)
                RefreshCategoryRows()
                RefreshCategoryMembers()
                memberScroll:SetVerticalScroll(0)
                RefreshSelectedCategory()
            end)
            categoryRows[index] = row
        end
        local count = 0
        for _ in pairs(category.mounts) do
            count = count + 1
        end
        row.category = category
        row:SetPoint("TOPLEFT", categoryContent, "TOPLEFT", 0, -(index - 1) * 28)
        row:SetPoint("RIGHT", categoryContent, "RIGHT", 0, 0)
        row.icon:SetTexture(category.icon or ns.Constants.DEFAULT_ICON)
        if category == selectedCategory then
            row.selection:Show()
        else
            row.selection:Hide()
        end
        row.label:SetText(category.name .. "  |cff888888(" .. count .. ")|r")
        row.label:SetTextColor(category == selectedCategory and 1 or 0.85, category == selectedCategory and 0.82 or 0.85, category == selectedCategory and 0.25 or 0.85)
        row:Show()
    end
    for index = #categories + 1, #categoryRows do
        categoryRows[index]:Hide()
    end
    categoryContent:SetHeight(math.max(1, #categories * 28))
    categoryScroll:UpdateScrollChildRect()
end

RefreshCategoryMembers = function()
    if not selectedCategory then
        for _, row in ipairs(memberRows) do
            row:Hide()
        end
        memberContent:SetHeight(1)
        memberStatus:SetText("Select a mount in the Mount Journal, then add it here.")
        return
    end

    local entries = {}
    for mountID in pairs(selectedCategory.mounts) do
        local mount = ns.Mounts:GetByID(mountID)
        entries[#entries + 1] = {
            id = mountID,
            name = mount and mount.name or ("Mount " .. mountID .. " (not collected)"),
            icon = mount and mount.icon or ns.Constants.DEFAULT_ICON,
            usable = mount and mount.usable == true,
        }
    end
    table.sort(entries, function(left, right)
        return left.name:lower() < right.name:lower()
    end)

    local rowIndex = 0
    for _, entry in ipairs(entries) do
        rowIndex = rowIndex + 1
        local row = memberRows[rowIndex]
        if not row then
            row = CreateFrame("Frame", nil, memberContent)
            row:SetHeight(27)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
            row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.remove:SetSize(72, 20)
            row.remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.remove:SetText("Remove")
            row.remove:EnableMouseWheel(true)
            row.remove:SetScript("OnMouseWheel", function(_, delta)
                ScrollFrameByWheel(memberScroll, delta)
            end)
            row.remove:SetScript("OnClick", function(self)
                if selectedCategory then
                    selectedCategory.mounts[self.mountID] = nil
                    RefreshCategoryRows()
                    RefreshCategoryMembers()
                    RefreshSelectedCategory()
                end
            end)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
            row.label:SetPoint("RIGHT", row.remove, "LEFT", -5, 0)
            row.label:SetJustifyH("LEFT")
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta)
                ScrollFrameByWheel(memberScroll, delta)
            end)
            memberRows[rowIndex] = row
        end
        row:SetPoint("TOPLEFT", memberContent, "TOPLEFT", 0, -(rowIndex - 1) * 27)
        row:SetPoint("RIGHT", memberContent, "RIGHT", 0, 0)
        row.icon:SetTexture(entry.icon)
        row.label:SetText(entry.usable and entry.name or (entry.name .. "  |cffff5555Unavailable|r"))
        row.label:SetTextColor(entry.usable and 1 or 0.65, entry.usable and 1 or 0.45, entry.usable and 1 or 0.45)
        row.remove.mountID = entry.id
        row:Show()
    end
    for index = rowIndex + 1, #memberRows do
        memberRows[index]:Hide()
    end
    memberContent:SetHeight(math.max(1, rowIndex * 27))
    memberScroll:UpdateScrollChildRect()
    memberStatus:SetText("Select a mount in the Mount Journal, then add it here.")
end

RefreshSelectedCategory = function()
    if not selectedCategory then
        actionMacroIndex = nil
        actionButton.icon:SetTexture(ns.Constants.DEFAULT_ICON)
        actionStatus:SetText("Create a category, then select its mounts.")
        return
    end

    actionButton.icon:SetTexture(selectedCategory.icon or ns.Constants.DEFAULT_ICON)
    local mounts = ns.Mounts:GetUsableCategoryMounts(selectedCategory)
    if #mounts == 0 then
        actionMacroIndex = nil
        actionStatus:SetText(next(selectedCategory.mounts) and "No mounts in this category are usable by this character." or "Select a usable mount in the Mount Journal and add it here.")
        return
    end
    local macroIndex, status = ns.Macros:SyncCategory(selectedCategory, true)
    actionMacroIndex = macroIndex
    if macroIndex then
        actionStatus:SetText("Click to summon, or drag the icon to your hotbar.")
    else
        actionStatus:SetText(status .. " The on-panel button still works.")
    end
end

local function RefreshIconPicker()
    for index, mount in ipairs(ns.Mounts:GetIconMounts()) do
        local button = iconButtons[index]
        if not button then
            button = CreateFrame("Button", nil, iconPicker.content)
            button:SetSize(30, 30)
            button:EnableMouseWheel(true)
            button:SetScript("OnMouseWheel", function(_, delta)
                ScrollFrameByWheel(iconPicker.scroll, delta)
            end)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetAllPoints()
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            button:SetScript("OnClick", function(self)
                currentIcon = self.mountIcon
                iconButton.icon:SetTexture(currentIcon)
                iconPicker:Hide()
            end)
            iconButtons[index] = button
        end
        local column = (index - 1) % 6
        local row = math.floor((index - 1) / 6)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", iconPicker.content, "TOPLEFT", 8 + column * 36, -8 - row * 36)
        button.mountIcon = mount.icon
        button.icon:SetTexture(mount.icon)
        button:Show()
    end
    local iconMountCount = #ns.Mounts:GetIconMounts()
    for index = iconMountCount + 1, #iconButtons do
        iconButtons[index]:Hide()
    end
    iconPicker.content:SetHeight(math.max(1, math.ceil(iconMountCount / 6) * 36 + 8))
    iconPicker.scroll:UpdateScrollChildRect()
end

local function HideIconPicker()
    iconPicker:Hide()
end

SelectCategory = function(category)
    selectedCategory = category
    editingCategory = category
    if category then
        nameInput:SetText(category.name)
        currentIcon = category.icon or ns.Constants.DEFAULT_ICON
        iconButton.icon:SetTexture(currentIcon)
        categorySaveButton:SetText("Update")
    else
        nameInput:SetText("")
        currentIcon = ns.Mounts:GetAll()[1] and ns.Mounts:GetAll()[1].icon or ns.Constants.DEFAULT_ICON
        iconButton.icon:SetTexture(currentIcon)
        categorySaveButton:SetText("Create")
    end
end

-- Build the UI
function UI:Build()
    if self.panel or not MountJournal then
        return -- if already built, or if MountJournal doesn't exist yet, do nothing
    end

    -- main panel
    panel = CreateFrame("Frame", "MountOrganizerPanel", MountJournal, "BackdropTemplate")
    self.panel = panel
    panel:SetWidth(360)
    panel:SetPoint("TOPLEFT", MountJournal, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMLEFT", MountJournal, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameStrata("LOW")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    -- Main title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 13, -10)
    title:SetText("Mount Organizer")
    local titleIcon = panel:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(20, 20)
    titleIcon:SetPoint("RIGHT", title, "LEFT", -6, 0)
    titleIcon:SetTexture("Interface\\AddOns\\MountOrganizer\\media\\MountOrganizer_20x20.tga")

    -- Category name input
    nameInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    nameInput:SetSize(166, 24)
    nameInput:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -39)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(25)
    nameInput:SetTextInsets(5, 5, 0, 0)

    -- Category icon
    iconButton = CreateFrame("Button", nil, panel, "BackdropTemplate")
    iconButton:SetSize(26, 26)
    iconButton:SetPoint("LEFT", nameInput, "RIGHT", 8, 0)
    iconButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    iconButton:SetBackdropColor(0, 0, 0, 0.8)
    iconButton:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    iconButton.icon = iconButton:CreateTexture(nil, "ARTWORK")
    iconButton.icon:SetPoint("TOPLEFT", iconButton, "TOPLEFT", 2, -2)
    iconButton.icon:SetPoint("BOTTOMRIGHT", iconButton, "BOTTOMRIGHT", -2, 2)

    -- New/Create buttons
    local newButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    newButton:SetSize(54, 24)
    newButton:SetPoint("LEFT", iconButton, "RIGHT", 6, 0)
    newButton:SetText("New")

    categorySaveButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    categorySaveButton:SetSize(66, 24)
    categorySaveButton:SetPoint("LEFT", newButton, "RIGHT", 4, 0)
    categorySaveButton:SetText("Create")

    -- Category label
    local categoryLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    categoryLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -75)
    categoryLabel:SetText("CATEGORIES")

    -- Categories list
    categoryScroll, categoryContent = CreateScroll(panel, -91, -185)
    categoryScroll:ClearAllPoints()
    categoryScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -91)
    categoryScroll:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -28, -185)
    local membersLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    membersLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -200)
    membersLabel:SetText("IN CATEGORY")

    -- Mount members list
    local addSelectedButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addSelectedButton:SetSize(112, 22)
    addSelectedButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -193)
    addSelectedButton:SetText("Add Selected")
    addSelectedButton:SetScript("OnClick", function()
        if not selectedCategory then
            memberStatus:SetText("Create or select a category first.")
            return
        end
        local mountID = MountJournal.selectedMountID
        if not mountID then
            memberStatus:SetText("Select a mount in the Mount Journal first.")
            return
        end
        local mount = ns.Mounts:GetByID(mountID)
        if not mount then
            memberStatus:SetText("That mount is not collected by this character.")
            return
        end
        if not mount.usable then
            memberStatus:SetText(mount.useError or "That mount cannot be used by this character.")
            return
        end
        selectedCategory.mounts[mountID] = true
        RefreshCategoryRows()
        RefreshCategoryMembers()
        RefreshSelectedCategory()
    end)

    memberStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    memberStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -222)
    memberStatus:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    memberStatus:SetJustifyH("LEFT")
    memberStatus:SetWordWrap(true)
    memberStatus:SetText("Select a mount in the Mount Journal, then add it here.")
    memberScroll, memberContent = CreateScroll(panel, -240, 60)

    actionButton = CreateFrame("Button", nil, panel)
    actionButton:SetSize(36, 36)
    actionButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 14, 18)
    actionButton:RegisterForClicks("AnyUp")
    actionButton:RegisterForDrag("LeftButton")
    actionButton.icon = actionButton:CreateTexture(nil, "ARTWORK")
    actionButton.icon:SetAllPoints()
    actionButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    actionButton:SetScript("OnClick", function()
        if not selectedCategory then
            return
        end
        ns.Mounts:SummonRandom(selectedCategory)
    end)
    actionButton:SetScript("OnDragStart", function()
        if actionMacroIndex and not InCombatLockdown() then
            PickupMacro(actionMacroIndex)
        end
    end)
    actionButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Random mount from this category", 1, 1, 1, 0)
        GameTooltip:AddLine("Click to summon, or drag to your hotbar.", 1, 1, 1)
        GameTooltip:Show()
    end)
    actionButton:SetScript("OnLeave", GameTooltip_Hide)

    actionStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    actionStatus:SetPoint("LEFT", actionButton, "RIGHT", 9, 0)
    actionStatus:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    actionStatus:SetJustifyH("LEFT")
    actionStatus:SetWordWrap(true)

    -- Icon chooser
    iconPicker = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    iconPicker:SetSize(260, 210)
    iconPicker:SetPoint("TOPLEFT", iconButton, "BOTTOMRIGHT", 4, -4)
    iconPicker:SetFrameStrata("TOOLTIP")
    iconPicker:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    iconPicker.scroll, iconPicker.content = CreateScroll(iconPicker, -5, 5)
    iconPicker.scroll:ClearAllPoints()
    iconPicker.scroll:SetPoint("TOPLEFT", iconPicker, "TOPLEFT", 6, -6)
    iconPicker.scroll:SetPoint("BOTTOMRIGHT", iconPicker, "BOTTOMRIGHT", -24, 6)
    iconPickerCloseButton = CreateFrame("Button", nil, iconPicker, "UIPanelCloseButton")
    iconPickerCloseButton:SetSize(24, 24)
    iconPickerCloseButton:SetPoint("TOPRIGHT", iconPicker, "TOPRIGHT", -2, -2)
    iconPickerCloseButton:SetScript("OnClick", HideIconPicker)
    iconPicker:Hide()

    -- iconButton click handler
    iconButton:SetScript("OnClick", function()
        if iconPicker:IsShown() then
            HideIconPicker()
        else
            RefreshIconPicker()
            iconPicker:Show()
        end
    end)

    -- new button click handler
    newButton:SetScript("OnClick", function()
        HideIconPicker()
        editingCategory = nil
        nameInput:SetText("")
        currentIcon = ns.Mounts:GetAll()[1] and ns.Mounts:GetAll()[1].icon or ns.Constants.DEFAULT_ICON
        iconButton.icon:SetTexture(currentIcon)
        categorySaveButton:SetText("Create")
        nameInput:SetFocus()
    end)

    -- "Save" button click handler
    categorySaveButton:SetScript("OnClick", function()
        local name = strtrim(nameInput:GetText() or "")
        if name == "" then
            print("|cFFFF5555Mount Organizer: Enter a category name.|r")
            return
        end
        if editingCategory then
            editingCategory.name = name
            editingCategory.icon = currentIcon or ns.Constants.DEFAULT_ICON
            selectedCategory = editingCategory
            ns.Macros:SyncCategory(selectedCategory, false)
            RefreshCategoryRows()
            RefreshCategoryMembers()
            RefreshSelectedCategory()
            return
        end
        local category = ns.Storage:AddCategory(name, currentIcon)
        SelectCategory(category)
        iconPicker:Hide()
        RefreshCategoryRows()
        RefreshCategoryMembers()
        RefreshSelectedCategory()
    end)

    -- Category delete button
    local deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteButton:SetSize(64, 20)
    deleteButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -72)
    deleteButton:SetText("Delete")
    deleteButton:SetScript("OnClick", function()
        if not selectedCategory then
            return
        end
        if InCombatLockdown() then
            memberStatus:SetText("Categories can be deleted after combat.")
            return
        end
        local deleted, errorText = ns.Macros:DeleteCategory(selectedCategory)
        if not deleted then
            memberStatus:SetText(errorText)
            return
        end
        ns.Storage:RemoveCategory(selectedCategory)
        SelectCategory(ns.Storage:GetCategories()[1])
        RefreshCategoryRows()
        RefreshCategoryMembers()
        RefreshSelectedCategory()
    end)

    ns.Mounts:Refresh()
    if #ns.Mounts:GetAll() > 0 then
        currentIcon = ns.Mounts:GetAll()[1].icon
    else
        currentIcon = ns.Constants.DEFAULT_ICON
    end
    iconButton.icon:SetTexture(currentIcon)
    ns.Macros:SyncAll()
    SelectCategory(ns.Storage:GetCategories()[1])
    RefreshCategoryRows()
    RefreshCategoryMembers()
    RefreshSelectedCategory()
    ns.Layout:Attach(panel, MountJournal)
end

-- Abstraction macro
function UI:RefreshCategoryMembers()
    RefreshCategoryRows()
    RefreshCategoryMembers()
    RefreshSelectedCategory()
end

-- Abstraction macro
function UI:RefreshSelectedCategory()
    RefreshSelectedCategory()
end

-- Abstraction macro
function UI:RefreshAll()
    RefreshCategoryRows()
    RefreshCategoryMembers()
    RefreshIconPicker()
    RefreshSelectedCategory()
end
