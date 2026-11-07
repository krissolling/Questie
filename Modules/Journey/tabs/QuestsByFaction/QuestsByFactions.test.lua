dofile("setupTests.lua")

describe("Journey faction index", function()
    local journey, factionTab, db, reputation, quests

    before_each(function()
        dofile("Modules/Libs/QuestieLoader.lua")
        dofile("Modules/Expansions.lua")
        local expansions = QuestieLoader:ImportModule("Expansions")
        expansions.Current = expansions.Era
        QuestieLoader:ImportModule("QuestieJourneyFactions").BuildFactionIntroductionOrder = function(order)
            return {[72] = order.classic}
        end
        local player = QuestieLoader:ImportModule("QuestiePlayer")
        player.HasRequiredRace = function(mask) return mask ~= 2 end
        player.HasRequiredClass = function(mask) return mask ~= 4 end
        QuestieLoader:ImportModule("QuestieQuestBlacklist").HIDE_ON_MAP = 1
        QuestieLoader:ImportModule("QuestieCorrections").hiddenQuests = {[102] = 2, [103] = 1, [104] = 2}
        QuestieLoader:ImportModule("QuestieEvent").IsEventQuest = function(id) return id == 104 end
        reputation = QuestieLoader:ImportModule("QuestieReputation")
        reputation.GetFactionName = spy.new(function(id) return id ~= 99 and tostring(id) or nil end)

        quests = {
            [101] = {requiredMinRep = {72, 1}, requiredMaxRep = {76, 100}},
            [102] = {reputationReward = {{88, 10}}},
            [103] = {reputationReward = {{72, 10}, {99, 10}}},
            [104] = {reputationReward = {{72, 20}}},
            [105] = {reputationReward = {{72, 30}}, requiredRaces = 2},
            [106] = {reputationReward = {{72, 40}}, requiredClasses = 4},
        }
        db = QuestieLoader:ImportModule("QuestieDB")
        db.QuestPointers = quests
        db.QueryQuestSingle = function(id, field)
            if (id == 102 or id == 105 or id == 106) and field == "reputationReward" then
                error("Ineligible quest should not decode its reputation rewards")
            end
            return quests[id][field]
        end

        dofile("Modules/Journey/tabs/QuestsByFaction/QuestsByFactions.lua")
        journey = QuestieLoader:ImportModule("QuestieJourney")
        factionTab = journey.private.questsByFaction
    end)

    it("builds the quest map and dropdown from the same visible quest set", function()
        factionTab:InitializeFactionData()
        factionTab:InitializeFactionData()

        assert.are_same({
            [72] = {[101] = true, [103] = true, [104] = true},
            [76] = {[101] = true},
            [99] = {[103] = true},
        }, journey.factionMap)
        assert.are_same({[72] = "72"}, journey.factionsByExpansion.classic)
        assert.are_same({[76] = "76"}, journey.factionsByExpansion.mop)
        assert.spy(reputation.GetFactionName).was.called(3)
    end)
end)
