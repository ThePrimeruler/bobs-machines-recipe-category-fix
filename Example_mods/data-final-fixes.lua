local utils = require("lib.utils")

local machine_list = utils.constants.every_machine_list

local auto_create_tiers = require("prototypes.auto_create_tiers")

-- Recreate entities in data-final-fixes to fix discrepancies caused from other mods changing values
for _, machine_name in ipairs(machine_list) do
    auto_create_tiers.recreate_entities(machine_name)
end



-- if pelagos, then update flame throwers to match
if mods["pelagos"] and utils.setting_do_military_tiers then
    require('prototypes.pelagos.pelagos_data_final_fixes')
end



-- update lab science packs to match their tier 1
local function get_biolab_name(level)
    return utils.mod_name..'-biolab-'..level
end

local biolab = data.raw["lab"]["biolab"]
for tier = 2,utils.setting_num_tiers,1 do
    local machine = data.raw["lab"][get_biolab_name(tier)]
    if machine ~= nil then
        machine["inputs"] = biolab["inputs"]
    end
end

if utils.do_aop then
    local q_comp = data.raw["lab"]["aop-quantum-computer"]
    for tier = 2,utils.setting_num_tiers,1 do
        local machine = data.raw['lab'][utils.get_machine_name(tier,'aop-quantum-computer')]
        if machine ~= nil then
            machine["inputs"] = q_comp["inputs"]
        end
    end
end



-- update assembly machines to match their tier 1 crafting abilities (crafting_categories)
-- special case for electric lumber mills:
if utils.do_lignumis and utils.setting_lignumis_add_electric_lumber_mills then
    local lumber_mill = 'lumber-mill'
    local electric_lumber_mill = 'electric-lumber-mill'
    local lumber_mill_name = utils.get_machine_name(1,lumber_mill)
    local lumber_mill_entity_type, lumber_mill_proto = utils.find_entity_by_name(lumber_mill_name)
    local electric_lumber_mill_name = utils.get_machine_name(1,electric_lumber_mill)
    local electric_lumber_mill_entity_type, electric_lumber_mill_proto = utils.find_entity_by_name(electric_lumber_mill_name)

    if lumber_mill_proto.crafting_categories then
        data.raw[electric_lumber_mill_entity_type][utils.get_machine_name(1,electric_lumber_mill)].crafting_categories = lumber_mill_proto.crafting_categories
    end
end
for _, machine_name in ipairs(machine_list) do
    utils.debug('ensuring '..tostring(machine_name)..' crafting_categories match higher tiers')
    local real_name = utils.get_machine_name(1,machine_name)
    utils.debug('real_name is '..tostring(real_name))
    local entity_type, tier1_proto = utils.find_entity_by_name(real_name)
    if tier1_proto.crafting_categories and data.raw[entity_type][utils.get_machine_name(2,machine_name)] then
        for tier = 2,utils.setting_num_tiers,1 do
            local machine = data.raw[entity_type][utils.get_machine_name(tier,machine_name)]
            if machine ~= nil then
                machine.crafting_categories = tier1_proto.crafting_categories
            end
        end
    end
end

-- make sure item weights match their tier 1 variants (or if none specified, make 1 stack fit in a rocket)
for _, machine_name in ipairs(machine_list) do
    utils.debug('ensuring '..tostring(machine_name)..' item weights match higher tiers')
    local tier_1_name = utils.get_machine_name(1,machine_name)
    utils.spam('tier_1_name is '..tostring(tier_1_name))
    local tier_1_item = data.raw["item"][tier_1_name]
    if tier_1_item == nil then
        utils.error('Failed To Find Item For "' .. tier_1_name .. '". Skipping Weight Update')
    else
        local t1_weight = tier_1_item.weight or math.floor(utils.measurements.ton/(tier_1_item.stack_size or 20.0)) -- get the item weight from the tier_1 item, or make it 1 stack
        for tier=2,utils.setting_num_tiers,1 do
            local tiered_name = utils.get_machine_name(tier,machine_name)
            utils.spam('tiered_name is '..tostring(tiered_name))

            local machine = data.raw["item"][tiered_name]
            if machine ~= nil then
                machine.weight = t1_weight
            end
        end
    end
end


-- look through technologies and entities for the base tier update the technology pre-requisite if it has been changed or made invalid
local technologies = data.raw["technology"]
local recipes = data.raw["recipe"]

local function is_technology_valid(tech)
    return tech and (not tech.hidden) and (tech.enabled ~= false)
end

-- TODO: Rewrite these functions
local function find_technology_unlocking_recipe(recipe_name)
    for tech_name, tech_data in pairs(technologies) do
        if tech_data.effects and is_technology_valid(tech_data) then
            for _, effect in ipairs(tech_data.effects) do
                if effect.type == 'unlock-recipe' and effect.recipe == recipe_name then
                    return tech_name, tech_data
                end
            end
        end
    end
    return nil, nil
end

local function get_replacement_prerequisite(old_prereq, current_tier, machine_name, tier1_tech_name)
    -- Direct upgrade chain replacement
    if not tier1_tech_name then debug('no tier1_tech_name')
    elseif current_tier == 2 and old_prereq == utils.get_machine_name(1, machine_name) then
        if is_technology_valid(technologies[tier1_tech_name]) then
            return tier1_tech_name
        end
    elseif current_tier >= 3 and old_prereq == utils.get_machine_name(current_tier-1, machine_name) then
        local tier2_tech = technologies[utils.get_machine_name(current_tier-1, machine_name)]
        if is_technology_valid(tier2_tech) then
            return tier2_tech.name
        end
    end

    -- Recipe-based replacement
    if recipes[old_prereq] then
        for tech_name, tech_data in pairs(technologies) do
            if tech_data.effects and is_technology_valid(tech_data) then
                for _, effect in ipairs(tech_data.effects) do
                    if effect.type == 'unlock-recipe' and effect.recipe == old_prereq then
                        return tech_name
                    end
                end
            end
        end
    end
    return nil
end

local function update_technology_prerequisites(tech, current_tier, machine_name, tier1_tech_name)
    if not tech.prerequisites or #tech.prerequisites == 0 then return end
    
    local valid_prerequisites = {}
    local needs_update = false
    
    for _, prereq_name in ipairs(tech.prerequisites) do
        local prereq_tech = technologies[prereq_name]
        
        if is_technology_valid(prereq_tech) then
            table.insert(valid_prerequisites, prereq_name)
        else
            needs_update = true
            utils.debug("Prerequisite " .. prereq_name .. " is invalid for " .. tech.name)
            
            local replacement = get_replacement_prerequisite(prereq_name, current_tier, machine_name, tier1_tech_name)
            if replacement then
                table.insert(valid_prerequisites, replacement)
                utils.debug("Using " .. replacement .. " as replacement for " .. prereq_name)
            else
                utils.warning("No replacement found for prerequisite \"" .. prereq_name .. "\" in " .. tech.name .. " removing it.")
                utils.table_remove_by_value(valid_prerequisites, prereq_name)
            end
        end
    end
    
    if needs_update then
        if #valid_prerequisites > 0 then
            tech.prerequisites = valid_prerequisites
            utils.debug("Updated prerequisites for " .. tech.name .. ": " .. table.concat(valid_prerequisites, ", "))
        else
            tech.hidden = true
            tech.enabled = false
            utils.warning("No valid prerequisites found for " .. tech.name .. ", hiding technology")
        end
    end
end

for _, machine_name in ipairs(machine_list) do
    utils.debug('ensuring '..tostring(machine_name)..' technology match higher tiers')

    local tier1_recipe_name = utils.get_machine_name(1, machine_name)
    local tier1_tech_name, tier1_tech = find_technology_unlocking_recipe(tier1_recipe_name)

    if not tier1_tech_name then
        utils.error("Could not find tier 1 technology for machine: " .. machine_name)
        tier1_tech_name = ''
    end

    for tier = 2,utils.setting_num_tiers,1 do
        local tech_name = utils.get_machine_name(tier, machine_name)
        local technology = technologies[tech_name]

        if technology then
            update_technology_prerequisites(technology, tier, machine_name, tier1_tech_name)
        else
            utils.debug("Skipping tier " .. tier .. " for " .. machine_name .. " - technology not found")
        end
    end

    ::continue::
end








-- remove machine's next_upgrade field if it's hidden (was removed/other)
for _, machine_name in ipairs(machine_list) do
    utils.debug('verifying that '..tostring(machine_name)..' is still valid for the upgrade planner')

    -- --------------------------------------------------
    -- Tier 1
    -- --------------------------------------------------
    local real_name = utils.get_machine_name(1,machine_name)

    utils.debug('real_name is '..tostring(real_name))


    local entity_type, proto = utils.find_entity_by_name(real_name)
    -- utils.debug(utils.jsonSerializeTable(proto))
    if proto and proto.next_upgrade then
        utils.debug(real_name..' has a next_upgrade')

        if proto.fast_replaceable_group == nil or proto.fast_replaceable_group == ''  then
            utils.warning("Removing next_upgrade from " .. real_name .. " because it is doesn't have a fast_replaceable_group.")
            data.raw[entity_type][real_name].next_upgrade = nil
        end

        if proto.hidden then
            utils.warning("Removing next_upgrade from " .. real_name .. " because it is hidden.")
            data.raw[entity_type][real_name].next_upgrade = nil
        end

        tier_1_item = data.raw.item[real_name]
        if tier_1_item and tier_1_item.hidden then
            utils.warning("Removing next_upgrade from " .. real_name .. " because its item is hidden.")
            data.raw[entity_type][real_name].next_upgrade = nil
        end

    else
        if not proto then
            utils.spam(real_name..' not proto')
        elseif not proto.next_upgrade then
            utils.spam(real_name..' not next upgrade')
        else
            utils.spam(real_name..' something else')
        end
    end

    -- Tiers
    local bad = false
    for tier=2,utils.setting_num_tiers,1 do


        local real_name = utils.get_machine_name(tier,machine_name)

        utils.debug('real_name is '..tostring(real_name))


        local entity_type, proto = utils.find_entity_by_name(real_name)
        if proto == nil then
            bad = true
        end
        -- utils.debug(utils.jsonSerializeTable(proto))
        if bad then
            if proto ~= nil then
                data.raw[entity_type][real_name].next_upgrade = nil
            end
        elseif proto and proto.next_upgrade then
            utils.debug(real_name..' has a next_upgrade')

            if proto.fast_replaceable_group == nil or proto.fast_replaceable_group == ''  then
                utils.warning("Removing next_upgrade from " .. real_name .. " because it is doesn't have a fast_replaceable_group.")
                data.raw[entity_type][real_name].next_upgrade = nil
                bad = true
            end

            if proto.hidden then
                utils.warning("Removing next_upgrade from " .. real_name .. " because it is hidden.")
                data.raw[entity_type][real_name].next_upgrade = nil
                bad = true
            end

            tier_1_item = data.raw.item[real_name]
            if tier_1_item and tier_1_item.hidden then
                utils.warning("Removing next_upgrade from " .. real_name .. " because its item is hidden.")
                data.raw[entity_type][real_name].next_upgrade = nil
                bad = true
            end

        else
            if not proto then
                utils.spam(real_name..' not proto')
            elseif not proto.next_upgrade then
                utils.spam(real_name..' not next upgrade')
            else
                utils.spam(real_name..' something else')
            end
        end
    end
end







-- Ensure cloned machines inherit the UI categorization from tier 1
for _, machine_name in ipairs(machine_list) do
    local base_name = utils.get_machine_name(1, machine_name)
    local entity_type, base_proto = utils.find_entity_by_name(base_name)

    if base_proto then
        local base_item = data.raw.item[base_name]
        if base_item then
            for tier = 2,utils.setting_num_tiers do
                local tier_name = utils.get_machine_name(tier, machine_name)
                local _, tier_proto = utils.find_entity_by_name(tier_name)
                local tier_item = data.raw.item[tier_name]

                if tier_proto and tier_item then
                    -- update all subgroups and orders, just to be safe
                    tier_item.subgroup = base_item.subgroup or 'production-machine'
                    tier_item.order = (base_item.order or 'zzz')..'-b'..tier_name
                else
                    utils.debug("Skipping " .. tier_name .." (no prototype or item found for categorization)")
                end
            end
        else
            utils.debug("Base item for " .. base_name .. " not found, skipping UI fix.")
        end
    else
        utils.debug("Base prototype for " .. base_name .. " not found, skipping UI fix.")
    end
end





-- add turrets to their damage researches
tech_table_mapping = {
    ["physical%-projectile%-damage"] = utils.constants.physical_projectile_research_list,
    ["refined%-flammables"] = utils.constants.refined_flammables_research_list,
}
for key, val in pairs(tech_table_mapping) do -- loop through the damage technologies

    -- taken and modified from snouz_long_electric_gun_turret mod (https://github.com/snouz/snouz_long_electric_gun_turret)
    for _, tech in pairs(data.raw["technology"]) do 
        if tech.name and string.find(tech.name, key) and tech.effects then

            for _, machine_name in ipairs(val) do
                local start_tier = 2
                if utils.constants.added_machine_tier_1[machine_name] then
                    start_tier = 1
                end

                -- loop through each tier and add them to the techs
                local machine_tier1_name = utils.get_machine_name(1,machine_name)

                for level = start_tier,utils.setting_num_tiers, 1 do
                    local machine_tiered_name = utils.get_machine_name(level,machine_name)
                    _, proto = utils.find_entity_by_name(machine_tiered_name)
                    if proto then

                        local modifier = 0
                        for _, effect in pairs(tech.effects) do -- find a modifier in the tech so that our changes are consistent
                            if effect.type == "turret-attack" and effect.modifier then
                                if modifier == 0 then -- get first effect listed (hopefully more consistent)
                                    modifier = effect.modifier
                                end
                                if effect.turret_id == machine_tier1_name then -- if we found the tier1 turret then stop looking (match better)
                                    modifier = effect.modifier
                                    break
                                end
                            end
                        end
                        table.insert(tech.effects, 
                        {
                            type = "turret-attack",
                            turret_id = machine_tiered_name,
                            modifier = modifier * math.pow(1.5,level-1),
                        })
                    end
                end
            end
        end
    end
end



-- Finally, Fix Turbo Transport Belts (Merge Bobs and Space Age)
if utils.fix_bob_turbo_belts then

    local bob_turbo = {
        ["bob-turbo-transport-belt"]    = "turbo-transport-belt",
        ["bob-turbo-underground-belt"]  = "turbo-underground-belt",
        ["bob-turbo-splitter"]          = "turbo-splitter",
    }

    -- Remove Bob's turbo unlocks from logistics-4
    local log4 = data.raw.technology["logistics-4"]
    if log4 and log4.effects then
    local new_effects = {}
    for _, effect in ipairs(log4.effects) do
        if effect.type == "unlock-recipe" and bob_turbo[effect.recipe] then
        -- skip this unlock
        else
            table.insert(new_effects, effect)
        end
    end
    log4.effects = new_effects
    end

    -- Replace bob-turbo items in all recipes
    for _, recipe in pairs(data.raw.recipe) do
    local function replace_ingredients(ingredients)
        if ingredients then
        for i, ing in ipairs(ingredients) do
            local name = ing.name or ing[1]
            if bob_turbo[name] then
                if ing.name then
                    ing.name = bob_turbo[name]
                else
                    ing[1] = bob_turbo[name]
                end
            end
        end
        end
    end

    local function replace_results(results)
        if results then
        for i, res in ipairs(results) do
            local name = res.name or res[1]
            if bob_turbo[name] then
                if res.name then
                    res.name = bob_turbo[name]
                else
                    res[1] = bob_turbo[name]
                end
            end
        end
        end
    end

    if recipe.normal or recipe.expensive then
        if recipe.normal then
            replace_ingredients(recipe.normal.ingredients)
            replace_results(recipe.normal.results)
        end
        if recipe.expensive then
            replace_ingredients(recipe.expensive.ingredients)
            replace_results(recipe.expensive.results)
        end
        else
            replace_ingredients(recipe.ingredients)
            replace_results(recipe.results)
        end
    end

    -- Fix upgrade chains to point to turbo belts
    local upgrade_pairs = {
        ["transport-belt"]    = {"express-transport-belt", "turbo-transport-belt"},
        ["underground-belt"]  = {"express-underground-belt", "turbo-underground-belt"},
        ["splitter"]          = {"express-splitter", "turbo-splitter"},
    }

    for type, pair in pairs(upgrade_pairs) do
        local lower, target = pair[1], pair[2]
        if data.raw[type] and data.raw[type][lower] then
            data.raw[type][lower].next_upgrade = target
        end
    end

    -- Forward turbo belts to Bob's ultimate tier if present
    if data.raw["transport-belt"]["bob-ultimate-transport-belt"] then
        data.raw["transport-belt"]["turbo-transport-belt"].next_upgrade = "bob-ultimate-transport-belt"
        data.raw["underground-belt"]["turbo-underground-belt"].next_upgrade = "bob-ultimate-underground-belt"
        data.raw["splitter"]["turbo-splitter"].next_upgrade = "bob-ultimate-splitter"
    end
end
