local _, F = ...
local window
local width, height = 700, 480

function F.BuildAtlas()
    local zones, names = {}, {}
    local function page(zone)
        if not F.IsText(zone) or zone == "" then return end
        if not zones[zone] then
            zones[zone] = {creatures={}, activity={}, stories={}, encounters=0}
            names[#names + 1] = zone
        end
        return zones[zone]
    end
    for _, creature in pairs(F.db.creatures) do
        local habitats, points, counts = {}, {}, {}
        for zone in pairs(creature.zones) do habitats[zone] = true end
        for _, encounter in ipairs(creature.history) do
            if F.IsText(encounter.zone) then
                habitats[encounter.zone] = true
                counts[encounter.zone] = (counts[encounter.zone] or 0) + 1
            end
        end
        for _, key in ipairs(F.Keys(creature.locations)) do
            local point = creature.locations[key]
            if F.IsText(point.zone) then
                habitats[point.zone] = true
                points[point.zone] = points[point.zone] or point
            end
        end
        for zone in pairs(habitats) do
            local entry = page(zone)
            if entry then
                entry.creatures[#entry.creatures + 1] = {record=creature, point=points[zone]}
                entry.encounters = entry.encounters + (counts[zone] or 0)
            end
        end
    end
    for zone, activity in pairs(F.GetAtlasActivity()) do page(zone).activity = activity end
    for _, story in ipairs(F.ListTales()) do
        local seen = {}
        for _, zone in ipairs(story.zones) do
            if not seen[zone] then
                local entry = page(zone)
                entry.stories[#entry.stories + 1] = story
                seen[zone] = true
            end
        end
    end
    local current = F.Safe(GetRealZoneText)
    page(current)
    table.sort(names)
    local tracked = F.TrackedCreatures()
    for _, entry in pairs(zones) do
        table.sort(entry.creatures, function(a, b)
            local left, right = a.record, b.record
            local leftTracked, rightTracked = tracked[left.id] == true, tracked[right.id] == true
            if leftTracked ~= rightTracked then return leftTracked end
            if left.favorite ~= right.favorite then return left.favorite end
            if left.name == right.name then return left.id < right.id end
            return left.name < right.name
        end)
    end
    return zones, names, current
end

local function label(parent, value, x, y, span, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(span)
    text:SetJustifyH("LEFT")
    text:SetText(value)
    return text
end

local function button(parent, title, x, y, span, action)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetPoint("TOPLEFT", x, y)
    control:SetSize(span, 24)
    control:SetText(title)
    control:SetScript("OnClick", action)
    return control
end

local function openCreature(record)
    F.CreateUI()
    F.selected = record.id
    if not F.readOnly then F.db.settings.selected = record.id end
    if F.ShowManaged("journal") then F.Render() end
end

local function render(reset)
    local w = window
    local page = w.zones[w.zone]
    local theme = F.GetCodexTheme()
    w.picker:SetChoice(w.zone or "Choose a zone")
    w.heading:SetText(w.zone or "Your Atlas")
    F.StyleCodexHeading(w.heading, theme)
    local rows = page and (w.stories and page.stories or page.creatures) or {}
    local query = w.search:GetText():lower():match("^%s*(.-)%s*$")
    if query ~= "" then
        local matches = {}
        for _, item in ipairs(rows) do
            local name = w.stories and item.title or item.record.name
            if name:lower():find(query, 1, true) then matches[#matches + 1] = item end
        end
        rows = matches
    end
    w.offset = reset and 0 or math.max(0, math.min(w.offset, #rows - #w.rows))
    w.summary:SetText(page and (string.format("%d creatures  |  %d recorded encounters  |  %d saved stories",
        #page.creatures, page.encounters, #page.stories)) or "Travel or discover creatures to fill these pages.")
    for i, control in ipairs(w.rows) do
        local item = rows[i + w.offset]
        control:SetShown(item ~= nil)
        if item then
            control.item, control.story = item, w.stories
            control:SetText(w.stories and item.title or item.record.name)
        end
    end
    local empty = query ~= "" and "No matches in this zone."
        or (w.stories and "No saved stories for this zone." or "No creatures recorded here yet.")
    w.range:SetText(#rows == 0 and empty
        or string.format("%d–%d of %d  |  Scroll to browse", w.offset + 1, math.min(w.offset + #w.rows, #rows), #rows))
    local lines = page and page.activity or {}
    w.activity:SetText(#lines > 0 and table.concat(lines, "\n\n") or "Recent loot, quests and notes appear here as you play.")
    w.activityBody:SetHeight(math.max(240, w.activity:GetStringHeight() + 12))
    if reset then w.scroll:SetVerticalScroll(0) end
    if w.stories then w.creatures:Enable(); w.storyTab:Disable()
    else w.creatures:Disable(); w.storyTab:Enable() end
    local first = page and page.creatures[1]
    local lead = first and F.TrackedCreatures()[first.record.id] and first.record.name
    w.lead:SetText(lead and ("Field lead: " .. lead .. " is on your tracking list.") or "")
    w.point = nil
    if page then
        for _, item in ipairs(page.creatures) do
            if item.point then w.point = item.point; break end
        end
    end
    w.map:SetShown(w.point ~= nil)
end

local function create()
    local w = CreateFrame("Frame", "ForeverCodexAtlas", UIParent, "BasicFrameTemplateWithInset")
    window = w
    w:SetSize(width, height)
    w.TitleText:SetText("Forever Codex - Atlas")
    if w.Inset then F.Safe(w.Inset.Hide, w.Inset) end
    local backdrop = w:CreateTexture(nil, "BACKGROUND", nil, 3)
    backdrop:SetPoint("TOPLEFT", 7, -27)
    backdrop:SetPoint("BOTTOMRIGHT", -7, 7)
    w.cover = backdrop
    F.RegisterWindow("atlas", w, width, height)
    tinsert(UISpecialFrames, "ForeverCodexAtlas")
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", function(self) if not F.Safe(InCombatLockdown) then self:StartMoving() end end)
    w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); F.SaveWindowPosition("atlas") end)
    w.picker = F.Dropdown(w, "Choose a zone", 16, -36, 210, function() return w.names end,
        function(zone) w.zone = zone; render(true) end)
    button(w, "Here", 232, -36, 60, function()
        if w.zones[w.current] then w.zone = w.current; render(true) end
    end)
    button(w, "Refresh", 298, -36, 78, function() F.OpenAtlas() end)
    button(w, "Gold planner", 382, -36, 120, function() F.OpenGoldPlanner() end)
    w.map = button(w, "Encounter map", 540, -36, 142, function()
        if w.point then F.OpenEncounterPoint(w.point) end
    end)
    w.heading = label(w, "", 18, -76, 645, "GameFontNormalHuge")
    w.summary = label(w, "", 18, -110, 645, "GameFontHighlightSmall")
    w.creatures = button(w, "Creatures", 17, -137, 127, function() w.stories = false; render(true) end)
    w.storyTab = button(w, "Stories", 147, -137, 127, function() w.stories = true; render(true) end)
    w.search = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
    w.search:SetPoint("TOPLEFT", 70, -167)
    w.search:SetSize(201, 23)
    w.search:SetAutoFocus(false)
    w.search:SetMaxLetters(80)
    label(w, "Search", 19, -172, 48, "GameFontHighlightSmall")
    w.search:SetScript("OnTextChanged", function() if w.zones then render(true) end end)
    w.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    w:SetScript("OnHide", function() w.search:ClearFocus(); F.ManagedHidden("atlas") end)
    local list = CreateFrame("Frame", nil, w)
    list:SetPoint("TOPLEFT", 17, -198)
    list:SetSize(257, 203)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) w.offset = w.offset - delta; render(false) end)
    w.rows, w.offset = {}, 0
    for i = 1, 7 do
        w.rows[i] = button(list, "", 0, -(i - 1) * 29, 255, function(self)
            if self.story then F.OpenTales(self.item.id) else openCreature(self.item.record) end
        end)
    end
    w.range = label(w, "", 19, -408, 255, "GameFontHighlightSmall")
    w.lead = label(w, "", 186, -448, 495, "GameFontNormalSmall")
    label(w, "Recent activity in this zone", 304, -144, 360, "GameFontNormal")
    w.scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
    w.scroll:SetPoint("TOPLEFT", 304, -173)
    w.scroll:SetSize(350, 242); F.AddScrollCue(w.scroll)
    w.activityBody = CreateFrame("Frame", nil, w.scroll)
    w.activityBody:SetSize(350, 242)
    w.scroll:SetScrollChild(w.activityBody)
    w.activity = label(w.activityBody, "", 0, 0, 343, "GameFontHighlightSmall")
    button(w, "Back to Bestiary", 16, -441, 155, function()
        F.CreateUI()
        if F.ShowManaged("journal") then F.Render() end
    end)
    w:Hide()
end

function F.OpenAtlas()
    if not F.db or F.Safe(InCombatLockdown) then return end
    if not window then create() end
    local w = window
    w.zones, w.names, w.current = F.BuildAtlas()
    if not w.zones[w.zone] then w.zone = w.zones[w.current] and w.current or w.names[1] end
    local theme = F.GetCodexTheme()
    w.cover:SetColorTexture(theme.cover[1], theme.cover[2], theme.cover[3], .98)
    F.StyleCodexHeading(w.TitleText, theme)
    F.Safe(w.activity.SetTextColor, w.activity, unpack(theme.text))
    render(true)
    F.ShowManaged("atlas")
end
