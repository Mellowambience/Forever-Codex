local _, F = ...
local w,model,detail,body,search,notes,scroll,modelStatus,heading,subtitle,progressLabel,bar
local rows,tabButtons={},{}
local tab="Overview"
local filters={kind="All types",status="All research",zone="All zones",sort="Name A-Z",profession="All professions",offset=0}
local expanded,modelStage,smallZoomLabel
local function label(parent,font,text,x,y,width)
    local t=parent:CreateFontString(nil,"OVERLAY",font); t:SetPoint("TOPLEFT",x,y)
    t:SetJustifyH("LEFT"); if width then t:SetWidth(width) end; t:SetText(text or ""); return t
end
local function button(parent,text,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(width,25); b:SetPoint("TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",fn); return b
end
local function bg(parent,r,g,b,a)
    local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1); return t
end
local function bookArea(parent,layer,left,top,right,bottom)
    local texture=parent:CreateTexture(nil,"BACKGROUND",nil,layer)
    texture:SetPoint("TOPLEFT",parent,"TOPLEFT",left,top)
    texture:SetPoint("BOTTOMRIGHT",parent,"BOTTOMLEFT",right,bottom)
    return texture
end
local function bookBand(parent,layer,x,y,width,height)
    local texture=parent:CreateTexture(nil,"BACKGROUND",nil,layer)
    texture:SetPoint("TOPLEFT",x,y)
    texture:SetSize(width,height)
    return texture
end
local function styleBestiary(parent)
    if parent.Inset then F.Safe(parent.Inset.Hide,parent.Inset) end
    parent.themeTextures={}
    local function add(texture,key,alpha)
        parent.themeTextures[#parent.themeTextures+1]={texture=texture,key=key,alpha=alpha or 1}
        return texture
    end
    local function area(key,alpha,...)
        return add(bookArea(parent,...),key,alpha)
    end
    local function band(key,alpha,...)
        return add(bookBand(parent,...),key,alpha)
    end
    area("cover",1,2,6,-25,934,6)
    area("sidebar",1,3,12,-31,296,18)
    area("panel",1,3,305,-31,928,18)
    parent.paperGrain=bookArea(parent,4,307,-33,926,20)
    parent.paperGrain:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment")
    F.Safe(parent.paperGrain.SetAlpha,parent.paperGrain,.09)
    area("edge",1,5,297,-31,304,17)
    area("glow",.17,5,298,-35,303,22)
    area("trim",.72,6,300,-35,301,22)
    area("trim",.52,5,923,-33,925,19)
    area("edge",1,6,926,-33,928,18)
    for y=-63,-480,-56 do
        band("trim",.78,6,298,y,5,2)
    end
    band("trim",1,5,309,-62,612,59)
    band("paper",1,6,311,-64,608,54)
    band("accent",.58,7,317,-65,596,1)
    band("glow",.16,5,309,-120,602,210)
    band("trim",.9,6,312,-123,596,204)
    band("trim",.46,6,315,-381,590,1)
    -- Small stepped corner lines echo the book spine without covering controls.
    for _,x in ipairs({14,912}) do
        band("trim",.88,6,x,-31,14,1)
        band("glow",.46,6,x+4,-34,6,1)
    end
    local edge=parent:CreateTexture(nil,"BACKGROUND",nil,6)
    edge:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",13,16)
    edge:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-13,16)
    edge:SetHeight(1)
    add(edge,"trim",.6)
end
local function tint(texture,color,alpha)
    texture:SetColorTexture(color[1],color[2],color[3],alpha or 1)
end
local function textColor(region,color)
    if region then F.Safe(region.SetTextColor,region,unpack(color)) end
end
local function applyRowTheme(row,theme)
    local selected=row.record and row.record.id==F.selected
    tint(row.tint,selected and theme.selection or theme.row)
    tint(row.selectionEdge,selected and theme.glow or theme.trim,selected and .84 or .4)
    textColor(row.title,selected and theme.accent or theme.text)
    textColor(row.info,theme.muted)
end
function F.ApplyBestiaryTheme()
    local theme=F.GetCodexTheme()
    if w then
        w.themeButton:SetChoice(theme.name)
        for _,entry in ipairs(w.themeTextures) do tint(entry.texture,theme[entry.key],entry.alpha) end
        F.Safe(w.paperGrain.SetVertexColor,w.paperGrain,unpack(theme.grain))
        F.StyleCodexHeading(w.TitleText,theme)
        F.StyleCodexHeading(heading,theme,theme.ink)
        textColor(subtitle,theme.secondaryInk)
        textColor(w.summary,theme.accent)
        textColor(w.empty,theme.text)
        textColor(w.count,theme.muted)
        textColor(w.searchHint,theme.muted)
        textColor(w.levelHint,theme.muted)
        textColor(w.noteLabel,theme.accent)
        textColor(progressLabel,theme.accent)
        textColor(detail,theme.text)
        textColor(modelStatus,theme.muted)
        textColor(smallZoomLabel,theme.accent)
        tint(modelStage.themeBackground,theme.model)
        tint(bar.themeBackground,theme.edge)
        bar:SetStatusBarColor(unpack(theme.accent))
        for _,row in ipairs(rows) do applyRowTheme(row,theme) end
    end
    if expanded then
        tint(expanded.themeCover,theme.cover,.99)
        tint(expanded.themeModel,theme.model)
        tint(expanded.themeTrim,theme.trim,.85)
        tint(expanded.themeGlow,theme.glow,.16)
        F.StyleCodexHeading(expanded.TitleText,theme)
        textColor(expanded.controlsHint,theme.muted)
        textColor(expanded.zoom,theme.accent)
    end
end
local function sortedKeys(t) local keys={}; for k in pairs(t or {}) do keys[#keys+1]=k end; table.sort(keys,function(a,b) return tostring(a)<tostring(b) end); return keys end
local function coordinates(fn,...)
    local ok,x,y=pcall(fn,...)
    if ok and F.IsNumber(x) and F.IsNumber(y) then return x,y end
end
local function clearDrag(frame)
    frame.dragX,frame.dragY,frame.dragButton=nil,nil,nil
end
local function value(v) return v and tostring(v) or "Not yet available" end
local function section(s) return "|cffd7b56d"..s.."|r\n" end
local function nextTier(n) for _,v in ipairs({1,5,15,30}) do if n<v then return v end end; return 30 end
local function updateBody(text)
    detail:SetText(text); body:SetHeight(math.max(180,detail:GetStringHeight()+20))
end
function F.LoadModel(record)
    if model.recordID==record.id then return end
    model.recordID=record.id; model.preview=false; model.previewNPC=nil; model.cameraDistance=nil
    F.Safe(model.ClearModel,model); modelStatus:SetText("Loading native creature model...")
    if expanded then
        expanded.TitleText:SetText(record.name.." | Creature viewer")
        expanded.appearance:SetChoice("Default appearance")
    end
    local ok=pcall(model.SetCreature,model,record.id)
    if not ok then modelStatus:SetText("Model unavailable in this client context.") end
    F.Safe(model.SetFacing,model,0.5)
end
function F.PreviewTarget()
    local s=F.Snapshot("target")
    if not s then F.Message("Target a creature to preview its model."); return end
    model.recordID=nil; model.cameraDistance=nil; F.Safe(model.ClearModel,model)
    model.preview=true
    model.previewNPC=s.id
    local ok,result=pcall(model.SetUnit,model,"target")
    if ok and F.Public(result) and result~=false then
        modelStatus:SetText("Live target preview - no discovery added")
    else
        model.preview=false; model.previewNPC=nil
        modelStatus:SetText("Target model is restricted or unavailable.")
    end
end
function F.Render()
    if not w then return end
    local theme=F.GetCodexTheme()
    local matches=F.Rows(search:GetText(),filters.kind,filters.status,filters)
    if F.HideDetailPanels then F.HideDetailPanels() end; detail:Show()
    local total,kills,mastered=0,0,0
    for _,r in pairs(F.db.creatures) do total=total+1; kills=kills+r.kills; if r.kills>=30 then mastered=mastered+1 end end
    w.summary:SetText(total.." species discovered  |  "..kills.." kills  |  "..mastered.." mastered")
    if not F.selected or not F.db.creatures[F.selected] then F.selected=matches[1] and matches[1].id end
    filters.offset=math.max(0,math.min(filters.offset,math.max(0,#matches-#rows)))
    for i,b in ipairs(rows) do
        local r=matches[filters.offset+i]; b:SetShown(r~=nil)
        if r then
            b.record=r; b.title:SetText((r.favorite and "|cffd7b56d* |r" or "")..r.name)
            b.info:SetText((r.kind or "Unknown type").."  |  "..r.kills.." kills  |  "..F.Tier(r.kills))
            applyRowTheme(b,theme)
        end
    end
    w.count:SetText(#matches>#rows and ("%d–%d of %d · Scroll to browse"):format(filters.offset+1,filters.offset+#rows,#matches)
        or (#matches.." matches"))
    w.empty:SetShown(#matches==0)
    w.empty:SetText(total==0 and "An unwritten journal\n\nDefeat a creature to discover its entry.\n\nTargeting and model previews alone do not add discoveries." or "No matches.\n\nClear search or change the filters.")
    for name,b in pairs(tabButtons) do if name==tab then b:Disable() else b:Enable() end end
    local r=F.db.creatures[F.selected]
    local noteText=r and r.notes or ""
    if F.Safe(notes.GetText,notes)~=noteText then
        notes.loading=true; notes:SetText(noteText); notes.loading=false
    end
    if not r then
        heading:SetText("Your bestiary begins here"); subtitle:SetText("Explore. Encounter. Discover.")
        updateBody(section("An unwritten page").."Your first confirmed creature kill opens this journal.\n\nUse Preview target to inspect a native model without adding a discovery.\n\nAll information is observed in your client. Restricted or unavailable values stay unknown.")
        F.Safe(model.ClearModel,model); model.recordID=nil; modelStatus:SetText("Native 3D creature viewer")
        progressLabel:SetText("Research milestones: 1 / 5 / 15 / 30 kills"); bar:SetMinMaxValues(0,1); bar:SetValue(0)
        notes:Hide(); w.noteLabel:Hide(); w.favorite:Disable(); w.skin:Disable(); w.salvage:Disable(); return
    end
    heading:SetText(r.name); subtitle:SetText((r.kind or "Unknown type").."  |  Level "..value(r.level).."  |  "..(r.zone or "Unknown habitat"))
    w.favorite:Enable(); w.favorite:SetText(r.favorite and "Unbookmark" or "Bookmark")
    w.skin:Enable(); w.salvage:Enable()
    notes:SetShown(tab=="Notes"); w.noteLabel:SetShown(tab=="Notes")
    scroll:SetPoint("BOTTOMRIGHT",-35,tab=="Notes" and 165 or 105)
    if F.readOnly then notes:Disable(); w.favorite:Disable(); w.skin:Disable(); w.salvage:Disable(); w.summary:SetText("Read-only: saved data belongs to a newer addon version. Update before recording.")
    else notes:Enable() end
    F.LoadModel(r)
    local next=nextTier(r.kills)
    progressLabel:SetText(F.Tier(r.kills).."  |  "..r.kills.." kills"..(r.kills<30 and ("  |  next milestone: "..next) or "  |  mastery complete"))
    bar:SetMinMaxValues(0,next); bar:SetValue(math.min(r.kills,next))
    if tab=="Loot" then detail:Hide(); F.RenderLoot(body,r); return end
    if tab=="Crafting" then detail:Hide(); F.RenderCrafting(body,r); return end
    if tab=="Notes" then detail:Hide(); F.RenderNotes(body,r); return end
    if tab=="Overview" then updateBody(F.OverviewText(r)); return end
    if tab=="Research" then updateBody(F.ResearchText(r)); return end
    local text=""
    if tab=="Abilities" then
        text=section("Observed successful casts")
        local found=false
        for _,id in ipairs(sortedKeys(r.abilities)) do local a=r.abilities[id]; found=true; text=text..a.name.." (spell "..id..")\nObserved casts: "..a.count.."\n\n" end
        if not found then text=text.."No accessible spell casts recorded yet. Keep the creature targeted or visible on a nameplate during encounters.\n\n" end
        text=text.."Only successful casts exposed by the client appear here. This is not a complete ability list, and no weaknesses or tactics are invented."
    elseif tab=="Professions" then
        text=section("Profession research")
        local found=false
        for _,name in ipairs(sortedKeys(r.professions)) do local p=r.professions[name]; found=true; text=text..name.." - "..(p.observed and "source-linked gathering observed" or "manually confirmed").."\n"; for _,link in pairs(p.materials or {}) do text=text.."  "..link.."\n" end; text=text.."\n" end
        if not found then text=text.."No gathering observations recorded.\n\n" end
        text=text.."Skinning is detected when a successful skinning cast and its following source-linked loot can both be observed. Manual confirmations are available below.\n\n"..section("Observed loot")
        local loot={}; for _,l in pairs(r.loot) do loot[#loot+1]=l end; table.sort(loot,function(a,b) return (a.link or "")<(b.link or "") end)
        for _,l in ipairs(loot) do text=text..(l.link or ("Item "..value(l.itemID))).." x "..(l.count or 0).."\n" end
        if #loot==0 then text=text.."No source-attributed item observations yet.\n" end
        text=text.."\nCounts describe loot seen, not necessarily collected. They are not drop chances. Reopening loot is deduplicated during the session. Recipe links and other automatic gathering types are not included in this version."
    end
    updateBody(text)
end
function F.RestoreJournalModel()
    if not model or not model.inExpanded or F.Safe(InCombatLockdown) then return end
    model:SetParent(modelStage); model:ClearAllPoints(); model:SetAllPoints(modelStage); model.zoomLabel=smallZoomLabel; model.inExpanded=nil
    F.ResizeModelCamera(model)
end
function F.ToggleExpandedViewer()
    if not model then return end
    if F.activeWindow=="viewer" then expanded:Hide(); return end
    if F.Safe(InCombatLockdown) then F.Message("Open the creature viewer after combat."); return end
    if not expanded then
        expanded=CreateFrame("Frame","ForeverBestiaryExpandedViewer",UIParent,"BasicFrameTemplateWithInset")
        F.expanded=expanded; expanded:SetSize(780,640); expanded:SetPoint("CENTER"); expanded:SetClampedToScreen(true); F.RegisterWindow("viewer",expanded,780,640)
        expanded:SetMovable(true); expanded:EnableMouse(true); expanded:RegisterForDrag("LeftButton")
        expanded:SetScript("OnDragStart",function(self) if not InCombatLockdown() then self:StartMoving() end end)
        expanded:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); F.SaveWindowPosition("viewer") end)
        if expanded.Inset then F.Safe(expanded.Inset.Hide,expanded.Inset) end
        expanded.themeCover=bookArea(expanded,2,6,-25,774,6)
        expanded.themeGlow=bookArea(expanded,3,15,-35,765,95)
        expanded.themeTrim=bookArea(expanded,4,18,-38,762,98)
        expanded.themeModel=bookArea(expanded,5,20,-40,760,100)
        tinsert(UISpecialFrames,"ForeverBestiaryExpandedViewer")
        expanded.controlsHint=label(expanded,"GameFontDisableSmall","Left-drag: rotate | Right-drag: pan | Scroll: zoom",20,-595,460)
        button(expanded,"-",480,-591,32,function() F.ZoomModel(model,-1) end)
        button(expanded,"+",518,-591,32,function() F.ZoomModel(model,1) end)
        button(expanded,"Fit",558,-591,65,function() F.FitModel(model) end)
        expanded.zoom=label(expanded,"GameFontNormalSmall","100%",640,-598,100)
        expanded.appearance=F.Dropdown(expanded,"Default appearance",20,-552,260,function()
            local options={"Default appearance"}; local r=F.db.creatures[F.selected]; expanded.appearanceIDs={}
            if r then for i,id in ipairs(F.Keys(r.appearances)) do local name="Observed appearance "..i; options[#options+1]=name; expanded.appearanceIDs[name]=id end end
            return options
        end,function(choice)
            local display=expanded.appearanceIDs[choice]
            local ok
            if display then ok=pcall(model.SetDisplayInfo,model,display)
            elseif model.recordID then ok=pcall(model.SetCreature,model,model.recordID)
            else return end
            if not ok then
                modelStatus:SetText("Appearance unavailable in this client context.")
                F.Message("This model appearance could not be loaded.")
            end
        end)
        button(expanded,"Back to codex",292,-552,160,function()
            if F.ShowManaged("journal") then F.Render() end
        end)
        expanded:SetScript("OnHide",function()
            if not F.layoutSuspending then F.RestoreJournalModel() end
            F.HideDropdowns(); F.ManagedHidden("viewer")
        end)
        F.ApplyBestiaryTheme()
        expanded:Hide()
    end
    local r=F.db.creatures[F.selected]; expanded.TitleText:SetText((r and r.name or "Target preview").." | Creature viewer")
    if not F.ShowManaged("viewer") then return end
    model.inExpanded=true; model:SetParent(expanded); model:ClearAllPoints(); model:SetPoint("TOPLEFT",20,-40); model:SetPoint("BOTTOMRIGHT",-20,100); model.zoomLabel=expanded.zoom
    F.ResizeModelCamera(model)
end
function F.CreateUI()
    if w then return end
    w=CreateFrame("Frame","ForeverBestiaryWindow",UIParent,"BasicFrameTemplateWithInset")
    local screenHeight=F.Safe(UIParent.GetHeight,UIParent)
    local journalHeight=F.IsNumber(screenHeight) and math.min(800,math.max(650,screenHeight-40)) or 800
    F.window=w; F.RegisterWindow("journal",w,940,journalHeight); w:SetSize(940,journalHeight); w:SetPoint("CENTER"); w:SetMovable(true); w:EnableMouse(true); w:SetClampedToScreen(true)
    w:RegisterForDrag("LeftButton"); w:SetScript("OnDragStart",function(self) if not InCombatLockdown() then self:StartMoving() end end)
    w:SetScript("OnHide",function()
        if not F.switchingWindows and expanded then expanded:Hide() end
        F.Safe(search and search.ClearFocus,search)
        F.Safe(notes and notes.ClearFocus,notes)
        F.Safe(F.minLevelBox and F.minLevelBox.ClearFocus,F.minLevelBox)
        F.Safe(F.maxLevelBox and F.maxLevelBox.ClearFocus,F.maxLevelBox)
        F.HideDropdowns()
        F.ManagedHidden("journal")
    end)
    w:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        F.SaveWindowPosition("journal")
    end)
    w.TitleText:SetText("Forever Codex  |  Bestiary")
    tinsert(UISpecialFrames,"ForeverBestiaryWindow")
    styleBestiary(w)
    w.summary=label(w,"GameFontNormalSmall","",20,-40,274)
    button(w,"Today's Page",315,-35,124,function() F.OpenToday() end)
    button(w,"Atlas",443,-35,72,function() F.OpenAtlas() end)
    w.themeButton=F.CodexThemeButton(w,519,-35,108)
    search=CreateFrame("EditBox",nil,w,"InputBoxTemplate"); search:SetSize(263,25); search:SetPoint("TOPLEFT",24,-68); search:SetAutoFocus(false); search:SetMaxLetters(100)
    search:SetScript("OnTextChanged",function() filters.offset=0; F.Refresh() end); search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    w.searchHint=label(w,"GameFontDisableSmall","Search creatures, zones or loot",24,-96,260)
    local function choices(field,first)
        local found={}; for _,r in pairs(F.db.creatures) do if field=="kind" then if r.kind then found[r.kind]=true end else for k in pairs(r[field] or {}) do found[k]=true end end end
        local values=F.Keys(found); table.insert(values,1,first); return values
    end
    F.kindButton=F.Dropdown(w,"All types",18,-118,130,function() return choices("kind","All types") end,function(value) filters.kind=value; filters.offset=0; F.Render() end)
    F.statusButton=F.Dropdown(w,"All research",155,-118,132,function() return {"All research","Bookmarked","Tracked","Discovered","Studied","Researched","Mastered"} end,function(value) filters.status=value; filters.offset=0; F.Render() end)
    F.zoneButton=F.Dropdown(w,"All zones",18,-149,130,function() return choices("zones","All zones") end,function(value) filters.zone=value; filters.offset=0; F.Render() end)
    F.sortButton=F.Dropdown(w,"Name A-Z",155,-149,132,function() return {"Name A-Z","Most kills","Recent","Level"} end,function(value) filters.sort=value; filters.offset=0; F.Render() end)
    w.levelHint=label(w,"GameFontDisableSmall","Level min / max",22,-181,130)
    for i,key in ipairs({"minLevel","maxLevel"}) do local box=CreateFrame("EditBox",nil,w,"InputBoxTemplate"); box:SetSize(50,22); box:SetPoint("TOPLEFT",24+(i-1)*64,-196); box:SetAutoFocus(false); box:SetMaxLetters(3); box:SetScript("OnTextChanged",function(self) filters[key]=self:GetText(); filters.offset=0; F.Refresh() end); box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end); F[key.."Box"]=box end
    F.professionButton=F.Dropdown(w,"All professions",155,-184,132,function() return choices("professions","All professions") end,function(value) filters.profession=value; filters.offset=0; F.Render() end)
    local visibleRows=math.max(8,math.floor((journalHeight-335)/34))
    local list=CreateFrame("Frame",nil,w); list:SetSize(275,visibleRows*34); list:SetPoint("TOPLEFT",16,-225); list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel",function(_,delta) filters.offset=filters.offset-delta; F.Render() end)
    for i=1,visibleRows do
        local b=CreateFrame("Button",nil,list); b:SetSize(275,32); b:SetPoint("TOPLEFT",0,-(i-1)*34); b.tint=bg(b,.19,.121,.081)
        b.selectionEdge=bookBand(b,1,0,0,2,32)
        b.title=label(b,"GameFontNormalSmall","",8,-3,255); b.info=label(b,"GameFontHighlightSmall","",8,-17,255)
        b:SetScript("OnClick",function(self) F.selected=self.record.id; F.db.settings.selected=F.selected; scroll:SetVerticalScroll(0); F.Render() end)
        b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self.record.name); GameTooltip:AddLine(self.record.kind or "Unknown type",1,1,1); GameTooltip:Show() end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end); rows[i]=b
    end
    w.empty=label(list,"GameFontHighlight","",12,-20,250)
    w.count=label(w,"GameFontDisableSmall","",20,-journalHeight+78,275)
    button(w,"My professions",18,-journalHeight+107,130,function() F.OpenProfessions() end)
    button(w,"Gold planner",155,-journalHeight+107,132,function() F.OpenGoldPlanner() end)
    button(w,"Clear filters",18,-journalHeight+50,130,function() filters.kind="All types"; filters.status="All research"; filters.zone="All zones"; filters.sort="Name A-Z"; filters.profession="All professions"; filters.offset=0; F.kindButton:SetChoice(filters.kind); F.statusButton:SetChoice(filters.status); F.zoneButton:SetChoice(filters.zone); F.sortButton:SetChoice(filters.sort); F.professionButton:SetChoice(filters.profession); F.minLevelBox:SetText(""); F.maxLevelBox:SetText(""); search:SetText(""); F.Render() end)
    button(w,"Preview target",155,-journalHeight+50,132,function() F.PreviewTarget() end)
    heading=label(w,"GameFontNormalHuge","",315,-68,590)
    subtitle=label(w,"GameFontHighlightSmall","",317,-100,470)
    local stage=CreateFrame("Frame",nil,w); stage:SetSize(590,200); stage:SetPoint("TOPLEFT",315,-125)
    stage.themeBackground=bg(stage,.105,.073,.055)
    modelStage=stage
    model=CreateFrame("PlayerModel",nil,stage); model:SetAllPoints(); model:EnableMouse(true); model:EnableMouseWheel(true); F.Safe(model.SetFacing,model,.5)
    model:SetScript("OnModelLoaded",function(self) if self.preview then F.CaptureAppearance(self) end; F.InitModelCamera(self); modelStatus:SetText(model.preview and "Target preview - no discovery added" or "Drag: rotate  |  Right-drag: pan  |  Scroll: zoom"); model.preview=false; model.previewNPC=nil end)
    model:SetScript("OnMouseDown",function(self,which) self.dragX,self.dragY=coordinates(GetCursorPosition); self.dragButton=which end)
    model:SetScript("OnMouseUp",clearDrag)
    model:SetScript("OnHide",clearDrag)
    model:SetScript("OnUpdate",function(self)
        if not self.dragX then return end
        if IsMouseButtonDown and not F.Safe(IsMouseButtonDown,self.dragButton or "LeftButton") then clearDrag(self); return end
        local x,y=coordinates(GetCursorPosition)
        local scale=F.Safe(self.GetEffectiveScale,self)
        if not x or not F.IsNumber(scale) or scale<=0 then clearDrag(self); return end
        if self.dragButton=="RightButton" then F.PanModel(self,(y-self.dragY)/scale)
        else
            local facing=F.Safe(self.GetFacing,self)
            if F.IsNumber(facing) then F.Safe(self.SetFacing,self,facing+(x-self.dragX)/scale/100) end
        end
        self.dragX,self.dragY=x,y
    end)
    model:SetScript("OnMouseWheel",function(self,delta) F.ZoomModel(self,delta) end)
    modelStatus=label(w,"GameFontDisableSmall","",320,-330,350)
    button(w,"-",680,-326,30,function() F.ZoomModel(model,-1) end)
    button(w,"+",716,-326,30,function() F.ZoomModel(model,1) end)
    button(w,"Fit",752,-326,55,function() F.FitModel(model) end)
    model.zoomLabel=label(w,"GameFontNormalSmall","100%",819,-333,80)
    smallZoomLabel=model.zoomLabel
    button(w,"Expand",810,-96,95,function() F.ToggleExpandedViewer() end)
    local tabs={"Overview","Abilities","Loot","Professions","Crafting","Research","Notes"}
    for i,name in ipairs(tabs) do local n=name; tabButtons[n]=button(w,n,315+(i-1)*84,-352,80,function() tab=n; scroll:SetVerticalScroll(0); F.HideDropdowns(); F.Render() end) end
    scroll=CreateFrame("ScrollFrame",nil,w,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",318,-389); scroll:SetPoint("BOTTOMRIGHT",-35,130); F.AddScrollCue(scroll)
    body=CreateFrame("Frame",nil,scroll); body:SetSize(570,200); scroll:SetScrollChild(body)
    detail=label(body,"GameFontHighlight","",0,0,565); detail:SetSpacing(3)
    w.noteLabel=label(w,"GameFontNormalSmall","Field notes (saved as you type)",320,-journalHeight+150,570)
    notes=CreateFrame("EditBox",nil,w,"InputBoxTemplate"); notes:SetSize(565,25); notes:SetPoint("TOPLEFT",323,-journalHeight+130); notes:SetAutoFocus(false); notes:SetMaxLetters(2000)
    notes:SetScript("OnTextChanged",function(self)
        local r=F.db.creatures[F.selected]
        if not r or self.loading or F.readOnly then return end
        local text=F.Safe(self.GetText,self)
        if F.IsText(text) then r.notes=text end
    end)
    notes:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    progressLabel=label(w,"GameFontNormalSmall","",320,-journalHeight+94,570)
    bar=CreateFrame("StatusBar",nil,w); bar:SetSize(590,6); bar:SetPoint("TOPLEFT",315,-journalHeight+75); bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar.themeBackground=bg(bar,.2,.23,.19)
    w.favorite=button(w,"Bookmark",315,-journalHeight+49,115,function() local r=F.db.creatures[F.selected]; if r then r.favorite=not r.favorite; F.Render() end end)
    button(w,"Track research",650,-35,140,function() local r=F.db.creatures[F.selected]; if r then F.ToggleCreatureTracking(r) end end)
    button(w,"Map vicinity",800,-35,105,function() local r=F.db.creatures[F.selected]; if r then F.OpenLocation(r) end end)
    local function confirm(name) local r=F.db.creatures[F.selected]; if r then local p=r.professions[name] or {}; p.manual=true; r.professions[name]=p; tab="Professions"; F.Render() end end
    w.skin=button(w,"Confirm skinning",436,-journalHeight+49,148,function() confirm("Skinning") end)
    w.salvage=button(w,"Confirm salvage",590,-journalHeight+49,148,function() confirm("Salvage") end)
    button(w,"Reset model",744,-journalHeight+49,161,function() F.FitModel(model) end)
    F.selected=F.db.settings.selected or F.selected
    F.ApplyBestiaryTheme()
    w:Hide()
end
function F.UpdateMinimap()
    if not F.minimap then return end
    F.minimap:SetShown(not F.db.settings.hideMinimap)
    local width,height=F.Safe(Minimap.GetWidth,Minimap),F.Safe(Minimap.GetHeight,Minimap)
    if not F.IsNumber(width) or not F.IsNumber(height) then return end
    local a=math.rad(F.db.settings.angle); local radius=math.max(width,height)/2+8
    F.minimap:ClearAllPoints(); F.minimap:SetPoint("CENTER",Minimap,"CENTER",math.cos(a)*radius,math.sin(a)*radius)
end
function F.CreateMinimap()
    if F.minimap or not Minimap then return end
    local b=CreateFrame("Button","ForeverBestiaryMinimapButton",Minimap); F.minimap=b
    b:SetSize(31,31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(Minimap:GetFrameLevel()+8)
    local back=b:CreateTexture(nil,"BACKGROUND"); back:SetSize(20,20); back:SetPoint("TOPLEFT",7,-5); back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetSize(20,20); icon:SetPoint("TOPLEFT",7,-5); icon:SetTexture("Interface\\AddOns\\ForeverBestiary\\Media\\CodexIcon"); icon:SetTexCoord(0,1,0,1)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local border=b:CreateTexture(nil,"OVERLAY"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetSize(53,53); border:SetPoint("TOPLEFT")
    b:RegisterForClicks("LeftButtonUp","RightButtonUp"); b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick",function(_,which) if which=="RightButton" then F.db.settings.hideMinimap=true; F.UpdateMinimap(); F.Message("Minimap button hidden. /fbc minimap restores it.") else F.Toggle() end end)
    b:SetScript("OnDragStart",function(self) self.dragging=true; GameTooltip:Hide() end)
    b:SetScript("OnDragStop",function(self) self.dragging=false end)
    b:SetScript("OnUpdate",function(self)
        if not self.dragging then return end
        if IsMouseButtonDown and not F.Safe(IsMouseButtonDown,"LeftButton") then self.dragging=false; return end
        local x,y=coordinates(GetCursorPosition)
        local cx,cy=coordinates(Minimap.GetCenter,Minimap)
        local scale=F.Safe(Minimap.GetEffectiveScale,Minimap)
        if not x or not cx or not F.IsNumber(scale) or scale<=0 then return end
        F.db.settings.angle=math.deg(math.atan2(y/scale-cy,x/scale-cx)); F.UpdateMinimap()
    end)
    b:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_LEFT"); GameTooltip:SetText("Forever Codex"); GameTooltip:AddLine("Left-click: open your codex",1,1,1); GameTooltip:AddLine("Drag: move around the minimap",1,1,1); GameTooltip:AddLine("Right-click: hide (/fbc minimap restores)",.7,.7,.7); GameTooltip:Show() end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    F.UpdateMinimap()
end
