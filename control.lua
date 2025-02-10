-- control.lua

local flib_gui = require "__flib__.gui"

-- NOTE: ghost of destroyed entities have different unit_number than the original entity 
--   but accessible with ghost_unit_number
--   could also just reset data on destruction?
--   uses of spoilage scanner is liable for destruction so it would be best for it to be recoverable
--   could also just don't delete data but that might cause issues

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

        -- calculate freshness
        local signals = {}
        if entity_data.mode == 1 then  -- average
            local counts = {}
            for i=1, #inv do
                local itemStack = inv[i]
                if itemStack and itemStack.valid_for_read and itemStack.spoil_percent > 0 then
                    local item_name = itemStack.name
                    if not signals[item_name] then
                        signals[item_name] = 0
                        counts[item_name] = 0
                    end
                    signals[item_name] = signals[item_name] + itemStack.spoil_percent * itemStack.count
                    counts[item_name] = counts[item_name] + itemStack.count
                end
            end
            for k,v in pairs(signals) do
                signals[k] = math.ceil(100 - v / counts[k] * 100)
            end
        elseif entity_data.mode == 2 then  -- least
            for i=1, #inv do
                local itemStack = inv[i]
                if itemStack and itemStack.valid_for_read and itemStack.spoil_percent > 0 then
                    local item_name = itemStack.name
                    if not signals[item_name] then signals[item_name] = 0 end
                    if signals[item_name] < itemStack.spoil_percent then signals[item_name] = itemStack.spoil_percent end
                end
            end
            for k,v in pairs(signals) do
                signals[k] = math.ceil(100 - v * 100)
            end
        elseif entity_data.mode == 3 then  -- most
            for i=1, #inv do
                local itemStack = inv[i]
                if itemStack and itemStack.valid_for_read and itemStack.spoil_percent > 0 then
                    local item_name = itemStack.name
                    if not signals[item_name] then signals[item_name] = 100 end
                    if signals[item_name] > itemStack.spoil_percent then signals[item_name] = itemStack.spoil_percent end
                end
            end
            for k,v in pairs(signals) do
                signals[k] = math.ceil(100 - v * 100)
            end
        end

        -- set signals
        local control_behavior = entity_data.combinator.get_control_behavior()
        if control_behavior.sections_count == 0 then control_behavior.add_section() end
        local section = control_behavior.get_section(1)
        section.filters = {}
        local i = 1
        for k,v in pairs(signals)
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
    if storage.entity_data[entity.unit_number] then return end
    local entity_data = {combinator=entity, target=nil, mode=1}
    storage.entity_data[entity.unit_number] = entity_data
    update_target(entity_data)
end

local function on_entity_removed(event)
    storage.entity_data[event.entity.unit_number] = nil
end

local function on_entity_rotated(event)
    local entity = event.entity
    if not entity.name == "spoilage-scanner" then return end
    if not storage.entity_data[entity.unit_number] then return end
    update_target(storage.entity_data[entity.unit_number])
end


-- GUI SHIT STARTS HERE
local function on_mode_changed(event)
    local elem = event.element
    if not elem then return end

    if elem.name == "ssrb-ave" then
        elem.parent["ssrb-least" ].state = false
        elem.parent["ssrb-most" ].state = false
        storage.entity_data[elem.tags.unit_number].mode = 1  -- TODO: use constants
    elseif elem.name == "ssrb-least" then
        elem.parent["ssrb-ave" ].state = false
        elem.parent["ssrb-most" ].state = false
        storage.entity_data[elem.tags.unit_number].mode = 2
    elseif elem.name == "ssrb-most" then
        elem.parent["ssrb-ave" ].state = false
        elem.parent["ssrb-least" ].state = false
        storage.entity_data[elem.tags.unit_number].mode = 3
    end
end

local function on_gui_opened(event)
    local player = game.get_player(event.player_index)
    local entity = event.entity

    if event.gui_type ~= defines.gui_type.entity then return end
    if not entity or not entity.valid or entity.name ~= "spoilage-scanner" then return end
    if not player then return end
    if player.gui.relative["scanner-gui"] then player.gui.relative["scanner-gui"].destroy() end

    local entity_data = storage.entity_data[entity.unit_number]
    if not entity_data then return end
    game.print(serpent.line(storage.entity_data[entity.unit_number]))

    local _, frame = flib_gui.add(player.gui.relative, {
        type = "frame",
        name = "scanner-gui",
        tags = {unit_number = entity.unit_number},
        direction="vertical",
        elem_mods = {
            anchor = {
                gui = defines.relative_gui_type.constant_combinator_gui,
                position = defines.relative_gui_position.right
            }
        },
        children = {
            {
                type = "flow",
                name = "titlebar",
                children = {
                    {
                        type = "label",
                        style = "frame_title",
                        caption = { "gui.spoilage-sensor-title" },
                        elem_mods = { ignored_by_interaction = true },
                    },
                    {
                        type = "empty-widget", 
                        style = "flib_titlebar_drag_handle", 
                        elem_mods = { ignored_by_interaction = true } 
                    }
                },
            }
        }
    })

    local target_preview_flow = {
        type = "flow",
        direction = "vertical"
    }
    if entity_data.target then
        target_preview_flow.children = {
            {
                type = "flow",
                style = "flib_titlebar_flow",
                direction = "horizontal",
                style_mods = {
                    vertical_align = "center",
                    horizontally_stretchable = true,
                    bottom_padding = 4,
                },
                children = {
                    {
                        type = "sprite",
                        sprite = "utility/status_working",
                        style = "status_image",
                        style_mods = { stretch_image_to_widget_size = true },
                    },
                    {
                        type = "label",
                        caption = {"gui.spoilage-sensor-target"}
                    },
                },
            },
            {
                type = "frame",
                style = "deep_frame_in_shallow_frame",
                style_mods = {
                    minimal_width = 0,
                    horizontally_stretchable = true,
                    padding = 0,
                },
                children = {
                    { 
                        type = "entity-preview", 
                        style = "wide_entity_button",
                        elem_mods = {
                            entity = entity_data.target
                        },
                    },
                },
            }
        }
    else
        target_preview_flow.children = {
            {
                type = "flow",
                style = "flib_titlebar_flow",
                direction = "horizontal",
                style_mods = {
                    vertical_align = "center",
                    horizontally_stretchable = true,
                    bottom_padding = 4,
                },
                children = {
                    {
                        type = "sprite",
                        sprite = "utility/status_yellow",
                        style = "status_image",
                        style_mods = { stretch_image_to_widget_size = true },
                    },
                    {
                        type = "label",
                        caption = {"gui.spoilage-sensor-no-target"}
                    },
                },
            }
        }
    end

    local mode_flow = {
        type = "flow",
        direction = "vertical",
        children = {
            {
                type = "label",
                style = "caption_label",
                caption = "Mode of operation"  -- TODO: make localizable
            },
            {
                name = "ssrb-ave",
                type = "radiobutton",
                state = entity_data.mode==1,
                caption = { "gui.spoilage-sensor-average" },
                tags = {unit_number = entity.unit_number},
                handler = {[defines.events.on_gui_checked_state_changed] = on_mode_changed}
            },
            {
                name = "ssrb-least",
                type = "radiobutton",
                state = entity_data.mode==2,
                caption = { "gui.spoilage-sensor-least" },
                tags = {unit_number = entity.unit_number},
                handler = {[defines.events.on_gui_checked_state_changed] = on_mode_changed}
            },
            {
                name = "ssrb-most",
                type = "radiobutton",
                state = entity_data.mode==3,
                caption = { "gui.spoilage-sensor-most" },
                tags = {unit_number = entity.unit_number},
                handler = {[defines.events.on_gui_checked_state_changed] = on_mode_changed}
            }
        }
    }

    local content_frame = {
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding_and_vertical_spacing",
        style_mods = {minimal_width = 250},
        children = {target_preview_flow, { type = "line", style_mods = { top_padding = 4 } }, mode_flow}
    }
    flib_gui.add(frame, content_frame)
end

local function on_gui_closed(event)
    local player = game.get_player(event.player_index)
    local entity = event.entity

    if event.gui_type ~= defines.gui_type.entity then return end
    if not entity or not entity.valid or entity.name ~= "spoilage-scanner" then return end
    if not player then return end
    if player.gui.relative["scanner-gui"] then player.gui.relative["scanner-gui"].destroy() end
end


flib_gui.add_handlers({["scanner-gui-mode_select"] = on_mode_changed})
flib_gui.handle_events()

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
script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_tick, on_tick)


script.on_init(function()
    storage.entity_data = {}
end)