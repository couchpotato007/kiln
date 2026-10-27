package kiln

// Tests that drive real frames headlessly:
//
//   odin test kiln -define:KILN_SNAPSHOT=true
//
// Without the define, tasks run on real threads (the frame test needs the snapshot backend).

import "base:runtime"
import "core:sync"
import "core:testing"
import "core:time"
import clay "clay-odin"

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

// Tests that run frames share kiln's global UI state (and Clay's), so they take turns.
@(private = "file")
g_frames_lock: sync.Mutex

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
	sync.mutex_lock(&g_frames_lock)
	defer sync.mutex_unlock(&g_frames_lock)
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

// Coverage (alpha) of the pixel at (x, y) of an SVG rendered at `size` pixels.
@(private = "file")
svg_alpha :: proc(src: string, size, x, y: int) -> u8 {
	svg, ok := svg_parse(src)
	defer svg_destroy(&svg)
	if !ok {return 0}
	return svg_rasterize(&svg, size, size, context.temp_allocator)[y * size + x].a
}

@(test)
test_svg :: proc(t: ^testing.T) {
	// A filled square covers its pixels fully, nothing outside.
	square := `<svg viewBox="0 0 10 10"><rect x="2" y="2" width="6" height="6"/></svg>`
	testing.expect_value(t, svg_alpha(square, 10, 5, 5), 255)
	testing.expect_value(t, svg_alpha(square, 10, 1, 5), 0)
	// Half a pixel of coverage at an edge.
	half := `<svg viewBox="0 0 10 10"><path d="M2.5 0H10V10H2.5z"/></svg>`
	testing.expect(t, abs(int(svg_alpha(half, 10, 2, 5)) - 128) <= 2)

	// even-odd leaves a hole, nonzero (same winding) does not.
	RINGS :: `<path d="M1 1h8v8h-8z M3 3h4v4h-4z"/>`
	evenodd := `<svg viewBox="0 0 10 10" fill-rule="evenodd">` + RINGS + `</svg>`
	nonzero := `<svg viewBox="0 0 10 10">` + RINGS + `</svg>`
	testing.expect_value(t, svg_alpha(evenodd, 10, 5, 5), 0)
	testing.expect_value(t, svg_alpha(nonzero, 10, 5, 5), 255)

	// Strokes: a 2 wide line along y = 5 covers rows 4 and 5; round caps reach past the ends.
	line := `<svg viewBox="0 0 10 10"><path d="M3 5H7" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round"/></svg>`
	testing.expect_value(t, svg_alpha(line, 10, 5, 4), 255)
	testing.expect_value(t, svg_alpha(line, 10, 5, 6), 0)
	testing.expect(t, svg_alpha(line, 10, 2, 4) > 100)

	// Arcs, relative commands, transforms and implicit line-tos after a move.
	circle := `<svg viewBox="0 0 10 10"><g transform="translate(5 5)"><path d="M-3 0a3 3 0 1 0 6 0a3 3 0 1 0-6 0z"/></g></svg>`
	testing.expect_value(t, svg_alpha(circle, 10, 5, 5), 255)
	testing.expect_value(t, svg_alpha(circle, 10, 0, 0), 0)
	poly := `<svg viewBox="0 0 10 10"><path d="m1 1 8 0 0 8-8 0z"/></svg>`
	testing.expect_value(t, svg_alpha(poly, 10, 5, 5), 255)

	// One color (here currentColor) is monochrome, two colors are not.
	mono, _ := svg_parse(ICON_CALENDAR.svg)
	testing.expect(t, mono.mono)
	svg_destroy(&mono)
	colored, _ := svg_parse(`<svg viewBox="0 0 2 2"><rect width="1" height="1" fill="red"/><rect x="1" width="1" height="1" fill="#00f"/></svg>`)
	testing.expect(t, !colored.mono)
	svg_destroy(&colored)

	// All built-in icons parse and draw something.
	for ic in ([]Icon{ICON_CHECK, ICON_CLOSE, ICON_CHEVRON_DOWN, ICON_CHEVRON_UP, ICON_CHEVRON_LEFT, ICON_CHEVRON_RIGHT, ICON_MENU, ICON_MORE, ICON_PLUS, ICON_MINUS, ICON_SEARCH, ICON_CALENDAR, ICON_EYE, ICON_EYE_OFF, ICON_STAR}) {
		svg, ok := svg_parse(ic.svg)
		testing.expect(t, ok)
		pixels := svg_rasterize(&svg, 24, 24, context.temp_allocator)
		ink := 0
		for p in pixels {ink += int(p.a)}
		testing.expect(t, ink > 255 * 10)
		svg_destroy(&svg)
	}
	free_all(context.temp_allocator)
}

// A frame with one custom widget built like an app would build it: `interact`, `widget_state`
// and a painter. It records what the widget saw.
@(private = "file")
Drag_Model :: struct {
	s:       Interaction,
	points:  ^[dynamic][2]f32,
	created: bool,
	painter: ^Painter,
}

@(private = "file")
drag_frame :: proc(m: ^Drag_Model, mouse: [2]f32, buttons: bit_set[MouseButton], edge: enum {
		None,
		Press,
		Release,
	}) {
	view :: proc(m: ^Drag_Model, _: ^[dynamic]int) {
		if column(padding = .LG) {
			eid := id("pad")
			m.s = interact(eid)
			Draft :: struct {
				points: [dynamic][2]f32,
			}
			d: ^Draft
			d, m.created = widget_state(eid, Draft, proc(d: ^Draft) {delete(d.points)})
			if m.s.started {clear(&d.points)}
			if m.s.held {append(&d.points, m.s.pos)}
			m.points = &d.points
			m.painter = painter()
			paint_line(m.painter, d.points[:], 2, g_theme.text)
			if clay.UI(eid)({layout = {sizing = {clay.SizingFixed(200), clay.SizingFixed(100)}}, custom = paint(m.painter)}) {}
		}
	}
	input := Input {
		mouse  = mouse,
		down   = buttons,
		dt     = 1.0 / 60,
		window = {400, 300},
		dpi    = 1,
	}
	if edge == .Press {input.pressed = {.Left}}
	if edge == .Release {input.released = {.Left}}
	app_frame(App(Drag_Model, int){view = view}, m, input, {})
}

@(test)
test_drag_and_paint :: proc(t: ^testing.T) {
	when !KILN_SNAPSHOT {return}
	context.allocator = runtime.heap_allocator()
	sync.mutex_lock(&g_frames_lock)
	defer sync.mutex_unlock(&g_frames_lock)
	app_init({})
	m: Drag_Model
	// Two frames to lay the pad out (padding .LG puts it off the origin) and register it.
	drag_frame(&m, {-100, -100}, {}, .None)
	drag_frame(&m, {-100, -100}, {}, .None)
	testing.expect(t, !m.created)

	drag_frame(&m, {40, 50}, {.Left}, .Press)
	testing.expect(t, m.s.started)
	testing.expect(t, m.s.held)
	origin := [2]f32{40, 50} - m.s.pos // the pad's top left corner
	testing.expect(t, origin.x > 0 && origin.y > 0)

	// Dragging out of the pad still belongs to it.
	drag_frame(&m, {90, 60}, {.Left}, .None)
	testing.expect(t, !m.s.started)
	testing.expect_value(t, m.s.delta, [2]f32{50, 10})
	drag_frame(&m, {500, 60}, {.Left}, .None)
	testing.expect(t, m.s.held)
	testing.expect(t, !m.s.hovered)

	drag_frame(&m, {500, 60}, {}, .Release)
	testing.expect(t, m.s.released)
	testing.expect(t, !m.s.clicked) // released outside the pad
	testing.expect_value(t, len(m.points), 3)
	if len(m.points) == 3 {testing.expect_value(t, m.points[1], [2]f32{90, 60} - origin)}
	testing.expect_value(t, len(m.painter.shapes), 1)

	drag_frame(&m, {500, 60}, {}, .None)
	testing.expect(t, !m.s.released)

	// The state is freed with `destroy` once the widget is gone for long enough.
	testing.expect(t, m.s.pos != {})
	testing.expect(t, len(g_widget_states) >= 1)
	g_frame += STALE_FRAMES + 1
	collect_garbage()
	testing.expect_value(t, len(g_widget_states), 0)
	free_all(context.temp_allocator)
}
