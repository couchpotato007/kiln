package kiln

// Small status/count pill. Non-interactive, meant for labels next to titles or inside rows.

import clay "lib:kiln/clay-odin"

// Color role of a badge. Softer than the button variants: the background is a tint of the color.
BadgeVariant :: enum {
	Neutral, // subtle surface, muted text
	Primary, // tinted with the primary color
	Info, // tinted with the secondary color
	Danger, // tinted with the danger color
}

// Appearance of a badge. Create it with `style_badge`, adjust fields as needed, pass it to `badge`.
BadgeConfig :: struct {
	id:        clay.ElementId,
	label:     string,
	box:       clay.ElementDeclaration, // pill (padding, radius, background)
	text:      clay.TextElementConfig,
	dot:       bool, // small leading circle, e.g. for online status
	dot_size:  f32, // unscaled diameter
	dot_color: clay.Color,
}

// Badge look from the current theme. Height fits the caption text, width fits the label.
style_badge :: proc(id: clay.ElementId, label: string, variant := BadgeVariant.Neutral) -> BadgeConfig {
	c := current_theme
	cfg := BadgeConfig {
		id = id,
		label = label,
		box = {
			layout = {
				sizing = {clay.SizingFit(), clay.SizingFit()},
				padding = pad_xy(.SM, .XS),
				childGap = sp(.XS),
				childAlignment = {y = .Center},
			},
			cornerRadius = radius(.Full),
		},
		text = text_style(.Caption, c.text_muted),
		dot_size = 8,
	}

	switch variant {
	case .Neutral:
		cfg.box.backgroundColor = c.surface_1
	case .Primary:
		cfg.box.backgroundColor = color_alpha(c.primary, 0.2)
		cfg.text = text_style(.Caption, c.primary)
		cfg.dot_color = c.primary
	case .Info:
		cfg.box.backgroundColor = color_alpha(c.secondary, 0.2)
		cfg.text = text_style(.Caption, c.secondary)
		cfg.dot_color = c.secondary
	case .Danger:
		cfg.box.backgroundColor = color_alpha(c.danger, 0.2)
		cfg.text = text_style(.Caption, c.danger)
		cfg.dot_color = c.danger
	}
	if cfg.dot_color == {} {cfg.dot_color = cfg.text.textColor}
	return cfg
}

// Two ways to declare a badge:
//
//   kiln.badge("Neu")                                      // short form, ID derived from the label
//   kiln.badge("3", .Primary, id = kiln.id_local("count")) // explicit ID, e.g. in loops
//   kiln.badge_cfg(kiln.style_badge(id, "Neu", .Primary))  // full control via BadgeConfig
badge :: proc {
	badge_cfg,
	badge_label,
}

// Short form.
badge_label :: proc(
	label: string,
	variant := BadgeVariant.Neutral,
	id := clay.ElementId{},
) {
	eid := id
	if eid.id == 0 {eid = id_local(label)}
	badge_cfg(style_badge(eid, label, variant))
}

// Declares a badge from a full config.
badge_cfg :: proc(cfg: BadgeConfig) {
	if clay.UI(cfg.id)(cfg.box) {
		if cfg.dot {
			if clay.UI_AutoId()(
			{
				layout = {
					sizing = {
						clay.SizingFixed(px(cfg.dot_size)),
						clay.SizingFixed(px(cfg.dot_size)),
					},
				},
				backgroundColor = cfg.dot_color,
				cornerRadius = clay.CornerRadiusAll(px(cfg.dot_size) / 2),
			},
			) {}
		}
		if len(cfg.label) > 0 {
			clay.Text(cfg.label, cfg.text)
		}
	}
}
