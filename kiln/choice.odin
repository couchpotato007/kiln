package kiln

// Choice widgets: segmented, tabs, nav, select.
//
// Each one takes the selected index and the labels and returns `(new_index, changed)`.
// With an enum-indexed array of labels they take and return the enum instead:
//
//   Mode :: enum {Liste, Kacheln}
//   MODE_NAMES := [Mode]string{.Liste = "Liste", .Kacheln = "Kacheln"}
//   if v, ok := kiln.segmented(m.mode, MODE_NAMES); ok {append(out, Set_Mode{v})}

import "base:intrinsics"
import clay "clay-odin"

@(private)
enum_labels :: proc(labels: ^[$E]$T) -> []T {
	return ([^]T)(labels)[:len(labels)]
}

@(private)
to_enum :: proc($E: typeid, i: int) -> E {
	return E(i + int(min(E)))
}

@(private)
from_enum :: proc(e: $E) -> int {
	return int(e) - int(min(E))
}

// ---------------------------------------------------------------------------
// Segmented
// ---------------------------------------------------------------------------

// A pill-shaped row of joined options for switching between a few modes.
// `fill` stretches it (and its segments, equally) to the width of the container.
segmented :: proc {
	segmented_index,
	segmented_enum,
}

segmented_index :: proc(selected: int, labels: []string, fill := false) -> (int, bool) {
	c := &g_theme
	eid := id("segmented")
	result, changed := selected, false

	if clay.UI(eid)(
	{
		layout = {
			sizing = {fill ? clay.SizingGrow() : clay.SizingFit(), clay.SizingFit()},
			padding = inset(.XS),
			childGap = space(.XS),
		},
		backgroundColor = c.surface,
		cornerRadius = corners(.Full),
		border = outline(c.border),
	},
	) {
		for label, i in labels {
			sid := sub_id(eid, "segment", i)
			s := interact(sid)
			if s.clicked && selected != i {
				result, changed = i, true
			}
			on := anim(sid, 0, result == i ? 1 : 0)
			h := anim(sid, 1, s.hovered ? 1 : 0)

			bg := mix(fade(c.surface_hover, 0), c.surface_hover, h)
			fg := mix(c.text_muted, c.text, h)
			bg = mix(bg, c.primary, on)
			fg = mix(fg, c.on_primary, on)
			style := font(.Body, fg)
			style.wrapMode = .None

			if clay.UI(sid)(
			{
				layout = {
					sizing = {fill ? clay.SizingGrow() : clay.SizingFit(), clay.SizingFit()},
					padding = inset(.MD, .XS),
					childAlignment = {.Center, .Center},
				},
				backgroundColor = bg,
				cornerRadius = corners(.Full),
			},
			) {
				clay.TextDynamic(label, style)
			}
		}
	}
	set_last(eid)
	return result, changed
}

segmented_enum :: proc(
	selected: $E,
	labels: [E]string,
	fill := false,
) -> (
	E,
	bool,
) where intrinsics.type_is_enum(E) {
	l := labels
	i, ok := segmented_index(from_enum(selected), enum_labels(&l), fill)
	return to_enum(E, i), ok
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

// A tab bar with an underline on the selected tab. Showing the matching content is up to the
// caller (a `switch` on the selection).
tabs :: proc {
	tabs_index,
	tabs_enum,
}

tabs_index :: proc(selected: int, labels: []string) -> (int, bool) {
	c := &g_theme
	eid := id("tabs")
	result, changed := selected, false

	if clay.UI(eid)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
		},
	},
	) {
		if clay.UI()({layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, childGap = space(.XS)}}) {
			for label, i in labels {
				tid := sub_id(eid, "tab", i)
				s := interact(tid)
				if s.clicked && selected != i {
					result, changed = i, true
				}
				on := anim(tid, 0, result == i ? 1 : 0)
				h := anim(tid, 1, s.hovered ? 1 : 0)
				color := mix(mix(c.text_muted, c.text, h), c.primary, on)

				if clay.UI(tid)({layout = {layoutDirection = .TopToBottom}}) {
					if clay.UI()({layout = {padding = inset(.LG, .SM)}}) {
						clay.TextDynamic(label, font(.Body, color))
					}
					if clay.UI()(
					{
						layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(line_width() * 2)}},
						backgroundColor = mix(fade(c.primary, 0), c.primary, on),
					},
					) {}
				}
			}
		}
		rule()
	}
	set_last(eid)
	return result, changed
}

tabs_enum :: proc(selected: $E, labels: [E]string) -> (E, bool) where intrinsics.type_is_enum(E) {
	l := labels
	i, ok := tabs_index(from_enum(selected), enum_labels(&l))
	return to_enum(E, i), ok
}

// ---------------------------------------------------------------------------
// Navigation list
// ---------------------------------------------------------------------------

// One destination of a navigation list. `icon` is a single glyph like "◆" or "⚙".
NavItem :: struct {
	icon, label: string,
}

// A vertical list of destinations (sidebars, drawers). `collapsed` shows only the icons, with
// the label as tooltip, for narrow navigation rails.
nav :: proc {
	nav_index,
	nav_enum,
}

nav_index :: proc(selected: int, items: []NavItem, collapsed := false) -> (int, bool) {
	c := &g_theme
	eid := id("nav")
	result, changed := selected, false

	if clay.UI(eid)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			childGap = space(.XS),
		},
	},
	) {
		for item, i in items {
			iid := sub_id(eid, "item", i)
			s := interact(iid)
			if s.clicked && selected != i {
				result, changed = i, true
			}
			on := result == i
			h := anim(iid, 0, s.hovered ? 1 : 0)
			bg := mix(fade(c.surface_hover, 0), c.surface_hover, h)
			if on {bg = tone_tint(.Primary)}
			fg := on ? c.primary : mix(c.text_muted, c.text, h)

			if clay.UI(iid)(
			{
				layout = {
					sizing = {clay.SizingGrow(), clay.SizingFixed(size(.Control))},
					padding = collapsed ? {} : inset(.MD, .None),
					childGap = space(.MD),
					childAlignment = {x = collapsed ? .Center : .Left, y = .Center},
				},
				backgroundColor = bg,
				cornerRadius = corners(.MD),
			},
			) {
				if len(item.icon) > 0 {clay.TextDynamic(item.icon, font(.Body, fg))}
				if !collapsed {
					style := font(.Body, fg)
					style.wrapMode = .None
					clay.TextDynamic(item.label, style)
				}
			}
			if collapsed {tooltip_on(iid, item.label, .Right)}
		}
	}
	set_last(eid)
	return result, changed
}

nav_enum :: proc(
	selected: $E,
	items: [E]NavItem,
	collapsed := false,
) -> (
	E,
	bool,
) where intrinsics.type_is_enum(E) {
	l := items
	i, ok := nav_index(from_enum(selected), enum_labels(&l), collapsed)
	return to_enum(E, i), ok
}

// ---------------------------------------------------------------------------
// Select
// ---------------------------------------------------------------------------

@(private)
SELECT_VISIBLE :: 8 // rows before the list scrolls

// A dropdown. `selected` is -1 (or out of range) while nothing is chosen; then the placeholder
// is shown. The list opens below the field, or above it when there is no room below.
select :: proc {
	select_index,
	select_enum,
}

select_index :: proc(
	selected: int,
	options: []string,
	placeholder := "",
	disabled := false,
) -> (
	int,
	bool,
) {
	c := &g_theme
	eid := id("select")
	list := sub_id(eid, "list")
	result, changed := selected, false

	s := interact(eid, disabled)
	if s.clicked {popup_set(eid, !popup_is_open(eid))}
	if disabled {popup_set(eid, false)}
	popup_dismiss(eid, list)
	open := popup_is_open(eid)

	h := anim(eid, 0, (s.hovered || open) ? 1 : 0)
	valid := selected >= 0 && selected < len(options)
	shown := valid ? options[selected] : placeholder
	style := font(.Body, (valid && !disabled) ? c.text : c.text_faint)
	style.wrapMode = .None

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFixed(size(.Control))},
			padding = inset(.MD, .None),
			childGap = space(.SM),
			childAlignment = {y = .Center},
		},
		backgroundColor = c.sunken,
		cornerRadius = corners(.MD),
		border = outline(mix(c.border, c.primary, h)),
		clip = {horizontal = true},
	},
	) {
		clay.TextDynamic(shown, style)
		spacer()
		clay.TextDynamic(open ? "▴" : "▾", font(.Body, c.text_muted))

		if open {
			if i, ok := popup_list(eid, list, options, selected); ok {
				result, changed = i, i != selected
				popup_set(eid, false)
			}
		}
	}
	set_last(eid, s)
	return result, changed
}

select_enum :: proc(
	selected: $E,
	options: [E]string,
	placeholder := "",
	disabled := false,
) -> (
	E,
	bool,
) where intrinsics.type_is_enum(E) {
	l := options
	i, ok := select_index(from_enum(selected), enum_labels(&l), placeholder, disabled)
	return to_enum(E, i), ok
}

// The floating option list of a select, attached to the field. Returns the clicked index.
@(private)
popup_list :: proc(owner, list: Id, options: []string, selected: int) -> (int, bool) {
	c := &g_theme
	field := clay.GetElementData(owner).boundingBox
	row_h := f32(font_size(.Body)) + 2 * f32(space(.SM))
	visible := min(len(options), SELECT_VISIBLE)
	list_h := f32(visible) * row_h + 2 * f32(space(.XS))

	// Open upwards if the list does not fit below the field but does above it.
	below := field.y + field.height + list_h + f32(space(.XS)) <= g_in.window.y
	up := !below && field.y - list_h - f32(space(.XS)) >= 0

	picked := -1
	old_z := g_z
	g_z = old_z + Z_POPUP
	defer g_z = old_z

	if clay.UI(list)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingFixed(field.width), clay.SizingFit({max = list_h})},
			padding = inset(.XS),
		},
		backgroundColor = c.surface,
		cornerRadius = corners(.MD),
		border = outline(c.border_strong),
		clip = {vertical = true, childOffset = clay.GetScrollOffset()},
		floating = {
			attachTo = .Parent,
			attachment = up ? {element = .LeftBottom, parent = .LeftTop} : {element = .LeftTop, parent = .LeftBottom},
			offset = {0, up ? -f32(space(.XS)) : f32(space(.XS))},
			zIndex = g_z,
			pointerCaptureMode = .Capture,
		},
	},
	) {
		interact(list) // clicks between the items stay inside the list
		scrollable(list)
		for opt, i in options {
			oid := sub_id(owner, "option", i)
			s := interact(oid)
			if s.clicked {picked = i}
			bg: Color
			if i == selected {bg = tone_tint(.Primary)}
			if s.hovered {bg = c.surface_hover}
			style := font(.Body, i == selected ? c.primary : c.text)
			style.wrapMode = .None
			if clay.UI(oid)(
			{
				layout = {
					sizing = {clay.SizingGrow(), clay.SizingFixed(row_h)},
					padding = inset(.MD, .None),
					childAlignment = {y = .Center},
				},
				backgroundColor = bg,
				cornerRadius = corners(.SM),
			},
			) {
				clay.TextDynamic(opt, style)
			}
		}
	}
	return picked, picked >= 0
}
