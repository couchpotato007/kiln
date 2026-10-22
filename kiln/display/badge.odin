package display

// Small status/count pill. Non-interactive, meant for labels next to titles or inside rows.

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"

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
//   kiln.badge("3", .Info, id = kiln.id_local("count"))   // explicit id, e.g. in loops
badge :: proc(
	label: string,
	variant := BadgeVariant.Neutral,
	dot := false,
	id := clay.ElementId{},
) {
	c := th.current()
	eid := fd.resolve_id(id, label)

	bg, fg: clay.Color
	switch variant {
	case .Neutral:
		bg, fg = c.surface_1, c.text_muted
	case .Primary:
		bg, fg = th.color_alpha(c.primary, c.tint_alpha), c.primary
	case .Info:
		bg, fg = th.color_alpha(c.secondary, c.tint_alpha), c.secondary
	case .Danger:
		bg, fg = th.color_alpha(c.danger, c.tint_alpha), c.danger
	}

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingFit(), clay.SizingFit()},
			padding = th.pad_xy(.SM, .XS),
			childGap = th.sp(.XS),
			childAlignment = {y = .Center},
		},
		backgroundColor = bg,
		cornerRadius = th.radius(.Full),
	},
	) {
		if dot {
			d := th.size_px(.Dot)
			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
				backgroundColor = fg,
				cornerRadius = clay.CornerRadiusAll(d / 2),
			},
			) {}
		}
		if len(label) > 0 {
			clay.Text(label, th.text_style(.Caption, fg))
		}
	}
}
