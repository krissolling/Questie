---@type QuestieJourney
local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
local _QuestieJourney = QuestieJourney.private
-------------------------
--Import modules.
-------------------------
---@type QuestieSearchResults
local QuestieSearchResults = QuestieLoader:ImportModule("QuestieSearchResults")
---@type ThreadLib
local ThreadLib = QuestieLoader:ImportModule("ThreadLib")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local AceGUI = LibStub("AceGUI-3.0")
local loadingTabs = {}

_QuestieJourney.containerCache = nil
_QuestieJourney.treeCache = nil

local function _DrawBrowseTab(container, group, tab, data, build)
    if data then
        tab:DrawTab(container)
        return
    end

    local label = AceGUI:Create("Label")
    label:SetText(l10n("Please wait a moment for Questie to finish loading"))
    label:SetFullWidth(true)
    container:AddChild(label)

    if loadingTabs[group] then
        return
    end
    loadingTabs[group] = true

    ThreadLib.Thread(function()
        build()
        loadingTabs[group] = nil
        if _QuestieJourney.lastOpenWindow == group and QuestieJourney:IsShown() then
            container:ReleaseChildren()
            tab:DrawTab(container)
        end
    end, 0, "Error loading Journey tab " .. group, nil, function()
        loadingTabs[group] = nil
        if _QuestieJourney.lastOpenWindow == group then
            container:ReleaseChildren()
        end
    end, "QuestieJourney.LoadTab." .. group)
end

function _QuestieJourney:HandleTabChange(container, group)
    if not _QuestieJourney.containerCache then
        _QuestieJourney.containerCache = container
    end

    _QuestieJourney.lastOpenWindow = group
    container:ReleaseChildren()

    if group == "journey" then
        local treeGroup = _QuestieJourney.myJourney:DrawTab(container)
        _QuestieJourney.myJourney:ManageTree(treeGroup)
        return treeGroup
    elseif group == "zone" then
        _DrawBrowseTab(container, group, _QuestieJourney.questsByZone, QuestieJourney.zoneMap, _QuestieJourney.BuildZoneData)
    elseif group == "faction" then
        local tab = _QuestieJourney.questsByFaction
        _DrawBrowseTab(container, group, tab, QuestieJourney.factionMap, function()
            tab:InitializeFactionData()
        end)
    elseif group == "search" then
        QuestieSearchResults:DrawSearchTab(container)
    end
end


