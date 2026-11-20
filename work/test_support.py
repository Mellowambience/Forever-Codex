import runpy

lua = runpy.run_path('work/test_release.py')['lua']
lua.execute("""
local handlerCalls = 0
function geterrorhandler()
    return function() handlerCalls = handlerCalls + 1 end
end
local function failure() error("UI.lua:42 private test text") end
assert(not F.SupportCall("Test render", failure))
assert(not F.SupportCall("Test render", failure))
assert(handlerCalls == 1, "Repeated errors should only notify once")
F.NoteUnavailableEvent("TEST_UNAVAILABLE")
local report = F.BuildSupportReport()
assert(report:find("Test render at UI.lua:42 (2)", 1, true))
assert(report:find("TEST_UNAVAILABLE", 1, true))
assert(not report:find("private test text", 1, true))
assert(not report:find("Tester", 1, true))

SlashCmdList.FOREVERBESTIARY("report")
assert(ForeverCodexSupportReport:IsShown() and F.activeWindow == "support")
local events
for _, frame in ipairs(frames) do
    if frame.events.ADDON_LOADED then events = frame; break end
end
assert(events and events.events.PLAYER_REGEN_DISABLED)
F.priceSearch = {waiting = 123}
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
assert(not ForeverCodexSupportReport:IsShown() and not F.activeWindow and not F.priceSearch)

assert(not F.safeMode)
SlashCmdList.FOREVERBESTIARY("safe")
assert(ForeverBestiarySupport.safe and not F.safeMode)
local optionalCalls = 0
F.LoadPrices = function() optionalCalls = optionalCalls + 1 end
F.InstallPriceTooltips = F.LoadPrices
F.SellerEvent = F.LoadPrices
events.scripts.OnEvent(events, "ADDON_LOADED", "ForeverBestiary")
events.scripts.OnEvent(events, "PLAYER_LOGIN")
events.scripts.OnEvent(events, "AUCTION_HOUSE_SHOW")
assert(F.safeMode and optionalCalls == 0 and not F.PriceQuote(2318))
assert(F.db.creatures[123], "Safe mode keeps collection data loaded")
SlashCmdList.FOREVERBESTIARY("safe")
assert(not ForeverBestiarySupport.safe and F.safeMode)
""")
print('PASS: redacted error counts, report entry point, combat cleanup, and safe mode startup isolation')
