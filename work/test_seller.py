import runpy
ctx=runpy.run_path('work/test_release.py'); lua=ctx['lua']
lua.execute('''
F.readOnly=nil
function GetRealmName() return "Realm" end
function UnitFactionGroup() return "Horde" end
function GetMoney() return 100000 end
function InCombatLockdown() return false end
ItemLocation={CreateFromBagAndSlot=function(self,bag,slot) return {bag=bag,slot=slot} end}
local bag={itemID=2318,stackCount=20,isLocked=false,isBound=false,hyperlink="item:2318"}
C_Container={GetContainerNumSlots=function(b) return b==0 and 1 or 0 end,GetContainerItemInfo=function() return bag end}
GetItemInfo=function() return "Leather","item:2318",1,1,1,"Trade Goods","Leather",20,"",1,15,7,6,0 end
local calls=0; local args
C_AuctionHouse={GetItemCommodityStatus=function() return 2 end,GetAvailablePostCount=function() return 20 end,CalculateCommodityDeposit=function() return 100 end,PostCommodity=function(...) calls=calls+1; args={...}; return false end}
F.db.creatures={[123]=F.NormalizeRecord(123,{name="Beast",loot={['2318']={itemID=2318,count=20}}})}
F.db.trackedItems={}; F.db.recipes={}; F.db.trackedRecipes={}; F.db.settings.ahCut=5
local s=F.db.settings.seller; s.keep={}; s.protectRecipes=true; s.stack=5
F.LoadPrices(); F.RememberPrice(2318,1000)
F.OpenSeller(); assert(F.sellWindow:IsShown()); assert(#F.sellWindow.queue==1 and not F.sellWindow.queue[1].reason)
F.PostNextSale(); assert(calls==0,"Never post away from AH")
F.auctionOpen=true; F.RefreshSeller(); F.PostNextSale()
assert(calls==1 and args[2]==2 and args[3]==5 and args[4]==1000)
F.PostNextSale(); assert(calls==1,"No duplicate while pending")
F.SellerEvent("AUCTION_HOUSE_AUCTION_CREATED"); assert(not F.salePending)
F.KeepItem(2318); assert(F.BuildSaleQueue()[1].reason=="Marked Keep")
F.PostNextSale(); assert(calls==1)
F.KeepItem(2318); F.db.trackedItems[2318]=1
assert(F.BuildSaleQueue()[1].reason=="Tracked item"); F.db.trackedItems={}
F.db.recipes[1]={id=1,learnedBy={[F.character]=true},reagents={[2318]=1}}
assert(F.BuildSaleQueue()[1].reason=="Recipe material")
s.protectRecipes=false; assert(not F.BuildSaleQueue()[1].reason)
F.db.trackedRecipes[1]=1; assert(F.BuildSaleQueue()[1].reason=="Recipe material")
F.db.recipes={}; F.db.trackedRecipes={}
F.db.creatures[123].favorite=true; assert(F.BuildSaleQueue()[1].reason=="Bookmarked creature loot"); F.db.creatures[123].favorite=false
bag.isBound=true; assert(F.BuildSaleQueue()[1].reason=="Bound or trade status unavailable"); bag.isBound=false
bag.isLocked=true; assert(F.BuildSaleQueue()[1].reason=="Item locked or status unavailable"); bag.isLocked=false
F.prices.items[2318].time=time()-3*86400; assert(string.find(F.BuildSaleQueue()[1].reason,"older",1,true)); F.RememberPrice(2318,1000)
s.maxDeposit=0; assert(F.BuildSaleQueue()[1].reason=="Deposit exceeds your limit"); s.maxDeposit=10000
s.undercut=true; assert(F.BuildSaleQueue()[1].unitPrice==990); s.undercut=false
C_AuctionHouse.PostCommodity=function(...) calls=calls+1; return true end
C_AuctionHouse.ConfirmPostCommodity=function(...) calls=calls+1; args={...} end
F.PostNextSale(); assert(F.salePending.confirm and calls==2)
F.ConfirmSale(); assert(calls==3 and not F.salePending.confirm and args[3]==5)
F.SellerEvent("AUCTION_HOUSE_AUCTION_CREATED")
F.PostNextSale(); assert(F.salePending.confirm); s.keep[2318]=true; F.ConfirmSale(); assert(not F.salePending and calls==4,"Changed protection prevents confirm"); s.keep={}
C_AuctionHouse.PostCommodity=function() error("Protected function") end
F.PostNextSale(); assert(not F.salePending)
C_AuctionHouse.GetItemCommodityStatus=function() return 1 end
C_AuctionHouse.CalculateItemDeposit=function() return 50 end
C_AuctionHouse.PostItem=function(...) args={...}; calls=calls+1; return false end
F.PostNextSale(); assert(args[3]==5 and args[4]==5000 and args[5]==5000,"Item bid/buyout totals")
F.SellerEvent("AUCTION_HOUSE_CLOSED"); assert(not F.salePending and not F.auctionOpen and not F.sellWindow:IsShown())
s.keep[2318]=true; s.duration=3; s.stack=20; s.maxDeposit=1000; F.LoadStorage()
assert(F.db.settings.seller.keep[2318] and F.db.settings.seller.duration==3 and F.db.settings.seller.stack==20 and F.db.settings.seller.maxDeposit==1000)
F.readOnly=true; F.auctionOpen=true; local before=calls; F.PostNextSale(); assert(calls==before)
''')
print('PASS: seller UI, post arguments, stack/fees/deposit rules, all item protections, no duplicate posts, native confirmation/error handling, close cancellation, settings persistence and read-only guard')

