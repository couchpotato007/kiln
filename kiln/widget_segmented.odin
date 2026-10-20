package kiln

// Segmented control: a row of joined buttons for switching between a small set of modes.
// Like tabs, but pill-shaped and suitable for toolbars and settings rows.

import clay "lib:kiln/clay-odin"

// Appearance of a segmented control. Create it with `style_segmented`.
SegmentedConfig :: struct {
	id:            clay.ElementId, // base ID, every segment derives its own ID from it
	box:           clay.ElementDeclaration, // outer container (pill)
	segment:       clay.ElementDeclaration, // one segment (padding, radius)
	text:          clay.TextElementConfig, // inactive segment label
	text_hover:    clay.Color,
	segment_hover: clay.Color,
	selected_bg:   clay.Color,
	selected_text: clay.TextElementConfig,
}

// Segmented control look from the current theme: a bordered pill with a primary-colored
// selected segment.
style_segmented :: proc(id: clay.ElementId) -> SegmentedConfig {
	c := current_theme
	return {
		id = id,
		box = {
			layout = {
				sizing = {clay.SizingFit(), clay.SizingFit()},
				padding = pad_all(.XS),
				childGap = sp(.XS),
			},
			backgroundColor = c.surface_0,
			cornerRadius = radius(.Full),
			border = border_box(c.border),
		},
		segment = {
			layout = {
				sizing = {clay.SizingFit(), clay.SizingFit()},
				padding = pad_xy(.MD, .XS),
				childAlignment = {x = .Center, y = .Center},
			},
			cornerRadius = radius(.Full),
		},
		text = text_style(.Body, c.text_muted),
		text_hover = c.text,
		segment_hover = c.surface_1,
		selected_bg = c.primary,
		selected_text = text_style(.Body, c.on_primary),
	}
}

// Declares a segmented control. Clicking a segment stores its index in `selected`.
// Returns true in the frame in which the selection changed:
//
//   mode := m.mode
//   if kiln.segmented(&mode, [?]string{"Liste", "Kacheln", "Raster"}[:], kiln.style_segmented(kiln.id_local("mode"))) {
//       append(out, Set_Mode{mode})
//   }
segmented :: proc(selected: ^int, labels: []string, cfg: SegmentedConfig) -> bool {
	changed := false

	if clay.UI(cfg.id)(cfg.box) {
		for label, i in labels {
			seg_id := clay.ID("seg", cfg.id.id * 1000 + u32(i))
			s := interact(seg_id)
			if s.clicked && selected^ != i {
				selected^ = i
				changed = true
			}

			a := anim(seg_id, 0, selected^ == i ? 1 : 0)
			h := anim(seg_id, 1, s.hovered ? 1 : 0)

			seg := cfg.segment
			if selected^ != i {
				seg.backgroundColor = color_lerp(color_alpha(cfg.segment_hover, 0), cfg.segment_hover, h)
			} else {
				seg.backgroundColor = color_lerp(cfg.segment_hover, cfg.selected_bg, a)
			}

			if clay.UI(seg_id)(seg) {
				text := cfg.text
				if selected^ != i {
					text.textColor = color_lerp(cfg.text.textColor, cfg.text_hover, h)
				} else {
					text = cfg.selected_text
				}
				clay.Text(label, text)
			}
		}
	}
	return changed
}
