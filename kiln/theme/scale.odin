package theme

import "core:math"

// UI scaling. The effective scale is `zoom * dpi_scale * fit_scale`, recomputed once per
// frame by the app loop (`update_scale`). All `px*` helpers apply it.
Scale :: struct {
	zoom:       f32, // manual zoom factor (0 = 1), see `set_zoom`
	fit_height: f32, // if > 0, scale with the window height relative to this value
	ignore_dpi: bool, // do not multiply by the window DPI scale
}

@(private)
FIT_MIN :: 0.75
@(private)
FIT_MAX :: 2.5
@(private)
FIT_STEP :: 0.125 // rounding avoids constant font reloads while resizing

@(private)
g_scale: Scale
@(private)
g_effective: f32 = 1

set_scale :: proc(s: Scale) {
	g_scale = s
	g_scale.zoom = clamp(s.zoom == 0 ? 1 : s.zoom, 0.5, 4)
}

// Sets the manual zoom factor (clamped to 0.5..4), e.g. for Ctrl +/- shortcuts.
set_zoom :: proc(zoom: f32) {
	g_scale.zoom = clamp(zoom, 0.5, 4)
}

zoom :: proc() -> f32 {
	return g_scale.zoom == 0 ? 1 : g_scale.zoom
}

// The effective scale of the current frame.
scale_factor :: proc() -> f32 {
	return g_effective
}

// Recomputes the effective scale. Called once per frame before the layout is built.
update_scale :: proc(dpi_scale, window_height: f32) {
	s := zoom()
	if !g_scale.ignore_dpi {
		s *= max(dpi_scale, 0.1)
	}
	if g_scale.fit_height > 0 {
		fit := math.round(window_height / g_scale.fit_height / FIT_STEP) * FIT_STEP
		s *= clamp(fit, FIT_MIN, FIT_MAX)
	}
	g_effective = s
}
