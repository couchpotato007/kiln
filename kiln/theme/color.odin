package theme

import clay "lib:kiln/clay-odin"

// Interpolates all channels (including alpha) from `a` to `b` by `t` (0..1).
color_mix :: proc(a, b: clay.Color, t: f32) -> clay.Color {
	return a + (b - a) * t
}

// Returns `col` with its alpha replaced by `alpha` (0..1).
color_alpha :: proc(col: clay.Color, alpha: f32) -> clay.Color {
	r := col
	r[3] = clamp(alpha, 0, 1) * 255
	return r
}

// Background slots of the theme. Resolved every frame, so theme changes apply instantly.
Surface :: enum {
	None, // transparent
	Window,
	Sunken, // inputs, inset areas
	Surface_0, // raised, subtle
	Surface_1,
	Surface_2, // raised, strong
	Primary,
}

surface_color :: proc(s: Surface) -> clay.Color {
	c := g_theme
	switch s {
	case .None:
		return {}
	case .Window:
		return c.bg
	case .Sunken:
		return c.bg_sunken
	case .Surface_0:
		return c.surface_0
	case .Surface_1:
		return c.surface_1
	case .Surface_2:
		return c.surface_2
	case .Primary:
		return c.primary
	}
	return {}
}
