package counter

import "core:fmt"
import "lib:kiln"

Model :: struct {
	value: int,
	step:  int,
}

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
	if kiln.card() {
		kiln.label(fmt.tprintf("Zähler: %d", m.value), .Subtitle)

		step := m.step
		if kiln.slider(&step, 1, 10) {
			append(out, Set_Step{step})
		}
		kiln.label(fmt.tprintf("Schritt: %d", m.step))

		if kiln.hstack() {
			if kiln.button("-", .Secondary) {append(out, Dec{})}
			if kiln.button("+") {append(out, Inc{})}
			kiln.spacer()
			if kiln.button("Reset", .Danger) {append(out, Reset{})}
		}
	}
}
