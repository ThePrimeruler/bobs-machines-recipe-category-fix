local mod_name = 'bobs-machines-recipe-category-fix'

local do_debug = false
local function debug_log(message)
    if do_debug then
        log('[Debug]['..mod_name..']'..tostring(message))
    end
end

local function copy_crafting_categories(machine_type, source_name, target_name)
    local machine_table = data.raw[machine_type]
    if not machine_table then
        debug_log('Missing machine type '..tostring(machine_type)..' while copying categories.')
        return
    end

    local source = machine_table[source_name]
    local target = machine_table[target_name]

    if not source or not source.crafting_categories then
        debug_log('Missing crafting categories on source '..tostring(source_name)..'.')
        return
    end
    if not target then
        debug_log('Missing target prototype '..tostring(target_name)..'.')
        return
    end

    target.crafting_categories = table.deepcopy(source.crafting_categories)
end

if mods["bobassembly"] then
    local category_fixes = {
        {
            machine_type = "assembling-machine",
            source = "assembling-machine-3",
            targets = {
                "bob-assembling-machine-4",
                "bob-assembling-machine-5",
                "bob-assembling-machine-6",
            },
        },
        {
            machine_type = "assembling-machine",
            source = "chemical-plant",
            targets = {
                "bob-chemical-plant-2",
                "bob-chemical-plant-3",
                "bob-chemical-plant-4",
            },
        },
        {
            machine_type = "furnace",
            source = "steel-furnace",
            targets = {
                "bob-fluid-furnace",
            },
        },
        {
            machine_type = "furnace",
            source = "electric-furnace",
            targets = {
                "bob-electric-furnace-2",
                "bob-electric-furnace-3",
                "bob-multi-purpose-furnace-1",
                "bob-multi-purpose-furnace-2",
            },
        },
    }

    for _, fix in ipairs(category_fixes) do
        for _, target in ipairs(fix.targets) do
            copy_crafting_categories(fix.machine_type, fix.source, target)
        end
    end
end
