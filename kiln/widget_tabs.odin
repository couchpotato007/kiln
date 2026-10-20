package kiln

import clay "lib:kiln/clay-odin"

// Declares a tab bar: muted labels, primary-colored underline on the selected tab.
// Clicking a tab stores its index in `selected`; showing the matching content is up to the
// caller (e.g. a `switch selected`). Tab IDs are derived from the bar's ID, so every tab bar
// in the same parent needs its own `id`. Returns true in the frame in which the selection changed.
//
//   if kiln.tabs(&tab, TAB_NAMES[:]) { ... }
tabs :: proc(selected: ^int, labels: []string, id := clay.ElementId{}) -> bool {
	c := current_theme
	eid := resolve_id(id, "tabs")
	changed := false

	if clay.UI(eid)(
	{layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}}},
	) {
		if clay.UI_AutoId()({layout = {childGap = sp(.XS)}}) {
			for label, i in labels {
				tab_id := clay.ID("tab", eid.id * 1000 + u32(i))
				s := interact(tab_id)
				if s.clicked && selected^ != i {
					selected^ = i
					changed = true
				}

				a := anim(tab_id, 0, selected^ == i ? 1 : 0)
				h := anim(tab_id, 1, s.hovered ? 1 : 0)
				color := color_lerp(color_lerp(c.text_muted, c.text, h), c.primary, a)

				if clay.UI(tab_id)(
				{layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingFit(), clay.SizingFit()}}},
				) {
					if clay.UI_AutoId()({layout = {padding = pad_xy(.LG, .SM)}}) {
						clay.Text(label, text_style(.Body, color))
					}
					// Underline fades in and out with the selection.
					if clay.UI_AutoId()(
					{
						layout = {
							sizing = {
								clay.SizingGrow(),
								clay.SizingFixed(border_px() * 2),
							},
						},
						backgroundColor = color_lerp(color_alpha(c.primary, 0), c.primary, a),
					},
					) {}
				}
			}
		}
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(border_px())}},
			backgroundColor = c.border,
		},
		) {}
	}
	return changed
}
