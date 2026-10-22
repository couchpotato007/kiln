package greeter

import "core:fmt"
import "core:strings"
import "lib:kiln"

Model :: struct {
	field:    kiln.TextField,
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
		m.greeting = strings.clone(kiln.text_field_string(&m.field))
	case .Clear:
		delete(m.greeting)
		m.greeting = ""
		kiln.text_field_set(&m.field, "")
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card() {
		if kiln.text_field(&m.field, "Name...").submitted {append(out, Msg.Submit)}

		if kiln.hstack() {
			if kiln.button("Begrüßen") {append(out, Msg.Submit)}
			if kiln.button("Leeren", .Ghost) {append(out, Msg.Clear)}
		}
		if len(m.greeting) > 0 {
			kiln.label(fmt.tprintf("Hallo %s!", m.greeting), .Subtitle, kiln.theme().secondary)
		}
	}
}
