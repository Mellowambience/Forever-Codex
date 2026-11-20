import runpy, random, time
ctx=runpy.run_path('work/test_release.py'); lua=ctx['lua']
lua.execute('''
-- Match native Show/Hide transitions for managed windows.
for _,frame in ipairs({F.window,F.expanded}) do
 if frame then
  function frame:Hide() local was=self.shown; self.shown=false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
  function frame:Show() self.shown=true end
 end
end
local function check(width,height,fw,fh,blocks)
 local p=F.PlanWindow(width,height,fw,fh,blocks)
 if p then
  assert(p.x>=15.99 and p.y>=15.99 and p.x+p.w<=width-15.99 and p.y+p.h<=height-15.99)
  for _,b in ipairs(blocks) do assert(not F.RectsOverlap(p,b),"Overlap") end
 end
 return p
end
assert(check(1600,900,548,600,{{x=0,y=100,w=850,h=760}}),"Seller should fit beside AH")
assert(check(1280,720,460,600,{{x=0,y=80,w=700,h=640}}),"Seller fits lower resolution alongside AH")
assert(not check(1024,768,940,700,{{x=0,y=0,w=1024,h=768}}),"Fullscreen suspends journal")
assert(check(800,600,940,650,{}),"Small-screen scale fit")
assert(check(1920,1080,548,600,{{x=0,y=100,w=850,h=850},{x=1600,y=0,w=320,h=1000}}),"AH and bags leave clean center")
assert(check(1280,720,460,600,{{x=0,y=80,w=830,h=640}}),"Compact seller should remain usable at AH on smaller screens")
local r=F.PlanWindow(1600,900,548,600,{}, {x=300,y=450}); assert(math.abs(r.x+r.w/2-300)<1)
F.CreateUI(); F.ShowManaged("journal"); assert(F.window:IsShown() and F.activeWindow=="journal")
F.OpenSeller(); assert(not F.window:IsShown() and F.sellWindow:IsShown() and F.activeWindow=="seller")
assert(F.sellWindow:GetWidth() and F.sellWindow.rules.shown==false)
F.sellWindow.rulesToggle.scripts.OnClick(); assert(F.sellWindow.rules.shown==true)
F.ShowManaged("journal"); F.ToggleExpandedViewer()
assert(not F.window:IsShown() and F.expanded:IsShown() and not F.sellWindow:IsShown())
F.expanded:Hide(); assert(F.window:IsShown() and F.activeWindow=="journal","Closing viewer returns to codex")
-- Accessible native frame geometry, including effective scale conversion.
AuctionHouseFrame=CreateFrame("Frame")
function AuctionHouseFrame:GetLeft() return 0 end
function AuctionHouseFrame:GetRight() return 425 end
function AuctionHouseFrame:GetBottom() return 50 end
function AuctionHouseFrame:GetTop() return 430 end
function AuctionHouseFrame:GetEffectiveScale() return 2 end
local rect=F.FrameRect(AuctionHouseFrame); assert(rect.w==850 and rect.h==760)
F.auctionOpen=true; F.OpenSeller(); assert(not F.window:IsShown() and F.sellWindow:IsShown())
-- Native fullscreen frame temporarily suspends and restores requested panel.
WorldMapFrame=CreateFrame("Frame")
function WorldMapFrame:GetLeft() return 0 end
function WorldMapFrame:GetRight() return 1600 end
function WorldMapFrame:GetBottom() return 0 end
function WorldMapFrame:GetTop() return 900 end
F.LayoutWindows(true); assert(not F.sellWindow:IsShown() and F.activeWindow=="seller")
WorldMapFrame:Hide(); F.LayoutWindows(true); assert(F.sellWindow:IsShown())
F.CloseManaged("seller"); WorldMapFrame:Show(); WorldMapFrame:Hide(); F.LayoutWindows(true)
assert(not F.sellWindow:IsShown() and not F.activeWindow,"Explicitly closed windows stay closed")
''')
random.seed(11)
started=time.perf_counter()
for _ in range(250):
 width=random.choice([1024,1280,1600,1920,2560]); height=random.choice([720,900,1080,1440])
 blocks=[dict(x=random.randrange(width),y=random.randrange(height),w=random.randrange(50,500),h=random.randrange(50,600)) for i in range(random.randrange(0,9))]
 obs=lua.table_from([lua.table_from(r) for r in blocks])
 plan=lua.globals().F.PlanWindow(width,height,548,600,obs)
 if plan:
  assert 15.9<=plan.x and plan.x+plan.w<=width-15.9 and 15.9<=plan.y and plan.y+plan.h<=height-15.9
  for b in blocks: assert not (plan.x<b['x']+b['w'] and b['x']<plan.x+plan.w and plan.y<b['y']+b['h'] and b['y']<plan.y+plan.h)
print(f'PASS: AH/bag docking, small screens, scaled native coordinates, exclusive windows, model return, compact rules, fullscreen suspension/restoration, explicit close; 250 crowded layouts in {time.perf_counter()-started:.3f}s')
