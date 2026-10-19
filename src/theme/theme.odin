package theme


import clay "lib:clay-odin"
import "lib:renderer"
import "core:math"
import rl "vendor:raylib"


// Semantic color slots used by all widgets.
// Use `theme_catppuccin` to get a preset, or fill it manually and pass it to `set_theme`.
Theme :: struct {
	bg, bg_sunken:                                      clay.Color, // window background / inset areas (inputs)
	surface_0, surface_1, surface_2:                    clay.Color, // raised surfaces, from subtle to strong
	border, border_strong:                              clay.Color,
	text, text_muted, text_disabled:                    clay.Color,
	primary, primary_hover, primary_active, on_primary: clay.Color, // on_primary: text/icons drawn on primary
	secondary, danger:                                  clay.Color,
	selection:                                          clay.Color, // text selection highlight (semi-transparent)
}

// Catppuccin color schemes. Mocha/Macchiato/Frappe are dark, Latte is light.
Flavor :: enum {
	Mocha,
	Macchiato,
	Frappe,
	Latte,
}

// Subset of the official Catppuccin palette that is needed to build a `Theme`.
@(private = "file")
Palette :: struct {
	base, mantle:                 clay.Color,
	surface0, surface1, surface2: clay.Color,
	overlay0:                     clay.Color,
	text, subtext0:               clay.Color,
	mauve, blue, red:             clay.Color,
}

@(private = "file")
PALETTES := [Flavor]Palette {
	.Mocha = {
		base = {30, 30, 46, 255},
		mantle = {24, 24, 37, 255},
		surface0 = {49, 50, 68, 255},
		surface1 = {69, 71, 90, 255},
		surface2 = {88, 91, 112, 255},
		overlay0 = {108, 112, 134, 255},
		text = {205, 214, 244, 255},
		subtext0 = {166, 173, 200, 255},
		mauve = {203, 166, 247, 255},
		blue = {137, 180, 250, 255},
		red = {243, 139, 168, 255},
	},
	.Macchiato = {
		base = {36, 39, 58, 255},
		mantle = {30, 32, 48, 255},
		surface0 = {54, 58, 79, 255},
		surface1 = {73, 77, 100, 255},
		surface2 = {91, 96, 120, 255},
		overlay0 = {110, 115, 138, 255},
		text = {202, 211, 245, 255},
		subtext0 = {165, 173, 203, 255},
		mauve = {198, 160, 246, 255},
		blue = {138, 173, 244, 255},
		red = {237, 135, 150, 255},
	},
	.Frappe = {
		base = {48, 52, 70, 255},
		mantle = {41, 44, 60, 255},
		surface0 = {65, 69, 89, 255},
		surface1 = {81, 87, 109, 255},
		surface2 = {98, 104, 128, 255},
		overlay0 = {115, 121, 148, 255},
		text = {198, 206, 239, 255},
		subtext0 = {165, 173, 206, 255},
		mauve = {202, 158, 230, 255},
		blue = {140, 170, 238, 255},
		red = {231, 130, 132, 255},
	},
	.Latte = {
		base = {239, 241, 245, 255},
		mantle = {230, 233, 239, 255},
		surface0 = {204, 208, 218, 255},
		surface1 = {188, 192, 204, 255},
		surface2 = {172, 176, 190, 255},
		overlay0 = {156, 160, 176, 255},
		text = {76, 79, 105, 255},
		subtext0 = {108, 111, 133, 255},
		mauve = {136, 57, 239, 255},
		blue = {30, 102, 245, 255},
		red = {210, 15, 57, 255},
	},
}

// Interpolates the RGB channels from `a` to `b` by `t` (0..1). The alpha of `a` is kept.
color_mix :: proc(a, b: clay.Color, t: f32) -> clay.Color {
	r := a + (b - a) * t
	r[3] = a[3]
	return r
}

// Returns `col` with its alpha replaced by `alpha` (0..1).
color_alpha :: proc(col: clay.Color, alpha: f32) -> clay.Color {
	r := col
	r[3] = clamp(alpha, 0, 1) * 255
	return r
}

// Builds a complete `Theme` from a Catppuccin flavor. Hover/active colors of the
// primary color are derived by mixing it with the text/background color.
theme_catppuccin :: proc(flavor: Flavor) -> Theme {
	p := PALETTES[flavor]
	return {
		bg = p.base,
		bg_sunken = p.mantle,
		surface_0 = p.surface0,
		surface_1 = p.surface1,
		surface_2 = p.surface2,
		border = p.surface1,
		border_strong = p.overlay0,
		text = p.text,
		text_muted = p.subtext0,
		text_disabled = p.overlay0,
		primary = p.mauve,
		primary_hover = color_mix(p.mauve, p.text, 0.12),
		primary_active = color_mix(p.mauve, p.base, 0.2),
		on_primary = p.base,
		secondary = p.blue,
		danger = p.red,
		selection = color_alpha(p.blue, 0.35),
	}
}

// The active theme. All `style_*` procs of the widgets read their default colors from here.
current: Theme
g_fonts: ThemeFonts

// Selects the initial flavor and the font files (regular and bold TTF).
// Call once after the window was created. Fonts are loaded in `begin_frame`.
init :: proc(flavor: Flavor, fonts: ThemeFonts) {
	current = theme_catppuccin(flavor)
	g_fonts = fonts
	g_scale.effective = 0
}

// Switches to another Catppuccin flavor at runtime. Takes effect on the next widget declaration.
set_flavor :: proc(flavor: Flavor) {
	current = theme_catppuccin(flavor)
}

// Sets a custom theme, e.g. a preset with a few colors overridden.
set_theme :: proc(theme: Theme) {
	current = theme
}


// Named spacing steps (padding, gaps). Values are in `SPACING` and scaled by `sp`/`px`.
Space :: enum {
	None,
	XS,
	SM,
	MD,
	LG,
	XL,
}

// Named corner radius steps. Values are in `RADIUS`.
Radius :: enum {
	None,
	SM,
	MD,
	LG,
	Full,
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

// Spacing in unscaled units, indexed by `Space`.
SPACING := [Space]f32 {
	.None = 0,
	.XS   = 4,
	.SM   = 8,
	.MD   = 12,
	.LG   = 16,
	.XL   = 24,
}
// Corner radii in unscaled units, indexed by `Radius`. `.Full` is not scaled (pill shape).
RADIUS := [Radius]f32 {
	.None = 0,
	.SM   = 4,
	.MD   = 8,
	.LG   = 14,
	.Full = 9999,
}
// Which font file each role uses.
FONT_FACE := [FontRole]FontFace {
	.Caption  = .Regular,
	.Body     = .Regular,
	.Subtitle = .Bold,
	.Title    = .Bold,
	.Headline = .Bold,
}

// Unscaled border width.
BORDER_WIDTH: f32 : 1
// Unscaled height shared by buttons, text fields, selects and sliders.
CONTROL_HEIGHT: f32 : 36
// Font size of `.Body` in unscaled units; other roles follow `FONT_RATIO`.
FONT_BASE: f32 : 16
// Modular scale factor between two neighbouring font roles.
FONT_RATIO: f32 : 1.25


// Paths to the TTF files used for `FontFace.Regular` and `FontFace.Bold`.
ThemeFonts :: struct {
	regular: cstring,
	bold:    cstring,
}

// Global UI scaling state. The effective scale is
// `user * dpi_scale * fit_scale` and is recomputed every frame in `begin_frame`.
UiScale :: struct {
	user:                 f32, // manual zoom factor, see `set_zoom`
	use_dpi:              bool, // multiply by the window DPI scale
	fit_reference_height: f32, // if > 0, scale with window height relative to this value
	fit_min, fit_max:     f32, // clamp range for the fit scale
	fit_step:             f32, // round the fit scale to multiples of this (avoids constant font reloads)
	font_oversample:      i32, // fonts are rasterized at size * oversample for sharper text
	effective:            f32, // result, do not set manually
}

g_scale := UiScale {
	user            = 1,
	use_dpi         = true,
	fit_min         = 0.75,
	fit_max         = 2.5,
	fit_step        = 0.125,
	font_oversample = 2,
}

// Sets the manual zoom factor (clamped to 0.5..4), e.g. for Ctrl +/- shortcuts.
set_zoom :: proc(zoom: f32) {
	g_scale.user = clamp(zoom, 0.5, 4)
}

// Recomputes the effective UI scale and reloads the fonts if it changed.
// Call once per frame before building the layout.
begin_frame :: proc() {
	s := g_scale.user
	if g_scale.use_dpi {
		s *= max(rl.GetWindowScaleDPI().x, 0.1)
	}
	if g_scale.fit_reference_height > 0 {
		fit := f32(rl.GetScreenHeight()) / g_scale.fit_reference_height
		if g_scale.fit_step > 0 {
			fit = math.round(fit / g_scale.fit_step) * g_scale.fit_step
		}
		s *= clamp(fit, g_scale.fit_min, g_scale.fit_max)
	}
	if abs(s - g_scale.effective) > 0.001 {
		g_scale.effective = s
		reload_fonts()
	}
}

@(private = "file")
g_codepoints: [dynamic]rune

// Codepoints baked into the font atlas: ASCII, Latin-1/Latin Extended, general punctuation and the Euro sign.
// Extend this if you need more glyphs.
codepoints :: proc() -> []rune {
	if len(g_codepoints) == 0 {
		for r in 32 ..= 126 {append(&g_codepoints, rune(r))}
		for r in 160 ..= 591 {append(&g_codepoints, rune(r))}
		for r in 0x2010 ..= 0x205E {append(&g_codepoints, rune(r))}
		append(&g_codepoints, rune(0x20AC))
	}
	return g_codepoints[:]
}

// Loads one font into the renderer's font table at slot `id` (the slot equals the `FontRole` index).
load_font :: proc(id: u16, size: u16, path: cstring) {
	cps := codepoints()
	font := rl.LoadFontEx(path, i32(size) * g_scale.font_oversample, raw_data(cps), i32(len(cps)))
	rl.SetTextureFilter(font.texture, .BILINEAR)
	assign_at(&renderer.raylib_fonts, id, renderer.Raylib_Font{font = font, fontId = id})
}

// Unloads and reloads all role fonts at the current scale and clears Clay's text measurement cache.
reload_fonts :: proc() {
	for role in FontRole {
		id := u16(role)
		if int(id) < len(renderer.raylib_fonts) {
			rl.UnloadFont(renderer.raylib_fonts[id].font)
		}
		path := FONT_FACE[role] == .Bold ? g_fonts.bold : g_fonts.regular
		load_font(id, font_size(role), path)
	}
	clay.ResetMeasureTextCache()
}


// Converts unscaled units to scaled pixels (rounded).
px :: proc(units: f32) -> f32 {
	return math.round(units * g_scale.effective)
}

// Like `px`, but returns the u16 that Clay expects for padding, gaps and border widths.
px16 :: proc(units: f32) -> u16 {
	return u16(max(0, px(units)))
}

// Scaled spacing value for use as `childGap`.
sp :: proc(s: Space) -> u16 {
	return px16(SPACING[s])
}

// Equal padding on all sides.
pad_all :: proc(s: Space) -> clay.Padding {
	return clay.PaddingAll(sp(s))
}

// Padding with separate horizontal and vertical steps.
pad_xy :: proc(horizontal, vertical: Space) -> clay.Padding {
	return {
		left = sp(horizontal),
		right = sp(horizontal),
		top = sp(vertical),
		bottom = sp(vertical),
	}
}

// Scaled corner radius for all four corners.
radius :: proc(r: Radius) -> clay.CornerRadius {
	v := RADIUS[r]
	if r == .Full {return clay.CornerRadiusAll(v)}
	return clay.CornerRadiusAll(px(v))
}

// Fixed sizing with the standard control height (buttons, inputs, ...).
size_control_height :: proc() -> clay.SizingAxis {
	return clay.SizingFixed(px(CONTROL_HEIGHT))
}

// Outer border of the theme's border width in the given color.
border_box :: proc(color: clay.Color) -> clay.BorderElementConfig {
	return {color = color, width = clay.BorderOutside(px16(BORDER_WIDTH))}
}

// Scaled font size in pixels for a role: `FONT_BASE * FONT_RATIO^(role - Body) * scale`.
font_size :: proc(role: FontRole) -> u16 {
	exp := f32(int(role) - int(FontRole.Body))
	return u16(max(1, math.round(FONT_BASE * math.pow(FONT_RATIO, exp) * g_scale.effective)))
}

// Text config (font slot, size, color) for a typographic role.
text_style :: proc(role: FontRole, color: clay.Color) -> clay.TextElementConfig {
	return {fontId = u16(role), fontSize = font_size(role), textColor = color}
}


// Element declaration for a bordered, rounded container that stacks its children vertically.
style_panel :: proc(padding := Space.MD) -> clay.ElementDeclaration {
	return {
		layout = {padding = pad_all(padding), childGap = sp(.SM), layoutDirection = .TopToBottom},
		backgroundColor = current.surface_0,
		cornerRadius = radius(.MD),
		border = border_box(current.border),
	}
}
