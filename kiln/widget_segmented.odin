package kiln

// Segmented control: a row of joined buttons for switching between a small set of modes.
// Like tabs, but pill-shaped and suitable for toolbars and settings rows.

import clay "lib:kiln/clay-odin"

// Declares a segmented control (bordered pill with a primary-colored selected segment).
// Clicking a segment stores its index in `selected`.
// Returns true in the frame in which the selection changed:
//
//   mode := m.mode
//   if kiln.segmented(&mode, []string{"Liste", "Kacheln", "Raster"}) { append(out, Set_Mode{mode}) }
//
// Segment IDs are derived from the control's ID, so every control in the same parent needs its own `id`.
segmented :: proc(selected: ^int, labels: []string, id := clay.ElementId{}) -> bool {
	c := current_theme
	eid := resolve_id(id, "segmented")
	changed := false

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingFit(), clay.SizingFit()},
			padding = pad_all(.XS),
			childGap = sp(.XS),
		},
		backgroundColor = c.surface_0,
		cornerRadius = radius(.Full),
		border = border_box(c.border),
	},
	) {
		for label, i in labels {
			seg_id := clay.ID("seg", eid.id * 1000 + u32(i))
			s := interact(seg_id)
			if s.clicked && selected^ != i {
				selected^ = i
				changed = true
			}

			a := anim(seg_id, 0, selected^ == i ? 1 : 0)
			h := anim(seg_id, 1, s.hovered ? 1 : 0)

			bg: clay.Color
			text: clay.TextElementConfig
			if selected^ != i {
				bg = color_lerp(color_alpha(c.surface_1, 0), c.surface_1, h)
				text = text_style(.Body, color_lerp(c.text_muted, c.text, h))
			} else {
				bg = color_lerp(c.surface_1, c.primary, a)
				text = text_style(.Body, c.on_primary)
			}

			if clay.UI(seg_id)(
			{
				layout = {
					sizing = {clay.SizingFit(), clay.SizingFit()},
					padding = pad_xy(.MD, .XS),
					childAlignment = {x = .Center, y = .Center},
				},
				backgroundColor = bg,
				cornerRadius = radius(.Full),
			},
			) {
				clay.Text(label, text)
			}
		}
	}
	return changed
}
