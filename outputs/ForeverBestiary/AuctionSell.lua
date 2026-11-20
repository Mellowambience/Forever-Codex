local _, F = ...
local function valid(v) return F.IsNumber(v) and v>=0 and v<1000000000000 end
local function inCombat() return F.Safe(InCombatLockdown)==true end
local function config() return F.db.settings.seller end
local function status(message) F.sellStatus=message; if F.sellWindow then F.sellWindow.status:SetText(message) end end
local function postFunction(ah,commodity,confirm)
    if not ah then return end
    if commodity then
        if confirm then return ah.ConfirmPostCommodity end
        return ah.PostCommodity
    end
    if confirm then return ah.ConfirmPostItem end
    return ah.PostItem
end
local function location(bag,slot)
    if ItemLocation and ItemLocation.CreateFromBagAndSlot then return F.Safe(ItemLocation.CreateFromBagAndSlot,ItemLocation,bag,slot) end
end
function F.KeepItem(itemID)
    itemID=F.ValidID(itemID); if not itemID or F.readOnly then return end
    local keep=config().keep
    if keep[itemID] then keep[itemID]=nil else
        local n=0; for _ in pairs(keep) do n=n+1 end
        if n>=1000 then F.Message("Your Keep list is full (1,000 items)."); return end
        keep[itemID]=true
    end
    if F.RefreshSeller then F.RefreshSeller() end; F.Refresh()
end
function F.SaleProtection()
    local known,protected={},{}
    for item in pairs(config().keep) do protected[item]="Marked Keep" end
    for item in pairs(F.db.trackedItems) do protected[item]="Tracked item" end
    for _,recipe in pairs(F.db.recipes) do
        if recipe.learnedBy[F.character] and (config().protectRecipes or F.db.trackedRecipes[recipe.id]) then
            for item in pairs(recipe.reagents) do protected[item]="Recipe material" end
        end
    end
    for _,r in pairs(F.db.creatures) do
        local materials=F.MaterialsForCreature(r)
        for id in pairs(materials) do known[id]=true; if r.favorite then protected[id]="Bookmarked creature loot" end end
    end
    return known,protected
end
local function bagItem(bag,slot)
    local api=C_Container; local item=api and F.Safe(api.GetContainerItemInfo,bag,slot)
    if type(item)~="table" then return end
    local itemID=F.ValidID(item.itemID)
    if not itemID or not valid(item.stackCount) or item.stackCount<1 or not F.IsText(item.hyperlink) then return end
    local loc=location(bag,slot); if not loc then return end
    return {id=itemID,count=item.stackCount,locked=item.isLocked,bound=item.isBound,link=item.hyperlink,location=loc,bag=bag,slot=slot}
end
function F.SaleCandidate(item,known,protected)
    local id=item.id; local info=F.ItemInfo(id); local settings=config()
    local row={id=id,name=info.name,info=info,bag=item.bag,slot=item.slot,location=item.location,count=item.count,link=item.link}
    local function skip(reason) row.reason=reason; return row end
    if not known[id] then return skip("Not recorded bestiary loot") end
    if protected[id] then return skip(protected[id]) end
    if not F.Public(item.locked) or item.locked~=false then return skip("Item locked or status unavailable") end
    local bound=item.bound
    if not F.Public(bound) then return skip("Bound or trade status unavailable") end
    if bound==nil then bound=F.Safe(C_Item and C_Item.IsBound,item.location) end
    if bound~=false or info.bindType==1 or info.bindType==4 then return skip("Bound or trade status unavailable") end
    if info.classID==2 or info.classID==4 or info.classID==17 or info.quality and info.quality>=2 then return skip("Equipment, pets and uncommon+ items kept") end
    if info.classID==12 then return skip("Quest item kept") end
    if not F.IsNumber(info.quality) or not valid(info.sellPrice) then return skip("Item details loading") end
    if F.noAuctionPrices and F.noAuctionPrices[id] and time()-F.noAuctionPrices[id]<120 then return skip("No current AH listings found; try again later") end
    local price,age,source=F.PriceQuote(id)
    if not valid(price) or price<1 or not valid(age) then return skip("Search item at AH for a dated price") end
    if age>2 then return skip("Price older than two days; search again") end
    price=math.max(1,math.floor(price*(settings.undercut and .99 or 1)))
    if price<settings.minUnit then return skip("Below your minimum unit price") end
    if math.floor(price*(100-(F.db.settings.ahCut or 5))/100)<=info.sellPrice then return skip("Vendor pays at least as much") end
    local ah=C_AuctionHouse
    if not ah then return skip("Posting API unavailable on this client") end
    local commodity=F.Safe(ah.GetItemCommodityStatus,item.location)
    local enums=Enum and Enum.ItemCommodityStatus
    if commodity==(enums and enums.Commodity or 2) then row.commodity=true
    elseif commodity~=(enums and enums.Item or 1) then return skip("Auction eligibility unavailable") end
    if type(postFunction(ah,row.commodity,false))~="function" then return skip("Posting API unavailable on this client") end
    row.quantity=math.min(item.count,settings.stack); row.unitPrice=price; row.duration=settings.duration; row.source=source
    local available=F.Safe(ah.GetAvailablePostCount,item.location)
    if not valid(available) or available<row.quantity then return skip("Item is not available for auction") end
    local deposit
    if row.commodity then deposit=F.Safe(ah.CalculateCommodityDeposit,id,row.duration,row.quantity)
    else deposit=F.Safe(ah.CalculateItemDeposit,item.location,row.duration,row.quantity) end
    if not valid(deposit) then return skip("Deposit unavailable") end
    if deposit>settings.maxDeposit then return skip("Deposit exceeds your limit") end
    local money=F.Safe(GetMoney)
    if not valid(money) or deposit>money then return skip("Not enough gold for deposit") end
    local net=math.floor(price*row.quantity*(100-(F.db.settings.ahCut or 5))/100)
    if net-deposit<=info.sellPrice*row.quantity then return skip("Deposit leaves too little advantage over vendor") end
    row.deposit=deposit; row.net=net; return row
end
function F.BuildSaleQueue()
    local rows={}; if not F.db then return rows end
    local known,protected=F.SaleProtection()
    if not C_Container or type(C_Container.GetContainerNumSlots)~="function" then return rows end
    local last=NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    last=F.IsNumber(last) and math.min(5,last) or 4
    for bag=0,last do
        local n=F.Safe(C_Container.GetContainerNumSlots,bag)
        if valid(n) then for slot=1,math.min(n,100) do
            local item=bagItem(bag,slot)
            if item and known[item.id] then rows[#rows+1]=F.SaleCandidate(item,known,protected) end
        end end
    end
    table.sort(rows,function(a,b) if (a.reason==nil)~=(b.reason==nil) then return a.reason==nil end; if a.name~=b.name then return a.name<b.name end; if a.bag~=b.bag then return a.bag<b.bag end; return a.slot<b.slot end)
    return rows
end
function F.PostNextSale()
    if F.safeMode or F.readOnly or inCombat() or not F.auctionOpen then status("Open the Auction House to post."); return end
    if F.priceSearch then status("Wait for the current price search to finish."); return end
    if F.salePending then status("Waiting for the game. Refresh clears a timed-out request after 15 seconds."); return end
    local rows=F.BuildSaleQueue(); local row=rows[1]
    if not row or row.reason then
        if F.FindSalePrices and #F.SaleSearchTargets(rows)>0 then F.FindSalePrices(); return end
        local reasons={}; for _,r in ipairs(rows) do reasons[r.reason or "Unknown"]=true end
        local list=F.Keys(reasons); while #list>3 do table.remove(list) end
        status("Nothing eligible: "..(#rows==0 and "no recorded loot in bags." or table.concat(list,"; "))); F.RefreshSeller(); return
    end
    -- Re-read this exact slot immediately before posting; never rely on an old queue.
    local current=bagItem(row.bag,row.slot)
    if not current or current.id~=row.id or current.count~=row.count or current.link~=row.link
        or not F.Public(current.locked) or current.locked~=false or not F.Public(current.bound)
        or (current.bound~=nil and current.bound~=false) then
        status("Bags changed; queue refreshed."); F.RefreshSeller(); return
    end
    local ah=C_AuctionHouse
    F.salePending={row=row,started=GetTime()}; status("Posting "..row.quantity.." x "..row.name.."...")
    local ok,confirmation
    if row.commodity then ok,confirmation=pcall(ah.PostCommodity,row.location,row.duration,row.quantity,row.unitPrice)
    else local total=row.unitPrice*row.quantity; ok,confirmation=pcall(ah.PostItem,row.location,row.duration,row.quantity,total,total) end
    if not ok then F.salePending=nil; status("The game blocked posting. Use its auction controls or try again from Post next.")
    elseif F.Public(confirmation) and confirmation==true and F.salePending then
        F.salePending.confirm=true; status("The game requires price confirmation. Use Confirm price to continue.")
    end
    F.UpdateSaleButton()
end
function F.ConfirmSale()
    local pending=F.salePending
    if not pending or not pending.confirm or not F.auctionOpen or inCombat() or F.readOnly or F.safeMode then return end
    local row=pending.row; local current=bagItem(row.bag,row.slot)
    local known,protected=F.SaleProtection()
    local fresh=current and current.id==row.id and current.link==row.link and F.SaleCandidate(current,known,protected)
    if not fresh or fresh.reason or fresh.commodity~=row.commodity or fresh.unitPrice~=row.unitPrice or fresh.quantity~=row.quantity or fresh.deposit~=row.deposit or fresh.duration~=row.duration then
        F.Safe(C_AuctionHouse and C_AuctionHouse.CancelSell); F.salePending=nil; status("Item or rules changed. Build a new posting request."); F.UpdateSaleButton(); return
    end
    local fn=postFunction(C_AuctionHouse,row.commodity,true)
    if type(fn)~="function" then
        F.Safe(C_AuctionHouse and C_AuctionHouse.CancelSell)
        F.salePending=nil; status("Confirmation unavailable. Use the native Auction House to list this item."); F.UpdateSaleButton(); return
    end
    pending.confirm=nil; pending.started=GetTime(); status("Confirming auction...")
    local ok
    if row.commodity then ok=pcall(fn,row.location,row.duration,row.quantity,row.unitPrice)
    else local total=row.unitPrice*row.quantity; ok=pcall(fn,row.location,row.duration,row.quantity,total,total) end
    if not ok then F.salePending=nil; status("Confirmation was blocked by the game. Use native auction controls.") end
    F.UpdateSaleButton()
end
function F.SellerEvent(event,...)
    if event=="AUCTION_HOUSE_SHOW" then
        F.auctionOpen=true; if config().autoOpen and not inCombat() then F.OpenSeller() end
    elseif event=="AUCTION_HOUSE_CLOSED" then
        F.auctionOpen=nil; F.salePending=nil; if F.priceSearch then F.FinishSaleSearch("Price lookup stopped: AH closed.") end; if F.sellWindow then F.CloseManaged("seller") end
    elseif event=="AUCTION_HOUSE_AUCTION_CREATED" and F.salePending then
        F.salePending=nil; status("Auction created. Post next continues the queue."); F.UpdateSaleButton()
    elseif event=="AUCTION_HOUSE_POST_ERROR" and F.salePending then
        F.salePending=nil; status("The game reported an error. Queue stopped; refresh before trying again."); F.UpdateSaleButton()
    elseif not F.salePending and F.sellWindow and F.sellWindow:IsShown() then
        if event=="BAG_UPDATE_DELAYED" then
            F.RefreshSeller()
        elseif event=="GET_ITEM_INFO_RECEIVED" then
            local itemID,success=...
            itemID=F.ValidID(itemID)
            if itemID and F.Public(success) and success==true then
                for _,row in ipairs(F.sellWindow.queue or {}) do
                    if row.id==itemID and row.reason=="Item details loading" then F.RefreshSeller(); return end
                end
            end
        end
    end
end
local function label(parent,value,x,y,width,font)
    local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall"); t:SetPoint("TOPLEFT",x,y); t:SetWidth(width); t:SetJustifyH("LEFT"); t:SetText(value); return t
end
local function button(parent,value,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetPoint("TOPLEFT",x,y); b:SetSize(width,25); b:SetText(value); b:SetScript("OnClick",fn); return b
end
function F.UpdateSaleButton()
    if not F.sellWindow then return end
    local b=F.sellWindow.post; local pending=F.salePending
    local needPrices=F.SaleSearchTargets and #F.SaleSearchTargets(F.sellWindow.queue or {})>0 and (F.sellWindow.ready or 0)==0
    b:SetText(pending and pending.confirm and "Confirm price" or pending and "Waiting..." or F.priceSearch and "Finding prices..." or needPrices and "Find prices" or "Post next")
    if F.auctionOpen and not inCombat() and not F.readOnly and not F.priceSearch and (not pending or pending.confirm) then b:Enable() else b:Disable() end
end
function F.RefreshSeller()
    local w=F.sellWindow; if not w or not w:IsShown() then return end
    w.queue=F.BuildSaleQueue(); local ready=0
    for _,r in ipairs(w.queue) do if not r.reason then ready=ready+1 end end
    w.ready=ready
    w.summary:SetText(ready.." eligible stacks | "..(#w.queue-ready).." kept / skipped | prices per item")
    for _,r in ipairs(w.rows) do r:Hide() end
    local y=0
    for i,entry in ipairs(w.queue) do
        local r=w.rows[i]
        if not r then
            r=CreateFrame("Frame",nil,w.content); r:SetSize(402,68)
            r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetSize(24,24); r.icon:SetPoint("TOPLEFT",0,-2)
            r.title=label(r,"",32,0,278,"GameFontNormalSmall"); r.detail=label(r,"",32,-20,278)
            r:EnableMouse(true); r:SetScript("OnEnter",function(self) F.ShowItemTooltip(self,self.entry.id,self.entry.link) end); r:SetScript("OnLeave",function() GameTooltip:Hide() end)
            r.keep=button(r,"Keep",324,0,75,function() F.KeepItem(r.entry.id) end)
            w.rows[i]=r
        end
        r.entry=entry; r.icon:SetTexture(entry.info.icon); r:ClearAllPoints(); r:SetPoint("TOPLEFT",0,-y); r:Show()
        r.title:SetText(entry.name.." x "..(entry.quantity or entry.count))
        r.detail:SetText(entry.reason or ("List: "..F.Money(entry.unitPrice).." each | net: "..F.Money(entry.net).."\nDeposit: "..F.Money(entry.deposit).." | "..(entry.source or "AH search")))
        r.keep:SetText(config().keep[entry.id] and "Unkeep" or "Keep")
        r.detail:ClearAllPoints(); r.detail:SetPoint("TOPLEFT",32,-r.title:GetStringHeight()-5)
        local height=math.max(38,r.title:GetStringHeight()+r.detail:GetStringHeight()+9); r:SetHeight(height); y=y+height+5
    end
    w.content:SetHeight(math.max(1,y)); w.content:SetWidth(402); F.UpdateSaleButton()
end
function F.ArrangeSeller()
    local w=F.sellWindow; if not w then return end
    local s=config(); local listTop=w.rulesOpen and 254 or 142
    w.rules:SetShown(w.rulesOpen==true); w.rulesToggle:SetText(w.rulesOpen and "Hide rules" or "Selling rules")
    w.ruleSummary:SetText(({"12h","24h","48h"})[s.duration].." | "..(s.undercut and "Undercut 1%" or "Match price").." | "..(s.stack==1000 and "Whole stack" or (s.stack.." per stack")))
    w.summary:ClearAllPoints(); w.summary:SetPoint("TOPLEFT",16,-listTop+24)
    w.scroll:ClearAllPoints(); w.scroll:SetPoint("TOPLEFT",16,-listTop); w.scroll:SetSize(402,600-listTop-132)
    w.duration:SetChoice(({"12 hours","24 hours","48 hours"})[s.duration])
    w.pricing:SetChoice(s.undercut and "Undercut 1%" or "Match price")
    w.stack:SetChoice(s.stack==1000 and "Whole stack" or ("Stack: "..s.stack))
    w.deposit:SetChoice("Max deposit: "..F.Money(s.maxDeposit)); w.floor:SetChoice("Minimum: "..F.Money(s.minUnit))
    w.recipes:SetChoice(s.protectRecipes and "Keep recipe materials" or "Sell untracked materials")
    w.cut:SetChoice("AH cut: "..(F.db.settings.ahCut or 5).."%")
end
function F.OpenSeller()
    if F.safeMode then F.Message("Auction seller is paused in safe mode. Use /fbc safe and reload to re-enable it."); return end
    if inCombat() then F.Message("Open the auction seller after combat."); return end
    local w=F.sellWindow
    if not w then
        w=CreateFrame("Frame","ForeverBestiarySeller",UIParent,"BasicFrameTemplateWithInset"); F.sellWindow=w
        w:SetSize(460,600); w:SetPoint("CENTER"); F.RegisterWindow("seller",w,460,600)
        w:SetMovable(true); w:EnableMouse(true); w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart",function(self) if not inCombat() then self:StartMoving() end end)
        w:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); F.SaveWindowPosition("seller") end)
        w.TitleText:SetText("Forever Codex | Auction seller"); tinsert(UISpecialFrames,"ForeverBestiarySeller")
        w:SetScript("OnHide",function() F.HideDropdowns(); F.ManagedHidden("seller") end)
        label(w,"Sell recorded loot from your bags. Tracked items and Keep items stay protected.\nEquipment, pets and uncommon+ loot stay in your bags.",16,-40,428)
        w.ruleSummary=label(w,"",16,-83,300,"GameFontNormalSmall")
        w.rulesToggle=button(w,"Selling rules",332,-76,112,function() w.rulesOpen=not w.rulesOpen; F.HideDropdowns(); F.ArrangeSeller() end)
        w.rules=CreateFrame("Frame",nil,w); w.rules:SetPoint("TOPLEFT",16,-110); w.rules:SetSize(428,105)
        local function update() F.ArrangeSeller(); F.RefreshSeller() end
        w.duration=F.Dropdown(w.rules,"24 hours",0,0,112,function() return {"12 hours","24 hours","48 hours"} end,function(v) config().duration=v=="12 hours" and 1 or v=="48 hours" and 3 or 2; update() end)
        w.pricing=F.Dropdown(w.rules,"Match price",120,0,136,function() return {"Match price","Undercut 1%"} end,function(v) config().undercut=v=="Undercut 1%"; update() end)
        w.stack=F.Dropdown(w.rules,"Whole stack",264,0,164,function() return {"Whole stack","Stack: 1","Stack: 5","Stack: 20","Stack: 200"} end,function(v) config().stack=tonumber(string.match(v,"(%d+)")) or 1000; update() end)
        w.recipes=F.Dropdown(w.rules,"Keep recipe materials",0,-32,260,function() return {"Keep recipe materials","Sell untracked materials"} end,function(v) config().protectRecipes=v=="Keep recipe materials"; update() end)
        w.cut=F.Dropdown(w.rules,"AH cut: 5%",268,-32,160,function() return {"AH cut: 5%","AH cut: 15%"} end,function(v) F.db.settings.ahCut=v=="AH cut: 15%" and 15 or 5; update(); F.Refresh() end)
        w.floor=F.Dropdown(w.rules,"Minimum: 1c",0,-64,160,function() return {"Minimum: 1c","Minimum: 1s","Minimum: 1g"} end,function(v) config().minUnit=v=="Minimum: 1g" and 10000 or v=="Minimum: 1s" and 100 or 1; update() end)
        w.deposit=F.Dropdown(w.rules,"Max deposit: 1g",168,-64,260,function() return {"Max deposit: 10s", "Max deposit: 1g", "Max deposit: 10g"} end,function(v) config().maxDeposit=v=="Max deposit: 10s" and 1000 or v=="Max deposit: 10g" and 100000 or 10000; update() end)
        w.summary=label(w,"",16,-118,428,"GameFontNormalSmall")
        w.scroll=CreateFrame("ScrollFrame",nil,w,"UIPanelScrollFrameTemplate")
        w.content=CreateFrame("Frame",nil,w.scroll); w.content:SetSize(402,1); w.scroll:SetScrollChild(w.content); w.rows={}
        w.status=label(w,"",16,-482,428)
        w.post=button(w,"Post next",16,-550,124,function() if F.salePending and F.salePending.confirm then F.ConfirmSale() else F.PostNextSale() end end)
        button(w,"Refresh",148,-550,88,function()
            if F.salePending and GetTime()-F.salePending.started<15 then status("Still waiting for the game; no second request sent."); return end
            if F.salePending then F.Safe(C_AuctionHouse and C_AuctionHouse.CancelSell) end
            F.salePending=nil; status("Queue refreshed. Failed listings can lose their deposit."); F.RefreshSeller()
        end)
        button(w,"Back to codex",244,-550,112,function() F.CreateUI(); F.ShowManaged("journal"); F.Render() end)
        button(w,"Close",364,-550,80,function() F.CloseManaged("seller") end)
    end
    F.ArrangeSeller(); F.ShowManaged("seller")
    status(F.salePending and F.sellStatus or (F.auctionOpen and "Ready. Post next uses the game's posting click; a sale is not guaranteed." or "Open the AH, then Find prices to load quotes. You can manage Keep items here anytime."))
    F.RefreshSeller()
end
