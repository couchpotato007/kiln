package todo

import "core:fmt"
import "core:strings"
import clay "lib:clay-odin"
import "lib:theme"
import "lib:widgets"

Item :: struct {
	text: string,
	done: bool,
}

Model :: struct {
	field: widgets.TextField,
	items: [dynamic]Item,
}

Add :: struct {}
Toggle :: struct {
	index: int,
}
Remove :: struct {
	index: int,
}
Clear_Done :: struct {}

Msg :: union #no_nil {
	Add,
	Toggle,
	Remove,
	Clear_Done,
}

init :: proc() -> Model {
	m: Model
	append(&m.items, Item{text = strings.clone("Clay ausprobieren")})
	append(&m.items, Item{text = strings.clone("Widgets testen"), done = true})
	return m
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Add:
		text := strings.trim_space(widgets.text_field_string(&m.field))
		if len(text) == 0 {return}
		append(&m.items, Item{text = strings.clone(text)})
		widgets.text_field_set(&m.field, "")
	case Toggle:
		if v.index < len(m.items) {
			m.items[v.index].done = !m.items[v.index].done
		}
	case Remove:
		if v.index < len(m.items) {
			delete(m.items[v.index].text)
			ordered_remove(&m.items, v.index)
		}
	case Clear_Done:
		for i := len(m.items) - 1; i >= 0; i -= 1 {
			if m.items[i].done {
				delete(m.items[i].text)
				ordered_remove(&m.items, i)
			}
		}
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	done := 0
	for it in m.items {
		if it.done {done += 1}
	}
	input_empty := len(strings.trim_space(widgets.text_field_string(&m.field))) == 0

	if widgets.card() {
		if widgets.hstack(.SM) {
			res := widgets.text_field(
				&m.field,
				widgets.style_textfield(clay.ID_LOCAL("new"), "Neue Aufgabe..."),
			)
			if res.submitted {append(out, Add{})}

			if widgets.button("Hinzufügen", disabled = input_empty) {append(out, Add{})}
		}

		frac: f32 = len(m.items) > 0 ? f32(done) / f32(len(m.items)) : 0
		widgets.progress(frac, widgets.style_progress(clay.ID_LOCAL("progress")))
		widgets.label(
			fmt.tprintf("%d von %d erledigt", done, len(m.items)),
			.Caption,
			theme.current.text_muted,
		)
		widgets.separator()

		if widgets.scroll_view(240) {
			if len(m.items) == 0 {
				widgets.label("Nichts zu tun.", .Body, theme.current.text_disabled)
			}
			for it, i in m.items {
				if widgets.hstack(.SM) {
					checked := it.done
					cb := widgets.style_checkbox(clay.ID_LOCAL("done", u32(i)), it.text)
					if it.done {cb.text.textColor = theme.current.text_disabled}
					if widgets.checkbox(&checked, cb) {append(out, Toggle{i})}

					widgets.spacer()
					if widgets.button("x", .Ghost, id = clay.ID_LOCAL("del", u32(i))) {
						append(out, Remove{i})
					}
				}
			}
		}

		if widgets.hstack(.SM) {
			widgets.spacer()
			if widgets.button("Erledigte entfernen", .Secondary, done == 0) {
				append(out, Clear_Done{})
			}
		}
	}
}
