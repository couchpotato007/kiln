package kiln

// Right-click context menu on an anchor element. Reuses the popup and MenuItem machinery
// of the dropdown menu, but is opened with the right mouse button and needs no trigger widget.

import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Opens a floating list when the user right-clicks the anchor (e.g. a row, card or button
// with its own explicit ID). Clicking an entry closes the list; clicking elsewhere or pressing
// Escape closes it as well. The open state is kept internally, the caller owns no state.
// Returns the index of the clicked entry and true in the frame of the click, otherwise (-1, false):
//
//   if i, ok := kiln.context_menu(items, row_id); ok { ... }
context_menu :: proc(items: []MenuItem, anchor: clay.ElementId) -> (int, bool) {
	picked := -1
	list_id := clay.ID("ctx_list", anchor.id)

	// Right-click on the anchor toggles the menu.
	if rl.IsMouseButtonPressed(.RIGHT) && clay.PointerOver(anchor) {
		popup_set(anchor, !popup_is_open(anchor))
	}

	if popup_is_open(anchor) {
		outside :=
			(rl.IsMouseButtonPressed(.LEFT) || rl.IsMouseButtonPressed(.RIGHT)) &&
			!clay.PointerOver(anchor) &&
			!clay.PointerOver(list_id)
		if outside || rl.IsKeyPressed(.ESCAPE) {popup_set(anchor, false)}
	}

	if popup_is_open(anchor) {
		picked = menu_list(items, anchor, list_id, "ctx_item", 150)
		if picked >= 0 {popup_set(anchor, false)}
	}
	return picked, picked >= 0
}
