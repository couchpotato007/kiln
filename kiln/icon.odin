package kiln

// Icons: SVG documents, images or characters of the font, drawn at the size of text.
//
//   FOLDER :: kiln.Icon{svg = #load("icons/folder.svg", string)}
//
//   kiln.icon(FOLDER, .Title, .Primary)
//   if kiln.button(kiln.ICON_MENU, .Ghost) {kiln.show("nav")}
//   if kiln.button("Speichern", icon = kiln.ICON_CHECK) { ... }
//
// SVGs are rasterized for every pixel size they are drawn at, so they stay sharp at any zoom.
// Icons with a single color (like most icon sets, which use `currentColor` or black) take the
// color of the text around them; colorful ones keep their colors. See svg.odin for the subset of
// SVG that is understood.

import "core:math"
import "core:os"
import "core:path/filepath"
import "core:strings"
import clay "clay-odin"

// An icon. Set one of the fields; the zero value is "no icon". Icons are plain values, so they
// can be constants and live in tables (`NavItem`, `TreeNode`).
Icon :: struct {
	svg:   string, // an SVG document, e.g. `#load("icons/menu.svg", string)`
	glyph: string, // or a character of the font, e.g. "★"
	image: Image, // or an image, scaled to the icon height
	tint:  bool, // draw `image` in the text color (single-color images; `load_icon` decides)
}

// Icon height relative to the font size of its text style; icons have some padding built in.
@(private)
ICON_SCALE :: 1.2

// Built-in icons: 24x24 strokes in the text color, used by kiln's own widgets too.

ICON_CHECK :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>`,
}
ICON_CLOSE :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/></svg>`,
}
ICON_CHEVRON_DOWN :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg>`,
}
ICON_CHEVRON_UP :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 15l6-6 6 6"/></svg>`,
}
ICON_CHEVRON_LEFT :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 6l-6 6 6 6"/></svg>`,
}
ICON_CHEVRON_RIGHT :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6"/></svg>`,
}
ICON_MENU :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 6.5h16M4 12h16M4 17.5h16"/></svg>`,
}
ICON_MORE :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="5.5" cy="12" r="1.75"/><circle cx="12" cy="12" r="1.75"/><circle cx="18.5" cy="12" r="1.75"/></svg>`,
}
ICON_PLUS :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>`,
}
ICON_MINUS :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M5 12h14"/></svg>`,
}
ICON_SEARCH :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/></svg>`,
}
ICON_CALENDAR :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/></svg>`,
}
ICON_EYE :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 12C4.5 7.8 8 5.5 12 5.5s7.5 2.3 9.5 6.5c-2 4.2-5.5 6.5-9.5 6.5S4.5 16.2 2.5 12z"/><circle cx="12" cy="12" r="3"/></svg>`,
}
ICON_EYE_OFF :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 12C4.5 7.8 8 5.5 12 5.5s7.5 2.3 9.5 6.5c-2 4.2-5.5 6.5-9.5 6.5S4.5 16.2 2.5 12z"/><circle cx="12" cy="12" r="3"/><path d="M4 4l16 16"/></svg>`,
}
ICON_STAR :: Icon {
	svg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><polygon points="12 3.3 14.47 9.4 21.04 9.86 15.99 14.1 17.58 20.49 12 17 6.42 20.49 8.01 14.1 2.96 9.86 9.53 9.4"/></svg>`,
}

// An icon at the size of text in `style`, in the color of `tone` (if it has a single color).
//
//   kiln.icon(kiln.ICON_STAR, .Title, .Warning)
icon :: proc(ic: Icon, style := TextStyle.Body, tone := Tone.Default) {
	eid := id("icon")
	flow_item(eid)
	if clay.UI(eid)({layout = {childAlignment = {.Center, .Center}}}) {
		icon_element(ic, style, tone_color(tone))
	}
	set_last(eid)
}

// Loads an icon from a file: an SVG, or an image (PNG, JPG, ...). Images with a single color
// (e.g. black on transparent) are tinted like text, colorful ones are drawn as they are. Call it
// after the window opened (in `init`); the icon lives until the app ends.
load_icon :: proc(path: string) -> (Icon, bool) {
	if strings.equal_fold(filepath.ext(path), ".svg") {
		data, err := os.read_entire_file(path, context.allocator)
		if err != nil {return {}, false}
		return {svg = string(data)}, true
	}
	w, h, pixels, ok := backend_load_pixels(path)
	if !ok {return {}, false}
	return icon_pixels(w, h, pixels), true
}

// An icon from RGBA pixels (row by row, top to bottom), with the same color rule as `load_icon`.
icon_pixels :: proc(width, height: int, pixels: []Pixel) -> Icon {
	// Single-colored: every visible pixel has about the color of the first one.
	mono := true
	ref: Maybe(Pixel)
	for p in pixels {
		if p.a < 16 {continue}
		r, has := ref.?
		if !has {
			ref = p
			continue
		}
		for k in 0 ..< 3 {
			if abs(int(p[k]) - int(r[k])) > 24 {mono = false}
		}
		if !mono {break}
	}
	if !mono {return {image = create_image(width, height, pixels), tint = false}}
	white := make([]Pixel, len(pixels), context.temp_allocator)
	for p, i in pixels {white[i] = {255, 255, 255, p.a}}
	return {image = create_image(width, height, white), tint = true}
}

// True for the zero Icon.
icon_empty :: proc(ic: Icon) -> bool {
	return len(ic.svg) == 0 && len(ic.glyph) == 0 && ic.image.handle == nil
}

// Pixel height of an icon next to text in `style`.
@(private)
icon_size :: proc(style: TextStyle) -> f32 {
	return math.round(f32(font_size(style)) * ICON_SCALE)
}

// Declares the element of an icon (inside a widget), in `color` if the icon has a single color.
@(private)
icon_element :: proc(ic: Icon, style: TextStyle, color: Color) {
	d := icon_size(style)
	switch {
	case len(ic.svg) > 0:
		img, mono := icon_svg_image(ic.svg, int(d))
		image_element(img.handle, {d, d}, color, mono)
	case ic.image.handle != nil && ic.image.height > 0:
		w := math.round(d * f32(ic.image.width) / f32(ic.image.height))
		image_element(ic.image.handle, {w, d}, color, ic.tint)
	case len(ic.glyph) > 0:
		style_cfg := font(style, color)
		style_cfg.wrapMode = .None
		clay.TextDynamic(ic.glyph, style_cfg)
	}
}

// An image multiplied by a color, drawn by the backends for Clay's custom elements. (An image
// element's background color would also be drawn as a rectangle behind it.)
@(private)
TintedImage :: struct {
	handle: rawptr,
	tint:   Color,
}

// An image element of `size` pixels; `tinted` draws it multiplied by `tint`.
@(private)
image_element :: proc(handle: rawptr, size: [2]f32, tint: Color, tinted: bool) {
	if handle == nil {return}
	decl := clay.ElementDeclaration {
		layout = {sizing = {clay.SizingFixed(size.x), clay.SizingFixed(size.y)}},
	}
	if tinted {
		t := new(TintedImage, context.temp_allocator) // lives until the frame is drawn
		t^ = {handle, tint}
		decl.custom = {customData = t}
	} else {
		decl.image = {imageData = handle}
	}
	if clay.UI()(decl) {}
}

// A string that identifies an icon, for widget ids.
@(private)
icon_key :: proc(ic: Icon) -> string {
	switch {
	case len(ic.svg) > 0:
		return ic.svg
	case len(ic.glyph) > 0:
		return ic.glyph
	}
	return "icon"
}

// ---------------------------------------------------------------------------
// Cache of parsed SVGs and their textures per pixel size
// ---------------------------------------------------------------------------

@(private)
IconTexture :: struct {
	image: Image,
	frame: u64, // last frame it was drawn in
}

@(private)
IconSvg :: struct {
	svg:      Svg,
	ok:       bool,
	textures: map[int]IconTexture,
}

// Keyed by the SVG document (a copy of it).
@(private)
g_icon_svgs: map[string]^IconSvg

@(private)
icon_svg_image :: proc(doc: string, size: int) -> (Image, bool) {
	entry := g_icon_svgs[doc]
	if entry == nil {
		entry = new(IconSvg)
		entry.svg, entry.ok = svg_parse(doc)
		g_icon_svgs[strings.clone(doc)] = entry
	}
	if !entry.ok || size <= 0 {return {}, false}
	if size not_in entry.textures {
		pixels := svg_rasterize(&entry.svg, size, size, context.temp_allocator)
		entry.textures[size] = {image = create_image(size, size, pixels)}
	}
	t := &entry.textures[size]
	t.frame = g_frame
	return t.image, entry.svg.mono
}

// Frees textures of sizes that were not drawn for a while (e.g. after zooming).
@(private)
icons_collect :: proc() {
	for _, entry in g_icon_svgs {
		for size, &t in entry.textures {
			if t.frame + STALE_FRAMES < g_frame {
				destroy_image(&t.image)
				delete_key(&entry.textures, size)
			}
		}
	}
}
