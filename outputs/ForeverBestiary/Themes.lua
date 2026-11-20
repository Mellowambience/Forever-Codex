local _, F = ...

local presets = {
    {
        name = "Gothic Aether",
        headingFile = "Fonts\\MORPHEUS.TTF",
        cover = {.075, .045, .105}, sidebar = {.135, .09, .185}, panel = {.17, .125, .225},
        paper = {.84, .705, .535}, ink = {.17, .095, .225}, secondaryInk = {.26, .15, .31},
        text = {.955, .925, .985}, muted = {.78, .72, .86}, accent = {.895, .79, 1},
        trim = {.52, .34, .67}, glow = {.54, .81, .98}, model = {.095, .07, .15},
        row = {.17, .12, .235}, selection = {.32, .21, .43}, grain = {.82, .64, .53}, edge = {.55, .36, .39},
    },
    {
        name = "Aged Parchment",
        cover = {.105, .048, .04}, sidebar = {.19, .113, .072}, panel = {.32, .22, .133},
        paper = {.83, .66, .45}, ink = {.16, .09, .05}, secondaryInk = {.23, .13, .07},
        text = {.99, .945, .855}, muted = {.83, .75, .62}, accent = {.93, .775, .50},
        trim = {.62, .40, .19}, glow = {1, .82, .54}, model = {.105, .073, .055},
        row = {.19, .121, .081}, selection = {.32, .196, .102}, grain = {.88, .73, .54}, edge = {.61, .40, .21},
    },
    {
        name = "Moonlit Silver",
        cover = {.045, .068, .103}, sidebar = {.085, .135, .203}, panel = {.11, .18, .26},
        paper = {.80, .845, .89}, ink = {.075, .12, .20}, secondaryInk = {.12, .205, .29},
        text = {.94, .975, 1}, muted = {.69, .79, .88}, accent = {.76, .885, .98},
        trim = {.31, .48, .63}, glow = {.66, .89, 1}, model = {.05, .095, .15},
        row = {.11, .18, .26}, selection = {.18, .32, .44}, grain = {.72, .82, .92}, edge = {.43, .57, .69},
    },
    {
        name = "Ember and Brass",
        cover = {.105, .042, .04}, sidebar = {.195, .08, .075}, panel = {.255, .105, .09},
        paper = {.895, .695, .475}, ink = {.225, .085, .07}, secondaryInk = {.32, .13, .09},
        text = {1, .945, .875}, muted = {.88, .745, .66}, accent = {1, .755, .455},
        trim = {.68, .33, .19}, glow = {1, .49, .24}, model = {.14, .053, .045},
        row = {.225, .098, .083}, selection = {.40, .17, .115}, grain = {.91, .68, .49}, edge = {.66, .38, .235},
    },
}

local themes, names = {}, {}
for i, theme in ipairs(presets) do
    themes[theme.name] = theme
    names[i] = theme.name
end

local defaultTheme = presets[1]
local headingFonts = setmetatable({}, {__mode = "k"})

function F.NormalizeCodexTheme(name)
    return F.IsText(name) and themes[name] and name or defaultTheme.name
end

function F.GetCodexTheme()
    local settings = F.db and F.db.settings
    return themes[F.NormalizeCodexTheme(settings and settings.theme)]
end

function F.RefreshCodexTheme()
    if F.RefreshToday then F.RefreshToday() end
    if F.ApplyBestiaryTheme then F.SupportCall("Bestiary theme", F.ApplyBestiaryTheme) end
    if F.ApplyTalesTheme then F.SupportCall("Campfire Tales theme", F.ApplyTalesTheme) end
end

function F.SetCodexTheme(name)
    if not F.IsText(name) or not themes[name] or not F.db or not F.db.settings then return false end
    F.db.settings.theme = name
    F.RefreshCodexTheme()
    return true
end

function F.StyleCodexHeading(region, theme, color)
    if not region then return end
    F.Safe(region.SetTextColor, region, unpack(color or theme.accent))
    local locale = F.Safe(GetLocale)
    local face = (locale == "enUS" or locale == "enGB") and theme.headingFile or nil
    local original = headingFonts[region]
    if face and not original then
        local ok, file, size, flags = pcall(region.GetFont, region)
        if ok and F.IsText(file) and F.IsNumber(size) then
            original = {file = file, size = size, flags = F.IsText(flags) and flags or ""}
            headingFonts[region] = original
        end
    end
    if original then
        F.Safe(region.SetFont, region, face or original.file, original.size, original.flags)
    end
end

function F.CodexThemeButton(parent, x, y, width)
    local button = F.Dropdown(parent, F.GetCodexTheme().name, x, y, width, function() return names end, F.SetCodexTheme)
    function button:SetChoice(name)
        self.value = name
        self:SetText("Theme  v")
    end
    button:SetChoice(F.GetCodexTheme().name)
    return button
end
