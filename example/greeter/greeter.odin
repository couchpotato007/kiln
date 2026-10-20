package greeter

import "core:fmt"
import "core:strings"
import clay "lib:clay-odin"
import "lib:theme"
import "lib:widgets"

Model :: struct {
	field:    widgets.TextField, // reiner UI-State, wird vom Widget selbst verwaltet
	greeting: string,
}

Msg :: enum {
	Submit,
	Clear,
}

init :: proc() -> Model {
	return {}
}

update :: proc(m: ^Model, msg: Msg) {
	switch msg {
	case .Submit:
		delete(m.greeting)
		m.greeting = strings.clone(widgets.text_field_string(&m.field))
	case .Clear:
		delete(m.greeting)
		m.greeting = ""
		widgets.text_field_set(&m.field, "")
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if widgets.card() {
		res := widgets.text_field(
			&m.field,
			widgets.style_textfield(clay.ID_LOCAL("name"), "Name..."),
		)
		if res.submitted {append(out, Msg.Submit)}

		if widgets.hstack(.SM) {
			if widgets.button("Begrüßen") {append(out, Msg.Submit)}
			if widgets.button("Leeren", .Ghost) {append(out, Msg.Clear)}
		}
		if len(m.greeting) > 0 {
			widgets.label(fmt.tprintf("Hallo %s!", m.greeting), .Subtitle, theme.current.secondary)
		}
	}
}
