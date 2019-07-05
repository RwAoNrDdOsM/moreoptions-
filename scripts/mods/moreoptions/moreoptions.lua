local mod = get_mod("moreoptions")
local options_view_settings = require("scripts/ui/views/options_view_settings")
--mod:dofile("scripts/mods/moreoptions/wip")

-- Functions needed from OptionsView
function assigned(a, b)
	if a == nil then
		return b
	else
		return a
	end
end
function get_slider_value(min, max, value)
	local range = max - min
	local norm_value = math.clamp(value, min, max) - min

	return norm_value / range
end

-- Let's me modify existing localiaztion strings
local vmf = get_mod("VMF")
mod:hook("Localize", function(func, text_id)
    local str = vmf.quick_localize(mod, text_id)
    if str then return str end
    return func(text_id)
end)

-- DefaultUserSettings for More Options Mod
MoreOptionsDefaultUserSettings = {
	toggle_stationary_dodge_jump = false,
	local_light_shadow_atlas_size = "extreme",
	sun_shadows_atlas_size = "extreme",
	lod_object_multiplier = 1,
	gamepad_keybinds = {
		action_one = "right_trigger"
	}
}
------------------------------------------------------------------------------
-- Gameplay

-- Disable Dodge/Jump Key if stationary Dodge isn't enabled
mod:hook_safe(OptionsView, "cb_toggle_stationary_dodge", function (self, content)
    local selected_index = content.current_selection
    local options_values = content.options_values
    local value = options_values[selected_index]
    if value == false then
		self:set_widget_disabled("cb_toggle_stationary_dodge_jump", true)
    else
        self:set_widget_disabled("cb_toggle_stationary_dodge_jump", false)
    end
end)

local cb_toggle_stationary_dodge = {
    setup = "cb_toggle_stationary_dodge_setup",
    saved_value = "cb_toggle_stationary_dodge_saved_value",
    callback = "cb_toggle_stationary_dodge",
    tooltip_text = "tooltip_toggle_stationary_dodge",
    widget_type = "stepper"
}

table.insert(options_view_settings.gameplay_settings_definition, 6, cb_toggle_stationary_dodge)

-- Option toggle stationary dodge on Jump/Dodge key
OptionsView.cb_toggle_stationary_dodge_jump_setup = function (self)
	local options = {
		{
			value = true,
			text = Localize("menu_settings_on")
		},
		{
			value = false,
			text = Localize("menu_settings_off")
		}
	}
	local default_value = MoreOptionsDefaultUserSettings.toggle_stationary_dodge_jump
	local toggle_stationary_dodge = Application.user_setting("toggle_stationary_dodge_jump")

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

	return selection, options, "menu_settings_toggle_stationary_dodge_jump", default_option
end

OptionsView.cb_toggle_stationary_dodge_jump_saved_value = function (self, widget)
	local toggle_stationary_dodge_jump = assigned(self.changed_user_settings.toggle_stationary_dodge_jump, Application.user_setting("toggle_stationary_dodge_jump"))
	slot3 = widget.content

	if toggle_stationary_dodge_jump then
		slot4 = 1
	else
		slot4 = 2
	end

    slot3.current_selection = slot4
	if not Application.user_setting("toggle_stationary_dodge") then
		local toggle_stationary_dodge = DefaultUserSettings.get("user_settings", "toggle_stationary_dodge")
	end

	local content = widget.content
	content.disabled = not toggle_stationary_dodge
end

OptionsView.cb_toggle_stationary_dodge_jump = function (self, content)
	local options_values = content.options_values
	local current_selection = content.current_selection
	self.changed_user_settings.toggle_stationary_dodge_jump = options_values[current_selection]
end

local cb_toggle_stationary_dodge_jump = {
    setup = "cb_toggle_stationary_dodge_jump_setup",
    saved_value = "cb_toggle_stationary_dodge_jump_saved_value",
    callback = "cb_toggle_stationary_dodge_jump",
    tooltip_text = "tooltip_toggle_stationary_dodge_jump",
    widget_type = "drop_down"
}

table.insert(options_view_settings.gameplay_settings_definition, 7, cb_toggle_stationary_dodge_jump)

-- Implementation of stationary Jump/Dodge key
local DOUBLE_TAP_DODGES = {
	move_left_pressed = Vector3Box(-Vector3.right()),
	move_right_pressed = Vector3Box(Vector3.right()),
	move_back_pressed = Vector3Box(-Vector3.forward())
}
mod:hook_origin(CharacterStateHelper, "check_to_start_dodge", function (unit, input_extension, status_extension, t)
	if status_extension:dodge_locked() or not status_extension:can_dodge(t) then
		return false
	end

	local movement_settings_table = PlayerUnitMovementSettings.get_movement_settings_table(unit)
	local input = CharacterStateHelper.get_movement_input(input_extension)
	local double_tap_dodge = input_extension.double_tap_dodge
	local start_dodge = false
	local dodge_direction = Vector3(0, 0, 0)
	local dodge_hold = input_extension:get("dodge_hold")
	local manual_dodge = input_extension:get("dodge")
	local dodge_input = manual_dodge or (input_extension:get("jump") and dodge_hold)
	local input_length = Vector3.length(input)
	local using_keyboard = not Managers.input:is_device_active("gamepad")
    local stationary_dodge = Application.user_setting("toggle_stationary_dodge")
    local stationary_dodge_jump = Application.user_setting("toggle_stationary_dodge_jump") -- Get stationary dodge on dodge/jump key

	if double_tap_dodge then
		for input, dir in pairs(DOUBLE_TAP_DODGES) do
			if input_extension:get(input) then
				local was_double_tap = input_extension:was_double_tap(input, t, Application.user_setting("double_tap_dodge_threshold"))

				for input, dir in pairs(DOUBLE_TAP_DODGES) do
					input_extension:clear_double_tap(input)
				end

				if was_double_tap then
					start_dodge = true
					dodge_direction = dir:unbox()

					break
				end

				input_extension:start_double_tap(input, t)

				break
			end
		end
	end

	if not start_dodge and dodge_input and input_extension.minimum_dodge_input < input_length then
		local normalized_input = input / input_length
		local x = normalized_input.x
		local y = normalized_input.y
		local abs_x = math.abs(x)
		local forward_ok = y <= 0 or (not using_keyboard and abs_x > 0.9239) or (manual_dodge and abs_x > 0.707)

		if forward_ok then
			start_dodge = true

			if y > 0 then
				dodge_direction = Vector3(math.sign(x), 0, 0)
			else
				dodge_direction = normalized_input
			end
		end
	elseif (dodge_input and stationary_dodge and stationary_dodge_jump) or (manual_dodge and stationary_dodge) then --Added not on jump/dodge key option
		start_dodge = true
		dodge_direction = -Vector3.forward()
	end

	if start_dodge then
		Managers.state.entity:system("play_go_tutorial_system"):register_dodge(dodge_direction)
		status_extension:add_fatigue_points("action_dodge")
		status_extension:set_dodge_locked(true)
		status_extension:add_dodge_cooldown()

		slot15 = ScriptUnit.extension(unit, "first_person_system")
	end

	return start_dodge, dodge_direction
end)

-- Tutorials
local cb_tutorials_enabled = {
    setup = "cb_tutorials_enabled_setup",
    saved_value = "cb_tutorials_enabled_saved_value",
    callback = "cb_tutorials_enabled",
    tooltip_text = "tooltip_tutorials_enabled",
    widget_type = "stepper"
}

table.insert(options_view_settings.gameplay_settings_definition, 30, cb_tutorials_enabled)


--Twitch Difficulty
local cb_twitch_difficulty = {
    setup = "cb_twitch_difficulty_setup",
    saved_value = "cb_twitch_difficulty_saved_value",
    callback = "cb_twitch_difficulty",
    tooltip_text = "tooltip_twitch_difficulty",
    widget_type = "slider"
}

table.insert(options_view_settings.gameplay_settings_definition, 36, cb_twitch_difficulty)

-- Twitch Difficulty Implementation
mod:hook_origin(TwitchGameMode, "cb_on_vote_complete", function (self, current_vote)
	local winning_template = TwitchVoteTemplates[current_vote.winning_template_name]
	local twitch_difficulty_setting = Application.user_setting("twitch_difficulty")
	local twitch_difficulty = (400 * ((twitch_difficulty_setting - 50)/100))
	--[[if twitch_difficulty > 0 then		-- mock up if you only want to allow 50 - 100 difficulty regardless if people modify the config
		twitch_difficulty = 0
	end]]
	self._funds = self._funds + winning_template.cost - twitch_difficulty -- i.e. if difficulty is 100 it add -200 to the funds, if the difficulty is 0 it add +200 to the funds
	self._used_vote_templates[winning_template.name] = NUM_ROUNDS_TO_DISABLE_USED_VOTES
	self._vote_keys[current_vote.vote_key] = nil
end)

------------------------------------------------------------------------------
-- Video

-- Video Adapter
local cb_adapter = {
    setup = "cb_adapter_setup",
    saved_value = "cb_adapter_saved_value",
    callback = "cb_adapter",
    tooltip_text = "tooltip_video_adapter",
    widget_type = "stepper"
}

table.insert(options_view_settings.video_settings_definition, 2, cb_adapter)

-- Local Light Quality and Local Light Atlas Size Seperation
-- Add cached_local_lights_shadow_atlas_size
LocalLightShadowQuality = {
	low = {
		local_lights_shadow_map_filter_quality = "low",
		--[[local_lights_shadow_atlas_size = {
			2048,
			2048
		}]]
	},
	medium = {
		local_lights_shadow_map_filter_quality = "medium",
		--[[local_lights_shadow_atlas_size = {
			2048,
			2048
		}]]
	},
	high = {
		local_lights_shadow_map_filter_quality = "high",
		--[[local_lights_shadow_atlas_size = {
			2048,
			2048
		}]]
	},
	--[[extreme = { 
		local_lights_shadow_map_filter_quality = "high", -- Removed since there is no difference between High and Extreme.
		local_lights_shadow_atlas_size = {
			2048,
			2048
		}
	}]]
}

mod:hook_origin(OptionsView, "cb_local_light_shadow_quality_setup", function (self)
    local options = {
        {
            value = "off",
            text = Localize("menu_settings_off")
        },
        {
            value = "low",
            text = Localize("menu_settings_low")
        },
        {
            value = "medium",
            text = Localize("menu_settings_medium")
        },
        {
            value = "high",
            text = Localize("menu_settings_high")
        },
       --[[ {
            value = "extreme",
            text = Localize("menu_settings_extreme") -- Removed for above reason
        }]]
    }
    local local_light_shadow_quality = Application.user_setting("local_light_shadow_quality")
    local deferred_local_lights_cast_shadows = Application.user_setting("render_settings", "deferred_local_lights_cast_shadows")
    local forward_local_lights_cast_shadows = Application.user_setting("render_settings", "forward_local_lights_cast_shadows")
    local selection = nil

    if not deferred_local_lights_cast_shadows or not forward_local_lights_cast_shadows then
        selection = 1
    elseif local_light_shadow_quality == "low" then
        selection = 2
    elseif local_light_shadow_quality == "medium" then
        selection = 3
    elseif local_light_shadow_quality == "high" then
        selection = 4
    elseif local_light_shadow_quality == "extreme" then
        selection = 5
    end

    return selection, options, "menu_settings_local_light_shadow_quality"
end)

LocalLightShadowAtlasSize = {
    lowest = {
		local_lights_shadow_atlas_size = {
			128,
			128
		}
	},
    low = {
		local_lights_shadow_atlas_size = {
			256,
			256
		}
	},
	medium = {
		local_lights_shadow_atlas_size = {
			512,
			512
		}
	},
	high = {
		local_lights_shadow_atlas_size = {
			1024,
			1024
		}
	},
	extreme = {
		local_lights_shadow_atlas_size = {
			2048,
			2048
		}
	}
}

OptionsView.cb_local_light_shadow_atlas_size_setup = function (self)
	local options = {
        {
			value = "lowest",
			text = "128x128"
		},
		{
			value = "low",
			text = "256x256"
		},
		{
			value = "medium",
			text = "512x512"
		},
		{
			value = "high",
			text = "1024x1024"
		},
		{
			value = "extreme",
			text = "2048x2048"
		}
	}
	local default_value = MoreOptionsDefaultUserSettings.local_light_shadow_atlas_size
	local local_light_shadow_atlas_size = Application.user_setting("local_light_shadow_atlas_size")
	local selection = nil

	if local_light_shadow_atlas_size == nil then
		local_light_shadow_atlas_size = default_value
	end

	if local_light_shadow_atlas_size == "lowest" then
		selection = 1
	elseif local_light_shadow_atlas_size == "low" then
		selection = 2
	elseif local_light_shadow_atlas_size == "medium" then
		selection = 3
	elseif local_light_shadow_atlas_size == "high" then
		selection = 4
	elseif local_light_shadow_atlas_size == "extreme" then
		selection = 5
	end

	return selection, options, "menu_settings_local_light_shadow_atlas_size"
end
OptionsView.cb_local_light_shadow_atlas_size_saved_value = function (self, widget)
	local local_light_shadow_atlas_size = assigned(self.changed_user_settings.local_light_shadow_atlas_size, Application.user_setting("local_light_shadow_atlas_size"))
	local selection = nil

	if local_light_shadow_atlas_size == "lowest" then
		selection = 1
	elseif local_light_shadow_atlas_size == "low" then
		selection = 2
	elseif local_light_shadow_atlas_size == "medium" then
		selection = 3
	elseif local_light_shadow_atlas_size == "high" then
		selection = 4
	elseif local_light_shadow_atlas_size == "extreme" then
		selection = 5
	end

	widget.content.current_selection = selection
end
OptionsView.cb_local_light_shadow_atlas_size = function (self, content, called_from_graphics_quality)
	local value = content.options_values[content.current_selection]
	local local_light_shadow_atlas_size = nil
	local_light_shadow_atlas_size = value

	self.changed_user_settings.local_light_shadow_atlas_size = local_light_shadow_atlas_size
	local local_light_shadow_atlas_size_settings = LocalLightShadowAtlasSize[local_light_shadow_atlas_size]

	for setting, key in pairs(local_light_shadow_atlas_size_settings) do
		self.changed_render_settings[setting] = key
	end

	if not called_from_graphics_quality then
		self:force_set_widget_value("graphics_quality_settings", "custom")
	end
end

local cb_local_light_shadow_atlas_size = {
    setup = "cb_local_light_shadow_atlas_size_setup",
    saved_value = "cb_local_light_shadow_atlas_size_saved_value",
    callback = "cb_local_light_shadow_atlas_size",
    tooltip_text = "tooltip_local_light_shadow_atlas_size",
    widget_type = "stepper"
}

table.insert(options_view_settings.video_settings_definition, 26, cb_local_light_shadow_atlas_size)

-- Sun Shadow Quality and Sun Shadow Atlas Size Seperation
SunShadowQuality = {
	low = {
		sun_shadow_map_filter_quality = "low",
		--[[sun_shadow_map_size = {
			1024,
			1024
		}]]
	},
	medium = {
		sun_shadow_map_filter_quality = "medium",
		--[[sun_shadow_map_size = {
			1024,
			1024
		}]]
	},
	high = {
		sun_shadow_map_filter_quality = "high",
		--[[sun_shadow_map_size = {
			2048,
			2048
		}]]
	},
	--[[extreme = {
		sun_shadow_map_filter_quality = "high", -- Removed as there is no difference from high
		sun_shadow_map_size = {
			2048,
			2048
		}
	}]]
}

mod:hook_origin(OptionsView, "cb_sun_shadows_setup", function (self)
    local options = {
        {
            value = "off",
            text = Localize("menu_settings_off")
        },
        {
            value = "low",
            text = Localize("menu_settings_low")
        },
        {
            value = "medium",
            text = Localize("menu_settings_medium")
        },
        {
            value = "high",
            text = Localize("menu_settings_high")
        },
        --[[{
            value = "extreme",
            text = Localize("menu_settings_extreme") -- Removed as there is no difference to high
        }]]
    }
    local sun_shadows = Application.user_setting("render_settings", "sun_shadows")
    local sun_shadow_quality = Application.user_setting("sun_shadow_quality")
    local selection = nil

    if sun_shadows then
        if sun_shadow_quality == "low" then
            selection = 2
        elseif sun_shadow_quality == "medium" then
            selection = 3
        elseif sun_shadow_quality == "high" then
            selection = 4
        elseif sun_shadow_quality == "extreme" then
            selection = 5
        end
    else
        selection = 1
    end

    return selection, options, "menu_settings_sun_shadows"
end)

--Add in static_sun_shadow_map_size
SunShadowAtlasSize = {
    lowest = {
		sun_shadow_map_size = {
			128,
			128
		}
	},
    low = {
		sun_shadow_map_size = {
			256,
			256
		}
	},
	medium = {
		sun_shadow_map_size = {
			512,
			512
		}
	},
	high = {
		sun_shadow_map_size = {
			1024,
			1024
		}
	},
	extreme = {
		sun_shadow_map_size = {
			2048,
			2048
		}
	}
}

OptionsView.cb_sun_shadows_atlas_size_setup = function (self)
	local options = {
		{
			value = "lowest",
			text = "128x128"
		},
		{
			value = "low",
			text = "256x256"
		},
		{
			value = "medium",
			text = "512x512"
		},
		{
			value = "high",
			text = "1024x1024"
		},
		{
			value = "extreme",
			text = "2048x2048"
		}
	}
	local default_value = MoreOptionsDefaultUserSettings.sun_shadows_atlas_size
	local sun_shadows_atlas_size = Application.user_setting("sun_shadows_atlas_size")
	local selection = nil

	if sun_shadows_atlas_size == nil then
		sun_shadows_atlas_size = default_value
	end
	
	if sun_shadows_atlas_size == "low" then
		selection = 2
	elseif sun_shadows_atlas_size == "medium" then
		selection = 3
	elseif sun_shadows_atlas_size == "high" then
		selection = 4
	elseif sun_shadows_atlas_size == "extreme" then
		selection = 5
	end

	return selection, options, "menu_settings_sun_shadows_atlas_size"
end
OptionsView.cb_sun_shadows_atlas_size_saved_value = function (self, widget)
	local sun_shadows_atlas_size = assigned(self.changed_user_settings.sun_shadows_atlas_size, Application.user_setting("sun_shadows_atlas_size"))
	local selection = nil

	if sun_shadows_atlas_size == "lowest" then
		selection = 1
	elseif sun_shadows_atlas_size == "low" then
		selection = 2
	elseif sun_shadows_atlas_size == "medium" then
		selection = 3
	elseif sun_shadows_atlas_size == "high" then
		selection = 4
	elseif sun_shadows_atlas_size == "extreme" then
		selection = 5
	end

	widget.content.current_selection = selection
end
OptionsView.cb_sun_shadows_atlas_size = function (self, content, called_from_graphics_quality)
	local options_values = content.options_values
	local current_selection = content.current_selection
	local sun_shadows_atlas_size = nil
	local value = options_values[current_selection]
	sun_shadows_atlas_size = value

	self.changed_user_settings.sun_shadows_atlas_size = sun_shadows_atlas_size
	local sun_shadows_atlas_size_settings = SunShadowAtlasSize[sun_shadows_atlas_size]

	for setting, key in pairs(sun_shadows_atlas_size_settings) do
		self.changed_render_settings[setting] = key
	end

	if not called_from_graphics_quality then
		self:force_set_widget_value("graphics_quality_settings", "custom")
	end
end

local cb_sun_shadows_atlas_size = {
    setup = "cb_sun_shadows_atlas_size_setup",
    saved_value = "cb_sun_shadows_atlas_size_saved_value",
    callback = "cb_sun_shadows_atlas_size",
    tooltip_text = "tooltip_sun_shadows_atlas_size",
    widget_type = "stepper"
}

table.insert(options_view_settings.video_settings_definition, 28, cb_sun_shadows_atlas_size)

-- Lod Quality Settings
mod:hook_origin(OptionsView, "cb_lod_quality_setup", function (self)
    local options = {
        {
            value = 0.6,
            text = Localize("menu_settings_low")
        },
        {
            value = 1,
            text = Localize("menu_settings_medium") -- modified medium to 1
        },
        {
            value = 2,
            text = Localize("menu_settings_high") -- added higher option
        }
    }
    local default_value = MoreOptionsDefaultUserSettings.lod_object_multiplier
    local default_option = nil

    if not Application.user_setting("render_settings", "lod_object_multiplier") then
        local saved_option = 1
    end

    local selected_option = 1

    for i = 1, #options, 1 do
        if saved_option == options[i].value then
            selected_option = i
        end

        if default_value == options[i].value then
            default_option = i
        end
    end

    return selected_option, options, "menu_settings_lod_quality", default_option
end)

-- Lod Quality
local lod = {
    setup = "cb_lod_quality_setup",
    saved_value = "cb_lod_quality_saved_value",
    callback = "cb_lod_quality",
    tooltip_text = "tooltip_lod_quality", --If you can get the proper tooltip locaize that'd be nice
    widget_type = "stepper"
}

table.insert(options_view_settings.video_settings_definition, 50, lod)

-- Lod Decoration Density
mod:hook_origin(OptionsView, "cb_decoration_density_setup", function (self)
	local options = {
		{
			value = 0,
			text = Localize("menu_settings_off")
		},
		{
			text = "25%",
			value = 0.25
		},
		{
			text = "50%",
			value = 0.5
		},
		{
			text = "75%",
			value = 0.75
		},
		{
			text = "100%",
			value = 1
		}
	}

	if not Application.user_setting("render_settings", "lod_decoration_density") then
		local saved_option = 1
	end

	local selected_option = 1

	for i = 1, #options, 1 do
		if saved_option == options[i].value then
			selected_option = i

			break
		end
	end

	return selected_option, options, "menu_settings_decoration_density"
end)
local lod_decoration_density = {
    setup = "cb_decoration_density_setup",
    saved_value = "cb_decoration_density_saved_value",
    callback = "cb_decoration_density",
    tooltip_text = "tooltip_decoration_density",
    widget_type = "stepper"
}

table.insert(options_view_settings.video_settings_definition, 51, lod_decoration_density)

------------------------------------------------------------------------------
-- Audio

-- SFX Volume (WIP)
local sfx_volume = {
    setup = "cb_sfx_bus_volume_setup",
    saved_value = "cb_sfx_bus_volume_saved_value",
    callback = "cb_sfx_bus_volume",
    tooltip_text = "tooltip_sfx_volume",
    widget_type = "slider"
}

table.insert(options_view_settings.audio_settings_definition, 4, sfx_volume)

-- Voice Volume (WIP)
local voice_volume = {
    setup = "cb_voice_bus_volume_setup",
    saved_value = "cb_voice_bus_volume_saved_value",
    callback = "cb_voice_bus_volume",
    tooltip_text = "tooltip_voice_volume",
    widget_type = "slider"
}

table.insert(options_view_settings.audio_settings_definition, 5, voice_volume)
------------------------------------------------------------------------------
-- Gamepad

-- Gamepad Layouts
-- Was crashing when trying to use alternate_4
--[[local keymap_override_1 = {
	toggle_input_helper = {},
	jump_1 = {
		"gamepad",
		"a",
		"pressed"
	},
	jump_2 = {},
	jump_only = {},
	dodge_1 = {
		"gamepad",
		"a",
		"held"
	},
	dodge_2 = {},
	dodge = {},
	crouch = {
		"gamepad",
		"b",
		"pressed"
	},
	crouching = {
		"gamepad",
		"b",
		"held"
	},
	walk = {},
	action_one = {
		"gamepad",
		"right_shoulder",
		"pressed"
	},
	action_one_hold = {
		"gamepad",
		"right_shoulder",
		"held"
	},
	action_one_release = {
		"gamepad",
		"right_shoulder",
		"released"
	},
	action_one_softbutton_gamepad = {
		"gamepad",
		"right_shoulder",
		"soft_button"
	},
	action_one_mouse = {},
	action_two = {
		"gamepad",
		"left_shoulder",
		"pressed"
	},
	action_two_hold = {
		"gamepad",
		"left_shoulder",
		"held"
	},
	action_two_release = {
		"gamepad",
		"left_shoulder",
		"released"
	},
	weapon_reload_input = {
		"gamepad",
		"x",
		"pressed"
	},
	weapon_reload_hold_input = {
		"gamepad",
		"x",
		"held"
	},
	action_three = {
		"gamepad",
		"right_thumb",
		"pressed"
	},
	action_three_hold = {
		"gamepad",
		"right_thumb",
		"held"
	},
	action_three_release = {
		"gamepad",
		"right_thumb",
		"released"
	},
	action_career = {
		"gamepad",
		"left_trigger",
		"pressed"
	},
	action_career_hold = {
		"gamepad",
		"left_trigger",
		"held"
	},
	action_career_release = {
		"gamepad",
		"left_trigger",
		"released"
	},
	ping = {
		"gamepad",
		"right_trigger",
		"pressed"
	},
	ping_hold = {
		"gamepad",
		"right_trigger",
		"held"
	},
	ping_release = {
		"gamepad",
		"right_trigger",
		"released"
	},
	ping_only = {},
	social_wheel_only = {},
	social_wheel_only_hold = {},
	social_wheel_only_release = {},
	interact = {
		"gamepad",
		"x",
		"pressed"
	},
	interacting = {
		"gamepad",
		"x",
		"held"
	},
	action_inspect = {
		"gamepad",
		"left_thumb",
		"pressed"
	},
	wield_switch = {},
	wield_switch_1 = {
		"gamepad",
		"y",
		"pressed"
	},
	wield_switch_2 = {},
	wield_1 = {},
	wield_2 = {},
	wield_3 = {
		"gamepad",
		"d_left",
		"pressed"
	},
	wield_4 = {
		"gamepad",
		"d_right",
		"pressed"
	},
	wield_5 = {
		"gamepad",
		"d_up",
		"pressed"
	},
	wield_6 = {},
	wield_7 = {},
	wield_8 = {},
	wield_9 = {},
	wield_0 = {},
	action_inspect_hold = {
		"gamepad",
		"left_thumb",
		"held"
	},
	action_inspect_release = {
		"gamepad",
		"left_thumb",
		"released"
	},
	wield_next = {},
	wield_prev = {},
	character_inspecting = {
		"gamepad",
		"d_down",
		"held"
	},
	active_ability_left_pressed = {},
	active_ability_right_pressed = {},
	active_ability_left_held = {},
	active_ability_right_held = {},
	active_ability_left_release = {},
	active_ability_right_release = {},
	wield_scroll = {},
	look_raw = {},
	look_raw_controller = {
		"gamepad",
		"right",
		"axis"
	},
	move_controller = {
		"gamepad",
		"left",
		"axis"
	},
	cursor = {
		"gamepad",
		"left",
		"axis"
	},
	angular_velocity = {},
	voip_push_to_talk = {},
	move_left = {},
	move_right = {},
	move_forward = {},
	move_back = {},
	move_left_pressed = {},
	move_right_pressed = {},
	move_forward_pressed = {},
	move_back_pressed = {},
	next_observer_target = {
		"gamepad",
		"a",
		"pressed"
	},
	previous_observer_target = {
		"gamepad",
		"b",
		"pressed"
	}
}

AlternatateGamepadKeymapsLayouts = {
	default = {
		PlayerControllerKeymaps = {
			xb1 = DefaultPlayerControllerKeymaps.xb1
		}
	},
	alternate_1 = {
		PlayerControllerKeymaps = {
			xb1 = keymap_override_1
		}
	},
	alternate_2 = {
		PlayerControllerKeymaps = {
			xb1 = keymap_override_2
		}
	},
	alternate_3 = {
		PlayerControllerKeymaps = {
			xb1 = keymap_override_3
		}
	},
	alternate_4 = {
		PlayerControllerKeymaps = {
			xb1 = keymap_override_7
		}
	}
}
AlternatateGamepadKeymapsLayoutsLeftHanded = {
	default = {
		PlayerControllerKeymaps = {
			xb1 = keymap_override_left
		}
	},
	alternate_1 = KeymapOverride4,
	alternate_2 = KeymapOverride5,
	alternate_3 = KeymapOverride6,
	alternate_4 = KeymapOverride8
}
AlternatateGamepadKeymapsOptionsMenu = {
	{
		text = "layout_default",
		value = "default"
	},
	{
		text = "layout_alternate_1",
		value = "alternate_1"
	},
	--[[{
		text = "layout_alternate_2",
		value = "alternate_2"
	},
	{
		text = "layout_alternate_3",
		value = "alternate_3"
	},
	{
		text = "layout_alternate_4",
		value = "alternate_4"
	}
}

local cb_gamepad_layout = {
    setup = "cb_gamepad_layout_setup",
    saved_value = "cb_gamepad_layout_saved_value",
    callback = "cb_gamepad_layout",
    tooltip_text = "tooltip_gamepad_layout",
    widget_type = "stepper"
}

table.insert(options_view_settings.gamepad_settings_definition, 16, cb_gamepad_layout)
]]
mod:hook_origin(OptionsView, "cb_gamepad_left_handed_enabled", function (self, content)
    local options_values = content.options_values
    local current_selection = content.current_selection
    self.changed_user_settings.gamepad_left_handed = options_values[current_selection]

    -- Crashes the game
    --local gamepad_layout = assigned(self.changed_user_settings.gamepad_layout, Application.user_setting("gamepad_layout"))
    --self:force_set_widget_value("gamepad_layout", gamepad_layout)
end)

-- Left Handed Mode
local cb_gamepad_left_handed_enabled = {
    setup = "cb_gamepad_left_handed_enabled_setup",
    saved_value = "cb_gamepad_left_handed_enabled_saved_value",
    callback = "cb_gamepad_left_handed_enabled",
    tooltip_text = "tooltip_gamepad_left_handed_enabled",
    widget_type = "stepper"
}

--table.insert(options_view_settings.gamepad_settings_definition, 17, cb_gamepad_left_handed_enabled)

--Rumble
local cb_gamepad_rumble_enabled = {
    setup = "cb_gamepad_rumble_enabled_setup",
    saved_value = "cb_gamepad_rumble_enabled_saved_value",
    callback = "cb_gamepad_rumble_enabled",
    tooltip_text = "tooltip_gamepad_rumble_enabled",
    widget_type = "stepper"
}

table.insert(options_view_settings.gamepad_settings_definition, 16, cb_gamepad_rumble_enabled)

--Rumble Implementation
mod:hook_safe(ControllerFeaturesImplementation, "add_effect", function (self, effect_name, params, user_id)
    if self._game_mode_ended or not Application.user_setting("gamepad_rumble_enabled") or (effect_name == "camera_shake" and self._is_in_inn) or script_data.honduras_demo or not Managers.input:is_device_active("gamepad") then
        return
    end

    --[[local user_id = user_id or Managers.account:user_id()

    if not user_id then
        mod:echo("2")
        return
    end]]

    --local controller = Managers.account:active_controller(user_id)
    local controller = Managers.input:get_most_recent_device() or Pad1.connected()

    if not controller or controller == nil then
        mod:echo("No Controller")
        return
    end
    
    local state_data = {}

    if ControllerFeaturesSettings[effect_name] then
        local effect = ControllerFeaturesSettings[effect_name]
        state_data.controller = controller

        effect.init(state_data, params)

        --[[state_data.effect_id = self._current_effect_id
        self._effects[user_id] = self._effects[user_id] or {}
        self._effects[user_id][self._current_effect_id] = {
            state_data = state_data,
            effect = effect
        }
        self._current_effect_id = self._current_effect_id + 1]]

        --mod:echo("Proccessed")
        return --self._current_effect_id - 1
    end
	mod:echo("Rumble effect not found: " .. tostring(effect_name))
	mod:echo("Please report this giving the rumble effect name as: '" .. tostring(effect_name) .. "'")
end)

ControllerFeaturesSettings = {
    rumble = {
        init = function(self)
            local left_rumble = Pad1.rumble_motor_id("left") 
            local right_rumble = Pad1.rumble_motor_id("right") 
            if Pad1.active() then
                Pad1.set_rumble_enabled(true) 
                Pad1.rumble_effect(left_rumble, ControllerFeaturesSettings.rumble.params)
                Pad1.rumble_effect(right_rumble, ControllerFeaturesSettings.rumble.params)
            end
        end,
        params = {
            attack = 0,
            attack_level = 0.7,
            decay = 0.2,
            release = 0,
            sustain = 0,
            sustain_level = 0,
        }
	},
	persistent_rumble = {
        init = function(self)
            local left_rumble = Pad1.rumble_motor_id("left") 
            local right_rumble = Pad1.rumble_motor_id("right") 
            if Pad1.active() then
                Pad1.set_rumble_enabled(true) 
                Pad1.rumble_effect(left_rumble, ControllerFeaturesSettings.rumble.params)
                Pad1.rumble_effect(right_rumble, ControllerFeaturesSettings.rumble.params)
            end
        end,
	},
	hit_rumble = {
        init = function(self)
            local left_rumble = Pad1.rumble_motor_id("left") 
            local right_rumble = Pad1.rumble_motor_id("right") 
            if Pad1.active() then
                Pad1.set_rumble_enabled(true) 
                Pad1.rumble_effect(left_rumble, ControllerFeaturesSettings.rumble.params)
                Pad1.rumble_effect(right_rumble, ControllerFeaturesSettings.rumble.params)
            end
        end,
	},
	camera_shake = {
        init = function(self)
            local left_rumble = Pad1.rumble_motor_id("left") 
            local right_rumble = Pad1.rumble_motor_id("right") 
            if Pad1.active() then
                Pad1.set_rumble_enabled(true) 
                Pad1.rumble_effect(left_rumble, ControllerFeaturesSettings.rumble.params)
                Pad1.rumble_effect(right_rumble, ControllerFeaturesSettings.rumble.params)
            end
        end,
	},
}

mod:hook_safe(OptionsView, "cb_gamepad_rumble_enabled", function (self, content)
	local options_values = content.options_values
	local current_selection = content.current_selection
    --self.changed_user_settings.gamepad_rumble_enabled = options_values[current_selection]
    if Managers.state.controller_features == nil then
        Managers.state.controller_features = ControllerFeaturesManager:new()
    end
end)

------------------------------------------------------------------------------
