from runpy import run_path

lua = run_path('work/test_release.py')['lua']
lua.execute('''
local function choose(button, name)
    button.scripts.OnClick(button)
    assert(button.popup:IsShown() and #button.popup.options == 4)
    for _, row in ipairs(button.popup.rows) do
        if row.option == name then row.scripts.OnClick(row); return end
    end
    error("Theme missing from picker: " .. name)
end

assert(F.GetCodexTheme().name == "Gothic Aether")
local bestiary = F.window
assert(bestiary and bestiary.themeButton.value == "Gothic Aether")
assert(F.AddTaleNote("The road back was quiet."))
F.OpenTales()
local tales = ForeverCodexTalesWindow
tales.tell.scripts.OnClick(tales.tell)
local draft = F.GetTaleDraft()
local editor = tales.editor:GetText()
local picked = F.selected
choose(tales.themePicker, "Moonlit Silver")
assert(tales.theme.name == "Moonlit Silver" and bestiary.themeButton.value == "Moonlit Silver")
assert(tales.page == "tale" and tales.editor:GetText() == editor)
assert(F.GetTaleDraft().text == draft.text and F.GetTaleDraft().record == draft.record)
assert(F.selected == picked)
assert(ForeverBestiaryDB.settings.theme == "Moonlit Silver")
F.LoadStorage()
assert(F.GetCodexTheme().name == "Moonlit Silver")
assert(not F.SetCodexTheme("unknown") and F.GetCodexTheme().name == "Moonlit Silver")
assert(F.NormalizeCodexTheme("unknown") == "Gothic Aether")

F.Toggle()
choose(bestiary.themeButton, "Ember and Brass")
assert(tales.themePicker.value == "Ember and Brass")
assert(tales.theme.name == "Ember and Brass" and F.selected == picked)

local locale = "enUS"
function GetLocale() return locale end
local font = {file="Native",size=20,flags="OUTLINE"}
function font:GetFont() return self.file, self.size, self.flags end
function font:SetFont(file, size, flags) self.file, self.size, self.flags = file, size, flags end
F.SetCodexTheme("Gothic Aether")
F.StyleCodexHeading(font, F.GetCodexTheme())
assert(font.file:find("MORPHEUS", 1, true) and font.size == 20 and font.flags == "OUTLINE")
F.SetCodexTheme("Aged Parchment")
F.StyleCodexHeading(font, F.GetCodexTheme())
assert(font.file == "Native")
locale = "koKR"
F.SetCodexTheme("Gothic Aether")
F.StyleCodexHeading(font, F.GetCodexTheme())
assert(font.file == "Native", "Localized fonts should remain available")
''')


def luminance(rgb):
    values = [rgb[i] for i in range(1, 4)]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in values]
    return sum(value * weight for value, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


f = lua.globals().F
for name in ('Gothic Aether', 'Aged Parchment', 'Moonlit Silver', 'Ember and Brass'):
    assert f.SetCodexTheme(name)
    theme = f.GetCodexTheme()
    for foreground, background in (('ink', 'paper'), ('secondaryInk', 'paper'), ('text', 'panel'),
                                   ('muted', 'panel'), ('accent', 'selection')):
        dark, light = sorted((luminance(theme[foreground]), luminance(theme[background])))
        assert (light + 0.05) / (dark + 0.05) >= 4.5, (name, foreground, background)

print('PASS: theme pickers, cross-chapter updates, saved preference, unchanged draft, localized fonts, and text contrast')
