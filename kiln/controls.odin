package kiln

// Basic controls: button, checkbox, toggle, radio, slider.
// Value controls take the current value and return `(new_value, changed)`.

import "base:intrinsics"
import "core:math"
import "core:unicode/utf8"
import clay "clay-odin"

ButtonVariant :: enum {
	Primary, // filled with the primary color
	Secondary, // raised surface with a border
	Ghost, // transparent until hovered
	Danger, // filled with the danger color
}

// A button; returns true in the frame it was clicked. A single-character label (an icon like
// "✕" or "☰") gives a square button. `fill` makes it as wide as its container; inside
// `actions` on compact screens buttons fill automatically. `tone` colors the label of ghost and
// secondary buttons, e.g. a red ghost "Entfernen".
button :: proc(
	label: string,
	variant := ButtonVariant.Primary,
	disabled := false,
	fill := false,
	tone := Tone.Default,
) -> bool {
	c := &g_theme
	eid := id(label)
	s := interact(eid, disabled)

	bg, hover, active, fg: Color
	switch variant {
	case .Primary:
		bg, fg = c.primary, c.on_primary
		hover, active = mix(bg, c.text, 0.12), mix(bg, c.window, 0.2)
	case .Danger:
		bg, fg = c.danger, c.on_primary
		hover, active = mix(bg, c.text, 0.12), mix(bg, c.window, 0.2)
	case .Secondary:
		bg, hover, active, fg = c.surface, c.surface_hover, c.surface_active, c.text
	case .Ghost:
		// A transparent version of the hover color, so the fade does not pass through black.
		bg, hover, active, fg = fade(c.surface, 0), c.surface, c.surface_hover, c.text
	}
	if tone != .Default && (variant == .Ghost || variant == .Secondary) {fg = tone_color(tone)}
	if disabled {
		bg = variant == .Ghost ? fade(c.surface, 0) : c.surface
		fg = c.text_faint
	} else {
		bg = mix(bg, hover, anim(eid, 0, s.hovered ? 1 : 0))
		if s.pressed {bg = active}
	}

	p := parent_box()
	grow := fill || (p != nil && p.kind == .Actions && p.stacked)
	square := !grow && utf8.rune_count_in_string(label) == 1

	width := clay.SizingFit()
	padding := inset(.LG, .None)
	if grow {width = clay.SizingGrow()}
	if square {
		width = clay.SizingFixed(size(.Control))
		padding = {}
	}

	style := font(.Body, fg)
	style.wrapMode = .None
	decl := clay.ElementDeclaration {
		layout = {
			sizing = {width, clay.SizingFixed(size(.Control))},
			padding = padding,
			childAlignment = {.Center, .Center},
		},
		backgroundColor = bg,
		cornerRadius = corners(.MD),
	}
	if variant == .Secondary {decl.border = outline(c.border)}

	flow_item(eid)
	if clay.UI(eid)(decl) {
		clay.TextDynamic(label, style)
	}
	set_last(eid, s)
	return s.clicked
}

// A checkbox with an optional label:
//
//   if v, ok := kiln.checkbox(m.notify, "Benachrichtigungen"); ok {append(out, Set_Notify{v})}
checkbox :: proc(checked: bool, label := "", disabled := false) -> (value: bool, changed: bool) {
	eid := id(len(label) > 0 ? label : "checkbox")
	s := interact(eid, disabled)
	value = checked
	if s.clicked {
		value = !checked
		changed = true
	}
	mark(eid, label, .Box, value, s)
	return
}

// An on/off switch with an optional label. Same as `checkbox`, for settings that apply at once.
toggle :: proc(on: bool, label := "", disabled := false) -> (value: bool, changed: bool) {
	eid := id(len(label) > 0 ? label : "toggle")
	s := interact(eid, disabled)
	value = on
	if s.clicked {
		value = !on
		changed = true
	}
	mark(eid, label, .Switch, value, s)
	return
}

// One option of a radio group: selects `value` when clicked. Works with enums and integers:
//
//   for s in Size {
//       if v, ok := kiln.radio(m.size, s, SIZE_NAMES[s]); ok {append(out, Set_Size{v})}
//   }
radio :: proc(
	selected: $T,
	value: T,
	label := "",
	disabled := false,
) -> (
	new_value: T,
	changed: bool,
) where intrinsics.type_is_enum(T) ||
	intrinsics.type_is_integer(T) {
	eid := id(len(label) > 0 ? label : "radio")
	s := interact(eid, disabled)
	new_value = selected
	if s.clicked && selected != value {
		new_value = value
		changed = true
	}
	mark(eid, label, .Round, new_value == value, s)
	return
}

@(private)
MarkShape :: enum {
	Box,
	Round,
	Switch,
}

// Draws checkbox / radio / switch with its label.
@(private)
mark :: proc(eid: Id, label: string, shape: MarkShape, on: bool, s: Interaction) {
	c := &g_theme
	t := anim(eid, 0, on ? 1 : 0)
	h := anim(eid, 1, s.hovered ? 1 : 0)
	m := size(.Mark)
	accent := s.disabled ? c.text_faint : c.primary

	flow_item(eid)
	if clay.UI(eid)({layout = {childGap = space(.SM), childAlignment = {y = .Center}}}) {
		switch shape {
		case .Box, .Round:
			if clay.UI()(
			{
				layout = {
					sizing = {clay.SizingFixed(m), clay.SizingFixed(m)},
					childAlignment = {.Center, .Center},
				},
				backgroundColor = mix(c.sunken, accent, t),
				cornerRadius = shape == .Round ? clay.CornerRadiusAll(m / 2) : corners(.SM),
				border = outline(mix(c.border_strong, accent, max(t, h))),
			},
			) {
				inner := m * (shape == .Round ? 0.4 : 0.5) * t
				corner := shape == .Round ? inner / 2 : min(radius(.SM), inner / 2)
				if clay.UI()(
				{
					layout = {sizing = {clay.SizingFixed(inner), clay.SizingFixed(inner)}},
					backgroundColor = c.on_primary,
					cornerRadius = clay.CornerRadiusAll(corner),
				},
				) {}
			}
		case .Switch:
			tw, th := math.round(m * 1.9), math.round(m * 1.1)
			knob := th - px(6)
			if clay.UI()(
			{
				layout = {
					sizing = {clay.SizingFixed(tw), clay.SizingFixed(th)},
					padding = {left = u16(px(3) + t * (tw - th))},
					childAlignment = {y = .Center},
				},
				backgroundColor = mix(c.surface_hover, accent, t),
				cornerRadius = clay.CornerRadiusAll(th / 2),
			},
			) {
				if clay.UI()(
				{
					layout = {sizing = {clay.SizingFixed(knob), clay.SizingFixed(knob)}},
					backgroundColor = mix(mix(c.text_muted, c.text, h), c.on_primary, t),
					cornerRadius = clay.CornerRadiusAll(knob / 2),
				},
				) {}
			}
		}
		if len(label) > 0 {
			clay.TextDynamic(label, font(.Body, s.disabled ? c.text_faint : c.text))
		}
	}
	set_last(eid, s)
}

// A horizontal slider for integers and floats in [lo, hi]:
//
//   if v, ok := kiln.slider(m.volume, 0, 100); ok {append(out, Set_Volume{v})}
slider :: proc(
	value: $T,
	lo, hi: T,
	disabled := false,
	key := "",
) -> (
	new_value: T,
	changed: bool,
) where intrinsics.type_is_integer(T) ||
	intrinsics.type_is_float(T) {
	c := &g_theme
	eid := id(len(key) > 0 ? key : "slider")
	s := interact(eid, disabled)
	data := clay.GetElementData(eid)
	knob := size(.Mark)
	flo, fhi := f32(lo), f32(hi)

	new_value = value
	if s.held && data.found {
		w := max(data.boundingBox.width - knob, 1)
		t := clamp((g_in.mouse.x - data.boundingBox.x - knob / 2) / w, 0, 1)
		raw := flo + t * (fhi - flo)
		when intrinsics.type_is_integer(T) {raw = math.round(raw)}
		if T(raw) != value {
			new_value = T(raw)
			changed = true
		}
	}

	frac: f32 = fhi > flo ? clamp((f32(new_value) - flo) / (fhi - flo), 0, 1) : 0
	h := anim(eid, 0, (s.hovered || s.held) ? 1 : 0)
	width := data.found ? data.boundingBox.width : 0
	track := size(.Track)
	r := clay.CornerRadiusAll(track / 2)
	accent := disabled ? c.text_faint : c.primary

	// Filled track, knob, rest of the track: plain layout, no floating elements.
	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFixed(size(.Control))},
			childAlignment = {y = .Center},
		},
	},
	) {
		if clay.UI()(
		{
			layout = {sizing = {clay.SizingFixed(frac * max(width - knob, 0)), clay.SizingFixed(track)}},
			backgroundColor = accent,
			cornerRadius = r,
		},
		) {}
		if clay.UI()(
		{
			layout = {sizing = {clay.SizingFixed(knob), clay.SizingFixed(knob)}},
			backgroundColor = disabled ? c.text_faint : mix(c.primary, c.text, 0.2 * h),
			cornerRadius = clay.CornerRadiusAll(knob / 2),
		},
		) {}
		if clay.UI()(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(track)}},
			backgroundColor = c.surface_hover,
			cornerRadius = r,
		},
		) {}
	}
	set_last(eid, s)
	return
}
