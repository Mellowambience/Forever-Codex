local _, F = ...
function F.SaleSearchTargets(rows)
    local targets,seen={},{}
    for _,row in ipairs(rows or F.BuildSaleQueue()) do
        if (row.reason=="Search item at AH for a dated price" or row.reason=="Price older than two days; search again") and not seen[row.id] then
            seen[row.id]=true; targets[#targets+1]=row.id
        end
    end
    return targets
end
function F.SetSaleStatus(message)
    if F.priceSearch and F.priceSearch.onStatus then F.priceSearch.onStatus(message); return end
    F.sellStatus=message; if F.sellWindow then F.sellWindow.status:SetText(message) end
end
function F.FinishSaleSearch(message)
    local search=F.priceSearch
    F.priceSearch=nil
    if search and search.onStatus then search.onStatus(message) else F.SetSaleStatus(message) end
    if search and search.onDone then search.onDone() end
    F.RefreshSeller()
end
function F.NextSaleSearch()
    local search=F.priceSearch; if not search or search.waiting then return end
    local ah=C_AuctionHouse
    if not ah or not F.auctionOpen or F.salePending or F.safeMode or F.readOnly or F.Safe(InCombatLockdown)==true then
        F.FinishSaleSearch("Price lookup stopped. Reopen the AH and check prices again."); return
    end
    if GetTime()<(search.nextAt or 0) or F.Safe(ah.IsThrottledMessageSystemReady)==false then return end
    local id=search.items[search.index]
    if not id then F.FinishSaleSearch("Prices updated: "..search.found.." quoted, "..search.empty.." with no listings, "..search.unpriced.." without a readable buyout."); return end
    local key=F.Safe(ah.MakeItemKey,id,0,0,0)
    if type(key)~="table" then F.FinishSaleSearch("Could not build this item's AH search. Use the native item search."); return end
    search.waiting=id; search.sent=GetTime(); search.nextAt=GetTime()+1.25
    F.SetSaleStatus("Finding prices: "..search.index.." / "..#search.items..". Waiting for the AH...")
    local ok=pcall(ah.SendSearchQuery,key,{},true)
    if not ok then F.FinishSaleSearch("The AH rejected the price search. Try the price check again when it is ready.") end
end
function F.FindSalePrices(targets, onStatus, onDone)
    local report=onStatus or F.SetSaleStatus
    if F.priceSearch or F.salePending or F.safeMode or F.readOnly or F.Safe(InCombatLockdown)==true then report("Finish the current search or posting first; price checks are unavailable in combat or safe mode."); return end
    if not F.auctionOpen then report("Open the Auction House to find prices."); return end
    local ah=C_AuctionHouse
    if not ah or type(ah.SendSearchQuery)~="function" or type(ah.MakeItemKey)~="function" then report("Use the native AH to search each item; this client does not expose automatic price lookup."); return end
    targets=targets or F.SaleSearchTargets()
    if #targets==0 then report("No missing prices. Kept items remain protected; check their listed reasons."); return end
    while #targets>20 do table.remove(targets) end
    F.priceSearch={items=targets,index=1,found=0,empty=0,unpriced=0,nextAt=0,started=GetTime(),onStatus=onStatus,onDone=onDone}
    if not F.priceSearchWatcher then
        local watcher=CreateFrame("Frame"); F.priceSearchWatcher=watcher
        watcher:SetScript("OnUpdate",function()
            local s=F.priceSearch; if not s then return end
            if not F.auctionOpen then F.FinishSaleSearch("Price lookup stopped: AH closed."); return end
            if GetTime()-s.started>60 then F.FinishSaleSearch("AH is busy. Price lookup stopped; try again when it is ready."); return end
            if s.waiting and GetTime()-s.sent>12 then F.FinishSaleSearch("Price lookup timed out. Try the price check again; no auction was posted."); return end
            F.NextSaleSearch()
        end)
    end
    F.NextSaleSearch(); F.UpdateSaleButton()
end
function F.SalePriceResult(event,key,quotes)
    local search=F.priceSearch; if not search or not search.waiting then return end
    if not F.IsText(event) or not F.Public(key) then return end
    local id=type(key)=="table" and F.ValidID(key.itemID) or F.ValidID(key)
    if id~=search.waiting then return end
    local ah=C_AuctionHouse; if not ah then return end
    local n
    if string.find(event,"COMMODITY",1,true) then n=F.Safe(ah.GetNumCommoditySearchResults,id)
    elseif type(key)=="table" then n=F.Safe(ah.GetNumItemSearchResults,key) end
    if not F.IsNumber(n) then return end
    if n>0 and quotes and quotes[id] then
        search.found=search.found+1
    else
        if n==0 then
            F.noAuctionPrices=F.noAuctionPrices or {}
            local now=time()
            for itemID,stamp in pairs(F.noAuctionPrices) do
                if now-stamp>=120 then F.noAuctionPrices[itemID]=nil end
            end
            F.noAuctionPrices[id]=now
            search.empty=search.empty+1
        else
            search.unpriced=search.unpriced+1
        end
        if F.prices and F.prices.items[id] then
            F.prices.items[id]=nil
            F.priceCount=math.max(0,(F.priceCount or 1)-1)
        end
    end
    search.waiting=nil; search.index=search.index+1; F.RefreshSeller()
end
