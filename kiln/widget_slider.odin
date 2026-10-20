package kiln

import "base:intrinsics"
import "core:math"

import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Changes `value` within [lo, hi]. Works with integers and floats:
//
//   kiln.slider(&volume, 0, 100)
//
// Returns true if the value changed. Without `id` the ID is "slider" scoped to the parent,
// so several sliders in the same parent need an explicit `id`.
slider :: proc(
	value: ^$T,
	lo, hi: T,
	disabled := false,
	id := clay.ElementId{},
) -> bool where intrinsics.type_is_integer(T) ||
	intrinsics.type_is_float(T) {
	c := current_theme
	eid := resolve_id(id, "slider")
	s := interact(eid, disabled)
	data := clay.GetElementData(eid)
	knob := size_px(.MD)
	changed := false

	flo, fhi := f32(lo), f32(hi)

	if s.held && data.found {
		w := max(data.boundingBox.width - knob, 1)
		t := clamp((rl.GetMousePosition().x - data.boundingBox.x - knob * 0.5) / w, 0, 1)
		raw := flo + t * (fhi - flo)
		when intrinsics.type_is_integer(T) {
			raw = math.round(raw)
		}
		nv := T(raw)
		if nv != value^ {
			value^ = nv
			changed = true
		}
	}

	frac: f32 = fhi > flo ? clamp((f32(value^) - flo) / (fhi - flo), 0, 1) : 0
	hv := anim(eid, 0, (s.hovered || s.held) ? 1 : 0)
	width := data.found ? data.boundingBox.width : 0
	track_r := clay.CornerRadiusAll(size_px(.XS) / 2)

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), size_control_height()},
			childAlignment = {y = .Center},
		},
	},
	) {
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(size_px(.XS))}},
			backgroundColor = c.surface_1,
			cornerRadius = track_r,
		},
		) {
			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingPercent(frac), clay.SizingGrow()}},
				backgroundColor = disabled ? c.surface_1 : c.primary,
				cornerRadius = track_r,
			},
			) {}
		}
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingFixed(knob), clay.SizingFixed(knob)}},
			backgroundColor = color_lerp(c.primary, c.primary_hover, hv),
			cornerRadius = clay.CornerRadiusAll(knob / 2),
			floating = {
				attachTo = .Parent,
				attachment = {element = .LeftCenter, parent = .LeftCenter},
				pointerCaptureMode = .Passthrough,
				offset = {frac * max(width - knob, 0), 0},
			},
		},
		) {}
	}
	return changed
}
