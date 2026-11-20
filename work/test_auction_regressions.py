import runpy

lua = runpy.run_path('work/test_seller.py')['lua']
lua.execute("""
F.readOnly=nil; F.safeMode=false; F.auctionOpen=true
F.db.settings.seller.keep={}
F.db.settings.seller.maxDeposit=10000
F.RememberPrice(2318,1000)
C_AuctionHouse.GetItemCommodityStatus=function() return 2 end
C_AuctionHouse.PostCommodity=nil
local itemPosts=0
C_AuctionHouse.PostItem=function() itemPosts=itemPosts+1 end
local rows=F.BuildSaleQueue()
assert(rows[1] and rows[1].reason=="Posting API unavailable on this client",
    "A commodity must not be sent to the ordinary item API")
F.PostNextSale()
assert(itemPosts==0 and not F.salePending)
C_AuctionHouse.PostCommodity=function() return true end
C_AuctionHouse.ConfirmPostCommodity=nil
C_AuctionHouse.ConfirmPostItem=function() itemPosts=itemPosts+1 end
F.PostNextSale()
assert(F.salePending and F.salePending.confirm)
F.SellerEvent("UI_ERROR_MESSAGE")
assert(F.salePending, "Unrelated UI errors must not allow a duplicate listing")
F.ConfirmSale()
assert(not F.salePending and itemPosts==0, "No mismatched confirmation method")
F.PostNextSale()
C_AuctionHouse=nil
F.ConfirmSale()
assert(not F.salePending, "Unavailable auction API must clear pending safely")

local realm=F.prices.realm
ForeverBestiaryPrices={version=1,realm=realm,items={
    [2318]={price=500,time=time()-10},
    ["2318"]={price=1500,time=time()},
}}
F.LoadPrices()
assert(F.priceCount==1 and F.PriceQuote(2318)==1500, "Keep latest normalized quote")
assert(F.PriceQuote("2318")==1500)
F.safeMode=true; F.prices=nil
assert(F.PriceQuote(2318)==nil, "Safe mode can show vendor prices before AH setup")
assert(F.ItemInfo(nil).name=="Unknown item")
F.safeMode=false
F.readOnly=true; F.db.trackedItems={}
F.TrackItem(2318,3)
assert(next(F.db.trackedItems)==nil, "Track item respects read-only recovery")

F.priceTooltipsInstalled=nil
TooltipDataProcessor={AddTooltipPostCall=function() error("Unsupported") end}
Enum={TooltipDataType={Item=0}}
local old=GameTooltip
GameTooltip=nil
local hook
ItemRefTooltip={HookScript=function(_,_,fn) hook=fn end}
F.InstallPriceTooltips()
assert(F.priceTooltipsInstalled and hook, "Missing optional hook falls back without aborting load")
GameTooltip=old
F.priceTooltipsInstalled=nil
local callback
TooltipDataProcessor.AddTooltipPostCall=function(_,fn) callback=fn end
F.InstallPriceTooltips()
callback(nil,{id=2318})
callback({IsForbidden=function() error("Forbidden") end},{id=2318})
""")
print('PASS: missing native posting and tooltip APIs, unrelated errors, price normalization, safe mode and read-only tracking')
