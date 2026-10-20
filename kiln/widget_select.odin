package kiln


import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

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
// Without `id` the ID is "select" scoped to the parent, so several selects in the same parent
// need an explicit `id`.
select :: proc(
	selected: ^Select,
	options: []string,
	placeholder := "",
	disabled := false,
	id := clay.ElementId{},
) -> bool {
	c := current_theme
	eid := resolve_id(id, "select")
	changed := false
	list_id := clay.ID("select_list", eid.id)

	s := interact(eid, disabled)
	if s.clicked {popup_set(eid, !popup_is_open(eid))}
	if disabled {popup_set(eid, false)}
	if popup_is_open(eid) {
		outside :=
			rl.IsMouseButtonPressed(.LEFT) && !clay.PointerOver(eid) && !clay.PointerOver(list_id)
		if outside || rl.IsKeyPressed(.ESCAPE) {popup_set(eid, false)}
	}
	open := popup_is_open(eid)

	h := anim(eid, 0, (s.hovered || open) ? 1 : 0)
	data := clay.GetElementData(eid)

	current := -1
	if i, ok := selected^.?; ok && i >= 0 && i < len(options) {
		current = i
	}

	text := text_style(.Body, c.text)
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
			sizing = {clay.SizingGrow(), size_control_height()},
			padding = pad_xy(.MD, .None),
			childGap = sp(.SM),
			childAlignment = {y = .Center},
		},
		backgroundColor = c.bg_sunken,
		cornerRadius = radius(.MD),
		border = border_box(color_lerp(c.border, c.primary, h)),
	},
	) {
		clay.Text(shown, text)
		if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(0)}}}) {}
		clay.Text(open ? "^" : "v", text_style(.Body, c.text_muted))

		if open {
			if clay.UI(list_id)(
			{
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {
						clay.SizingFixed(data.found ? data.boundingBox.width : px(200)),
						clay.SizingFit(),
					},
					padding = pad_all(.XS),
				},
				backgroundColor = c.surface_0,
				cornerRadius = radius(.MD),
				border = border_box(c.border_strong),
				floating = {
					attachTo = .Parent,
					attachment = {element = .LeftTop, parent = .LeftBottom},
					offset = {0, space_px(.XS)},
					zIndex = 100,
					pointerCaptureMode = .Capture,
				},
			},
			) {
				for opt, i in options {
					item_id := clay.ID("select_item", eid.id * 1000 + u32(i))
					is := interact(item_id)
					if is.clicked {
						selected^ = i
						popup_set(eid, false)
						changed = true
					}
					bg: clay.Color
					if current == i {bg = c.surface_2}
					if is.hovered {bg = c.surface_1}
					if clay.UI(item_id)(
					{
						layout = {
							sizing = {clay.SizingGrow(), clay.SizingFit()},
							padding = pad_xy(.MD, .SM),
						},
						backgroundColor = bg,
						cornerRadius = radius(.SM),
					},
					) {
						clay.Text(opt, text_style(.Body, c.text))
					}
				}
			}
		}
	}
	return changed
}
