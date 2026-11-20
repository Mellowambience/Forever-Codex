local _, F = ...
local pools={}
local function text(parent,value,x,y,width,font)
    local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall"); t:SetPoint("TOPLEFT",x,y); t:SetWidth(width); t:SetJustifyH("LEFT"); t:SetText(value); return t
end
local function button(parent,title,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(width,24); b:SetPoint("TOPLEFT",x,y); b:SetText(title); b:SetScript("OnClick",fn); return b
end
function F.HideDetailPanels() for _,p in pairs(pools) do p:Hide() end end
function F.RenderLoot(parent,r)
    local p=pools.loot
    if not p then
        p=CreateFrame("Frame",nil,parent); p:SetPoint("TOPLEFT"); p:SetWidth(565); p.rows={}; pools.loot=p
        p.heading=text(p,"",0,0,560,"GameFontNormalSmall")
        p.query=CreateFrame("EditBox",nil,p,"InputBoxTemplate"); p.query:SetSize(190,24); p.query:SetPoint("TOPLEFT",6,-50); p.query:SetAutoFocus(false); p.query:SetMaxLetters(100); p.query:SetScript("OnTextChanged",function() F.Refresh() end); p.query:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        p.quality=F.Dropdown(p,"All rarities",205,-50,135,function() return {"All rarities","Uncommon+","Rare+"} end,function() F.Refresh() end)
        p.kind=F.Dropdown(p,"All items",347,-50,150,function() return {"All items","Materials","Equipment","Quest"} end,function() F.Refresh() end)
    end
    if not p.cut then p.cut=F.Dropdown(p,"AH cut: "..(F.db.settings.ahCut or 5).."%",0,-80,160,function() return {"AH cut: 5%","AH cut: 15%"} end,function(choice) F.db.settings.ahCut=choice=="AH cut: 15%" and 15 or 5; F.Refresh() end) end
    if not p.seller then p.seller=button(p,"Auction seller",175,-80,145,function() F.OpenSeller() end) end
    p:Show(); local ref=F.Reference(r.id)
    p.heading:SetText(ref and "Partial reference reports + your observations. No verified drop chances.\nSource: "..ref.source.." | checked "..ref.checked or "No reference coverage for this creature yet. Your observations appear below.\nSeen is not the same as personally acquired; no drop chance is inferred.")
    local entries=F.LootRows(r,p.query:GetText(),p.quality.value,p.kind.value)
    for _,row in ipairs(p.rows) do row:Hide() end
    local y=0
    for i,entry in ipairs(entries) do
        local row=p.rows[i]
        if not row then
            row=CreateFrame("Button",nil,p); row:SetWidth(560)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(30,30); row.icon:SetPoint("TOPLEFT",0,-2)
            row.title=text(row,"",38,0,400,"GameFontNormalSmall"); row.info=text(row,"",38,-18,410)
            row.keep=button(row,"Keep",470,-25,85,function() F.KeepItem(row.entry.itemID) end)
            row.price=text(row,"",38,-65,515)
            row.track=button(row,"Track",470,0,85,function() local item=row.entry.itemID; F.TrackItem(item,F.db.trackedItems[item] and 0 or 1) end)
            row:SetScript("OnEnter",function(self) F.ShowItemTooltip(self,self.entry.itemID,self.entry.info.link) end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end)
            row:SetScript("OnClick",function(self) if SetItemRef then SetItemRef("item:"..self.entry.itemID,self.entry.info.link,"LeftButton") end end)
            p.rows[i]=row
        end
        row.entry=entry; row:Show(); row.icon:SetTexture(entry.info.icon); row.title:SetText(entry.info.name..(entry.info.level and (" | ilvl "..entry.info.level) or ""))
        row.info:SetText("Seen: "..(entry.seen or 0).." | confirmed here: "..(entry.acquired or 0)..(entry.reference and " | prior report" or "").." | Bags: "..(F.InventoryCount(entry.itemID) or "unknown").." | " ..(entry.methods and table.concat(F.Keys(entry.methods),", ") or entry.method or "Method unknown"))
        row.keep:SetText(F.db.settings.seller.keep[entry.itemID] and "Unkeep" or "Keep")
        local quote,age=F.PriceQuote(entry.itemID)
        local suggested=F.PriceRecommendation(entry.itemID,entry.info)
        local price="Vendor "..F.Money(entry.info.sellPrice)
        if quote then
            price=price.."  |  AH "..F.Money(quote).." ("..F.PriceAge(age)..")"
            if suggested then price=price.."  |  List "..F.Money(suggested) end
        elseif entry.info.bindType~=1 and entry.info.bindType~=4 then
            price=price.."  |  AH quote unavailable"
        end
        row.price:SetText(price)
        row.track:SetText(F.db.trackedItems[entry.itemID] and "Untrack" or "Track")
        local titleHeight=math.max(14,row.title:GetStringHeight())
        row.info:ClearAllPoints(); row.info:SetPoint("TOPLEFT",38,-titleHeight-2)
        local priceTop=titleHeight+row.info:GetStringHeight()+5
        row.price:ClearAllPoints(); row.price:SetPoint("TOPLEFT",38,-priceTop)
        local height=math.max(49,priceTop+row.price:GetStringHeight()+3)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-108-y); row:SetHeight(height); y=y+height+5
    end
    if not p.empty then p.empty=text(p,"",0,-115,550) end
    p.empty:SetText(#entries==0 and "No matching loot records. Try changing the item filters or keep exploring." or "")
    local height=math.max(132,108+y); p:SetHeight(height); parent:SetHeight(height+20)
end
function F.RenderCrafting(parent,r)
    local p=pools.crafting
    if not p then
        p=CreateFrame("Frame",nil,parent); p:SetPoint("TOPLEFT"); p:SetWidth(565); p.rows={}; pools.crafting=p
        text(p,"Known recipes that use this creature's recorded materials, plus your pinned recipes.\nOpen a profession and choose Update recipes. Counts below cover current bags only.",0,0,550)
        button(p,"Update recipes",0,-45,150,function() F.ScanRecipes() end)
    end
    p:Show(); for _,row in ipairs(p.rows) do row:Hide() end
    local recipes=F.RelatedRecipes(r); local y=85
    for i,recipe in ipairs(recipes) do
        local row=p.rows[i]
        if not row then
            row=CreateFrame("Button",nil,p); row:SetWidth(560); row.title=text(row,"",0,0,440,"GameFontNormalSmall"); row.info=text(row,"",0,-20,440)
            row.track=button(row,"Track",470,0,85,function() local item=row.recipe; F.TrackRecipe(item.id,F.db.trackedRecipes[item.id] and 0 or 1) end)
            row:SetScript("OnClick",function(self)
                if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then pcall(C_TradeSkillUI.OpenRecipe,self.recipe.id)
                elseif SetItemRef then SetItemRef("spell:"..self.recipe.id,"|Hspell:"..self.recipe.id.."|h["..self.recipe.name.."]|h","LeftButton") end
            end)
            p.rows[i]=row
        end
        row.recipe=recipe; row:Show(); row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y)
        row.title:SetText(recipe.name..(recipe.profession and (" | "..recipe.profession) or ""))
        local lines={}; local crafts=F.db.trackedRecipes[recipe.id] or 1
        for _,item in ipairs(F.Keys(recipe.reagents)) do local info=F.ItemInfo(item); local have=F.InventoryCount(item); local need=recipe.reagents[item]*crafts; lines[#lines+1]=info.name..": "..(have or "?").." / "..need.." in bags"..(have and (" | still need "..math.max(0,need-have)) or "") end
        for _,requirement in ipairs(recipe.requirements or {}) do lines[#lines+1]="Requirement: "..requirement end
        if recipe.partial then lines[#lines+1]="Some alternative/currency requirements are not tracked." end
        row.info:SetText(table.concat(lines,"\n")); row.track:SetText(F.db.trackedRecipes[recipe.id] and "Untrack" or "Track")
        row.info:ClearAllPoints(); row.info:SetPoint("TOPLEFT",0,-row.title:GetStringHeight()-6)
        local h=math.max(55,row.title:GetStringHeight()+row.info:GetStringHeight()+22); row:SetHeight(h); y=y+h+12
    end
    if not p.empty then p.empty=text(p,"",0,-115,550) end
    p.empty:SetText(#recipes==0 and "No related recipes have been recorded for this character. Open each profession once and update its recipes." or "")
    p:SetHeight(math.max(170,y)); parent:SetHeight(math.max(190,y+20))
end
function F.RenderNotes(parent,r)
    local p=pools.notes
    if not p then
        p=CreateFrame("Frame",nil,parent); p:SetPoint("TOPLEFT"); p:SetWidth(565); pools.notes=p
        p.prompt=text(p,"",0,0,550,"GameFontNormalSmall")
        text(p,"These are prompts for your own observations, not claims about the creature.\nYour notes save in the field below. Related entries share a type or habitat.",0,-42,550)
        p.related=F.Dropdown(p,"Related discoveries",0,-92,330,function()
            p.relatedIDs={}; local current=F.db.creatures[F.selected]; local options={"Related discoveries"}
            for _,other in ipairs(F.RelatedCreatures(current)) do local name=other.name.." (#"..other.id..")"; options[#options+1]=name; p.relatedIDs[name]=other.id end
            return options
        end,function(choice) local id=p.relatedIDs[choice]; if id then F.selected=id; F.db.settings.selected=id; p.related:SetChoice("Related discoveries"); F.Render() end end)
    end
    p.prompt:SetText("Field note prompt\n"..F.FieldPrompt(r)); p:Show(); p:SetHeight(150); parent:SetHeight(170)
end
