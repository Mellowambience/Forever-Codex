local _, F = ...
local function positive(v) return F.IsNumber(v) and v>=1 and v<1000000000000 end
local function realmKey()
    local realm=F.Safe(GetRealmName); local faction=F.Safe(UnitFactionGroup,"player")
    if F.IsText(realm) and F.IsText(faction) then return realm..":"..faction end
end
function F.LoadPrices()
    local key=realmKey(); local old=ForeverBestiaryPrices; local rows={}; local latest={}
    local now=time()
    if key and type(old)=="table" and old.version==1 and old.realm==key and type(old.items)=="table" then
        for id,v in pairs(old.items) do
            local itemID=F.ValidID(id)
            if itemID and type(v)=="table" and positive(v.price) and F.IsNumber(v.time) and v.time<=now and now-v.time<=604800 then
                local previous=latest[itemID]
                if not previous or v.time>previous.time then
                    latest[itemID]={id=itemID,price=math.floor(v.price),time=v.time}
                end
            end
        end
    end
    for _,entry in pairs(latest) do rows[#rows+1]=entry end
    table.sort(rows,function(a,b) return a.time>b.time end)
    F.prices={version=1,realm=key,items={}}; F.priceCount=math.min(1000,#rows)
    for i=1,F.priceCount do local v=rows[i]; F.prices.items[v.id]={price=v.price,time=v.time} end
    if not F.readOnly and key then ForeverBestiaryPrices=F.prices end
end
function F.RememberPrice(id,price)
    id=F.ValidID(id)
    if not id or not positive(price) or not F.prices or not F.prices.realm or F.readOnly then return end
    local rows=F.prices.items
    if not rows[id] then
        if F.priceCount>=1000 then
            local oldest,stamp; for item,v in pairs(rows) do if not stamp or v.time<stamp then oldest,stamp=item,v.time end end
            if oldest then rows[oldest]=nil; F.priceCount=F.priceCount-1 end
        end
        F.priceCount=F.priceCount+1
    end
    rows[id]={price=math.floor(price),time=time()}; if F.noAuctionPrices then F.noAuctionPrices[id]=nil end
end
-- Read only results the player has already requested. Never query, buy, sell or post.
function F.CaptureAuctionPrices(event,key)
    local low={}
    if F.safeMode or not F.IsText(event) or not F.Public(key) then return low end
    local function add(id,price)
        id=F.ValidID(id)
        if id and positive(price) then low[id]=math.min(low[id] or price,price) end
    end
    local ah=C_AuctionHouse
    if event=="AUCTION_ITEM_LIST_UPDATE" then
        local n=F.Safe(GetNumAuctionItems,"list")
        if F.IsNumber(n) then for i=1,math.min(n,500) do
            local link=F.Safe(GetAuctionItemLink,"list",i)
            local values=type(GetAuctionItemInfo)=="function" and {pcall(GetAuctionItemInfo,"list",i)} or {}
            local id=F.IsText(link) and F.ValidID(string.match(link,"item:(%d+)"))
            if values[1] and positive(values[4]) and positive(values[11]) then add(id,values[11]/values[4]) end
        end end
    elseif ah and string.find(event,"COMMODITY",1,true) and F.ValidID(key) then
        local n=F.Safe(ah.GetNumCommoditySearchResults,key)
        if F.IsNumber(n) then for i=1,math.min(n,500) do local r=F.Safe(ah.GetCommoditySearchResultInfo,key,i); if type(r)=="table" then add(key,r.unitPrice) end end end
    elseif ah and type(key)=="table" and F.ValidID(key.itemID) then
        local n=F.Safe(ah.GetNumItemSearchResults,key)
        if F.IsNumber(n) then for i=1,math.min(n,500) do local r=F.Safe(ah.GetItemSearchResultInfo,key,i); if type(r)=="table" and positive(r.quantity) and positive(r.buyoutAmount) then add(key.itemID,r.buyoutAmount/r.quantity) end end end
    end
    for id,price in pairs(low) do F.RememberPrice(id,price) end
    F.Refresh()
    return low
end
function F.Money(n)
    if not F.IsNumber(n) then return "unknown" end
    n=math.max(0,math.floor(n)); local g=math.floor(n/10000); local s=math.floor(n/100)%100; local c=n%100
    return (g>0 and (g.."g ") or "")..(s>0 and (s.."s ") or "")..c.."c"
end
function F.PriceQuote(id)
    if F.safeMode then return end
    id=F.ValidID(id)
    if not id then return end
    if F.noAuctionPrices and F.noAuctionPrices[id] and time()-F.noAuctionPrices[id]<120 then return end
    local entry=F.prices and F.prices.items[id]; local price,age,source
    if entry then price=entry.price; age=math.max(0,time()-entry.time)/86400; source="your AH search" end
    local versions=type(Auctionator)=="table" and Auctionator.API
    local api=type(versions)=="table" and versions.v1
    if type(api)=="table" and type(api.GetAuctionPriceByItemID)=="function" then
        local p=F.Safe(api.GetAuctionPriceByItemID,"ForeverBestiary",id)
        local a=F.Safe(api.GetAuctionAgeByItemID,"ForeverBestiary",id)
        if positive(p) and F.IsNumber(a) and a>=0 and (not age or a<age) then price,age,source=p,a,"Auctionator" end
    end
    return price,age,source
end
function F.SellComparison(id,info)
    info=info or F.ItemInfo(id)
    local vendor=info.sellPrice; local prefix="Vendor / each: "..F.Money(vendor)
    if info.bindType==1 or info.bindType==4 then return prefix.." | AH: not normally tradeable" end
    local price,age,source=F.PriceQuote(id)
    if not price then return prefix.."\nAH: no price yet. Search this item at the Auction House." end
    local cut=F.db.settings.ahCut or 5; local net=math.floor(price*(100-cut)/100)
    local old=age>2
    local advice=old and "Old price: refresh before deciding." or (F.IsNumber(vendor) and (net>vendor and "AH may pay more if it sells." or "Vendor pays at least as much.") or "Vendor value unavailable.")
    return prefix.." | AH guide / each: "..F.Money(price).."\nNet if sold ("..cut.."% cut): "..F.Money(net).." | "..advice.."\n"..source.." | "..(age<1 and "under 1 day old" or (math.floor(age).." days old")).." | Base item estimate; variants/binding may differ.\nDeposits, failed listings and demand are not included."
end
