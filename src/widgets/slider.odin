package widgets


import clay "lib:clay-odin"
import "lib:theme"
import rl "vendor:raylib"

SliderConfig :: struct {
	id:           clay.ElementId,
	box:          clay.ElementDeclaration, // Klickfläche (volle Breite)
	track_height: f32,
	knob_size:    f32,
	track_color:  clay.Color,
	fill_color:   clay.Color,
	knob_color:   clay.Color,
	knob_hover:   clay.Color,
	disabled:     bool,
}

style_slider :: proc(id: clay.ElementId, disabled := false) -> SliderConfig {
	c := theme.current
	return {
		id = id,
		box = {
			layout = {
				sizing = {clay.SizingGrow(), theme.size_control_height()},
				childAlignment = {y = .Center},
			},
		},
		track_height = 6,
		knob_size = 16,
		track_color = c.surface_1,
		fill_color = c.primary,
		knob_color = c.primary,
		knob_hover = c.primary_hover,
		disabled = disabled,
	}
}

// Ändert `value` im Bereich [lo, hi]. Gibt true zurück, wenn sich der Wert geändert hat.
slider :: proc(value: ^f32, cfg: SliderConfig, lo := f32(0), hi := f32(1)) -> bool {
	s := interact(cfg.id, cfg.disabled)
	data := clay.GetElementData(cfg.id)
	knob := theme.px(cfg.knob_size)
	changed := false

	if s.held && data.found {
		w := max(data.boundingBox.width - knob, 1)
		t := clamp((rl.GetMousePosition().x - data.boundingBox.x - knob * 0.5) / w, 0, 1)
		nv := lo + t * (hi - lo)
		if nv != value^ {
			value^ = nv
			changed = true
		}
	}

	frac: f32 = hi > lo ? clamp((value^ - lo) / (hi - lo), 0, 1) : 0
	hv := anim(cfg.id, 0, (s.hovered || s.held) ? 1 : 0)
	width := data.found ? data.boundingBox.width : 0
	track_r := clay.CornerRadiusAll(theme.px(cfg.track_height) / 2)

	if clay.UI(cfg.id)(cfg.box) {
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(theme.px(cfg.track_height))}},
			backgroundColor = cfg.track_color,
			cornerRadius = track_r,
		},
		) {
			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingPercent(frac), clay.SizingGrow()}},
				backgroundColor = cfg.disabled ? cfg.track_color : cfg.fill_color,
				cornerRadius = track_r,
			},
			) {}
		}
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingFixed(knob), clay.SizingFixed(knob)}},
			backgroundColor = color_lerp(cfg.knob_color, cfg.knob_hover, hv),
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
