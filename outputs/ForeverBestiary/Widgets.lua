local _, F = ...
local serial=0
function F.AddScrollCue(scroll, above)
    local cue=scroll:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    if above then cue:SetPoint("BOTTOMRIGHT",scroll,"TOPRIGHT",0,1)
    else cue:SetPoint("BOTTOMRIGHT",scroll,"BOTTOMRIGHT",0,-13) end
    cue:SetText("Scroll for more")
    cue:Hide()
    local function update(self)
        local range=F.Safe(self.GetVerticalScrollRange,self)
        local offset=F.Safe(self.GetVerticalScroll,self) or 0
        cue:SetShown(F.IsNumber(range) and range>1)
        cue:SetText(F.IsNumber(offset) and offset>1 and "Scroll to browse" or "Scroll for more")
    end
    if scroll.HookScript then
        scroll:HookScript("OnScrollRangeChanged",update)
        scroll:HookScript("OnVerticalScroll",update)
        scroll:HookScript("OnShow",update)
    end
    update(scroll)
end
function F.Dropdown(parent,initial,x,y,width,provider,onChange)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(width,25); b:SetPoint("TOPLEFT",x,y); b:SetText(initial.."  v"); b.value=initial
    b.SetChoice=function(self,v) self.value=v; self:SetText(v.."  v") end
    b:SetScript("OnClick",function(self)
        if self.popup and self.popup:IsShown() then self.popup:Hide(); return end
        if F.activeDropdown then F.activeDropdown:Hide() end
        if not self.popup then
            serial=serial+1; local p=CreateFrame("Frame","ForeverBestiaryDropdown"..serial,UIParent)
            p:SetFrameStrata("DIALOG"); p:SetSize(width+20,280); p:SetClampedToScreen(true); p:EnableMouse(true)
            local bg=p:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.05,.075,.06,.99)
            p.cue=p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            p.cue:SetPoint("BOTTOM",0,7)
            p.rows={}; p.offset=0; p:EnableMouseWheel(true); tinsert(UISpecialFrames,"ForeverBestiaryDropdown"..serial)
            p:SetScript("OnUpdate",function(self)
                if type(MouseIsOver)=="function" and (F.Safe(IsMouseButtonDown,"LeftButton") or F.Safe(IsMouseButtonDown,"RightButton")) and not F.Safe(MouseIsOver,self) and not F.Safe(MouseIsOver,self.owner) then self:Hide() end
            end)
            p:SetScript("OnMouseWheel",function(_,delta) p.offset=math.max(0,math.min(math.max(0,#p.options-10),p.offset-delta)); p:Draw() end)
            function p:Draw()
                self.cue:SetShown(#self.options>10)
                if #self.options>10 then
                    self.cue:SetText(("%d–%d of %d · Scroll to browse"):format(self.offset+1,self.offset+10,#self.options))
                end
                for i=1,10 do
                    local row=self.rows[i]
                    if not row then row=CreateFrame("Button",nil,p,"UIPanelButtonTemplate"); row:SetSize(width+12,24); row:SetPoint("TOPLEFT",4,-4-(i-1)*26); self.rows[i]=row end
                    local option=self.options[self.offset+i]; row:SetShown(option~=nil)
                    if option then
                        row.option=option
                        local title=self.owner.FormatOption and self.owner:FormatOption(option) or option
                        row:SetText(title)
                        row:SetScript("OnClick",function(item) self.owner:SetChoice(item.option); self:Hide(); onChange(item.option) end)
                        if self.owner.value==option then row:SetText("> "..title) end
                    end
                end
            end
            self.popup=p
        end
        local p=self.popup; p.owner=self; p.options=provider(); p.offset=0; p:ClearAllPoints(); p:SetPoint("TOPLEFT",self,"BOTTOMLEFT",0,-2); p:SetHeight(math.min(10,#p.options)*26+(#p.options>10 and 25 or 8)); p:Draw(); p:Show(); F.activeDropdown=p
    end)
    return b
end
function F.HideDropdowns()
    local popup=F.activeDropdown
    F.activeDropdown=nil
    if popup then F.Safe(popup.Hide,popup) end
end
