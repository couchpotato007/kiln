package controls

// Checkbox and radio share their drawing code. Colors and sizes come from the theme.

import "base:intrinsics"
import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"

// Toggles `checked` when clicked. Returns true if `checked` changed.
//
//   kiln.checkbox(&notify, "Benachrichtigungen")
//   kiln.checkbox(&done, item.text, id = kiln.id_local("done", u32(i)))   // in loops
checkbox :: proc(checked: ^bool, label := "", disabled := false, id := clay.ElementId{}) -> bool {
	eid := fd.resolve_id(id, len(label) > 0 ? label : "checkbox")
	s := fd.interact(eid, disabled)
	changed := false
	if s.clicked {
		checked^ = !checked^
		changed = true
	}
	draw_toggle(eid, label, false, checked^, s)
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
	eid := fd.resolve_id(id, len(label) > 0 ? label : "radio")
	s := fd.interact(eid, disabled)
	changed := false
	if s.clicked && selected^ != value {
		selected^ = value
		changed = true
	}
	draw_toggle(eid, label, true, selected^ == value, s)
	return changed
}

@(private)
draw_toggle :: proc(
	eid: clay.ElementId,
	label: string,
	round, checked: bool,
	s: fd.Interaction,
) {
	c := th.current()
	t := fd.anim(eid, 0, checked ? 1 : 0)
	h := fd.anim(eid, 1, s.hovered ? 1 : 0)
	size := th.size_px(.Mark)

	mark := clay.ElementDeclaration {
		layout = {
			sizing = {clay.SizingFixed(size), clay.SizingFixed(size)},
			childAlignment = {.Center, .Center},
		},
		backgroundColor = th.color_mix(c.bg_sunken, c.primary, t),
		cornerRadius = round ? clay.CornerRadiusAll(size / 2) : th.radius(.SM),
		border = th.border_box(th.color_mix(c.border_strong, c.primary, max(t, h))),
	}

	if clay.UI(eid)({layout = {childGap = th.sp(.SM), childAlignment = {y = .Center}}}) {
		if clay.UI_AutoId()(mark) {
			inner := size * (round ? 0.4 : 0.5) * t
			corner := round ? inner / 2 : min(th.radius_px(.SM), inner / 2)
			if clay.UI_AutoId()(
			{
				layout = {sizing = {clay.SizingFixed(inner), clay.SizingFixed(inner)}},
				backgroundColor = c.on_primary,
				cornerRadius = clay.CornerRadiusAll(corner),
			},
			) {}
		}
		if len(label) > 0 {
			clay.Text(label, th.text_style(.Body, s.disabled ? c.text_disabled : c.text))
		}
	}
}
