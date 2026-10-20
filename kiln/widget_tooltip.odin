package kiln

// Hover tooltip: a small floating label that appears above an anchor element after a short delay.
// The anchor must have its own explicit ID; call `tooltip` AFTER declaring the anchor.

import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Appearance of a tooltip. Create it with `style_tooltip`.
TooltipConfig :: struct {
	id:               clay.ElementId, // the anchor element the tooltip belongs to
	label:            string,
	box:              clay.ElementDeclaration, // floating bubble
	text:             clay.TextElementConfig,
	delay:            f32, // seconds of continuous hover before the tooltip appears
	vertical_offset:  f32, // unscaled gap between anchor and bubble
}

// Tooltip look from the current theme: a small dark bubble with caption text.
style_tooltip :: proc(anchor: clay.ElementId, label: string) -> TooltipConfig {
	c := current_theme
	return {
		id = anchor,
		label = label,
		box = {
			layout = {padding = pad_xy(.MD, .XS)},
			backgroundColor = c.surface_2,
			cornerRadius = radius(.SM),
			border = border_box(c.border_strong),
		},
		text = text_style(.Caption, c.text),
		delay = 0.4,
		vertical_offset = 4,
	}
}

// Hover start times of the anchors, keyed by anchor ID. Pure UI state.
@(private = "file")
g_tooltip_hover: map[u32]f64

// Shows `cfg.label` in a floating bubble above the anchor (`cfg.id`) while the pointer
// hovers it for at least `cfg.delay` seconds. Declare the anchor first, then call this:
//
//   save_id := kiln.id_local("save")
//   if kiln.button("Speichern", id = save_id) { ... }
//   kiln.tooltip(kiln.style_tooltip(save_id, "Strg+S"))
//
// The bubble disappears as soon as the pointer leaves the anchor.
tooltip :: proc(cfg: TooltipConfig) {
	if cfg.id.id == 0 || len(cfg.label) == 0 {return}

	if !clay.PointerOver(cfg.id) {
		delete_key(&g_tooltip_hover, cfg.id.id)
		return
	}

	now := rl.GetTime()
	start, seen := g_tooltip_hover[cfg.id.id]
	if !seen {
		g_tooltip_hover[cfg.id.id] = now
		return
	}
	if now - start < f64(cfg.delay) {return}

	data := clay.GetElementData(cfg.id)
	if !data.found {return}

	bubble := cfg.box
	bubble.floating = {
		attachTo           = .ElementWithId,
		parentId           = cfg.id.id,
		attachment         = {element = .CenterBottom, parent = .CenterTop},
		offset             = {0, -px(cfg.vertical_offset)},
		zIndex             = 200,
		pointerCaptureMode = .Passthrough,
	}

	if clay.UI(clay.ID("tooltip", cfg.id.id))(bubble) {
		clay.Text(cfg.label, cfg.text)
	}
}
