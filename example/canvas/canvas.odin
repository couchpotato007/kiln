package canvas

// A drawing canvas, built only from kiln's public API like any app-side custom widget would be:
// raw pointer events in, a drawing out. The strokes live in the model; the stroke being drawn
// and an image of the finished strokes are UI state that kiln keeps for the widget.

import "core:fmt"
import "core:math/linalg"
import "lib:kiln"
import clay "lib:kiln/clay-odin"

Stroke :: struct {
	points: [dynamic][2]f32, // units, relative to the canvas' top left corner
	color:  kiln.Color,
	width:  f32, // units
}

Model :: struct {
	strokes: [dynamic]Stroke,
	version: int, // counts changes of `strokes`, so the canvas knows when to draw them again
	color:   int, // index into the theme's chart colors
	width:   f32,
}

Add_Stroke :: struct {
	stroke: Stroke, // points in the temp allocator
}
Undo :: struct {}
Clear :: struct {}
Set_Color :: struct {
	index: int,
}
Set_Width :: struct {
	width: f32,
}

Msg :: union {
	Add_Stroke,
	Undo,
	Clear,
	Set_Color,
	Set_Width,
}

MIN_WIDTH :: 1
MAX_WIDTH :: 24

init :: proc() -> Model {
	return {width = 4}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Add_Stroke:
		s := v.stroke
		s.points = make([dynamic][2]f32, len(v.stroke.points))
		copy(s.points[:], v.stroke.points[:])
		append(&m.strokes, s)
		m.version += 1
	case Undo:
		if len(m.strokes) > 0 {delete(pop(&m.strokes).points)}
		m.version += 1
	case Clear:
		for s in m.strokes {delete(s.points)}
		clear(&m.strokes)
		m.version += 1
	case Set_Color:
		m.color = v.index
	case Set_Width:
		m.width = clamp(v.width, MIN_WIDTH, MAX_WIDTH)
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	t := kiln.theme()
	color := t.chart[m.color]

	if kiln.card("Leinwand") {
		if kiln.flow() {
			for c, i in t.chart {
				if kiln.scope(i) {
					if color_button(c, i == m.color) {append(out, Set_Color{i})}
				}
			}
		}
		if kiln.field("Stiftbreite", help = "Auch mit dem Mausrad über der Fläche") {
			if w, ok := kiln.slider(m.width, MIN_WIDTH, MAX_WIDTH); ok {append(out, Set_Width{w})}
		}
		r := drawing_pad(m.strokes[:], m.version, color, m.width)
		if r.done {append(out, Add_Stroke{r.stroke})}
		if r.width_steps != 0 {append(out, Set_Width{m.width + r.width_steps})}
		if kiln.actions() {
			kiln.text(fmt.tprintf("%d Striche", len(m.strokes)), .Caption, .Muted)
			kiln.spacer()
			if kiln.button("Leeren", .Ghost, disabled = len(m.strokes) == 0) {append(out, Clear{})}
			if kiln.button("Rückgängig", .Secondary, disabled = len(m.strokes) == 0) {append(out, Undo{})}
			kiln.tooltip("Strg+Z")
		}
	}

	if kiln.key_pressed(.Z) && .Ctrl in kiln.modifiers() && len(m.strokes) > 0 {append(out, Undo{})}
}

// What happened on the pad in this frame.
Pad_Result :: struct {
	stroke:      Stroke, // the finished stroke (points in the temp allocator), if `done`
	done:        bool,
	width_steps: f32, // wheel steps over the pad, up is positive
}

// UI state of the pad, kept by kiln between frames: the stroke being drawn, and the finished
// strokes as an image, so a frame only draws that image and the new stroke.
@(private)
Pad_State :: struct {
	draft:   [dynamic][2]f32,
	cache:   kiln.Image,
	version: int, // of the strokes in `cache`
	size:    [2]int,
	scale:   f32,
}

@(private)
pad_destroy :: proc(s: ^Pad_State) {
	delete(s.draft)
	kiln.destroy_image(&s.cache)
}

// Points closer than this (units) to the previous one are dropped.
@(private)
MIN_STEP :: 1

// A surface to draw on with the pointer. Shows `strokes` (`version` tells when they changed) and
// returns a new stroke when the pointer is released.
drawing_pad :: proc(strokes: []Stroke, version: int, color: kiln.Color, width: f32, height: f32 = 360) -> (r: Pad_Result) {
	eid := kiln.id("drawing_pad")
	s := kiln.interact(eid)
	st, _ := kiln.widget_state(eid, Pad_State, pad_destroy)
	scale := kiln.scale_factor()

	// Every event, not one sample per frame: fast strokes keep their shape.
	for e in kiln.pointer_events(eid, wheel = true) {
		pos := e.pos / scale // pixels to units, so strokes keep their place when the zoom changes
		#partial switch e.kind {
		case .Press:
			if e.button == .Left {
				clear(&st.draft)
				append(&st.draft, pos)
			}
		case .Move:
			n := len(st.draft)
			if s.held && n > 0 && linalg.distance(st.draft[n - 1], pos) >= MIN_STEP {append(&st.draft, pos)}
		case .Release:
			if e.button == .Left && len(st.draft) > 0 {
				r.stroke = {make([dynamic][2]f32, len(st.draft), context.temp_allocator), color, width}
				copy(r.stroke.points[:], st.draft[:])
				r.done = true
				clear(&st.draft)
			}
		case .Wheel:
			r.width_steps += e.wheel.y > 0 ? 1 : -1
		}
	}

	// The finished strokes are drawn into an image when they, the size or the zoom change.
	_, _, w, h, laid_out := kiln.element_rect(eid)
	size := [2]int{int(w), int(h)}
	if laid_out && (st.cache.handle == nil || st.version != version || st.size != size || st.scale != scale) {
		kiln.destroy_image(&st.cache)
		all := kiln.drawing(scale)
		for stroke in strokes {stroke_line(all, stroke.points[:], stroke.width, stroke.color)}
		st.cache = kiln.render_image(all, size.x, size.y)
		st.version, st.size, st.scale = version, size, scale
	}

	d := kiln.drawing(scale)
	if st.cache.handle != nil {
		kiln.draw_image(d, st.cache, {}, {f32(size.x), f32(size.y)} / scale)
	} else {
		for stroke in strokes {stroke_line(d, stroke.points[:], stroke.width, stroke.color)}
	}
	stroke_line(d, st.draft[:], width, color)
	if s.hovered && !s.held {
		// Where the pen would land.
		kiln.circle_path(d, s.pos / scale, width / 2)
		kiln.stroke_path(d, color, kiln.line_width() / scale)
	}

	t := kiln.theme()
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(kiln.px(height))}},
		backgroundColor = t.sunken,
		cornerRadius = kiln.corners(.MD),
		border = kiln.outline(t.border),
		custom = kiln.draw(d),
	},
	) {}
	kiln.set_last(eid, s)
	return
}

// A line through `points`; a single point is a dot.
@(private)
stroke_line :: proc(d: ^kiln.Drawing, points: [][2]f32, width: f32, color: kiln.Color) {
	if len(points) == 0 {return}
	kiln.move_to(d, points[0])
	for p in points[1:] {kiln.line_to(d, p)}
	kiln.stroke_path(d, color, width)
}

// A round color button, with a ring when selected.
@(private)
color_button :: proc(color: kiln.Color, selected: bool) -> bool {
	eid := kiln.id("color")
	s := kiln.interact(eid)
	t := kiln.theme()
	d := kiln.size(.Control)
	kiln.flow_item(eid)
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
		backgroundColor = kiln.mix(color, t.text, 0.25 * kiln.anim(eid, 0, s.hovered ? 1 : 0)),
		cornerRadius = kiln.corners(.Full),
		border = selected ? {color = t.text, width = clay.BorderOutside(u16(2 * kiln.line_width()))} : {},
	},
	) {}
	kiln.set_last(eid, s)
	return s.clicked
}
