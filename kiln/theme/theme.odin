package theme

// The complete look of the UI: colors plus metrics. Widgets have no values of their own,
// they only reference the named steps defined here, so changing a value changes every widget.
//
//   t := kiln.catppuccin(.Mocha)
//   t.radii[.MD] = 2
//   t.sizes[.Control] = 40
//   t.spacing[.MD] = 16
//   kiln.set_theme(t)

import clay "lib:kiln/clay-odin"

// Color slots used by all widgets.
Colors :: struct {
	bg, bg_sunken:                                      clay.Color, // window background / inset areas (inputs)
	surface_0, surface_1, surface_2:                    clay.Color, // raised surfaces, from subtle to strong
	border, border_strong:                              clay.Color,
	text, text_muted, text_disabled:                    clay.Color,
	primary, primary_hover, primary_active, on_primary: clay.Color, // on_primary: text/icons drawn on primary
	secondary:                                          clay.Color,
	danger, danger_hover, danger_active:                clay.Color,
	selection:                                          clay.Color, // text selection highlight (semi-transparent)
}

// Named spacing steps (padding, gaps). Values live in `Metrics.spacing`.
Space :: enum {
	None,
	XS,
	SM,
	MD,
	LG,
	XL,
}

// Named corner radius steps. Values live in `Metrics.radii`.
Radius :: enum {
	None,
	SM,
	MD,
	LG,
	Full,
}

// Named element sizes. Values live in `Metrics.sizes`.
Size :: enum {
	Track, // slider track thickness
	Bar, // progress bar thickness
	Dot, // badge dot, spinner dots
	Mark, // checkbox / radio, slider knob, tree indent and arrow column
	Control, // control height (button, text field, select, slider)
	Dialog, // dialog width (modal)
	Menu, // minimum width of a context menu
}

// Typographic roles. Each role has its own font slot and size (see `font_size`).
FontRole :: enum {
	Caption,
	Body,
	Subtitle,
	Title,
	Headline,
}

FontFace :: enum {
	Regular,
	Bold,
}

// All dimensions of the UI, unscaled. The UI scale (DPI, zoom) is applied on top by
// `px`/`sp`/`radius`/`size_px`.
Metrics :: struct {
	spacing:        [Space]f32, // padding and gaps
	radii:          [Radius]f32, // corner radii, `.Full` is not scaled (pill shape)
	sizes:          [Size]f32, // element sizes, see `Size`
	border_width:   f32, // outline of cards, inputs, dividers; cursor and tab underline use twice this
	font_base:      f32, // font size of `.Body`
	font_ratio:     f32, // modular scale factor between two neighbouring font roles
	font_faces:     [FontRole]FontFace, // which face each role uses
	font_files:     [FontFace]cstring, // TTF file of each face
	anim_speed:     f32, // rate per second of hover/toggle fades
	tooltip_delay:  f32, // seconds of hover before a tooltip shows
	spinner_speed:  f32, // spinner pulses per second
	tint_alpha:     f32, // opacity of tinted backgrounds (badges)
	backdrop_alpha: f32, // opacity of the modal backdrop
	stripe_alpha:   f32, // opacity of the zebra stripes in tables
}

// Colors and metrics. The fields of both parts can be accessed directly,
// e.g. `theme.primary` and `theme.radii[.MD]`.
Theme :: struct {
	using colors:  Colors,
	using metrics: Metrics,
}

// The default metrics: 4px-based spacing, 36px controls, 16px base font, Iosevka.
default_metrics :: proc() -> Metrics {
	return {
		spacing = {.None = 0, .XS = 4, .SM = 8, .MD = 12, .LG = 16, .XL = 24},
		radii = {.None = 0, .SM = 4, .MD = 8, .LG = 14, .Full = 9999},
		sizes = {
			.Track = 6,
			.Bar = 8,
			.Dot = 8,
			.Mark = 18,
			.Control = 36,
			.Dialog = 420,
			.Menu = 160,
		},
		border_width = 1,
		font_base = 16,
		font_ratio = 1.25,
		font_faces = {
			.Caption = .Regular,
			.Body = .Regular,
			.Subtitle = .Bold,
			.Title = .Bold,
			.Headline = .Bold,
		},
		font_files = {
			.Regular = "resources/Iosevka-Regular.ttf",
			.Bold = "resources/Iosevka-SemiBold.ttf",
		},
		anim_speed = 14,
		tooltip_delay = 0.4,
		spinner_speed = 1.5,
		tint_alpha = 0.2,
		backdrop_alpha = 0.6,
		stripe_alpha = 0.5,
	}
}

// The active theme. All widgets read their colors and dimensions from here.
@(private)
g_theme: Theme

// Returns a copy of the active theme.
current :: proc() -> Theme {
	return g_theme
}

// Sets a complete theme (colors and metrics), e.g. a preset with a few values overridden.
// Takes effect on the next widget declaration; changes of the font metrics reload the fonts
// at the start of the next frame.
set_theme :: proc(t: Theme) {
	g_theme = t
}

// Replaces only the colors, e.g. to switch between a dark and a light scheme at runtime.
set_colors :: proc(c: Colors) {
	g_theme.colors = c
}

// Replaces only the metrics, e.g. for a compact or a rounded look.
set_metrics :: proc(m: Metrics) {
	g_theme.metrics = m
}
