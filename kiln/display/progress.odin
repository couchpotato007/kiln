package display

// Progress bar and spinner: purely visual, no state owned by the caller.

import "core:math"
import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"
import rl "vendor:raylib"

// Progress bar, `value` in [0, 1]. The shown value follows smoothly.
//
//   kiln.progress(0.4)
progress :: proc(value: f32, id := clay.ElementId{}) {
	c := th.current()
	eid := fd.resolve_id(id, "progress")
	v := fd.anim(eid, 0, clamp(value, 0, 1))
	h := th.size_px(.Bar)
	r := clay.CornerRadiusAll(h / 2)
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(h)}},
		backgroundColor = c.surface_1,
		cornerRadius = r,
	},
	) {
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingPercent(v), clay.SizingGrow()}},
			backgroundColor = c.primary,
			cornerRadius = r,
		},
		) {}
	}
}

@(private)
SPINNER_DOTS :: 3

// Loading indicator: primary-colored dots that scale up and fade in one after another
// (dot size `sizes[.Dot]`, gap `spacing[.XS]`, speed `spinner_speed`). Use it on its own or
// next to a label:
//
//   if kiln.hstack(.SM) {
//       kiln.spinner()
//       kiln.label("Lädt ...", .Body, kiln.theme().text_muted)
//   }
spinner :: proc(id := clay.ElementId{}) {
	c := th.current()
	eid := fd.resolve_id(id, "spinner")

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingFit(), clay.SizingFit()},
			childGap = th.sp(.XS),
			childAlignment = {y = .Center},
		},
	},
	) {
		t := rl.GetTime() * f64(c.spinner_speed)
		for i in 0 ..< SPINNER_DOTS {
			// A phase-shifted sine gives each dot its own pulse.
			pulse := f32(0.5 + 0.5 * math.sin((t - f64(i) * 0.2) * 2 * math.PI))
			d := th.size_px(.Dot) * (0.6 + 0.4 * pulse)
			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
				backgroundColor = th.color_alpha(c.primary, 0.35 + 0.65 * pulse),
				cornerRadius = clay.CornerRadiusAll(d / 2),
			},
			) {}
		}
	}
}
