local ic_bld = require('lib.icon_builder')
local ls_bld = require('lib.localised_string_builder')

local mod_name = 'bobs-machines-recipe-category-fix'

local do_debug = true 
debug = do_debug and function(input) log('[Debug]['..mod_name..']'..tostring(input)) end or function(_) end

local function jsonSerializeTable(val, name, depth)
    local indent = '    '
    depth = depth or 0

    local tmp = string.rep(indent, depth)

    if name then tmp = tmp .. '"' .. name .. '": ' end

    if type(val) == "table" then
        tmp = tmp .. "{" .. "\n"
        local add_comma = false
        for k, v in pairs(val) do
            if add_comma then
                tmp = tmp .. "," .. (not skipnewlines and "\n" or "")
            else
                add_comma = true
            end
            tmp =  tmp .. jsonSerializeTable(v, k, depth + 1)
        end
        tmp = tmp .. (not skipnewlines and "\n" or "")

        tmp = tmp .. string.rep(indent, depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[unserializable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

--- returns true if `the_list` contains `value`
---@param the_list any[]
---@param value any
---@return boolean
local function list_contains(the_list,value)
    for _, list_item in ipairs(the_list) do
        if list_item == value then
            return true
        end
    end
    return false
end

---Tries to get the LocalisedString of fluid
---@param name string fluid data name
---@return data.LocalisedString?
local function get_fluid_localised_name(name)
    local fluid = data.raw["fluid"][name]
    if not fluid then return end
    if fluid.localised_name then
        return fluid.localised_name
    end
    local type_name = "fluid"
    return {type_name.."-name."..name}
end
---Tries to get the LocalisedString of item
---@param name string item data name
---@return data.LocalisedString?
local function get_item_localised_name(name)
    local item = data.raw["item"][name]
    if not item then return end
    if item.localised_name then
        return item.localised_name
    end
    local type_name = "item"
    return {type_name.."-name."..name}
end

--- Replaces `ingredient_name` with `replace_name` based on `ratio`
---@param recipe data.RecipePrototype
---@param ingredient_name string ingredient being replaced
---@param replace_name string ingredient to replace with
---@param ratio number ratio of replacing to replaced ingredient
---@return data.RecipePrototype
local function replace_ingredient(recipe, ingredient_name, replace_name, ratio)
    if not recipe or not ingredient_name or not replace_name then
        error('replace_ingredient was given bad data')
        return
    end
    ratio = ratio or 1.0
    local new_ingredients = {}
    for i, ingredient in ipairs(recipe.ingredients or {}) do
        local ingredient_info = table.deepcopy(ingredient)
        if ingredient.name == ingredient_name then
            ingredient_info.name = replace_name
            ingredient_info.amount = math.floor(ingredient_info.amount * ratio)
        end
        new_ingredients[#new_ingredients+1] = ingredient_info
    end
    recipe.ingredients = new_ingredients
    return recipe
end

---Adds `crafting_category_id` to the recipe's `additional_categories` if the id exists
---@param recipe data.RecipePrototype
---@param crafting_category_id string
---@return data.RecipePrototype
local function add_crafting_category_if_exists(recipe, crafting_category_id)
    if data.raw["recipe-category"][crafting_category_id] == nil then
        return recipe
    end
    if recipe.additional_categories == nil then
        recipe.additional_categories = {}
    end
    if list_contains(recipe.additional_categories,crafting_category_id) then
        return recipe
    end
    recipe.additional_categories[#recipe.additional_categories+1] = crafting_category_id
    return recipe
end

--- Reads recipe to make a new recipe if it exists, assumes basic-crushing exist
---@param recipe data.RecipePrototype
---@return data.RecipePrototype
local function make_crushing_recipe_from_recipe(recipe, main_ingredient)
    local new_recipe = table.deepcopy(recipe)
    new_recipe.category = 'basic-crushing'
    new_recipe.additional_categories = nil
    new_recipe.hide_from_player_crafting = true

    local ingredients = new_recipe.ingredients

    local ing = ingredients[1]

    for index, value in ipairs(ingredients) do
        if value.name == main_ingredient then
            ing = value
        end
    end

    new_recipe.results[#new_recipe.results+1] = {
        type = "item",
        name = ing.name,
        amount = ing.amount,
        probability = 0.05,
        show_details_in_recipe_tooltip = false
    }

    new_recipe.name = mod_name..'-'..main_ingredient..'-crushing'
    new_recipe.localised_name = ls_bld.createLocale(
        mod_name..'.x_crushing',
        ls_bld.new(get_item_localised_name(ing.name)):addFallback(ls_bld.createLocale(mod_name..'.'..main_ingredient)):toLocalisedString()
    ):toLocalisedString()

    local ing_icon = ic_bld.getIconsFromProto(data.raw["item"][ing.name])
    local crushing_icon = ic_bld.makeSingleIconLayer(
        '__crushing-industry__/graphics/icons/generic-crushing.png',
        64, 4
    ):toIconBuilder()

    ing_icon:addIconsInfront(crushing_icon):setProtoIcons(new_recipe)

    return new_recipe
end

------ get settings ------
debug('Reading Settings ...')

-- Find Ingredients
debug('Finding Ingredients ...')
local wood = data.raw['item']['wood']
local woodchips = data.raw['item']['woodchips']
local woodpulp = data.raw['item']['bi-woodpulp']
local ash = data.raw['item']['ash'] or data.raw['item']['bi-ash']
local lumber = data.raw['item']['lumber']
local charcoal = data.raw['item']['charcoal']
local watercane = data.raw['item']['cut-water-cane']

------ Copy + Modify Recipes ------
debug('Adding Recipes ...')
local added_recipes = {}



-- woodpulp from woodchips
if mods['Bio_Industries_2'] and woodchips and woodpulp then
    local original_recipe_name = 'bi-woodpulp'
    local recipe = data.raw["recipe"][original_recipe_name]
    if recipe then
        recipe = table.deepcopy(recipe)
        recipe = replace_ingredient(recipe,'wood',woodchips.name)
        recipe.name = mod_name..'-woodpulp-from-woodchips'
        recipe.localised_name = ls_bld.createLocale(
            mod_name..'.x_from_y',
            ls_bld.new(get_item_localised_name(woodpulp.name)):addFallback(ls_bld.createLocale(mod_name..'.woodpulp')):toLocalisedString(),
            ls_bld.new(get_item_localised_name(woodchips.name)):addFallback(ls_bld.createLocale(mod_name..'.woodchips')):toLocalisedString()
        ):toLocalisedString()
        local pulp_icon = ic_bld.getIconsFromProto(recipe)
        if #pulp_icon.icons == 0 then
            pulp_icon = ic_bld.getIconsFromProto(woodpulp)
        end
        local chips_icon = ic_bld.getIconsFromProto(woodchips)
        pulp_icon:addIconsInfront(pulp_icon:formatTopRight(chips_icon)):setProtoIcons(recipe)

        recipe = add_crafting_category_if_exists(recipe,'woodworking')
        recipe = add_crafting_category_if_exists(recipe,'wood-processing-or-assembling')
        recipe = add_crafting_category_if_exists(recipe,'wood-processing-or-assembling-or-quality-assembling')

        added_recipes[#added_recipes+1] = {
            recipe=recipe,
            original_recipe=original_recipe_name,
        }
        data.extend({recipe})
    end
end

-- ash from woodchips
if mods['Bio_Industries_2'] and woodchips and ash then
    local original_recipe_name = 'bi-ash-1'
    local recipe = data.raw["recipe"][original_recipe_name]
    if recipe then
        recipe = table.deepcopy(recipe)
        recipe = replace_ingredient(recipe,'wood',woodchips.name, 1.5)
        recipe.name = mod_name..'-ash-from-woodchips'
        recipe.localised_name = ls_bld.createLocale(
            mod_name..'.x_from_y',
            ls_bld.new(get_item_localised_name(ash.name)):addFallback(ls_bld.createLocale(mod_name..'.ash')):toLocalisedString(),
            ls_bld.new(get_item_localised_name(woodchips.name)):addFallback(ls_bld.createLocale(mod_name..'.woodchips')):toLocalisedString()
        ):toLocalisedString()
        local ash = ic_bld.getIconsFromProto(ash)
        local chips_icon = ic_bld.getIconsFromProto(woodchips)
        ash:addIconsInfront(ash:formatTopRight(chips_icon)):setProtoIcons(recipe)

        added_recipes[#added_recipes+1] = {
            recipe=recipe,
            original_recipe=original_recipe_name,
        }
        data.extend({recipe})
    end
end

-- lumber from woodchips
if mods['lignumis'] and woodchips and lumber then
    local original_recipe_name = 'lumber'
    local recipe = data.raw["recipe"][original_recipe_name]
    if recipe then
        recipe = table.deepcopy(recipe)
        recipe = replace_ingredient(recipe,'wood',woodchips.name, 1.5)
        recipe.name = mod_name..'-lumber-from-woodchips'
        recipe.localised_name = ls_bld.createLocale(
            mod_name..'.x_from_y',
            ls_bld.new(get_item_localised_name(lumber.name)):addFallback(ls_bld.createLocale(mod_name..'.lumber')):toLocalisedString(),
            ls_bld.new(get_item_localised_name(woodchips.name)):addFallback(ls_bld.createLocale(mod_name..'.woodchips')):toLocalisedString()
        ):toLocalisedString()
        local lumber_icon = ic_bld.getIconsFromProto(recipe)
        if #lumber_icon.icons == 0 then
            lumber_icon = ic_bld.getIconsFromProto(lumber)
        end
        local chips_icon = ic_bld.getIconsFromProto(woodchips)
        lumber_icon:addIconsInfront(lumber_icon:formatTopRight(chips_icon)):setProtoIcons(recipe)

        added_recipes[#added_recipes+1] = {
            recipe=recipe,
            original_recipe=original_recipe_name,
        }
        data.extend({recipe})
    end
end

-- lumber from woodpulp
if mods['lignumis'] and woodpulp and lumber then
    local original_recipe_name = 'lumber'
    local recipe = data.raw["recipe"][original_recipe_name]
    if recipe then
        recipe = table.deepcopy(recipe)
        recipe = replace_ingredient(recipe,'wood',woodpulp.name, 2.0)
        recipe.name = mod_name..'-lumber-from-woodpulp'
        recipe.localised_name = ls_bld.createLocale(
            mod_name..'.x_from_y',
            ls_bld.new(get_item_localised_name(lumber.name)):addFallback(ls_bld.createLocale(mod_name..'.lumber')):toLocalisedString(),
            ls_bld.new(get_item_localised_name(woodpulp.name)):addFallback(ls_bld.createLocale(mod_name..'.woodpulp')):toLocalisedString()
        ):toLocalisedString()
        local lumber_icon = ic_bld.getIconsFromProto(recipe)
        if #lumber_icon.icons == 0 then
            lumber_icon = ic_bld.getIconsFromProto(lumber)
        end
        local pulp_icon = ic_bld.getIconsFromProto(woodpulp)
        lumber_icon:addIconsInfront(lumber_icon:formatTopRight(pulp_icon)):setProtoIcons(recipe)

        added_recipes[#added_recipes+1] = {
            recipe=recipe,
            original_recipe=original_recipe_name,
        }
        data.extend({recipe})
    end
end

-- Woodpulp to Charcoal From Wooden Industry
if mods['wood-industry'] and woodpulp and woodchips and charcoal then
    local original_recipe_name = 'charcoal'
    local recipe = data.raw["recipe"][original_recipe_name]
    if recipe then
        recipe = table.deepcopy(recipe)
        recipe = replace_ingredient(recipe,'woodchips',woodpulp.name, 1.5)
        recipe.name = mod_name..'-charcoal-from-woodpulp'
        recipe.localised_name = ls_bld.createLocale(
            mod_name..'.x_from_y',
            ls_bld.new(get_item_localised_name(charcoal.name)):addFallback(ls_bld.createLocale(mod_name..'.charcoal')):toLocalisedString(),
            ls_bld.new(get_item_localised_name(woodpulp.name)):addFallback(ls_bld.createLocale(mod_name..'.woodpulp')):toLocalisedString()
        ):toLocalisedString()
        local charcoal_icon = ic_bld.getIconsFromProto(charcoal)
        local pulp_icon = ic_bld.getIconsFromProto(woodpulp)
        charcoal_icon:addIconsInfront(charcoal_icon:formatTopRight(pulp_icon)):setProtoIcons(recipe)

        added_recipes[#added_recipes+1] = {
            recipe=recipe,
            original_recipe=original_recipe_name,
        }
        data.extend({recipe})
    end
end



-- Woodchip Crushing
if mods['Bio_Industries_2'] and woodchips and woodpulp and data.raw["recipe-category"]["basic-crushing"] then
    local original_recipe_name = 'bi-woodpulp'
    recipe = data.raw["recipe"][mod_name..'-woodpulp-from-woodchips']
    crushing_recipe = make_crushing_recipe_from_recipe(recipe,woodpulp.name)
    added_recipes[#added_recipes+1] = {
        recipe=crushing_recipe,
        original_recipe=original_recipe_name,
    }
    data.extend({crushing_recipe})
end


-- Watercane Crushing
if mods['wayward-seas'] and data.raw["recipe-category"]["basic-crushing"] and watercane then
    recipe = data.raw["recipe"]['water-cane-separation']
    crushing_recipe = make_crushing_recipe_from_recipe(recipe,watercane.name)
    added_recipes[#added_recipes+1] = {
        recipe=crushing_recipe,
        original_recipe=recipe.name,
    }
    data.extend({crushing_recipe})
end

-- Add lumbermill to Watercane Seperation machines
if mods['wayward-seas'] and data.raw["recipe"]['water-cane-separation'] and data.raw['recipe-category']['woodworking'] then
    local recipe = data.raw["recipe"]['water-cane-separation']
    recipe = add_crafting_category_if_exists(recipe,'woodworking')
    recipe = add_crafting_category_if_exists(recipe,'wood-processing-or-assembling')
    recipe = add_crafting_category_if_exists(recipe,'wood-processing-or-assembling-or-quality-assembling')
    data.extend({recipe})
end

-- TODO: Add Lumbermill to 'Resin From Woodpulp'

----- Add To Technologies ------
debug('Adding Recipe Unlocks To Technologies ...')
local technologies = data.raw["technology"]
for _, value in ipairs(added_recipes) do
    ---@type data.RecipePrototype
    local recipe = value.recipe
    ---@type string
    local original_recipe_name = value.original_recipe

    for name, technology in pairs(technologies) do
        local effects = technology.effects
        if effects then
            local has_recipe_unlock = false
            for _, effect in ipairs(effects) do
                if effect.type == 'unlock-recipe' and effect.recipe == original_recipe_name then
                    has_recipe_unlock = true
                end
            end
            if has_recipe_unlock then
                effects[#effects+1] = {
                    type='unlock-recipe',
                    recipe=recipe.name
                }
                technology.effects = effects
                data.raw["technology"][name] = technology
            end
        end
    end
end
