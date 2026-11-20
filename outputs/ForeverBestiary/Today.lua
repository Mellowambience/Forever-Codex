local _, F = ...
local window

function F.BuildToday()
    local page = {known=0, unpriced=0, leads={}, session=F.TodaySession()}
    local zone = F.Safe(GetRealZoneText)
    page.zone = F.IsText(zone) and zone or "Unknown location"
    for _, id in ipairs(F.Keys(F.db.recipes)) do
        local recipe = F.db.recipes[id]
        if recipe.learnedBy[F.character] then
            page.known = page.known + 1
            local plan = F.EstimateCraft(recipe)
            if plan.margin and plan.margin > 0 then
                if not page.best or plan.margin > page.best.plan.margin then
                    page.best = {id=id, recipe=recipe, plan=plan}
                end
            elseif not plan.margin then
                page.unpriced = page.unpriced + 1
                page.check = page.check or {id=id, recipe=recipe, plan=plan}
            end
        end
    end
    local needs, missing = F.MaterialNeeds(), {}
    page.pinned = next(needs) ~= nil
    for id, count in pairs(needs) do
        local owned = F.InventoryCount(id)
        if not F.IsNumber(owned) then page.inventoryUnknown = true
        elseif count > owned then missing[id] = count - owned end
    end
    page.needsMaterials = next(missing) ~= nil
    for _, id in ipairs(F.Keys(F.db.creatures)) do
        local creature = F.db.creatures[id]
        if creature.zones[page.zone] then
            local seen, items = {}, {}
            for _, loot in pairs(creature.loot) do
                if missing[loot.itemID] and not seen[loot.itemID] then
                    seen[loot.itemID] = true
                    items[#items+1] = loot.itemID
                end
            end
            table.sort(items)
            if #items > 0 then page.leads[#page.leads+1] = {creature=creature, items=items} end
        end
    end
    table.sort(page.leads, function(a,b)
        if a.creature.name == b.creature.name then return a.creature.id < b.creature.id end
        return a.creature.name < b.creature.name
    end)
    return page
end

function F.OpenBestiary(id)
    if F.Safe(InCombatLockdown) then return end
    F.CreateUI()
    if id and F.db.creatures[id] then
        F.selected = id
        if not F.readOnly then F.db.settings.selected = id end
    end
    if F.ShowManaged("journal") then F.Render() end
end

function F.TodayTale()
    if F.Safe(InCombatLockdown) then return end
    -- Never replace a player's draft from the home page.
    if not F.GetTaleDraft() then
        local tale, reason = F.GenerateTale()
        if tale then F.SetTaleDraft(tale) elseif reason then F.Message(reason) end
    end
    F.OpenTales()
end

local function label(parent, font, width)
    local text = parent:CreateFontString(nil,"OVERLAY",font)
    text:SetWidth(width); text:SetJustifyH("LEFT")
    return text
end
local function button(parent, title, width, action)
    local b = CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,25); b:SetText(title); b:SetScript("OnClick",action)
    return b
end

function F.RefreshToday()
    local w = window
    if not w or not w:IsShown() or not F.db then return end
    local page, theme = F.BuildToday(), F.GetCodexTheme()
    w.page = page
    w.cover:SetColorTexture(unpack(theme.cover))
    w.paper:SetColorTexture(unpack(theme.paper))
    w.binding:SetColorTexture(unpack(theme.trim))
    F.StyleCodexHeading(w.heading,theme)
    w.subtitle:SetText(page.zone .. "  |  A plan for the road ahead")
    F.Safe(w.subtitle.SetTextColor,w.subtitle,unpack(theme.muted))
    local best, check = page.best, page.check
    local coin
    if best then
        coin = best.recipe.name .. "\nEstimated margin: +" .. F.Money(best.plan.margin) .. " per craft after AH cut."
        coin = coin .. "\n" .. (best.plan.inventoryUnknown and "Bag counts unavailable."
            or (#best.plan.shopping == 0 and "Materials for one craft are in your bags."
            or "Missing materials at quoted AH prices: " .. F.Money(best.plan.buyCost)))
        coin = coin .. "\nBest among your priced recipes; quotes may be up to two days old. Deposits and demand are excluded."
        if page.unpriced > 0 then coin = coin .. " " .. page.unpriced .. " other recipes still need data." end
    elseif page.known == 0 then
        coin = "Your recipes belong here. Open My Professions, open your recipe window, then choose Import recipes."
    elseif check then
        coin = "No positive margin is confirmed yet. " .. check.recipe.name .. ": "
            .. (check.plan.reason or "Needs recent prices. Open the AH and use Check prices in Gold Planner.")
    else
        coin = "None of your priced recipes shows a positive margin right now. Review the costs or refresh prices before crafting to sell."
    end
    local nearby = {}
    for i=1,math.min(3,#page.leads) do
        local lead, names = page.leads[i], {}
        for _, id in ipairs(lead.items) do names[#names+1] = F.ItemInfo(id).name end
        nearby[#nearby+1] = lead.creature.name .. " - " .. table.concat(names,", ")
    end
    if #nearby > 0 then
        nearby[#nearby+1] = "Observed loot on creatures recorded in this zone. Not a live spawn location or guaranteed drop."
        if #page.leads > 3 then nearby[#nearby+1] = (#page.leads-3) .. " more recorded sources; browse the Bestiary." end
    elseif not page.pinned then
        nearby[1] = "Pin a known recipe in Gold Planner. Your Codex will connect missing materials to creatures you have recorded in this zone."
    elseif page.inventoryUnknown then
        nearby[1] = "Some bag counts are unavailable. Check your materials in Gold Planner before heading out."
    elseif not page.needsMaterials then
        nearby[1] = "Your bags cover the materials for your pinned recipes. Time to visit your profession window."
    else
        nearby[1] = "No observed creature drops here match your missing recipe materials yet. Explore the Atlas or keep recording loot."
    end
    local s = page.session
    local story = string.format("Since login / reload: %d discoveries, %d repeat encounters, %d quests turned in, %d items looted.",s.discover,s.encounter,s.quest,s.loot)
    story = story .. "\nYour tale uses the recent recorded adventure (up to 24 hours), with your race and class shaping its voice. You can edit it before sharing."
    if F.GetTaleDraft() then story = story .. "\nYou have a draft waiting; it will be kept." end
    local texts = {coin,table.concat(nearby,"\n\n"),story}
    local titles = {"I. Earn some coin", "II. While you're here", "III. Your journey"}
    local y = -14
    for i, card in ipairs(w.cards) do
        card.heading:SetPoint("TOPLEFT",16,y)
        card.heading:SetText(titles[i]); F.StyleCodexHeading(card.heading,theme,theme.ink)
        y = y - 29
        card.text:SetPoint("TOPLEFT",16,y); card.text:SetText(texts[i])
        F.Safe(card.text.SetTextColor,card.text,unpack(theme.ink))
        y = y - card.text:GetStringHeight() - 12
        card.action:SetPoint("TOPLEFT",16,y)
        y = y - 45
    end
    w.cards[1].action:SetText(page.known == 0 and "My professions" or "Review recipe")
    w.cards[2].action:SetText(#page.leads > 0 and "View first creature" or "Gold planner")
    w.cards[3].action:SetText(F.GetTaleDraft() and "Continue my tale" or "Write my tale")
    w.body:SetHeight(math.max(385,-y))
end

function F.OpenToday()
    if not F.db or F.Safe(InCombatLockdown) then return end
    if not window then
        local w = CreateFrame("Frame","ForeverCodexToday",UIParent,"BasicFrameTemplateWithInset")
        window = w; F.todayWindow = w
        w:SetSize(660,560); w.TitleText:SetText("Forever Codex")
        F.RegisterWindow("today",w,660,560)
        tinsert(UISpecialFrames,"ForeverCodexToday")
        if w.Inset then F.Safe(w.Inset.Hide,w.Inset) end
        w.cover = w:CreateTexture(nil,"BACKGROUND")
        w.cover:SetPoint("TOPLEFT",6,-26); w.cover:SetPoint("BOTTOMRIGHT",-6,6)
        w.heading = label(w,"GameFontNormalHuge",420); w.heading:SetPoint("TOPLEFT",24,-38); w.heading:SetText("Today's Page")
        w.subtitle = label(w,"GameFontHighlightSmall",560); w.subtitle:SetPoint("TOPLEFT",24,-72)
        F.CodexThemeButton(w,510,-40,125)
        w.paper = w:CreateTexture(nil,"BACKGROUND",nil,1)
        w.paper:SetPoint("TOPLEFT",20,-101); w.paper:SetPoint("BOTTOMRIGHT",-20,53)
        w.binding = w:CreateTexture(nil,"BACKGROUND",nil,2)
        w.binding:SetPoint("TOPLEFT",20,-101); w.binding:SetSize(5,406)
        w.scroll = CreateFrame("ScrollFrame",nil,w,"UIPanelScrollFrameTemplate")
        w.scroll:SetPoint("TOPLEFT",27,-108); w.scroll:SetSize(584,385); F.AddScrollCue(w.scroll)
        w.body = CreateFrame("Frame",nil,w.scroll); w.body:SetSize(570,385); w.scroll:SetScrollChild(w.body)
        w.cards = {}
        local actions = {
            function()
                local p = w.page; local entry = p.best or p.check
                if p.known == 0 then F.OpenProfessions()
                else F.OpenGoldPlanner(entry and entry.recipe.profession,entry and entry.id) end
            end,
            function() local lead=w.page.leads[1]; if lead then F.OpenBestiary(lead.creature.id) else F.OpenGoldPlanner() end end,
            F.TodayTale,
        }
        for i=1,3 do
            w.cards[i] = {heading=label(w.body,"GameFontNormalLarge",545),text=label(w.body,"GameFontHighlight",545),action=button(w.body,"",170,actions[i])}
        end
        local chapters={{"Bestiary",F.OpenBestiary},{"Professions",F.OpenProfessions},{"Gold planner",F.OpenGoldPlanner},{"Atlas",F.OpenAtlas},{"Refresh",F.RefreshToday}}
        for i, chapter in ipairs(chapters) do
            local action=chapter[2]
            local b=button(w,chapter[1],117,function() action() end); b:SetPoint("TOPLEFT",22+(i-1)*123,-520)
        end
        local grip=CreateFrame("Frame",nil,w)
        grip:SetPoint("TOPLEFT",8,-3); grip:SetPoint("TOPRIGHT",-30,-3); grip:SetHeight(24)
        grip:EnableMouse(true); grip:RegisterForDrag("LeftButton"); w:SetMovable(true)
        grip:SetScript("OnDragStart",function() if not F.Safe(InCombatLockdown) then w.dragging=true; w:StartMoving() end end)
        local function stop()
            if w.dragging then w:StopMovingOrSizing(); w.dragging=nil; F.SaveWindowPosition("today") end
        end
        grip:SetScript("OnDragStop",stop)
        w:SetScript("OnHide",function() stop(); F.ManagedHidden("today") end)
        local elapsed=0
        w:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=3 then elapsed=0; F.SupportCall("Today's Page refresh",F.RefreshToday) end
        end)
        w:Hide()
    end
    if F.ShowManaged("today") then F.RefreshToday() end
end
