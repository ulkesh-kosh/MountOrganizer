local _, ns = ...

local Layout = {}
ns.Layout = Layout

local panel
local shiftedUIPanels = {}
local hookedUIPanels = {}
local hookedJournalFrames = {}
local panelManagerHooked

local function CapturePanelPosition(frame)
    local points = {}
    for pointIndex = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(pointIndex)
        points[#points + 1] = { point, relativeTo, relativePoint, xOffset or 0, yOffset or 0 }
    end
    return {
        points = points,
        left = frame:GetLeft(),
        right = frame:GetRight(),
        offset = 0,
    }
end

local function RestorePanelPositions()
    if InCombatLockdown() then
        return
    end
    for frame, position in pairs(shiftedUIPanels) do
        frame:ClearAllPoints()
        for _, point in ipairs(position.points) do
            frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
        end
        shiftedUIPanels[frame] = nil
    end
end

local function ShiftPanelRight(frame, offset)
    if not shiftedUIPanels[frame] then
        local position = CapturePanelPosition(frame)
        if #position.points == 0 or not position.left or not position.right then
            return
        end
        shiftedUIPanels[frame] = position
    end

    local position = shiftedUIPanels[frame]
    local currentLeft = frame:GetLeft()
    if currentLeft and math.abs((currentLeft - position.left) - position.offset) > 2 then
        local updatedPosition = CapturePanelPosition(frame)
        if #updatedPosition.points > 0 and updatedPosition.left and updatedPosition.right then
            position = updatedPosition
            shiftedUIPanels[frame] = position
        end
    end
    frame:ClearAllPoints()
    for _, point in ipairs(position.points) do
        frame:SetPoint(point[1], point[2], point[3], point[4] + offset, point[5])
    end
    position.offset = offset
end

local function IsJournalContainer(frame, journal)
    local ancestor = journal:GetParent()
    while ancestor and ancestor ~= UIParent do
        if ancestor == frame then
            return true
        end
        ancestor = ancestor:GetParent()
    end
    return false
end

local function PushOverlappingPanels(journal)
    if InCombatLockdown() or not panel or not journal:IsVisible() then
        return
    end
    local panelLeft, panelBottom = panel:GetLeft(), panel:GetBottom()
    local panelRight, panelTop = panel:GetRight(), panel:GetTop()
    if not panelLeft or not panelRight or not panelTop or not panelBottom then
        return
    end

    for frameName in pairs(UIPanelWindows or {}) do
        local frame = _G[frameName]
        if frame and frame ~= journal and frame ~= panel and not IsJournalContainer(frame, journal) and frame:GetParent() == UIParent and frame:IsShown() then
            local left, bottom = frame:GetLeft(), frame:GetBottom()
            local right, top = frame:GetRight(), frame:GetTop()
            local position = shiftedUIPanels[frame]
            if position and left and math.abs((left - position.left) - position.offset) > 2 then
                position = CapturePanelPosition(frame)
                shiftedUIPanels[frame] = position
            end
            local overlaps = left and right and top and bottom
                and left < panelRight and right > panelLeft
                and bottom < panelTop and top > panelBottom
            if overlaps then
                if not position then
                    position = CapturePanelPosition(frame)
                    shiftedUIPanels[frame] = position
                elseif left and math.abs((left - position.left) - position.offset) > 2 then
                    position = CapturePanelPosition(frame)
                    shiftedUIPanels[frame] = position
                end
                local offset = panelRight - position.left + 12
                local screenRight = UIParent:GetRight()
                if screenRight then
                    offset = math.min(offset, math.max(0, screenRight - position.right - 8))
                end
                if offset > position.offset then
                    ShiftPanelRight(frame, offset)
                end
            end
        end
    end
end

function Layout:Schedule(journal)
    if not panel or InCombatLockdown() then
        return
    end
    if journal:IsVisible() then
        PushOverlappingPanels(journal)
    else
        RestorePanelPositions()
    end
end

local function HookUIPanelWindows(journal)
    for frameName in pairs(UIPanelWindows or {}) do
        local frame = _G[frameName]
        if frame and frame ~= journal and not hookedUIPanels[frame] then
            hookedUIPanels[frame] = true
            frame:HookScript("OnShow", function()
                Layout:Schedule(journal)
            end)
            frame:HookScript("OnHide", function()
                Layout:Schedule(journal)
            end)
        end
    end
    if not panelManagerHooked and type(UIParent_ManageFramePositions) == "function" then
        panelManagerHooked = true
        hooksecurefunc("UIParent_ManageFramePositions", function()
            Layout:Schedule(journal)
        end)
    end
end

function Layout:Attach(panelFrame, journal)
    panel = panelFrame
    local journalFrame = journal
    while journalFrame and journalFrame ~= UIParent do
        if not hookedJournalFrames[journalFrame] then
            hookedJournalFrames[journalFrame] = true
            journalFrame:HookScript("OnShow", function()
                Layout:Schedule(journal)
            end)
            journalFrame:HookScript("OnHide", function()
                Layout:Schedule(journal)
            end)
        end
        journalFrame = journalFrame:GetParent()
    end
    HookUIPanelWindows(journal)
    self:Schedule(journal)
end

function Layout:RefreshRegisteredPanels(journal)
    HookUIPanelWindows(journal)
    self:Schedule(journal)
end
