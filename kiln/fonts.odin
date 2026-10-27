package kiln

// Font files and fallbacks, shared by both backends.
//
// Every character is drawn with the first font that has it: the face of the text style, then
// the theme's `font_fallbacks` in order. The raylib backend bakes only the characters that were
// actually measured into its atlases and adds new ones at the start of the next frame, so any
// character a font has can be shown.

import "core:fmt"
import "core:os"
import stbtt "vendor:stb/truetype"

@(private)
LoadedFont :: struct {
	info:            stbtt.fontinfo,
	data:            []u8,
	owned:           bool, // data was read from a file and is freed with the font
	ascent, descent: f32, // unscaled
	loaded:          bool,
}

// The faces (indexed by FontFace), then the fallbacks.
@(private)
g_fonts: [dynamic]LoadedFont

// What the fonts in `g_fonts` were loaded from; if it changes, they are reloaded.
@(private)
FontSources :: struct {
	data:      [FontFace]rawptr,
	files:     [FontFace]cstring,
	fallbacks: rawptr,
	count:     int,
}

@(private)
g_font_sources: FontSources

// The font index (into `g_fonts`) per face and character.
@(private)
g_font_pick: map[[2]i32]i32

// Loads the theme's fonts if they changed; returns true then.
@(private)
fonts_sync :: proc() -> bool {
	t := &g_theme
	want := FontSources {
		files     = t.font_files,
		fallbacks = raw_data(t.font_fallbacks),
		count     = len(t.font_fallbacks),
	}
	for face in FontFace {want.data[face] = raw_data(t.font_data[face])}
	if len(g_fonts) > 0 && want == g_font_sources {return false}

	for &f in g_fonts {
		if f.owned {delete(f.data)}
	}
	clear(&g_fonts)
	clear(&g_font_pick)
	for face in FontFace {
		f: LoadedFont
		if data := t.font_data[face]; len(data) > 0 {
			f.data = data
		} else if file, err := os.read_entire_file(string(t.font_files[face]), context.allocator); err == nil {
			f.data, f.owned = file, true
		} else {
			fmt.eprintln("kiln: cannot read font", t.font_files[face])
		}
		append(&g_fonts, font_init(f))
	}
	for data in t.font_fallbacks {
		append(&g_fonts, font_init({data = data}))
	}
	g_font_sources = want
	return true
}

@(private)
font_init :: proc(font: LoadedFont) -> LoadedFont {
	f := font
	if len(f.data) == 0 {return f}
	offset := stbtt.GetFontOffsetForIndex(raw_data(f.data), 0)
	if offset < 0 || !stbtt.InitFont(&f.info, raw_data(f.data), offset) {
		fmt.eprintln("kiln: not a TrueType / OpenType font")
		return f
	}
	asc, desc, gap: i32
	stbtt.GetFontVMetrics(&f.info, &asc, &desc, &gap)
	f.ascent, f.descent = f32(asc), f32(desc)
	f.loaded = true
	return f
}

// The font that draws `r` in `face`: the face itself, the first fallback that has the character,
// or the face again (which then shows its replacement glyph).
@(private)
font_for :: proc(face: FontFace, r: rune) -> int {
	if len(g_fonts) == 0 {return int(face)} // before the first frame
	key := [2]i32{i32(face), i32(r)}
	if i, ok := g_font_pick[key]; ok {return int(i)}
	pick := int(face)
	if !font_has(int(face), r) {
		for i in len(FontFace) ..< len(g_fonts) {
			if font_has(i, r) {
				pick = i
				break
			}
		}
	}
	g_font_pick[key] = i32(pick)
	return pick
}

@(private)
font_has :: proc(i: int, r: rune) -> bool {
	f := &g_fonts[i]
	return f.loaded && stbtt.FindGlyphIndex(&f.info, r) != 0
}

// Distance from the top of a line to the baseline, as a fraction of the font size.
@(private)
font_ascent :: proc(i: int) -> f32 {
	if i >= len(g_fonts) {return 0.8}
	f := &g_fonts[i]
	if !f.loaded || f.ascent == f.descent {return 0.8}
	return f.ascent / (f.ascent - f.descent)
}
