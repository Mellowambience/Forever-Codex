import runpy
ctx=runpy.run_path('work/test_release.py'); lua=ctx['lua']
lua.execute('''
function GetRealmName() return "TestRealm" end
function UnitFactionGroup() return "Horde" end
F.readOnly=nil; F.LoadPrices(); F.db.settings.ahCut=5
F.RememberPrice(2318,10000)
local s=F.SellComparison(2318,{sellPrice=100})
assert(string.find(s,"95s",1,true) and string.find(s,"AH may pay more",1,true))
F.db.settings.ahCut=15
assert(string.find(F.SellComparison(2318,{sellPrice=9000}),"Vendor pays",1,true))
F.prices.items[2318].time=time()-3*86400
assert(string.find(F.SellComparison(2318,{sellPrice=100}),"Old price",1,true))
assert(string.find(F.SellComparison(2318,{sellPrice=0,bindType=1}),"not normally tradeable",1,true))
assert(string.find(F.SellComparison(999,{sellPrice=0}),"no price yet",1,true))
function GetNumAuctionItems() return 2 end
function GetAuctionItemLink(_,i) return "item:2318" end
function GetAuctionItemInfo(_,i) return "Leather",nil,20,nil,nil,nil,nil,nil,nil,i==1 and 10000 or 12000 end
F.CaptureAuctionPrices("AUCTION_ITEM_LIST_UPDATE")
assert(F.prices.items[2318].price==500,"Stack buyout must divide by quantity")
C_AuctionHouse={GetNumCommoditySearchResults=function() return 2 end, GetCommoditySearchResultInfo=function(_,i) return {unitPrice=i==1 and 900 or 700} end}
F.CaptureAuctionPrices("COMMODITY_SEARCH_RESULTS_UPDATED",2318); assert(F.prices.items[2318].price==700)
C_AuctionHouse={GetNumItemSearchResults=function() return 1 end,GetItemSearchResultInfo=function() return {quantity=2,buyoutAmount=2000} end}
F.CaptureAuctionPrices("ITEM_SEARCH_RESULTS_UPDATED",{itemID=2318}); assert(F.prices.items[2318].price==1000)
Auctionator={API={v1={GetAuctionPriceByItemID=function() return 777 end,GetAuctionAgeByItemID=function() return 0 end}}}
F.prices.items[2318].time=time()-86400
assert(string.find(F.SellComparison(2318,{sellPrice=0}),"Auctionator",1,true))
Auctionator.API.v1.GetAuctionPriceByItemID=function() error("Unavailable") end
assert(F.SellComparison(2318,{sellPrice=0}))
for i=1,1100 do F.RememberPrice(i,100) end
local n=0; for _ in pairs(F.prices.items) do n=n+1 end; assert(n==1000)
function UnitFactionGroup() return "Alliance" end
F.LoadPrices(); assert(next(F.prices.items)==nil,"Faction cache isolation")
F.RememberPrice(1,0/0); assert(next(F.prices.items)==nil)
F.readOnly=true; F.RememberPrice(1,100); assert(next(F.prices.items)==nil)
GetItemInfo=function() return "Leather","item:2318",1,1,1,"Trade Goods","Leather",20,"",1,15,7,6,2 end
local info=F.ItemInfo(2318); assert(info.sellPrice==15 and info.bindType==2)
''')
print('PASS: vendor metadata, AH cuts, stale/missing/bound items, stack and commodity unit prices, Auctionator fallback, bounded/faction-isolated cache, invalid data and read-only protection')
