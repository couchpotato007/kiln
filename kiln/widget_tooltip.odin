package kiln

// Hover tooltip: a small floating label that appears above an anchor element after a short delay.
// The anchor must have its own explicit ID; call `tooltip` AFTER declaring the anchor.

import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Hover start times of the anchors, keyed by anchor ID. Pure UI state.
@(private = "file")
g_tooltip_hover: map[u32]f64

// Shows `label` in a floating bubble above the anchor while the pointer hovers it for at least
// the theme's `tooltip_delay` seconds. Declare the anchor first, then call this:
//
//   save_id := kiln.id_local("save")
//   if kiln.button("Speichern", id = save_id) { ... }
//   kiln.tooltip(save_id, "Strg+S")
//
// The bubble disappears as soon as the pointer leaves the anchor.
tooltip :: proc(anchor: clay.ElementId, label: string) {
	if anchor.id == 0 || len(label) == 0 {return}

	if !clay.PointerOver(anchor) {
		delete_key(&g_tooltip_hover, anchor.id)
		return
	}

	now := rl.GetTime()
	start, seen := g_tooltip_hover[anchor.id]
	if !seen {
		g_tooltip_hover[anchor.id] = now
		return
	}
	if now - start < f64(current_theme.tooltip_delay) {return}

	data := clay.GetElementData(anchor)
	if !data.found {return}

	c := current_theme
	if clay.UI(clay.ID("tooltip", anchor.id))(
	{
		layout = {padding = pad_xy(.MD, .XS)},
		backgroundColor = c.surface_2,
		cornerRadius = radius(.SM),
		border = border_box(c.border_strong),
		floating = {
			attachTo = .ElementWithId,
			parentId = anchor.id,
			attachment = {element = .CenterBottom, parent = .CenterTop},
			offset = {0, -space_px(.XS)},
			zIndex = 200,
			pointerCaptureMode = .Passthrough,
		},
	},
	) {
		clay.Text(label, text_style(.Caption, c.text))
	}
}
