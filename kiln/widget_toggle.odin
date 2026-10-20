package kiln

// Checkbox and radio share their drawing code. Colors and sizes come from the global theme.

import "base:intrinsics"
import clay "lib:kiln/clay-odin"

// Toggles `checked` when clicked. Returns true if `checked` changed.
//
//   kiln.checkbox(&notify, "Benachrichtigungen")
//   kiln.checkbox(&done, item.text, id = kiln.id_local("done", u32(i)))   // in loops
checkbox :: proc(checked: ^bool, label := "", disabled := false, id := clay.ElementId{}) -> bool {
	eid := resolve_id(id, len(label) > 0 ? label : "checkbox")
	s := interact(eid, disabled)
	changed := false
	if s.clicked {
		checked^ = !checked^
		changed = true
	}
	toggle_draw(eid, label, false, disabled, checked^, s)
	return changed
}

// Sets `selected` to `value` when clicked. Works with enums and integers:
//
//   kiln.radio(&size, Size.Large, "Large", id = kiln.id_local("large"))
//
// Returns true if `selected` changed.
radio :: proc(
	selected: ^$T,
	value: T,
	label := "",
	disabled := false,
	id := clay.ElementId{},
) -> bool where intrinsics.type_is_enum(T) ||
	intrinsics.type_is_integer(T) {
	eid := resolve_id(id, len(label) > 0 ? label : "radio")
	s := interact(eid, disabled)
	changed := false
	if s.clicked && selected^ != value {
		selected^ = value
		changed = true
	}
	toggle_draw(eid, label, true, disabled, selected^ == value, s)
	return changed
}

@(private = "file")
toggle_draw :: proc(
	eid: clay.ElementId,
	label: string,
	round, disabled, checked: bool,
	s: Interaction,
) {
	c := current_theme
	t := anim(eid, 0, checked ? 1 : 0)
	h := anim(eid, 1, s.hovered ? 1 : 0)
	size := size_px(.MD)

	mark := clay.ElementDeclaration {
		layout = {
			sizing = {clay.SizingFixed(size), clay.SizingFixed(size)},
			childAlignment = {.Center, .Center},
		},
		backgroundColor = color_lerp(c.bg_sunken, c.primary, t),
		cornerRadius = round ? clay.CornerRadiusAll(size / 2) : radius(.SM),
		border = border_box(color_lerp(c.border_strong, c.primary, max(t, h))),
	}

	if clay.UI(eid)({layout = {childGap = sp(.SM), childAlignment = {y = .Center}}}) {
		if clay.UI_AutoId()(mark) {
			inner := size * (round ? 0.4 : 0.5) * t
			corner := round ? inner / 2 : min(radius_px(.SM), inner / 2)
			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingFixed(inner), clay.SizingFixed(inner)}},
				backgroundColor = c.on_primary,
				cornerRadius = clay.CornerRadiusAll(corner),
			},
			) {}
		}
		if len(label) > 0 {
			clay.Text(label, text_style(.Body, disabled ? c.text_disabled : c.text))
		}
	}
}
