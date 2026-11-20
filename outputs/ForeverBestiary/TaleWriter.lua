local _, F = ...

local maxEvents = 256
local fightKinds = {discover=true, encounter=true}
local smallCounts = {[2]="twice", [3]="three times", [4]="four times", [5]="five times", [6]="six times"}
local quipPriority = {discovery=1, loot=2, repeatFight=3}

-- Keep multi-byte characters intact when trimming text to fit the editor.
local function clip(value, limit)
    if #value <= limit then return value end
    local nextByte = string.byte(value, limit + 1)
    while limit > 0 and nextByte and nextByte >= 128 and nextByte < 192 do
        nextByte = string.byte(value, limit)
        limit = limit - 1
    end
    return string.sub(value, 1, limit)
end

local function plain(value, limit)
    if not F.IsText(value) then return end
    value = clip(value, 2000)
    value = string.gsub(value, "|H[^|]*|h(.-)|h", "%1")
    value = string.gsub(value, "|T.-|t", "")
    value = string.gsub(value, "|A.-|a", "")
    value = string.gsub(value, "|c%x%x%x%x%x%x%x%x", "")
    value = string.gsub(value, "|r", "")
    value = string.gsub(value, "|", "")
    value = string.gsub(value, "[%c%s]+", " ")
    value = string.match(value, "^%s*(.-)%s*$")
    if value == "" then return end
    if #value > limit then return clip(value, limit - 3) .. "..." end
    return value
end

local function collectScenes(events)
    local scenes, seed = {}, 0
    if not F.Public(events) or type(events) ~= "table" then return scenes, seed end
    local scene
    for index = math.max(1, #events - maxEvents + 1), #events do
        local event = events[index]
        if F.Public(event) and type(event) == "table" and F.IsText(event.kind) then
            local kind = event.kind
            local name = plain(event.name, 100)
            local zone = plain(event.zone, 100)
            local note = kind == "note" and plain(event.text, 240)
            local arrival = kind == "zone" and (name or zone)
            if note or arrival or (name and (fightKinds[kind] or kind == "loot" or kind == "quest")) then
                -- The same journey gets the same delivery, including on rewrite.
                local words = note or name or zone
                for offset = 1, #words do seed = (seed * 33 + words:byte(offset)) % 65521 end
                local stamp = F.IsNumber(event.time) and math.floor(event.time) or index
                seed = (seed + stamp) % 65521
                zone = arrival or zone
                if not scene or scene.zone ~= zone then
                    scene = {zone=zone, fights={}, byCreature={}, loot={}, lootSeen={}, quests={}, notes={}}
                    scenes[#scenes + 1] = scene
                end
                if arrival then
                    scene.arrival = true
                elseif note then
                    scene.notes[#scene.notes + 1] = note
                elseif kind == "quest" then
                    scene.quests[#scene.quests + 1] = name
                elseif kind == "loot" then
                    if not scene.lootSeen[name] then
                        scene.loot[#scene.loot + 1] = name
                        scene.lootSeen[name] = true
                    end
                elseif fightKinds[kind] then
                    local credit = F.Public(event.recovered) and event.recovered ~= true
                        and F.IsText(event.credit) and event.credit or "unknown"
                    local fight = scene.byCreature[name]
                    if not fight then
                        fight = {name=name, count=0, credit=credit}
                        scene.fights[#scene.fights + 1] = fight
                        scene.byCreature[name] = fight
                    end
                    local quantity = F.IsNumber(event.quantity) and math.max(1, math.min(1000000, math.floor(event.quantity))) or 1
                    fight.count = fight.count + quantity
                    if credit ~= fight.credit then fight.credit = "unknown" end
                    if kind == "discover" then fight.discovery = credit end
                end
            end
        end
    end
    return scenes, seed
end

local function namesInProse(names)
    if #names == 1 then return names[1] end
    if #names == 2 then return names[1] .. " and " .. names[2] end
    return table.concat(names, ", ", 1, #names - 1) .. ", and " .. names[#names]
end

local function pickFocus(scene)
    local focus
    for _, fight in ipairs(scene.fights) do
        if fight.discovery then return fight end
        if not focus or fight.count > focus.count then focus = fight end
    end
    return focus
end

local function repeatCount(count)
    return smallCounts[count] or (count .. " times")
end

local function fightProse(scene, focus)
    local others, lines = {}, {}
    for _, fight in ipairs(scene.fights) do
        if fight ~= focus and #others < 2 then others[#others + 1] = fight.name end
    end
    if focus.discovery then
        if focus.discovery == "personal" then
            lines[1] = "I brought down " .. focus.name .. " and gave it a page in my Codex."
        elseif focus.discovery == "group" then
            lines[1] = "my group brought down " .. focus.name .. ", which earned a page in my Codex."
        else
            lines[1] = "I added " .. focus.name .. " to my Codex for the first time."
        end
        if focus.count > 1 then
            lines[2] = "That name would turn up again before I turned the page."
        end
    elseif focus.credit == "personal" or focus.credit == "group" then
        local actor = focus.credit == "personal" and "I" or "my group"
        local repeatPhrase = focus.count > 1 and (" " .. repeatCount(focus.count)) or ""
        lines[1] = actor .. " brought down " .. focus.name .. repeatPhrase .. "."
    elseif focus.count > 1 then
        lines[1] = focus.name .. " kept finding its way into my Codex, " .. repeatCount(focus.count) .. " in all."
    else
        table.insert(others, 1, focus.name)
        lines[1] = "my Codex has " .. (#others == 1 and "an entry" or "entries") .. " for " .. namesInProse(others) .. "."
        others = {}
    end
    if #others > 0 and (not focus.discovery or focus.count == 1) then
        lines[#lines + 1] = "I could tell you a bit about " .. namesInProse(others) .. ", too."
    end
    return table.concat(lines, " ")
end

local function sceneWeight(scene)
    local score = #scene.notes > 0 and 5 or 0
    if scene.focus then score = score + (scene.focus.discovery and 4 or 2) end
    if #scene.quests > 0 then score = score + 4 end
    if #scene.loot > 0 then score = score + 1 end
    return score
end

local function storyScenes(scenes)
    if #scenes <= 3 then return scenes end
    local middle = 2
    for i = 3, #scenes - 1 do
        if sceneWeight(scenes[i]) > sceneWeight(scenes[middle]) then middle = i end
    end
    return {scenes[1], scenes[middle], scenes[#scenes]}
end

local function pickLine(lines, seed)
    if lines and #lines > 0 then return lines[seed % #lines + 1] end
end

local function sceneQuipCue(scene)
    if #scene.notes > 0 then return end
    if scene.focus and scene.focus.count >= 3 then return "repeatFight" end
    if #scene.loot >= 2 then return "loot" end
    if scene.focus and scene.focus.discovery then return "discovery" end
end

local function giveQuip(scenes, quips, seed)
    if seed % 2 ~= 0 then return end
    local target, cue, priority = nil, nil, 0
    for _, scene in ipairs(scenes) do
        local topic = sceneQuipCue(scene)
        if topic and quips[topic] and quipPriority[topic] > priority then
            target, cue, priority = scene, topic, quipPriority[topic]
        end
    end
    if target then
        target.quip = pickLine(quips[cue], math.floor(seed / 2))
        target.quipAfterLoot = cue == "loot"
    end
end

local function travelProse(scenes)
    local first, last = scenes[1].zone, scenes[#scenes].zone
    if #scenes == 1 then return "This stretch of my journey took me to " .. first .. "." end
    if #scenes == 2 then return "I started this stretch in " .. first .. " and made my way to " .. last .. "." end
    local stops = {scenes[2].zone}
    local nearLast = scenes[#scenes - 1].zone
    if #scenes > 3 and nearLast ~= stops[1] and nearLast ~= last and nearLast ~= first then
        stops[2] = nearLast
    end
    local ending = first == last and "coming back to " or "reaching "
    return "I set out from " .. first .. " and passed through " .. namesInProse(stops) .. " before " .. ending .. last .. "."
end

local function sceneProse(scene, index)
    local opening = ""
    if scene.zone then
        if index == 1 then opening = "In " .. scene.zone .. ", "
        elseif index == 2 and scene.arrival then opening = "I made my way to " .. scene.zone .. ", where "
        else opening = "Later, in " .. scene.zone .. ", " end
    elseif index > 1 then
        opening = "Later on, "
    end
    local lines = {}
    if scene.focus then lines[1] = fightProse(scene, scene.focus) end
    if scene.quip and not scene.quipAfterLoot then lines[#lines + 1] = scene.quip end
    if #scene.loot > 0 then
        local loot = {}
        for i = 1, math.min(#scene.loot, 2) do loot[i] = scene.loot[i] end
        local connective = scene.focus and "I also picked up " or "I picked up "
        lines[#lines + 1] = connective .. namesInProse(loot) .. "."
    end
    if scene.quipAfterLoot then lines[#lines + 1] = scene.quip end
    if #scene.quests > 0 then
        local title = scene.quests[#scene.quests]
        local task = title:match("^Quest %d+$") and "a job" or ('"' .. title .. '"')
        local connective = #lines > 0 and "I also saw " or "I saw "
        lines[#lines + 1] = connective .. task .. " through to the end."
    end
    if #scene.notes > 0 then
        local note = scene.notes[#scene.notes]
        local ending = note:match("[.!?]$") and '"' or '".'
        local lead = #lines == 0 and "one" or "One"
        lines[#lines + 1] = lead .. ' line in my field notes reads, "' .. note .. ending
    end
    if #lines == 0 then
        if index == 1 then return "I started this stretch in " .. scene.zone .. "." end
        return "Later I made it to " .. scene.zone .. "."
    end
    local text = table.concat(lines, " ")
    if opening == "" then
        return (text:gsub("^%l", string.upper))
    end
    return opening .. text
end

function F.WriteTale(events, class, race)
    local scenes, seed = collectScenes(events)
    if #scenes == 0 then
        return "There's no journey to retell yet. Visit a place, discover a creature, or leave a field note to start your tale."
    end
    local hasActivity = false
    for _, scene in ipairs(scenes) do
        scene.focus = pickFocus(scene)
        if sceneWeight(scene) > 0 then hasActivity = true end
    end
    local voice = F.TaleVoice and F.TaleVoice(class, race) or {}
    local quips = voice.quips or {}
    local greeting = pickLine(voice.openings, math.floor(seed / 3)) or voice.opening
    local introduction = greeting and (hasActivity or #scenes > 1) and (greeting .. " ") or ""
    if not hasActivity then
        local story = travelProse(scenes)
        if #scenes >= 3 and scenes[1].zone == scenes[#scenes].zone and seed % 2 == 0 then
            local quip = pickLine(quips.returnTrip, math.floor(seed / 2))
            if quip then story = story .. " " .. quip end
        end
        return introduction .. story
    end
    local selected = storyScenes(scenes)
    giveQuip(selected, quips, seed)
    local paragraphs = {}
    local opening
    for i, scene in ipairs(selected) do
        local text = sceneProse(scene, i)
        if sceneWeight(scene) == 0 then
            if #paragraphs == 0 then
                opening = opening and (opening .. " " .. text) or text
            else
                paragraphs[#paragraphs] = paragraphs[#paragraphs] .. " " .. text
            end
        else
            paragraphs[#paragraphs + 1] = opening and (opening .. " " .. text) or text
            opening = nil
        end
    end
    return introduction .. table.concat(paragraphs, "\n\n")
end
