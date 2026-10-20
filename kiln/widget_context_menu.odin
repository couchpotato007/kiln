package kiln

// Right-click context menu on an anchor element. Reuses the popup and MenuItem machinery
// of the dropdown menu, but is opened with the right mouse button and needs no trigger widget.

import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Appearance of a context menu. Create it with `style_context_menu`.
ContextMenuConfig :: struct {
	id:            clay.ElementId, // the anchor element (e.g. a row, card or button)
	list:          clay.ElementDeclaration, // popup container
	item:          clay.ElementDeclaration, // one row
	text:          clay.TextElementConfig,
	item_hover:    clay.Color,
	danger_text:   clay.Color,
	disabled_text: clay.Color,
	separator:     clay.Color,
}

// Context menu look from the current theme. Same rows as the dropdown menu.
style_context_menu :: proc(anchor: clay.ElementId) -> ContextMenuConfig {
	c := current_theme
	return {
		id = anchor,
		list = {
			layout = {layoutDirection = .TopToBottom, padding = pad_all(.XS)},
			backgroundColor = c.surface_0,
			cornerRadius = radius(.MD),
			border = border_box(c.border_strong),
		},
		item = {
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = pad_xy(.MD, .SM),
			},
			cornerRadius = radius(.SM),
		},
		text = text_style(.Body, c.text),
		item_hover = c.surface_1,
		danger_text = c.danger,
		disabled_text = c.text_disabled,
		separator = c.border,
	}
}

// Opens a floating list when the user right-clicks the anchor (`cfg.id`).
// Clicking an entry closes the list; clicking elsewhere or pressing Escape closes it as well.
// The open state is kept internally, the caller owns no state.
// Returns the index of the clicked entry and true in the frame of the click, otherwise (-1, false):
//
//   cfg := kiln.style_context_menu(row_id)
//   if i, ok := kiln.context_menu(items, cfg); ok { ... }
context_menu :: proc(items: []MenuItem, cfg: ContextMenuConfig) -> (int, bool) {
	picked := -1
	anchor := cfg.id
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
		// The popup is attached to the anchor and at least as wide as it.
		data := clay.GetElementData(anchor)
		list := cfg.list
		list.layout.sizing.width = clay.SizingFit({min = data.found ? data.boundingBox.width : 0})
		list.floating = {
			attachTo           = .ElementWithId,
			parentId           = anchor.id,
			attachment         = {element = .LeftTop, parent = .LeftBottom},
			offset             = {0, px(4)},
			zIndex             = 150,
			pointerCaptureMode = .Capture,
		}

		if clay.UI(list_id)(list) {
			for it, i in items {
				if it.separator {
					if clay.UI_AutoId()(
					{
						layout = {
							sizing = {
								clay.SizingGrow(),
								clay.SizingFixed(px(BORDER_WIDTH)),
							},
						},
						backgroundColor = cfg.separator,
					},
					) {}
					continue
				}

				item_id := clay.ID("ctx_item", anchor.id * 1000 + u32(i))
				s := interact(item_id, it.disabled)
				if s.clicked {
					picked = i
					popup_set(anchor, false)
				}

				decl := cfg.item
				if s.hovered {decl.backgroundColor = cfg.item_hover}
				text := cfg.text
				if it.danger {text.textColor = cfg.danger_text}
				if it.disabled {text.textColor = cfg.disabled_text}

				if clay.UI(item_id)(decl) {
					clay.Text(it.label, text)
				}
			}
		}
	}
	return picked, picked >= 0
}
