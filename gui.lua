-- TODO: investigate subtle issue of needing to press 'e' twice to close

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

    player.opened = nil
    local frame = player.gui.screen.add{type="frame", name="scanner-gui", tags={unit_number=entity.unit_number}}
    frame.auto_center = true
    player.opened = frame

    frame.style.width = 448
    frame.style.height = 700
    frame.style.margin = 0


end

local function on_gui_selection_state_changed(event)

end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
