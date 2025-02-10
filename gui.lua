local flib_gui = require "__flib__.gui"

-- TODO: investigate subtle issue of needing to press 'e' twice to close
-- TODO: docs
-- NOTE: ghost of destroyed entities have different unit_number than the original entity 
--   but accessible with ghost_unit_number
--   could also just reset data on destruction?
--   uses of spoilage scanner is liable for destruction so it would be best for it to be recoverable
--   could also just don't delete data but that might cause issues
-- NOTE: put numbers on the signal output slot?
-- TODO: autoupdating list of output signals gui element

local function on_gui_close_button(event)
	if not event.element then return end
	local player = game.get_player(event.player_index)
	if not player then return end
	if player.gui.screen["scanner-gui"] then
		player.gui.screen["scanner-gui"].destroy()

        -- TODO: add sounds
		-- if comb.name ~= "entity-ghost" then
		-- 	player.play_sound({ path = "open-close/combinator-close" })
		-- end
	end
end

---@param event EventData.on_gui_selection_state_changed
local function on_gui_mode_select(event)
    game.print("click")
    local elem = event.element
	if not elem then return end
    storage.entity_data[elem.tags.unit_number].mode = elem.selected_index -- NOTE: Use constants?
    game.print(serpent.line(storage.entity_data[elem.tags.unit_number]))
end

---@param entity LuaEntity name="spoilage-scanner"
---@return flib.GuiElemDef[]
local function circuit_subheader_gui_elems(entity)
    local elems = {}

    local red = entity.get_circuit_network(defines.wire_connector_id.circuit_red)
    local green = entity.get_circuit_network(defines.wire_connector_id.circuit_green)
    local red_id = red and red.valid and red.network_id or nil
    local green_id = green and green.valid and green.network_id or nil

    if not red_id and not green_id then
        table.insert(elems, {
            type = "label",
            style = "subheader_label",
            caption = { "gui.not-connected" }
        })
        return elems
    end
    table.insert(elems, {
        type = "label",
        style = "subheader_label",
        caption = { "gui-control-behavior.connected-to-network" }
    })
    if red_id then
        table.insert(elems, {
            type = "label",
            caption = { "", { "gui-control-behavior.red-network-id", red_id }, " [img=info]" },
            tooltip = { "", { "gui-control-behavior.circuit-network" }, ": ", tostring(red_id) }
        })
    end
    if green_id then
        table.insert(elems, {
            type = "label",
            caption = { "", { "gui-control-behavior.green-network-id", green_id }, " [img=info]" },
            tooltip = { "", { "gui-control-behavior.circuit-network" }, ": ", tostring(green_id) }
        })
    end

    return elems
end

local function on_gui_opened(event)
    local player = game.get_player(event.player_index)
    local entity = event.entity

    if event.gui_type ~= defines.gui_type.entity then return end
    if not entity or not entity.valid or entity.name ~= "spoilage-scanner" then return end
    if not player then return end
    if player.gui.screen["scanner-gui"] 
            and player.gui.screen["scanner-gui"].tags["unit_number"] == entity.unit_number then 
        player.opened = player.gui.screen["scanner-gui"]
        return
    end

    -- TODO: add data checks if entity is saved in storage

    local entity_data = storage.entity_data[entity.unit_number]
    game.print(serpent.line(entity_data))
    
    player.opened = nil

    local _, frame = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = "scanner-gui",
        tags = {unit_number = entity.unit_number},
        direction="vertical",
        elem_mods = {auto_center = true}
    })
    player.opened = frame

    



    local titlebar = {
        type = "flow",
        name = "titlebar",
        children = {
            {
                type = "label",
                style = "frame_title",
                caption = { "entity-name.spoilage-scanner" },
                elem_mods = { ignored_by_interaction = true },
            },
            {
                type = "empty-widget", 
                style = "flib_titlebar_drag_handle", 
                elem_mods = { ignored_by_interaction = true } 
            },
            {
                type = "sprite-button",
                style = "frame_action_button",
                mouse_button_filter = { "left" },
                sprite = "utility/close",
                hovered_sprite = "utility/close",
                name = "close-scanner-gui",
                handler = on_gui_close_button,
                tags = { unit_number = entity.unit_number },
            },
        },
    }



    local circuit_subheader = {
        type = "frame",
        style = "subheader_frame",
        style_mods = {
            horizontally_stretchable = true,
            horizontally_squashable = true,
            top_margin = -8,
            left_margin = -12,
            right_margin = -12
        },
        children = {
            {
                type = "flow",
                style = "player_input_horizontal_flow",
                children = circuit_subheader_gui_elems(entity)
            }
        }
    }


    local RED = "utility/status_not_working"
    local GREEN = "utility/status_working"
    local YELLOW = "utility/status_yellow"
    local STATUS_SPRITES = {
        [defines.entity_status.working] = GREEN,
        [defines.entity_status.normal] = GREEN,
        [defines.entity_status.ghost] = YELLOW,
        [defines.entity_status.no_power] = RED,
        [defines.entity_status.low_power] = YELLOW,
        [defines.entity_status.disabled_by_control_behavior] = RED,
        [defines.entity_status.disabled_by_script] = RED,
        [defines.entity_status.marked_for_deconstruction] = RED
    }
    local DEFAULT_STATUS_SPRITE = RED
    local GHOST_STATUS_SPRITE = YELLOW
    local STATUS_NAMES = {
        [defines.entity_status.working] = { "entity-status.working" },
        [defines.entity_status.normal] = { "entity-status.normal" },
        [defines.entity_status.ghost] = { "entity-status.ghost" },
        [defines.entity_status.no_power] = { "entity-status.no-power" },
        [defines.entity_status.low_power] = { "entity-status.low-power" },
        [defines.entity_status.disabled_by_control_behavior] = { "entity-status.disabled" },
        [defines.entity_status.disabled_by_script] = { "entity-status.disabled-by-script" },
        [defines.entity_status.marked_for_deconstruction] = { "entity-status.marked-for-deconstruction" }
    }
    local DEFAULT_STATUS_NAME = { "entity-status.disabled" }
    local GHOST_STATUS_NAME = { "entity-status.ghost" }

    -- TODO: margin too big
    local status_widget = {
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
                sprite = entity.name=="entity-ghost" and GHOST_STATUS_SPRITE or STATUS_SPRITES[entity.status] or DEFAULT_STATUS_SPRITE,
                style = "status_image",
                style_mods = { stretch_image_to_widget_size = true },
            },
            {
                type = "label",
                caption = entity.name=="entity-ghost" and GHOST_STATUS_NAME or STATUS_NAMES[entity.status] or DEFAULT_STATUS_NAME
            },
        },
    }

    local entity_preview = {
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
                    entity = entity
                },
            },
        },
    }

    local mode_select = {
        type = "flow",
        style = "player_input_horizontal_flow",
        children = {
            {
                type = "label",
                style = "caption_label",
                caption = "Mode of operation"
            },
            {
                type = "drop-down",
                tags = {unit_number = entity.unit_number},
                style_mods = {horizontally_stretchable = true},
                selected_index = entity_data.mode,
                items = {
                    "Average",
                    "Least spoiled",
                    "Most spoiled"
                },
                handler = {[defines.events.on_gui_selection_state_changed] = on_gui_mode_select} --TODO: fix event handling
            }
        }
    }

    local content_frame = {
        type = "frame",
        direction = "vertical",
        style = "entity_frame",
        style_mods = {
            minimal_width = 350,
        },
        children = {circuit_subheader, status_widget, entity_preview, mode_select}
    }

    flib_gui.add(frame, {titlebar, content_frame})


end

local function on_gui_selection_state_changed(event)

end


flib_gui.add_handlers({
    ["scanner-gui-close-button"] = on_gui_close_button,
    ["scanner-gui-mode_select"] = on_gui_mode_select,
})
flib_gui.handle_events()

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
