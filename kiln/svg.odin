package kiln

// A small SVG renderer for icons. It understands what icon sets (Lucide, Tabler, Material,
// Heroicons, Feather, ...) use: <path>, <rect>, <circle>, <ellipse>, <line>, <polyline> and
// <polygon> inside <svg> and <g>, with fill, stroke (width, caps, joins), fill-rule, opacity,
// currentColor and transforms. Gradients, <use>, masks, clip paths, text and CSS classes are
// not supported (gradients draw in the text color).
//
// Parsing turns every shape into polygons in viewBox units (strokes included), so drawing at
// any size is only scan conversion: icons stay sharp at every zoom level.

import "core:math"
import "core:slice"
import "core:strings"

@(private)
Svg :: struct {
	view:   [4]f32, // viewBox: min x, min y, width, height
	shapes: [dynamic]SvgShape,
	mono:   bool, // only one color (or currentColor): drawn white and tinted like text
}

// Polygons filled with one color. `ends` holds the end index (into `points`) of each polygon.
@(private)
SvgShape :: struct {
	points:   [dynamic][2]f32,
	ends:     [dynamic]int,
	even_odd: bool,
	color:    Color, // alpha includes the opacity
	current:  bool, // currentColor: the color comes from the tint
}

@(private)
svg_destroy :: proc(svg: ^Svg) {
	for &s in svg.shapes {
		delete(s.points)
		delete(s.ends)
	}
	delete(svg.shapes)
	svg^ = {}
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

@(private = "file")
Paint :: struct {
	kind:  enum {
		None,
		Current,
		Color,
	},
	color: Color,
}

@(private = "file")
Cap :: enum {
	Butt,
	Round,
	Square,
}

@(private = "file")
Join :: enum {
	Miter,
	Round,
	Bevel,
}

// a, b, c, d, e, f: x' = a*x + c*y + e, y' = b*x + d*y + f
@(private = "file")
Mat :: [6]f32

@(private = "file")
IDENTITY :: Mat{1, 0, 0, 1, 0, 0}

// The inherited presentation attributes of an element.
@(private = "file")
Style :: struct {
	fill, stroke:                          Paint,
	stroke_width, miter_limit:             f32,
	opacity, fill_opacity, stroke_opacity: f32,
	cap:                                   Cap,
	join:                                  Join,
	even_odd:                              bool,
	m:                                     Mat,
	hidden:                                bool,
}

// Elements whose content is never drawn directly.
@(private = "file")
SKIPPED := [?]string {
	"defs",
	"clipPath",
	"mask",
	"symbol",
	"pattern",
	"linearGradient",
	"radialGradient",
	"title",
	"desc",
	"metadata",
	"style",
	"script",
	"text",
	"filter",
	"marker",
	"foreignObject",
}

// Parses an SVG document. Fails only if there is no <svg> element.
@(private)
svg_parse :: proc(src: string) -> (svg: Svg, ok: bool) {
	root := Style {
		fill           = {kind = .Color, color = {0, 0, 0, 255}},
		stroke_width   = 1,
		miter_limit    = 4,
		opacity        = 1,
		fill_opacity   = 1,
		stroke_opacity = 1,
		m              = IDENTITY,
	}
	stack := make([dynamic]Style, context.temp_allocator)
	append(&stack, root)
	svg.view = {0, 0, 24, 24}
	tol: f32 = 0.024 // flattening tolerance in viewBox units, set from the viewBox

	i := 0
	for i < len(src) {
		lt := strings.index_byte(src[i:], '<')
		if lt < 0 {break}
		i += lt
		rest := src[i:]
		skip_to :: proc(s, end: string) -> int {
			e := strings.index(s, end)
			return e < 0 ? len(s) : e + len(end)
		}
		switch {
		case strings.has_prefix(rest, "<!--"):
			i += skip_to(rest, "-->")
			continue
		case strings.has_prefix(rest, "<![CDATA["):
			i += skip_to(rest, "]]>")
			continue
		case strings.has_prefix(rest, "<?"), strings.has_prefix(rest, "<!"):
			i += skip_to(rest, ">")
			continue
		case strings.has_prefix(rest, "</"):
			i += skip_to(rest, ">")
			if len(stack) > 1 {pop(&stack)}
			continue
		}

		// An opening tag: name, attributes, then ">" or "/>".
		j := 1
		for j < len(rest) && !is_space(rest[j]) && rest[j] != '/' && rest[j] != '>' {j += 1}
		name := rest[1:j]
		if k := strings.index_byte(name, ':'); k >= 0 {name = name[k + 1:]} // svg:path
		attrs := make(map[string]string, 8, context.temp_allocator)
		closed := false
		for j < len(rest) {
			for j < len(rest) && is_space(rest[j]) {j += 1}
			if j >= len(rest) {break}
			if rest[j] == '>' {
				j += 1
				break
			}
			if rest[j] == '/' {
				closed = true
				j += 1
				continue
			}
			k := j
			for j < len(rest) && rest[j] != '=' && rest[j] != '>' && rest[j] != '/' && !is_space(rest[j]) {j += 1}
			key := rest[k:j]
			for j < len(rest) && is_space(rest[j]) {j += 1}
			if j >= len(rest) || rest[j] != '=' {continue}
			j += 1
			for j < len(rest) && is_space(rest[j]) {j += 1}
			if j >= len(rest) {break}
			q := rest[j]
			if q == '"' || q == '\'' {
				e := strings.index_byte(rest[j + 1:], q)
				if e < 0 {e = len(rest) - j - 1}
				attrs[key] = rest[j + 1:j + 1 + e]
				j += e + 2
			} else {
				k = j
				for j < len(rest) && !is_space(rest[j]) && rest[j] != '>' {j += 1}
				attrs[key] = rest[k:j]
			}
		}
		i += min(j, len(rest))

		// `style="fill:none;stroke-width:2"` wins over the attributes.
		if css, has := attrs["style"]; has {
			for decl in strings.split(css, ";", context.temp_allocator) {
				k, _, v := strings.partition(decl, ":")
				k, v = strings.trim_space(k), strings.trim_space(v)
				if len(k) > 0 && len(v) > 0 {attrs[k] = v}
			}
		}

		st := apply_style(stack[len(stack) - 1], attrs)
		switch name {
		case "svg":
			if !ok {
				ok = true
				svg.view = view_box(attrs)
				tol = max(svg.view[2], svg.view[3]) / 1000
			}
		case "path", "rect", "circle", "ellipse", "line", "polyline", "polygon":
			if ok && !st.hidden {add_element(&svg, name, attrs, st, tol)}
		case:
			for s in SKIPPED {
				if s == name {st.hidden = true}
			}
		}
		if !closed {append(&stack, st)}
	}

	// Monochrome if all shapes share one color.
	svg.mono = true
	first: Maybe(SvgShape)
	for s in svg.shapes {
		f, has := first.?
		if !has {
			first = s
		} else if s.current != f.current || (!s.current && s.color.rgb != f.color.rgb) {
			svg.mono = false
		}
	}
	return
}

@(private = "file")
is_space :: proc(c: u8) -> bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

@(private = "file")
view_box :: proc(attrs: map[string]string) -> [4]f32 {
	if vb, has := attrs["viewBox"]; has {
		l := Lexer{s = vb}
		v: [4]f32
		all := true
		for &x in v {x, all = number(&l); if !all {break}}
		if all && v[2] > 0 && v[3] > 0 {return v}
	}
	w, h := number_attr(attrs, "width", 24), number_attr(attrs, "height", 24)
	return {0, 0, w > 0 ? w : 24, h > 0 ? h : 24}
}

@(private = "file")
apply_style :: proc(parent: Style, attrs: map[string]string) -> Style {
	st := parent
	// Group opacity is approximated by multiplying it into the children.
	st.opacity *= clamp(number_attr(attrs, "opacity", 1), 0, 1)
	if v, has := attrs["fill"]; has {st.fill = parse_paint(v, parent.fill)}
	if v, has := attrs["stroke"]; has {st.stroke = parse_paint(v, parent.stroke)}
	if _, has := attrs["stroke-width"]; has {st.stroke_width = max(0, number_attr(attrs, "stroke-width", 1))}
	if _, has := attrs["stroke-miterlimit"]; has {st.miter_limit = number_attr(attrs, "stroke-miterlimit", 4)}
	if _, has := attrs["fill-opacity"]; has {st.fill_opacity = clamp(number_attr(attrs, "fill-opacity", 1), 0, 1)}
	if _, has := attrs["stroke-opacity"]; has {st.stroke_opacity = clamp(number_attr(attrs, "stroke-opacity", 1), 0, 1)}
	if v, has := attrs["fill-rule"]; has {st.even_odd = v == "evenodd"}
	switch attrs["stroke-linecap"] {
	case "butt":
		st.cap = .Butt
	case "round":
		st.cap = .Round
	case "square":
		st.cap = .Square
	}
	switch attrs["stroke-linejoin"] {
	case "miter", "miter-clip", "arcs":
		st.join = .Miter
	case "round":
		st.join = .Round
	case "bevel":
		st.join = .Bevel
	}
	if attrs["display"] == "none" || attrs["visibility"] == "hidden" {st.hidden = true}
	if t, has := attrs["transform"]; has {st.m = mat_mul(parent.m, parse_transform(t))}
	return st
}

@(private = "file")
parse_paint :: proc(s: string, parent: Paint) -> Paint {
	v := strings.trim_space(s)
	switch v {
	case "none", "transparent":
		return {}
	case "currentColor", "currentcolor":
		return {kind = .Current}
	case "inherit", "":
		return parent
	}
	if strings.has_prefix(v, "url(") {return {kind = .Current}} // gradients and patterns
	if c, ok := parse_color(v); ok {return {kind = .Color, color = c}}
	return parent
}

@(private = "file")
NAMED_COLORS := [?]struct {
	name:  string,
	color: Color,
} {
	{"black", {0, 0, 0, 255}},
	{"white", {255, 255, 255, 255}},
	{"red", {255, 0, 0, 255}},
	{"green", {0, 128, 0, 255}},
	{"blue", {0, 0, 255, 255}},
	{"yellow", {255, 255, 0, 255}},
	{"orange", {255, 165, 0, 255}},
	{"purple", {128, 0, 128, 255}},
	{"gray", {128, 128, 128, 255}},
	{"grey", {128, 128, 128, 255}},
	{"silver", {192, 192, 192, 255}},
	{"lime", {0, 255, 0, 255}},
	{"navy", {0, 0, 128, 255}},
	{"teal", {0, 128, 128, 255}},
	{"maroon", {128, 0, 0, 255}},
	{"fuchsia", {255, 0, 255, 255}},
	{"magenta", {255, 0, 255, 255}},
	{"aqua", {0, 255, 255, 255}},
	{"cyan", {0, 255, 255, 255}},
}

@(private = "file")
parse_color :: proc(s: string) -> (Color, bool) {
	hex :: proc(c: u8) -> f32 {
		switch c {
		case '0' ..= '9':
			return f32(c - '0')
		case 'a' ..= 'f':
			return f32(c - 'a' + 10)
		case 'A' ..= 'F':
			return f32(c - 'A' + 10)
		}
		return 0
	}
	if strings.has_prefix(s, "#") {
		h := s[1:]
		switch len(h) {
		case 3, 4:
			c := Color{hex(h[0]) * 17, hex(h[1]) * 17, hex(h[2]) * 17, 255}
			if len(h) == 4 {c.a = hex(h[3]) * 17}
			return c, true
		case 6, 8:
			c := Color{hex(h[0]) * 16 + hex(h[1]), hex(h[2]) * 16 + hex(h[3]), hex(h[4]) * 16 + hex(h[5]), 255}
			if len(h) == 8 {c.a = hex(h[6]) * 16 + hex(h[7])}
			return c, true
		}
		return {}, false
	}
	if strings.has_prefix(s, "rgb") {
		open := strings.index_byte(s, '(')
		if open < 0 {return {}, false}
		l := Lexer{s = s[open + 1:]}
		c := Color{0, 0, 0, 255}
		for k in 0 ..< 4 {
			v, ok := number(&l)
			if !ok {return c, k >= 3}
			pct := l.i < len(l.s) && l.s[l.i] == '%'
			if pct {l.i += 1}
			if k < 3 {
				c[k] = clamp(pct ? v * 2.55 : v, 0, 255)
			} else {
				c.a = clamp(pct ? v * 2.55 : v * 255, 0, 255)
			}
		}
		return c, true
	}
	for n in NAMED_COLORS {
		if strings.equal_fold(n.name, s) {return n.color, true}
	}
	return {}, false
}

@(private = "file")
parse_transform :: proc(s: string) -> Mat {
	m := IDENTITY
	rest := s
	for {
		open := strings.index_byte(rest, '(')
		close := strings.index_byte(rest, ')')
		if open < 0 || close < open {break}
		name := strings.trim(rest[:open], " \t\n\r,")
		l := Lexer{s = rest[open + 1:close]}
		a: [6]f32
		n := 0
		for n < 6 {
			v, ok := number(&l)
			if !ok {break}
			a[n] = v
			n += 1
		}
		t := IDENTITY
		switch name {
		case "matrix":
			if n == 6 {t = a}
		case "translate":
			t = {1, 0, 0, 1, a[0], n > 1 ? a[1] : 0}
		case "scale":
			t = {a[0], 0, 0, n > 1 ? a[1] : a[0], 0, 0}
		case "rotate":
			r := a[0] * math.RAD_PER_DEG
			cs, sn := math.cos(r), math.sin(r)
			t = {cs, sn, -sn, cs, 0, 0}
			if n == 3 { // around (cx, cy)
				t = mat_mul(mat_mul({1, 0, 0, 1, a[1], a[2]}, t), {1, 0, 0, 1, -a[1], -a[2]})
			}
		case "skewX":
			t = {1, 0, math.tan(a[0] * math.RAD_PER_DEG), 1, 0, 0}
		case "skewY":
			t = {1, math.tan(a[0] * math.RAD_PER_DEG), 0, 1, 0, 0}
		}
		m = mat_mul(m, t)
		rest = rest[close + 1:]
	}
	return m
}

// `m` after `n`: applies `n` first.
@(private = "file")
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

@(private = "file")
apply :: proc(m: Mat, p: [2]f32) -> [2]f32 {
	return {m[0] * p.x + m[2] * p.y + m[4], m[1] * p.x + m[3] * p.y + m[5]}
}

// How much the transform scales lengths (on average).
@(private = "file")
mat_scale :: proc(m: Mat) -> f32 {
	return math.sqrt(abs(m[0] * m[3] - m[1] * m[2]))
}

// ---------------------------------------------------------------------------
// Numbers
// ---------------------------------------------------------------------------

@(private = "file")
Lexer :: struct {
	s: string,
	i: int,
}

@(private = "file")
skip_separators :: proc(l: ^Lexer) {
	for l.i < len(l.s) && (is_space(l.s[l.i]) || l.s[l.i] == ',') {l.i += 1}
}

// Reads a number like "-1.5e3"; also splits "1.5.5" and "1-2" the way SVG does.
@(private = "file")
number :: proc(l: ^Lexer) -> (f32, bool) {
	skip_separators(l)
	s, start := l.s, l.i
	i := l.i
	if i < len(s) && (s[i] == '+' || s[i] == '-') {i += 1}
	digits := 0
	for i < len(s) && s[i] >= '0' && s[i] <= '9' {i, digits = i + 1, digits + 1}
	if i < len(s) && s[i] == '.' {
		i += 1
		for i < len(s) && s[i] >= '0' && s[i] <= '9' {i, digits = i + 1, digits + 1}
	}
	if digits == 0 {return 0, false}
	mantissa_end := i
	exp := 0
	if i < len(s) && (s[i] == 'e' || s[i] == 'E') {
		k := i + 1
		neg := false
		if k < len(s) && (s[k] == '+' || s[k] == '-') {
			neg = s[k] == '-'
			k += 1
		}
		if k < len(s) && s[k] >= '0' && s[k] <= '9' {
			for k < len(s) && s[k] >= '0' && s[k] <= '9' {
				exp = exp * 10 + int(s[k] - '0')
				k += 1
			}
			if neg {exp = -exp}
			i = k
		}
	}

	v: f64 = 0
	frac: f64 = 0
	scale: f64 = 1
	for c in transmute([]u8)s[start:mantissa_end] {
		switch c {
		case '0' ..= '9':
			if frac > 0 {
				scale /= 10
				v += f64(c - '0') * scale
			} else {
				v = v * 10 + f64(c - '0')
			}
		case '.':
			frac = 1
		}
	}
	if s[start] == '-' {v = -v}
	if exp != 0 {v *= math.pow(10, f64(exp))}
	l.i = i
	return f32(v), true
}

// An arc flag: a single "0" or "1", which may be written without separators ("a1 1 0 01.5 2").
@(private = "file")
flag :: proc(l: ^Lexer) -> (bool, bool) {
	skip_separators(l)
	if l.i >= len(l.s) || (l.s[l.i] != '0' && l.s[l.i] != '1') {return false, false}
	l.i += 1
	return l.s[l.i - 1] == '1', true
}

@(private = "file")
number_attr :: proc(attrs: map[string]string, key: string, default: f32) -> f32 {
	s, has := attrs[key]
	if !has {return default}
	l := Lexer{s = s}
	v, ok := number(&l)
	return ok ? v : default
}

// ---------------------------------------------------------------------------
// Geometry: elements become polylines, then filled and stroked polygons
// ---------------------------------------------------------------------------

// Polylines in viewBox units, built from user-space commands.
@(private = "file")
Builder :: struct {
	m:      Mat,
	tol:    f32, // in viewBox units
	points: [dynamic][2]f32,
	ends:   [dynamic]int, // end of each subpath in `points`
	closed: [dynamic]bool,
}

@(private = "file")
move_to :: proc(b: ^Builder, p: [2]f32) {
	end_subpath(b, false)
	append(&b.points, apply(b.m, p))
}

@(private = "file")
line_to :: proc(b: ^Builder, p: [2]f32) {
	append(&b.points, apply(b.m, p))
}

@(private = "file")
end_subpath :: proc(b: ^Builder, closed: bool) {
	start := len(b.ends) > 0 ? b.ends[len(b.ends) - 1] : 0
	if len(b.points) == start {return}
	append(&b.ends, len(b.points))
	append(&b.closed, closed)
}

// Number of line segments for a curve whose second differences are at most `dd` (Wang's formula).
@(private = "file")
curve_steps :: proc(dd, factor, tol: f32) -> int {
	return clamp(int(math.ceil(math.sqrt(factor * dd / tol))), 1, 128)
}

@(private = "file")
cubic_to :: proc(b: ^Builder, p0, p1, p2, p3: [2]f32) {
	a, c1, c2, d := apply(b.m, p0), apply(b.m, p1), apply(b.m, p2), apply(b.m, p3)
	dd := max(linalg_len(a - 2 * c1 + c2), linalg_len(c1 - 2 * c2 + d))
	n := curve_steps(dd, 0.75, b.tol)
	for k in 1 ..= n {
		t := f32(k) / f32(n)
		u := 1 - t
		append(&b.points, u * u * u * a + 3 * u * u * t * c1 + 3 * u * t * t * c2 + t * t * t * d)
	}
}

@(private = "file")
quad_to :: proc(b: ^Builder, p0, p1, p2: [2]f32) {
	a, c, d := apply(b.m, p0), apply(b.m, p1), apply(b.m, p2)
	n := curve_steps(linalg_len(a - 2 * c + d), 0.25, b.tol)
	for k in 1 ..= n {
		t := f32(k) / f32(n)
		u := 1 - t
		append(&b.points, u * u * a + 2 * u * t * c + t * t * d)
	}
}

@(private = "file")
linalg_len :: proc(v: [2]f32) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

// Segments for an arc of `angle` radians and radius `r` (viewBox units).
@(private = "file")
arc_steps :: proc(r, angle, tol: f32) -> int {
	if r <= tol {return clamp(int(math.ceil(abs(angle) / (math.PI / 4))), 1, 8)}
	step := 2 * math.acos(clamp(1 - tol / r, -1, 1))
	return clamp(int(math.ceil(abs(angle) / max(step, 0.01))), 1, 256)
}

// An elliptical arc as in SVG's "A" command (endpoint parameterization, SVG spec F.6.5).
@(private = "file")
arc_to :: proc(b: ^Builder, p0: [2]f32, radii: [2]f32, rotation: f32, large, sweep: bool, p1: [2]f32) {
	if p0 == p1 {return}
	rx, ry := abs(radii.x), abs(radii.y)
	if rx == 0 || ry == 0 {
		line_to(b, p1)
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
			line_to(b, p1)
		} else {
			line_to(b, {cx + cs * rx * math.cos(t) - sn * ry * math.sin(t), cy + sn * rx * math.cos(t) + cs * ry * math.sin(t)})
		}
	}
}

@(private = "file")
ellipse :: proc(b: ^Builder, c, r: [2]f32) {
	if r.x <= 0 || r.y <= 0 {return}
	move_to(b, {c.x + r.x, c.y})
	arc_to(b, {c.x + r.x, c.y}, r, 0, false, true, {c.x - r.x, c.y})
	arc_to(b, {c.x - r.x, c.y}, r, 0, false, true, {c.x + r.x, c.y})
	end_subpath(b, true)
}

@(private = "file")
add_element :: proc(svg: ^Svg, name: string, attrs: map[string]string, st: Style, tol: f32) {
	b := Builder {
		m      = st.m,
		tol    = tol,
		points = make([dynamic][2]f32, context.temp_allocator),
		ends   = make([dynamic]int, context.temp_allocator),
		closed = make([dynamic]bool, context.temp_allocator),
	}
	num :: proc(attrs: map[string]string, key: string) -> f32 {return number_attr(attrs, key, 0)}

	switch name {
	case "path":
		path_data(&b, attrs["d"])
	case "rect":
		x, y, w, h := num(attrs, "x"), num(attrs, "y"), num(attrs, "width"), num(attrs, "height")
		if w <= 0 || h <= 0 {return}
		_, has_rx := attrs["rx"]
		_, has_ry := attrs["ry"]
		rx, ry := num(attrs, "rx"), num(attrs, "ry")
		if !has_rx {rx = ry}
		if !has_ry {ry = rx}
		rx, ry = clamp(rx, 0, w / 2), clamp(ry, 0, h / 2)
		if rx == 0 || ry == 0 {
			move_to(&b, {x, y})
			line_to(&b, {x + w, y})
			line_to(&b, {x + w, y + h})
			line_to(&b, {x, y + h})
		} else {
			r := [2]f32{rx, ry}
			move_to(&b, {x + rx, y})
			line_to(&b, {x + w - rx, y})
			arc_to(&b, {x + w - rx, y}, r, 0, false, true, {x + w, y + ry})
			line_to(&b, {x + w, y + h - ry})
			arc_to(&b, {x + w, y + h - ry}, r, 0, false, true, {x + w - rx, y + h})
			line_to(&b, {x + rx, y + h})
			arc_to(&b, {x + rx, y + h}, r, 0, false, true, {x, y + h - ry})
			line_to(&b, {x, y + ry})
			arc_to(&b, {x, y + ry}, r, 0, false, true, {x + rx, y})
		}
		end_subpath(&b, true)
	case "circle":
		r := num(attrs, "r")
		ellipse(&b, {num(attrs, "cx"), num(attrs, "cy")}, {r, r})
	case "ellipse":
		ellipse(&b, {num(attrs, "cx"), num(attrs, "cy")}, {num(attrs, "rx"), num(attrs, "ry")})
	case "line":
		move_to(&b, {num(attrs, "x1"), num(attrs, "y1")})
		line_to(&b, {num(attrs, "x2"), num(attrs, "y2")})
		end_subpath(&b, false)
	case "polyline", "polygon":
		l := Lexer{s = attrs["points"]}
		first := true
		for {
			x, okx := number(&l)
			y, oky := number(&l)
			if !okx || !oky {break}
			if first {move_to(&b, {x, y})} else {line_to(&b, {x, y})}
			first = false
		}
		end_subpath(&b, name == "polygon")
	}
	end_subpath(&b, false)
	if len(b.ends) == 0 {return}

	if st.fill.kind != .None {
		shape := SvgShape {
			even_odd = st.even_odd,
			color    = paint_color(st.fill, st.opacity * st.fill_opacity),
			current  = st.fill.kind == .Current,
		}
		start := 0
		for end in b.ends {
			if end - start >= 3 {
				append(&shape.points, ..b.points[start:end])
				append(&shape.ends, len(shape.points))
			}
			start = end
		}
		if len(shape.ends) > 0 {append(&svg.shapes, shape)} else {delete(shape.points)}
	}

	if st.stroke.kind != .None && st.stroke_width > 0 {
		shape := SvgShape {
			color   = paint_color(st.stroke, st.opacity * st.stroke_opacity),
			current = st.stroke.kind == .Current,
		}
		hw := st.stroke_width / 2 * mat_scale(st.m)
		start := 0
		for end, k in b.ends {
			stroke(&shape, b.points[start:end], b.closed[k], hw, st, tol)
			start = end
		}
		if len(shape.ends) > 0 {
			append(&svg.shapes, shape)
		} else {
			delete(shape.points)
			delete(shape.ends)
		}
	}
}

@(private = "file")
paint_color :: proc(p: Paint, opacity: f32) -> Color {
	c := p.kind == .Color ? p.color : Color{255, 255, 255, 255}
	c.a *= opacity
	return c
}

// Path data ("M4 6h16 a2 2 0 0 1 2 2z ..."). Stops at the first error and keeps what came before,
// as browsers do.
@(private = "file")
path_data :: proc(b: ^Builder, d: string) {
	l := Lexer{s = d}
	cmd: u8 = 0
	prev: u8 = 0 // previous command, for the reflected control points of S and T
	cur, start, ctrl: [2]f32

	for {
		skip_separators(&l)
		if l.i >= len(l.s) {break}
		c := l.s[l.i]
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
			cmd = c
			l.i += 1
			if cmd == 'z' || cmd == 'Z' {
				end_subpath(b, true)
				cur, prev = start, cmd
				continue
			}
		} else if cmd == 0 || cmd == 'z' || cmd == 'Z' {
			break
		}

		rel := cmd >= 'a'
		base := rel ? cur : [2]f32{}
		pt :: proc(l: ^Lexer, base: [2]f32) -> ([2]f32, bool) {
			x, okx := number(l)
			y, oky := number(l)
			return base + {x, y}, okx && oky
		}
		ok := true
		switch cmd | 0x20 { 	// lower case
		case 'm':
			p: [2]f32
			if p, ok = pt(&l, base); !ok {break}
			move_to(b, p)
			cur, start = p, p
			cmd = rel ? 'l' : 'L' // further pairs are line-tos
		case 'l':
			p: [2]f32
			if p, ok = pt(&l, base); !ok {break}
			line_to_start(b, cur)
			line_to(b, p)
			cur = p
		case 'h':
			x: f32
			if x, ok = number(&l); !ok {break}
			line_to_start(b, cur)
			cur.x = rel ? cur.x + x : x
			line_to(b, cur)
		case 'v':
			y: f32
			if y, ok = number(&l); !ok {break}
			line_to_start(b, cur)
			cur.y = rel ? cur.y + y : y
			line_to(b, cur)
		case 'c', 's':
			p1, p2, p: [2]f32
			if cmd | 0x20 == 'c' {
				if p1, ok = pt(&l, base); !ok {break}
			} else {
				p1 = (prev | 0x20 == 'c' || prev | 0x20 == 's') ? 2 * cur - ctrl : cur
			}
			if p2, ok = pt(&l, base); !ok {break}
			if p, ok = pt(&l, base); !ok {break}
			line_to_start(b, cur)
			cubic_to(b, cur, p1, p2, p)
			cur, ctrl = p, p2
		case 'q', 't':
			p1, p: [2]f32
			if cmd | 0x20 == 'q' {
				if p1, ok = pt(&l, base); !ok {break}
			} else {
				p1 = (prev | 0x20 == 'q' || prev | 0x20 == 't') ? 2 * cur - ctrl : cur
			}
			if p, ok = pt(&l, base); !ok {break}
			line_to_start(b, cur)
			quad_to(b, cur, p1, p)
			cur, ctrl = p, p1
		case 'a':
			rx, ry, rot: f32
			large, sweep, okf: bool
			if rx, ok = number(&l); !ok {break}
			if ry, ok = number(&l); !ok {break}
			if rot, ok = number(&l); !ok {break}
			if large, okf = flag(&l); !okf {ok = false;break}
			if sweep, okf = flag(&l); !okf {ok = false;break}
			p: [2]f32
			if p, ok = pt(&l, base); !ok {break}
			line_to_start(b, cur)
			arc_to(b, cur, {rx, ry}, rot, large, sweep, p)
			cur = p
		case:
			ok = false
		}
		if !ok {break}
		prev = cmd
	}
}

// Makes sure a subpath is open before a segment appends to it (a segment right after "z" starts
// a new subpath at the current point).
@(private = "file")
line_to_start :: proc(b: ^Builder, cur: [2]f32) {
	start := len(b.ends) > 0 ? b.ends[len(b.ends) - 1] : 0
	if len(b.points) == start {append(&b.points, apply(b.m, cur))}
}

// Adds a polygon with counter-clockwise winding, so overlapping stroke pieces add up under the
// nonzero rule.
@(private = "file")
add_ccw :: proc(shape: ^SvgShape, pts: ..[2]f32) {
	area: f32 = 0
	for p, i in pts {
		q := pts[(i + 1) % len(pts)]
		area += p.x * q.y - q.x * p.y
	}
	if abs(area) < 1e-9 {return}
	if area > 0 {
		append(&shape.points, ..pts)
	} else {
		#reverse for p in pts {append(&shape.points, p)}
	}
	append(&shape.ends, len(shape.points))
}

@(private = "file")
circle :: proc(shape: ^SvgShape, c: [2]f32, r, tol: f32) {
	n := max(8, arc_steps(r, 2 * math.PI, tol))
	pts := make([][2]f32, n, context.temp_allocator)
	for &p, k in pts {
		t := 2 * math.PI * f32(k) / f32(n)
		p = c + r * [2]f32{math.cos(t), math.sin(t)}
	}
	add_ccw(shape, ..pts)
}

// The outline of a stroked polyline as convex pieces: one quad per segment plus joins and caps.
// Filled together with the nonzero rule they give the union.
@(private = "file")
stroke :: proc(shape: ^SvgShape, polyline: [][2]f32, closed: bool, hw: f32, st: Style, tol: f32) {
	pts := make([dynamic][2]f32, 0, len(polyline), context.temp_allocator)
	eps := tol * 0.01
	for p in polyline {
		if len(pts) == 0 || linalg_len(p - pts[len(pts) - 1]) > eps {append(&pts, p)}
	}
	if closed && len(pts) > 1 && linalg_len(pts[0] - pts[len(pts) - 1]) <= eps {pop(&pts)}
	n := len(pts)
	if n == 0 {return}
	if n == 1 { 	// a dot ("M12 17h0")
		p := pts[0]
		switch st.cap {
		case .Round:
			circle(shape, p, hw, tol)
		case .Square:
			add_ccw(shape, p + {-hw, -hw}, p + {hw, -hw}, p + {hw, hw}, p + {-hw, hw})
		case .Butt:
		}
		return
	}
	is_closed := closed && n > 2
	perp :: proc(d: [2]f32) -> [2]f32 {return {-d.y, d.x}}
	dir :: proc(a, b: [2]f32) -> [2]f32 {return (b - a) / linalg_len(b - a)}

	segments := is_closed ? n : n - 1
	for i in 0 ..< segments {
		a, b := pts[i], pts[(i + 1) % n]
		d := dir(a, b)
		nrm := perp(d) * hw
		if !is_closed && st.cap == .Square {
			if i == 0 {a -= d * hw}
			if i == segments - 1 {b += d * hw}
		}
		add_ccw(shape, a + nrm, b + nrm, b - nrm, a - nrm)
	}

	for i in 0 ..< n {
		if !is_closed && (i == 0 || i == n - 1) {continue}
		v := pts[i]
		d1, d2 := dir(pts[(i + n - 1) % n], v), dir(v, pts[(i + 1) % n])
		cross := d1.x * d2.y - d1.y * d2.x
		dot := d1.x * d2.x + d1.y * d2.y
		if abs(cross) < 1e-6 && dot > 0 {continue} // straight on
		if st.join == .Round {
			circle(shape, v, hw, tol)
			continue
		}
		side: f32 = cross > 0 ? -1 : 1 // the outer side of the turn
		n1, n2 := perp(d1) * hw * side, perp(d2) * hw * side
		add_ccw(shape, v, v + n1, v + n2) // bevel
		if st.join == .Miter && 1 + dot > 1e-6 && math.sqrt(2 / (1 + dot)) <= st.miter_limit {
			add_ccw(shape, v, v + n1, v + (n1 + n2) / (1 + dot), v + n2)
		}
	}

	if !is_closed && st.cap == .Round {
		circle(shape, pts[0], hw, tol)
		circle(shape, pts[n - 1], hw, tol)
	}
}

// ---------------------------------------------------------------------------
// Rasterizing
// ---------------------------------------------------------------------------

// Vertical samples per pixel row; horizontal coverage is computed exactly.
@(private = "file")
SUBSAMPLES :: 8

// Draws the SVG into `width` x `height` RGBA pixels (centered, aspect kept). Monochrome SVGs come
// out white, to be tinted.
@(private)
svg_rasterize :: proc(svg: ^Svg, width, height: int, allocator := context.allocator) -> []Pixel {
	w, h := max(width, 1), max(height, 1)
	vb := svg.view
	s := min(f32(w) / vb[2], f32(h) / vb[3])
	offset := [2]f32{(f32(w) - vb[2] * s) / 2 - vb[0] * s, (f32(h) - vb[3] * s) / 2 - vb[1] * s}

	acc := make([][4]f32, w * h, context.temp_allocator) // premultiplied
	cov := make([]f32, w * h, context.temp_allocator)
	for &shape in svg.shapes {
		slice.zero(cov)
		coverage(&shape, s, offset, cov, w, h)
		c := shape.color
		if svg.mono || shape.current {c.rgb = {255, 255, 255}}
		src := [4]f32{c.r / 255, c.g / 255, c.b / 255, 1}
		alpha := c.a / 255
		for &p, i in acc {
			a := min(cov[i], 1) * alpha
			if a > 0 {p = src * a + p * (1 - a)}
		}
	}

	out := make([]Pixel, w * h, allocator)
	for p, i in acc {
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

@(private = "file")
Edge :: struct {
	x0, y0, x1, y1: f32, // y0 < y1
	dir:            int,
}

@(private = "file")
Crossing :: struct {
	x:   f32,
	dir: int,
}

// Adds the coverage (0..1 per pixel) of a shape's polygons, scaled by `s` and moved by `offset`.
@(private = "file")
coverage :: proc(shape: ^SvgShape, s: f32, offset: [2]f32, cov: []f32, w, h: int) {
	edges := make([dynamic]Edge, context.temp_allocator)
	ymin, ymax := max(f32), min(f32)
	start := 0
	for end in shape.ends {
		for k in start ..< end {
			p := shape.points[k] * s + offset
			q := shape.points[k + 1 < end ? k + 1 : start] * s + offset
			if p.y == q.y {continue}
			if p.y < q.y {
				append(&edges, Edge{p.x, p.y, q.x, q.y, 1})
			} else {
				append(&edges, Edge{q.x, q.y, p.x, p.y, -1})
			}
			ymin, ymax = min(ymin, p.y, q.y), max(ymax, p.y, q.y)
		}
		start = end
	}
	if len(edges) == 0 {return}

	xs := make([dynamic]Crossing, context.temp_allocator)
	weight := f32(1) / SUBSAMPLES
	for y in max(0, int(math.floor(ymin))) ..< min(h, int(math.ceil(ymax))) {
		row := cov[y * w:(y + 1) * w]
		for sub in 0 ..< SUBSAMPLES {
			sy := f32(y) + (f32(sub) + 0.5) / SUBSAMPLES
			clear(&xs)
			for e in edges {
				if sy >= e.y0 && sy < e.y1 {
					append(&xs, Crossing{e.x0 + (sy - e.y0) * (e.x1 - e.x0) / (e.y1 - e.y0), e.dir})
				}
			}
			slice.sort_by(xs[:], proc(a, b: Crossing) -> bool {return a.x < b.x})
			winding := 0
			for k in 0 ..< len(xs) - 1 {
				winding += xs[k].dir
				inside := shape.even_odd ? winding % 2 != 0 : winding != 0
				if inside {add_span(row, xs[k].x, xs[k + 1].x, weight)}
			}
		}
	}
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
