package canvas

// A drawing canvas, built only from kiln's public API like any app-side custom widget would be.
// The strokes live in the model; the stroke being drawn is UI state that kiln keeps for the
// widget until the pointer is released.

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
	case Undo:
		if len(m.strokes) > 0 {delete(pop(&m.strokes).points)}
	case Clear:
		for s in m.strokes {delete(s.points)}
		clear(&m.strokes)
	case Set_Color:
		m.color = v.index
	case Set_Width:
		m.width = v.width
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
		if kiln.field("Stiftbreite") {
			if w, ok := kiln.slider(m.width, 1, 24); ok {append(out, Set_Width{w})}
		}
		if s, ok := drawing(m.strokes[:], color, m.width); ok {append(out, Add_Stroke{s})}
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

// The stroke being drawn, kept by kiln between frames.
@(private)
Draft :: struct {
	points: [dynamic][2]f32,
}

@(private)
draft_destroy :: proc(d: ^Draft) {
	delete(d.points)
}

// Points closer than this (units) to the previous one are dropped.
@(private)
MIN_STEP :: 1.5

// A surface to draw on with the pointer. Shows `strokes` and returns the new stroke (points in
// the temp allocator) when the pointer is released.
drawing :: proc(strokes: []Stroke, color: kiln.Color, width: f32, height: f32 = 360) -> (stroke: Stroke, done: bool) {
	eid := kiln.id("drawing")
	s := kiln.interact(eid)
	draft, _ := kiln.widget_state(eid, Draft, draft_destroy)
	scale := kiln.scale_factor()
	pos := s.pos / scale // pixels to units, so strokes keep their place when the zoom changes

	if s.started {clear(&draft.points)}
	if s.held {
		n := len(draft.points)
		if n == 0 || linalg.distance(draft.points[n - 1], pos) >= MIN_STEP {append(&draft.points, pos)}
	}
	if s.released && len(draft.points) > 0 {
		stroke = {
			points = make([dynamic][2]f32, len(draft.points), context.temp_allocator),
			color  = color,
			width  = width,
		}
		copy(stroke.points[:], draft.points[:])
		done = true
		clear(&draft.points)
	}

	// Painted in units: the painter scales to pixels.
	p := kiln.painter(scale)
	for st in strokes {kiln.paint_line(p, st.points[:], st.width, st.color)}
	if len(draft.points) > 0 {kiln.paint_line(p, draft.points[:], width, color)}
	if s.hovered && !s.held {
		// Where the pen would land, as a ring of the theme's line width.
		kiln.paint_circle(p, pos, width / 2, color, kiln.line_width() / scale)
	}

	t := kiln.theme()
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(kiln.px(height))}},
		backgroundColor = t.sunken,
		cornerRadius = kiln.corners(.MD),
		border = kiln.outline(t.border),
		custom = kiln.paint(p),
	},
	) {}
	kiln.set_last(eid, s)
	return
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
