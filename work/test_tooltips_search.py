import runpy
ctx=runpy.run_path('work/test_release.py'); lua=ctx['lua']
lua.execute('''
F.readOnly=nil; F.db.creatures={}; F.db.trackedItems={}; F.db.trackedRecipes={}; F.db.recipes={}; F.db.settings.seller.keep={}
function UnitFactionGroup() return "Horde" end
function GetMoney() return 100000 end
GetItemInfo=function(id) return "Material "..id,"item:"..id,1,1,1,"Trade Goods","Cloth",20,"",1,15,7,5,0 end
ItemLocation={CreateFromBagAndSlot=function(self,bag,slot) return {bag=bag,slot=slot} end}
C_Container={GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end,GetContainerItemInfo=function(_,slot) return {itemID=slot==1 and 2318 or 2589,stackCount=3,isLocked=false,isBound=false,hyperlink="item:"..(slot==1 and 2318 or 2589)} end}
F.db.creatures[1]=F.NormalizeRecord(1,{loot={a={itemID=2318,count=1},b={itemID=2589,count=1}}})
F.LoadPrices(); F.auctionOpen=true
local searches,posts={},0; local resultCount=1
C_AuctionHouse={MakeItemKey=function(id) return {itemID=id} end,IsThrottledMessageSystemReady=function() return true end,SendSearchQuery=function(key) searches[#searches+1]=key.itemID end,GetNumCommoditySearchResults=function() return resultCount end,GetCommoditySearchResultInfo=function() return {unitPrice=1000} end,GetItemCommodityStatus=function() return 2 end,GetAvailablePostCount=function() return 3 end,CalculateCommodityDeposit=function() return 10 end,PostCommodity=function() posts=posts+1; return false end}
F.OpenSeller(); assert(F.sellWindow.post.text=="Find prices")
F.PostNextSale(); assert(F.priceSearch and #searches==1 and posts==0,"Missing prices must search rather than silently refuse")
F.FindSalePrices(); assert(#searches==1,"Duplicate clicks cannot duplicate searches")
local first=searches[1]; F.SalePriceResult("COMMODITY_SEARCH_RESULTS_UPDATED",999); assert(F.priceSearch.waiting==first)
F.SalePriceResult("COMMODITY_SEARCH_RESULTS_UPDATED",first,F.CaptureAuctionPrices("COMMODITY_SEARCH_RESULTS_UPDATED",first))
assert(not F.priceSearch.waiting and F.priceSearch.found==1)
clock=clock+1.3; F.NextSaleSearch(); assert(#searches==2)
local second=searches[2]; resultCount=0; F.SalePriceResult("COMMODITY_SEARCH_RESULTS_UPDATED",second,F.CaptureAuctionPrices("COMMODITY_SEARCH_RESULTS_UPDATED",second))
assert(F.noAuctionPrices[second] and not F.PriceQuote(second))
clock=clock+1.3; F.NextSaleSearch(); assert(not F.priceSearch and F.sellWindow.post.text=="Post next")
local rows=F.BuildSaleQueue(); assert(not rows[1].reason and rows[2].reason=="No current AH listings found; try again later")
F.PostNextSale(); assert(posts==1 and F.salePending)
F.SellerEvent("AUCTION_HOUSE_AUCTION_CREATED")
-- Tooltip callback must support bag/link tooltips, deduplicate and honour the configured rule.
local tooltip={lines={}}
function tooltip:AddLine(text) self.lines[#self.lines+1]=text end
function tooltip:AddDoubleLine(a,b) self.lines[#self.lines+1]=a..": "..b end
function tooltip:NumLines() return #self.lines end
function tooltip:IsForbidden() return false end
F.db.settings.seller.undercut=true; F.db.settings.ahCut=5
F.AppendPriceTooltip(tooltip,first)
local content=table.concat(tooltip.lines,"\\n")
assert(string.find(content,"Current search quote: 10s",1,true))
assert(string.find(content,"Suggested listing: 9s 90c",1,true) and string.find(content,"After 5% cut: 9s 40c",1,true))
local n=#tooltip.lines; F.AppendPriceTooltip(tooltip,first); assert(#tooltip.lines==n)
tooltip.lines={}; F.AppendPriceTooltip(tooltip,second); assert(string.find(table.concat(tooltip.lines," "),"No listings found",1,true))
local callback
TooltipDataProcessor={AddTooltipPostCall=function(kind,fn) callback=fn end}; Enum={TooltipDataType={Item=0}}
F.InstallPriceTooltips(); assert(callback); tooltip.lines={}; callback(tooltip,{id=first}); assert(#tooltip.lines>0)
local old=#tooltip.lines; callback(tooltip,{id="SECRET"}); assert(#tooltip.lines==old)
function tooltip:IsForbidden() return true end
F.AppendPriceTooltip(tooltip,second); assert(#tooltip.lines==old)
-- Empty-result and timeout paths cannot post or leave the primary button waiting forever.
F.prices.items={}; F.noAuctionPrices=nil; F.FindSalePrices(); assert(F.priceSearch)
clock=clock+13; F.priceSearchWatcher.scripts.OnUpdate(); assert(not F.priceSearch and posts==1)
F.FindSalePrices(); F.auctionOpen=false; F.priceSearchWatcher.scripts.OnUpdate(); assert(not F.priceSearch)
''')
print('PASS: missing-price-to-search-to-post flow, bounded serialized queries, unrelated results, empty listings, duplicate clicks, quote/recommendation tooltip, modern hook, restricted tooltips, timeout and AH-close recovery')
