package todo

import "core:fmt"
import "core:strings"
import "lib:kiln"

Item :: struct {
	text: string,
	done: bool,
}

Model :: struct {
	field: kiln.TextField,
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
		text := strings.trim_space(kiln.text_field_string(&m.field))
		if len(text) == 0 {return}
		append(&m.items, Item{text = strings.clone(text)})
		kiln.text_field_set(&m.field, "")
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
	input_empty := len(strings.trim_space(kiln.text_field_string(&m.field))) == 0

	if kiln.card() {
		if kiln.hstack(.SM) {
			res := kiln.text_field(
				&m.field,
				kiln.style_textfield(kiln.id_local("new"), "Neue Aufgabe..."),
			)
			if res.submitted {append(out, Add{})}

			if kiln.button("Hinzufügen", disabled = input_empty) {append(out, Add{})}
		}

		frac: f32 = len(m.items) > 0 ? f32(done) / f32(len(m.items)) : 0
		kiln.progress(frac, kiln.style_progress(kiln.id_local("progress")))
		kiln.label(
			fmt.tprintf("%d von %d erledigt", done, len(m.items)),
			.Caption,
			kiln.current_theme.text_muted,
		)
		kiln.separator()

		if kiln.scroll_view(240) {
			if len(m.items) == 0 {
				kiln.label("Nichts zu tun.", .Body, kiln.current_theme.text_disabled)
			}
			for it, i in m.items {
				if kiln.hstack(.SM) {
					checked := it.done
					cb := kiln.style_checkbox(kiln.id_local("done", u32(i)), it.text)
					if it.done {cb.text.textColor = kiln.current_theme.text_disabled}
					if kiln.checkbox(&checked, cb) {append(out, Toggle{i})}

					kiln.spacer()
					if kiln.button("x", .Ghost, id = kiln.id_local("del", u32(i))) {
						append(out, Remove{i})
					}
				}
			}
		}

		if kiln.hstack(.SM) {
			kiln.spacer()
			if kiln.button("Erledigte entfernen", .Secondary, done == 0) {
				append(out, Clear_Done{})
			}
		}
	}
}
