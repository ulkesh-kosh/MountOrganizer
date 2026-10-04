local _, ns = ...

local Storage = {}
ns.Storage = Storage

local CATEGORY_ID_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

function Storage:Initialize()
    MountOrganizerDB = MountOrganizerDB or {}
    MountOrganizerDB.categories = MountOrganizerDB.categories or {}
    self.db = MountOrganizerDB

    for _, category in ipairs(self.db.categories) do
        category.mounts = category.mounts or {}
        if type(category.id) ~= "string" or #category.id ~= 10 or not category.id:match("^[A-Za-z0-9]+$") then
            category.id = self:GenerateCategoryID()
        end
        category.icon = category.icon or ns.Constants.DEFAULT_ICON
    end
    self.db.nextId = nil
end

function Storage:GetCategories()
    return self.db.categories
end

function Storage:FindCategory(categoryID)
    for _, category in ipairs(self.db.categories) do
        if category.id == categoryID then
            return category
        end
    end
end

function Storage:GenerateCategoryID()
    local categoryID
    repeat
        local characters = {}
        for characterIndex = 1, 10 do
            local randomIndex = math.random(#CATEGORY_ID_CHARACTERS)
            characters[characterIndex] = CATEGORY_ID_CHARACTERS:sub(randomIndex, randomIndex)
        end
        categoryID = table.concat(characters)
    until not self:FindCategory(categoryID)
    return categoryID
end

function Storage:AddCategory(name, icon)
    local category = {
        id = self:GenerateCategoryID(),
        name = name,
        icon = icon or ns.Constants.DEFAULT_ICON,
        mounts = {},
    }
    table.insert(self.db.categories, category)
    return category
end

function Storage:RemoveCategory(category)
    for index, storedCategory in ipairs(self.db.categories) do
        if storedCategory == category then
            table.remove(self.db.categories, index)
            return true
        end
    end
    return false
end
