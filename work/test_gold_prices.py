import runpy
lua=runpy.run_path('work/test_release.py')['lua']
lua.execute('''
F.readOnly=nil; F.safeMode=nil; F.salePending=nil
function UnitFactionGroup() return "Horde" end
GetItemInfo=function(id) return "Item "..id,"item:"..id,1,1,1,"Trade Goods","Cloth",20,"",1,15,7,5,0 end
F.InventoryCount=function() return 1 end
F.LoadPrices(); F.db.settings.ahCut=5
local recipe={name="Dinner",profession="Cooking",output=100,minimumYield=2,reagents={[200]=3},learnedBy={[F.character]=true}}
F.db.recipes={[77]=recipe}
assert(#F.CraftPriceTargets({output=100,reagents={[100]=1,[200]=2}})==2)
F.OpenGoldPlanner("Cooking")
local w=ForeverCodexGoldPlanner
local check
for _,child in ipairs(w.children) do if child.text=="Check prices" then check=child end end
assert(check)
F.auctionOpen=false; check.scripts.OnClick(); assert(not F.priceSearch)
F.auctionOpen=true
local queries={}; local count=1
C_AuctionHouse={MakeItemKey=function(id) return {itemID=id} end,SendSearchQuery=function(key) queries[#queries+1]=key.itemID end,GetNumCommoditySearchResults=function() return count end,GetCommoditySearchResultInfo=function(id) return {unitPrice=id==100 and 1000 or 100} end}
check.scripts.OnClick(); check.scripts.OnClick(); assert(#queries==1)
for i=1,2 do
 local id=F.priceSearch.waiting
 F.SalePriceResult("COMMODITY_SEARCH_RESULTS_UPDATED",999,{})
 assert(F.priceSearch.waiting==id)
 F.SalePriceResult("COMMODITY_SEARCH_RESULTS_UPDATED",id,F.CaptureAuctionPrices("COMMODITY_SEARCH_RESULTS_UPDATED",id))
 clock=clock+2; F.NextSaleSearch()
end
assert(not F.priceSearch and w.plans[77].margin==1600)
assert(w.plans[77].buyCost==200 and w.selected==77)
check.scripts.OnClick(); count=0
local id=F.priceSearch.waiting
F.SalePriceResult("COMMODITY_SEARCH_RESULTS_UPDATED",id,F.CaptureAuctionPrices("COMMODITY_SEARCH_RESULTS_UPDATED",id))
F.SellerEvent("AUCTION_HOUSE_CLOSED")
assert(not F.priceSearch and not w.plans[77].margin)
assert(string.find(w.status.text,"AH closed",1,true))
F.auctionOpen=true; check.scripts.OnClick(); clock=clock+13
F.priceSearchWatcher.scripts.OnUpdate()
assert(not F.priceSearch and string.find(w.status.text,"timed out",1,true))
C_AuctionHouse={}; check.scripts.OnClick()
assert(string.find(w.status.text,"native AH",1,true))
''')
print('PASS: Gold Planner price checks, deduplication, refresh, margin and shopping math, empty listings, AH closure, timeout, unsupported client')
