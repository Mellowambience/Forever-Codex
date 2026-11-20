local _, F = ...
local tooltipPrices=setmetatable({},{__mode="k"})
local function usableTooltip(tooltip)
    if not F.Public(tooltip) then return false end
    local kind=type(tooltip)
    if kind~="table" and kind~="userdata" then return false end
    if type(tooltip.IsForbidden)=="function" and F.Safe(tooltip.IsForbidden,tooltip)~=false then return false end
    return true
end
function F.PriceAge(age)
    if not F.IsNumber(age) then return "age unknown" end
    if age<1/1440 then return "just now" end
    if age<1/24 then return math.floor(age*1440).."m ago" end
    if age<1 then return math.floor(age*24).."h ago" end
    return math.floor(age).."d ago"
end
function F.PriceRecommendation(id,info)
    local price,age,source=F.PriceQuote(id); info=info or F.ItemInfo(id)
    if F.noAuctionPrices and F.noAuctionPrices[id] and time()-F.noAuctionPrices[id]<120 then return nil,"No listings found in the latest AH search." end
    if not F.IsNumber(price) or price<=0 or not F.IsNumber(age) or age<0 then return nil,"Find prices at the Auction House." end
    if age>2 then return nil,"Refresh the old AH quote first." end
    if info.bindType==1 or info.bindType==4 then return nil,"Normally untradeable." end
    local seller=F.db.settings.seller
    local recommendation=math.max(1,math.floor(price*(seller.undercut and .99 or 1)))
    if recommendation<seller.minUnit then return nil,"Below your minimum unit price." end
    local net=math.floor(recommendation*(100-(F.db.settings.ahCut or 5))/100)
    if F.IsNumber(info.sellPrice) and net<=info.sellPrice then return nil,"Vendor pays at least as much." end
    return recommendation,nil,net,source
end
function F.AppendPriceTooltip(tooltip,id)
    id=F.ValidID(id)
    if F.safeMode or not id or not F.db or not usableTooltip(tooltip) or type(tooltip.AddLine)~="function" then return end
    local lines=F.Safe(tooltip.NumLines,tooltip)
    local previous=tooltipPrices[tooltip]
    if previous and previous.id==id and F.IsNumber(lines) and lines==previous.lines then return end
    local info=F.ItemInfo(id); local price,age,source=F.PriceQuote(id)
    tooltip:AddLine(" "); tooltip:AddLine("Forever Codex | per item",.84,.71,.43)
    local function line(label,value)
        if tooltip.AddDoubleLine then tooltip:AddDoubleLine(label,value,.8,.8,.8,1,1,1) else tooltip:AddLine(label..": "..value,1,1,1,true) end
    end
    line("Vendor",F.Money(info.sellPrice))
    if price then
        line(F.auctionOpen and source=="your AH search" and age and age<1/1440 and "Current search quote" or "Last seen AH quote",F.Money(price))
        tooltip:AddLine((source or "AH search").." | "..F.PriceAge(age),.65,.7,.65,true)
    else line("AH quote","Not available") end
    local recommendation,reason,net=F.PriceRecommendation(id,info)
    if recommendation then
        line("Suggested listing",F.Money(recommendation))
        line("After "..(F.db.settings.ahCut or 5).."% cut",F.Money(net))
        tooltip:AddLine("Asking-price guide; deposits and demand excluded.",.65,.7,.65,true)
        if info.classID==2 or info.classID==4 then tooltip:AddLine("Base item estimate; check binding and variant.",.65,.7,.65,true) end
    else tooltip:AddLine(reason,.9,.75,.4,true) end
    if F.db.settings.seller.keep[id] then tooltip:AddLine("Protected: Keep",.4,.9,.5) end
    tooltipPrices[tooltip]={id=id,lines=F.Safe(tooltip.NumLines,tooltip)}
end
function F.ShowItemTooltip(owner,id,link)
    id=F.ValidID(id)
    if not id or not usableTooltip(GameTooltip) then return end
    if not pcall(GameTooltip.SetOwner,GameTooltip,owner,"ANCHOR_RIGHT") then return end
    tooltipPrices[GameTooltip]=nil
    local ok
    if type(GameTooltip.SetItemByID)=="function" then ok=pcall(GameTooltip.SetItemByID,GameTooltip,id)
    else ok=pcall(GameTooltip.SetHyperlink,GameTooltip,F.IsText(link) and link or ("item:"..id)) end
    if not ok then F.Safe(GameTooltip.Hide,GameTooltip); return end
    F.AppendPriceTooltip(GameTooltip,id); GameTooltip:Show()
end
function F.InstallPriceTooltips()
    if F.safeMode or F.priceTooltipsInstalled then return end
    local function itemID(tooltip,data)
        if not usableTooltip(tooltip) then return end
        if F.Public(data) and type(data)=="table" and F.ValidID(data.id) then return F.ValidID(data.id) end
        if type(tooltip.GetItem)=="function" then local ok,_,link=pcall(tooltip.GetItem,tooltip); if ok and F.IsText(link) then return F.ValidID(string.match(link,"item:(%d+)")) end end
    end
    if TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall)=="function" and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        local ok=pcall(TooltipDataProcessor.AddTooltipPostCall,Enum.TooltipDataType.Item,function(tooltip,data)
            if usableTooltip(tooltip) then tooltipPrices[tooltip]=nil end
            F.AppendPriceTooltip(tooltip,itemID(tooltip,data))
        end)
        if ok then F.priceTooltipsInstalled=true; return end
    end
    for _,tooltip in pairs({GameTooltip,ItemRefTooltip}) do
        if usableTooltip(tooltip) and type(tooltip.HookScript)=="function" then
            local ok=pcall(tooltip.HookScript,tooltip,"OnTooltipSetItem",function(self)
                tooltipPrices[self]=nil
                F.AppendPriceTooltip(self,itemID(self))
            end)
            if ok then F.priceTooltipsInstalled=true end
        end
    end
end
