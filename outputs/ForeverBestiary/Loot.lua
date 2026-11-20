local _, F = ...
function F.RememberSource(key,quantity)
    local ledger=F.db.sourceLedger; local old=ledger[key]
    if not old then
        F.ledgerSize=(F.ledgerSize or 0)+1
        if F.ledgerSize>2048 then
            local oldest,stamp
            for k,v in pairs(ledger) do if not stamp or v.time<stamp then oldest,stamp=k,v.time end end
            if oldest then ledger[oldest]=nil; F.ledgerSize=F.ledgerSize-1 end
        end
    end
    ledger[key]={quantity=math.max(quantity,old and old.quantity or 0),confirmed=old and old.confirmed or 0,time=time()}
end
function F.ItemInfo(itemID)
    itemID=F.ValidID(itemID)
    local data={itemID=itemID,name=itemID and ("Item "..itemID) or "Unknown item",link=itemID and ("item:"..itemID),icon="Interface\\Icons\\INV_Misc_QuestionMark"}
    if not itemID then return data end
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(fn)=="function" then
        local ok,name,link,quality,level,required,kind,subclass,_,equip,icon,sellPrice,classID,subclassID,bindType=pcall(fn,itemID)
        if ok then
            for key,v in pairs({name=name,link=link,kind=kind,subclass=subclass,equip=equip}) do if F.IsText(v) then data[key]=v end end
            for key,v in pairs({quality=quality,level=level,required=required,icon=icon,classID=classID,subclassID=subclassID,sellPrice=sellPrice,bindType=bindType}) do if F.IsNumber(v) then data[key]=v end end
        end
    end
    return data
end
function F.InventoryCount(itemID)
    local n=F.Safe(C_Item and C_Item.GetItemCount or GetItemCount,itemID,false,false,false)
    return F.IsNumber(n) and math.max(0,n) or nil
end
function F.ItemSources(itemID)
    local sources={}
    for _,r in pairs(F.db.creatures) do
        local l=r.loot[tostring(itemID)]; local ref=F.Reference and F.Reference(r.id); local reported=false
        if ref then for _,drop in ipairs(ref.loot) do if drop.itemID==itemID then reported=true end end end
        if l or reported then sources[#sources+1]={record=r,seen=l and l.count or 0,reference=reported} end
    end
    table.sort(sources,function(a,b) return a.record.name<b.record.name end); return sources
end
function F.LootRows(r,query,quality,kind)
    local combined={}
    local ref=F.Reference and F.Reference(r.id)
    if ref then for _,drop in ipairs(ref.loot or {}) do combined[drop.itemID]={itemID=drop.itemID,reference=true,referenceName=drop.name,method=drop.method} end end
    for _,l in pairs(r.loot) do local row=combined[l.itemID] or {itemID=l.itemID}; row.seen=l.count; row.acquired=l.acquired or 0; row.methods=l.methods; combined[l.itemID]=row end
    local list={}; query=string.lower(query or "")
    for _,row in pairs(combined) do
        local info=F.ItemInfo(row.itemID); row.info=info
        if info.name=="Item "..row.itemID and row.referenceName then info.name=row.referenceName end
        local category=info.kind or "Unknown"
        local categoryOK=not kind or kind=="All items" or (kind=="Materials" and (info.classID==7 or info.classID==5 or category=="Trade Goods" or category=="Tradeskill" or category=="Reagent")) or (kind=="Equipment" and (info.classID==2 or info.classID==4 or category=="Armor" or category=="Weapon")) or (kind=="Quest" and (info.classID==12 or category=="Quest"))
        local qualityOK=not quality or quality=="All rarities" or (quality=="Uncommon+" and info.quality and info.quality>=2) or (quality=="Rare+" and info.quality and info.quality>=3)
        if categoryOK and qualityOK and string.find(string.lower(info.name.." "..row.itemID),query,1,true) then list[#list+1]=row end
    end
    table.sort(list,function(a,b) return a.info.name<b.info.name end); return list
end
function F.TrackItem(itemID,quantity)
    if F.readOnly or not F.db or not F.Public(quantity) then return end
    itemID=F.ValidID(itemID); quantity=tonumber(quantity)
    if not itemID then return end
    F.db.trackedItems[itemID]=F.IsNumber(quantity) and quantity>0 and math.min(10000,math.floor(quantity)) or nil; F.Refresh()
end
-- Only localized self-loot messages are counted as personal acquisition.
-- Pushed quest/crafting items are intentionally excluded from source attribution.
local function formatPattern(format)
    if not F.IsText(format) then return end
    local pattern="^"; local cursor=1; local fields={}
    while true do
        local first,last=string.find(format,"%%[%d%$]*[sd]",cursor)
        local literal=string.sub(format,cursor,first and first-1 or #format)
        pattern=pattern..string.gsub(literal,"([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")
        if not first then break end
        local token=string.sub(format,first,last); local char=string.sub(token,-1)
        fields[#fields+1]=char; pattern=pattern..(char=="d" and "(%d+)" or "(.-)"); cursor=last+1
    end
    return pattern.."$",fields
end
function F.PersonalLoot(message,lineID)
    if not F.IsText(message) or F.readOnly then return end
    if F.IsNumber(lineID) then F.seenLootMessages=F.seenLootMessages or {}; if F.seenLootMessages[lineID] then return end end
    for _,format in ipairs({LOOT_ITEM_SELF_MULTIPLE or "",LOOT_ITEM_SELF or ""}) do
        local pattern,fields=formatPattern(format)
        if pattern then
            local matches={string.match(message,pattern)}
            if #matches>0 then
                local itemID,link,quantity=nil,nil,1
                for i,kind in ipairs(fields) do
                    if kind=="s" then
                        link=matches[i]
                        itemID=F.ValidID(string.match(link,"item:(%d+)"))
                    elseif kind=="d" then quantity=tonumber(matches[i]) or 1 end
                end
                if itemID and F.IsNumber(quantity) and quantity>0 then
                    if F.IsNumber(lineID) then F.Remember(F.seenLootMessages,lineID,true) end
                    F.db.acquired[itemID]=(F.db.acquired[itemID] or 0)+quantity
                    local context=F.lootContext and F.lootContext[itemID]
                    if context and context.expires>=GetTime() and context.onlyRecord and context.remaining>=quantity then
                        local l=context.onlyRecord.loot[tostring(itemID)]
                        if l then
                            l.acquired=(l.acquired or 0)+quantity; context.remaining=context.remaining-quantity
                            local ledger=F.db.sourceLedger[context.ledgerKey]; if ledger then ledger.confirmed=(ledger.confirmed or 0)+quantity end
                        end
                    end
                    if F.RecordTaleLoot then F.SupportCall("Tale loot",F.RecordTaleLoot,itemID,link,quantity) end
                    F.Refresh(); return
                end
            end
        end
    end
end
