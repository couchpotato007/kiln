package counter

import "core:fmt"
import clay "lib:clay-odin"
import "lib:widgets"

Model :: struct {
	value: int,
	step:  int,
}

// Jede Variante ist ein eigener Typ. Nachrichten ohne Daten sind leere Structs.
Inc :: struct {}
Dec :: struct {}
Reset :: struct {}
Set_Step :: struct {
	step: int,
}

Msg :: union #no_nil {
	Inc,
	Dec,
	Reset,
	Set_Step,
}

init :: proc() -> Model {
	return {step = 1}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Inc:
		m.value += m.step
	case Dec:
		m.value -= m.step
	case Reset:
		m.value = 0
	case Set_Step:
		m.step = v.step
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if widgets.card() {
		widgets.label(fmt.tprintf("Zähler: %d", m.value), .Subtitle)

		step := m.step
		if widgets.slider(&step, 1, 10, widgets.style_slider(clay.ID_LOCAL("step"))) {
			append(out, Set_Step{step = step})
		}
		widgets.label(fmt.tprintf("Step: %d", step))

		if widgets.hstack(.SM) {
			if widgets.button("-", .Secondary) {append(out, Dec{})}
			if widgets.button("+") {append(out, Inc{})}
			widgets.spacer()
			if widgets.button("Reset", .Danger) {append(out, Reset{})}
		}
	}
}
