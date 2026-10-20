package kiln

// Animated loading indicator: a row of dots that pulse in sequence.
// Purely visual, no state required; the animation is driven by the frame time.

import "core:math"
import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Appearance of a spinner. Create it with `style_spinner`.
SpinnerConfig :: struct {
	id:     clay.ElementId,
	box:    clay.ElementDeclaration, // row container
	dot:    clay.ElementDeclaration, // one dot in its resting state
	size:   f32, // unscaled diameter of a dot
	gap:    f32, // unscaled distance between dots
	count:  int, // number of dots
	speed:  f32, // pulses per second
	color:  clay.Color,
}

// Spinner look from the current theme: primary-colored dots on the current background.
style_spinner :: proc(id: clay.ElementId) -> SpinnerConfig {
	c := current_theme
	size: f32 = 8
	gap: f32 = 4
	cfg := SpinnerConfig {
		id = id,
		box = {
			layout = {
				sizing = {clay.SizingFit(), clay.SizingFit()},
				childGap = px16(gap),
				childAlignment = {y = .Center},
			},
		},
		dot = {
			layout = {sizing = {clay.SizingFixed(px(size)), clay.SizingFixed(px(size))}},
			backgroundColor = c.primary,
			cornerRadius = clay.CornerRadiusAll(px(size) / 2),
		},
		size = size,
		gap = gap,
		count = 3,
		speed = 1.5,
		color = c.primary,
	}
	return cfg
}

// Declares a spinner. Each dot scales up and fades in one after another.
// Use it on its own or next to a label like "Lädt ...":
//
//   if kiln.hstack(.SM) {
//       kiln.spinner(kiln.style_spinner(kiln.id_local("load")))
//       kiln.label("Lädt ...", .Body, kiln.current_theme.text_muted)
//   }
spinner :: proc(cfg: SpinnerConfig) {
	if clay.UI(cfg.id)(cfg.box) {
		t := rl.GetTime() * f64(cfg.speed)
		for i in 0 ..< cfg.count {
			// Phase-shifted sine gives each dot its own pulse.
			phase := t - f64(i) * 0.2
			pulse := f32(0.5 + 0.5 * math.sin(phase * 2 * math.PI))
			scale := 0.6 + 0.4 * pulse

			dot := cfg.dot
			s := px(cfg.size) * scale
			dot.layout.sizing = {clay.SizingFixed(s), clay.SizingFixed(s)}
			dot.backgroundColor = color_alpha(cfg.color, 0.35 + 0.65 * pulse)
			dot.cornerRadius = clay.CornerRadiusAll(s / 2)
			if clay.UI_AutoId()(dot) {}
		}
	}
}
