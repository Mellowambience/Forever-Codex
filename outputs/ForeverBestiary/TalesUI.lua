local _, F = ...

local window
local WIDTH, HEIGHT = 740, 488
local PAGE_WIDTH, PAGE_HEIGHT = 497, 270
local PAGE_MARGIN, PAGE_SPACING = 10, 3
local ROW_HEIGHT = 25
local TITLE_BYTES, TALE_BYTES, RECORD_BYTES, NOTE_BYTES = 120, 8192, 24576, 500

local function paint(parent, x, y, width, height, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 2)
    texture:SetPoint("TOPLEFT", x, y)
    texture:SetSize(width, height)
    return texture
end

local function tintTexture(texture, color, alpha)
    texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
end

local function bookColor(parent, x, y, width, height, color, alpha, sublevel, layer)
    local texture = paint(parent, x, y, width, height, layer, sublevel)
    local art = window.themeArt
    art[#art + 1] = {texture=texture, color=color, alpha=alpha}
    tintTexture(texture, window.theme[color], alpha)
    return texture
end

local function pageCorner(parent, x, y, horizontal, vertical)
    bookColor(parent, x + math.min(0, horizontal * 13), y, 14, 1, "secondaryInk", .70, 6)
    bookColor(parent, x, y + math.max(0, vertical * 9), 1, 10, "secondaryInk", .70, 6)
    local dot = bookColor(parent, x + (horizontal > 0 and 3 or -5), y + (vertical > 0 and 5 or -3), 3, 3, "glow", .78, 6)
    F.Safe(dot.SetRotation, dot, math.pi / 4)
end

local function bindBook(w)
    if w.Inset then F.Safe(w.Inset.Hide, w.Inset) end
    bookColor(w, 7, -28, 726, 454, "cover")
    bookColor(w, 12, -32, 181, 446, "sidebar", 1, 3)
    bookColor(w, 194, -31, 7, 446, "model", 1, 3)
    bookColor(w, 195, -35, 1, 438, "trim", 1, 4)
    for y = -63, -461, -56 do
        bookColor(w, 195, y, 4, 2, "trim", 1, 4)
    end
    local clasp = bookColor(w, 195, -109, 5, 5, "glow", .75, 5)
    F.Safe(clasp.SetRotation, clasp, math.pi / 4)
    bookColor(w, 19, -52, 154, 1, "trim", 1, 4)
    bookColor(w, 19, -398, 154, 1, "trim", 1, 4)
    bookColor(w, 204, -440, 508, 1, "trim", 1, 4)

    bookColor(w, 201, -108, 528, 288, "edge", 1, 3)
    bookColor(w, 203, -111, 523, 282, "paper", 1, 4)
    w.bookGrain = paint(w, 203, -111, 523, 282, nil, 5)
    w.bookGrain:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment")
    F.Safe(w.bookGrain.SetAlpha, w.bookGrain, .17)
    bookColor(w, 203, -111, 7, 282, "edge", .27, 6)
    bookColor(w, 719, -111, 7, 282, "edge", .27, 6)
    bookColor(w, 204, -393, 523, 1, "trim", 1, 6)
    bookColor(w, 206, -395, 521, 1, "edge", 1, 6)
    pageCorner(w, 207, -114, 1, -1)
    pageCorner(w, 710, -114, -1, -1)
    pageCorner(w, 207, -389, 1, 1)
    pageCorner(w, 710, -389, -1, 1)
end

local function bookmark(control, x, y, width, height)
    local mark = bookColor(control, x, y, width, height, "accent", 1, 1, "OVERLAY")
    mark:Hide()
    return mark
end

local function label(parent, value, x, y, font, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", x, y)
    text:SetJustifyH("LEFT")
    if width then text:SetWidth(width) end
    text:SetText(value)
    return text
end

local function tintButton(control, accent)
    for _, key in ipairs({"Left", "Middle", "Right"}) do
        local segment = control[key]
        if segment then
            F.Safe(segment.SetVertexColor, segment, .62 + .30 * accent[1], .62 + .30 * accent[2], .62 + .30 * accent[3])
        end
    end
end

local function button(parent, value, x, y, width, click)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetPoint("TOPLEFT", x, y)
    control:SetSize(width, 24)
    control:SetText(value)
    control:SetScript("OnClick", click)
    local buttons = window.themeButtons
    buttons[#buttons + 1] = control
    tintButton(control, window.theme.accent)
    return control
end

local function enable(control, enabled)
    if enabled then control:Enable() else control:Disable() end
end

local function tabState(control, available, selected)
    enable(control, available and not selected)
    control.bookmark:SetShown(selected)
end

local function archiveRowState(row, selected)
    enable(row, not selected)
    row.bookmark:SetShown(selected)
end

local function status(message)
    window.status:SetText(message or "")
end

local function copyShortcut()
    return F.Safe(IsMacClient) and "Cmd+C" or "Ctrl+C"
end

local function selectedTale()
    if not window.selected then return window.draft end
    for _, tale in ipairs(window.tales) do
        if tale.id == window.selected then return tale end
    end
end

local function resizePage()
    local edit = window.editor
    window.measure:SetText((edit:GetText():gsub("|", "||")) .. " ")
    edit:SetHeight(math.max(PAGE_HEIGHT, window.measure:GetStringHeight() + 14))
end

local function updatePageHint()
    local w = window
    local hint = ""
    if w.page == "recent" and F.TalesWritable() then
        hint = w.recentPending and "New entries ready. Click outside to refresh." or "Updates as you play."
    elseif w.page == "retell" then
        hint = "Select a passage, then press " .. copyShortcut() .. "."
    elseif w.page == "record" then
        hint = "Activity recorded when this story was written."
    elseif w.draft and not w.selected and w.draftHasNewEvents then
        hint = "New entries in Activity."
    end
    w.pageHint:SetText(hint)
end

local function scrollRange()
    local scroll = window.pageScroll
    F.Safe(scroll.UpdateScrollChildRect, scroll)
    return F.Safe(scroll.GetVerticalScrollRange, scroll) or 0
end

local function refreshRecent()
    local w = window
    if w.page ~= "recent" or w.loading or not w:IsShown() then return end
    if F.Safe(w.editor.HasFocus, w.editor) then
        w.recentPending = true
    else
        local body = F.GetRecentTaleRecord()
        if body ~= w.editorText then
            local scroll = w.pageScroll
            local offset = F.Safe(scroll.GetVerticalScroll, scroll) or 0
            local follow = offset >= scrollRange() - 16
            w.loading = true
            w.editor:SetText(body)
            w.editorText = body
            resizePage()
            local range = scrollRange()
            scroll:SetVerticalScroll(follow and range or math.min(offset, range))
            w.loading = false
        end
        w.recentPending = false
    end
    updatePageHint()
end

function F.RefreshTaleRecordView()
    if not window then return end
    if window.page == "recent" then
        refreshRecent()
    elseif window.draft then
        window.draftHasNewEvents = true
        if window:IsShown() then updatePageHint() end
    end
end

local function renderPage()
    local w = window
    local tale = selectedTale()
    if not tale then w.selected = nil; tale = w.draft end
    if not tale and (w.page == "record" or w.page == "retell") then w.page = "tale" end
    local writable = F.TalesWritable()
    local recent = w.page == "recent"
    local activity = recent or w.page == "record"
    local story = w.page == "tale"
    local retelling = w.page == "retell"
    local editable = story and tale ~= nil and not w.selected and writable
    local hasStory = story and tale ~= nil and tale.text:match("%S") ~= nil
    w.loading = true
    w.title:ClearFocus()
    w.editor:ClearFocus()
    w.title:SetText(tale and tale.title or "")
    w.title:SetShown(editable == true)
    w.titleLabel:SetShown(editable == true)
    w.storyTitle:SetShown(not activity and not editable)
    w.storyTitle:SetText(tale and (tale.title:gsub("|", "")) or "Your first story")
    w.recentTitle:SetShown(activity)
    w.recentTitle:SetText(recent and "Recent activity" or "Activity in this story")
    w.activityRecent:SetShown(activity and tale ~= nil)
    w.recordTab:SetShown(activity and tale ~= nil)
    enable(w.title, editable)
    local body
    local excerptCount = 0
    if recent then
        body = F.GetRecentTaleRecord()
        w.recentPending, w.draftHasNewEvents = false, false
    elseif retelling then
        local excerpts = F.TaleExcerpts(tale.text)
        excerptCount = #excerpts
        w.excerpt = math.max(1, math.min(w.excerpt, excerptCount))
        body = excerpts[w.excerpt] or "Write a few lines of your story to share it."
    elseif tale and w.page == "record" then
        body = tale.record ~= "" and tale.record or "There is no activity saved with this story."
    elseif tale then
        body = tale.text
    else
        body = writable and "Turn your recent adventures into a story you can edit and share.\n\nExplore, finish a quest, or add a field note, then choose Write story."
            or "Campfire Tales needs a newer version of the Codex to open your stories."
    end
    F.Safe(w.editor.SetMaxBytes, w.editor, editable and TALE_BYTES or RECORD_BYTES)
    w.editor:SetText(body)
    w.editorText = body
    w.editable = editable
    resizePage()
    w.pageScroll:SetVerticalScroll(recent and scrollRange() or 0)
    w.loading = false
    tabState(w.recentTab, true, activity)
    tabState(w.taleTab, true, story)
    w.taleTab:SetText(retelling and "Back to story" or "Story")
    tabState(w.activityRecent, tale, recent)
    tabState(w.recordTab, tale, w.page == "record")
    updatePageHint()
    w.previous:SetShown(retelling and w.excerpt > 1)
    w.next:SetShown(retelling and w.excerpt < excerptCount)
    w.pageCount:SetShown(retelling and excerptCount > 1)
    w.pageCount:SetText(excerptCount > 0 and (w.excerpt .. " / " .. excerptCount) or "")
    w.save:SetShown(editable and hasStory)
    w.share:SetShown(hasStory)
    w.select:SetShown(retelling and excerptCount > 0)
    w.remove:SetShown(story and tale ~= nil and writable == true)
    w.remove:SetText(w.selected and "Delete story" or "Discard draft")
    w.tell:SetShown(story and writable == true and (not w.selected or not w.draft))
    w.tell:SetText(w.draft and "Rewrite story" or "Write story")
    w.tell:SetPoint("TOPLEFT", w.draft and 454 or 204, -445)
    w.draftButton:SetShown(w.draft ~= nil and (w.selected ~= nil or not story))
    w.note:SetShown(writable == true)
    w.noteLabel:SetShown(writable == true)
    w.addNote:SetShown(writable == true)
    enable(w.addNote, writable and w.note:GetText():match("%S") ~= nil)
end

local function renderArchive()
    local w = window
    local tales = w.tales
    for i, tale in ipairs(tales) do
        local row = w.rows[i]
        if not row then
            row = button(w.archive, "", 0, -(i - 1) * ROW_HEIGHT, 154, function(self)
                w.selected = self.taleID
                w.page = "tale"
                renderPage()
                for _, entry in ipairs(w.rows) do archiveRowState(entry, entry.taleID == w.selected) end
                status("")
            end)
            local text = F.Safe(row.GetFontString, row)
            if text then F.Safe(text.SetMaxLines, text, 1) end
            row.bookmark = bookmark(row, 4, -5, 2, 14)
            w.rows[i] = row
        end
        row.taleID = tale.id
        row:SetText((tale.title:gsub("|", "")))
        archiveRowState(row, tale.id == w.selected)
        row:Show()
    end
    for i = #tales + 1, #w.rows do w.rows[i]:Hide() end
    w.archive:SetHeight(math.max(1, #tales * ROW_HEIGHT))
    w.empty:SetShown(#tales == 0)
end

local function showDraft()
    window.selected = nil
    window.page = "tale"
    renderPage()
    renderArchive()
    status("")
end

local function rememberDraft()
    F.SetTaleDraft(window.draft)
end

local function writeTale()
    if not F.TalesWritable() then return end
    local tale, reason = F.GenerateTale()
    if not tale then status(reason or "There are no recorded events to tell yet."); return end
    if not F.SetTaleDraft(tale) then status("This draft could not be saved."); return end
    window.draft = tale
    window.draftHasNewEvents = false
    showDraft()
end

local function tellTale()
    local draft = window.draft
    if not draft then writeTale(); return end
    StaticPopupDialogs.FOREVER_CODEX_REWRITE_TALE = {
        text = "Replace your current draft with a new story from your latest activity? Save your draft first if you want to keep it.",
        button1 = "Replace draft",
        button2 = "Cancel",
        OnAccept = function()
            if window.draft == draft then writeTale() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("FOREVER_CODEX_REWRITE_TALE")
end

local function saveTale()
    if not F.TalesWritable() or not window.draft then return end
    local id, reason = F.SaveTale(window.draft)
    if not id then status(reason or "This story could not be saved."); return end
    window.draft = nil
    rememberDraft()
    window.selected = id
    window.page = "tale"
    window.tales = F.ListTales()
    window.archiveScroll:SetVerticalScroll(0)
    renderPage()
    renderArchive()
    status("Story saved to your archive.")
end

local function confirmRemoval()
    local id = window.selected
    local draft = window.draft
    if not id and not draft then return end
    StaticPopupDialogs.FOREVER_CODEX_REMOVE_TALE = {
        text = id and "Delete this saved story?" or "Discard this draft?",
        button1 = id and "Delete" or "Discard",
        button2 = "Cancel",
        OnAccept = function()
            if not F.TalesWritable() then return end
            if id then
                if not F.DeleteTale(id) then status("This story could not be deleted."); return end
                window.tales = F.ListTales()
            else
                if window.draft ~= draft then return end
                window.draft = nil
                rememberDraft()
            end
            showDraft()
            status(id and "Story deleted." or "Draft discarded.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("FOREVER_CODEX_REMOVE_TALE")
end

local function addNote()
    local note = window.note
    if not F.TalesWritable() or not note:GetText():match("%S") then return end
    if not F.AddTaleNote(note:GetText()) then
        status("This field note could not be saved.")
        return
    end
    note:SetText("")
    note:ClearFocus()
    status("Field note added to your journey.")
end

function F.ApplyTalesTheme()
    local w = window
    if not w then return end
    local theme = F.GetCodexTheme()
    w.theme = theme
    for _, layer in ipairs(w.themeArt) do
        tintTexture(layer.texture, theme[layer.color], layer.alpha)
    end
    for _, control in ipairs(w.themeButtons) do tintButton(control, theme.accent) end
    tintButton(w.themePicker, theme.accent)
    F.Safe(w.themePicker.SetChoice, w.themePicker, theme.name)
    F.Safe(w.bookGrain.SetVertexColor, w.bookGrain, unpack(theme.grain))
    for _, heading in ipairs({w.TitleText, w.archiveTitle, w.storyTitle, w.recentTitle}) do
        F.StyleCodexHeading(heading, theme)
    end
    for _, field in ipairs({w.titleLabel, w.noteLabel, w.pageCount}) do
        F.Safe(field.SetTextColor, field, unpack(theme.accent))
    end
    for _, field in ipairs({w.pageHint, w.status, w.empty}) do
        F.Safe(field.SetTextColor, field, unpack(theme.muted))
    end
    F.Safe(w.title.SetTextColor, w.title, unpack(theme.text))
    F.Safe(w.note.SetTextColor, w.note, unpack(theme.text))
    F.Safe(w.editor.SetTextColor, w.editor, unpack(theme.ink))
    F.Safe(w.editor.SetHighlightColor, w.editor, theme.selection[1], theme.selection[2], theme.selection[3], .16)
end

local function createWindow()
    local w = CreateFrame("Frame", "ForeverCodexTalesWindow", UIParent, "BasicFrameTemplateWithInset")
    window = w
    w.page, w.excerpt, w.tales = "tale", 1, {}
    w.theme, w.themeArt, w.themeButtons = F.GetCodexTheme(), {}, {}
    w:SetSize(WIDTH, HEIGHT)
    w:SetPoint("CENTER")
    w.TitleText:SetText("Forever Codex - Campfire Tales")
    bindBook(w)
    F.RegisterWindow("tales", w, WIDTH, HEIGHT)
    tinsert(UISpecialFrames, "ForeverCodexTalesWindow")
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", function(self)
        if not F.Safe(InCombatLockdown) then self:StartMoving() end
    end)
    w:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        F.SaveWindowPosition("tales")
    end)

    local bookIcon = paint(w, 19, -32, 17, 17, "ARTWORK")
    bookIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    bookIcon:SetTexCoord(.08, .92, .08, .92)
    w.archiveTitle = label(w, "Saved stories", 43, -36, "GameFontNormal")
    w.draftButton = button(w, "Draft story", 17, -57, 154, showDraft)
    local archiveScroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
    archiveScroll:SetPoint("TOPLEFT", 17, -91)
    archiveScroll:SetSize(156, 271)
    F.AddScrollCue(archiveScroll,true)
    w.archiveScroll = archiveScroll
    w.archive = CreateFrame("Frame", nil, archiveScroll)
    w.archive:SetSize(156, 1)
    archiveScroll:SetScrollChild(w.archive)
    w.rows = {}
    w.empty = label(w.archive, "No saved stories yet.", 3, -5, nil, 146)
    w.remove = button(w, "Discard draft", 17, -367, 154, confirmRemoval)
    w.noteLabel = label(w, "Field note", 20, -404, "GameFontNormalSmall")
    w.note = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
    w.note:SetSize(148, 22)
    w.note:SetPoint("TOPLEFT", 23, -420)
    w.note:SetAutoFocus(false)
    if w.note.SetMaxBytes then w.note:SetMaxBytes(NOTE_BYTES)
    else w.note:SetMaxLetters(NOTE_BYTES) end
    w.addNote = button(w, "Add note", 17, -445, 154, addNote)
    w.note:SetScript("OnEnterPressed", addNote)
    w.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    w.note:SetScript("OnTextChanged", function(self)
        enable(w.addNote, F.TalesWritable() and self:GetText():match("%S") ~= nil)
    end)

    w.titleLabel = label(w, "Draft title", 209, -36, "GameFontNormalSmall")
    w.storyTitle = label(w, "", 209, -46, "GameFontNormal", PAGE_WIDTH)
    F.Safe(w.storyTitle.SetMaxLines, w.storyTitle, 1)
    w.recentTitle = label(w, "Recent activity", 209, -46, "GameFontNormal")
    w.title = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
    w.title:SetSize(497, 22)
    w.title:SetPoint("TOPLEFT", 209, -52)
    w.title:SetAutoFocus(false)
    if w.title.SetMaxBytes then w.title:SetMaxBytes(TITLE_BYTES)
    else w.title:SetMaxLetters(TITLE_BYTES) end
    w.title:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    w.title:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    w.title:SetScript("OnTextChanged", function(self, userInput)
        if userInput and not w.loading and w.draft and not w.selected and F.TalesWritable() then
            w.draft.title = self:GetText()
            rememberDraft()
        end
    end)

    w.recentTab = button(w, "Activity", 321, -82, 112, function()
        w.page = "recent"
        renderPage()
        status("")
    end)
    w.taleTab = button(w, "Story", 204, -82, 112, function()
        w.page = "tale"
        renderPage()
        status("")
    end)
    w.activityRecent = button(w, "Recent activity", 450, -40, 122, function()
        w.page = "recent"
        renderPage()
        status("")
    end)
    w.recordTab = button(w, "This story", 578, -40, 122, function()
        w.page = "record"
        renderPage()
        status("")
    end)
    w.recentTab.bookmark = bookmark(w.recentTab, 6, -21, 100, 2)
    w.taleTab.bookmark = bookmark(w.taleTab, 6, -21, 100, 2)
    w.activityRecent.bookmark = bookmark(w.activityRecent, 6, -21, 110, 2)
    w.recordTab.bookmark = bookmark(w.recordTab, 6, -21, 110, 2)
    w.themePicker = F.CodexThemeButton(w, 538, -82, 164)
    w.pageHint = label(w, "", 434, -403, nil, 273)
    w.pageScroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
    w.pageScroll:SetPoint("TOPLEFT", 209, -119)
    w.pageScroll:SetSize(PAGE_WIDTH, PAGE_HEIGHT)
    F.AddScrollCue(w.pageScroll,true)
    local pageFont = QuestFont or ChatFontNormal or GameFontHighlight
    w.measure = label(w, "", 0, 0, "ChatFontNormal", PAGE_WIDTH - 2 * PAGE_MARGIN)
    F.Safe(w.measure.SetFontObject, w.measure, pageFont)
    F.Safe(w.measure.SetSpacing, w.measure, PAGE_SPACING)
    F.Safe(w.measure.SetAlpha, w.measure, 0)
    local edit = CreateFrame("EditBox", nil, w.pageScroll)
    edit:SetSize(PAGE_WIDTH, PAGE_HEIGHT)
    edit:SetFontObject(pageFont)
    edit:SetMultiLine(true)
    F.Safe(edit.SetTextInsets, edit, PAGE_MARGIN, PAGE_MARGIN, 7, 7)
    F.Safe(edit.SetSpacing, edit, PAGE_SPACING)
    F.Safe(edit.SetShadowColor, edit, 0, 0, 0, 0)
    edit:SetAutoFocus(false)
    edit:EnableMouse(true)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", function()
        if w.recentPending then refreshRecent() end
    end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if w.loading or not userInput then return end
        if not w.editable or not F.TalesWritable() then
            self:SetText(w.editorText)
            return
        end
        w.draft.text = self:GetText()
        rememberDraft()
        local hasStory = w.draft.text:match("%S") ~= nil
        w.save:SetShown(hasStory)
        w.share:SetShown(hasStory)
        resizePage()
    end)
    edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        if w.loading or not F.IsNumber(y) or not F.IsNumber(height) then return end
        local top = F.Safe(w.pageScroll.GetVerticalScroll, w.pageScroll) or 0
        local caret = -y
        if caret < top then
            w.pageScroll:SetVerticalScroll(math.max(0, caret))
        elseif caret + height > top + PAGE_HEIGHT then
            local bottom = caret + height - PAGE_HEIGHT
            local range = F.Safe(w.pageScroll.GetVerticalScrollRange, w.pageScroll) or bottom
            w.pageScroll:SetVerticalScroll(math.min(bottom, range))
        end
    end)
    w.pageScroll:SetScrollChild(edit)
    w.editor = edit

    w.previous = button(w, "Previous", 204, -396, 91, function()
        w.excerpt = w.excerpt - 1
        renderPage()
        status("")
    end)
    w.pageCount = label(w, "", 300, -403, nil, 48)
    w.pageCount:SetJustifyH("CENTER")
    w.next = button(w, "Next", 353, -396, 71, function()
        w.excerpt = w.excerpt + 1
        renderPage()
        status("")
    end)
    w.status = label(w, "", 209, -425, nil, 497)
    w.tell = button(w, "Write story", 204, -445, 120, tellTale)
    w.save = button(w, "Save story", 204, -445, 120, saveTale)
    w.share = button(w, "Share in chat", 329, -445, 120, function()
        w.page, w.excerpt = "retell", 1
        renderPage()
        status("")
    end)
    w.select = button(w, "Select passage", 204, -445, 150, function()
        edit:SetFocus()
        edit:HighlightText()
        status("Press " .. copyShortcut() .. " to copy, then paste the passage into chat.")
    end)
    button(w, "Back to Bestiary", 578, -445, 131, function()
        F.CreateUI()
        if F.ShowManaged("journal") then F.Render() end
    end)
    w:SetScript("OnShow", refreshRecent)
    w:SetScript("OnHide", function()
        edit:ClearFocus()
        w.title:ClearFocus()
        w.note:ClearFocus()
        F.Safe(StaticPopup_Hide, "FOREVER_CODEX_REMOVE_TALE")
        F.Safe(StaticPopup_Hide, "FOREVER_CODEX_REWRITE_TALE")
        if not F.layoutSuspending then w.tales = {} end
        F.ManagedHidden("tales")
    end)
    w:Hide()
end

function F.OpenTales(storyID)
    if F.Safe(InCombatLockdown) then
        F.Message("Open Campfire Tales after combat.")
        return
    end
    if not window then createWindow() end
    F.ApplyTalesTheme()
    window.draft = F.GetTaleDraft()
    window.tales = F.ListTales()
    if not window:IsShown() then window.page = "tale" end
    if storyID then window.selected, window.page = storyID, "tale" end
    renderPage()
    renderArchive()
    status("")
    F.ShowManaged("tales")
end
