local flib_gui = require "__flib__.gui"

-- NOTE: ghost of destroyed entities have different unit_number than the original entity 
--   but accessible with ghost_unit_number
--   could also just reset data on destruction?
--   uses of spoilage scanner is liable for destruction so it would be best for it to be recoverable
--   could also just don't delete data but that might cause issues

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


flib_gui.add_handlers({
    ["scanner-gui-mode_select"] = on_mode_changed,
})
flib_gui.handle_events()

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)