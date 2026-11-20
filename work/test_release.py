from pathlib import Path
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
F={}; frames={}; UISpecialFrames={}; SlashCmdList={}; tinsert=table.insert; clock=100
function issecretvalue(v) return type(v)=="string" and v=="SECRET" end
function strsplit(sep,s) return string.match(s,"([^-]+)-([^-]+)-([^-]+)-([^-]+)-([^-]+)-([^-]+)-(.+)") end
function strtrim(s) return string.match(s,"^%s*(.-)%s*$") end
function time() return 12345 end
function GetTime() return clock end
function GetBuildInfo() return "1.60.1","70790" end
function date() return "Nov 06, 2026" end
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame(kind,name,parent,template)
 local f={shown=true,scripts={},text="",events={},kind=kind,children={}}
 local noop=function() end
 local methods={"SetParent","SetSize","SetMultiLine","SetFontObject","SetFocus","HighlightText","SetPoint","ClearAllPoints","SetMovable","EnableMouse","RegisterForDrag","SetJustifyH","SetWidth","SetHeight","SetSpacing","SetAutoFocus","EnableMouseWheel","SetClampedToScreen","SetScale","SetAllPoints","SetColorTexture","SetTexture","SetFrameStrata","SetFrameLevel","SetNormalTexture","SetHighlightTexture","RegisterForClicks","SetTexCoord","SetStatusBarTexture","SetStatusBarColor","SetMinMaxValues","SetValue","SetMaxLetters","SetPortraitZoom","SetCamDistanceScale","SetPosition","SetScrollChild","SetVerticalScroll","StartMoving","StopMovingOrSizing","ClearFocus","ClearModel"}
 for _,k in ipairs(methods) do f[k]=noop end
 function f:RegisterEvent(e) self.events[e]=true end
 function f:SetScript(e,fn) self.scripts[e]=fn end
 function f:CreateFontString() return CreateFrame("FontString") end
 function f:CreateTexture() return CreateFrame("Texture",nil,self) end
 function f:SetTexture(t) self.texture=t end
 function f:SetSize(width,height) self.width=width; self.height=height end
 function f:SetPoint(...) self.point={...} end
 function f:GetNormalTexture() return CreateFrame("Texture") end
 function f:Hide() self.shown=false end
 function f:Show() self.shown=true end
 function f:SetShown(v) self.shown=v end
 function f:IsShown() return self.shown end
 function f:Enable() self.enabled=true end
 function f:Disable() self.enabled=false end
 function f:GetText() return self.text end
 function f:SetText(t) self.text=t; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
 function f:GetStringHeight() return 100 end
 function f:SetCreature(id) self.creature=id end
 function f:SetUnit(unit) self.unit=unit end
 function f:GetWidth() return 1600 end
 function f:GetHeight() return 900 end
 function f:GetCenter() return 400,400 end
 function f:GetEffectiveScale() return 1 end
 function f:GetFrameLevel() return 1 end
 function f:SetFacing(v) self.facing=v end
 function f:GetFacing() return self.facing or .5 end
 f.TitleText={SetText=noop}; frames[#frames+1]=f
 if parent and parent.children then parent.children[#parent.children+1]=f end
 if name then _G[name]=f end
 return f
end
UIParent=CreateFrame("Frame"); Minimap=CreateFrame("Frame"); GameTooltip={SetOwner=function() end,SetText=function() end,AddLine=function() end,Show=function() end,Hide=function() end}
function InCombatLockdown() return false end
function IsMouseButtonDown() return true end
function GetCursorPosition() return 300,300 end
unitGUID="Creature-0-1-2-3-123-ABC"; currentLevel=8; currentHP=145; lootSlots=2
function UnitGUID(u) if u=="player" then return "Player-1" elseif u=="pet" then return "Pet-1" end; return unitGUID end
function UnitName(u) if u=="player" then return "Tester" end; return "Test Wolf" end
function GetRealmName() return "Realm" end
function UnitCreatureType() return "Beast" end
function UnitClassification() return "normal" end
function UnitLevel() return currentLevel end
function UnitHealthMax() return currentHP end
function UnitAttackSpeed() return 2 end
function UnitArmor() return 0 end
function UnitDamage() return 0,0 end
function GetRealZoneText() return "Elwynn" end
function GetNumLootItems() return lootSlots end
function GetLootSourceInfo(slot) return unitGUID,2 end
function GetLootSlotLink() return "|Hitem:2318:0|h[Light Leather]|h" end
C_Spell={GetSpellName=function(id) if id==8613 or id==8617 then return "Skinning" end; return "Spell "..id end}
ForeverBestiaryDB={version=1,creatures={[123]={name="Old Wolf",kills=2,notes="Old note",health=100,loot={old={link="|Hitem:2318:0|h[Light Leather]|h",count=1}},profession="Skinning (manually confirmed)"}}}
''')
root = Path('outputs/ForeverBestiary')
manifest = (root / 'ForeverBestiary.toc').read_text(encoding='utf-8')
assert manifest == (root / 'ForeverBestiary_Camelot.toc').read_text(encoding='utf-8')
for filename in manifest.splitlines():
    if filename.endswith('.lua'):
        lua.execute('assert(loadstring(...))("ForeverBestiary",F)', (root / filename).read_text(encoding='utf-8'))
lua.execute('''
local e=frames[#frames]
e.scripts.OnEvent(e,"ADDON_LOADED","ForeverBestiary")
assert(F.db.version==3 and F.db.creatures[123].notes=="Old note")
assert(F.db.creatures[123].loot["2318"].count==1,"Loot migration failed")
assert(F.minimap and F.minimap:IsShown(),"Minimap not created")
local icon
for _,t in ipairs(F.minimap.children) do if t.texture and string.find(t.texture,"CodexIcon",1,true) then icon=t end end
assert(icon and icon.width==20 and icon.height==20,"Minimap artwork must be inset")
assert(icon.point[2]>=0 and icon.point[2]+icon.width<=F.minimap.width,"Minimap icon overflows horizontally")
assert(-icon.point[3]>=0 and -icon.point[3]+icon.height<=F.minimap.height,"Minimap icon overflows vertically")
F.Snapshot("target"); assert(F.db.creatures[123].name=="Test Wolf"); assert(F.db.creatures[123].kills==2)
F.Kill("Player-1",unitGUID); assert(F.db.creatures[123].kills==3)
F.Kill("Player-1",unitGUID); assert(F.db.creatures[123].kills==3,"Duplicate kill")
F.Kill("Player-1","SECRET"); assert(F.NPC("Player-1")==nil)
F.db.settings.group=false
F.Kill("Player-other","Creature-0-1-2-3-321-A"); assert(not F.db.creatures[321])
F.Kill("Pet-1","Creature-0-1-2-3-321-A"); assert(F.db.creatures[321].kills==1)
currentLevel=9; currentHP=180; F.Snapshot("target")
assert(F.db.creatures[123].variants["8:normal"] and F.db.creatures[123].variants["9:normal"])
assert(not F.db.creatures[123].armor and not F.db.creatures[123].damageMin,"Unsupported zeros must stay unknown")
F.Loot(); F.Loot(); assert(F.db.creatures[123].loot["2318"].count==5,"Multi-slot aggregation or dedup failed")
lootSlots=1; F.Loot(); assert(F.db.creatures[123].loot["2318"].count==5,"Shrinking loot duplicated")
F.CastStart("player",8617); F.Spell("player","Cast-skin",8617); F.Loot()
assert(F.db.creatures[123].professions.Skinning.observed,"Rank-aware skinning not linked")
F.Spell("target","Cast-1",999); F.Spell("target","Cast-1",999)
assert(F.db.creatures[123].abilities[999].count==1,"Spell duplicate counted")
F.Spell("target","SECRET","SECRET")
assert(#F.Rows("wolf","Beast","All research")==1)
F.db.creatures[123].favorite=true; assert(#F.Rows("","All types","Bookmarked")==1)
assert(F.Tier(1)=="Discovered" and F.Tier(5)=="Studied" and F.Tier(15)=="Researched" and F.Tier(30)=="Mastered")
F.selected=nil; F.Toggle(); assert(F.todayWindow:IsShown(),"Default open must show Today")
F.OpenBestiary(); assert(F.window:IsShown() and F.selected,"Saved journal must select an entry")
F.selected=123; F.Render(); local native=false; for _,f in ipairs(frames) do if f.creature==F.selected then native=true end end; assert(native,"Native model ID not loaded")
for _,name in ipairs({"Overview","Abilities","Loot","Professions","Crafting","Research","Notes"}) do
 for _,b in ipairs(frames) do if b.text==name and b.scripts.OnClick then b.scripts.OnClick(b); break end end
end
for _,b in ipairs(frames) do if b.kind=="EditBox" and b.scripts.OnTextChanged and b.text=="Old note" then b:SetText("Persistent note") end end
assert(F.db.creatures[123].notes=="Persistent note","Notes not saved")
F.Toggle(); assert(not F.window:IsShown())
SlashCmdList.FOREVERBESTIARY("minimap"); assert(not F.minimap:IsShown())
SlashCmdList.FOREVERBESTIARY("minimap"); assert(F.minimap:IsShown())
F.minimap.scripts.OnClick(F.minimap,"RightButton"); assert(F.db.settings.hideMinimap)
F.minimap.scripts.OnDragStart(F.minimap); F.minimap.scripts.OnUpdate(F.minimap); F.minimap.scripts.OnDragStop(F.minimap)
assert(type(F.db.settings.angle)=="number")
local model
for _,frame in ipairs(frames) do if frame.kind=="PlayerModel" then model=frame end end
assert(model)
model.scripts.OnModelLoaded(model)
local fit=model.cameraDistance
assert(fit>1,"Wide model panel needs distance padding")
F.ZoomModel(model,5); assert(model.cameraDistance<fit*.5,"Five ticks must provide meaningful close-up")
F.ZoomModel(model,-10); assert(model.cameraDistance>fit*2,"Zoom out must go beyond original framing")
F.ZoomModel(model,-500); assert(model.cameraDistance==18)
F.ZoomModel(model,500); assert(model.cameraDistance==.15)
F.PanModel(model,80); assert(model.cameraPan>0)
F.FitModel(model); assert(model.cameraDistance==fit and model.cameraPan==0)
F.ZoomModel(model,2); local remembered=model.cameraDistance; model.cameraDistance=nil
F.InitModelCamera(model); assert(model.cameraDistance==remembered,"Per-creature camera must persist")
assert(F.ModelFitScale(590,200)>F.ModelFitScale(200,590),"Aspect ratio must influence fit")
F.ToggleExpandedViewer(); assert(F.expanded:IsShown(),"Expanded viewer must open")
F.ToggleExpandedViewer(); assert(not F.expanded:IsShown(),"Expanded viewer must close")
for i=1,2100 do F.Remember(F.seenCasts,"test"..i,true) end
assert(#F.cacheKeys[F.seenCasts]<=2048,"Unbounded cache")
''')
print('PASS: Lua 5.1, v1 migration, kill credit, deduplication, restricted IDs, level variants, unknown stats, multi-slot loot, rank-aware skinning, observed spells, filters, bookmarks, research, saved selection, all UI tabs, notes, native model, minimap toggle/hide/drag, bounded caches')



