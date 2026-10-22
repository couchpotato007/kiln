package controls

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"

// Selected option index. The zero value (nil) means "nothing selected", so the placeholder is shown.
// Read it with `if i, ok := sel.?; ok { ... }`. The open/closed state of the list is kept
// internally, so the value can be copied and written back like any other widget value.
Select :: Maybe(int)

// Declares a dropdown. Returns true if the selection changed. `selected` can be a copy of the
// model value:
//
//   lang := m.language
//   if kiln.select(&lang, LANGUAGES[:], "Bitte wählen...") { append(out, Set_Language{lang}) }
//
// Without `id` the id is "select" scoped to the parent, so several selects in the same parent
// need an explicit `id`.
select :: proc(
	selected: ^Select,
	options: []string,
	placeholder := "",
	disabled := false,
	id := clay.ElementId{},
) -> bool {
	c := th.current()
	eid := fd.resolve_id(id, "select")
	list_id := fd.child_id(eid, "list")
	changed := false

	s := fd.interact(eid, disabled)
	if s.clicked {fd.popup_set(eid, !fd.popup_is_open(eid))}
	if disabled {fd.popup_set(eid, false)}
	fd.popup_dismiss(eid, list_id)
	open := fd.popup_is_open(eid)

	h := fd.anim(eid, 0, (s.hovered || open) ? 1 : 0)
	data := clay.GetElementData(eid)

	current := -1
	if i, ok := selected^.?; ok && i >= 0 && i < len(options) {
		current = i
	}

	text := th.text_style(.Body, c.text)
	shown := placeholder
	if current >= 0 {
		shown = options[current]
	} else {
		text.textColor = c.text_disabled
	}
	if disabled {text.textColor = c.text_disabled}

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), th.control_height()},
			padding = th.pad_xy(.MD, .None),
			childGap = th.sp(.SM),
			childAlignment = {y = .Center},
		},
		backgroundColor = c.bg_sunken,
		cornerRadius = th.radius(.MD),
		border = th.border_box(th.color_mix(c.border, c.primary, h)),
	},
	) {
		clay.Text(shown, text)
		if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(0)}}}) {}
		clay.Text(open ? "^" : "v", th.text_style(.Body, c.text_muted))

		if open {
			if clay.UI(list_id)(
			{
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {width = clay.SizingFit({min = data.found ? data.boundingBox.width : 0})},
					padding = th.pad_all(.XS),
				},
				backgroundColor = c.surface_0,
				cornerRadius = th.radius(.MD),
				border = th.border_box(c.border_strong),
				floating = {
					attachTo = .Parent,
					attachment = {element = .LeftTop, parent = .LeftBottom},
					offset = {0, th.space_px(.XS)},
					zIndex = fd.Z_POPUP,
					pointerCaptureMode = .Capture,
				},
			},
			) {
				for opt, i in options {
					item_id := fd.child_id(eid, "item", i)
					is := fd.interact(item_id)
					if is.clicked {
						selected^ = i
						fd.popup_set(eid, false)
						changed = true
					}
					bg: clay.Color
					if current == i {bg = c.surface_2}
					if is.hovered {bg = c.surface_1}
					if clay.UI(item_id)(
					{
						layout = {
							sizing = {clay.SizingGrow(), clay.SizingFit()},
							padding = th.pad_xy(.MD, .SM),
						},
						backgroundColor = bg,
						cornerRadius = th.radius(.SM),
					},
					) {
						clay.Text(opt, th.text_style(.Body, c.text))
					}
				}
			}
		}
	}
	return changed
}
