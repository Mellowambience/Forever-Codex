local _, F = ...
F.schema=3
local function count(v) return F.IsNumber(v) and math.max(0,math.min(1000000000,math.floor(v))) or 0 end
local function str(v,limit)
    if not F.IsText(v) then return end
    limit=limit or 300
    local nextByte=string.byte(v,limit+1)
    if nextByte and nextByte>=128 and nextByte<192 then
        while limit>0 do local b=string.byte(v,limit); if not b or b<128 or b>=192 then limit=limit-1; break end; limit=limit-1 end
    end
    return string.sub(v,1,limit)
end
local function id(v) if F.IsText(v) or F.IsNumber(v) then local n=tonumber(v); if n and n>0 and n==math.floor(n) and n<1000000000 then return n end end end
F.ValidID=id
local function timestamp(value)
    if F.IsNumber(value) and value>=0 and value<=4102444800 then return math.floor(value) end
end
function F.CopyData(value,depth,seen)
    depth=depth or 0; seen=seen or {}
    if depth>12 or not F.Public(value) then return end
    local t=type(value)
    if t=="string" or t=="boolean" then return value end
    if t=="number" then if F.IsNumber(value) then return value end; return end
    if t~="table" or seen[value] then return end
    seen[value]=true; local copy={}
    for k,v in pairs(value) do
        if F.Public(k) and (type(k)=="string" or type(k)=="number") then local c=F.CopyData(v,depth+1,seen); if c~=nil then copy[k]=c end end
    end
    seen[value]=nil; return copy
end
function F.NormalizeRecord(npc,r)
    r=type(r)=="table" and r or {}
    local out={id=npc,name=str(r.name) or ("Creature "..npc),kills=count(r.kills),notes=str(r.notes,2000) or "",favorite=r.favorite==true,zones={},variants={},abilities={},loot={},professions={},characters={},locations={},history={},appearances={}}
    for _,k in ipairs({"kind","zone","classification","observedBuild"}) do out[k]=str(r[k]) end
    out.fieldStatus={}; for field,state in pairs(type(r.fieldStatus)=="table" and r.fieldStatus or {}) do if str(field) and (state=="restricted" or state=="unavailable") then out.fieldStatus[field]=state end end
    out.statBuild={}; for field,build in pairs(type(r.statBuild)=="table" and r.statBuild or {}) do if str(field) and str(build) then out.statBuild[field]=build end end
    for _,k in ipairs({"level","health","attackSpeed","armor"}) do if F.IsNumber(r[k]) then out[k]=r[k] end end
    if F.IsNumber(r.damageMin) and F.IsNumber(r.damageMax) and r.damageMin>0 and r.damageMax>=r.damageMin then
        out.damageMin,out.damageMax=r.damageMin,r.damageMax
    end
    out.first,out.last=timestamp(r.first),timestamp(r.last)
    for _,k in ipairs({"zones","characters"}) do
        for key,v in pairs(type(r[k])=="table" and r[k] or {}) do if str(key) then if k=="zones" then if v==true then out[k][key]=true end else out[k][key]=count(v) end end end
    end
    if out.zone then out.zones[out.zone]=true end
    for key,v in pairs(type(r.variants)=="table" and r.variants or {}) do
        if str(key) and type(v)=="table" and F.IsNumber(v.level) then
            local item={level=v.level,classification=str(v.classification)}
            for _,field in ipairs({"healthMin","healthMax"}) do if F.IsNumber(v[field]) and v[field]>0 then item[field]=v[field] end end
            out.variants[key]=item
        end
    end
    for key,a in pairs(type(r.abilities)=="table" and r.abilities or {}) do local spell=id(key); if spell and type(a)=="table" then out.abilities[spell]={id=spell,name=str(a.name) or ("Spell "..spell),count=count(a.count),last=F.IsNumber(a.last) and a.last or nil} end end
    for _,l in pairs(type(r.loot)=="table" and r.loot or {}) do
        if type(l)=="table" then
            local link=str(l.link,1000); local item=id(l.itemID) or (link and id(string.match(link,"item:(%d+)")))
            if item then
                local key=tostring(item); local old=out.loot[key]
                if not old or count(l.count)>old.count then
                    local methods={}; for method,n in pairs(type(l.methods)=="table" and l.methods or {}) do if str(method) then methods[method]=count(n) end end
                    if next(methods)==nil and count(l.count)>0 then methods["Legacy / unspecified"]=count(l.count) end
                    out.loot[key]={itemID=item,link=link or ("item:"..item),count=count(l.count),acquired=count(l.acquired),methods=methods}
                end
            end
        end
    end
    for name,p in pairs(type(r.professions)=="table" and r.professions or {}) do
        if str(name) and type(p)=="table" then
            local cleaned={manual=p.manual==true,observed=p.observed==true,materials={}}
            for item,link in pairs(type(p.materials)=="table" and p.materials or {}) do if id(item) and str(link,1000) then cleaned.materials[tostring(id(item))]=link end end
            out.professions[name]=cleaned
        end
    end
    if str(r.profession) then out.professions[r.profession]={manual=true,materials={}} end
    if type(r.locations)=="table" then
        for key,p in pairs(r.locations) do
            if str(key) and type(p)=="table" and id(p.mapID) and F.IsNumber(p.x) and F.IsNumber(p.y) and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1 then
                out.locations[key]={mapID=id(p.mapID),x=p.x,y=p.y,zone=str(p.zone),instance=str(p.instance),build=str(p.build)}
            end
        end
    end
    if type(r.history)=="table" then
        for _,h in ipairs(r.history) do
            if #out.history>=30 then break end
            local stamp=type(h)=="table" and timestamp(h.time)
            if stamp then out.history[#out.history+1]={time=stamp,zone=str(h.zone),level=F.IsNumber(h.level) and h.level or nil} end
        end
    end
    local appearanceCount=0
    for display,a in pairs(type(r.appearances)=="table" and r.appearances or {}) do
        if appearanceCount<16 and id(display) and type(a)=="table" then out.appearances[id(display)]={displayID=id(display),seen=F.IsNumber(a.seen) and a.seen or nil,source="Live target preview"}; appearanceCount=appearanceCount+1 end
    end
    return out
end
function F.LoadStorage()
    F.readOnly=nil
    local raw=type(ForeverBestiaryDB)=="table" and ForeverBestiaryDB or {}
    local source=raw; local recovered=false
    if raw.creatures~=nil and type(raw.creatures)~="table" and type(ForeverBestiaryBackup)=="table" and type(ForeverBestiaryBackup.data)=="table" and type(ForeverBestiaryBackup.data.creatures)=="table" then source=ForeverBestiaryBackup.data; recovered=true end
    if F.IsNumber(raw.version) and raw.version>F.schema then F.readOnly=true end
    if not F.readOnly and type(source.creatures)=="table" and (source.version~=F.schema or recovered) and not recovered then
        ForeverBestiaryBackup={created=time(),reason="Before schema "..F.schema.." migration",data=F.CopyData(raw)}
    end
    local db={version=F.schema,creatures={},settings={},trackedItems={},trackedRecipes={},recipes={},acquired={},sourceLedger={}}
    local removed=0
    for key,r in pairs(type(source.creatures)=="table" and source.creatures or {}) do local npc=id(key); if npc and type(r)=="table" then db.creatures[npc]=F.NormalizeRecord(npc,r) else removed=removed+1 end end
    local s=type(source.settings)=="table" and source.settings or {}
    db.settings.theme=F.NormalizeCodexTheme(s.theme)
    db.settings.ahCut=s.ahCut==15 and 15 or 5; db.settings.notify=s.notify~=false; db.settings.group=s.group~=false; db.settings.hideMinimap=s.hideMinimap==true
    db.settings.angle=F.IsNumber(s.angle) and s.angle%360 or 220; db.settings.selected=id(s.selected)
    if type(s.position)=="table" and F.IsNumber(s.position.x) and F.IsNumber(s.position.y) then
        db.settings.position={x=s.position.x,y=s.position.y}
        if F.IsNumber(s.position.scale) and s.position.scale>0 then
            db.settings.position.scale=math.min(1,s.position.scale)
        end
    end
    local seller=type(s.seller)=="table" and s.seller or {}
    db.settings.seller={duration=seller.duration==1 and 1 or seller.duration==3 and 3 or 2,undercut=seller.undercut==true,stack=math.min(1000,math.max(1,count(seller.stack)>0 and count(seller.stack) or 1000)),minUnit=math.min(1000000000,math.max(1,count(seller.minUnit))),maxDeposit=math.min(100000000,math.max(0,seller.maxDeposit==nil and 10000 or count(seller.maxDeposit))),protectRecipes=seller.protectRecipes~=false,autoOpen=seller.autoOpen~=false,keep={}}
    local kept=0
    for item,v in pairs(type(seller.keep)=="table" and seller.keep or {}) do if id(item) and v==true and kept<1000 then db.settings.seller.keep[id(item)]=true; kept=kept+1 end end
    db.settings.modelViews={}
    db.settings.trackedCreatures={}; for npc,v in pairs(type(s.trackedCreatures)=="table" and s.trackedCreatures or {}) do if id(npc) and v==true then db.settings.trackedCreatures[id(npc)]=true end end
    for npc,v in pairs(type(s.modelViews)=="table" and s.modelViews or {}) do
        if id(npc) and type(v)=="table" and F.IsNumber(v.distance) then db.settings.modelViews[id(npc)]={distance=math.max(.15,math.min(18,v.distance)),pan=F.IsNumber(v.pan) and math.max(-20,math.min(20,v.pan)) or 0,ratio=F.IsNumber(v.ratio) and math.max(.02,math.min(30,v.ratio)) or nil} end
    end
    for _,key in ipairs({"trackedItems","trackedRecipes","acquired"}) do for item,n in pairs(type(source[key])=="table" and source[key] or {}) do if id(item) then db[key][id(item)]=count(n) end end end
    for spell,r in pairs(type(source.recipes)=="table" and source.recipes or {}) do
        spell=id(spell)
        if spell and type(r)=="table" and str(r.name) then
            local recipe={id=spell,name=str(r.name),profession=str(r.profession),output=id(r.output),partial=r.partial==true,checked=F.IsNumber(r.checked) and r.checked or nil,reagents={},learnedBy={},requirements={}}
            recipe.minimumYield=id(r.minimumYield)
            for item,n in pairs(type(r.reagents)=="table" and r.reagents or {}) do if id(item) and count(n)>0 then recipe.reagents[id(item)]=count(n) end end
            for character,learned in pairs(type(r.learnedBy)=="table" and r.learnedBy or {}) do if str(character) and learned==true then recipe.learnedBy[character]=true end end
            for _,requirement in ipairs(type(r.requirements)=="table" and r.requirements or {}) do if str(requirement) then recipe.requirements[#recipe.requirements+1]=requirement end end
            db.recipes[spell]=recipe
        end
    end
    local ledger={}
    for key,l in pairs(type(source.sourceLedger)=="table" and source.sourceLedger or {}) do
        if str(key,150) and type(l)=="table" and F.IsNumber(l.time) and time()-l.time<86400 then ledger[#ledger+1]={key=key,quantity=count(l.quantity),confirmed=count(l.confirmed),time=l.time} end
    end
    table.sort(ledger,function(a,b) return a.time>b.time end)
    for i=1,math.min(2048,#ledger) do local l=ledger[i]; db.sourceLedger[l.key]={quantity=l.quantity,confirmed=l.confirmed,time=l.time} end
    F.ledgerSize=math.min(2048,#ledger)
    F.db=db
    F.lootContext=nil
    if not F.readOnly then ForeverBestiaryDB=db end
    if F.readOnly then F.Message("Newer saved data found. Recording is disabled until you update this addon.")
    elseif recovered then F.Message("Recovered the journal from its pre-upgrade backup.")
    elseif removed>0 then F.Message("Skipped "..removed.." malformed entries. Valid discoveries were kept.") end
    F.character=(F.Safe(UnitName,"player") or "Unknown").."-"..(F.Safe(GetRealmName) or "Unknown")
    F.RefreshCodexTheme()
end
function F.RestoreBackup()
    if F.readOnly then F.Message("Update the addon before restoring a backup over newer saved data."); return end
    if type(ForeverBestiaryBackup)~="table" or type(ForeverBestiaryBackup.data)~="table" then F.Message("No migration backup is available."); return end
    ForeverBestiaryDB=F.CopyData(ForeverBestiaryBackup.data); F.readOnly=nil; F.LoadStorage(); F.selected=nil; F.Refresh(); F.Message("Migration backup restored. Reload to write it to disk.")
end
function F.ClearCollection()
    if F.readOnly then return end
    ForeverBestiaryBackup={created=time(),reason="Before manual collection clear",data=F.CopyData(F.db)}
    F.db.creatures={}; F.db.settings.selected=nil; F.db.settings.trackedCreatures={}; F.selected=nil; F.lootContext=nil
    F.Refresh(); F.Message("Discoveries cleared. A backup is available with /fbc restore.")
end
