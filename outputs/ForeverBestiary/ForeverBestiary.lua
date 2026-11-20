local _, F = ...
F.version = "0.3.20"
F.observed, F.seenKills, F.seenLoot, F.seenCasts = {}, {}, {}, {}
F.cacheKeys = setmetatable({}, {__mode = "k"})
function F.Public(v) return not issecretvalue or not issecretvalue(v) end
function F.Safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and F.Public(value) then return value end
end
local function number(v) return F.Public(v) and type(v)=="number" and v==v and v~=math.huge and v~=-math.huge end
local function text(v) return F.Public(v) and type(v)=="string" end
F.IsNumber, F.IsText = number, text
function F.NPC(guid)
    if not text(guid) then return end
    local kind, _, _, _, _, id = strsplit("-",guid)
    if kind=="Creature" or kind=="Vehicle" then return F.ValidID(id) end
end
function F.Message(s)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd7b56dForever Codex:|r "..s)
    end
end
function F.Tier(n) return n>=30 and "Mastered" or n>=15 and "Researched" or n>=5 and "Studied" or "Discovered" end
function F.Remember(cache,key,value)
    if cache[key]==nil then
        local ring=F.cacheKeys[cache]
        if not ring then
            ring={next=1}
            F.cacheKeys[cache]=ring
        end
        local old=ring[ring.next]
        if old~=nil then cache[old]=nil end
        ring[ring.next]=key
        ring.next=ring.next%2048+1
    end
    cache[key]=value
end
function F.Init()
    F.LoadStorage()
end
local statKeys={"health","attackSpeed","armor","damageMin","damageMax"}
local function merge(r,s)
    r.statBuild=r.statBuild or {}
    if (s.level and r.level~=s.level) or (s.classification and r.classification~=s.classification) then
        for _,key in ipairs(statKeys) do
            r[key]=nil
            r.statBuild[key]=nil
        end
    end
    for _,k in ipairs({"name","kind","level","health","zone","classification","attackSpeed","armor","damageMin","damageMax"}) do if s[k]~=nil then r[k]=s[k] end end
    for _,key in ipairs({"health","attackSpeed","armor","damageMin","damageMax"}) do if s[key]~=nil and s.build then r.statBuild[key]=s.build end end
    if s.zone then r.zones[s.zone]=true end
    if s.level then
        local key=tostring(s.level)..":"..(s.classification or "normal")
        local v=r.variants[key] or {level=s.level,classification=s.classification}
        if s.health then v.healthMin=math.min(v.healthMin or s.health,s.health); v.healthMax=math.max(v.healthMax or s.health,s.health) end
        r.variants[key]=v
    end
    if s.build then r.observedBuild=s.build end
    if s.fieldStatus then r.fieldStatus=s.fieldStatus end
    -- Transfer pre-discovery observations once. Subsequent casts go straight to the record.
    for id, pending in pairs(s.abilities or {}) do
        local recorded = r.abilities[id]
        if recorded then
            recorded.count = math.min(1000000000, recorded.count + pending.count)
            recorded.last = math.max(recorded.last or 0, pending.last or 0)
        else
            r.abilities[id] = pending
        end
        s.abilities[id] = nil
    end
end
function F.Snapshot(unit,minimumInterval)
    if not text(unit) then return end
    local guid=F.Safe(UnitGUID,unit); local id=F.NPC(guid)
    if not id then return end
    local s=F.observed[guid] or {id=id,abilities={}}
    if minimumInterval and s.seenAt and GetTime()-s.seenAt<minimumInterval then return s,guid end
    local previousLevel,previousClass=s.level,s.classification
    for k,fn in pairs({name=UnitName,kind=UnitCreatureType,classification=UnitClassification}) do
        local v=F.Safe(fn,unit); if text(v) and v~="" then s[k]=v end
    end
    local zone=F.Safe(GetRealZoneText); if text(zone) then s.zone=zone end
    local level=F.Safe(UnitLevel,unit); if number(level) then s.level=level end
    if previousLevel~=s.level or previousClass~=s.classification then
        for _,key in ipairs(statKeys) do s[key]=nil end
    end
    s.fieldStatus={}
    -- Read each API once. Zero from unsupported enemy-stat calls is ambiguous.
    for key,fn in pairs({health=UnitHealthMax,attackSpeed=UnitAttackSpeed,armor=UnitArmor}) do
        local ok,value=false,nil
        if type(fn)=="function" then ok,value=pcall(fn,unit) end
        if ok and number(value) and value>0 then
            s[key]=value
        else
            s.fieldStatus[key]=ok and not F.Public(value) and "restricted" or "unavailable"
        end
    end
    if type(UnitDamage)=="function" then
        local ok,lo,hi=pcall(UnitDamage,unit)
        if ok and number(lo) and number(hi) and lo>0 and hi>=lo then s.damageMin=lo; s.damageMax=hi end
    end
    if F.EnrichSnapshot then F.EnrichSnapshot(s) end
    F.Remember(F.observed,guid,s)
    local r=F.db and F.db.creatures[id]; if r then merge(r,s) end
    return s,guid
end
function F.Kill(attacker,guid)
    local id=F.NPC(guid)
    if not F.db or F.readOnly or not id or F.seenKills[guid] then return end
    if not F.db.settings.group then
        if not text(attacker) then return end
        if attacker~=F.Safe(UnitGUID,"player") and attacker~=F.Safe(UnitGUID,"pet") then return end
    end
    F.Remember(F.seenKills,guid,true)
    local firstDiscovery=not F.db.creatures[id]
    local r=F.db.creatures[id] or F.NormalizeRecord(id,{})
    if F.observed[guid] then merge(r,F.observed[guid]) end
    r.kills=r.kills+1; r.first=r.first or time(); r.last=time()
    r.characters[F.character]=(r.characters[F.character] or 0)+1
    F.db.creatures[id]=r; F.selected=F.selected or id
    if F.RecordEncounter then F.RecordEncounter(r,F.observed[guid]) end
    if F.RecordTaleEncounter then
        F.SupportCall("Tale encounter",F.RecordTaleEncounter,r,attacker,firstDiscovery)
    end
    if F.db.settings.notify and (r.kills==1 or r.kills==5 or r.kills==15 or r.kills==30) then F.Message(F.Tier(r.kills)..": "..r.name.." ("..r.kills.." kills)") end
    F.Refresh()
end
local function isSkinning(spellID)
    if spellID==8613 then return true end
    local name=F.Safe(C_Spell and C_Spell.GetSpellName,spellID)
    local base=F.Safe(C_Spell and C_Spell.GetSpellName,8613)
    return text(name) and text(base) and name==base
end
function F.CastStart(unit,spellID)
    if F.IsText(unit) and unit=="player" and number(spellID) and isSkinning(spellID) then
        local _,guid=F.Snapshot("target")
        F.pendingHarvest=guid and {guid=guid,expires=GetTime()+30} or nil
    end
end
function F.Spell(unit,castGUID,spellID)
    spellID=F.ValidID(spellID)
    if not F.db or F.readOnly or not text(unit) or not spellID then return end
    if unit=="player" then
        if isSkinning(spellID) then
            local pending=F.pendingHarvest
            if pending and pending.expires>=GetTime() then F.harvest={guid=pending.guid,expires=GetTime()+12,profession="Skinning"} end
            F.pendingHarvest=nil
        end
        return
    end
    if text(castGUID) and F.seenCasts[castGUID] then return end
    local s=F.Snapshot(unit,.35); if not s then return end
    if text(castGUID) then F.Remember(F.seenCasts,castGUID,true) end
    local name=F.Safe(C_Spell and C_Spell.GetSpellName,spellID) or ("Spell "..spellID)
    if not text(name) then return end
    local r=F.db.creatures[s.id]
    local abilities=r and r.abilities or s.abilities
    local ability=abilities[spellID] or {id=spellID,name=name,count=0}
    ability.count=math.min(1000000000,ability.count+1)
    ability.last=time()
    abilities[spellID]=ability
    if r then F.Refresh() end
end
function F.Loot()
    if F.readOnly then return end
    if type(GetLootSourceInfo)~="function" then return end
    local n=F.Safe(GetNumLootItems); if not number(n) then return end
    local totals={}
    for slot=1,n do
        local link=F.Safe(GetLootSlotLink,slot)
        if text(link) then
            local itemID=tonumber(string.match(link,"item:(%d+)"))
            if itemID then
                local sources={pcall(GetLootSourceInfo,slot)}; local ok=table.remove(sources,1)
                if ok then
                    for i=1,#sources,2 do
                        local guid,quantity=sources[i],sources[i+1]; local id=F.NPC(guid)
                        local r=id and F.db.creatures[id]
                        if r and number(quantity) and quantity>0 then
                            local harvest=F.harvest and F.harvest.expires>=GetTime() and F.harvest.guid==guid and F.harvest.profession
                            local phase=harvest or "Loot"
                            local key=guid..":"..phase..":"..itemID
                            local t=totals[key] or {record=r,itemID=itemID,link=link,quantity=0,harvest=harvest}
                            t.quantity=t.quantity+quantity; totals[key]=t
                        end
                    end
                end
            end
        end
    end
    F.lootContext={}
    for key,t in pairs(totals) do
        -- Aggregate identical items across slots before deduplication.
        local persistent=F.db.sourceLedger and F.db.sourceLedger[key]
        local previous=math.max(F.seenLoot[key] or 0,persistent and persistent.quantity or 0)
        if t.quantity>previous then
            F.Remember(F.seenLoot,key,t.quantity)
            local r=t.record; local k=tostring(t.itemID); local l=r.loot[k] or {itemID=t.itemID,link=t.link,count=0}
            l.methods=l.methods or {}; local method=t.harvest or "Creature loot"; l.methods[method]=(l.methods[method] or 0)+t.quantity-previous
            l.count=l.count+t.quantity-previous; l.link=t.link; r.loot[k]=l
            if t.harvest then
                local p=r.professions[t.harvest] or {observed=true,materials={}}
                p.observed=true; p.materials=p.materials or {}; p.materials[k]=t.link; r.professions[t.harvest]=p
            end
        end
        if F.RememberSource then F.RememberSource(key,t.quantity) end
        local c=F.lootContext[t.itemID]
        if not c then F.lootContext[t.itemID]={onlyRecord=t.record,ledgerKey=key,remaining=math.max(0,t.quantity-(persistent and persistent.confirmed or 0)),expires=GetTime()+5}
        else c.onlyRecord=nil end
    end
    F.Refresh()
end
function F.Refresh()
    if not F.Render or not F.window or not F.window:IsShown() then return end
    if C_Timer and C_Timer.After then
        if F.refreshPending then return end
        F.refreshPending=true
        C_Timer.After(.08,function()
            F.refreshPending=nil
            if not F.window or not F.window:IsShown() then return end
            if F.SupportCall then F.SupportCall("journal refresh",F.Render)
            else F.Render() end
        end)
    else
        F.Render()
    end
end
