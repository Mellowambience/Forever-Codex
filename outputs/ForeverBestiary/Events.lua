local _, F = ...
local events=CreateFrame("Frame")
local observedEvents={PLAYER_TARGET_CHANGED="target",UPDATE_MOUSEOVER_UNIT="mouseover"}
local auctionEvents={AUCTION_HOUSE_SHOW=true,AUCTION_HOUSE_CLOSED=true,AUCTION_HOUSE_AUCTION_CREATED=true,AUCTION_HOUSE_POST_ERROR=true}
local auctionPriceEvents={AUCTION_ITEM_LIST_UPDATE=true,COMMODITY_SEARCH_RESULTS_UPDATED=true,COMMODITY_SEARCH_RESULTS_ADDED=true,ITEM_SEARCH_RESULTS_UPDATED=true,ITEM_SEARCH_RESULTS_ADDED=true}
local coreEvents={
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_LOGOUT",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "UNIT_HEALTH",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "PARTY_KILL",
    "LOOT_OPENED", "LOOT_READY", "LOOT_CLOSED", "CHAT_MSG_LOOT", "QUEST_TURNED_IN",
    "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE",
}
local function register(event)
    local ok=pcall(events.RegisterEvent,events,event)
    if not ok then F.NoteUnavailableEvent(event) end
    if event=="PARTY_KILL" then F.killEvent=ok end
end
local function diagnostic()
    local count=0; for _ in pairs(F.db.creatures) do count=count+1 end
    F.Message("v"..F.version.." | "..count.." species | PARTY_KILL "..(F.killEvent and "registered" or "unavailable").." | restricted values skipped")
end
function F.Toggle()
    if F.Safe(InCombatLockdown) then F.CloseForCombat(); return end
    if F.activeWindow then F.CloseManaged(F.activeWindow) else F.OpenToday() end
end
events:RegisterEvent("ADDON_LOADED")
local function handleEvent(event,...)
    if event=="ADDON_LOADED" then
        if ...~="ForeverBestiary" then return end
        F.InitSupport()
        F.Init()
        F.SupportCall("Campfire Tales startup", F.LoadTales)
        if not F.safeMode then
            F.SupportCall("Auction price startup", F.LoadPrices)
            F.SupportCall("Item tooltip startup", F.InstallPriceTooltips)
        end
        F.SupportCall("Window layout startup", F.StartWindowLayout)
        for _,event in ipairs(coreEvents) do register(event) end
        if not F.safeMode then
            for event in pairs(auctionEvents) do register(event) end
            for event in pairs(auctionPriceEvents) do register(event) end
        end
        F.CreateMinimap()
    elseif event=="PLAYER_REGEN_DISABLED" then
        if F.priceSearch then F.FinishSaleSearch("Price lookup stopped: entered combat.") end
        F.CloseForCombat()
    elseif not F.db then return
    elseif auctionEvents[event] then
        if not F.safeMode then F.SellerEvent(event,...) end
    elseif event=="PLAYER_LOGIN" then
        F.Snapshot("target"); F.UpdateMinimap()
        if not F.safeMode then F.SupportCall("Item tooltip startup", F.InstallPriceTooltips) end
    elseif event=="PLAYER_ENTERING_WORLD" then
        F.SupportCall("Tale history recovery",F.RecoverTaleEncounters)
        F.RecordTaleZone()
    elseif event=="ZONE_CHANGED_NEW_AREA" then F.RecordTaleZone()
    elseif observedEvents[event] then F.Snapshot(observedEvents[event])
    elseif event=="NAME_PLATE_UNIT_ADDED" then local unit=...; F.Snapshot(unit,.35)
    elseif event=="UNIT_HEALTH" then
        local unit=...; if F.IsText(unit) and (unit=="target" or unit=="mouseover") then F.Snapshot(unit,.35) end
    elseif event=="PARTY_KILL" then F.Snapshot("target"); F.Kill(...)
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then F.Spell(...)
    elseif event=="UNIT_SPELLCAST_START" then local unit,_,spellID=...; F.CastStart(unit,spellID)
    elseif event=="LOOT_OPENED" or event=="LOOT_READY" then F.Loot()
    elseif event=="LOOT_CLOSED" then F.lootContext=nil
    elseif event=="CHAT_MSG_LOOT" then local args={...}; F.PersonalLoot(args[1],args[11])
    elseif event=="QUEST_TURNED_IN" then F.RecordTaleQuestTurnIn(...)
    elseif event=="TRADE_SKILL_SHOW" or event=="TRADE_SKILL_LIST_UPDATE" then F.QueueRecipeScan()
    elseif event=="BAG_UPDATE_DELAYED" or event=="GET_ITEM_INFO_RECEIVED" then
        F.Refresh()
        if not F.safeMode then F.SellerEvent(event,...) end
    elseif auctionPriceEvents[event] then
        if F.safeMode then return end
        local key=...
        local quotes=F.CaptureAuctionPrices(event,key)
        F.SalePriceResult(event,key,quotes); F.RefreshSeller()
    elseif event=="PLAYER_LOGOUT" then F.db.settings.selected=F.selected end
end
events:SetScript("OnEvent",function(_,event,...)
    F.SupportCall(event,handleEvent,event,...)
end)
SLASH_FOREVERBESTIARY1="/fbc"; SLASH_FOREVERBESTIARY2="/bestiary"; SLASH_FOREVERBESTIARY3="/codex"
local function commandHandler(command)
    local original=strtrim(command or "")
    command=string.lower(original)
    if command=="today" then F.OpenToday(); return end
    if command=="bestiary" then F.OpenBestiary(); return end
    if command=="gold" then F.OpenGoldPlanner(); return end
    if command=="professions" then F.OpenProfessions(); return end
    if command=="feedback" then F.OpenFeedback(); return end
    if command=="atlas" then F.OpenAtlas(); return end
    if command=="tale" or command=="tales" then F.OpenTales(); return end
    local noteStart=command:match("^tale%s+note%s+()")
    if noteStart then
        local saved=F.AddTaleNote(original:sub(noteStart))
        F.Message(saved and "Field note added to Campfire Tales." or "Could not save that field note.")
        return
    elseif command=="tale note" then F.Message("Use /fbc tale note followed by your note."); return end
    if command=="report" then F.OpenSupportReport(); return end
    if command=="safe" then F.ToggleSafeMode(); return end
    if not F.db then return end
    if command=="minimap" then F.db.settings.hideMinimap=not F.db.settings.hideMinimap; F.UpdateMinimap(); F.Message(F.db.settings.hideMinimap and "Minimap button hidden. /fbc minimap restores it." or "Minimap button shown.")
    elseif command=="notify" then F.db.settings.notify=not F.db.settings.notify; F.Message("Discovery notifications "..(F.db.settings.notify and "on" or "off"))
    elseif command=="group" then F.db.settings.group=not F.db.settings.group; F.Message("Kill credit: "..(F.db.settings.group and "you and your group" or "you and your pet"))
    elseif command=="debug" then diagnostic()
    elseif command=="sell" or command=="auction" then F.OpenSeller()
    elseif command=="recipes" then F.ScanRecipes()
    elseif command=="clear" then
        StaticPopupDialogs.FOREVER_BESTIARY_CLEAR={text="Clear all creature discoveries, kills and field notes? A backup will be kept. Recipe records and inventory tracking will stay.",button1="Clear discoveries",button2="Cancel",OnAccept=function() F.ClearCollection() end,timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3}
        StaticPopup_Show("FOREVER_BESTIARY_CLEAR")
    elseif command=="restore" then
        if F.readOnly then F.Message("Update the addon before restoring a backup over newer saved data."); return end
        StaticPopupDialogs.FOREVER_BESTIARY_RESTORE={text="Restore your pre-upgrade bestiary backup? Discoveries recorded after that backup will be replaced.",button1="Restore backup",button2="Cancel",OnAccept=function() F.RestoreBackup() end,timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3}
        StaticPopup_Show("FOREVER_BESTIARY_RESTORE")
    elseif command=="target" then
        if F.Safe(InCombatLockdown) then F.Message("Preview the creature after combat."); return end
        F.CreateUI(); F.ShowManaged("journal"); F.Render(); F.PreviewTarget()
    elseif command=="help" then F.Message("/fbc opens the codex. Commands: today, bestiary, gold, professions, atlas, target, minimap, notify, group, sell, recipes, tale, restore, debug, report, safe.")
    elseif command=="resetpos" then F.ResetWindowPosition("journal")
    else F.Toggle() end
end
SlashCmdList.FOREVERBESTIARY=function(command)
    F.SupportCall("Slash command",commandHandler,command)
end
