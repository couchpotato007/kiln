package widgets


import clay "lib:clay-odin"
import "lib:theme"
import rl "vendor:raylib"

// Zustand (lebt beim Aufrufer). index < 0 = nichts gewählt.
Select :: struct {
	index: int,
	open:  bool,
}

SelectConfig :: struct {
	id:                clay.ElementId,
	box:               clay.ElementDeclaration, // geschlossenes Feld
	text:              clay.TextElementConfig,
	placeholder:       string,
	placeholder_color: clay.Color,
	arrow_color:       clay.Color,
	border_hover:      clay.Color, // Border bei Hover/offen
	list:              clay.ElementDeclaration, // Popup-Container
	item:              clay.ElementDeclaration, // eine Zeile im Popup
	item_hover:        clay.Color,
	item_selected:     clay.Color,
	disabled:          bool,
	disabled_text:     clay.Color,
}

style_select :: proc(id: clay.ElementId, placeholder := "", disabled := false) -> SelectConfig {
	c := theme.current
	return {
		id = id,
		box = {
			layout = {
				sizing = {clay.SizingGrow(), theme.size_control_height()},
				padding = theme.pad_xy(.MD, .None),
				childGap = theme.sp(.SM),
				childAlignment = {y = .Center},
			},
			backgroundColor = c.bg_sunken,
			cornerRadius = theme.radius(.MD),
			border = theme.border_box(c.border),
		},
		text = theme.text_style(.Body, c.text),
		placeholder = placeholder,
		placeholder_color = c.text_disabled,
		arrow_color = c.text_muted,
		border_hover = c.primary,
		list = {
			layout = {layoutDirection = .TopToBottom, padding = theme.pad_all(.XS)},
			backgroundColor = c.surface_0,
			cornerRadius = theme.radius(.MD),
			border = theme.border_box(c.border_strong),
		},
		item = {
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = theme.pad_xy(.MD, .SM),
			},
			cornerRadius = theme.radius(.SM),
		},
		item_hover = c.surface_1,
		item_selected = c.surface_2,
		disabled = disabled,
		disabled_text = c.text_disabled,
	}
}

// Gibt true zurück, wenn sich die Auswahl geändert hat.
select :: proc(sel: ^Select, options: []string, cfg: SelectConfig) -> bool {
	changed := false
	list_id := clay.ID("select_list", cfg.id.id)

	s := interact(cfg.id, cfg.disabled)
	if s.clicked {sel.open = !sel.open}
	if cfg.disabled {sel.open = false}
	if sel.open {
		outside :=
			rl.IsMouseButtonPressed(.LEFT) &&
			!clay.PointerOver(cfg.id) &&
			!clay.PointerOver(list_id)
		if outside || rl.IsKeyPressed(.ESCAPE) {sel.open = false}
	}

	h := anim(cfg.id, 0, (s.hovered || sel.open) ? 1 : 0)
	data := clay.GetElementData(cfg.id)

	box := cfg.box
	box.border.color = color_lerp(cfg.box.border.color, cfg.border_hover, h)

	text := cfg.text
	shown := cfg.placeholder
	if sel.index >= 0 && sel.index < len(options) {
		shown = options[sel.index]
	} else {
		text.textColor = cfg.placeholder_color
	}
	if cfg.disabled {text.textColor = cfg.disabled_text}

	if clay.UI(cfg.id)(box) {
		clay.Text(shown, text)
		if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(0)}}}) {}
		clay.Text(sel.open ? "^" : "v", theme.text_style(.Body, cfg.arrow_color))

		if sel.open {
			list := cfg.list
			list.layout.sizing.width = clay.SizingFixed(
				data.found ? data.boundingBox.width : theme.px(200),
			)
			list.floating = {
				attachTo = .Parent,
				attachment = {element = .LeftTop, parent = .LeftBottom},
				offset = {0, theme.px(4)},
				zIndex = 100,
				pointerCaptureMode = .Capture,
			}
			if clay.UI(list_id)(list) {
				for opt, i in options {
					item_id := clay.ID("select_item", cfg.id.id * 1000 + u32(i))
					is := interact(item_id)
					if is.clicked {
						sel.index = i
						sel.open = false
						changed = true
					}
					item := cfg.item
					if sel.index == i {item.backgroundColor = cfg.item_selected}
					if is.hovered {item.backgroundColor = cfg.item_hover}
					if clay.UI(item_id)(item) {
						clay.Text(opt, cfg.text)
					}
				}
			}
		}
	}
	return changed
}
