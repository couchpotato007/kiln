package kiln

// Catppuccin color schemes. Mocha, Macchiato and Frappe are dark, Latte is light.
Flavor :: enum {
	Mocha,
	Macchiato,
	Frappe,
	Latte,
}

// The part of the official Catppuccin palette that `Colors` is built from.
@(private)
Palette :: struct {
	base, mantle:                 Color,
	surface0, surface1, surface2: Color,
	overlay0:                     Color,
	text, subtext0:               Color,
	mauve, blue, green, yellow:   Color,
	red:                          Color,
	peach, pink, teal:            Color,
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
		green = {166, 227, 161, 255},
		yellow = {249, 226, 175, 255},
		red = {243, 139, 168, 255},
		peach = {250, 179, 135, 255},
		pink = {245, 194, 231, 255},
		teal = {148, 226, 213, 255},
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
		green = {166, 218, 149, 255},
		yellow = {238, 212, 159, 255},
		red = {237, 135, 150, 255},
		peach = {245, 169, 127, 255},
		pink = {245, 189, 230, 255},
		teal = {139, 213, 202, 255},
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
		green = {166, 209, 137, 255},
		yellow = {229, 200, 144, 255},
		red = {231, 130, 132, 255},
		peach = {239, 159, 118, 255},
		pink = {244, 184, 228, 255},
		teal = {129, 200, 190, 255},
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
		green = {64, 160, 43, 255},
		yellow = {223, 142, 29, 255},
		red = {210, 15, 57, 255},
		peach = {254, 100, 11, 255},
		pink = {234, 118, 203, 255},
		teal = {23, 146, 153, 255},
	},
}

catppuccin_colors :: proc(flavor: Flavor) -> Colors {
	p := PALETTES[flavor]
	return {
		window = p.base,
		sunken = p.mantle,
		surface = p.surface0,
		surface_hover = p.surface1,
		surface_active = p.surface2,
		border = p.surface1,
		border_strong = p.overlay0,
		text = p.text,
		text_muted = p.subtext0,
		text_faint = p.overlay0,
		primary = p.mauve,
		on_primary = p.base,
		info = p.blue,
		success = p.green,
		warning = p.yellow,
		danger = p.red,
		selection = fade(p.blue, 0.35),
		chart = {p.blue, p.peach, p.green, p.yellow, p.pink, p.teal, p.mauve, p.red},
	}
}

// A complete theme from a Catppuccin flavor and the default metrics.
catppuccin :: proc(flavor: Flavor) -> Theme {
	return {colors = catppuccin_colors(flavor), metrics = default_metrics()}
}
