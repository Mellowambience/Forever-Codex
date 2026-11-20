local _, F = ...
local MIN_DISTANCE, MAX_DISTANCE = .15, 18
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
function F.ModelFitScale(width,height)
    -- Creature cameras are authored for a taller viewport. Add breathing room
    -- for this wide journal panel, including wings and idle animation.
    width=F.IsNumber(width) and width or 0
    height=F.IsNumber(height) and height or 0
    if width<=0 or height<=0 then return 1.5 end
    return clamp(math.max(1.3,width/math.max(1,height))*1.15,1.3,8)
end
local function fitDistance(model)
    return F.ModelFitScale(F.Safe(model.GetWidth,model),F.Safe(model.GetHeight,model))
end
local function savedViews()
    F.db.settings.modelViews=F.db.settings.modelViews or {}
    return F.db.settings.modelViews
end
local function saveView(m)
    if m.recordID and not F.readOnly then savedViews()[m.recordID]={distance=m.cameraDistance,pan=m.cameraPan or 0,ratio=m.cameraDistance/(m.fitDistance or m.cameraDistance)} end
end
function F.ApplyModelCamera(m)
    if not m.cameraDistance then return end
    F.Safe(m.SetCamDistanceScale,m,m.cameraDistance)
    F.Safe(m.SetPosition,m,0,0,m.cameraPan or 0)
    if m.zoomLabel then m.zoomLabel:SetText(string.format("%d%%",math.floor((m.fitDistance or m.cameraDistance)/m.cameraDistance*100+.5))) end
end
function F.FitModel(m)
    m.fitDistance=fitDistance(m)
    m.cameraDistance=m.fitDistance; m.cameraPan=0
    F.Safe(m.SetPortraitZoom,m,0)
    F.Safe(m.SetFacing,m,.5)
    F.ApplyModelCamera(m); saveView(m)
end
function F.InitModelCamera(m)
    m.fitDistance=fitDistance(m)
    local view=m.recordID and savedViews()[m.recordID]
    if type(view)=="table" and F.IsNumber(view.distance) then
        m.cameraDistance=clamp(F.IsNumber(view.ratio) and m.fitDistance*view.ratio or view.distance,MIN_DISTANCE,MAX_DISTANCE)
        m.cameraPan=F.IsNumber(view.pan) and clamp(view.pan,-20,20) or 0
        F.Safe(m.SetPortraitZoom,m,0)
        F.ApplyModelCamera(m)
    else F.FitModel(m) end
end
function F.ResizeModelCamera(m)
    local ratio=(m.cameraDistance or 1)/(m.fitDistance or 1)
    m.fitDistance=fitDistance(m)
    m.cameraDistance=clamp(m.fitDistance*ratio,MIN_DISTANCE,MAX_DISTANCE)
    F.ApplyModelCamera(m); saveView(m)
end
function F.ZoomModel(m,delta)
    if not m.cameraDistance then F.InitModelCamera(m) end
    m.cameraDistance=clamp(m.cameraDistance*.82^delta,MIN_DISTANCE,MAX_DISTANCE)
    F.ApplyModelCamera(m); saveView(m)
end
function F.PanModel(m,pixels)
    m.cameraPan=clamp((m.cameraPan or 0)+pixels*(m.cameraDistance or 1)/350,-20,20)
    F.ApplyModelCamera(m); saveView(m)
end
