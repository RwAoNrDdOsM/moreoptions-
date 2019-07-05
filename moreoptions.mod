return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`moreoptions` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("moreoptions", {
			mod_script       = "scripts/mods/moreoptions/moreoptions",
			mod_data         = "scripts/mods/moreoptions/moreoptions_data",
			mod_localization = "scripts/mods/moreoptions/moreoptions_localization",
		})
	end,
	packages = {
		"resource_packages/moreoptions/moreoptions",
	},
}
