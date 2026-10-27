package kiln

// Convenience widgets built from the basic ones: callout, empty state, chips and stat.

import "base:intrinsics"
import clay "clay-odin"

// A tinted box with an accent bar on the left for messages in the page (errors, hints,
// "connected"). The block holds text and buttons:
//
//   if kiln.callout(.Danger, "Konnte nicht laden") {
//       kiln.text(m.error)
//       if kiln.button("Nochmal", .Secondary) {append(out, Retry{})}
//   }
@(deferred_none = close_box)
callout :: proc(tone := Tone.Info, title := "") -> bool {
	accent := tone == .Default ? g_theme.text_muted : tone_color(tone)
	open_box(
		id(len(title) > 0 ? title : "callout"),
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = inset(.MD),
				childGap = space(.SM),
			},
			backgroundColor = tone_tint(tone),
			cornerRadius = corners(.MD),
			border = {color = accent, width = {left = u16(max(1, px(3)))}},
		},
	)
	if len(title) > 0 {text(title, .Subtitle, tone)}
	return true
}

// A centered, muted message for an empty list or page; the block can hold an action button:
//
//   if kiln.empty_state("Keine Aufgaben", "Lege oben die erste an.") {
//       if kiln.button("Beispiele laden", .Secondary) {append(out, Load_Examples{})}
//   }
@(deferred_none = close_box)
empty_state :: proc(title: string, text: string) -> bool {
	c := &g_theme
	open_box(
		id(title),
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = inset(.XL),
				childGap = space(.SM),
				childAlignment = {x = .Center},
			},
		},
	)
	title_style := font(.Subtitle, c.text_muted)
	title_style.textAlignment = .Center
	clay.TextDynamic(title, title_style)
	if len(text) > 0 {
		body := font(.Body, c.text_faint)
		body.textAlignment = .Center
		clay.TextDynamic(text, body)
	}
	return true
}

// A pill that toggles, e.g. a filter. Returns true when clicked; the caller flips `selected`:
//
//   if kiln.chip("Nur offene", m.only_open) {append(out, Toggle_Open{})}
chip :: proc(label: string, selected: bool, disabled := false) -> bool {
	c := &g_theme
	eid := id(label)
	s := interact(eid, disabled)
	h := anim(eid, 0, s.hovered ? 1 : 0)

	bg := mix(fade(c.surface_hover, 0), c.surface_hover, h)
	fg := c.text
	border := mix(c.border, c.border_strong, h)
	if selected {
		bg = mix(tone_tint(.Primary), fade(c.primary, c.tint_alpha * 1.6), h)
		fg, border = c.primary, fade(c.primary, 0.5)
	}
	if s.pressed {bg = c.surface_active}
	if disabled {fg = c.text_faint}
	style := font(.Body, fg)
	style.wrapMode = .None

	flow_item(eid)
	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingFit(), clay.SizingFixed(math_floor(size(.Control) * 0.85))},
			padding = inset(.MD, .None),
			childGap = space(.XS),
			childAlignment = {y = .Center},
		},
		backgroundColor = bg,
		cornerRadius = corners(.Full),
		border = outline(border),
	},
	) {
		if selected {clay.TextDynamic("✓", style)}
		clay.TextDynamic(label, style)
	}
	set_last(eid, s)
	return s.clicked
}

// A single choice from chips that wrap into lines (a `flow`).
chips :: proc {
	chips_index,
	chips_enum,
}

chips_index :: proc(selected: int, labels: []string) -> (int, bool) {
	result, changed := selected, false
	if flow(.SM, .SM) {
		for label, i in labels {
			if chip(label, i == selected) && i != selected {
				result, changed = i, true
			}
		}
	}
	return result, changed
}

chips_enum :: proc(selected: $E, labels: [E]string) -> (E, bool) where intrinsics.type_is_enum(E) {
	l := labels
	i, ok := chips_index(from_enum(selected), enum_labels(&l))
	return to_enum(E, i), ok
}

// A key figure: a caption, the value, and optionally a change badge and a note. Fits into
// `grid` cells:
//
//   kiln.stat("Bildschirmzeit", "5h 8m", delta = "↓ 12 %", delta_tone = .Success, large = true)
stat :: proc(
	label, value: string,
	note := "",
	delta := "",
	delta_tone := Tone.Default,
	large := false,
) {
	if column(.XS) {
		text(label, .Caption, .Muted)
		text(value, large ? .Headline : .Subtitle)
		if len(delta) > 0 || len(note) > 0 {
			if row(.XS) {
				if len(delta) > 0 {badge(delta, delta_tone)}
				if len(note) > 0 {text(note, .Caption, .Faint)}
			}
		}
	}
}

@(private = "file")
math_floor :: proc(v: f32) -> f32 {
	return f32(int(v))
}
