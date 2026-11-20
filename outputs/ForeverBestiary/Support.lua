local _, F = ...
local failures, failureOrder, unavailable = {}, {}, {}
local overflow = 0
local sourceFiles = {
    ["Atlas.lua"] = true,
    ["AuctionPriceSearch.lua"] = true, ["AuctionSell.lua"] = true,
    ["Events.lua"] = true, ["ForeverBestiary.lua"] = true, ["Journal.lua"] = true,
    ["Layout.lua"] = true, ["Loot.lua"] = true, ["LootUI.lua"] = true,
    ["Prices.lua"] = true, ["Recipes.lua"] = true, ["Storage.lua"] = true,
    ["Support.lua"] = true, ["Tooltips.lua"] = true, ["UI.lua"] = true,
    ["Tales.lua"] = true, ["TaleVoices.lua"] = true, ["TaleWriter.lua"] = true, ["TalesUI.lua"] = true, ["Themes.lua"] = true,
    ["Viewer.lua"] = true, ["Widgets.lua"] = true,
}

function F.InitSupport()
    local saved = ForeverBestiarySupport
    F.safeMode = type(saved) == "table" and saved.safe == true
    ForeverBestiarySupport = {safe = F.safeMode}
end

function F.ToggleSafeMode()
    if not ForeverBestiarySupport then F.InitSupport() end
    ForeverBestiarySupport.safe = not ForeverBestiarySupport.safe
    local nextMode = ForeverBestiarySupport.safe and "on" or "off"
    F.Message("Safe mode will be " .. nextMode .. " after /reload. Safe mode pauses auction features and Codex item tooltips.")
end

function F.NoteUnavailableEvent(event)
    unavailable[event] = true
end

local function errorLocation(err)
    if not F.IsText(err) then return end
    local file, line = string.match(err, "([%a]+%.lua):(%d+)")
    if sourceFiles[file] and #line <= 6 then return file .. ":" .. line end
end

function F.SupportCall(component, callback, ...)
    local ok, err = pcall(callback, ...)
    if ok then return true end

    local location = errorLocation(err)
    local key = component .. (location and (" at " .. location) or "")
    if failures[key] then
        failures[key] = failures[key] + 1
    elseif #failureOrder < 16 then
        failures[key] = 1
        failureOrder[#failureOrder + 1] = key
        local handler = F.Safe(geterrorhandler)
        if type(handler) == "function" and F.IsText(err) then pcall(handler, err) end
        pcall(F.Message, "A Codex action failed. Use /fbc report for support details.")
    else
        overflow = overflow + 1
    end
    return false
end

function F.BuildSupportReport()
    local _, version, build, _, interface = pcall(GetBuildInfo)
    if not F.IsText(version) or not string.match(version, "^%d+%.%d+%.%d+$") then version = "unknown" end
    if not F.IsText(build) or not string.match(build, "^%d+$") then build = "unknown" end
    if not F.IsNumber(interface) then interface = "unknown" end
    local db = F.db
    local creatures = 0
    for _ in pairs(db and db.creatures or {}) do creatures = creatures + 1 end
    local lines = {
        "Forever Codex " .. F.version,
        "WoW " .. version .. " (build " .. build .. ", interface " .. interface .. ")",
        "Collection schema " .. tostring(db and db.version or "not loaded") .. " | creatures " .. creatures,
        "Collection " .. (F.readOnly and "read-only" or (db and "loaded" or "unavailable")),
        "Safe mode " .. (F.safeMode and "on" or "off"),
        "Discovery event " .. (F.killEvent and "registered" or "unavailable"),
        "Auction API " .. (C_AuctionHouse and "available" or "unavailable"),
    }
    local missing = {}
    for event in pairs(unavailable) do missing[#missing + 1] = event end
    table.sort(missing)
    if #missing > 0 then lines[#lines + 1] = "Unavailable events: " .. table.concat(missing, ", ") end
    lines[#lines + 1] = ""
    lines[#lines + 1] = #failureOrder == 0 and "No captured Codex errors this session." or "Captured Codex errors this session:"
    for _, key in ipairs(failureOrder) do
        lines[#lines + 1] = key .. " (" .. failures[key] .. ")"
    end
    if overflow > 0 then lines[#lines + 1] = "Additional errors: " .. overflow end
    return table.concat(lines, "\n")
end

local window

function F.OpenSupportReport()
    if F.Safe(InCombatLockdown) then
        F.Message("Open the support report after combat.")
        return
    end
    if not window then
        window = CreateFrame("Frame", "ForeverCodexSupportReport", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(540, 400)
        window:SetPoint("CENTER")
        window.TitleText:SetText("Forever Codex | Support report")
        F.RegisterWindow("support", window, 540, 400)
        tinsert(UISpecialFrames, "ForeverCodexSupportReport")

        local hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 16, -34)
        hint:SetText("Ctrl+C copies the selected report. Share it with your description of the issue.")
        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -55)
        scroll:SetPoint("BOTTOMRIGHT", -35, 16)
        local report = CreateFrame("EditBox", nil, scroll)
        report:SetSize(480, 310)
        report:SetFontObject(ChatFontNormal or GameFontHighlight)
        report:SetMultiLine(true)
        report:SetAutoFocus(false)
        report:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        report:SetScript("OnTextChanged", function(self, userInput)
            if userInput then self:SetText(self.reportText) end
        end)
        scroll:SetScrollChild(report)
        window.report = report
        window:SetScript("OnHide", function()
            report:ClearFocus()
            F.ManagedHidden("support")
        end)
        window:Hide()
    end
    local report = window.report
    report.reportText = F.BuildSupportReport()
    report:SetText(report.reportText)
    F.ShowManaged("support")
    if window:IsShown() then
        report:SetFocus()
        report:HighlightText()
    end
end
