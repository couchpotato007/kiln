package kiln


import clay "lib:kiln/clay-odin"

// Visual style of a button. The colors come from the global theme.
ButtonVariant :: enum {
	Primary, // filled with the primary color
	Secondary, // neutral surface with a border
	Ghost, // transparent until hovered
	Danger, // filled with the danger color
}

// Declares a button and returns true in the frame in which it was clicked
// (press and release on the button).
//
//   kiln.button("Save")
//   kiln.button("Delete", .Danger, id = kiln.id_local("del", u32(i)))  // explicit ID, e.g. in loops
//   kiln.button("Wide", fill_width = true)
//
// Without `id` the ID is derived from the label and the parent element, so two buttons
// with the same label in the same parent need an explicit `id`.
button :: proc(
	label: string,
	variant := ButtonVariant.Primary,
	disabled := false,
	id := clay.ElementId{},
	fill_width := false,
) -> bool {
	c := current_theme
	eid := resolve_id(id, label)
	s := interact(eid, disabled)

	bg, hover, active, fg: clay.Color
	switch variant {
	case .Primary:
		bg, hover, active, fg = c.primary, c.primary_hover, c.primary_active, c.on_primary
	case .Secondary:
		bg, hover, fg = c.surface_1, c.surface_2, c.text
		active = color_mix(c.surface_2, c.text, 0.1)
	case .Ghost:
		// Transparent version of the hover color, so the hover fade does not pass through black.
		bg, hover, active, fg = color_alpha(c.surface_0, 0), c.surface_0, c.surface_1, c.text
	case .Danger:
		bg, hover, active, fg = c.danger, c.danger_hover, c.danger_active, c.on_primary
	}

	if s.disabled {
		bg = variant == .Ghost ? color_alpha(c.surface_0, 0) : c.surface_0
		fg = c.text_disabled
	} else {
		bg = color_lerp(bg, hover, anim(eid, 0, s.hovered ? 1 : 0))
		if s.pressed {bg = active}
	}

	decl := clay.ElementDeclaration {
		layout = {
			sizing = {fill_width ? clay.SizingGrow() : clay.SizingFit(), size_control_height()},
			padding = pad_xy(.LG, .None),
			childGap = sp(.SM),
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = bg,
		cornerRadius = radius(.MD),
	}
	if variant == .Secondary {decl.border = border_box(c.border)}

	if clay.UI(eid)(decl) {
		clay.Text(label, text_style(.Body, fg))
	}
	return s.clicked
}
