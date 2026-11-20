import runpy
lua=runpy.run_path('work/test_release.py')['lua']
lua.execute('''
F.safeMode=nil; F.readOnly=nil
F.db.recipes={}; F.db.trackedRecipes={}; F.db.creatures={}
assert(F.BuildToday().known==0 and not F.BuildToday().pinned)
function UnitFactionGroup() return "Horde" end
GetRealZoneText=function() return "Desolace" end
GetItemInfo=function(id) return "Item "..id,"item:"..id,1,1,1,"Trade Goods","Cloth",20,"",1,15,7,5,0 end
F.InventoryCount=function() return 1 end
F.LoadPrices(); F.db.settings.ahCut=5
F.db.recipes={
 [1]={id=1,name="Dinner",profession="Cooking",output=100,minimumYield=2,reagents={[200]=3},learnedBy={[F.character]=true}},
 [2]={id=2,name="Alt only",output=101,minimumYield=1,reagents={[200]=1},learnedBy={other=true}},
 [3]={id=3,name="Unknown prices",output=102,minimumYield=1,reagents={[201]=1},learnedBy={[F.character]=true}},
}
F.RememberPrice(100,1000); F.RememberPrice(200,100); F.RememberPrice(101,100000)
local p=F.BuildToday()
assert(p.known==2 and p.best.id==1 and p.best.plan.margin==1600 and p.unpriced==1)
F.prices.items[100].time=time()-3*86400
assert(not F.BuildToday().best,"Stale quote cannot be a recommendation")
F.RememberPrice(100,1000)
F.TrackRecipe(1,2)
F.db.creatures[10]=F.NormalizeRecord(10,{name="Local beast",zones={Desolace=true},loot={a={itemID=200,count=1},b={itemID=200,count=1}}})
F.db.creatures[11]=F.NormalizeRecord(11,{name="Distant beast",zones={Durotar=true},loot={a={itemID=200,count=1}}})
p=F.BuildToday(); assert(#p.leads==1 and #p.leads[1].items==1)
F.InventoryCount=function() return 6 end
assert(#F.BuildToday().leads==0 and not F.BuildToday().needsMaterials)
F.InventoryCount=function() return nil end
assert(#F.BuildToday().leads==0 and F.BuildToday().inventoryUnknown)
F.InventoryCount=function() return 1 end
F.db.recipes[1].partial=true
assert(not F.BuildToday().best,"Partial recipes cannot be recommended")
F.db.recipes[1].partial=nil
ForeverCodexTales=nil; F.LoadTales()
local before=F.TodaySession()
F.RecordTaleEncounter({id=10,name="Local beast",last=time()},"Player-1",true)
F.RecordTaleEncounter({id=10,name="Local beast",last=time()},"Player-1",false)
F.RecordTaleEncounter({id=10,name="Local beast",last=time()},"Player-1",false)
local after=F.TodaySession()
assert(after.discover-before.discover==1 and after.encounter-before.encounter==2,"Coalescing must preserve session counts")
F.OpenToday(); assert(F.activeWindow=="today")
F.todayWindow.cards[1].action.scripts.OnClick()
assert(F.activeWindow=="goldPlanner" and ForeverCodexGoldPlanner.selected==1)
F.OpenToday(); F.todayWindow.cards[2].action.scripts.OnClick()
assert(F.activeWindow=="journal" and F.selected==10)
F.SetTaleDraft({title="My words",text="Keep my story",record="",zones={}})
F.TodayTale(); assert(F.GetTaleDraft().text=="Keep my story")
F.OpenToday(); F.SetCodexTheme("Aged Parchment")
assert(F.todayWindow.heading.text=="Today's Page")
InCombatLockdown=function() return true end
F.Toggle(); assert(not F.activeWindow and not F.todayWindow:IsShown())
InCombatLockdown=function() return false end
F.Toggle(); assert(F.activeWindow=="today")
F.Toggle(); assert(not F.activeWindow)
''')
print('PASS: Today empty states, character filtering, margins, stale/partial guards, zone and material matching, deduplication, session counts, chapter navigation, draft preservation, themes and combat close')
