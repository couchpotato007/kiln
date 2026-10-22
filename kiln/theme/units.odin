package theme

// Theme metrics -> scaled pixels. Widgets only use these, never raw numbers.

import "core:math"
import clay "lib:kiln/clay-odin"

// Converts unscaled units to scaled pixels (rounded).
px :: proc(units: f32) -> f32 {
	return math.round(units * g_effective)
}

// Like `px`, but returns the u16 that Clay expects for padding, gaps and border widths.
px16 :: proc(units: f32) -> u16 {
	return u16(max(0, px(units)))
}

// Scaled spacing value for use as `childGap`.
sp :: proc(s: Space) -> u16 {
	return px16(g_theme.spacing[s])
}

// Scaled spacing value as float, for offsets.
space_px :: proc(s: Space) -> f32 {
	return px(g_theme.spacing[s])
}

// Equal padding on all sides.
pad_all :: proc(s: Space) -> clay.Padding {
	return clay.PaddingAll(sp(s))
}

// Padding with separate horizontal and vertical steps.
pad_xy :: proc(horizontal, vertical: Space) -> clay.Padding {
	return {
		left = sp(horizontal),
		right = sp(horizontal),
		top = sp(vertical),
		bottom = sp(vertical),
	}
}

// Scaled corner radius in pixels. `.Full` is not scaled (pill shape).
radius_px :: proc(r: Radius) -> f32 {
	v := g_theme.radii[r]
	return r == .Full ? v : px(v)
}

// Scaled corner radius for all four corners.
radius :: proc(r: Radius) -> clay.CornerRadius {
	return clay.CornerRadiusAll(radius_px(r))
}

// Scaled element size in pixels.
size_px :: proc(s: Size) -> f32 {
	return px(g_theme.sizes[s])
}

// Fixed sizing with the standard control height (buttons, inputs, ...).
control_height :: proc() -> clay.SizingAxis {
	return clay.SizingFixed(size_px(.Control))
}

// Scaled border width in pixels (at least 1 if the theme has a border).
border_px :: proc() -> f32 {
	w := g_theme.border_width
	if w <= 0 {return 0}
	return max(1, px(w))
}

// Outer border of the theme's border width in the given color.
border_box :: proc(color: clay.Color) -> clay.BorderElementConfig {
	return {color = color, width = clay.BorderOutside(u16(border_px()))}
}

// Scaled font size in pixels for a role: `font_base * font_ratio^(role - Body) * scale`.
font_size :: proc(role: FontRole) -> u16 {
	exp := f32(int(role) - int(FontRole.Body))
	t := g_theme
	return u16(max(1, math.round(t.font_base * math.pow(t.font_ratio, exp) * g_effective)))
}

// Text config (font slot, size, color) for a typographic role.
text_style :: proc(role: FontRole, color: clay.Color) -> clay.TextElementConfig {
	return {fontId = u16(role), fontSize = font_size(role), textColor = color}
}
