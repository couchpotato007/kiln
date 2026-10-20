package widgets


import clay "lib:clay-odin"
import "lib:theme"

// Visual style of a button, used by `style_button`.
ButtonVariant :: enum {
	Primary, // filled with the primary color
	Secondary, // neutral surface with a border
	Ghost, // transparent until hovered
	Danger, // filled with the danger color
}

// Appearance of a button. Create it with `style_button`, adjust fields as needed, pass it to `button`.
ButtonConfig :: struct {
	id:            clay.ElementId,
	label:         string,
	box:           clay.ElementDeclaration, // layout, background, radius, border
	text:          clay.TextElementConfig,
	hover:         clay.Color, // background while hovered (faded in)
	active:        clay.Color, // background while pressed
	disabled:      bool,
	disabled_bg:   clay.Color,
	disabled_text: clay.Color,
}

// Button look from the current theme. Height is the control height, width fits the label.
// Set `cfg.box.layout.sizing.width = clay.SizingGrow()` for a full-width button.
style_button :: proc(
	id: clay.ElementId,
	label: string,
	variant := ButtonVariant.Primary,
	disabled := false,
) -> ButtonConfig {
	c := theme.current
	cfg := ButtonConfig {
		id = id,
		label = label,
		disabled = disabled,
		box = {
			layout = {
				sizing = {clay.SizingFit(), theme.size_control_height()},
				padding = theme.pad_xy(.LG, .None),
				childGap = theme.sp(.SM),
				childAlignment = {x = .Center, y = .Center},
			},
			cornerRadius = theme.radius(.MD),
		},
		disabled_bg = c.surface_0,
		disabled_text = c.text_disabled,
	}

	switch variant {
	case .Primary:
		cfg.box.backgroundColor = c.primary
		cfg.hover = c.primary_hover
		cfg.active = c.primary_active
		cfg.text = theme.text_style(.Body, c.on_primary)
	case .Secondary:
		cfg.box.backgroundColor = c.surface_1
		cfg.box.border = theme.border_box(c.border)
		cfg.hover = c.surface_2
		cfg.active = theme.color_mix(c.surface_2, c.text, 0.1)
		cfg.text = theme.text_style(.Body, c.text)
	case .Ghost:
		// Transparent version of the hover color, so the hover fade does not pass through black.
		cfg.box.backgroundColor = theme.color_alpha(c.surface_0, 0)
		cfg.hover = c.surface_0
		cfg.active = c.surface_1
		cfg.disabled_bg = theme.color_alpha(c.surface_0, 0)
		cfg.text = theme.text_style(.Body, c.text)
	case .Danger:
		cfg.box.backgroundColor = c.danger
		cfg.hover = theme.color_mix(c.danger, c.text, 0.12)
		cfg.active = theme.color_mix(c.danger, c.bg, 0.2)
		cfg.text = theme.text_style(.Body, c.on_primary)
	}
	return cfg
}

// Two ways to declare a button, both return true in the frame in which it was clicked:
//
//   widgets.button("Save")                                  // short form, ID derived from the label
//   widgets.button("Delete", .Danger, id = clay.ID_LOCAL("del", u32(i)))  // explicit ID, e.g. in loops
//   widgets.button(widgets.style_button(id, "Save"))        // full control via ButtonConfig
button :: proc {
	button_cfg,
	button_label,
}

// Short form. Without `id` the ID is derived from the label and the parent element, so two buttons
// with the same label in the same parent need an explicit `id`.
button_label :: proc(
	label: string,
	variant := ButtonVariant.Primary,
	disabled := false,
	id := clay.ElementId{},
) -> bool {
	eid := id
	if eid.id == 0 {eid = clay.ID_LOCAL(label)}
	return button_cfg(style_button(eid, label, variant, disabled))
}

// Declares a button from a full config. A click requires press and release on the button.
// The hover color is faded in smoothly.
button_cfg :: proc(cfg: ButtonConfig) -> bool {
	s := interact(cfg.id, cfg.disabled)

	decl := cfg.box
	text := cfg.text
	if s.disabled {
		decl.backgroundColor = cfg.disabled_bg
		text.textColor = cfg.disabled_text
	} else {
		hv := anim(cfg.id, 0, s.hovered ? 1 : 0)
		if cfg.hover != {} {
			decl.backgroundColor = color_lerp(cfg.box.backgroundColor, cfg.hover, hv)
		}
		if s.pressed && cfg.active != {} {
			decl.backgroundColor = cfg.active
		}
	}

	if clay.UI(cfg.id)(decl) {
		clay.Text(cfg.label, text)
	}
	return s.clicked
}
