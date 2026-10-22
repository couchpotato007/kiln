package render

// Font table of the renderer. One font per `FontRole`, rasterized at the scaled size so text
// stays sharp. The fonts are (re)loaded by `sync_fonts` whenever the scale or the theme's
// font metrics change.

import clay "lib:kiln/clay-odin"
import th "lib:kiln/theme"
import rl "vendor:raylib"

// Fonts are rasterized at size * FONT_OVERSAMPLE for sharper text.
@(private)
FONT_OVERSAMPLE :: 2

@(private)
fonts: [th.FontRole]rl.Font

// Everything the loaded fonts depend on. If it changes, the fonts are reloaded.
@(private)
FontState :: struct {
	scale, base, ratio: f32,
	faces:              [th.FontRole]th.FontFace,
	files:              [th.FontFace]cstring,
}

@(private)
g_loaded: FontState
@(private)
g_has_fonts: bool

// Codepoints baked into the font atlas: ASCII, Latin-1/Latin Extended, general punctuation and the Euro sign.
@(private)
g_codepoints: [dynamic]rune

@(private)
codepoints :: proc() -> []rune {
	if len(g_codepoints) == 0 {
		for r in 32 ..= 126 {append(&g_codepoints, rune(r))}
		for r in 160 ..= 591 {append(&g_codepoints, rune(r))}
		for r in 0x2010 ..= 0x205E {append(&g_codepoints, rune(r))}
		append(&g_codepoints, rune(0x20AC))
	}
	return g_codepoints[:]
}

// Reloads all role fonts if the scale or the theme's font metrics changed since the last call.
// Called once per frame by the app loop, after `theme.update_scale`.
sync_fonts :: proc() {
	t := th.current()
	want := FontState {
		scale = th.scale_factor(),
		base  = t.font_base,
		ratio = t.font_ratio,
		faces = t.font_faces,
		files = t.font_files,
	}
	if g_has_fonts && want == g_loaded {return}

	unload_fonts()
	cps := codepoints()
	for role in th.FontRole {
		path := t.font_files[t.font_faces[role]]
		size := i32(th.font_size(role)) * FONT_OVERSAMPLE
		font := rl.LoadFontEx(path, size, raw_data(cps), i32(len(cps)))
		rl.SetTextureFilter(font.texture, .BILINEAR)
		fonts[role] = font
	}
	g_loaded = want
	g_has_fonts = true
	clay.ResetMeasureTextCache()
}

unload_fonts :: proc() {
	if !g_has_fonts {return}
	for role in th.FontRole {
		rl.UnloadFont(fonts[role])
	}
	g_has_fonts = false
}
