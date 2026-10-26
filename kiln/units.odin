package kiln

// Units, scaling and screen classes.
//
// Every dimension in the theme and in the API is given in units. The effective scale
// (`zoom * dpi * fit`) turns units into pixels; it is recomputed once per frame.

import "core:math"
import clay "clay-odin"

// How the UI scales with the window.
Scale :: struct {
	zoom:       f32, // manual zoom factor (0 = 1), also changed with Ctrl +/-/0
	fit_height: f32, // if > 0, scale with the window height relative to this many units
	ignore_dpi: bool, // do not multiply by the monitor's DPI scale
}

// Window size classes, see `Metrics.breakpoints`.
Screen :: enum {
	Compact, // phones, very narrow windows
	Medium, // tablets, half-screen windows
	Expanded, // desktop windows
}

@(private)
g_scale: Scale = {
	zoom = 1,
}
@(private)
g_scale_factor: f32 = 1

@(private)
ZOOM_MIN :: 0.5
@(private)
ZOOM_MAX :: 3

set_zoom :: proc(zoom: f32) {
	g_scale.zoom = clamp(zoom, ZOOM_MIN, ZOOM_MAX)
}

zoom :: proc() -> f32 {
	return g_scale.zoom
}

// Pixels per unit in the current frame.
scale_factor :: proc() -> f32 {
	return g_scale_factor
}

@(private)
set_scale :: proc(s: Scale) {
	g_scale = s
	g_scale.zoom = clamp(s.zoom == 0 ? 1 : s.zoom, ZOOM_MIN, ZOOM_MAX)
}

@(private)
update_scale :: proc() {
	s := g_scale.zoom
	if !g_scale.ignore_dpi {s *= max(g_in.dpi, 0.1)}
	if g_scale.fit_height > 0 {
		// Rounded steps avoid reloading the fonts on every pixel of a resize.
		fit := math.round(g_in.window.y / g_scale.fit_height * 8) / 8
		s *= clamp(fit, 0.75, 2.5)
	}
	g_scale_factor = s
}

// Window size in units.
window_size :: proc() -> [2]f32 {
	return g_in.window / g_scale_factor
}

// The size class of the window.
screen :: proc() -> Screen {
	w := window_size().x
	if w >= g_theme.breakpoints[.Expanded] {return .Expanded}
	if w >= g_theme.breakpoints[.Medium] {return .Medium}
	return .Compact
}

// Picks the value for the current screen class:
//
//   columns := kiln.by_screen(1, 2, 4)
by_screen :: proc(compact, medium, expanded: $T) -> T {
	switch screen() {
	case .Compact:
		return compact
	case .Medium:
		return medium
	case .Expanded:
		return expanded
	}
	return expanded
}

// ---------------------------------------------------------------------------
// Theme values as pixels, for custom widgets built on Clay
// ---------------------------------------------------------------------------

// Units to pixels (rounded).
px :: proc(units: f32) -> f32 {
	return math.round(units * g_scale_factor)
}

// A spacing step in pixels, as Clay expects it for gaps.
space :: proc(s: Space) -> u16 {
	return u16(max(0, px(g_theme.spacing[s])))
}

// Padding from spacing steps: `inset(.MD)` on all sides, `inset(.LG, .SM)` horizontal / vertical.
inset :: proc {
	inset_all,
	inset_xy,
}

inset_all :: proc(s: Space) -> clay.Padding {
	v := space(s)
	return {v, v, v, v}
}

inset_xy :: proc(x, y: Space) -> clay.Padding {
	h, v := space(x), space(y)
	return {left = h, right = h, top = v, bottom = v}
}

// A corner radius in pixels. `.Full` is not scaled.
radius :: proc(r: Radius) -> f32 {
	v := g_theme.radii[r]
	return r == .Full ? v : px(v)
}

corners :: proc(r: Radius) -> clay.CornerRadius {
	return clay.CornerRadiusAll(radius(r))
}

// An element size in pixels.
size :: proc(s: Size) -> f32 {
	return px(g_theme.sizes[s])
}

// The theme's border width in pixels (at least 1 if the theme has borders).
line_width :: proc() -> f32 {
	w := g_theme.border_width
	if w <= 0 {return 0}
	return max(1, px(w))
}

// A border of the theme's width around an element.
outline :: proc(color: Color) -> clay.BorderElementConfig {
	return {color = color, width = clay.BorderOutside(u16(line_width()))}
}

// Font size of a text style in pixels: `font_base * font_ratio^(style - Body)`.
font_size :: proc(style: TextStyle) -> u16 {
	exp := f32(int(style) - int(TextStyle.Body))
	t := &g_theme
	return u16(max(1, math.round(t.font_base * math.pow(t.font_ratio, exp) * g_scale_factor)))
}

// Clay text config for a style and color.
font :: proc(style: TextStyle, color: Color) -> clay.TextElementConfig {
	return {fontId = u16(style), fontSize = font_size(style), textColor = color}
}

// Width of `text` in pixels when set in `style`.
measure :: proc(text: string, style: TextStyle) -> f32 {
	if len(text) == 0 {return 0}
	return backend_measure(text, style, font_size(style)).x
}
