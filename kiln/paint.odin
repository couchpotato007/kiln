package kiln

// Painting: lines, circles and images drawn into an element, for custom widgets that need more
// than Clay's rectangles, borders and text (drawing surfaces, sparklines, gauges, ...).
//
// A painter collects shapes for one frame; `paint` hands it to an element, which draws its
// background, then the shapes in order (cut off at its bounds), then its children:
//
//   p := kiln.painter(kiln.scale_factor())                 // coordinates in units
//   kiln.paint_line(p, points, 2, kiln.theme().primary)
//   if clay.UI(eid)({layout = ..., backgroundColor = ..., custom = kiln.paint(p)}) {}
//
// Coordinates are relative to the element's top left corner. Painters and their shapes live
// until the end of the frame.

import clay "clay-odin"

Painter :: struct {
	scale:  f32, // multiplies coordinates and widths: 1 = pixels, `scale_factor()` = units
	shapes: [dynamic]Shape,
}

@(private)
Shape :: union {
	Shape_Line,
	Shape_Circle,
	Shape_Image,
}

// A polyline with round joins and caps; a single point is a dot.
@(private)
Shape_Line :: struct {
	points: [][2]f32, // pixels
	width:  f32,
	color:  Color,
}

@(private)
Shape_Circle :: struct {
	center:        [2]f32,
	radius, width: f32, // width 0 = filled, otherwise a ring of that width centered on the radius
	color:         Color,
}

@(private)
Shape_Image :: struct {
	handle:    rawptr,
	pos, size: [2]f32,
	tint:      Color, // multiplies the pixels
}

// A new painter for this frame. `scale` multiplies all coordinates and widths, so with
// `scale_factor()` a widget paints in units and its drawing follows the zoom.
painter :: proc(scale: f32 = 1) -> ^Painter {
	p := new(Painter, context.temp_allocator)
	p.scale = scale
	p.shapes = make([dynamic]Shape, context.temp_allocator)
	return p
}

// The custom config that makes an element draw the painter's shapes: `custom = kiln.paint(p)`.
paint :: proc(p: ^Painter) -> clay.CustomElementConfig {
	return {customData = p}
}

// A line through `points` (copied) with round joins and caps; one point gives a dot.
paint_line :: proc(p: ^Painter, points: [][2]f32, width: f32, color: Color) {
	if len(points) == 0 || width <= 0 || color.a <= 0 {return}
	pts := make([][2]f32, len(points), context.temp_allocator)
	for q, i in points {pts[i] = q * p.scale}
	append(&p.shapes, Shape_Line{pts, width * p.scale, color})
}

// A filled circle, or with `width > 0` a ring of that width centered on `radius`.
paint_circle :: proc(p: ^Painter, center: [2]f32, radius: f32, color: Color, width: f32 = 0) {
	if radius <= 0 || color.a <= 0 {return}
	append(&p.shapes, Shape_Circle{center * p.scale, radius * p.scale, width * p.scale, color})
}

// An image stretched over the rectangle at `pos` with `size`, its pixels multiplied by `tint`.
paint_image :: proc(p: ^Painter, img: Image, pos, size: [2]f32, tint := Color{255, 255, 255, 255}) {
	if img.handle == nil {return}
	append(&p.shapes, Shape_Image{img.handle, pos * p.scale, size * p.scale, tint})
}
