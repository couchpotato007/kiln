package kiln

// Drawing: vector graphics for custom widgets, in the spirit of GtkSnapshot and Cairo. A drawing
// records paths, fills, strokes, images and text for one frame; an element shows it with
// `custom = kiln.draw(d)`, behind its border and children and cut off at its bounds:
//
//   d := kiln.drawing(kiln.scale_factor())          // coordinates in units, so it follows the zoom
//   kiln.move_to(d, {0, 40})
//   kiln.curve_to(d, {30, 0}, {60, 80}, {90, 40})
//   kiln.stroke_path(d, kiln.theme().primary, width = 2)
//   if kiln.transform(d, translate = {120, 40}, rotate = math.PI / 8) {
//       kiln.rect_path(d, {-20, -20}, {40, 40}, radius = 6)
//       kiln.fill_path(d, kiln.chart_color(2))
//   }
//   if clay.UI(eid)({layout = ..., backgroundColor = ..., custom = kiln.draw(d)}) {}
//
// Coordinates start at the element's top left corner and grow right and down; angles are in
// radians and turn clockwise. `transform`, `clip` and `opacity` are blocks like containers.
// `render_image` draws a drawing into an image once, e.g. to keep a complex picture between
// frames. Drawings live until the end of the frame.

import "core:hash"
import "core:math"
import "core:slice"
import clay "clay-odin"
import stbtt "vendor:stb/truetype"

Line_Cap :: enum {
	Butt,
	Round,
	Square,
}

Line_Join :: enum {
	Miter,
	Round,
	Bevel,
}

// A drawing being recorded; build it with the procs in this file, not by hand.
Drawing :: struct {
	base:   f32, // the scale given to `drawing`
	path:   Path_Builder, // the current path, in pixels; its `m` is the current transform
	cur:    [2]f32, // the current point, in drawing coordinates
	start:  [2]f32, // where the current subpath started
	ops:    [dynamic]Draw_Op,
	saved:  [dynamic]Mat, // transforms of the enclosing `transform` blocks
	groups: int, // open `clip` and `opacity` blocks
}

@(private)
Draw_Op :: union {
	Draw_Fill,
	Draw_Image,
	Draw_Clip,
	Draw_Group,
	Draw_End,
}

@(private)
Draw_Fill :: struct {
	polys:    Polygons, // pixels
	even_odd: bool,
	color:    Color,
}

@(private)
Draw_Image :: struct {
	handle: rawptr,
	size:   [2]int, // of the image, in its pixels
	m:      Mat, // image pixels to drawing pixels
	tint:   Color,
}

// Everything until the matching `Draw_End` is cut off outside the polygons.
@(private)
Draw_Clip :: struct {
	polys:    Polygons,
	even_odd: bool,
}

// Everything until the matching `Draw_End` is drawn on its own and then blended with `opacity`.
@(private)
Draw_Group :: struct {
	opacity: f32,
}

@(private)
Draw_End :: struct {}

// Curves are flattened to lines that are at most this far off (pixels).
@(private = "file")
DRAW_TOLERANCE :: 0.2

// A new drawing for this frame. `scale` turns drawing coordinates into pixels: 1 draws in
// pixels, `scale_factor()` in units.
drawing :: proc(scale: f32 = 1) -> ^Drawing {
	d := new(Drawing, context.temp_allocator)
	d.base = scale
	d.path = path_builder({scale, 0, 0, scale, 0, 0}, DRAW_TOLERANCE)
	d.ops = make([dynamic]Draw_Op, context.temp_allocator)
	d.saved = make([dynamic]Mat, context.temp_allocator)
	return d
}

// The custom config that makes an element show a drawing: `custom = kiln.draw(d)`.
draw :: proc(d: ^Drawing) -> clay.CustomElementConfig {
	return {customData = d}
}

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

// Starts a new subpath at `p`.
move_to :: proc(d: ^Drawing, p: [2]f32) {
	path_move(&d.path, p)
	d.cur, d.start = p, p
}

// A straight line from the current point to `p`.
line_to :: proc(d: ^Drawing, p: [2]f32) {
	path_continue(d)
	path_line(&d.path, p)
	d.cur = p
}

// A quadratic Bézier curve from the current point to `p` with the control point `c`.
quad_to :: proc(d: ^Drawing, c, p: [2]f32) {
	path_continue(d)
	path_quad(&d.path, d.cur, c, p)
	d.cur = p
}

// A cubic Bézier curve from the current point to `p` with the control points `c1` and `c2`.
curve_to :: proc(d: ^Drawing, c1, c2, p: [2]f32) {
	path_continue(d)
	path_cubic(&d.path, d.cur, c1, c2, p)
	d.cur = p
}

// A circular arc around `center` from angle `from` to `to`. A line connects the current point
// with the start of the arc; `to < from` draws counter-clockwise.
arc :: proc(d: ^Drawing, center: [2]f32, radius, from, to: f32) {
	if path_empty(&d.path) {d.start = center + radius * [2]f32{math.cos(from), math.sin(from)}}
	path_arc(&d.path, center, radius, from, to)
	d.cur = center + radius * [2]f32{math.cos(to), math.sin(to)}
}

// Closes the current subpath with a line back to its start.
close_path :: proc(d: ^Drawing) {
	path_end(&d.path, true)
	d.cur = d.start
}

// A rectangle as a closed subpath, with rounded corners if `radius > 0`.
rect_path :: proc(d: ^Drawing, pos, size: [2]f32, radius: f32 = 0) {
	r := clamp(radius, 0, min(abs(size.x), abs(size.y)) / 2)
	x0, y0, x1, y1 := pos.x, pos.y, pos.x + size.x, pos.y + size.y
	if r <= 0 {
		move_to(d, {x0, y0})
		line_to(d, {x1, y0})
		line_to(d, {x1, y1})
		line_to(d, {x0, y1})
	} else {
		move_to(d, {x0 + r, y0})
		arc(d, {x1 - r, y0 + r}, r, -math.PI / 2, 0)
		arc(d, {x1 - r, y1 - r}, r, 0, math.PI / 2)
		arc(d, {x0 + r, y1 - r}, r, math.PI / 2, math.PI)
		arc(d, {x0 + r, y0 + r}, r, math.PI, 3 * math.PI / 2)
	}
	close_path(d)
}

// A circle as a closed subpath.
circle_path :: proc(d: ^Drawing, center: [2]f32, radius: f32) {
	move_to(d, center + {radius, 0})
	arc(d, center, radius, 0, 2 * math.PI)
	close_path(d)
}

// Makes sure the current subpath has a start, so a segment right after `close_path` or at the
// beginning starts at the current point.
@(private = "file")
path_continue :: proc(d: ^Drawing) {
	if path_empty(&d.path) {
		append(&d.path.points, mat_apply(d.path.m, d.cur))
		d.start = d.cur
	}
}

@(private = "file")
path_clear :: proc(d: ^Drawing) {
	clear(&d.path.points)
	clear(&d.path.ends)
	clear(&d.path.closed)
}

// ---------------------------------------------------------------------------
// Painting the path
// ---------------------------------------------------------------------------

// Fills the inside of the current path (open subpaths are closed) and starts a new path.
// `even_odd` makes overlapping parts holes, otherwise everything enclosed is filled.
fill_path :: proc(d: ^Drawing, color: Color, even_odd := false) {
	path_end(&d.path, false)
	polys := temp_polygons()
	path_polygons(&polys, &d.path)
	if len(polys.ends) > 0 && color.a > 0 {append(&d.ops, Draw_Fill{polys, even_odd, color})}
	path_clear(d)
}

// Draws the outline of the current path `width` wide and starts a new path. A subpath of a single
// point gives a dot with round or square caps.
stroke_path :: proc(d: ^Drawing, color: Color, width: f32, cap := Line_Cap.Round, join := Line_Join.Round, miter_limit: f32 = 4) {
	path_end(&d.path, false)
	if width > 0 && color.a > 0 {
		polys := temp_polygons()
		hw := width / 2 * mat_scale(d.path.m)
		start := 0
		for end, k in d.path.ends {
			poly_stroke(&polys, d.path.points[start:end], d.path.closed[k], hw, cap, join, miter_limit, DRAW_TOLERANCE)
			start = end
		}
		if len(polys.ends) > 0 {append(&d.ops, Draw_Fill{polys, false, color})}
	}
	path_clear(d)
}

@(private = "file")
temp_polygons :: proc() -> Polygons {
	return {make([dynamic][2]f32, context.temp_allocator), make([dynamic]int, context.temp_allocator)}
}

// An image stretched over the rectangle at `pos` with `size`, its pixels multiplied by `tint`.
draw_image :: proc(d: ^Drawing, img: Image, pos, size: [2]f32, tint := Color{255, 255, 255, 255}) {
	if img.handle == nil || img.width <= 0 || img.height <= 0 {return}
	m := mat_mul(d.path.m, {size.x / f32(img.width), 0, 0, size.y / f32(img.height), pos.x, pos.y})
	append(&d.ops, Draw_Image{img.handle, {img.width, img.height}, m, tint})
}

// One line of text in a text style, its top left corner at `pos`. The letters are filled
// outlines, so they turn and scale with `transform`. `measure` gives the width in pixels.
draw_text :: proc(d: ^Drawing, s: string, pos: [2]f32, style := TextStyle.Body, color: Color) {
	if len(s) == 0 || color.a <= 0 || len(g_fonts) == 0 {return}
	size := f32(font_size(style)) / d.base // in drawing coordinates
	face := g_theme.font_faces[style]
	baseline := pos.y + font_ascent(int(face)) * size
	b := path_builder(d.path.m, DRAW_TOLERANCE)
	pen := pos.x
	for r in s {
		fi := font_for(face, r)
		if fi >= len(g_fonts) || !g_fonts[fi].loaded {
			pen += size / 2
			continue
		}
		info := &g_fonts[fi].info
		k := stbtt.ScaleForPixelHeight(info, size)
		at :: proc(x, y: stbtt.vertex_type, pen, baseline, k: f32) -> [2]f32 {
			return {pen + f32(x) * k, baseline - f32(y) * k}
		}
		verts: [^]stbtt.vertex
		n := stbtt.GetCodepointShape(info, r, &verts)
		cur: [2]f32
		for v in verts[:n] {
			p := at(v.x, v.y, pen, baseline, k)
			switch stbtt.vmove(v.type) {
			case .vmove:
				path_move(&b, p)
			case .vline:
				path_line(&b, p)
			case .vcurve:
				path_quad(&b, cur, at(v.cx, v.cy, pen, baseline, k), p)
			case .vcubic:
				path_cubic(&b, cur, at(v.cx, v.cy, pen, baseline, k), at(v.cx1, v.cy1, pen, baseline, k), p)
			case .none:
			}
			cur = p
		}
		if n > 0 {stbtt.FreeShape(info, verts)}
		adv, lsb: i32
		stbtt.GetCodepointHMetrics(info, r, &adv, &lsb)
		pen += f32(adv) * k
	}
	path_end(&b, false)
	polys := temp_polygons()
	path_polygons(&polys, &b)
	if len(polys.ends) > 0 {append(&d.ops, Draw_Fill{polys, false, color})}
}

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

// Moves, turns and scales what is drawn inside: the origin moves to `translate`, then the
// coordinates turn by `rotate` and are scaled by `scale`.
//
//   if kiln.transform(d, translate = center, rotate = angle) { ... }
@(deferred_in = transform_end)
transform :: proc(d: ^Drawing, translate := [2]f32{}, rotate: f32 = 0, scale := [2]f32{1, 1}) -> bool {
	append(&d.saved, d.path.m)
	cs, sn := math.cos(rotate), math.sin(rotate)
	m := mat_mul(d.path.m, {1, 0, 0, 1, translate.x, translate.y})
	m = mat_mul(m, {cs, sn, -sn, cs, 0, 0})
	d.path.m = mat_mul(m, {scale.x, 0, 0, scale.y, 0, 0})
	return true
}

@(private)
transform_end :: proc(d: ^Drawing, _: [2]f32, _: f32, _: [2]f32) {
	if len(d.saved) > 0 {d.path.m = pop(&d.saved)}
}

// Cuts off what is drawn inside at the current path (which it uses up):
//
//   kiln.circle_path(d, c, r)
//   if kiln.clip(d) {kiln.draw_image(d, photo, c - r, 2 * r)}
@(deferred_in = clip_end)
clip :: proc(d: ^Drawing, even_odd := false) -> bool {
	path_end(&d.path, false)
	polys := temp_polygons()
	path_polygons(&polys, &d.path)
	append(&d.ops, Draw_Clip{polys, even_odd})
	d.groups += 1
	path_clear(d)
	return true
}

@(private)
clip_end :: proc(d: ^Drawing, _: bool) {
	group_end(d)
}

// Draws what is inside on its own and blends it with `alpha` (0..1), so overlapping parts do
// not show through each other.
@(deferred_in = opacity_end)
opacity :: proc(d: ^Drawing, alpha: f32) -> bool {
	append(&d.ops, Draw_Group{clamp(alpha, 0, 1)})
	d.groups += 1
	return true
}

@(private)
opacity_end :: proc(d: ^Drawing, _: f32) {
	group_end(d)
}

@(private = "file")
group_end :: proc(d: ^Drawing) {
	if d.groups == 0 {return}
	append(&d.ops, Draw_End{})
	d.groups -= 1
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

// Draws a drawing into a new `width` x `height` image (pixels), e.g. a picture that is
// expensive to draw and changes rarely. Free it with `destroy_image`.
render_image :: proc(d: ^Drawing, width, height: int) -> Image {
	w, h := max(width, 1), max(height, 1)
	return create_image(w, h, draw_rasterize(d, w, h, {}, context.temp_allocator))
}

// A hash of everything a drawing shows, so backends can keep its pixels while it does not change.
@(private)
draw_hash :: proc(d: ^Drawing) -> u64 {
	h := hash.fnv64a(slice.to_bytes([]int{len(d.ops)}))
	for op in d.ops {
		switch o in op {
		case Draw_Fill:
			h = hash.fnv64a(slice.to_bytes(o.polys.points[:]), h)
			h = hash.fnv64a(slice.to_bytes(o.polys.ends[:]), h)
			h = hash.fnv64a(slice.to_bytes([]Color{o.color, {f32(int(o.even_odd)), 1, 0, 0}}), h)
		case Draw_Image:
			h = hash.fnv64a(slice.to_bytes([]Draw_Image{o}), h)
		case Draw_Clip:
			h = hash.fnv64a(slice.to_bytes(o.polys.points[:]), h)
			h = hash.fnv64a(slice.to_bytes(o.polys.ends[:]), h)
			h = hash.fnv64a(slice.to_bytes([]int{2 + int(o.even_odd)}), h)
		case Draw_Group:
			h = hash.fnv64a(slice.to_bytes([]f32{o.opacity, 7}), h)
		case Draw_End:
			h = hash.fnv64a(slice.to_bytes([]int{9}), h)
		}
	}
	return h
}

// A drawing that is only one image without rotation or skew, which backends draw directly:
// its rectangle in pixels and the image.
@(private)
draw_single_image :: proc(d: ^Drawing) -> (img: Draw_Image, rect: [4]f32, ok: bool) {
	if len(d.ops) != 1 {return}
	img, ok = d.ops[0].(Draw_Image)
	if !ok || img.m[1] != 0 || img.m[2] != 0 {return {}, {}, false}
	p0 := mat_apply(img.m, {0, 0})
	p1 := mat_apply(img.m, {f32(img.size.x), f32(img.size.y)})
	return img, {min(p0.x, p1.x), min(p0.y, p1.y), abs(p1.x - p0.x), abs(p1.y - p0.y)}, true
}

// Renders a drawing into `w` x `h` RGBA pixels (not premultiplied), its pixel coordinates moved
// by `offset`. Both backends draw drawings with this, so they look the same everywhere.
@(private)
draw_rasterize :: proc(d: ^Drawing, w, h: int, offset: [2]f32, allocator := context.allocator) -> []Pixel {
	n := w * h
	Group :: struct {
		layer:   [][4]f32, // premultiplied; nil for a clip, which draws into the layer below
		mask:    []f32, // what may be drawn in this group; nil = everything
		opacity: f32,
	}
	groups := make([dynamic]Group, context.temp_allocator)
	append(&groups, Group{layer = make([][4]f32, n, context.temp_allocator)})
	cov := make([]f32, n, context.temp_allocator)

	top_layer :: proc(groups: []Group) -> [][4]f32 {
		#reverse for g in groups {if g.layer != nil {return g.layer}}
		return nil
	}

	for op in d.ops {
		g := groups[len(groups) - 1]
		switch o in op {
		case Draw_Fill:
			polys := o.polys
			x0, y0, x1, y1 := raster_coverage(&polys, o.even_odd, 1, offset, cov, w, h)
			layer := top_layer(groups[:])
			src := [4]f32{o.color.r / 255, o.color.g / 255, o.color.b / 255, 1}
			alpha := o.color.a / 255
			for y in y0 ..< y1 {
				for x in x0 ..< x1 {
					i := y * w + x
					a := min(cov[i], 1) * alpha
					cov[i] = 0
					if g.mask != nil {a *= g.mask[i]}
					if a > 0 {layer[i] = src * a + layer[i] * (1 - a)}
				}
			}
		case Draw_Image:
			draw_image_pixels(top_layer(groups[:]), g.mask, w, h, o, offset)
		case Draw_Clip:
			polys := o.polys
			mask := make([]f32, n, context.temp_allocator)
			x0, y0, x1, y1 := raster_coverage(&polys, o.even_odd, 1, offset, cov, w, h)
			for y in y0 ..< y1 {
				for x in x0 ..< x1 {
					i := y * w + x
					mask[i] = min(cov[i], 1) * (g.mask != nil ? g.mask[i] : 1)
					cov[i] = 0
				}
			}
			append(&groups, Group{mask = mask})
		case Draw_Group:
			append(&groups, Group{layer = make([][4]f32, n, context.temp_allocator), mask = g.mask, opacity = o.opacity})
		case Draw_End:
			if len(groups) > 1 {draw_group_end(&groups)}
		}
	}
	for len(groups) > 1 {draw_group_end(&groups)}

	out := make([]Pixel, n, allocator)
	for p, i in groups[0].layer {
		if p.a <= 0 {continue}
		out[i] = {
			u8(clamp(p.r / p.a * 255 + 0.5, 0, 255)),
			u8(clamp(p.g / p.a * 255 + 0.5, 0, 255)),
			u8(clamp(p.b / p.a * 255 + 0.5, 0, 255)),
			u8(clamp(p.a * 255 + 0.5, 0, 255)),
		}
	}
	return out
}

// Closes the innermost clip or group; a group is blended into the layer below.
@(private = "file")
draw_group_end :: proc(groups: ^[dynamic]$G) {
	g := pop(groups)
	if g.layer == nil {return}
	below: [][4]f32
	#reverse for b in groups {
		if b.layer != nil {
			below = b.layer
			break
		}
	}
	for p, i in g.layer {
		if p.a <= 0 {continue}
		q := p * g.opacity
		below[i] = q + below[i] * (1 - q.a)
	}
}

// Samples an image (bilinear, edges not smoothed) into the pixels it covers.
@(private = "file")
draw_image_pixels :: proc(layer: [][4]f32, mask: []f32, w, h: int, o: Draw_Image, offset: [2]f32) {
	iw, ih, pixels := backend_image_pixels(o.handle)
	if len(pixels) == 0 {return}
	m := mat_mul({1, 0, 0, 1, offset.x, offset.y}, o.m)
	inv := mat_invert(m)
	lo, hi := [2]f32{max(f32), max(f32)}, [2]f32{min(f32), min(f32)}
	for c in ([4][2]f32{{0, 0}, {f32(o.size.x), 0}, {0, f32(o.size.y)}, {f32(o.size.x), f32(o.size.y)}}) {
		p := mat_apply(m, c)
		lo, hi = {min(lo.x, p.x), min(lo.y, p.y)}, {max(hi.x, p.x), max(hi.y, p.y)}
	}
	x0, y0 := max(0, int(math.floor(lo.x))), max(0, int(math.floor(lo.y)))
	x1, y1 := min(w, int(math.ceil(hi.x))), min(h, int(math.ceil(hi.y)))
	// Image pixels per pixel of the drawing, to map the drawing's pixels onto the image's.
	sx, sy := f32(iw) / f32(o.size.x), f32(ih) / f32(o.size.y)
	tint := o.tint / 255
	fetch :: proc(pixels: []Pixel, iw, ih, x, y: int) -> [4]f32 {
		p := pixels[clamp(y, 0, ih - 1) * iw + clamp(x, 0, iw - 1)]
		a := f32(p.a) / 255
		return {f32(p.r) / 255 * a, f32(p.g) / 255 * a, f32(p.b) / 255 * a, a} // premultiplied
	}
	for y in y0 ..< y1 {
		for x in x0 ..< x1 {
			uv := mat_apply(inv, {f32(x) + 0.5, f32(y) + 0.5})
			if uv.x < 0 || uv.y < 0 || uv.x >= f32(o.size.x) || uv.y >= f32(o.size.y) {continue}
			u, v := uv.x * sx - 0.5, uv.y * sy - 0.5
			fu, fv := math.floor(u), math.floor(v)
			tu, tv := u - fu, v - fv
			iu, iv := int(fu), int(fv)
			c := (fetch(pixels, iw, ih, iu, iv) * (1 - tu) + fetch(pixels, iw, ih, iu + 1, iv) * tu) * (1 - tv)
			c += (fetch(pixels, iw, ih, iu, iv + 1) * (1 - tu) + fetch(pixels, iw, ih, iu + 1, iv + 1) * tu) * tv
			c = {c.r * tint.r * tint.a, c.g * tint.g * tint.a, c.b * tint.b * tint.a, c.a * tint.a}
			if mask != nil {c *= mask[y * w + x]}
			if c.a <= 0 {continue}
			i := y * w + x
			layer[i] = c + layer[i] * (1 - c.a)
		}
	}
}
