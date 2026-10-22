package overlay

// Hover tooltip: a small floating label that appears above an anchor element after a short delay.
// The anchor must have its own explicit id; call `tooltip` AFTER declaring the anchor.

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"
import rl "vendor:raylib"

// Hover start times of the anchors, keyed by anchor id. Pure UI state.
@(private)
g_hover: map[u32]f64

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
		delete_key(&g_hover, anchor.id)
		return
	}

	c := th.current()
	now := rl.GetTime()
	start, seen := g_hover[anchor.id]
	if !seen {
		g_hover[anchor.id] = now
		return
	}
	if now - start < f64(c.tooltip_delay) {return}
	if !clay.GetElementData(anchor).found {return}

	if clay.UI(fd.child_id(anchor, "tooltip"))(
	{
		layout = {padding = th.pad_xy(.MD, .XS)},
		backgroundColor = c.surface_2,
		cornerRadius = th.radius(.SM),
		border = th.border_box(c.border_strong),
		floating = {
			attachTo = .ElementWithId,
			parentId = anchor.id,
			attachment = {element = .CenterBottom, parent = .CenterTop},
			offset = {0, -th.space_px(.XS)},
			zIndex = fd.Z_TOOLTIP,
			pointerCaptureMode = .Passthrough,
		},
	},
	) {
		clay.Text(label, th.text_style(.Caption, c.text))
	}
}
