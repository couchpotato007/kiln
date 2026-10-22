package controls

// Segmented control: a row of joined buttons for switching between a small set of modes.
// Like tabs, but pill-shaped and suitable for toolbars and settings rows.

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"

// Declares a segmented control (bordered pill with a primary-colored selected segment).
// Clicking a segment stores its index in `selected`.
// Returns true in the frame in which the selection changed:
//
//   mode := m.mode
//   if kiln.segmented(&mode, []string{"Liste", "Kacheln", "Raster"}) { append(out, Set_Mode{mode}) }
//
// Segment ids are derived from the control's id, so every control in the same parent needs its own `id`.
segmented :: proc(selected: ^int, labels: []string, id := clay.ElementId{}) -> bool {
	c := th.current()
	eid := fd.resolve_id(id, "segmented")
	changed := false

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingFit(), clay.SizingFit()},
			padding = th.pad_all(.XS),
			childGap = th.sp(.XS),
		},
		backgroundColor = c.surface_0,
		cornerRadius = th.radius(.Full),
		border = th.border_box(c.border),
	},
	) {
		for label, i in labels {
			seg_id := fd.child_id(eid, "seg", i)
			s := fd.interact(seg_id)
			if s.clicked && selected^ != i {
				selected^ = i
				changed = true
			}

			a := fd.anim(seg_id, 0, selected^ == i ? 1 : 0)
			h := fd.anim(seg_id, 1, s.hovered ? 1 : 0)

			bg: clay.Color
			text: clay.TextElementConfig
			if selected^ != i {
				bg = th.color_mix(th.color_alpha(c.surface_1, 0), c.surface_1, h)
				text = th.text_style(.Body, th.color_mix(c.text_muted, c.text, h))
			} else {
				bg = th.color_mix(c.surface_1, c.primary, a)
				text = th.text_style(.Body, c.on_primary)
			}

			if clay.UI(seg_id)(
			{
				layout = {
					sizing = {clay.SizingFit(), clay.SizingFit()},
					padding = th.pad_xy(.MD, .XS),
					childAlignment = {x = .Center, y = .Center},
				},
				backgroundColor = bg,
				cornerRadius = th.radius(.Full),
			},
			) {
				clay.Text(label, text)
			}
		}
	}
	return changed
}
