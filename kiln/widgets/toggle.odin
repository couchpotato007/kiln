package widgets

// Checkbox and radio share their config and drawing code.

import "base:intrinsics"
import clay "lib:clay-odin"
import "lib:theme"

ToggleConfig :: struct {
	id:            clay.ElementId,
	label:         string,
	size:          f32, // edge length / diameter in UI units (scaled)
	round:         bool, // true for radio
	disabled:      bool,
	box:           clay.ElementDeclaration, // row (mark + label)
	mark:          clay.ElementDeclaration, // box / circle in the unchecked state
	text:          clay.TextElementConfig,
	checked_bg:    clay.Color,
	check_color:   clay.Color, // inner square / dot
	hover_border:  clay.Color,
	disabled_text: clay.Color,
}

style_checkbox :: proc(id: clay.ElementId, label: string, disabled := false) -> ToggleConfig {
	return style_toggle(id, label, false, disabled)
}

style_radio :: proc(id: clay.ElementId, label: string, disabled := false) -> ToggleConfig {
	return style_toggle(id, label, true, disabled)
}

// Toggles `checked` when clicked. Returns true if `checked` changed.
checkbox :: proc(checked: ^bool, cfg: ToggleConfig) -> bool {
	s := interact(cfg.id, cfg.disabled)
	changed := false
	if s.clicked {
		checked^ = !checked^
		changed = true
	}
	toggle_draw(cfg, checked^, s)
	return changed
}

// Sets `selected` to `value` when clicked. Works with enums and integers:
//
//   widgets.radio(&size, Size.Large, widgets.style_radio(clay.ID_LOCAL("large"), "Large"))
//
// Returns true if `selected` changed.
radio :: proc(
	selected: ^$T,
	value: T,
	cfg: ToggleConfig,
) -> bool where intrinsics.type_is_enum(T) ||
	intrinsics.type_is_integer(T) {
	s := interact(cfg.id, cfg.disabled)
	changed := false
	if s.clicked && selected^ != value {
		selected^ = value
		changed = true
	}
	toggle_draw(cfg, selected^ == value, s)
	return changed
}


@(private = "file")
style_toggle :: proc(
	id: clay.ElementId,
	label: string,
	round: bool,
	disabled: bool,
) -> ToggleConfig {
	c := theme.current
	size: f32 = 18
	return {
		id = id,
		label = label,
		size = size,
		round = round,
		disabled = disabled,
		box = {layout = {childGap = theme.sp(.SM), childAlignment = {y = .Center}}},
		mark = {
			backgroundColor = c.bg_sunken,
			cornerRadius = round ? clay.CornerRadiusAll(theme.px(size) / 2) : theme.radius(.SM),
			border = theme.border_box(c.border_strong),
		},
		text = theme.text_style(.Body, c.text),
		checked_bg = c.primary,
		check_color = c.on_primary,
		hover_border = c.primary,
		disabled_text = c.text_disabled,
	}
}

@(private = "file")
toggle_draw :: proc(cfg: ToggleConfig, checked: bool, s: Interaction) {
	t := anim(cfg.id, 0, checked ? 1 : 0)
	h := anim(cfg.id, 1, s.hovered ? 1 : 0)
	size := theme.px(cfg.size)

	mark := cfg.mark
	mark.layout.sizing = {clay.SizingFixed(size), clay.SizingFixed(size)}
	mark.layout.childAlignment = {.Center, .Center}
	mark.backgroundColor = color_lerp(cfg.mark.backgroundColor, cfg.checked_bg, t)
	mark.border.color = color_lerp(cfg.mark.border.color, cfg.hover_border, max(t, h))

	text := cfg.text
	if cfg.disabled {text.textColor = cfg.disabled_text}

	if clay.UI(cfg.id)(cfg.box) {
		if clay.UI_AutoId()(mark) {
			inner := size * (cfg.round ? 0.4 : 0.5) * t
			corner := cfg.round ? inner / 2 : min(theme.px(theme.RADIUS[.SM]), inner / 2)
			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingFixed(inner), clay.SizingFixed(inner)}},
				backgroundColor = cfg.check_color,
				cornerRadius = clay.CornerRadiusAll(corner),
			},
			) {}
		}
		if len(cfg.label) > 0 {
			clay.Text(cfg.label, text)
		}
	}
}
