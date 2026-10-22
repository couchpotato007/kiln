package overlay

// Dropdown menu and right-click context menu. Both share the floating list (`menu_list`)
// and the popup state of the foundation package, so the caller owns no state.

import clay "lib:kiln/clay-odin"
import "lib:kiln/controls"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"
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
// closes it as well.
// Returns the index of the clicked entry and true in the frame of the click, otherwise (-1, false):
//
//   if i, ok := kiln.menu(items, "Aktionen"); ok { ... }
menu :: proc(
	items: []MenuItem,
	label: string,
	disabled := false,
	id := clay.ElementId{},
) -> (
	index: int,
	ok: bool,
) {
	trigger := fd.resolve_id(id, label)
	list_id := fd.child_id(trigger, "list")

	if controls.button(label, .Secondary, disabled, id = trigger) {
		fd.popup_set(trigger, !fd.popup_is_open(trigger))
	}
	if disabled {fd.popup_set(trigger, false)}
	fd.popup_dismiss(trigger, list_id)

	index = -1
	if fd.popup_is_open(trigger) {
		min_width := clay.GetElementData(trigger).boundingBox.width
		index = menu_list(items, list_id, min_width, {
			attachTo   = .ElementWithId,
			parentId   = trigger.id,
			attachment = {element = .LeftTop, parent = .LeftBottom},
			offset     = {0, th.space_px(.XS)},
		})
		if index >= 0 {fd.popup_set(trigger, false)}
	}
	return index, index >= 0
}

// Position of the last right-click, where the context menu opens.
@(private)
g_context_pos: clay.Vector2

// Opens a floating list at the cursor when the user right-clicks the anchor (e.g. a row, card
// or button with its own explicit id). Clicking an entry closes the list; clicking elsewhere or
// pressing Escape closes it as well. Right-clicking the anchor again moves the menu.
// Returns the index of the clicked entry and true in the frame of the click, otherwise (-1, false):
//
//   if i, ok := kiln.context_menu(items, row_id); ok { ... }
context_menu :: proc(items: []MenuItem, anchor: clay.ElementId) -> (index: int, ok: bool) {
	list_id := fd.child_id(anchor, "context")

	if rl.IsMouseButtonPressed(.RIGHT) && clay.PointerOver(anchor) {
		g_context_pos = rl.GetMousePosition()
		fd.popup_set(anchor, true)
	} else {
		fd.popup_dismiss(anchor, list_id, keep_owner = false)
	}

	index = -1
	if fd.popup_is_open(anchor) {
		index = menu_list(items, list_id, th.size_px(.Menu), {
			attachTo   = .Root,
			attachment = {element = .LeftTop, parent = .LeftTop},
			offset     = g_context_pos,
		})
		if index >= 0 {fd.popup_set(anchor, false)}
	}
	return index, index >= 0
}

// Floating list of menu entries with the given placement. Returns the clicked index or -1.
@(private)
menu_list :: proc(
	items: []MenuItem,
	list_id: clay.ElementId,
	min_width: f32,
	placement: clay.FloatingElementConfig,
) -> int {
	c := th.current()
	picked := -1

	floating := placement
	floating.zIndex = fd.Z_POPUP
	floating.pointerCaptureMode = .Capture

	if clay.UI(list_id)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFit({min = min_width})},
			padding = th.pad_all(.XS),
		},
		backgroundColor = c.surface_0,
		cornerRadius = th.radius(.MD),
		border = th.border_box(c.border_strong),
		floating = floating,
	},
	) {
		for it, i in items {
			if it.separator {
				if clay.UI_AutoId()(
				{
					layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(th.border_px())}},
					backgroundColor = c.border,
				},
				) {}
				continue
			}

			item_id := fd.child_id(list_id, "item", i)
			s := fd.interact(item_id, it.disabled)
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
					padding = th.pad_xy(.MD, .SM),
				},
				backgroundColor = bg,
				cornerRadius = th.radius(.SM),
			},
			) {
				clay.Text(it.label, th.text_style(.Body, text_color))
			}
		}
	}
	return picked
}
