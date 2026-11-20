local _, F = ...
local function keys(t) local out={}; for k in pairs(t or {}) do out[#out+1]=k end; table.sort(out,function(a,b) return tostring(a)<tostring(b) end); return out end
F.Keys=keys
function F.RecordEncounter(r,s)
    r.observedBuild=s and s.build or r.observedBuild
    r.history=r.history or {}; table.insert(r.history,1,{time=time(),zone=r.zone,level=r.level}); if #r.history>30 then table.remove(r.history) end
    if s and s.location and GetTime()-(s.seenAt or 0)<30 then
        local p=s.location; local key=p.mapID..":"..math.floor(p.x*50)..":"..math.floor(p.y*50)
        r.locations=r.locations or {}; local n=0; for _ in pairs(r.locations) do n=n+1 end
        if n<30 or r.locations[key] then r.locations[key]=p end
    end
end
function F.EnrichSnapshot(s)
    local _,build=GetBuildInfo(); if F.IsText(build) then s.build=build end
    s.seenAt=GetTime()
    s.location=nil
    if C_Map then
        local map=F.Safe(C_Map.GetBestMapForUnit,"player")
        map=F.ValidID(map)
        local p=map and F.Safe(C_Map.GetPlayerMapPosition,map,"player")
        if (type(p)=="table" or type(p)=="userdata") and type(p.GetXY)=="function" then
            local ok,x,y=pcall(p.GetXY,p)
            if ok and F.IsNumber(x) and F.IsNumber(y) and x>=0 and x<=1 and y>=0 and y<=1 then
                s.location={mapID=map,x=x,y=y,zone=s.zone,build=s.build,instance=F.Safe(IsInInstance) and "instance" or "outdoor"}
            end
        end
    end
end
function F.OpenLocation(r)
    local first=keys(r.locations)[1]; local p=first and r.locations[first]
    if not p then F.Message("No encounter location has been recorded for this creature yet."); return end
    F.OpenEncounterPoint(p)
end
function F.OpenEncounterPoint(p)
    if InCombatLockdown() then F.Message("Open this location after combat."); return end
    if C_Map and UiMapPoint and C_Map.SetUserWaypoint and F.Safe(C_Map.CanSetUserWaypointOnMap,p.mapID) then
        local ok,point=pcall(UiMapPoint.CreateFromCoordinates,p.mapID,p.x,p.y)
        if ok then pcall(C_Map.SetUserWaypoint,point) end
    end
    if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:Show(); WorldMapFrame:SetMapID(p.mapID)
    elseif ToggleWorldMap then ToggleWorldMap(); if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(p.mapID) end
    else F.Message("Map viewer unavailable. Recorded map "..p.mapID..": "..string.format("%.1f, %.1f",p.x*100,p.y*100)) end
end
function F.TrackedCreatures()
    F.db.settings.trackedCreatures=F.db.settings.trackedCreatures or {}; return F.db.settings.trackedCreatures
end
function F.ToggleCreatureTracking(r)
    local tracked=F.TrackedCreatures(); tracked[r.id]=not tracked[r.id] or nil; F.Refresh()
end
function F.ZoneSummary()
    local zones={}
    for _,r in pairs(F.db.creatures) do
        for zone in pairs(r.zones) do local z=zones[zone] or {species=0,mastered=0,kills=0}; z.species=z.species+1; z.kills=z.kills+r.kills; if r.kills>=30 then z.mastered=z.mastered+1 end; zones[zone]=z end
    end
    return zones
end
function F.Rows(query,kind,status,options)
    options=options or {}; local rows={}; query=string.lower(query or "")
    for _,r in pairs(F.db.creatures) do
        local hay=r.name.." "..(r.kind or "").." "..table.concat(keys(r.zones)," ").." "..r.id
        for _,l in pairs(r.loot or {}) do hay=hay.." "..(l.link or "").." "..(l.itemID or "") end
        if F.Reference then local ref=F.Reference(r.id); if ref then for _,l in ipairs(ref.loot or {}) do hay=hay.." "..(l.name or "").." "..l.itemID end end end
        local min,max=tonumber(options.minLevel),tonumber(options.maxLevel)
        local levelOK=(not min or (r.level and r.level>=min)) and (not max or (r.level and r.level<=max))
        local zoneOK=not options.zone or options.zone=="All zones" or r.zones[options.zone]
        local professionOK=not options.profession or options.profession=="All professions" or r.professions[options.profession]
        if (not kind or kind=="All types" or kind==r.kind) and (not status or status=="All research" or status==F.Tier(r.kills) or (status=="Bookmarked" and r.favorite) or (status=="Tracked" and F.TrackedCreatures()[r.id])) and levelOK and zoneOK and professionOK and string.find(string.lower(hay),query,1,true) then rows[#rows+1]=r end
    end
    table.sort(rows,function(a,b)
        if options.sort=="Most kills" and a.kills~=b.kills then return a.kills>b.kills end
        if options.sort=="Recent" and (a.last or 0)~=(b.last or 0) then return (a.last or 0)>(b.last or 0) end
        if options.sort=="Level" and (a.level or 0)~=(b.level or 0) then return (a.level or 0)<(b.level or 0) end
        if a.name==b.name then return a.id<b.id end; return a.name<b.name
    end)
    return rows
end
function F.StatLabel(r,key)
    local v=r[key]; if v~=nil then return tostring(v).." (observed"..(r.statBuild and r.statBuild[key] and (", build "..r.statBuild[key]) or ", build unrecorded")..")" end
    local state=r.fieldStatus and r.fieldStatus[key]
    return state=="restricted" and "Restricted by the game" or "Not observed / unavailable"
end
function F.OverviewText(r)
    local text="|cffd7b56dObserved combat stats|r\nMaximum health: "..F.StatLabel(r,"health").."\nArmor (API base): "..F.StatLabel(r,"armor").."\nBase melee damage: "..(F.IsNumber(r.damageMin) and F.IsNumber(r.damageMax) and string.format("%.1f - %.1f (observed)",r.damageMin,r.damageMax) or "Not observed / unavailable").."\nAttack interval: "..(r.attackSpeed and string.format("%.2f seconds (observed)",r.attackSpeed) or "Not observed / unavailable").."\nResistances: Not exposed reliably\nObserved build: "..(r.observedBuild or "Not recorded by earlier versions").."\n\n|cffd7b56dHabitat & history|r\n"..table.concat(keys(r.zones),", ").."\nThis character: "..(r.characters[F.character] or 0).." kills\nNPC ID: "..r.id.."\n\n"
    for _,key in ipairs(keys(r.variants)) do local v=r.variants[key]; text=text.."Level "..v.level.." / "..(v.classification or "normal")..": health "..(v.healthMin or "unknown")..(v.healthMax and v.healthMax~=v.healthMin and (" - "..v.healthMax) or "").."\n" end
    if next(r.locations or {}) then text=text.."\n|cffd7b56dEncounter vicinity (your position)|r\n"; for _,key in ipairs(keys(r.locations)) do local p=r.locations[key]; text=text..(p.zone or "Map "..p.mapID).." / map "..p.mapID..": "..string.format("%.1f, %.1f",p.x*100,p.y*100).." ("..(p.instance or "unknown context")..")\n" end end
    local ref=F.Reference and F.Reference(r.id)
    if ref then text=text.."\n|cffd7b56dReference coverage|r\n"..(ref.name or r.name).." / "..(ref.zone or "").."\nSource: "..ref.source.."\nContent checked: "..ref.checked.."\nReference loot is partial prior reporting, not a server loot table.\n"
    else text=text.."\nNo reference entry is included for this creature yet.\n" end
    return text.."\nStats can vary with buffs, level and context. Restricted values are never inferred from unrelated game versions."
end
function F.ResearchText(r)
    local out="|cffd7b56dYour research|r\n"..F.Tier(r.kills).." | "..r.kills.." kills\n"
    for _,v in ipairs({{1,"Discovered"},{5,"Studied"},{15,"Researched"},{30,"Mastered"}}) do out=out..(r.kills>=v[1] and "[Complete] " or "[In progress] ")..v[2].." - "..v[1].." kills\n" end
    if r.kills>=30 then out=out.."\nCodex badge earned: Field Master (addon-only).\n" end
    out=out.."\n|cffd7b56dTracked creatures|r\n"
    local any=false; for _,id in ipairs(F.Keys(F.TrackedCreatures())) do local tracked=F.db.creatures[id]; if tracked then any=true; out=out..tracked.name..": "..tracked.kills.." kills / "..F.Tier(tracked.kills).."\n" end end
    if not any then out=out.."Choose Track research on a creature to pin its progress here.\n" end
    out=out.."\n|cffd7b56dTracked items (current bags)|r\n"
    for _,id in ipairs(F.Keys(F.db.trackedItems)) do out=out..F.ItemInfo(id).name..": "..(F.InventoryCount(id) or "?").." / "..F.db.trackedItems[id].."\n" end
    out=out.."\n|cffd7b56dZone research|r\n"
    local zones=F.ZoneSummary(); for _,zone in ipairs(F.Keys(zones)) do local z=zones[zone]; out=out..zone..": "..z.species.." discovered, "..z.mastered.." mastered\n" end
    out=out.."No game-wide completion percentage is inferred from this partial catalog.\n\n|cffd7b56dRecent encounters for this creature|r\n"
    for i,h in ipairs(r.history or {}) do if i<=10 then out=out..(F.Safe(date,"%b %d %H:%M",h.time) or "Date unavailable").." | "..(h.zone or "unknown habitat").."\n" end end
    return out
end
function F.RelatedCreatures(r)
    if not r then return {} end
    local rows={}
    for _,other in pairs(F.db.creatures) do
        if other.id~=r.id then
            local sharedZone=false; for zone in pairs(r.zones) do if other.zones[zone] then sharedZone=true end end
            if sharedZone or (r.kind and other.kind==r.kind) then rows[#rows+1]=other end
        end
    end
    table.sort(rows,function(a,b) return a.name<b.name end); return rows
end
function F.FieldPrompt(r)
    local prompts={Beast="Does it travel alone? What would you watch for on your next encounter?",Undead="What did you notice about its attacks and the place you found it?",Humanoid="Did it heal, flee, or bring anyone else into the fight?",Mechanical="Which parts of the fight would you want to remember next time?"}
    return prompts[r.kind] or "What would you want to know before meeting this creature again?"
end
function F.CaptureAppearance(m)
    if not m.previewNPC or F.readOnly then return end
    local r=F.db.creatures[m.previewNPC]; local display=F.Safe(m.GetDisplayInfo,m)
    if r and F.ValidID(display) then
        r.appearances=r.appearances or {}; local n=0; for _ in pairs(r.appearances) do n=n+1 end
        if n<16 or r.appearances[display] then r.appearances[display]={displayID=display,seen=time(),source="Live target preview"} end
    end
end
