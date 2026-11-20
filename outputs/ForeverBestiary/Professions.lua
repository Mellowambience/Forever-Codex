local _, F = ...
local function plain(value, limit)
    if not F.IsText(value) then return "" end
    value = value:gsub("[%c|]", " "):match("^%s*(.-)%s*$")
    local boundary = math.min(#value, limit)
    while boundary < #value and boundary > 0 do
        local nextByte = value:byte(boundary + 1)
        if nextByte < 128 or nextByte >= 192 then break end
        boundary = boundary - 1
    end
    return value:sub(1, boundary)
end

local function button(w, title, x, y, width, action)
    local b = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(title)
    b:SetScript("OnClick", action)
    return b
end

local function label(w, value, x, y)
    local text = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", x, y)
    text:SetText(value)
    return text
end

local function edit(w, x, y, width, limit)
    local field = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
    field:SetSize(width, 24)
    field:SetPoint("TOPLEFT", x, y)
    field:SetAutoFocus(false)
    field:SetMaxLetters(limit)
    field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return field
end

local function panel(key, name, title, width, height)
    local w = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    w:SetSize(width, height)
    F.RegisterWindow(key, w, width, height)
    local grip = CreateFrame("Frame", nil, w)
    grip:SetPoint("TOPLEFT", 8, -3)
    grip:SetPoint("TOPRIGHT", -30, -3)
    grip:SetHeight(24)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    w:SetMovable(true)
    grip:SetScript("OnDragStart", function()
        if F.Safe(InCombatLockdown) then return end
        w.codexDragging = true
        w:StartMoving()
    end)
    local function stopMoving()
        if not w.codexDragging then return end
        w:StopMovingOrSizing()
        w.codexDragging = nil
        F.SaveWindowPosition(key)
    end
    grip:SetScript("OnDragStop", stopMoving)
    w.stopCodexDrag = stopMoving
    w.TitleText:SetText(title)
    F.StyleCodexHeading(w.TitleText, F.GetCodexTheme())
    w:Hide()
    tinsert(UISpecialFrames, name)
    return w
end

function F.ReadCharacterProfessions()
    local rows, names = {}, {}
    local function add(name, rank, maximum, id)
        name = plain(name,56)
        if name == "" or names[name] then return end
        names[name] = true
        rows[#rows+1] = {name=name, rank=F.IsNumber(rank) and rank or nil, maximum=F.IsNumber(maximum) and maximum or nil, id=F.ValidID(id)}
    end
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local ok, first, second, archaeology, fishing, cooking, firstAid = pcall(GetProfessions)
        if ok then
            for _, index in pairs({first,second,archaeology,fishing,cooking,firstAid}) do
                if F.IsNumber(index) then
                    local read, name, _, rank, maximum, _, _, id = pcall(GetProfessionInfo,index)
                    if read then add(name,rank,maximum,id) end
                end
            end
        end
    end
    local count = F.Safe(GetNumSkillLines)
    if #rows == 0 and F.IsNumber(count) and type(GetSkillLineInfo) == "function" then
        local section
        for i=1,math.min(200,count) do
            local ok,name,header,_,rank,_,_,maximum = pcall(GetSkillLineInfo,i)
            if ok and F.IsText(name) and F.Public(header) then
                if header then
                    section = name == TRADE_SKILLS or name == PROFESSIONS or name == SECONDARY_SKILLS
                        or name == "Professions" or name == "Secondary Skills"
                elseif section and F.IsNumber(rank) and rank > 0 then add(name,rank,maximum) end
            end
        end
    end
    local api = C_TradeSkillUI
    if F.Safe(api and api.IsTradeSkillReady) and not F.Safe(api.IsTradeSkillLinked)
        and not F.Safe(api.IsTradeSkillGuild) and not F.Safe(api.IsNPCCrafting) then
        local info = F.Safe(api.GetBaseProfessionInfo)
        if type(info) == "table" and F.IsNumber(info.skillLevel) and info.skillLevel > 0 then
            add(info.professionName,info.skillLevel,info.maxSkillLevel,info.professionID)
        end
    end
    table.sort(rows,function(a,b) return a.name < b.name end)
    return rows
end

local professionWindow
local function rankText(row)
    if not row.rank then return "Rank unavailable" end
    return row.rank .. (row.maximum and ("/" .. row.maximum) or "")
end

local function professionAdvice(row)
    if row.id == 185 or row.name == "Cooking" then
        if row.maximum == 150 and row.rank and row.rank >= 125 then
            if F.Safe(UnitFactionGroup,"player") == "Horde" then
                return "Raise your cap to 225 with the Expert Cookbook. Wulan sells it in Shadowprey Village, Desolace (26.2, 69.8). You can also check the Auction House."
            elseif F.Safe(UnitFactionGroup,"player") == "Alliance" then
                return "Raise your cap to 225 with the Expert Cookbook. Shandrina sells it in Ashenvale (49.6, 67.0). You can also check the Auction House."
            end
            return "Use an Expert Cookbook to raise your cap to 225. Check the Auction House or your faction's cookbook vendor."
        elseif row.maximum == 225 and row.rank == 225 then
            return "For Artisan Cooking at character level 35, see Dirge Quikcleave in Gadgetzan, Tanaris, for Clamlette Surprise."
        end
    end
    if row.rank and row.maximum and row.rank >= row.maximum then
        return "At your current skill cap. Check your trainer or the next rank's unlock requirements."
    end
    return "Open the profession to see recipes and their skill-up colors."
end

function F.OpenProfessions()
    if F.Safe(InCombatLockdown) then return end
    if not professionWindow then
        local w = panel("professions","ForeverCodexProfessions","Forever Codex - My Professions",525,315)
        professionWindow = w
        local function render(row)
            w.selected = row
            local count = 0
            if row then
                for _, recipe in pairs(F.db.recipes) do
                    if recipe.profession == row.name and recipe.learnedBy[F.character] then count=count+1 end
                end
            end
            w.detail:SetText(row and (rankText(row) .. " skill   |   " .. count .. " recipes in Codex") or "")
            w.advice:SetText(row and professionAdvice(row) or "WoW hasn't exposed any profession ranks here. Open one of your profession windows, then use Refresh.")
            w.open:SetShown(row ~= nil and row.id ~= nil and type(C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) == "function")
        end
        w.render = render
        w.pick = F.Dropdown(w,"Choose a profession",20,-42,240,function() return w.names end,
            function(name) render(w.byName[name]) end)
        w.detail = label(w,"",20,-89)
        w.advice = label(w,"",20,-126)
        w.advice:SetWidth(477)
        w.advice:SetJustifyH("LEFT")
        button(w,"Refresh",20,-264,80,function() F.OpenProfessions() end)
        w.open = button(w,"Open recipes",107,-264,110,function()
            if not F.Safe(C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill,w.selected.id) then
                F.Message("Open this profession from your spellbook.")
            end
        end)
        button(w,"Import recipes",224,-264,120,function()
            local count = F.ScanRecipes(true)
            if not count then w.importStatus = "Open your own recipe window before importing."
            elseif count == 0 then w.importStatus = "No supported known recipes found in the open window."
            else w.importStatus = "Imported " .. count .. " recipes. Open Gold Planner to compare them." end
            F.OpenProfessions()
        end)
        w.status = label(w,"Open recipes, then Import recipes to fill the Gold Planner.",20,-184)
        w.status:SetWidth(477)
        button(w,"Gold planner",20,-224,126,function()
            F.OpenGoldPlanner(w.selected and w.selected.name)
        end)
        button(w,"Bestiary",400,-264,100,function()
            F.CreateUI()
            if F.ShowManaged("journal") then F.Render() end
        end)
        w:SetScript("OnHide",function() w.stopCodexDrag(); F.ManagedHidden("professions") end)
    end
    local w = professionWindow
    local rows = F.ReadCharacterProfessions()
    w.names, w.byName = {}, {}
    for _, row in ipairs(rows) do
        w.names[#w.names+1],w.byName[row.name] = row.name,row
    end
    local current = (w.selected and w.byName[w.selected.name]) or rows[1]
    w.pick:SetChoice(current and current.name or "Choose a profession")
    w.render(current)
    if w.importStatus then w.status:SetText(w.importStatus) end
    F.ShowManaged("professions")
end

local function freshPrice(id)
    local price, age = F.PriceQuote(id)
    if F.IsNumber(price) and price > 0 and F.IsNumber(age) and age >= 0 and age <= 2 then return price end
end

function F.EstimateCraft(recipe)
    local result = {missing={}, shopping={}, cost=0, buyCost=0}
    for _, id in ipairs(F.Keys(recipe.reagents)) do
        local needed = recipe.reagents[id]
        local owned = F.InventoryCount(id)
        if not F.IsNumber(owned) then result.inventoryUnknown = true; owned = 0 end
        local short = math.max(0, needed - owned)
        local price = freshPrice(id)
        if short > 0 then result.shopping[#result.shopping+1] = {id=id, count=short} end
        if price then
            result.cost = result.cost + price * needed
            result.buyCost = result.buyCost + price * short
        else
            result.missing[#result.missing+1] = id
        end
    end
    if recipe.partial or not recipe.output or not next(recipe.reagents) then
        result.reason = "Incomplete recipe costs or missing output."
        return result
    end
    local output = F.ItemInfo(recipe.output)
    if output.bindType ~= 0 and output.bindType ~= 2 then
        result.reason = "Output tradeability is unavailable or restricted."
        return result
    end
    local yield = F.ValidID(recipe.minimumYield)
    if not yield then
        result.reason = "Craft yield unavailable. Import this recipe again from your profession window."
        return result
    end
    result.yield = yield
    local price = freshPrice(recipe.output)
    if not price and recipe.reagents[recipe.output] == nil then result.missing[#result.missing+1] = recipe.output end
    if #result.missing == 0 then
        local cut = F.db.settings.ahCut == 15 and 15 or 5
        result.net = math.floor(price * yield * (100-cut)/100)
        result.margin = result.net - result.cost
    end
    return result
end

function F.CraftPriceTargets(recipe)
    local targets, seen = {}, {}
    local function add(id)
        id = F.ValidID(id)
        if id and not seen[id] then seen[id]=true; targets[#targets+1]=id end
    end
    if recipe then
        add(recipe.output)
        for _, id in ipairs(F.Keys(recipe.reagents)) do add(id) end
    end
    return targets
end

local goldWindow
local function signedMoney(amount)
    return (amount < 0 and "-" or "+") .. F.Money(math.abs(amount))
end

local function drawPlan(w, id)
    local recipe = w.recipes[id]
    w.selected = recipe and id or nil
    w.pin:SetShown(recipe ~= nil and not F.readOnly)
    if not recipe then
        w.detail:SetText("No recipes in this view. Open My professions, choose a profession, open its recipes, then click Import recipes.")
        w.detailBody:SetHeight(math.max(174,w.detail:GetStringHeight()+10))
        w.scroll:SetVerticalScroll(0)
        return
    end
    local plan = w.plans[id]
    w.pin:SetText(F.db.trackedRecipes[id] and "Unpin recipe" or "Pin recipe")
    local lines = {recipe.name}
    if plan.margin then
        lines[#lines+1] = "Estimated margin: " .. signedMoney(plan.margin)
        lines[#lines+1] = "Sale proceeds after AH cut (" .. plan.yield .. " output): " .. F.Money(plan.net)
        lines[#lines+1] = "All materials: " .. F.Money(plan.cost) .. "   |   Buy from AH: "
            .. (plan.inventoryUnknown and "bag count unavailable" or F.Money(plan.buyCost))
    elseif plan.reason then
        lines[#lines+1] = plan.reason
    else
        lines[#lines+1] = "Open the Auction House and click Check prices for these items:"
        for _, item in ipairs(plan.missing) do lines[#lines+1] = "  " .. F.ItemInfo(item).name end
    end
    lines[#lines+1] = ""
    lines[#lines+1] = #plan.shopping == 0 and "Materials for one craft are in your bags."
        or (plan.inventoryUnknown and "Materials to check (some bag counts unavailable)" or "Shopping list for one craft")
    for _, item in ipairs(plan.shopping) do lines[#lines+1] = "  " .. item.count .. " x " .. F.ItemInfo(item.id).name end
    w.detail:SetText(table.concat(lines,"\n"))
    w.detailBody:SetHeight(math.max(168,w.detail:GetStringHeight()+10))
    w.scroll:SetVerticalScroll(0)
end

function F.OpenGoldPlanner(profession, recipeID)
    if not F.db or F.Safe(InCombatLockdown) then return end
    if not goldWindow then
        local w = panel("goldPlanner","ForeverCodexGoldPlanner","Forever Codex - Gold Planner",570,408)
        goldWindow = w
        w.pick = F.Dropdown(w,"Choose recipe",20,-39,385,function() return w.order end,function(id)
            w.pick:SetText(w.recipes[id].name .. "  v")
            drawPlan(w,id)
        end)
        w.pick.FormatOption = function(_,id)
            local margin = w.plans[id].margin
            return w.recipes[id].name .. (margin and ("  |  " .. signedMoney(margin)) or "  |  No estimate")
        end
        button(w,"Check prices",415,-39,130,function()
            if not w.selected then w.status:SetText("Import and choose a recipe first."); return end
            local targets = F.CraftPriceTargets(w.recipes[w.selected])
            if #targets > 20 then w.status:SetText("This recipe has too many materials. Search items in the AH, then Recalculate."); return end
            F.FindSalePrices(targets, function(message) w.status:SetText(message) end,
                function() if w:IsShown() then F.OpenGoldPlanner(w.profession) end end)
        end)
        w.scroll = CreateFrame("ScrollFrame",nil,w,"UIPanelScrollFrameTemplate")
        w.scroll:SetPoint("TOPLEFT",20,-78)
        w.scroll:SetSize(512,174); F.AddScrollCue(w.scroll)
        w.detailBody = CreateFrame("Frame",nil,w.scroll)
        w.detailBody:SetSize(500,174)
        w.scroll:SetScrollChild(w.detailBody)
        w.detail = label(w.detailBody,"",0,0)
        w.detail:SetWidth(490)
        w.detail:SetJustifyH("LEFT")
        local note = label(w,"Estimates use recent AH listings and the recipe's minimum yield.\nOwned materials count at market price. Deposits and demand are excluded.",20,-262)
        note:SetWidth(385)
        note:SetJustifyH("LEFT")
        w.status = label(w,"At the AH: Check prices, review the estimate, then pin your recipe.",20,-303)
        w.status:SetWidth(525)
        w.status:SetJustifyH("LEFT")
        button(w,"Recalculate",415,-271,130,function() F.OpenGoldPlanner(w.profession) end)
        w.pin = button(w,"Pin recipe",20,-364,115,function()
            local id = w.selected
            if not id then return end
            F.TrackRecipe(id,F.db.trackedRecipes[id] and 0 or 1)
            drawPlan(w,id)
        end)
        button(w,"All professions",145,-364,125,function() F.OpenGoldPlanner() end)
        button(w,"My professions",280,-364,130,F.OpenProfessions)
        button(w,"Auction seller",420,-364,125,F.OpenSeller)
        w:SetScript("OnHide",function() w.stopCodexDrag(); F.ManagedHidden("goldPlanner") end)
    end
    local w = goldWindow
    w.profession, w.order, w.recipes, w.plans = profession, {}, {}, {}
    for id, recipe in pairs(F.db.recipes) do
        if recipe.learnedBy[F.character] and (not profession or recipe.profession == profession) then
            w.recipes[id], w.plans[id] = recipe,F.EstimateCraft(recipe)
            w.order[#w.order+1] = id
        end
    end
    table.sort(w.order,function(a,b)
        local left,right = w.plans[a].margin,w.plans[b].margin
        if left ~= right then
            if left == nil then return false end
            if right == nil then return true end
            return left > right
        end
        if w.recipes[a].name == w.recipes[b].name then return a < b end
        return w.recipes[a].name < w.recipes[b].name
    end)
    local id = w.recipes[recipeID] and recipeID or (w.recipes[w.selected] and w.selected or w.order[1])
    w.pick.value = id
    if id then w.pick:Enable() else w.pick:Disable() end
    w.pick:SetText(id and (w.recipes[id].name .. "  v") or "Choose recipe")
    drawPlan(w,id)
    F.ShowManaged("goldPlanner")
end

local feedback
function F.OpenFeedback()
    if F.Safe(InCombatLockdown) then return end
    if not feedback then
        local w = panel("feedback","ForeverCodexFeedback", "Forever Codex - Give feedback", 620, 300)
        local prompts = {"What were you trying to do?", "What happened?", "What would have helped?"}
        local fields = {}
        for i, prompt in ipairs(prompts) do
            label(w, prompt, 20, -38 - (i - 1) * 36)
            fields[i] = edit(w, 200, -31 - (i - 1) * 36, 395, 180)
        end
        label(w, "Copy your report and paste it into CurseForge comments.", 20, -151)
        local output = edit(w, 22, -178, 573, 700)
        output:SetMultiLine(true)
        output:SetHeight(62)
        button(w, "Prepare report", 20, -248, 125, function()
            local lines = {"Forever Codex " .. F.version}
            for i, prompt in ipairs(prompts) do lines[#lines + 1] = prompt .. " " .. plain(fields[i]:GetText(), 180) end
            output:SetText(table.concat(lines, "\n"))
            output:SetFocus()
            output:HighlightText()
        end)
        w:SetScript("OnHide", function()
            w.stopCodexDrag()
            for _, field in ipairs(fields) do field:ClearFocus() end
            output:ClearFocus()
            F.ManagedHidden("feedback")
        end)
        feedback = w
    end
    F.ShowManaged("feedback")
end
