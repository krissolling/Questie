dofile("setupTests.lua")

describe("QuestieJourney startup and browsing", function()
    local journey, private, zone, faction, container, jobs
    local originalLibStub, originalUnitGUID

    before_each(function()
        dofile("Modules/Libs/QuestieLoader.lua")
        originalLibStub, originalUnitGUID = _G.LibStub, _G.UnitGUID
        _G.LibStub = function()
            return {
                Create = function()
                    return {SetText = function() end, SetFullWidth = function() end}
                end,
            }
        end
        _G.UnitGUID = function() return "Player-123" end

        dofile("Localization/l10n.lua")
        dofile("Modules/Journey/QuestieJourney.lua")
        dofile("Modules/Journey/QuestieJourneyPrivates.lua")

        journey = QuestieLoader:ImportModule("QuestieJourney")
        private = journey.private
        journey.BuildMainFrame = spy.new(function() end)
        journey.SetupKeybinding = spy.new(function() end)
        journey.IsShown = function() return true end
        zone = private.questsByZone
        zone.DrawTab = spy.new(function() end)
        private.BuildZoneData = spy.new(function()
            coroutine.yield()
            journey.zoneMap = {}
        end)
        faction = {
            InitializeFactionData = spy.new(function() end),
            InitializeFactionQuestData = spy.new(function() journey.factionMap = {} end),
            DrawTab = spy.new(function() end),
        }
        private.questsByFaction = faction
        QuestieLoader:ImportModule("QuestieSearchResults").DrawSearchTab = function() end
        container = {ReleaseChildren = function() end, AddChild = function() end}
        jobs = {}
        QuestieLoader:ImportModule("ThreadLib").Thread = function(run, _, _, _, onError)
            jobs[#jobs + 1] = {thread = coroutine.create(run), onError = onError}
        end
    end)

    after_each(function()
        _G.LibStub, _G.UnitGUID = originalLibStub, originalUnitGUID
    end)

    it("keeps the character history and keybind setup at startup and schedules no browse work", function()
        journey:Initialize()

        assert.are_equal("Player-123", Questie.db.char.guid)
        assert.spy(journey.BuildMainFrame).was.called(1)
        assert.spy(journey.SetupKeybinding).was.called(1)
        assert.spy(private.BuildZoneData).was.not_called()
        assert.spy(faction.InitializeFactionData).was.not_called()
        assert.are_equal(0, #jobs)
    end)

    it("deduplicates an in-flight build and does not redraw over a newer selection", function()
        private:HandleTabChange(container, "zone")
        assert(coroutine.resume(jobs[1].thread))
        private:HandleTabChange(container, "zone")
        private:HandleTabChange(container, "search")
        assert(coroutine.resume(jobs[1].thread))

        assert.are_equal(1, #jobs)
        assert.spy(zone.DrawTab).was.not_called()
        private:HandleTabChange(container, "zone")
        assert.spy(zone.DrawTab).was.called_with(zone, container)
        assert.spy(private.BuildZoneData).was.called(1)
        assert.spy(faction.InitializeFactionData).was.not_called()
    end)

    it("builds factions only on first visit and draws once the index is available", function()
        private:HandleTabChange(container, "faction")
        assert.spy(faction.DrawTab).was.not_called()
        assert(coroutine.resume(jobs[1].thread))
        private:HandleTabChange(container, "faction")

        assert.are_equal(1, #jobs)
        assert.spy(faction.InitializeFactionData).was.called(1)
        assert.spy(faction.InitializeFactionQuestData).was.called(1)
        assert.spy(faction.DrawTab).was.called(2)
    end)

    it("lets a later selection retry a failed build", function()
        private.BuildZoneData = function() error("index build failed") end
        private:HandleTabChange(container, "zone")
        local success, message = coroutine.resume(jobs[1].thread)
        assert.is_false(success)
        jobs[1].onError(message)

        private.BuildZoneData = function() journey.zoneMap = {} end
        private:HandleTabChange(container, "zone")
        assert(coroutine.resume(jobs[2].thread))
        assert.spy(zone.DrawTab).was.called(1)
    end)
end)
