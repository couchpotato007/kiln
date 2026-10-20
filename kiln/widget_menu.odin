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

// Appearance of a dropdown menu. Create it with `style_menu`.
MenuConfig :: struct {
	trigger:       ButtonConfig, // the button that opens the menu, its ID is the menu's base ID
	list:          clay.ElementDeclaration, // popup container
	item:          clay.ElementDeclaration, // one row
	text:          clay.TextElementConfig,
	item_hover:    clay.Color,
	danger_text:   clay.Color,
	disabled_text: clay.Color,
	separator:     clay.Color,
}

// Menu look from the current theme. The trigger is a secondary button with the given label.
style_menu :: proc(id: clay.ElementId, label: string, disabled := false) -> MenuConfig {
	c := current_theme
	return {
		trigger = style_button(id, label, .Secondary, disabled),
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

// Declares a menu button. Clicking it opens a floating list below the button; clicking an entry
// closes the list. Clicking elsewhere or pressing Escape closes it as well.
// The open state is kept internally, the caller owns no state.
// Returns the index of the clicked entry and true in the frame of the click, otherwise (-1, false):
//
//   if i, ok := kiln.menu(items, cfg); ok { ... }
menu :: proc(items: []MenuItem, cfg: MenuConfig) -> (int, bool) {
	picked := -1
	trigger_id := cfg.trigger.id
	list_id := clay.ID("menu_list", trigger_id.id)

	if button(cfg.trigger) {popup_set(trigger_id, !popup_is_open(trigger_id))}
	if cfg.trigger.disabled {popup_set(trigger_id, false)}

	if popup_is_open(trigger_id) {
		outside :=
			rl.IsMouseButtonPressed(.LEFT) &&
			!clay.PointerOver(trigger_id) &&
			!clay.PointerOver(list_id)
		if outside || rl.IsKeyPressed(.ESCAPE) {popup_set(trigger_id, false)}
	}

	if popup_is_open(trigger_id) {
		// The popup is attached to the trigger by ID and at least as wide as the trigger.
		data := clay.GetElementData(trigger_id)
		list := cfg.list
		list.layout.sizing.width = clay.SizingFit({min = data.found ? data.boundingBox.width : 0})
		list.floating = {
			attachTo           = .ElementWithId,
			parentId           = trigger_id.id,
			attachment         = {element = .LeftTop, parent = .LeftBottom},
			offset             = {0, px(4)},
			zIndex             = 100,
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

				item_id := clay.ID("menu_item", trigger_id.id * 1000 + u32(i))
				s := interact(item_id, it.disabled)
				if s.clicked {
					picked = i
					popup_set(trigger_id, false)
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
