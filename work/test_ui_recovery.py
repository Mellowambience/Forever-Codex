import runpy

lua = runpy.run_path("work/test_release.py")["lua"]
lua.execute("""
local model, events, overview
for _, frame in ipairs(frames) do
    if frame.kind == "PlayerModel" then model = frame end
    if frame.events.PLAYER_REGEN_DISABLED then events = frame end
    if frame.text == "Overview" and frame.scripts.OnClick then overview = frame end
end
assert(model and events and overview)

F.ShowManaged("journal")
F.selected = 123
local record = F.db.creatures[123]
record.damageMin, record.damageMax = 4, nil
overview.scripts.OnClick()

local getWidth = model.GetWidth
model.GetWidth = function() return nil end
F.FitModel(model)
assert(model.cameraDistance > 0, "Unresolved model geometry needs a safe camera")
model.GetWidth = getWidth

local setUnit = model.SetUnit
model.SetUnit = function() return false end
F.PreviewTarget()
assert(not model.preview and not model.previewNPC, "Rejected previews must not capture an appearance")
model.SetUnit = setUnit

local getCenter = Minimap.GetCenter
local angle = F.db.settings.angle
Minimap.GetCenter = function() return nil, nil end
F.minimap.scripts.OnDragStart(F.minimap)
F.minimap.scripts.OnUpdate(F.minimap)
F.minimap.scripts.OnDragStop(F.minimap)
assert(F.db.settings.angle == angle, "Missing minimap geometry must preserve the saved angle")
Minimap.GetCenter = getCenter

-- Reproduce the native Hide callback when combat dismisses a visible window.
for _, frame in ipairs({F.window, F.expanded}) do
    function frame:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
end
F.ToggleExpandedViewer()
assert(F.expanded:IsShown() and model.inExpanded)
local parentChanges = 0
model.SetParent = function() parentChanges = parentChanges + 1 end
InCombatLockdown = function() return true end
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
assert(not F.window:IsShown() and not F.expanded:IsShown() and not F.activeWindow)
assert(parentChanges == 0 and model.inExpanded, "Combat close must defer model reparenting")
assert(not F.ShowManaged("journal") and not F.window:IsShown(), "Combat must not reopen a closed panel")
InCombatLockdown = function() return false end
F.LayoutWindows(true)
assert(not F.activeWindow and not F.window:IsShown(), "Leaving combat must not reopen the journal")
F.ShowManaged("journal")
assert(F.window:IsShown() and not model.inExpanded and parentChanges == 1, "Next open restores the journal model")

-- Closing the viewer through its usual hide callback also works in combat.
F.ToggleExpandedViewer()
InCombatLockdown = function() return true end
F.expanded:Hide()
assert(not F.activeWindow and not F.window:IsShown(), "Viewer close must not open the journal during combat")

-- A user can place the journal over a native panel. The drag stop and watcher
-- must leave the engine's anchors intact until a screen size change.
InCombatLockdown = function() return false end
AuctionHouseFrame = CreateFrame("Frame")
AuctionHouseFrame.GetLeft = function() return 0 end
AuctionHouseFrame.GetRight = function() return 600 end
AuctionHouseFrame.GetBottom = function() return 0 end
AuctionHouseFrame.GetTop = function() return 900 end
F.ShowManaged("journal")
local window = F.window
local anchorChanges = 0
window.SetPoint = function(self, ...) self.point = {...}; anchorChanges = anchorChanges + 1 end
window.SetScale = function(self, scale) self.scale = scale end
window.GetLeft = function() return 220 end
window.GetRight = function(self) return 220 + self.width end
window.GetBottom = function() return 60 end
window.GetTop = function(self) return 60 + self.height end
window.scripts.OnDragStop(window)
assert(F.db.settings.position.x == -110)
F.LayoutWindows()
assert(anchorChanges == 0, "Docking must not run after a manual drag")

F.CloseManaged("journal")
F.ShowManaged("journal")
assert(window.point[4] == 220 and window.point[5] == 60 + window.height, "Reopen at the saved position")

local originalWidth, originalHeight = UIParent.GetWidth, UIParent.GetHeight
UIParent.GetWidth = function() return 700 end
UIParent.GetHeight = function() return 600 end
F.LayoutWindows()
local x, top = window.point[4] * window.scale, window.point[5] * window.scale
assert(x >= 0 and x + window.width * window.scale <= 700.01)
assert(top <= 600.01 and top - window.height * window.scale >= -0.01)
UIParent.GetWidth, UIParent.GetHeight = originalWidth, originalHeight

SlashCmdList.FOREVERBESTIARY("resetpos")
assert(F.db.settings.position == nil and window.point[4] >= 612, "Reset restores automatic docking")
""")
print("PASS: incomplete damage, unresolved model/minimap geometry, rejected preview, combat dismissal/reopen, and manual window drag/reset")
