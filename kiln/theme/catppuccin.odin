package theme

import clay "lib:kiln/clay-odin"

// Catppuccin color schemes. Mocha/Macchiato/Frappe are dark, Latte is light.
Flavor :: enum {
	Mocha,
	Macchiato,
	Frappe,
	Latte,
}

// Subset of the official Catppuccin palette that is needed to build `Colors`.
@(private)
Palette :: struct {
	base, mantle:                 clay.Color,
	surface0, surface1, surface2: clay.Color,
	overlay0:                     clay.Color,
	text, subtext0:               clay.Color,
	mauve, blue, red:             clay.Color,
}

@(private)
PALETTES := [Flavor]Palette {
	.Mocha = {
		base = {30, 30, 46, 255},
		mantle = {24, 24, 37, 255},
		surface0 = {49, 50, 68, 255},
		surface1 = {69, 71, 90, 255},
		surface2 = {88, 91, 112, 255},
		overlay0 = {108, 112, 134, 255},
		text = {205, 214, 244, 255},
		subtext0 = {166, 173, 200, 255},
		mauve = {203, 166, 247, 255},
		blue = {137, 180, 250, 255},
		red = {243, 139, 168, 255},
	},
	.Macchiato = {
		base = {36, 39, 58, 255},
		mantle = {30, 32, 48, 255},
		surface0 = {54, 58, 79, 255},
		surface1 = {73, 77, 100, 255},
		surface2 = {91, 96, 120, 255},
		overlay0 = {110, 115, 138, 255},
		text = {202, 211, 245, 255},
		subtext0 = {165, 173, 203, 255},
		mauve = {198, 160, 246, 255},
		blue = {138, 173, 244, 255},
		red = {237, 135, 150, 255},
	},
	.Frappe = {
		base = {48, 52, 70, 255},
		mantle = {41, 44, 60, 255},
		surface0 = {65, 69, 89, 255},
		surface1 = {81, 87, 109, 255},
		surface2 = {98, 104, 128, 255},
		overlay0 = {115, 121, 148, 255},
		text = {198, 206, 239, 255},
		subtext0 = {165, 173, 206, 255},
		mauve = {202, 158, 230, 255},
		blue = {140, 170, 238, 255},
		red = {231, 130, 132, 255},
	},
	.Latte = {
		base = {239, 241, 245, 255},
		mantle = {230, 233, 239, 255},
		surface0 = {204, 208, 218, 255},
		surface1 = {188, 192, 204, 255},
		surface2 = {172, 176, 190, 255},
		overlay0 = {156, 160, 176, 255},
		text = {76, 79, 105, 255},
		subtext0 = {108, 111, 133, 255},
		mauve = {136, 57, 239, 255},
		blue = {30, 102, 245, 255},
		red = {210, 15, 57, 255},
	},
}

// Builds the colors from a Catppuccin flavor. Hover/active colors of the primary and
// danger color are derived by mixing them with the text/background color.
catppuccin_colors :: proc(flavor: Flavor) -> Colors {
	p := PALETTES[flavor]
	return {
		bg = p.base,
		bg_sunken = p.mantle,
		surface_0 = p.surface0,
		surface_1 = p.surface1,
		surface_2 = p.surface2,
		border = p.surface1,
		border_strong = p.overlay0,
		text = p.text,
		text_muted = p.subtext0,
		text_disabled = p.overlay0,
		primary = p.mauve,
		primary_hover = color_mix(p.mauve, p.text, 0.12),
		primary_active = color_mix(p.mauve, p.base, 0.2),
		on_primary = p.base,
		secondary = p.blue,
		danger = p.red,
		danger_hover = color_mix(p.red, p.text, 0.12),
		danger_active = color_mix(p.red, p.base, 0.2),
		selection = color_alpha(p.blue, 0.35),
	}
}

// Builds a complete `Theme` from a Catppuccin flavor with the default metrics.
catppuccin :: proc(flavor: Flavor) -> Theme {
	return {colors = catppuccin_colors(flavor), metrics = default_metrics()}
}
