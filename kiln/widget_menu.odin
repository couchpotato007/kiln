package kiln


import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// One entry of a menu.
MenuItem :: struct {
	label:     string,
	disabled:  bool, // greyed out, cannot be clicked
	danger:    bool, // drawn in the danger color (e.g. "Delete")
	separator: bool, // draws a divider line instead of an entry, `label` is ignored
}

// Declares a menu button (a secondary button with `label`). Clicking it opens a floating list
// below the button; clicking an entry closes the list. Clicking elsewhere or pressing Escape
// closes it as well. The open state is kept internally, the caller owns no state.
// Returns the index of the clicked entry and true in the frame of the click, otherwise (-1, false):
//
//   if i, ok := kiln.menu(items, "Aktionen"); ok { ... }
menu :: proc(
	items: []MenuItem,
	label: string,
	disabled := false,
	id := clay.ElementId{},
) -> (
	int,
	bool,
) {
	picked := -1
	trigger_id := resolve_id(id, label)
	list_id := clay.ID("menu_list", trigger_id.id)

	if button(label, .Secondary, disabled, trigger_id) {
		popup_set(trigger_id, !popup_is_open(trigger_id))
	}
	if disabled {popup_set(trigger_id, false)}

	if popup_is_open(trigger_id) {
		outside :=
			rl.IsMouseButtonPressed(.LEFT) &&
			!clay.PointerOver(trigger_id) &&
			!clay.PointerOver(list_id)
		if outside || rl.IsKeyPressed(.ESCAPE) {popup_set(trigger_id, false)}
	}

	if popup_is_open(trigger_id) {
		picked = menu_list(items, trigger_id, list_id, "menu_item", 100)
		if picked >= 0 {popup_set(trigger_id, false)}
	}
	return picked, picked >= 0
}

// Floating list attached below `anchor`, at least as wide as the anchor. Shared by `menu` and
// `context_menu`. Returns the clicked index or -1.
@(private)
menu_list :: proc(
	items: []MenuItem,
	anchor, list_id: clay.ElementId,
	item_prefix: string,
	z: i16,
) -> int {
	c := current_theme
	picked := -1
	data := clay.GetElementData(anchor)

	if clay.UI(list_id)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFit({min = data.found ? data.boundingBox.width : 0})},
			padding = pad_all(.XS),
		},
		backgroundColor = c.surface_0,
		cornerRadius = radius(.MD),
		border = border_box(c.border_strong),
		floating = {
			attachTo = .ElementWithId,
			parentId = anchor.id,
			attachment = {element = .LeftTop, parent = .LeftBottom},
			offset = {0, space_px(.XS)},
			zIndex = z,
			pointerCaptureMode = .Capture,
		},
	},
	) {
		for it, i in items {
			if it.separator {
				if clay.UI_AutoId()(
				{
					layout = {
						sizing = {clay.SizingGrow(), clay.SizingFixed(border_px())},
					},
					backgroundColor = c.border,
				},
				) {}
				continue
			}

			item_id := clay.ID(item_prefix, anchor.id * 1000 + u32(i))
			s := interact(item_id, it.disabled)
			if s.clicked {picked = i}

			bg: clay.Color
			if s.hovered {bg = c.surface_1}
			text_color := c.text
			if it.danger {text_color = c.danger}
			if it.disabled {text_color = c.text_disabled}

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
				clay.Text(it.label, text_style(.Body, text_color))
			}
		}
	}
	return picked
}
