package render

import "base:runtime"
import "core:unicode/utf8"
import clay "lib:kiln/clay-odin"
import th "lib:kiln/theme"
import rl "vendor:raylib"

// Size of `text` set in the font and size of `cfg`.
text_dimensions :: proc(text: string, cfg: clay.TextElementConfig) -> clay.Dimensions {
	font := fonts[th.FontRole(cfg.fontId)]

	line_width: f32 = 0
	for letter in text {
		glyph_index := rl.GetGlyphIndex(font, letter)
		glyph := font.glyphs[glyph_index]
		if glyph.advanceX != 0 {
			line_width += f32(glyph.advanceX)
		} else {
			line_width += font.recs[glyph_index].width + f32(glyph.offsetX)
		}
	}

	scale := f32(cfg.fontSize) / f32(font.baseSize)
	spacing := f32(utf8.rune_count_in_string(text)) * f32(cfg.letterSpacing)
	return {width = line_width * scale + spacing, height = f32(cfg.fontSize)}
}

// Width of `text`, for widgets that position things inside a line of text (cursor, selection).
text_width :: proc(text: string, cfg: clay.TextElementConfig) -> f32 {
	if len(text) == 0 {return 0}
	return text_dimensions(text, cfg).width
}

// Text measurement callback for Clay: `clay.SetMeasureTextFunction(render.measure_text, nil)`.
measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()
	return text_dimensions(string(text.chars[:text.length]), config^)
}
