local _, F = ...
function F.CaptureRecipe(recipeID)
    local api=C_TradeSkillUI
    if not F.db or F.readOnly or not api or not api.GetRecipeInfo or not api.GetRecipeSchematic then return end
    if F.Safe(api.IsTradeSkillLinked) or F.Safe(api.IsTradeSkillGuild) or F.Safe(api.IsNPCCrafting) then return end
    local info=F.Safe(api.GetRecipeInfo,recipeID)
    if type(info)~="table" or not F.Public(info.learned) then return end
    if info.learned~=true then local old=F.db.recipes[recipeID]; if old then old.learnedBy[F.character]=nil end; return end
    local schema=F.Safe(api.GetRecipeSchematic,recipeID,false)
    if type(schema)~="table" or not F.Public(schema.reagentSlotSchematics) or type(schema.reagentSlotSchematics)~="table" or not F.IsText(info.name) then return end
    local reagents={}; local partial=false
    for _,slot in ipairs(schema.reagentSlotSchematics) do
        if not F.Public(slot) or type(slot)~="table" or not F.Public(slot.required) then
            partial=true
        elseif slot.required==true then
            local options=slot.reagents
            local option=F.Public(options) and type(options)=="table" and #options==1 and options[1]
            local item=F.Public(option) and type(option)=="table" and F.ValidID(option.itemID)
            local quantity=slot.quantityRequired
            if item and F.IsNumber(quantity) and quantity>0 and quantity==math.floor(quantity) then
                reagents[item]=math.min(1000000000,(reagents[item] or 0)+quantity)
            else
                partial=true
            end
        end
    end
    if next(reagents)==nil then return end
    local old=F.db.recipes[recipeID]
    local r={id=recipeID,name=info.name,reagents=reagents,output=F.ValidID(schema.outputItemID),learnedBy=old and old.learnedBy or {},partial=partial,checked=time(),requirements={}}
    r.minimumYield=F.ValidID(schema.quantityMin)
    local requirements=F.Safe(api.GetRecipeRequirements,recipeID)
    for _,requirement in ipairs(type(requirements)=="table" and requirements or {}) do if F.Public(requirement) and type(requirement)=="table" and F.IsText(requirement.name) then r.requirements[#r.requirements+1]=requirement.name end end
    r.learnedBy[F.character]=true
    local profession=F.Safe(api.GetProfessionInfoByRecipeID,recipeID)
    if type(profession)=="table" and F.IsText(profession.professionName) then r.profession=profession.professionName end
    F.db.recipes[recipeID]=r; return r
end
function F.ScanRecipes(silent)
    if not F.db or F.readOnly then return end
    local api=C_TradeSkillUI
    if not api or F.Safe(api.IsTradeSkillLinked) or F.Safe(api.IsTradeSkillGuild) or F.Safe(api.IsNPCCrafting) then return end
    local ids=F.Safe(api.GetAllRecipeIDs)
    if type(ids)~="table" and api then ids=F.Safe(api.GetFilteredRecipeIDs) end
    if type(ids)~="table" then if not silent then F.Message("Open your profession's recipe window first, then choose Update recipes.") end; return end
    local total=0
    for _,recipeID in ipairs(ids) do
        local id=F.ValidID(recipeID)
        if id and F.CaptureRecipe(id) then total=total+1 end
    end
    if not silent then F.Message("Updated "..total.." accessible known recipes. Other professions can be opened and updated separately.") end
    F.Refresh(); return total
end
-- Profession panels can emit a burst of list updates for one user action.
function F.QueueRecipeScan()
    if F.readOnly or F.recipeScanPending then return end
    if not C_Timer or not C_Timer.After then F.ScanRecipes(true); return end
    F.recipeScanPending=true
    C_Timer.After(.8,function()
        F.recipeScanPending=nil
        if F.SupportCall then F.SupportCall("recipes",F.ScanRecipes,true)
        else F.ScanRecipes(true) end
    end)
end
function F.MaterialsForCreature(r)
    local items={}; for _,l in pairs(r.loot) do items[l.itemID]=true end
    local ref=F.Reference and F.Reference(r.id); if ref then for _,l in ipairs(ref.loot) do items[l.itemID]=true end end
    return items
end
function F.RelatedRecipes(r)
    local materials=F.MaterialsForCreature(r); local recipes={}
    for _,recipe in pairs(F.db.recipes) do
        if recipe.learnedBy[F.character] then
            local related=F.db.trackedRecipes[recipe.id]~=nil
            for item in pairs(recipe.reagents) do if materials[item] then related=true end end
            if related then recipes[#recipes+1]=recipe end
        end
    end
    table.sort(recipes,function(a,b) return a.name<b.name end); return recipes
end
function F.TrackRecipe(recipeID,quantity)
    local r=F.db.recipes[recipeID]; if not r or not r.learnedBy[F.character] then F.Message("Update this character's known recipes first."); return end
    quantity=tonumber(quantity); F.db.trackedRecipes[recipeID]=quantity and quantity>0 and math.min(1000,math.floor(quantity)) or nil; F.Refresh()
end
function F.MaterialNeeds()
    local needs={}
    for recipeID,crafts in pairs(F.db.trackedRecipes) do local recipe=F.db.recipes[recipeID]; if recipe and recipe.learnedBy[F.character] then for item,n in pairs(recipe.reagents) do needs[item]=(needs[item] or 0)+n*crafts end end end
    return needs
end
