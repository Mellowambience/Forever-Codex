local _, F = ...

local generic = {
    repeatFight = {
        "By the last entry, 'see above' would've saved some ink.",
        "At this rate, I ought to start charging for appearances.",
    },
    loot = {
        "I'll let the quartermaster guess what sort of trip it was.",
        "If you're wondering whether those go together, my backpack voted yes.",
    },
    discovery = {
        "Tell anyone who asks that I was studying.",
        "There goes another perfectly good blank page.",
    },
    returnTrip = {
        "Draw a circle on the map and it looks planned.",
        "If you saved your place on the map, well done.",
    },
}

local classes = {
    WARRIOR = {
        openings = { "Make room by the fire. I'll give it to you straight." },
        repeatFight = { "At some point, the tally starts to look like drills." },
        discovery = { "I can keep a record as well as I can hold a line." },
    },
    PALADIN = {
        openings = { "Light keep you. Sit a while and hear how the road went." },
        discovery = { "It's good to see that my duties leave room for a little scholarship." },
        returnTrip = { "I suppose the Light is patient enough to hear that place name twice." },
    },
    HUNTER = {
        openings = { "Settle in. I keep track of what turns up along the way." },
        repeatFight = { "Even a hunter runs out of fresh ways to write the same name." },
        loot = { "If any of that looks like bait, keep it away from the fire." },
    },
    ROGUE = {
        openings = { "Lean in. I'll tell this one quietly." },
        loot = { "You can ask about the bag. The bag has been advised to say nothing." },
        returnTrip = { "A good route always leaves you a way back in." },
    },
    PRIEST = {
        openings = { "Rest a moment. There's time enough to hear what happened." },
        repeatFight = { "I hear patience is a virtue. There it is, in writing, several times over." },
        discovery = { "The margins are wide enough for a small prayer, should one be needed." },
    },
    SHAMAN = {
        openings = { "Sit close. The wind can wait its turn to speak." },
        loot = { "The elements can argue over whose domain that lot belongs to." },
        returnTrip = { "The wind changes its mind all the time. I reckon I'm in good company." },
    },
    MAGE = {
        openings = { "I'll tell it in order. Mixing up the words is a habit a mage can ill afford." },
        repeatFight = { "That's enough entries to put it on the exam." },
        discovery = { "I've added it to the reading list. Yours, if you're volunteering." },
    },
    WARLOCK = {
        openings = { "Settle in. All this tale calls for is a fire." },
        loot = { "If you find a soul shard in that lot, it goes in a different pouch." },
        discovery = { "This is the kind of research I can write up in ordinary ink." },
    },
    DRUID = {
        openings = { "Every trail looks different from the end of it. Here's how mine went." },
        repeatFight = { "There are seasons that come around less often than that name." },
        returnTrip = { "I approve of circles. I'd still like a smaller one next time." },
    },
}

local races = {
    HUMAN = {
        openings = { "Take a seat. There's time for one more tale by the fire." },
        discovery = { "I wonder what the librarians in Stormwind would make of that entry." },
    },
    DWARF = {
        openings = { "By the ancestors, sit down and let me tell you how it went." },
        loot = { "I'll take advice on how to sort it after you've offered to carry some." },
        discovery = { "There's always room in a good book for one more field report." },
    },
    NIGHTELF = {
        openings = { "Elune grant us a quiet moment. I have a tale to tell." },
        repeatFight = { "I have a long memory. All the same, I made sure to write it down." },
    },
    GNOME = {
        openings = { "Pull up a seat. I'll spare you the diagrams." },
        loot = { "If the quartermaster asks how those go together, say the design is still in review." },
        returnTrip = { "A second visit is what I call testing for repeatability." },
    },
    ORC = {
        openings = { "Strength and honor. Pull up a seat." },
        discovery = { "I can hear the elders now. 'Good. Make sure you can pronounce it, too.'" },
    },
    SCOURGE = {
        openings = { "Draw up a chair. I've plenty of time for a tale." },
        repeatFight = { "Even by Forsaken standards, that name kept coming back." },
        returnTrip = { "Coming back is something of a tradition where I'm from." },
    },
    TAUREN = {
        openings = { "May the Earth Mother watch over this fire. Let me tell you where the road took me." },
        loot = { "Whoever can name a use for all of that gets the next turn to tell a story." },
    },
    TROLL = {
        openings = { "Sit by the fire. If the loa are listening, they can hear this one too." },
        repeatFight = { "Say a name that often and I start to think it ought to have a drumbeat." },
    },
}

local undeadWarlock = {
    openings = {
        "Pull up a seat. I have a warlock's account from this side of the grave.",
        "Come closer to the fire. I've kept a few pages for a night like this.",
    },
    repeatFight = { "Write a name that often and someone will mistake it for a summoning." },
    loot = { "A warlock can call anything a reagent. Being dead helps with the straight face." },
    discovery = { "A fresh name for the book. Fresh is a relative term where I'm from." },
    returnTrip = { "Draw that route in chalk and the living will swear it was a ritual." },
}

local empty = {}

local function token(value)
    if F.IsText(value) then return value:upper():gsub("%s+", "") end
end

local function append(target, source)
    for _, line in ipairs(source or empty) do target[#target + 1] = line end
end

function F.TaleVoice(class, race)
    class, race = token(class), token(race)
    if race == "UNDEAD" then race = "SCOURGE" end
    local special = class == "WARLOCK" and race == "SCOURGE" and undeadWarlock or nil
    local layers = { special or empty, classes[class] or empty, races[race] or empty }
    local openings, quips = {}, {}

    if special then
        append(openings, special.openings)
    else
        for _, layer in ipairs(layers) do append(openings, layer.openings) end
    end
    for cue, fallback in pairs(generic) do
        local lines = {}
        for _, layer in ipairs(layers) do append(lines, layer[cue]) end
        if #lines == 0 then append(lines, fallback) end
        quips[cue] = lines
    end

    return { opening = openings[1], openings = openings, quips = quips }
end
