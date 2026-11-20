from pathlib import Path
import runpy,time
scope=runpy.run_path(str(Path(__file__).with_name('test_release.py')))
lua=scope['lua']
lua.execute('''
-- Upgrade/corruption handling, backup integrity and newer-version preservation.
ForeverBestiaryDB={version=2,creatures={bad="broken",[123]={name="Wolf",kills=42,notes="Keep this",zones={Elwynn=true,Wrong=false},loot={a={link="item:2318",count="invalid"}},abilities={bad=false}}},settings={modelViews={[123]={distance=2,pan=1,ratio=.5}}}}
F.Init()
assert(F.db.creatures[123].kills==42 and F.db.creatures[123].notes=="Keep this")
assert(not F.db.creatures[123].zones.Wrong)
assert(ForeverBestiaryBackup.data.version==2 and ForeverBestiaryBackup.data.creatures[123].notes=="Keep this")
assert(F.db.settings.modelViews[123].ratio==.5)
local good=F.CopyData(ForeverBestiaryDB)
local future={version=99,creatures={[999]={name="Future",kills=1}},settings={newSetting="untouched"}}
ForeverBestiaryDB=future; F.Init(); F.Kill("Player-1","Creature-0-1-2-3-333-X")
assert(F.readOnly and ForeverBestiaryDB==future and not future.creatures[333])
ForeverBestiaryDB=good; F.Init(); assert(not F.readOnly)

-- Explicit confirmation is needed before backup restoration.
StaticPopupDialogs={}; local popup
function StaticPopup_Show(name) popup=name end
F.db.creatures[123].notes="Changed after upgrade"
SlashCmdList.FOREVERBESTIARY("restore")
assert(popup=="FOREVER_BESTIARY_RESTORE" and F.db.creatures[123].notes=="Changed after upgrade")
StaticPopupDialogs[popup].OnAccept()
assert(F.db.creatures[123].notes=="Keep this")

-- Live location context is the observer's vicinity, with map/floor retained.
C_Map={GetBestMapForUnit=function() return 21 end,GetPlayerMapPosition=function() return {GetXY=function() return .35,.45 end} end,CanSetUserWaypointOnMap=function() return false end}
WorldMapFrame=CreateFrame("Frame"); function WorldMapFrame:SetMapID(id) self.map=id end
unitGUID="Creature-0-1-2-3-123-LOCATION"; F.Snapshot("target"); F.Kill("Player-1",unitGUID)
local r=F.db.creatures[123]
assert(next(r.locations) and r.observedBuild=="70790")
F.OpenLocation(r); assert(WorldMapFrame.map==21)
F.ToggleCreatureTracking(r); assert(F.TrackedCreatures()[123])
for i=1,40 do unitGUID="Creature-0-1-2-3-123-HISTORY"..i; F.Snapshot("target"); F.Kill("Player-1",unitGUID) end
assert(#r.history==30,"Encounter history must stay bounded")
assert(#F.Rows("Wolf","Beast","All research",{zone="Elwynn",minLevel="8",maxLevel="10"})==1)
assert(#F.Rows("Wolf","Beast","All research",{zone="Unknown"})==0)
assert(#F.Rows("Wolf","Beast","All research",{minLevel="99"})==0)

-- Seen loot, personal acquisition and unique source confirmation are distinct.
LOOT_ITEM_SELF="You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE="You receive loot: %sx%d."
lootSlots=2; unitGUID="Creature-0-1-2-3-123-LOOTTEST"; F.Loot()
local link=GetLootSlotLink(1); local seen=r.loot["2318"].count
F.PersonalLoot("Other receives loot: "..link..".",1); assert(not F.db.acquired[2318])
F.PersonalLoot("You receive loot: "..link.."x2.",2)
assert(F.db.acquired[2318]==2 and r.loot["2318"].acquired==2)
F.PersonalLoot("You receive loot: "..link.."x2.",2); assert(F.db.acquired[2318]==2)
F.PersonalLoot("You receive loot: "..link.."x3.",3)
assert(F.db.acquired[2318]==5 and r.loot["2318"].acquired==2,"Ambiguous or excessive quantities cannot be source-confirmed")
F.seenLoot={}; F.Init(); F.Loot(); r=F.db.creatures[123]
assert(r.loot["2318"].count==seen,"Reloading must not duplicate the same corpse observation")

-- Recipes are known by character, support required fixed reagents and disclose alternatives.
C_TradeSkillUI={
 GetAllRecipeIDs=function() return {500,501} end,
 GetRecipeInfo=function(id) return {name="Test leather armor",learned=id==500} end,
 GetRecipeSchematic=function() return {outputItemID=999,reagentSlotSchematics={{required=true,quantityRequired=3,reagents={{itemID=2318}}},{required=true,quantityRequired=1,reagents={{itemID=2589},{itemID=2592}}}}} end,
 GetRecipeRequirements=function() return {{name="Leatherworking 25"}} end,
 GetProfessionInfoByRecipeID=function() return {professionName="Leatherworking"} end,
}
C_Item={GetItemCount=function(item,bank) assert(bank==false,"Bank must not silently enter bag counts"); return item==2318 and 4 or 0 end}
assert(F.ScanRecipes(true)==1)
assert(F.db.recipes[500].partial and F.db.recipes[500].requirements[1]=="Leatherworking 25")
F.TrackRecipe(500,2); assert(F.MaterialNeeds()[2318]==6)
assert(F.InventoryCount(2318)==4 and #F.RelatedRecipes(r)==1)
F.TrackItem(2318,5); assert(F.db.trackedItems[2318]==5)
F.Init(); assert(F.db.recipes[500].reagents[2318]==3 and F.db.trackedRecipes[500]==2)
assert(F.db.acquired[2318]==5,"Acquisition totals must survive migration validation")
local oldUnitName=UnitName
function UnitName(unit) if unit=="player" then return "Another" end; return oldUnitName(unit) end
F.Init(); assert(#F.RelatedRecipes(F.db.creatures[123])==0 and not F.MaterialNeeds()[2318],"Another character must not inherit learned recipes")
UnitName=oldUnitName; F.Init()

-- Source data stays gated by discovery and does not contain drop chances.
assert(F.referenceCount==6)
assert(F.Reference(1922)==nil,"Uncovered creatures must not get invented reference data")
for _,row in ipairs(F.LootRows(F.db.creatures[123])) do assert(not row.chance) end
local copied=F.CopyData(ForeverBestiaryDB); copied.creatures[123].notes="Independent"
assert(F.db.creatures[123].notes~="Independent","Backups must not alias live tables")
''')
start=time.perf_counter()
lua.execute('''
F.db.creatures={}
for i=1,10000 do F.db.creatures[i]=F.NormalizeRecord(i,{name="Creature "..i,kills=i%40,kind="Beast",level=i%60+1,zones={Test=true}}) end
assert(#F.Rows("Creature","Beast","All research",{zone="Test",minLevel="1",sort="Most kills"})==10000)
''')
elapsed=time.perf_counter()-start
print(f'PASS: corruption recovery, migration backup, future schema, restore confirmation, map context, bounded history, combined filters, personal loot/source confirmation, reload dedup, known recipe tracking/persistence, character isolation, bags-only counts, reference gaps; 10,000-record normalize/filter/sort in {elapsed:.3f}s')
