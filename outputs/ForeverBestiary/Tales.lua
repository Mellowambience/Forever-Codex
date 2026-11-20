local _, F = ...
local eventLimit, archiveLimit = 256, 100
local taleLimit, recordLimit = 8192, 24576
local windowSeconds = 24 * 60 * 60
local schema = 3
local eventTypes = {zone=true, discover=true, encounter=true, loot=true, note=true, quest=true}
local credits = {personal=true, group=true, unknown=true}
local state
local session = {discover=0, encounter=0, quest=0, loot=0, note=0}

function F.TodaySession()
    local result = {}
    for key, value in pairs(session) do result[key] = value end
    return result
end

local function clean(value, limit, multiline)
    if not F.IsText(value) then return end
    value = value:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("|", ""):gsub("\r\n", "\n")
    if multiline then
        value = value:gsub("[%z\1-\8\11-\31\127]", " ")
    else
        value = value:gsub("%c", " ")
    end
    value = value:match("^%s*(.-)%s*$")
    if #value > limit then
        while limit > 0 do
            local byte = value:byte(limit + 1)
            if byte < 128 or byte >= 192 then break end
            limit = limit - 1
        end
        value = value:sub(1, limit)
    end
    if value ~= "" then return value end
end

local function normalizeEvent(entry)
    if type(entry) ~= "table" or not F.IsText(entry.kind) or not eventTypes[entry.kind] then return end
    if not F.IsNumber(entry.time) or entry.time < 0 or entry.time > 4102444800 then return end
    local name = clean(entry.name, 160)
    local note = clean(entry.text, 500)
    local id = F.ValidID(entry.id)
    if entry.kind == "quest" and not id then return end
    if entry.kind == "note" then
        if not note then return end
    elseif not name then return end
    return {
        kind = entry.kind,
        name = name,
        zone = clean(entry.zone, 160),
        text = note,
        time = entry.time,
        credit = F.IsText(entry.credit) and credits[entry.credit] and entry.credit or nil,
        quantity = F.IsNumber(entry.quantity) and math.max(1, math.min(1000000, math.floor(entry.quantity))) or nil,
        id = id,
        recovered = entry.recovered == true or nil,
    }
end

local function normalizeTale(tale)
    if type(tale) ~= "table" then return end
    local zones = {}
    if type(tale.zones) == "table" then
        for i = 1, math.min(#tale.zones, 60) do
            local zone = clean(tale.zones[i], 160)
            if zone then zones[#zones + 1] = zone end
        end
    end
    return {
        id = F.ValidID(tale.id),
        title = clean(tale.title, 120) or "Campfire tale",
        text = clean(tale.text, taleLimit, true) or "",
        record = clean(tale.record, recordLimit, true) or "",
        savedAt = F.IsNumber(tale.savedAt) and tale.savedAt or 0,
        zones = zones,
    }
end

function F.LoadTales()
    local raw = ForeverCodexTales
    if type(raw) == "table" and F.IsNumber(raw.version) and raw.version > schema then
        state = nil
        return
    end
    raw = type(raw) == "table" and raw or {}
    state = {version=schema, events={}, archive={}, nextID=F.ValidID(raw.nextID) or 1,
        lastZone=clean(raw.lastZone, 160), recoveredHistory=raw.recoveredHistory == true}
    if type(raw.events) == "table" then
        for i = math.max(1, #raw.events - eventLimit + 1), #raw.events do
            local entry = normalizeEvent(raw.events[i])
            if entry then state.events[#state.events + 1] = entry end
        end
    end
    if type(raw.archive) == "table" then
        for _, entry in ipairs(raw.archive) do
            local tale = normalizeTale(entry)
            if tale and tale.id then
                state.archive[#state.archive + 1] = tale
                state.nextID = math.max(state.nextID, tale.id + 1)
            end
        end
    end
    state.draft = normalizeTale(raw.draft)
    ForeverCodexTales = state
end

function F.TalesWritable()
    return state ~= nil
end

local function refreshRecord()
    if F.RefreshTaleRecordView then F.SupportCall("Live tale record", F.RefreshTaleRecordView) end
end

local function exclusiveHistory(record, character)
    if record.kills <= 0 or record.kills >= 1000000000 or record.characters[character] ~= record.kills then
        return false
    end
    for key, kills in pairs(record.characters) do
        if key ~= character and kills > 0 then return false end
    end
    return true
end

function F.RecoverTaleEncounters()
    if not state or state.recoveredHistory or F.readOnly then return end
    local name, realm = F.Safe(UnitName, "player"), F.Safe(GetRealmName)
    if not F.IsText(name) or name == "" or not F.IsText(realm) or realm == "" then return end
    local character = name .. "-" .. realm
    local events, discoveries, recovered = {}, {}, {}
    local now = time()
    for _, entry in ipairs(state.events) do
        if entry.time >= now - windowSeconds then
            events[#events + 1] = entry
            if entry.kind == "discover" then
                local key = (entry.id or entry.name) .. "\n" .. entry.time
                discoveries[key] = (discoveries[key] or 0) + 1
            end
        end
    end
    local room = eventLimit - #events
    local function newest(a, b)
        if a.time == b.time then return a.id < b.id end
        return a.time > b.time
    end
    local function keepLatest()
        table.sort(recovered, newest)
        for i = #recovered, room + 1, -1 do recovered[i] = nil end
    end
    if room > 0 then
        for id, record in pairs(F.db.creatures) do
            if exclusiveHistory(record, character) then
                local creature = clean(record.name, 160)
                for _, hit in ipairs(record.history) do
                    if creature and hit.time >= now - windowSeconds and hit.time <= now then
                        local duplicate
                        if record.first and math.abs(hit.time - record.first) <= 1 then
                            for offset = -1, 1 do
                                local stamp = "\n" .. (hit.time + offset)
                                if (discoveries[id .. stamp] or 0) > 0 then duplicate = id .. stamp; break end
                                if (discoveries[creature .. stamp] or 0) > 0 then duplicate = creature .. stamp; break end
                            end
                        end
                        if duplicate then
                            discoveries[duplicate] = discoveries[duplicate] - 1
                        else
                            recovered[#recovered + 1] = normalizeEvent({kind="encounter", name=creature, id=id,
                                time=hit.time, zone=hit.zone, credit="unknown", recovered=true})
                            if #recovered >= eventLimit * 2 then keepLatest() end
                        end
                    end
                end
            end
        end
        keepLatest()
    end
    if #recovered > 0 then
        local ordered, live = {}, 1
        for i = #recovered, 1, -1 do
            local entry = recovered[i]
            while events[live] and events[live].time <= entry.time do
                ordered[#ordered + 1] = events[live]
                live = live + 1
            end
            ordered[#ordered + 1] = entry
        end
        for i = live, #events do ordered[#ordered + 1] = events[i] end
        events = ordered
    end
    state.events = events
    state.recoveredHistory = true
    refreshRecord()
end

local function addEvent(entry)
    if not state then return false end
    entry = normalizeEvent(entry)
    if not entry then return false end
    if session[entry.kind] then session[entry.kind] = session[entry.kind] + (entry.quantity or 1) end
    local events = state.events
    local last = events[#events]
    if (entry.kind == "loot" or entry.kind == "encounter") and last and not last.recovered
        and last.kind == entry.kind and last.name == entry.name and last.zone == entry.zone
        and last.credit == entry.credit and last.id == entry.id
        and entry.time >= last.time and entry.time - last.time <= 120 then
        last.quantity = math.min(1000000, (last.quantity or 1) + (entry.quantity or 1))
        last.time = entry.time
    else
        if #events >= eventLimit then
            local remove = 1
            if events[1].time >= entry.time - windowSeconds then
                for i, previous in ipairs(events) do
                    if previous.recovered or previous.kind == "loot" or previous.kind == "encounter" then remove = i; break end
                end
            end
            table.remove(events, remove)
        end
        events[#events + 1] = entry
    end
    refreshRecord()
    return true
end

local function currentZone()
    return clean(F.Safe(GetRealZoneText), 160)
end

function F.RecordTaleZone()
    if not state then return end
    local zone = currentZone()
    if zone and zone ~= state.lastZone and addEvent({kind="zone", name=zone, time=time()}) then
        state.lastZone = zone
    end
end

function F.RecordTaleEncounter(record, attacker, firstDiscovery)
    if not state then return end
    local credit = "unknown"
    if F.IsText(attacker) then
        if attacker == F.Safe(UnitGUID, "player") or attacker == F.Safe(UnitGUID, "pet") then
            credit = "personal"
        elseif F.db and F.db.settings.group then
            credit = "group"
        end
    end
    addEvent({kind=firstDiscovery and "discover" or "encounter", id=record.id,
        name=record.name, zone=currentZone(), credit=credit, time=record.last})
end

function F.RecordTaleQuestTurnIn(questID)
    if not state or not F.IsNumber(questID) then return end
    local id = F.ValidID(questID)
    if not id then return end
    local now = time()
    -- The event carries no unique turn-in token. Only suppress an exact same-second repeat.
    for _, entry in ipairs(state.events) do
        if entry.kind == "quest" and entry.id == id and entry.time == now then return end
    end
    local title = clean(F.Safe(C_QuestLog and C_QuestLog.GetTitleForQuestID, id), 160)
    return addEvent({kind="quest", id=id, name=title or ("Quest " .. id), zone=currentZone(), time=now})
end

function F.RecordTaleLoot(itemID, link, quantity)
    if not state then return end
    local name = F.IsText(link) and link:match("|h%[([^%]]+)%]|h") or nil
    if not name then name = "Item " .. itemID end
    addEvent({kind="loot", name=name, quantity=quantity, zone=currentZone(), time=time()})
end

function F.AddTaleNote(note)
    return addEvent({kind="note", text=note, zone=currentZone(), time=time()})
end

local function recordLine(entry)
    local timestamp = F.Safe(date, "%b %d %H:%M", entry.time) or "--:--"
    local zone = entry.zone and (" in " .. entry.zone) or ""
    local detail
    if entry.kind == "zone" then
        detail = "Entered " .. entry.name
    elseif entry.kind == "discover" or entry.kind == "encounter" then
        local credit = entry.credit == "personal" and "personal or pet credit"
            or entry.credit == "group" and "group credit" or "credit unavailable"
        local count = entry.quantity and entry.quantity > 1 and (" x" .. entry.quantity) or ""
        detail = (entry.kind == "discover" and "Discovered " or "Encountered ") .. entry.name .. count .. zone
            .. (entry.recovered and " (recovered from Bestiary)" or (" (" .. credit .. ")"))
    elseif entry.kind == "loot" then
        detail = "Received " .. entry.name .. " x" .. (entry.quantity or 1) .. zone
    elseif entry.kind == "quest" then
        detail = "Turned in " .. entry.name .. zone
    else
        detail = "Field note" .. zone .. ": " .. entry.text
    end
    return timestamp .. "  " .. detail
end

local function recentRecord(now)
    local events, lines = {}, {}
    local heading = "Recent events from the last 24 hours"
    local bytes = #heading
    for i = #state.events, 1, -1 do
        local entry = state.events[i]
        if entry.time >= now - windowSeconds and entry.time <= now then
            local line = recordLine(entry)
            if #events >= 60 or bytes + #line + 1 > recordLimit then break end
            table.insert(events, 1, entry)
            table.insert(lines, 1, line)
            bytes = bytes + #line + 1
        end
    end
    return events, heading .. "\n" .. table.concat(lines, "\n")
end

local noRecent = "No recent events yet. Travel, find loot, turn in a quest, or add a field note."

function F.GetAtlasActivity()
    if not state then return {} end
    local events = recentRecord(time())
    local activity = {}
    for _, event in ipairs(events) do
        local zone = event.kind == "zone" and event.name or event.zone
        if zone then
            activity[zone] = activity[zone] or {}
            table.insert(activity[zone], 1, recordLine(event))
        end
    end
    return activity
end

function F.GetRecentTaleRecord()
    if not state then return "Campfire Tales data needs a newer version of the Codex.", 0 end
    local events, record = recentRecord(time())
    return #events > 0 and record or noRecent, #events
end

local function identityToken(api)
    local ok, _, token = pcall(api, "player")
    if ok and F.IsText(token) then return token end
end

function F.GenerateTale()
    if not state then return nil, "Campfire Tales data needs a newer version of the Codex." end
    local now = time()
    local events, record = recentRecord(now)
    if #events == 0 then return nil, noRecent end
    local title = "Campfire tale"
    local day = F.Safe(date, "%B %d", now)
    if F.IsText(day) then title = title .. " - " .. day end
    local story = F.WriteTale(events, identityToken(UnitClass), identityToken(UnitRace))
    local zones, seen = {}, {}
    for _, event in ipairs(events) do
        local zone = event.kind == "zone" and event.name or event.zone
        if zone and not seen[zone] then zones[#zones + 1] = zone; seen[zone] = true end
    end
    return normalizeTale({title=title, text=story, record=record, zones=zones})
end

function F.TaleExcerpts(story)
    local passages = {}
    story = clean(story, taleLimit, true)
    if not story then return passages end
    for paragraph in story:gmatch("[^\n]+") do
        local remaining = paragraph:match("^%s*(.-)%s*$")
        while #remaining > 220 do
            local boundary = 220
            while remaining:byte(boundary + 1) >= 128 and remaining:byte(boundary + 1) < 192 do
                boundary = boundary - 1
            end
            local prefix = remaining:sub(1, boundary)
            local breakAt = prefix:match("^.*()%s")
            if breakAt and not remaining:sub(boundary + 1, boundary + 1):match("%s") then
                boundary = breakAt
            end
            passages[#passages + 1] = remaining:sub(1, boundary):match("^(.-)%s*$")
            remaining = remaining:sub(boundary + 1):match("^%s*(.*)$")
        end
        if remaining ~= "" then passages[#passages + 1] = remaining end
    end
    return passages
end

function F.GetTaleDraft()
    return state and normalizeTale(state.draft)
end

function F.SetTaleDraft(tale)
    if not state then return false end
    state.draft = normalizeTale(tale)
    return true
end

function F.ListTales()
    local list = {}
    if not state then return list end
    for _, tale in ipairs(state.archive) do list[#list + 1] = normalizeTale(tale) end
    table.sort(list, function(a, b)
        if a.savedAt == b.savedAt then return a.id > b.id end
        return a.savedAt > b.savedAt
    end)
    return list
end

function F.SaveTale(tale)
    if not state then return nil, "Campfire Tales data needs a newer version of the Codex." end
    local saved = normalizeTale(tale)
    if not saved or saved.text == "" then return nil, "Write or generate a tale before saving." end
    saved.savedAt = time()
    for i, entry in ipairs(state.archive) do
        if entry.id == saved.id then
            state.archive[i] = saved
            F.SetTaleDraft(saved)
            return saved.id
        end
    end
    if #state.archive >= archiveLimit then return nil, "Your archive has 100 tales. Delete a saved tale to make room." end
    saved.id = state.nextID
    state.nextID = state.nextID + 1
    state.archive[#state.archive + 1] = saved
    F.SetTaleDraft(saved)
    return saved.id
end

function F.DeleteTale(id)
    id = F.ValidID(id)
    if not state or not id then return false end
    for i, tale in ipairs(state.archive) do
        if tale.id == id then
            table.remove(state.archive, i)
            if state.draft and state.draft.id == id then state.draft.id = nil end
            return true
        end
    end
    return false
end
