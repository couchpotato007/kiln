package kiln

// Non-interactive widgets: text, badge, avatar, progress, spinner, image.

import "core:math"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import clay "clay-odin"

// Text in a style and tone. It wraps at word boundaries when the container is too narrow.
//
//   kiln.text("Einstellungen", .Title)
//   kiln.text("Zuletzt geändert vor 3 Minuten", .Caption, .Muted)
text :: proc(s: string, style := TextStyle.Body, tone := Tone.Default) {
	clay.TextDynamic(s, font(style, tone_color(tone)))
	g_last = {}
}

// A small pill for status and counts. `dot` adds a leading circle (e.g. online status).
//
//   kiln.badge("Neu", .Primary)
//   kiln.badge("Online", .Success, dot = true)
badge :: proc(label: string, tone := Tone.Default, dot := false) {
	eid := id(label)
	fg := tone == .Default ? g_theme.text_muted : tone_color(tone)
	style := font(.Caption, fg)
	style.wrapMode = .None

	if clay.UI(eid)(
	{
		layout = {
			padding = {space(.SM), space(.SM), space(.XS) / 2, space(.XS) / 2},
			childGap = space(.XS),
			childAlignment = {y = .Center},
		},
		backgroundColor = tone_tint(tone),
		cornerRadius = corners(.Full),
	},
	) {
		if dot {
			d := size(.Dot)
			if clay.UI()(
			{
				layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
				backgroundColor = fg,
				cornerRadius = clay.CornerRadiusAll(d / 2),
			},
			) {}
		}
		if len(label) > 0 {clay.TextDynamic(label, style)}
	}
	set_last(eid)
}

@(private)
AVATAR_TONES := [?]Tone{.Primary, .Info, .Success, .Warning, .Danger}

// A circle with the initials of `name`; its color is derived from the name.
avatar :: proc(name: string, large := false) {
	d := size(.Avatar) * (large ? 2 : 1)
	hash: u32 = 2166136261
	for b in transmute([]u8)name {hash = (hash ~ u32(b)) * 16777619}
	tone := AVATAR_TONES[hash % len(AVATAR_TONES)]

	// First letter of the first two words.
	b := strings.builder_make(context.temp_allocator)
	for word in strings.fields(name, context.temp_allocator) {
		r, _ := utf8.decode_rune_in_string(word)
		strings.write_rune(&b, unicode.to_upper(r))
		if strings.builder_len(b) >= 2 {break}
	}

	eid := id(name)
	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingFixed(d), clay.SizingFixed(d)},
			childAlignment = {.Center, .Center},
		},
		backgroundColor = tone_tint(tone),
		cornerRadius = clay.CornerRadiusAll(d / 2),
	},
	) {
		clay.TextDynamic(strings.to_string(b), font(large ? .Title : .Caption, tone_color(tone)))
	}
	set_last(eid)
}

// A progress bar, `value` in [0, 1]. The bar follows changes smoothly.
progress :: proc(value: f32, tone := Tone.Primary) {
	eid := id("progress")
	v := anim(eid, 0, clamp(value, 0, 1))
	h := size(.Bar)
	r := clay.CornerRadiusAll(h / 2)
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(h)}},
		backgroundColor = g_theme.surface_hover,
		cornerRadius = r,
	},
	) {
		if clay.UI()(
		{
			layout = {sizing = {clay.SizingPercent(v), clay.SizingGrow()}},
			backgroundColor = tone_color(tone),
			cornerRadius = r,
		},
		) {}
	}
	set_last(eid)
}

// A loading indicator: three dots that pulse one after another.
spinner :: proc() {
	c := &g_theme
	eid := id("spinner")
	if clay.UI(eid)({layout = {childGap = space(.XS), childAlignment = {y = .Center}}}) {
		t := g_in.time * f64(c.spinner_speed)
		for i in 0 ..< 3 {
			pulse := f32(0.5 + 0.5 * math.sin((t - f64(i) * 0.2) * 2 * math.PI))
			d := size(.Dot) * (0.6 + 0.4 * pulse)
			if clay.UI()(
			{
				layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
				backgroundColor = fade(c.primary, 0.35 + 0.65 * pulse),
				cornerRadius = clay.CornerRadiusAll(d / 2),
			},
			) {}
		}
	}
	set_last(eid)
}

// An image (see `create_image` / `load_image`). Without a size it fills the available width
// and keeps its aspect ratio; with one of `width` / `height` (units) the other one follows.
image :: proc(img: Image, width: f32 = 0, height: f32 = 0) {
	if img.handle == nil || img.width <= 0 || img.height <= 0 {return}
	eid := id("image")
	aspect := f32(img.width) / f32(img.height)

	decl := clay.ElementDeclaration {
		image = {imageData = img.handle},
	}
	switch {
	case width > 0 && height > 0:
		decl.layout.sizing = {clay.SizingFixed(px(width)), clay.SizingFixed(px(height))}
	case width > 0:
		decl.layout.sizing = {clay.SizingFixed(px(width)), clay.SizingFixed(px(width) / aspect)}
	case height > 0:
		decl.layout.sizing = {clay.SizingFixed(px(height) * aspect), clay.SizingFixed(px(height))}
	case:
		decl.layout.sizing = {clay.SizingGrow(), clay.SizingFit()}
		decl.aspectRatio = {aspect}
	}
	if clay.UI(eid)(decl) {}
	set_last(eid)
}

// Pixel data and backend handle of an image. Create it after the window opened (in `init`).
Image :: struct {
	handle:        rawptr,
	width, height: int,
}

// One RGBA pixel.
Pixel :: [4]u8
