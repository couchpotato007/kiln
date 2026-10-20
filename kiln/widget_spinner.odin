package kiln

// Animated loading indicator: a row of dots that pulse in sequence.
// Purely visual, no state required; the animation is driven by the frame time.

import "core:math"
import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

@(private = "file")
SPINNER_DOTS :: 3

// Declares a spinner: primary-colored dots that scale up and fade in one after another
// (dot size `sizes[.SM]`, gap `spacing[.XS]`, speed `spinner_speed` of the theme).
// Use it on its own or next to a label like "Lädt ...":
//
//   if kiln.hstack(.SM) {
//       kiln.spinner()
//       kiln.label("Lädt ...", .Body, kiln.current_theme.text_muted)
//   }
spinner :: proc(id := clay.ElementId{}) {
	c := current_theme
	eid := resolve_id(id, "spinner")

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingFit(), clay.SizingFit()},
			childGap = sp(.XS),
			childAlignment = {y = .Center},
		},
	},
	) {
		t := rl.GetTime() * f64(current_theme.spinner_speed)
		for i in 0 ..< SPINNER_DOTS {
			// Phase-shifted sine gives each dot its own pulse.
			phase := t - f64(i) * 0.2
			pulse := f32(0.5 + 0.5 * math.sin(phase * 2 * math.PI))
			scale := 0.6 + 0.4 * pulse
			d := size_px(.SM) * scale

			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
				backgroundColor = color_alpha(c.primary, 0.35 + 0.65 * pulse),
				cornerRadius = clay.CornerRadiusAll(d / 2),
			},
			) {}
		}
	}
}
