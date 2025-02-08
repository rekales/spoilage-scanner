-- control.lua

-- gui options (perhaps no longer needed due to small options)
--  > invert freshness/spoilage (although easily implemented with arithmetic)
--  > choose inventory types to get info (perhaps no longer necessary)
--  > update interval override
--  > average/least/most mode switch

local function concat_table(t1, t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
end

local function update_target(entity_data)
    local combinator = entity_data.combinator
    if combinator.valid then
        local target_pos = combinator.position

        if combinator.direction == defines.direction.north then
            target_pos.y = target_pos.y - 1
        elseif combinator.direction == defines.direction.east then
            target_pos.x = target_pos.x + 1
        elseif combinator.direction == defines.direction.south then
            target_pos.y = target_pos.y + 1
        elseif combinator.direction == defines.direction.west then
            target_pos.x = target_pos.x - 1
        end
        
        local entities = combinator.surface.find_entities_filtered({
            position = target_pos, 
            type = {
                "container", 
                "logistic-container", 
                "assembling-machine", 
                "furnace", 
                "lab",
                "reactor",
                "boiler",
                "rocket-silo",
                "space-platform-hub",
                "cargo-landing-pad",
                "agricultural-tower"
            }
        })
        if #entities > 0 then
            entity_data.target = entities[1]
        else
            entity_data.target = nil
        end
    end
end

local function update_signals(entity_data)
    if (entity_data and entity_data.combinator and entity_data.combinator.valid) then
        if not entity_data.target then
            -- TODO: set light to red
            local control_behavior = entity_data.combinator.get_control_behavior()
            if control_behavior.sections_count == 0 then control_behavior.add_section() end
            control_behavior.get_section(1).filters = {}
            return
        elseif not entity_data.target.valid then
            entity_data.target = nil
            return
        end

        -- cache entity.type?
        local inv = {}
        if entity_data.target.type == "container" or entity_data.target.type == "logistic-container"then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.chest))
        elseif entity_data.target.type == "assembling-machine" then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.assembling_machine_input))
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.assembling_machine_output))
            if entity_data.target.burner then
                concat_table(inv, entity_data.target.get_inventory(defines.inventory.fuel))
            end
        elseif entity_data.target.type == "furnace" then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.furnace_source))
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.furnace_result))
        elseif entity_data.target.type == "lab" then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.lab_input))
        elseif entity_data.target.type == "reactor" or entity_data.target.type == "boiler" then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.fuel))
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.burnt_result))
        elseif entity_data.target.type == "rocket-silo" then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.rocket_silo_rocket))
        elseif entity_data.target.type == "space-platform-hub" then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.hub_main))
        elseif entity_data.target.type == "cargo-landing-pad" then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.cargo_landing_pad_main))
        elseif entity_data.target.type == "agricultural-tower" then
            concat_table(inv, entity_data.target.get_inventory(defines.inventory.assembling_machine_output))
        end

        local spoilages = {}
        local counts = {}
        for i=1, #inv do
            local itemStack = inv[i]
            if itemStack and itemStack.valid_for_read and itemStack.spoil_percent > 0 then
                local item_name = inv[i].name
                if not spoilages[item_name] then 
                    spoilages[item_name] = 0 
                    counts[item_name] = 0
                end

                spoilages[item_name] = spoilages[item_name] + inv[i].spoil_percent * inv[i].count
                counts[item_name] = counts[item_name] + inv[i].count
            end
        end

        -- calculate freshness
        if settings.global["spoilage-sensor-invert-output"].value then
            for k,v in pairs(spoilages) do
                spoilages[k] = math.ceil(v / counts[k] * 100)
            end
        else
            for k,v in pairs(spoilages) do
                spoilages[k] = math.ceil(100 - v / counts[k] * 100)
            end
        end

        -- set signals
        local control_behavior = entity_data.combinator.get_control_behavior()
        if control_behavior.sections_count == 0 then control_behavior.add_section() end
        local section = control_behavior.get_section(1)
        section.filters = {}
        local i = 1
        for k,v in pairs(spoilages)
        do
            section.set_slot(i, {value = {type="item", name=k, quality="normal"}, min=v})
            i = i + 1
        end
    end
end


-- TODO: needs better ticking alg (i.e. don't do everything at the same tick)
local function on_tick (event)
    if event.tick % settings.global["spoilage-sensor-signal-update-interval"].value == 0 then
        for k,v in pairs(storage.entity_data) do
            update_signals(v)
        end
    end

    if event.tick % settings.global["spoilage-sensor-signal-scan-interval"].value == 1 then
        for k,v in pairs(storage.entity_data) do
            update_target(v)
        end
    end
end

local function on_entity_created(event)
    local entity = event.entity
    local entity_data = {combinator=entity, target=nil, mode=2}
        table.insert(storage.entity_data, entity_data)
        update_target(entity_data)
end

local function on_entity_removed(event)
    for k,v in pairs(storage.entity_data) do
        if event.entity == v.combinator then
            table.remove(storage.entity_data, k)
        end
    end
end

local function on_entity_rotated(event)
    if not event.entity.name == "spoilage-scanner" then return end
    for k,v in pairs(storage.entity_data) do
        if event.entity == v.combinator then
            update_target(v)
        end
    end
end




local event_filter = {{ filter="name", name="spoilage-scanner" }}
script.on_event(defines.events.on_built_entity, on_entity_created, event_filter)
script.on_event(defines.events.on_robot_built_entity, on_entity_created, event_filter)
script.on_event(defines.events.on_entity_cloned, on_entity_created, event_filter)
script.on_event(defines.events.on_space_platform_built_entity, on_entity_created, event_filter)
script.on_event(defines.events.script_raised_built, on_entity_created, event_filter)
script.on_event(defines.events.script_raised_revive, on_entity_created, event_filter)
script.on_event(defines.events.on_player_mined_entity, on_entity_removed, event_filter)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, event_filter)
script.on_event(defines.events.on_space_platform_mined_entity, on_entity_removed, event_filter)
script.on_event(defines.events.on_entity_died, on_entity_removed, event_filter)
script.on_event(defines.events.script_raised_destroy, on_entity_removed, event_filter)
script.on_event(defines.events.on_player_rotated_entity, on_entity_rotated)
script.on_event(defines.events.on_player_flipped_entity, on_entity_rotated)
script.on_event(defines.events.on_tick, on_tick)


-- try using unit_number as key
script.on_init(function()
    storage.entity_data = {}
end)


require("gui")