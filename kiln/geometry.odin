package kiln

// 2D geometry shared by the SVG renderer and drawings: affine transforms, paths flattened into
// polylines, strokes turned into polygons, and scan conversion of polygons into coverage.

import "core:math"
import "core:slice"

// a, b, c, d, e, f: x' = a*x + c*y + e, y' = b*x + d*y + f
@(private)
Mat :: [6]f32

@(private)
MAT_IDENTITY :: Mat{1, 0, 0, 1, 0, 0}

// `m` after `n`: applies `n` first.
@(private)
mat_mul :: proc(m, n: Mat) -> Mat {
	return {
		m[0] * n[0] + m[2] * n[1],
		m[1] * n[0] + m[3] * n[1],
		m[0] * n[2] + m[2] * n[3],
		m[1] * n[2] + m[3] * n[3],
		m[0] * n[4] + m[2] * n[5] + m[4],
		m[1] * n[4] + m[3] * n[5] + m[5],
	}
}

@(private)
mat_apply :: proc(m: Mat, p: [2]f32) -> [2]f32 {
	return {m[0] * p.x + m[2] * p.y + m[4], m[1] * p.x + m[3] * p.y + m[5]}
}

// How much the transform scales lengths (on average).
@(private)
mat_scale :: proc(m: Mat) -> f32 {
	return math.sqrt(abs(m[0] * m[3] - m[1] * m[2]))
}

// The inverse transform; the identity if `m` is not invertible.
@(private)
mat_invert :: proc(m: Mat) -> Mat {
	det := m[0] * m[3] - m[1] * m[2]
	if abs(det) < 1e-12 {return MAT_IDENTITY}
	a, b, c, d := m[3] / det, -m[1] / det, -m[2] / det, m[0] / det
	return {a, b, c, d, -(a * m[4] + c * m[5]), -(b * m[4] + d * m[5])}
}

@(private)
vec_len :: proc(v: [2]f32) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

// ---------------------------------------------------------------------------
// Paths: polylines in device space, built from user-space commands
// ---------------------------------------------------------------------------

@(private)
Path_Builder :: struct {
	m:      Mat,
	tol:    f32, // flattening tolerance, in device units
	points: [dynamic][2]f32,
	ends:   [dynamic]int, // end of each subpath in `points`
	closed: [dynamic]bool,
}

@(private)
path_builder :: proc(m: Mat, tol: f32, allocator := context.temp_allocator) -> Path_Builder {
	return {
		m = m,
		tol = tol,
		points = make([dynamic][2]f32, allocator),
		ends = make([dynamic]int, allocator),
		closed = make([dynamic]bool, allocator),
	}
}

@(private)
path_move :: proc(b: ^Path_Builder, p: [2]f32) {
	path_end(b, false)
	append(&b.points, mat_apply(b.m, p))
}

@(private)
path_line :: proc(b: ^Path_Builder, p: [2]f32) {
	append(&b.points, mat_apply(b.m, p))
}

// True if the current subpath has no points yet (after a move it has one).
@(private)
path_empty :: proc(b: ^Path_Builder) -> bool {
	start := len(b.ends) > 0 ? b.ends[len(b.ends) - 1] : 0
	return len(b.points) == start
}

@(private)
path_end :: proc(b: ^Path_Builder, closed: bool) {
	if path_empty(b) {return}
	append(&b.ends, len(b.points))
	append(&b.closed, closed)
}

// Number of line segments for a curve whose second differences are at most `dd` (Wang's formula).
@(private)
curve_steps :: proc(dd, factor, tol: f32) -> int {
	return clamp(int(math.ceil(math.sqrt(factor * dd / tol))), 1, 128)
}

@(private)
path_cubic :: proc(b: ^Path_Builder, p0, p1, p2, p3: [2]f32) {
	a, c1, c2, d := mat_apply(b.m, p0), mat_apply(b.m, p1), mat_apply(b.m, p2), mat_apply(b.m, p3)
	dd := max(vec_len(a - 2 * c1 + c2), vec_len(c1 - 2 * c2 + d))
	n := curve_steps(dd, 0.75, b.tol)
	for k in 1 ..= n {
		t := f32(k) / f32(n)
		u := 1 - t
		append(&b.points, u * u * u * a + 3 * u * u * t * c1 + 3 * u * t * t * c2 + t * t * t * d)
	}
}

@(private)
path_quad :: proc(b: ^Path_Builder, p0, p1, p2: [2]f32) {
	a, c, d := mat_apply(b.m, p0), mat_apply(b.m, p1), mat_apply(b.m, p2)
	n := curve_steps(vec_len(a - 2 * c + d), 0.25, b.tol)
	for k in 1 ..= n {
		t := f32(k) / f32(n)
		u := 1 - t
		append(&b.points, u * u * a + 2 * u * t * c + t * t * d)
	}
}

// Segments for an arc of `angle` radians and radius `r` (device units).
@(private)
arc_steps :: proc(r, angle, tol: f32) -> int {
	if r <= tol {return clamp(int(math.ceil(abs(angle) / (math.PI / 4))), 1, 8)}
	step := 2 * math.acos(clamp(1 - tol / r, -1, 1))
	return clamp(int(math.ceil(abs(angle) / max(step, 0.01))), 1, 256)
}

// A circular arc around `c` from angle `a0` to `a1` (radians, clockwise on screen), starting
// with a line from the current point (or a move if the subpath is empty).
@(private)
path_arc :: proc(b: ^Path_Builder, c: [2]f32, r, a0, a1: f32) {
	start := c + r * [2]f32{math.cos(a0), math.sin(a0)}
	if path_empty(b) {append(&b.points, mat_apply(b.m, start))} else {path_line(b, start)}
	n := arc_steps(r * mat_scale(b.m), a1 - a0, b.tol)
	for k in 1 ..= n {
		t := a0 + (a1 - a0) * f32(k) / f32(n)
		path_line(b, c + r * [2]f32{math.cos(t), math.sin(t)})
	}
}

// An elliptical arc as in SVG's "A" command (endpoint parameterization, SVG spec F.6.5).
@(private)
path_arc_svg :: proc(b: ^Path_Builder, p0: [2]f32, radii: [2]f32, rotation: f32, large, sweep: bool, p1: [2]f32) {
	if p0 == p1 {return}
	rx, ry := abs(radii.x), abs(radii.y)
	if rx == 0 || ry == 0 {
		path_line(b, p1)
		return
	}
	phi := rotation * math.RAD_PER_DEG
	cs, sn := math.cos(phi), math.sin(phi)
	dx, dy := (p0.x - p1.x) / 2, (p0.y - p1.y) / 2
	x1, y1 := cs * dx + sn * dy, -sn * dx + cs * dy
	lambda := x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
	if lambda > 1 {
		s := math.sqrt(lambda)
		rx, ry = rx * s, ry * s
	}
	num := rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
	den := rx * rx * y1 * y1 + ry * ry * x1 * x1
	coef := den > 0 ? math.sqrt(max(0, num / den)) : 0
	if large == sweep {coef = -coef}
	cxp, cyp := coef * rx * y1 / ry, -coef * ry * x1 / rx
	cx := cs * cxp - sn * cyp + (p0.x + p1.x) / 2
	cy := sn * cxp + cs * cyp + (p0.y + p1.y) / 2
	ux, uy := (x1 - cxp) / rx, (y1 - cyp) / ry
	vx, vy := (-x1 - cxp) / rx, (-y1 - cyp) / ry
	start := math.atan2(uy, ux)
	delta := math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
	if !sweep && delta > 0 {delta -= 2 * math.PI}
	if sweep && delta < 0 {delta += 2 * math.PI}

	n := arc_steps(max(rx, ry) * mat_scale(b.m), delta, b.tol)
	for k in 1 ..= n {
		t := start + delta * f32(k) / f32(n)
		if k == n {
			path_line(b, p1)
		} else {
			path_line(b, {cx + cs * rx * math.cos(t) - sn * ry * math.sin(t), cy + sn * rx * math.cos(t) + cs * ry * math.sin(t)})
		}
	}
}

@(private)
path_ellipse :: proc(b: ^Path_Builder, c, r: [2]f32) {
	if r.x <= 0 || r.y <= 0 {return}
	path_move(b, {c.x + r.x, c.y})
	path_arc_svg(b, {c.x + r.x, c.y}, r, 0, false, true, {c.x - r.x, c.y})
	path_arc_svg(b, {c.x - r.x, c.y}, r, 0, false, true, {c.x + r.x, c.y})
	path_end(b, true)
}

// ---------------------------------------------------------------------------
// Polygons: the outlines to fill, strokes included
// ---------------------------------------------------------------------------

// Polygons filled together. `ends` holds the end index (into `points`) of each polygon.
@(private)
Polygons :: struct {
	points: [dynamic][2]f32,
	ends:   [dynamic]int,
}

// The closed subpaths of a path as polygons (open ones are closed, as filling does).
@(private)
path_polygons :: proc(out: ^Polygons, b: ^Path_Builder) {
	start := 0
	for end in b.ends {
		if end - start >= 3 {
			append(&out.points, ..b.points[start:end])
			append(&out.ends, len(out.points))
		}
		start = end
	}
}

// Adds a polygon with counter-clockwise winding, so overlapping stroke pieces add up under the
// nonzero rule.
@(private)
poly_add_ccw :: proc(out: ^Polygons, pts: ..[2]f32) {
	area: f32 = 0
	for p, i in pts {
		q := pts[(i + 1) % len(pts)]
		area += p.x * q.y - q.x * p.y
	}
	if abs(area) < 1e-9 {return}
	if area > 0 {
		append(&out.points, ..pts)
	} else {
		#reverse for p in pts {append(&out.points, p)}
	}
	append(&out.ends, len(out.points))
}

@(private)
poly_circle :: proc(out: ^Polygons, c: [2]f32, r, tol: f32) {
	n := max(8, arc_steps(r, 2 * math.PI, tol))
	pts := make([][2]f32, n, context.temp_allocator)
	for &p, k in pts {
		t := 2 * math.PI * f32(k) / f32(n)
		p = c + r * [2]f32{math.cos(t), math.sin(t)}
	}
	poly_add_ccw(out, ..pts)
}

// The outline of a stroked polyline (half width `hw`) as convex pieces: one quad per segment
// plus joins and caps. Filled together with the nonzero rule they give the union.
@(private)
poly_stroke :: proc(out: ^Polygons, polyline: [][2]f32, closed: bool, hw: f32, cap: Line_Cap, join: Line_Join, miter_limit, tol: f32) {
	pts := make([dynamic][2]f32, 0, len(polyline), context.temp_allocator)
	eps := tol * 0.01
	for p in polyline {
		if len(pts) == 0 || vec_len(p - pts[len(pts) - 1]) > eps {append(&pts, p)}
	}
	if closed && len(pts) > 1 && vec_len(pts[0] - pts[len(pts) - 1]) <= eps {pop(&pts)}
	n := len(pts)
	if n == 0 {return}
	if n == 1 { 	// a dot
		p := pts[0]
		switch cap {
		case .Round:
			poly_circle(out, p, hw, tol)
		case .Square:
			poly_add_ccw(out, p + {-hw, -hw}, p + {hw, -hw}, p + {hw, hw}, p + {-hw, hw})
		case .Butt:
		}
		return
	}
	is_closed := closed && n > 2
	perp :: proc(d: [2]f32) -> [2]f32 {return {-d.y, d.x}}
	dir :: proc(a, b: [2]f32) -> [2]f32 {return (b - a) / vec_len(b - a)}

	segments := is_closed ? n : n - 1
	for i in 0 ..< segments {
		a, b := pts[i], pts[(i + 1) % n]
		d := dir(a, b)
		nrm := perp(d) * hw
		if !is_closed && cap == .Square {
			if i == 0 {a -= d * hw}
			if i == segments - 1 {b += d * hw}
		}
		poly_add_ccw(out, a + nrm, b + nrm, b - nrm, a - nrm)
	}

	for i in 0 ..< n {
		if !is_closed && (i == 0 || i == n - 1) {continue}
		v := pts[i]
		d1, d2 := dir(pts[(i + n - 1) % n], v), dir(v, pts[(i + 1) % n])
		cross := d1.x * d2.y - d1.y * d2.x
		dot := d1.x * d2.x + d1.y * d2.y
		if abs(cross) < 1e-6 && dot > 0 {continue} // straight on
		if join == .Round {
			poly_circle(out, v, hw, tol)
			continue
		}
		side: f32 = cross > 0 ? -1 : 1 // the outer side of the turn
		n1, n2 := perp(d1) * hw * side, perp(d2) * hw * side
		poly_add_ccw(out, v, v + n1, v + n2) // bevel
		if join == .Miter && 1 + dot > 1e-6 && math.sqrt(2 / (1 + dot)) <= miter_limit {
			poly_add_ccw(out, v, v + n1, v + (n1 + n2) / (1 + dot), v + n2)
		}
	}

	if !is_closed && cap == .Round {
		poly_circle(out, pts[0], hw, tol)
		poly_circle(out, pts[n - 1], hw, tol)
	}
}

// ---------------------------------------------------------------------------
// Scan conversion
// ---------------------------------------------------------------------------

// Vertical samples per pixel row; horizontal coverage is computed exactly.
@(private)
SUBSAMPLES :: 8

@(private = "file")
Edge :: struct {
	x0, y0, y1: f32, // y0 < y1
	dxdy:       f32,
	dir:        int,
}

@(private = "file")
Crossing :: struct {
	x:   f32,
	dir: int,
}

// Adds the coverage (0..1 per pixel, more where polygons overlap) of the polygons, scaled by `s`
// and moved by `offset`, into the `w` x `h` buffer `cov`. Returns the pixel box that was touched.
// Only the edges a scanline crosses are visited, so long paths with many short edges stay fast.
@(private)
raster_coverage :: proc(polys: ^Polygons, even_odd: bool, s: f32, offset: [2]f32, cov: []f32, w, h: int) -> (x0, y0, x1, y1: int) {
	edges := make([dynamic]Edge, 0, len(polys.points), context.temp_allocator)
	lo, hi := [2]f32{max(f32), max(f32)}, [2]f32{min(f32), min(f32)}
	start := 0
	for end in polys.ends {
		for k in start ..< end {
			p := polys.points[k] * s + offset
			q := polys.points[k + 1 < end ? k + 1 : start] * s + offset
			lo, hi = {min(lo.x, p.x), min(lo.y, p.y)}, {max(hi.x, p.x), max(hi.y, p.y)}
			if p.y == q.y {continue}
			if p.y < q.y {
				append(&edges, Edge{p.x, p.y, q.y, (q.x - p.x) / (q.y - p.y), 1})
			} else {
				append(&edges, Edge{q.x, q.y, p.y, (p.x - q.x) / (p.y - q.y), -1})
			}
		}
		start = end
	}
	x0, y0 = max(0, int(math.floor(lo.x))), max(0, int(math.floor(lo.y)))
	x1, y1 = min(w, int(math.ceil(hi.x)) + 1), min(h, int(math.ceil(hi.y)))
	if len(edges) == 0 || x1 <= x0 || y1 <= y0 {return 0, 0, 0, 0}
	slice.sort_by(edges[:], proc(a, b: Edge) -> bool {return a.y0 < b.y0})

	active := make([dynamic]int, context.temp_allocator)
	xs := make([dynamic]Crossing, context.temp_allocator)
	next := 0
	weight := f32(1) / SUBSAMPLES
	for y in y0 ..< y1 {
		row := cov[y * w:(y + 1) * w]
		for sub in 0 ..< SUBSAMPLES {
			sy := f32(y) + (f32(sub) + 0.5) / SUBSAMPLES
			for next < len(edges) && edges[next].y0 <= sy {
				append(&active, next)
				next += 1
			}
			kept := 0
			for i in active {
				if edges[i].y1 > sy {
					active[kept] = i
					kept += 1
				}
			}
			resize(&active, kept)

			clear(&xs)
			for i in active {
				e := edges[i]
				c := Crossing{e.x0 + (sy - e.y0) * e.dxdy, e.dir}
				append(&xs, c)
				for k := len(xs) - 1; k > 0 && xs[k - 1].x > c.x; k -= 1 {xs[k], xs[k - 1] = xs[k - 1], xs[k]} // insertion sort
			}
			winding := 0
			for k in 0 ..< len(xs) - 1 {
				winding += xs[k].dir
				inside := even_odd ? winding % 2 != 0 : winding != 0
				if inside {add_span(row, xs[k].x, xs[k + 1].x, weight)}
			}
		}
	}
	return
}

// Adds `weight` times the covered part of each pixel between x0 and x1.
@(private = "file")
add_span :: proc(row: []f32, x0, x1, weight: f32) {
	w := f32(len(row))
	a, b := clamp(x0, 0, w), clamp(x1, 0, w)
	if b <= a {return}
	ia, ib := int(a), int(b)
	if ia == ib {
		row[ia] += (b - a) * weight
		return
	}
	row[ia] += (f32(ia + 1) - a) * weight
	for i in ia + 1 ..< ib {row[i] += weight}
	if ib < len(row) {row[ib] += (b - f32(ib)) * weight}
}
