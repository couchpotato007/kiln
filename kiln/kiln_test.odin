package kiln

// Tests that drive real frames headlessly:
//
//   odin test kiln -define:KILN_SNAPSHOT=true
//
// Without the define, tasks run on real threads (the frame test needs the snapshot backend).

import "base:runtime"
import "core:testing"
import "core:time"

@(test)
test_dates :: proc(t: ^testing.T) {
	testing.expect_value(t, date_weekday({2026, 10, 26}), 0) // Monday
	testing.expect_value(t, date_weekday({1990, 5, 17}), 3) // Thursday
	testing.expect_value(t, date_add_months({2024, 1, 31}, 1), Date{2024, 2, 29})
	testing.expect_value(t, date_add_months({2023, 1, 31}, 1), Date{2023, 2, 28})
	testing.expect_value(t, date_add_months({2026, 1, 15}, -1), Date{2025, 12, 15})
	testing.expect_value(t, date_add_days({2026, 12, 31}, 1), Date{2027, 1, 1})
	testing.expect_value(t, date_add_days({2024, 2, 28}, 1), Date{2024, 2, 29})
	testing.expect_value(t, date_add_days({2023, 2, 28}, 1), Date{2023, 3, 1})
	testing.expect(t, date_valid({2024, 2, 29}))
	testing.expect(t, !date_valid({2023, 2, 29}))
	testing.expect(t, !date_valid({2000, 13, 1}))
	testing.expect_value(t, date_diff({2026, 1, 1}, {2027, 1, 1}), 365)

	d, ok := date_parse("2026-10-26")
	testing.expect(t, ok)
	testing.expect_value(t, d, Date{2026, 10, 26})
	testing.expect_value(t, date_format(d), "2026-10-26")
	_, bad := date_parse("2026-02-30")
	testing.expect(t, !bad)

	// Every day of four centuries survives the round trip through the day count.
	day := Date{1900, 1, 1}
	for _ in 0 ..< 146097 {
		next := date_add_days(day, 1)
		testing.expect(t, date_valid(next))
		testing.expect_value(t, date_compare(day, next), -1)
		testing.expect_value(t, civil_from_days(days_from_civil(next)), next)
		day = next
	}
	free_all(context.temp_allocator)
}

Test_Inner :: struct {
	n: int,
}
Test_Module_Msg :: union {
	Test_Inner,
}
Test_Other :: struct {}
Test_App_Msg :: union {
	Test_Other,
	Test_Module_Msg,
}

@(test)
test_task_messages :: proc(t: ^testing.T) {
	// A variant of a nested union arrives as the app's message type.
	task(proc(n: int) -> Test_Inner {return {n * 2}}, 21)
	task(proc(_: int) -> Test_Other {return {}}, 0)
	testing.expect_value(t, tasks_running(), 2)

	out := make([dynamic]Test_App_Msg, context.temp_allocator)
	for i := 0; len(out) < 2 && i < 200; i += 1 {
		tasks_drain(&out)
		if len(out) < 2 {time.sleep(10 * time.Millisecond)}
	}
	testing.expect_value(t, len(out), 2)
	testing.expect_value(t, tasks_running(), 0)
	if len(out) == 2 {
		module, is_module := out[0].(Test_Module_Msg)
		testing.expect(t, is_module)
		inner, is_inner := module.(Test_Inner)
		testing.expect(t, is_inner)
		testing.expect_value(t, inner.n, 42)
		_, is_other := out[1].(Test_Other)
		testing.expect(t, is_other)
	}
	free_all(context.temp_allocator)
}

// A frame with only a password field; returns the text it reports.
@(private = "file")
Field_Model :: struct {
	value: string,
	text:  string,
	id:    Id,
}

@(private = "file")
field_frame :: proc(m: ^Field_Model, input: Input) {
	view :: proc(m: ^Field_Model, _: ^[dynamic]int) {
		m.text, _ = text_field(m.value, "pw", password = true)
		m.id = last_id()
	}
	app := App(Field_Model, int) {
		view = view,
	}
	app_frame(app, m, input, {})
}

@(test)
test_password_field :: proc(t: ^testing.T) {
	when !KILN_SNAPSHOT {return}
	// kiln's UI state lives for the whole program; keep it out of the leak report.
	context.allocator = runtime.heap_allocator()
	app_init({})
	input := Input {
		mouse  = {-1000, -1000},
		dt     = 1.0 / 60,
		window = {400, 300},
		dpi    = 1,
	}
	m: Field_Model
	field_frame(&m, input)
	g_focus = m.id.id

	typed := []rune{'a', 'ä', '€', 'b'}
	step := input
	step.chars = typed
	field_frame(&m, step)
	testing.expect_value(t, m.text, "aä€b")
	m.value = "aä€b"
	e := g_edits[m.id.id]
	testing.expect_value(t, e.cursor, len("aä€b"))

	// Two runes to the left and Backspace removes the "ä", not a byte of it.
	for k in ([]Key{.Left, .Left, .Backspace}) {
		step = input
		step.keys = {k}
		field_frame(&m, step)
	}
	testing.expect_value(t, m.text, "a€b")
	testing.expect_value(t, e.cursor, 1)
	m.value = "a€b"

	// Clicks are measured on the dots: past the second dot means after the "€".
	testing.expect_value(t, hit_offset(e, measure("••", .Body) + 1, true), len("a€"))
	testing.expect_value(t, shown_offset("a€b", len("a€"), true), 2 * len(MASK))
	testing.expect_value(t, shown_text("a€b", true), "•••")

	// No copying out of a masked field.
	backend_set_clipboard("")
	step = input
	step.ctrl = true
	step.keys = {.A}
	field_frame(&m, step)
	step.keys = {.C}
	field_frame(&m, step)
	testing.expect_value(t, backend_get_clipboard(), "")

	// Pasting still works.
	backend_set_clipboard("xy")
	step.keys = {.V}
	field_frame(&m, step)
	testing.expect_value(t, m.text, "xy")
	free_all(context.temp_allocator)
}
