local mod = get_mod("moreoptions")
local options_view_settings = require("scripts/ui/views/options_view_settings")
-- WIP

-- Other possible stuff
--cb_matchmaking_region (PS4 Only)
--cb_safe_rect (Probs not needed)
--process_priority
--use_baked_enemy_meshes
--VolumetricFogQuality "off" volumetric_data_size = [ 0 0 0 ] volumetric_reprojection_amount = 0 or -0.875
--double_tap_dodge_threshold
--max_upload_speed
--particles_cast_shadows
--particles_distance_culling
--render_heatmap_enabled
--shadow_fade_in_speed
--shadow_fade_out_speed
--specular_aa
--ssr_high_quality
--static_sun_shadows
--profanity_check
--render_api
--async_fog
--async_ssr
--capture_cubemap
--clear_back_buffer_enabled
--clustered_shading_enabled
--debug_rendering
--hdr
--lens_flares_enabled
--lens_quality_enabled
--lens_quality_high_quality
--local_lights
--local_lights_distance_culling = false
--local_lights_distance_culling_cut_distance = 50
--local_lights_distance_culling_fade_distance = 30
--toggle_alternate_attack

------------------------------------------------------------------------------
-- Gameplay

-- ingame language changing
local cb_language = {
    setup = "cb_language_setup",
    saved_value = "cb_language_saved_value",
    callback = "cb_language",
    tooltip_text = "tooltip_music_volume",
    widget_type = "stepper"
}

--table.insert(options_view_settings.gameplay_settings_definition, 30, cb_language)

mod:hook_origin(OptionsView, "cb_language", function (self, content)
    local options_values = content.options_values
    local current_selection = content.current_selection
    self.changed_user_settings.language_id = options_values[current_selection]
    self:reload_language(self.changed_user_settings.language_id)
end)

mod:hook_origin(OptionsView, "reload_language", function (self, language_id)
    if Managers.package:has_loaded("resource_packages/strings", "boot") then
        Managers.package:unload("resource_packages/strings", "boot")
    end

	Localizer.set_language(language_id)
    Application.set_resource_property_preference_order(language_id)
    Managers.package:load("resource_packages/strings", "boot")
    --mod:echo("Loading package: " .. tostring(language_id))

    Managers.localizer = LocalizationManager:new()

    local function tweak_parser(tweak_name)
        if not LocalizerTweakData[tweak_name] then
            slot1 = "<missing LocalizerTweakData \"" .. tweak_name .. "\">"
        end

        return slot1
    end

    Managers.localizer:add_macro("TWEAK", tweak_parser)

    local function key_parser(input_service_and_key_name)
        local split_start, split_end = string.find(input_service_and_key_name, "__")
        slot3 = assert

        if split_start then
            slot4 = split_end
        end

        slot3(slot4, "[key_parser] You need to specify a key using this format $KEY;<input_service>__<key>. Example: $KEY;options_menu__back (note the dubbel underline separating input service and key")

        local input_service_name = string.sub(input_service_and_key_name, 1, split_start - 1)
        local key_name = string.sub(input_service_and_key_name, split_end + 1)
        local input_service = Managers.input:get_service(input_service_name)

        fassert(input_service, "[key_parser] No input service with the name %s", input_service_name)

        local key = input_service:get_keymapping(key_name)

        fassert(key, "[key_parser] There is no such key: %s in input service: %s", key_name, input_service_name)

        local device = Managers.input:get_most_recent_device()
        local device_type = InputAux.get_device_type(device)
        local button_index = nil

        for _, mapping in ipairs(key.input_mappings) do
            if mapping[1] == device_type then
                button_index = mapping[2]

                break
            end
        end

        local key_locale_name = nil

        if button_index then
            key_locale_name = device.button_name(button_index)

            if device_type == "keyboard" and not device.button_locale_name(button_index) then
                key_locale_name = key_locale_name
            end

            if device_type == "mouse" then
                key_locale_name = string.format("%s %s", "mouse", key_locale_name)
            end
        else
            local button_index = nil
            local default_device_type = "keyboard"

            for _, mapping in ipairs(key.input_mappings) do
                if mapping[1] == default_device_type then
                    button_index = mapping[2]

                    break
                end
            end

            if button_index then
                key_locale_name = Keyboard.button_name(button_index)

                if not Keyboard.button_locale_name(button_index) then
                    key_locale_name = key_locale_name
                end
            else
                key_locale_name = Localize(unassigned_keymap)
            end
        end

        return key_locale_name
    end

    Managers.localizer:add_macro("KEY", key_parser)
end)

------------------------------------------------------------------------------
-- Video
ItemRarityTexturesOptions = {
	{
		value = "default",
		text = mod:localize("default")
	},
	{
		value = "red",
		text = mod:localize("red")
	},
	{
		value = "blue",
		text = mod:localize("blue")
	},
	{
		value = "light_blue",
		text = mod:localize("light_blue")
	},
	{
		value = "green",
		text = mod:localize("green")
	},
}

local UIImprovements = get_mod("ui_improvements")
if UIImprovements then
	mod:hook_origin(UIImprovements, "overwrite_exotic_background", function(self)
		--[[if mod:is_enabled() and mod:get("alternative_exotic_background") then
			UISettings.item_rarity_textures.exotic = "icon_bg_exotic_2"
		else
			UISettings.item_rarity_textures.exotic = "icon_bg_exotic"
		end]]
		--[[if mod:is_enabled() and mod:get("alternative_exotic_background") then
			local ingame_ui = StateInGameRunning.ingame_ui
			local views = ingame_ui.views
			local options_view = views.options_view
			options_view:force_set_widget_value("item_rarity_textures_common", "ui_improvements_bg")
		else
			options_view:force_set_widget_value("item_rarity_textures_common", "default")
		end]]
	end)
	table.insert(ItemRarityTexturesOptions, 2, { -- add option if UIImprovements are enabled
		{
			value = "ui_improvements_bg",
			text = mod:localize("ui_improvements_bg")
		},
	})
end
--[[common = "icon_bg_common",
promo = "icon_bg_promo",
exotic = "icon_bg_exotic",
default = "icon_bg_default",
plentiful = "icon_bg_plentiful",
rare = "icon_bg_rare",
unique = "icon_bg_unique"]]

OptionsView.cb_item_rarity_textures_common_setup = function (self)
	local options = ItemRarityTexturesOptions
	local default_value = "default"
	local toggle_stationary_dodge = Application.user_setting("item_rarity_textures_common")

	if toggle_stationary_dodge then
		slot4 = 1
	else
		local selection = 2
	end

	if default_value then
		slot5 = 1
	else
		local default_option = 2
	end

	return selection, options, "item_rarity_textures_common", default_option
end

OptionsView.cb_item_rarity_textures_common_saved_value = function (self, widget)
	local item_rarity_textures_common = assigned(self.changed_user_settings.item_rarity_textures_common, Application.user_setting("item_rarity_textures_common"))
	slot3 = widget.content

	if item_rarity_textures_common then
		slot4 = 1
	else
		slot4 = 2
	end

	slot3.current_selection = slot4
end

OptionsView.cb_item_rarity_textures_common_jump = function (self, content)
	local options_values = content.options_values
	local current_selection = content.current_selection
	self.changed_user_settings.item_rarity_textures_common = options_values[current_selection]
	if current_selection ~= "default" then
		UISettings.item_rarity_textures.common = "icon_bg_item_" .. current_selection
	elseif current_selection == "ui_improvements_bg" then -- only add to exotic
		UISettings.item_rarity_textures.common = "icon_bg_exotic_2"
	else
		UISettings.item_rarity_textures.common = "icon_bg_common"
	end
end

local cb_item_rarity_textures_common_jump = {
    setup = "cb_item_rarity_textures_common_setup",
    saved_value = "cb_item_rarity_textures_common_saved_value",
    callback = "cb_item_rarity_textures_common",
    tooltip_text = "tooltip_item_rarity_textures_common",
    widget_type = "drop_down"
}

table.insert(options_view_settings.video_settings_definition, 1, cb_item_rarity_textures_common)

------------------------------------------------------------------------------
-- Gamepad

-- Deadzones
local cb_gamepad_left_dead_zone = {
    setup = "cb_gamepad_left_dead_zone_setup",
    saved_value = "cb_gamepad_left_dead_zone_saved_value",
    callback = "cb_gamepad_left_dead_zone",
    tooltip_text = "tooltip_gamepad_left_dead_zone",
    widget_type = "stepper"
}

--table.insert(options_view_settings.gamepad_settings_definition, 17, cb_gamepad_left_dead_zone)

local cb_gamepad_right_dead_zone = {
    setup = "cb_gamepad_right_dead_zone_setup",
    saved_value = "cb_gamepad_right_dead_zone_saved_value",
    callback = "cb_gamepad_right_dead_zone",
    tooltip_text = "tooltip_gamepad_left_dead_zone",
    widget_type = "stepper"
}

--table.insert(options_view_settings.gamepad_settings_definition, 18, cb_gamepad_right_dead_zone)

mod:hook_origin(OptionsView, "cb_gamepad_right_dead_zone_setup", function (self)
	local min = 0
	local max = 1
	local active_controller = Managers.input:get_most_recent_device() or Pad1.connected()
	local axis_id = Pad1.axis_id("right")

	local default_value = 0
	if Application.user_setting("gamepad_right_dead_zone") then
		local gamepad_left_dead_zone = Application.user_setting("gamepad_right_dead_zone")
	end

	local value = get_slider_value(min, max, gamepad_right_dead_zone)
	local default_dead_zone_value = Pad1.axis(axis_id)
	local dead_zone_value = default_dead_zone_value + value * (0.9 - default_dead_zone_value)

	if gamepad_right_dead_zone > 0 then
		local mode = Pad1.CIRCULAR

		Pad1.set_dead_zone(axis_id, mode, dead_zone_value)
	end

	return value, min, max, 1, "menu_settings_gamepad_right_dead_zone", default_value
end)

mod:hook_origin(OptionsView, "cb_gamepad_left_dead_zone_setup", function (self)
	local min = 0
	local max = 1
	local active_controller = Managers.input:get_most_recent_device() or Pad1.connected()
	local axis_id = Pad1.axis_id("left")

	local default_value = 0
	if Application.user_setting("gamepad_left_dead_zone") then
		local gamepad_left_dead_zone = Application.user_setting("gamepad_left_dead_zone")
	end

	local value = get_slider_value(min, max, gamepad_left_dead_zone)
	local default_dead_zone_value = Pad1.axis(axis_id)
	local dead_zone_value = default_dead_zone_value + value * (0.9 - default_dead_zone_value)

	if gamepad_left_dead_zone > 0 then
		local mode = Pad1.CIRCULAR

		Pad1.set_dead_zone(axis_id, mode, dead_zone_value)
	end

	return value, min, max, 1, "menu_settings_gamepad_left_dead_zone", default_value
end)

-- Left Handed localization Fix
--AlternatateGamepadSettings.left_handed.replace_gamepad_action_names = table.clone(AlternatateGamepadSettings.default.replace_gamepad_action_names)

--Keybinds
CurrentPlayerControllerKeymaps = table.clone(DefaultPlayerControllerKeymaps)
mod:hook_safe(OptionsView, "apply_changes", function (self, user_settings, render_settings, bot_spawn_priority, show_bot_spawn_priority_popup)
	local using_left_handed_option = assigned(user_settings.gamepad_left_handed, Application.user_setting("gamepad_left_handed"))
	local gamepad_keymaps = {
		PlayerControllerKeymaps = {
			xb1 = CurrentPlayerControllerKeymaps.xb1
		}
	}

	self:apply_gamepad_changes(gamepad_keymaps, using_left_handed_option)
end)

local GamepadKeys = {
	{
		value = "d_up",
	},
	{
		value = "d_down",
	},
	{
		value = "d_left",
	},
	{
		value = "d_right",
	},
	{
		value = "start",
	},
	{
		value = "back",
	},
	{
		value = "left_thumb",
	},
	{
		value = "right_thumb",
	},
	{
		value = "left_shoulder",
	},
	{
		value = "right_shoulder",
	},
	{
		value = "left_trigger",
	},
	{
		value = "right_trigger",
	},
	{
		value = "a",
	},
	{
		value = "b",
	},
	{
		value = "x",
	},
	{
		value = "y",
	},
}
for i = 1, #GamepadKeys, 1 do
	if not GamepadKeys[i].text then
		if Application.user_setting("gamepad_use_ps4_style_input_icons") then
			GamepadKeys[i].text = tostring(GamepadKeys[i].value) .. "_ps4"
		else
			GamepadKeys[i].text = tostring(GamepadKeys[i].value) .. "_xb1"
		end
	end
end
local GamepadAxis = {
	{
		text = "left_thumb_stick",
		value = "left",
	},
	{
		text = "right_thumb_stick",
		value = "right",
	}
}

OptionsView.cb_gamepad_action_one_setup = function (self)
	local options = GamepadKeys
	local default_value = MoreOptionsDefaultUserSettings.gamepad_keybinds.action_one
	local gamepad_action_one = Application.user_setting("gamepad_action_one")
	local selected_option = 1
	local default_option = nil

	for i = 1, #options, 1 do
		local option = options[i]

		if gamepad_action_one == option.value then
			selected_option = i
		end

		if default_value == option.value then
			default_option = i
		end
	end

	return selected_option, options, "menu_settings_gamepad_action_one", default_option
end

OptionsView.cb_gamepad_action_one_saved_value = function (self, widget)
	local gamepad_action_one = assigned(self.changed_user_settings.gamepad_action_one, Application.user_setting("gamepad_action_one"))
	local options_values = widget.content.options_values
	local selected_option = 1

	for i = 1, #options_values, 1 do
		if gamepad_action_one == options_values[i] then
			selected_option = i
		end
	end

	widget.content.current_selection = selected_option
end

OptionsView.cb_gamepad_action_one = function (self, content)
	local value = content.options_values[content.current_selection]
	self.changed_user_settings.gamepad_action_one = value
	local using_left_handed_option = assigned(self.changed_user_settings.gamepad_left_handed, Application.user_setting("gamepad_left_handed"))
	local gamepad_keymaps = CurrentPlayerControllerKeymaps.xb1
	for i = 1, #gamepad_keymaps, 1 do
		local current_key = gamepad_keymaps[i]
		if current_key[2] == value then
			current_key[2] = "unassigned_keymap"
		end
	end
	gamepad_keymaps.action_one[2] = value
	gamepad_keymaps.action_one_hold[2] = value
	gamepad_keymaps.action_one_release[2] = value

	local new_gamepad_keymaps = {
		PlayerControllerKeymaps = {
			xb1 = CurrentPlayerControllerKeymaps.xb1
		}
	}
	self:update_gamepad_layout_widget(new_gamepad_keymaps, using_left_handed_option)
end

local controller_keybinds = {
	{
		size_y = 30,
		widget_type = "empty"
	},
	{
		text = "settings_view_header_controller_keybinds",
		widget_type = "title"
	},
	{
		size_y = 10,
		widget_type = "empty"
	},
	{
		text = "settings_view_header_combat",
		widget_type = "title"
	},
	{
		setup = "cb_gamepad_action_one_setup",
		saved_value = "cb_gamepad_action_one_saved_value",
		callback = "cb_gamepad_action_one",
		tooltip_text = "tooltip_gamepad_action_one",
		widget_type = "stepper"
	},
}

--table.append(options_view_settings.gamepad_settings_definition, controller_keybinds)

--[[ Custom Controller Keybinds
local keybind_settings_definition = {
	{
		size_y = 30,
		widget_type = "empty"
	},
	{
		text = "settings_view_header_movement",
		widget_type = "title"
	},
	{
		keybind_description = "jump_1",
		widget_type = "keybind",
		actions = {
			"jump_1"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "jump_only",
		widget_type = "keybind",
		actions = {
			"jump_only"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "dodge",
		widget_type = "keybind",
		actions = {
			"dodge"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "crouch",
		widget_type = "keybind",
		actions = {
			"crouch",
			"crouching"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "walk",
		widget_type = "keybind",
		actions = {
			"walk"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		size_y = 30,
		widget_type = "empty"
	},
	{
		text = "settings_view_header_combat",
		widget_type = "title"
	},
	{
		keybind_description = "action_one",
		widget_type = "keybind",
		actions = {
			"action_one",
			"action_one_hold",
			"action_one_release",
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "action_two",
		widget_type = "keybind",
		actions = {
			"action_two",
			"action_two_hold",
			"action_two_release"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "weapon_reload",
		widget_type = "keybind",
		actions = {
			"weapon_reload_input",
			"weapon_reload_hold_input"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "action_three",
		widget_type = "keybind",
		actions = {
			"action_three",
			"action_three_hold",
			"action_three_release"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "input_active_ability",
		widget_type = "keybind",
		actions = {
			"action_career",
			"action_career_hold",
			"action_career_release"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "ping",
		widget_type = "keybind",
		actions = {
			"ping",
			"ping_hold",
			"ping_release"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "ping_only",
		widget_type = "keybind",
		actions = {
			"ping_only"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "social_wheel_only",
		widget_type = "keybind",
		actions = {
			"social_wheel_only",
			"social_wheel_only_hold",
			"social_wheel_only_release"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "interact",
		widget_type = "keybind",
		actions = {
			"interact",
			"interacting"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "wield_switch_1",
		widget_type = "keybind",
		actions = {
			"wield_switch_1"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "wield_3",
		widget_type = "keybind",
		actions = {
			"wield_3"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "wield_4",
		widget_type = "keybind",
		actions = {
			"wield_4"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "wield_5",
		widget_type = "keybind",
		actions = {
			"wield_5"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "wield_next",
		widget_type = "keybind",
		actions = {
			"wield_next"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "wield_prev",
		widget_type = "keybind",
		actions = {
			"wield_prev"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "character_inspecting",
		widget_type = "keybind",
		actions = {
			"character_inspecting"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		keybind_description = "action_inspect",
		widget_type = "keybind",
		actions = {
			"action_inspect",
			"action_inspect_hold",
			"action_inspect_release"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
	{
		size_y = 30,
		widget_type = "empty"
	},
	{
		text = "settings_view_header_multiplayer",
		widget_type = "title"
	},
	{
		keybind_description = "voip_push_to_talk",
		widget_type = "keybind",
		actions = {
			"voip_push_to_talk"
		},
		keymappings_key = "PlayerControllerKeymaps",
		keymappings_table_key = "xb1",
	},
}

table.append(options_view_settings.gamepad_settings_definition, keybind_settings_definition)]]

------------------------------------------------------------------------------
-- Motion Controllers
options_view_settings.motion_control_settings_definition = {
	{
		text = "settings_view_header_motion_control",
		widget_type = "title"
	},
	{
		size_y = 30,
		widget_type = "empty"
	},
	{
		setup = "cb_motion_controls_enabled_setup",
		saved_value = "cb_motion_controls_enabled_saved_value",
		callback = "cb_motion_controls_enabled",
		tooltip_text = "tooltip_motion_controls_enabled",
		widget_type = "slider"
	},
	{
		setup = "cb_motion_yaw_sensitivity_setup",
		saved_value = "cb_motion_yaw_sensitivity_saved_value",
		callback = "cb_motion_yaw_sensitivity",
		tooltip_text = "tooltip_motion_yaw_sensitivity",
		widget_type = "slider"
	},
	{
		setup = "cb_motion_pitch_sensitivity_setup",
		saved_value = "cb_motion_pitch_sensitivity_saved_value",
		callback = "cb_motion_pitch_sensitivity",
		tooltip_text = "tooltip_motion_pitch_sensitivity",
		widget_type = "slider"
	},
	{
		setup = "cb_disable_right_stick_look_setup",
		saved_value = "cb_disable_right_stick_look_saved_value",
		callback = "cb_disable_right_stick_look",
		tooltip_text = "tooltip_disable_right_stick_look",
		widget_type = "slider"
	},
	{
		setup = "cb_yaw_motion_enabled_setup",
		saved_value = "cb_yaw_motion_enabled_saved_value",
		callback = "cb_yaw_motion_enabled",
		tooltip_text = "tooltip_yaw_motion_enabled",
		widget_type = "slider"
	},
	{
		setup = "cb_pitch_motion_enabled_setup",
		saved_value = "cb_pitch_motion_enabled_saved_value",
		callback = "cb_pitch_motion_enabled",
		tooltip_text = "tooltip_pitch_motion_enabled",
		widget_type = "slider"
	},
	{
		setup = "cb_invert_yaw_enabled_setup",
		saved_value = "cb_invert_yaw_enabled_saved_value",
		callback = "cb_invert_yaw_enabled",
		tooltip_text = "tooltip_invert_yaw_enabled",
		widget_type = "slider"
	},
	{
		setup = "cb_invert_pitch_enabled_setup",
		saved_value = "cb_invert_pitch_enabled_saved_value",
		callback = "cb_invert_pitch_enabled",
		tooltip_text = "tooltip_invert_pitch_enabled",
		widget_type = "slider"
	},
}

--table.insert(options_view_settings.motion_control_settings_definition, (#options_view_settings.motion_control_settings_definition + 1), motion_control_settings_definition)
