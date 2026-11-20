from runpy import run_path

lua = run_path('work/test_release.py')['lua']
lua.execute('''
local events = frames[#frames]
for _, frame in ipairs(frames) do
    if frame.events.ADDON_LOADED then events = frame; break end
end
local function fire(event, ...)
    assert(events.events[event], event .. " must be registered")
    events.scripts.OnEvent(events, event, ...)
end
local function count(haystack, needle)
    local _, n = haystack:gsub(needle, "")
    return n
end

local now, zone = 100000, "Elwynn Forest"
function time() return now end
function date(format) return format == "%H:%M" and "19:00" or "November 11" end
function GetRealZoneText() return zone end
function UnitName(unit) return unit == "player" and "Tester" or "Riverpaw Scout" end
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
function SendChatMessage() error("Tales must never send chat") end

ForeverCodexTales = nil
F.LoadTales()
assert(not F.GenerateTale())
fire("PLAYER_ENTERING_WORLD")
F.LoadTales()
fire("PLAYER_ENTERING_WORLD")
assert(#ForeverCodexTales.events == 1, "Reload repeated the current zone")
zone = "Westfall"
fire("ZONE_CHANGED_NEW_AREA")
fire("ZONE_CHANGED_NEW_AREA")
F.db.settings.group = true
unitGUID = "Creature-0-1-2-3-778-A"
fire("PARTY_KILL", "Player-party", unitGUID)
unitGUID = "Creature-0-1-2-3-778-B"
fire("PARTY_KILL", "Player-1", unitGUID)
fire("PARTY_KILL", "Player-1", unitGUID)
unitGUID = "Creature-0-1-2-3-778-C"
fire("PARTY_KILL", "Player-1", unitGUID)
local link = "|cff1eff00|Hitem:2318:0|h[Light Leather]|h|r"
local function loot(message, lineID)
    fire("CHAT_MSG_LOOT", message, nil, nil, nil, nil, nil, nil, nil, nil, nil, lineID)
end
loot("Party member receives loot: " .. link .. ".", 1)
loot("You receive loot: " .. link .. "x2.", 2)
loot("You receive loot: " .. link .. "x2.", 2)
loot("You receive loot: " .. link .. ".", 3)
SlashCmdList.FOREVERBESTIARY("TaLe NoTe We Followed The River.")
assert(#ForeverCodexTales.events == 6, "Duplicate, unsupported, or missing events")

local draft = assert(F.GenerateTale())
assert(draft.text:find("I made my way to Westfall, where my group brought down Riverpaw Scout", 1, true))
assert(draft.text:find("That name would turn up again", 1, true))
assert(draft.text:find("We Followed The River.", 1, true))
assert(not draft.text:find("x3", 1, true) and not draft.text:find("November 11", 1, true))
assert(draft.record:find("Received Light Leather x3", 1, true))
assert(draft.record:find("group credit", 1, true))
assert(count(draft.record, "Entered Westfall") == 1)
assert(count(draft.record, "Discovered Riverpaw Scout") == 1)
assert(draft.record:find("Encountered Riverpaw Scout x2", 1, true))
assert(F.GetRecentTaleRecord() == draft.record)

draft.title = "The Road to Westfall"
assert(F.SetTaleDraft(draft))
F.LoadTales()
assert(F.GetTaleDraft().title == draft.title)
local id = assert(F.SaveTale(F.GetTaleDraft()))
F.SetTaleDraft(nil)
F.LoadTales()
assert(#F.ListTales() == 1 and F.ListTales()[1].id == id)
assert(not F.GetTaleDraft())
assert(F.DeleteTale(id) and not F.DeleteTale(id))

local longWord = string.rep("é", 115)
local excerpt = F.TaleExcerpts("I reached Westfall.\\n\\n" .. longWord)
assert(#excerpt == 3 and excerpt[1] == "I reached Westfall.")
assert(#excerpt[2] == 220 and excerpt[2] .. excerpt[3] == longWord)
local words = string.rep("A long road. ", 60):gsub("%s+$", "")
assert(table.concat(F.TaleExcerpts(words), " ") == words, "Retell should split at word boundaries")

now = now + 86401
assert(not F.GenerateTale(), "The tale included stale events")
for i = 1, 70 do assert(F.AddTaleNote("note " .. i .. ".")) end
assert(count(F.GenerateTale().record, "Field note") == 60)
local saved = ForeverCodexTales
local future = {version=4, marker={true}}
ForeverCodexTales = future
F.LoadTales()
assert(not F.AddTaleNote("can't write") and not F.GenerateTale())
assert(ForeverCodexTales == future and future.marker[1])

local character = F.character
F.db.creatures[950] = {id=950, name="Track Wolf", kills=3, first=now-100,
    characters={[character]=3}, history={{time=now-50,zone="Westfall"}, {time=now-100}, {time=now-90000}}}
F.db.creatures[951] = {id=951, name="Mixed Wolf", kills=3,
    characters={[character]=2,["Other-Realm"]=1}, history={{time=now-50}}}
F.db.creatures[952] = {id=952, name="Unattributed Wolf", kills=2,
    characters={[character]=1}, history={{time=now-50}}}
ForeverCodexTales = {version=1, lastZone=zone, draft=draft,
    events={{kind="discover",name="Track Wolf",time=now-100}, {kind="zone",name=zone,time=now-10}}}
F.LoadTales()
fire("PLAYER_ENTERING_WORLD")
local live, liveCount = F.GetRecentTaleRecord()
assert(liveCount == 3 and ForeverCodexTales.version == 3)
assert(live:find("Encountered Track Wolf in Westfall (recovered from Bestiary)", 1, true))
assert(live:find("Discovered Track Wolf", 1, true) < live:find("Encountered Track Wolf", 1, true))
assert(live:find("Encountered Track Wolf", 1, true) < live:find("Entered Westfall", 1, true))
assert(F.GetTaleDraft().record == draft.record, "Recovery changed an existing draft")
assert(F.GenerateTale().text:find("my Codex has an entry for Track Wolf", 1, true))
F.LoadTales()
fire("PLAYER_ENTERING_WORLD")
assert(F.GetRecentTaleRecord() == live, "Recovery repeated after reload")

ForeverCodexTales = nil
F.LoadTales()
SlashCmdList.FOREVERBESTIARY("tale")
assert(F.activeWindow == "tales" and ForeverCodexTalesWindow:IsShown())
local window = ForeverCodexTalesWindow
assert(window.page == "tale" and window.editor:GetText():find("Write story", 1, true))
assert(window.tell:IsShown() and not window.save:IsShown() and not window.share:IsShown())
assert(not window.recordTab:IsShown())
window.tell.scripts.OnClick(window.tell)
assert(not F.GetTaleDraft())
F.CloseManaged("tales")

ForeverCodexTales = saved
F.LoadTales()
SlashCmdList.FOREVERBESTIARY("tale")
assert(window.page == "tale")
window.recentTab.scripts.OnClick(window.recentTab)
assert(window.page == "recent" and window.editor:GetText():find("Field note", 1, true))
assert(F.AddTaleNote("Live while the window is open."))
assert(window.editor:GetText():find("Live while the window is open.", 1, true))
window.taleTab.scripts.OnClick(window.taleTab)
window.tell.scripts.OnClick(window.tell)
assert(window.page == "tale" and window.editor:GetText() == F.GetTaleDraft().text)
assert(window.save:IsShown() and window.share:IsShown() and not window.recordTab:IsShown())
window.recentTab.scripts.OnClick(window.recentTab)
assert(window.recordTab:IsShown())
window.recordTab.scripts.OnClick(window.recordTab)
local snapshot = window.editor:GetText()
assert(F.AddTaleNote("After the tale was drafted."))
assert(window.editor:GetText() == snapshot)
window.activityRecent.scripts.OnClick(window.activityRecent)
assert(window.editor:GetText():find("After the tale was drafted.", 1, true))
window.taleTab.scripts.OnClick(window.taleTab)
StaticPopupDialogs = {}
local shownPopup
function StaticPopup_Show(key) shownPopup = key end
local oldText = F.GetTaleDraft().text
window.tell.scripts.OnClick(window.tell)
assert(shownPopup == "FOREVER_CODEX_REWRITE_TALE" and F.GetTaleDraft().text == oldText)
StaticPopupDialogs[shownPopup].OnAccept()
assert(window.page == "tale" and window.editor:GetText():find("After the tale was drafted.", 1, true))

local savedSource = F.GetTaleDraft().record
window.editor.text = ""
window.editor.scripts.OnTextChanged(window.editor, true)
assert(not window.share:IsShown())
assert(F.GetTaleDraft().record == savedSource)
window.editor.text = "A first passage.\\n\\nA second passage."
window.editor.scripts.OnTextChanged(window.editor, true)
assert(window.share:IsShown())
window.share.scripts.OnClick(window.share)
assert(window.page == "retell" and window.editor:GetText() == "A first passage.")
local selectedPassage
function window.editor:HighlightText() selectedPassage = self:GetText() end
window.select.scripts.OnClick(window.select)
assert(selectedPassage == "A first passage.")
window.next.scripts.OnClick(window.next)
assert(window.editor:GetText() == "A second passage.")
window.taleTab.scripts.OnClick(window.taleTab)
window.save.scripts.OnClick(window.save)
local storyID = window.selected
assert(storyID and not F.GetTaleDraft() and F.ListTales()[1].record == savedSource)
window.recentTab.scripts.OnClick(window.recentTab)
window.recordTab.scripts.OnClick(window.recordTab)
assert(window.editor:GetText() == savedSource)
window.taleTab.scripts.OnClick(window.taleTab)
assert(window.selected == storyID and window.editor:GetText() == "A first passage.\\n\\nA second passage.")
fire("PLAYER_REGEN_DISABLED")
assert(not ForeverCodexTalesWindow:IsShown(), "Combat should dismiss the chapter")

local route = F.WriteTale({{kind="zone",name="Elwynn Forest"}, {kind="zone",name="Westfall"}, {kind="zone",name="Elwynn Forest"}})
assert(route:find("passed through Westfall before coming back to Elwynn Forest", 1, true))
local recovered = {}
for i = 1, 30 do
    recovered[i] = {kind="encounter", name="Riverpaw Scout", zone="Westfall", recovered=true, credit="personal"}
end
recovered[31] = {kind="loot", name="Light Leather", quantity=2, zone="Westfall"}
recovered[32] = {kind="note", text="I took the long way home.", zone="Westfall"}
local story = F.WriteTale(recovered)
assert(count(story, "Riverpaw Scout") == 1 and story:find("30 times in all", 1, true))
assert(story:find("I took the long way home.", 1, true) and not story:find("brought down", 1, true))
assert(story:find("I also picked up Light Leather.", 1, true))

local warlockVoice = F.TaleVoice("WARLOCK", "Scourge")
local function jokeCount(text)
    local total = 0
    for _, bank in pairs(warlockVoice.quips) do
        for _, quip in ipairs(bank) do
            if text:find(quip, 1, true) then total = total + 1 end
        end
    end
    return total
end
local eventsForStory = {
    {kind="encounter",name="Riverpaw Scout",quantity=4,zone="Westfall",credit="personal"},
    {kind="zone",name="Redridge Mountains"},
    {kind="loot",name="Light Leather",zone="Redridge Mountains"},
    {kind="loot",name="Tough Jerky",zone="Redridge Mountains"},
}
local jokes = 0
for stamp = 1, 32 do
    eventsForStory[4].time = stamp
    local tale = F.WriteTale(eventsForStory, "WARLOCK", "Scourge")
    assert(tale == F.WriteTale(eventsForStory, "WARLOCK", "Undead"), "A fixed story must keep its delivery")
    local n = jokeCount(tale)
    assert(n <= 1, "Jokes should be occasional")
    jokes = jokes + n
end
assert(jokes > 0 and jokes < 32)
assert(jokeCount(F.WriteTale(recovered, "WARLOCK", "Scourge")) == 0, "Field-note scene must keep its own tone")
assert(F.WriteTale(eventsForStory, "WARLOCK", "Scourge") ~= F.WriteTale(eventsForStory, "HUNTER", "Dwarf"))

local before = F.GetRecentTaleRecord()
function UnitClass(unit) assert(unit == "player"); return "Hexenmeister", "WARLOCK", 9 end
function UnitRace(unit) assert(unit == "player"); return "Verlassene", "Scourge", 5 end
local personalDraft = F.GenerateTale()
assert(personalDraft.record == before)
assert(personalDraft.text:find(warlockVoice.openings[1], 1, true) == 1
    or personalDraft.text:find(warlockVoice.openings[2], 1, true) == 1)
C_QuestLog = {GetTitleForQuestID=function() return "The Road to Redridge" end}
fire("QUEST_TURNED_IN", 234, 200, 300)
assert(F.GetRecentTaleRecord():find("Turned in The Road to Redridge in Westfall", 1, true))
assert(F.GenerateTale().text:find('"The Road to Redridge" through to the end', 1, true))
''')
print('PASS: Campfire Tales event routing, quest turn-ins, character voices, bounded quips, history recovery, live record, frozen drafts, archive, UTF-8 retelling, future schema and combat dismissal')
