package controls

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"

// Declares a tab bar: muted labels, primary-colored underline on the selected tab.
// Clicking a tab stores its index in `selected`; showing the matching content is up to the
// caller (e.g. a `switch selected`). Tab ids are derived from the bar's id, so every tab bar
// in the same parent needs its own `id`. Returns true in the frame in which the selection changed.
//
//   if kiln.tabs(&tab, TAB_NAMES[:]) { ... }
tabs :: proc(selected: ^int, labels: []string, id := clay.ElementId{}) -> bool {
	c := th.current()
	eid := fd.resolve_id(id, "tabs")
	changed := false

	if clay.UI(eid)(
	{layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}}},
	) {
		if clay.UI_AutoId()({layout = {childGap = th.sp(.XS)}}) {
			for label, i in labels {
				tab_id := fd.child_id(eid, "tab", i)
				s := fd.interact(tab_id)
				if s.clicked && selected^ != i {
					selected^ = i
					changed = true
				}

				a := fd.anim(tab_id, 0, selected^ == i ? 1 : 0)
				h := fd.anim(tab_id, 1, s.hovered ? 1 : 0)
				color := th.color_mix(th.color_mix(c.text_muted, c.text, h), c.primary, a)

				if clay.UI(tab_id)(
				{layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingFit(), clay.SizingFit()}}},
				) {
					if clay.UI_AutoId()({layout = {padding = th.pad_xy(.LG, .SM)}}) {
						clay.Text(label, th.text_style(.Body, color))
					}
					// The underline fades in and out with the selection.
					if clay.UI_AutoId()(
					{
						layout = {
							sizing = {clay.SizingGrow(), clay.SizingFixed(th.border_px() * 2)},
						},
						backgroundColor = th.color_mix(th.color_alpha(c.primary, 0), c.primary, a),
					},
					) {}
				}
			}
		}
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(th.border_px())}},
			backgroundColor = c.border,
		},
		) {}
	}
	return changed
}
