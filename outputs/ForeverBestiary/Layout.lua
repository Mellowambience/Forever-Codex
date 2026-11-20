local _, F = ...
local windows={}
local nativeNames={"AuctionHouseFrame","AuctionFrame","TradeSkillFrame","CraftFrame","ProfessionsFrame","MerchantFrame","CharacterFrame","SpellBookFrame","PlayerSpellsFrame","QuestLogFrame","QuestMapFrame","WorldMapFrame","BankFrame","BankPanel","MailFrame","FriendsFrame","GossipFrame","QuestFrame","DressUpFrame","ItemRefTooltip","ContainerFrameCombinedBags"}
local function shown(frame) return frame and F.Safe(frame.IsShown,frame)==true end
local function overlaps(a,b) return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h end
F.RectsOverlap=overlaps
-- Find a readable placement in the remaining screen area. Native frames are never moved.
function F.PlanWindow(width,height,frameWidth,frameHeight,obstacles,preferred)
    local margin,gap=16,12
    local free={{x=margin,y=margin,w=width-2*margin,h=height-2*margin}}
    for _,o in ipairs(obstacles or {}) do
        local block={x=o.x-gap,y=o.y-gap,w=o.w+2*gap,h=o.h+2*gap}; local nextFree={}
        for _,r in ipairs(free) do
            if not overlaps(r,block) then nextFree[#nextFree+1]=r else
                local left,right=math.max(r.x,block.x),math.min(r.x+r.w,block.x+block.w)
                local bottom,top=math.max(r.y,block.y),math.min(r.y+r.h,block.y+block.h)
                local pieces={{x=r.x,y=r.y,w=left-r.x,h=r.h},{x=right,y=r.y,w=r.x+r.w-right,h=r.h},{x=r.x,y=r.y,w=r.w,h=bottom-r.y},{x=r.x,y=top,w=r.w,h=r.y+r.h-top}}
                for _,p in ipairs(pieces) do if p.w>1 and p.h>1 then nextFree[#nextFree+1]=p end end
            end
        end
        -- Remove contained rectangles to keep crowded inventories bounded.
        free={}
        for i,r in ipairs(nextFree) do
            local contained=false
            for j,p in ipairs(nextFree) do if i~=j and r.x>=p.x and r.y>=p.y and r.x+r.w<=p.x+p.w and r.y+r.h<=p.y+p.h and (r.w*r.h<p.w*p.h or i>j) then contained=true; break end end
            if not contained then free[#free+1]=r end
        end
    end
    local best,score
    for _,r in ipairs(free) do
        local scale=math.min(1,r.w/frameWidth,r.h/frameHeight)
        -- A smaller screen may need scaling, but occupied screens should not force tiny text.
        local minimum=math.min(.82,(width-32)/frameWidth,(height-32)/frameHeight)
        if scale>=minimum and scale>0 then
            local w,h=frameWidth*scale,frameHeight*scale
            local cx=preferred and preferred.x or width/2; local cy=preferred and preferred.y or height/2
            local x=math.max(r.x,math.min(r.x+r.w-w,cx-w/2)); local y=math.max(r.y,math.min(r.y+r.h-h,cy-h/2))
            local value=scale*100000-((x+w/2-cx)^2+(y+h/2-cy)^2)/math.max(1,width*height)*100
            if not score or value>score then best={x=x,y=y,w=w,h=h,scale=scale}; score=value end
        end
    end
    return best
end
function F.FrameRect(frame)
    if not shown(frame) then return end
    local left=F.Safe(frame.GetLeft,frame); local right=F.Safe(frame.GetRight,frame)
    local top=F.Safe(frame.GetTop,frame); local bottom=F.Safe(frame.GetBottom,frame)
    local scale=F.Safe(frame.GetEffectiveScale,frame); local root=F.Safe(UIParent.GetEffectiveScale,UIParent)
    if not F.IsNumber(left) or not F.IsNumber(right) or not F.IsNumber(top) or not F.IsNumber(bottom) or not F.IsNumber(scale) or not F.IsNumber(root) or scale<=0 or root<=0 then return end
    local ratio=scale/root
    if right>left and top>bottom then return {x=left*ratio,y=bottom*ratio,w=(right-left)*ratio,h=(top-bottom)*ratio} end
end
local function obstacles()
    local rects,seen={},{}
    local function add(frame)
        if not frame or seen[frame] then return end; seen[frame]=true
        local r=F.FrameRect(frame); if r then rects[#rects+1]=r end
    end
    for _,name in ipairs(nativeNames) do add(_G[name]) end
    for i=1,13 do add(_G["ContainerFrame"..i]) end
    return rects
end
function F.RegisterWindow(name,frame,width,height)
    windows[name]={frame=frame,width=width,height=height}
    frame:SetFrameStrata("MEDIUM"); frame:SetClampedToScreen(true)
end
local function screenSize()
    local width,height=F.Safe(UIParent.GetWidth,UIParent),F.Safe(UIParent.GetHeight,UIParent)
    if F.IsNumber(width) and F.IsNumber(height) and width>32 and height>32 then return width,height end
end
local function manualSignature(name,width,height)
    return name..":"..width..":"..height..":manual"
end
function F.SaveWindowPosition(name)
    local entry=windows[name]
    local rect=entry and F.FrameRect(entry.frame)
    local width,height=screenSize()
    if not rect or not width then return end
    local position={x=rect.x+rect.w/2-width/2,y=rect.y+rect.h/2-height/2,scale=rect.w/entry.width}
    if name=="journal" and not F.readOnly then
        F.db.settings.position=position
    else
        entry.manualPosition=position
    end
    -- Keep the native drag result and skip docking at the next layout tick.
    if F.activeWindow==name then F.layoutSignature=manualSignature(name,width,height) end
end
function F.ResetWindowPosition(name)
    local entry=windows[name]
    if entry then entry.manualPosition=nil end
    if name=="journal" then F.db.settings.position=nil end
    if F.activeWindow==name then F.LayoutWindows(true) end
end
local function planManualWindow(width,height,entry,position)
    local scale=math.min(position.scale or 1,width/entry.width,height/entry.height)
    local w,h=entry.width*scale,entry.height*scale
    local x=math.max(0,math.min(width-w,(width-w)/2+position.x))
    local y=math.max(0,math.min(height-h,(height-h)/2+position.y))
    return {x=x,y=y,scale=scale}
end
function F.ManagedHidden(name)
    if F.switchingWindows or F.activeWindow~=name then return end
    F.activeWindow=nil; F.layoutSignature=nil
    if name=="viewer" and F.window and not F.Safe(InCombatLockdown) then
        if F.ShowManaged("journal") then F.Render() end
    end
end
function F.LayoutWindows(force)
    local entry=windows[F.activeWindow]; if not entry then return end
    if F.Safe(InCombatLockdown) then F.CloseForCombat(); return end
    if entry.frame.codexDragging then return end
    local width,height=screenSize()
    if not width then return end
    local position=entry.manualPosition
    if F.activeWindow=="journal" then
        position=(F.readOnly and position) or F.db.settings.position
    end
    local occupied,signature
    if position then
        signature=manualSignature(F.activeWindow,width,height)
    else
        occupied=obstacles()
        signature=F.activeWindow..":"..width..":"..height
        for _,r in ipairs(occupied) do signature=signature..string.format(":%.1f,%.1f,%.1f,%.1f",r.x,r.y,r.w,r.h) end
    end
    if not force and F.layoutSignature==signature then return end
    F.layoutSignature=signature; F.HideDropdowns()
    local preferred
    if not position and F.activeWindow=="seller" and F.auctionOpen then
        local ah=F.FrameRect(AuctionHouseFrame) or F.FrameRect(AuctionFrame)
        if ah then preferred={x=ah.x+ah.w+12+entry.width/2,y=ah.y+ah.h-entry.height/2} end
    end
    local plan=position and planManualWindow(width,height,entry,position)
        or F.PlanWindow(width,height,entry.width,entry.height,occupied,preferred)
    F.switchingWindows=true
    if plan then
        entry.frame:SetScale(plan.scale); entry.frame:ClearAllPoints()
        entry.frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",plan.x/plan.scale,plan.y/plan.scale+entry.height)
        entry.frame:Show(); entry.suspended=nil
    else
        F.layoutSuspending=true; entry.frame:Hide(); F.layoutSuspending=nil
        if not entry.suspended then F.Message("Bestiary tucked away while other windows fill the screen. It returns when there is room.") end
        entry.suspended=true
    end
    F.switchingWindows=nil
end
function F.ShowManaged(name)
    if not windows[name] then return false end
    if F.Safe(InCombatLockdown) then
        F.Message("Open this Codex window after combat.")
        return false
    end
    F.switchingWindows=true; F.HideDropdowns()
    if name~="viewer" and F.RestoreJournalModel then F.RestoreJournalModel() end
    for other,entry in pairs(windows) do if other~=name then entry.frame:Hide() end end
    F.switchingWindows=nil; F.activeWindow=name; F.LayoutWindows(true)
    return true
end
function F.CloseManaged(name)
    local entry=windows[name]; if not entry then return end
    if F.activeWindow==name then F.activeWindow=nil end
    F.switchingWindows=true; entry.frame:Hide(); F.switchingWindows=nil; F.HideDropdowns(); F.layoutSignature=nil
end
function F.CloseForCombat()
    -- Clear the requested window first so hide callbacks cannot reopen the journal
    -- and the layout watcher cannot restore a suspended panel.
    F.activeWindow=nil
    F.layoutSignature=nil
    F.switchingWindows=true
    F.HideDropdowns()
    for _,entry in pairs(windows) do
        entry.suspended=nil
        if shown(entry.frame) then F.Safe(entry.frame.Hide,entry.frame) end
    end
    F.switchingWindows=nil
end
function F.StartWindowLayout()
    if F.layoutWatcher then return end
    local watcher=CreateFrame("Frame"); F.layoutWatcher=watcher; local elapsed=0
    watcher:SetScript("OnUpdate",function(_,dt)
        if not F.activeWindow then return end
        elapsed=elapsed+dt; if elapsed<.25 then return end; elapsed=0
        -- Do not interrupt title-bar dragging with automatic placement.
        if F.Safe(IsMouseButtonDown,"LeftButton") then return end
        F.LayoutWindows()
    end)
end
