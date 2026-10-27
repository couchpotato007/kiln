package kiln

// The look of the UI: colors plus metrics. Widgets have no values of their own, they only
// reference the named steps defined here, so changing a value changes every widget.
//
//   t := kiln.catppuccin(.Mocha)
//   t.radii[.MD] = 2
//   t.sizes[.Control] = 40
//   kiln.set_theme(t)

import clay "clay-odin"

Color :: clay.Color

// Color slots used by all widgets.
Colors :: struct {
	window, sunken:                         Color, // window background / inset areas (inputs, sidebars)
	surface, surface_hover, surface_active: Color, // raised areas (cards, buttons) and their hover / pressed shade
	border, border_strong:                  Color,
	text, text_muted, text_faint:           Color,
	primary, on_primary:                    Color, // on_primary: text drawn on any accent color
	info, success, warning, danger:         Color,
	selection:                              Color, // text selection (semi-transparent)
	chart:                                  [8]Color, // categorical colors for charts, see `chart_color`
}

// Background slots for containers.
Surface :: enum {
	None, // transparent
	Window,
	Sunken,
	Raised,
}

// Semantic colors for text, badges, progress bars and toasts.
Tone :: enum {
	Default,
	Muted,
	Faint,
	Primary,
	Info,
	Success,
	Warning,
	Danger,
}

// Named spacing steps (padding, gaps).
Space :: enum {
	None,
	XS,
	SM,
	MD,
	LG,
	XL,
}

// Named corner radius steps. `.Full` gives pills and circles.
Radius :: enum {
	None,
	SM,
	MD,
	LG,
	Full,
}

// Named element sizes.
Size :: enum {
	Track, // slider track thickness
	Bar, // progress bar thickness
	Dot, // badge dot, spinner dots
	Mark, // checkbox / radio box, slider knob, tree indent
	Control, // height of buttons, inputs, selects
	Avatar,
	Drawer,
	Dialog, // maximum dialog width
	Menu, // minimum menu width
	Toast,
}

// Typographic styles, from small to large.
TextStyle :: enum {
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

// All dimensions of the UI in units. The UI scale (DPI, zoom) turns units into pixels.
Metrics :: struct {
	spacing:        [Space]f32,
	radii:          [Radius]f32, // `.Full` is not scaled
	sizes:          [Size]f32,
	breakpoints:    [Screen]f32, // minimum window width of each screen class
	border_width:   f32,
	font_base:      f32, // font size of `.Body`
	font_ratio:     f32, // factor between two neighbouring text styles
	font_faces:     [TextStyle]FontFace,
	font_files:     [FontFace]cstring, // paths, relative to the working directory
	font_data:      [FontFace][]u8, // font files in memory (e.g. `#load`ed); win over `font_files`
	font_fallbacks: [][]u8, // fonts in memory for characters the faces lack (CJK, symbols, ...), tried in order
	anim_speed:     f32, // rate per second of hover / toggle fades
	tooltip_delay:  f32, // seconds of hover before a tooltip shows
	toast_duration: f32, // seconds a toast stays visible
	spinner_speed:  f32, // spinner pulses per second
	tint_alpha:     f32, // opacity of tinted backgrounds (badges, selected items)
	backdrop_alpha: f32, // opacity of the dialog / drawer backdrop
	stripe_alpha:   f32, // opacity of the zebra stripes in tables
	locale:         Locale, // month / weekday names for calendars (`locale_en`, `locale_de`)
}

// Colors and metrics. Fields of both parts can be accessed directly: `t.primary`, `t.radii[.MD]`.
Theme :: struct {
	using colors:  Colors,
	using metrics: Metrics,
}

// The Iosevka subsets in resources/ are compiled into the binary, so apps start from any
// directory. Build with `-define:KILN_EMBED_FONTS=false` to load `font_files` at runtime instead
// (see tools/subset_font for making subsets of other fonts).
KILN_EMBED_FONTS :: #config(KILN_EMBED_FONTS, true)

when KILN_EMBED_FONTS {
	@(private)
	EMBEDDED_FONTS := [FontFace][]u8 {
		.Regular = #load("../resources/kiln-regular.ttf"),
		.Bold    = #load("../resources/kiln-bold.ttf"),
	}
} else {
	@(private)
	EMBEDDED_FONTS: [FontFace][]u8
}

// 4px based spacing, 36px controls, 16px body text, Iosevka.
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
			.Avatar = 36,
			.Drawer = 300,
			.Dialog = 440,
			.Menu = 180,
			.Toast = 340,
		},
		breakpoints = {.Compact = 0, .Medium = 600, .Expanded = 1000},
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
		font_files = {.Regular = "resources/kiln-regular.ttf", .Bold = "resources/kiln-bold.ttf"},
		font_data = EMBEDDED_FONTS,
		anim_speed = 14,
		tooltip_delay = 0.4,
		toast_duration = 3,
		spinner_speed = 1.5,
		tint_alpha = 0.18,
		backdrop_alpha = 0.45,
		stripe_alpha = 0.5,
		locale = locale_en(),
	}
}

@(private)
g_theme: Theme

// A copy of the active theme, e.g. to derive a modified one.
theme :: proc() -> Theme {
	return g_theme
}

// Replaces colors and metrics. Font changes reload the fonts at the start of the next frame.
set_theme :: proc(t: Theme) {
	g_theme = t
}

// Replaces only the colors, e.g. to switch between a dark and a light scheme.
set_colors :: proc(c: Colors) {
	g_theme.colors = c
}

// Replaces only the metrics, e.g. for a compact or a rounded look.
set_metrics :: proc(m: Metrics) {
	g_theme.metrics = m
}

// Interpolates all channels (including alpha) from `a` to `b` by `t` (0..1).
mix :: proc(a, b: Color, t: f32) -> Color {
	return a + (b - a) * clamp(t, 0, 1)
}

// `color` with its alpha replaced by `alpha` (0..1).
fade :: proc(color: Color, alpha: f32) -> Color {
	c := color
	c.a = clamp(alpha, 0, 1) * 255
	return c
}

// The theme color of a tone (as text / foreground color).
tone_color :: proc(t: Tone) -> Color {
	c := &g_theme
	switch t {
	case .Default:
		return c.text
	case .Muted:
		return c.text_muted
	case .Faint:
		return c.text_faint
	case .Primary:
		return c.primary
	case .Info:
		return c.info
	case .Success:
		return c.success
	case .Warning:
		return c.warning
	case .Danger:
		return c.danger
	}
	return c.text
}

// Tinted background for a tone (badges, selected rows, toasts).
tone_tint :: proc(t: Tone) -> Color {
	switch t {
	case .Default, .Muted, .Faint:
		return g_theme.surface_hover
	case .Primary, .Info, .Success, .Warning, .Danger:
	}
	return fade(tone_color(t), g_theme.tint_alpha)
}

surface_color :: proc(s: Surface) -> Color {
	switch s {
	case .None:
		return {}
	case .Window:
		return g_theme.window
	case .Sunken:
		return g_theme.sunken
	case .Raised:
		return g_theme.surface
	}
	return {}
}
