package kiln

// Small status/count pill. Non-interactive, meant for labels next to titles or inside rows.

import clay "lib:kiln/clay-odin"

// Color role of a badge. The background is a tint of the theme color.
BadgeVariant :: enum {
	Neutral, // subtle surface, muted text
	Primary, // tinted with the primary color
	Info, // tinted with the secondary color
	Danger, // tinted with the danger color
}

// Declares a badge. `dot` adds a small leading circle, e.g. for online status.
//
//   kiln.badge("Neu")
//   kiln.badge("Online", .Primary, dot = true)
//   kiln.badge("3", .Info, id = kiln.id_local("count"))   // explicit ID, e.g. in loops
badge :: proc(label: string, variant := BadgeVariant.Neutral, dot := false, id := clay.ElementId{}) {
	c := current_theme
	eid := resolve_id(id, label)

	bg, fg: clay.Color
	switch variant {
	case .Neutral:
		bg, fg = c.surface_1, c.text_muted
	case .Primary:
		bg, fg = color_alpha(c.primary, 0.2), c.primary
	case .Info:
		bg, fg = color_alpha(c.secondary, 0.2), c.secondary
	case .Danger:
		bg, fg = color_alpha(c.danger, 0.2), c.danger
	}

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingFit(), clay.SizingFit()},
			padding = pad_xy(.SM, .XS),
			childGap = sp(.XS),
			childAlignment = {y = .Center},
		},
		backgroundColor = bg,
		cornerRadius = radius(.Full),
	},
	) {
		if dot {
			d := size_px(.SM)
			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
				backgroundColor = fg,
				cornerRadius = clay.CornerRadiusAll(d / 2),
			},
			) {}
		}
		if len(label) > 0 {
			clay.Text(label, text_style(.Caption, fg))
		}
	}
}
