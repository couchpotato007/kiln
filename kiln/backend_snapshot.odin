package kiln

// The snapshot backend: renders the app without a window into PNG files at phone, tablet and
// desktop size, e.g. to check a layout on all screen classes at once:
//
//   odin run example -collection:lib=. -define:KILN_SNAPSHOT=true
//
// Each size gets a fresh model and runs a second of frames (so animations settle and layouts
// that measure the previous frame are stable). The pointer is outside the window. Output goes
// to `KILN_SNAPSHOT_DIR` (default "snapshots"). Text is rasterized with stb_truetype from the
// theme's font files, so it measures the same as in the raylib backend.

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import clay "clay-odin"
import stbi "vendor:stb/image"
import stbtt "vendor:stb/truetype"

when KILN_SNAPSHOT {

	KILN_SNAPSHOT_DIR :: #config(KILN_SNAPSHOT_DIR, "snapshots")

	@(private)
	SnapshotSize :: struct {
		name:          string,
		width, height: f32,
	}

	@(private)
	SNAPSHOT_SIZES := [?]SnapshotSize {
		{"phone", 390, 844},
		{"tablet", 820, 1180},
		{"desktop", 1440, 900},
	}

	@(private)
	SNAPSHOT_FRAMES :: 60

	// The sizes to render, e.g. `-define:KILN_SNAPSHOT_SIZES=phone,desktop`.
	KILN_SNAPSHOT_SIZES :: #config(KILN_SNAPSHOT_SIZES, "phone,tablet,desktop")

	// Frame of the first click of `Config.snapshot_clicks`, and frames between clicks.
	@(private)
	SNAPSHOT_CLICK_START :: 10
	@(private)
	SNAPSHOT_CLICK_EVERY :: 6

	run :: proc(a: App($Model, $Msg), config := Config{}) {
		cfg := app_init(config)
		os.make_directory_all(KILN_SNAPSHOT_DIR)
		name := strings.clone(snap_file_name(string(cfg.title)))

		for s in SNAPSHOT_SIZES {
			wanted := false
			for w in strings.split(KILN_SNAPSHOT_SIZES, ",", context.temp_allocator) {
				if strings.trim_space(w) == s.name {wanted = true}
			}
			if !wanted {continue}
			snap_run(a, cfg, s, fmt.tprintf("%s-%s", name, s.name), "")
			for o in cfg.snapshot_open {
				snap_run(a, cfg, s, fmt.tprintf("%s-%s-%s", name, s.name, snap_file_name(o)), o)
			}
		}
	}

	// Renders one image from a fresh model and fresh UI state.
	@(private)
	snap_run :: proc(a: App($Model, $Msg), cfg: Config, s: SnapshotSize, file_temp, overlay: string) {
		file := strings.clone(file_temp) // the temp allocator is cleared every frame
		defer delete(file)
		g_overlay, g_popup, g_focus, g_active = 0, 0, 0, 0
		clear(&g_hover_start)
		clear(&g_calendars)
		clear(&g_timers)

		model := a.init()
		if cfg.snapshot_setup != nil {cfg.snapshot_setup(&model)}
		if len(overlay) > 0 {show(overlay)}

		last_click := SNAPSHOT_CLICK_START + SNAPSHOT_CLICK_EVERY * len(cfg.snapshot_clicks)
		for f in 0 ..< max(SNAPSHOT_FRAMES, last_click + 30) {
			input := Input {
				mouse  = {-1000, -1000},
				dt     = 1.0 / 60,
				time   = f64(f) / 60,
				window = {s.width, s.height},
				dpi    = 1,
			}
			if cfg.snapshot_pointer != {} {input.mouse = cfg.snapshot_pointer * g_scale_factor}
			// A click is a press in one frame and the release in the next, at the same place.
			if k := f - SNAPSHOT_CLICK_START; k >= 0 && k / SNAPSHOT_CLICK_EVERY < len(cfg.snapshot_clicks) {
				input.mouse = cfg.snapshot_clicks[k / SNAPSHOT_CLICK_EVERY] * g_scale_factor
				switch k % SNAPSHOT_CLICK_EVERY {
				case 0:
					input.pressed, input.down = {.Left}, {.Left}
				case 1:
					input.released = {.Left}
				}
			}
			commands, msgs := app_frame(a, &model, input, cfg)
			if f == max(SNAPSHOT_FRAMES, last_click + 30) - 1 {
				path := fmt.tprintf("%s/%s.png", KILN_SNAPSHOT_DIR, file)
				snap_render(&commands, int(s.width), int(s.height), path)
				fmt.println("snapshot:", path)
			}
			app_update(a, &model, msgs)
			free_all(context.temp_allocator)
		}
	}

	create_image :: proc(width, height: int, pixels: []Pixel) -> Image {
		img := new(SnapImage)
		img.width, img.height = width, height
		img.pixels = make([]Pixel, width * height)
		copy(img.pixels, pixels)
		return {img, width, height}
	}

	load_image :: proc(path: string) -> (Image, bool) {
		w, h, n: i32
		data := stbi.load(strings.clone_to_cstring(path, context.temp_allocator), &w, &h, &n, 4)
		if data == nil {return {}, false}
		defer stbi.image_free(data)
		return create_image(int(w), int(h), ([^]Pixel)(data)[:w * h]), true
	}

	destroy_image :: proc(img: ^Image) {
		if img.handle == nil {return}
		s := (^SnapImage)(img.handle)
		delete(s.pixels)
		free(s)
		img^ = {}
	}

	@(private)
	SnapImage :: struct {
		width, height: int,
		pixels:        []Pixel,
	}

	@(private)
	snap_file_name :: proc(title: string) -> string {
		b := strings.builder_make(context.temp_allocator)
		for r in strings.to_lower(title, context.temp_allocator) {
			ok := (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9')
			strings.write_rune(&b, ok ? r : '-')
		}
		return strings.to_string(b)
	}

	@(private)
	g_snap_clipboard: string

	@(private)
	backend_get_clipboard :: proc() -> string {return g_snap_clipboard}

	@(private)
	backend_set_clipboard :: proc(s: string) {
		delete(g_snap_clipboard)
		g_snap_clipboard = strings.clone(s)
	}

	// -------------------------------------------------------------------------
	// Fonts
	// -------------------------------------------------------------------------

	@(private)
	SnapFont :: struct {
		info:   stbtt.fontinfo,
		data:   []u8,
		ascent: f32, // unscaled
		loaded: bool,
	}

	@(private)
	g_snap_fonts: [FontFace]SnapFont

	@(private)
	GlyphKey :: struct {
		face: FontFace,
		size: u16,
		r:    rune,
	}

	@(private)
	Glyph :: struct {
		w, h, x, y: i32, // bitmap size and offset from the pen position on the baseline
		alpha:      []u8,
	}

	@(private)
	g_glyphs: map[GlyphKey]Glyph

	@(private)
	backend_sync_fonts :: proc() {
		for face in FontFace {
			f := &g_snap_fonts[face]
			if f.loaded {continue}
			if embedded := g_theme.font_data[face]; len(embedded) > 0 {
				f.data = embedded
			} else {
				data, err := os.read_entire_file(string(g_theme.font_files[face]), context.allocator)
				if err != nil {
					fmt.eprintln("snapshot: cannot read font", g_theme.font_files[face])
					continue
				}
				f.data = data
			}
			stbtt.InitFont(&f.info, raw_data(f.data), 0)
			asc, desc, gap: i32
			stbtt.GetFontVMetrics(&f.info, &asc, &desc, &gap)
			f.ascent = f32(asc)
			f.loaded = true
		}
	}

	@(private)
	snap_font :: proc(style: TextStyle) -> ^SnapFont {
		return &g_snap_fonts[g_theme.font_faces[style]]
	}

	@(private)
	backend_measure :: proc(text: string, style: TextStyle, font_size: u16) -> [2]f32 {
		f := snap_font(style)
		if !f.loaded {return {f32(len(text)) * f32(font_size) / 2, f32(font_size)}}
		scale := stbtt.ScaleForPixelHeight(&f.info, f32(font_size))
		w: f32 = 0
		for r in text {
			adv, lsb: i32
			stbtt.GetCodepointHMetrics(&f.info, r, &adv, &lsb)
			w += f32(adv) * scale
		}
		return {w, f32(font_size)}
	}

	@(private)
	snap_glyph :: proc(style: TextStyle, font_size: u16, r: rune) -> Glyph {
		key := GlyphKey{g_theme.font_faces[style], font_size, r}
		if g, ok := g_glyphs[key]; ok {return g}
		f := snap_font(style)
		g: Glyph
		if f.loaded {
			scale := stbtt.ScaleForPixelHeight(&f.info, f32(font_size))
			bmp := stbtt.GetCodepointBitmap(&f.info, scale, scale, r, &g.w, &g.h, &g.x, &g.y)
			if bmp != nil {
				g.alpha = make([]u8, g.w * g.h)
				copy(g.alpha, bmp[:g.w * g.h])
				stbtt.FreeBitmap(bmp, nil)
			}
		}
		g_glyphs[key] = g
		return g
	}

	// -------------------------------------------------------------------------
	// Software renderer
	// -------------------------------------------------------------------------

	@(private)
	Canvas :: struct {
		w, h:  int,
		px:    [][3]f32,
		clips: [dynamic][4]f32, // x0, y0, x1, y1
	}

	@(private)
	snap_render :: proc(commands: ^clay.ClayArray(clay.RenderCommand), w, h: int, path: string) {
		cv := Canvas {
			w     = w,
			h     = h,
			px    = make([][3]f32, w * h, context.temp_allocator),
			clips = make([dynamic][4]f32, context.temp_allocator),
		}
		bg := g_theme.window
		for &p in cv.px {p = bg.rgb}

		for i in 0 ..< commands.length {
			cmd := clay.RenderCommandArray_Get(commands, i)
			b := cmd.boundingBox
			switch cmd.commandType {
			case .None, .Custom, .OverlayColorStart, .OverlayColorEnd:
			case .Rectangle:
				d := cmd.renderData.rectangle
				snap_fill(&cv, b, d.cornerRadius, d.backgroundColor, 0)
			case .Border:
				d := cmd.renderData.border
				wd := d.width
				if wd.left == wd.right && wd.left == wd.top && wd.left == wd.bottom {
					snap_fill(&cv, b, d.cornerRadius, d.color, f32(wd.left))
				} else {
					snap_fill(&cv, {b.x, b.y, f32(wd.left), b.height}, {}, d.color, 0)
					snap_fill(&cv, {b.x + b.width - f32(wd.right), b.y, f32(wd.right), b.height}, {}, d.color, 0)
					snap_fill(&cv, {b.x, b.y, b.width, f32(wd.top)}, {}, d.color, 0)
					snap_fill(&cv, {b.x, b.y + b.height - f32(wd.bottom), b.width, f32(wd.bottom)}, {}, d.color, 0)
				}
			case .Text:
				d := cmd.renderData.text
				snap_text(&cv, string(d.stringContents.chars[:d.stringContents.length]), b, d)
			case .Image:
				snap_image(&cv, (^SnapImage)(cmd.renderData.image.imageData), b)
			case .ScissorStart:
				r := [4]f32{b.x, b.y, b.x + b.width, b.y + b.height}
				if len(cv.clips) > 0 {
					t := cv.clips[len(cv.clips) - 1]
					r = {max(r[0], t[0]), max(r[1], t[1]), min(r[2], t[2]), min(r[3], t[3])}
				}
				append(&cv.clips, r)
			case .ScissorEnd:
				if len(cv.clips) > 0 {pop(&cv.clips)}
			}
		}

		out := make([]u8, w * h * 4, context.temp_allocator)
		for p, i in cv.px {
			out[i * 4 + 0] = u8(clamp(p.r, 0, 255))
			out[i * 4 + 1] = u8(clamp(p.g, 0, 255))
			out[i * 4 + 2] = u8(clamp(p.b, 0, 255))
			out[i * 4 + 3] = 255
		}
		stbi.write_png(strings.clone_to_cstring(path, context.temp_allocator), i32(w), i32(h), 4, raw_data(out), i32(w * 4))
	}

	// The pixel range covered by a box, limited to the window and the clip rectangle.
	@(private)
	snap_span :: proc(cv: ^Canvas, x0, y0, x1, y1: f32) -> (ix0, iy0, ix1, iy1: int) {
		lx0, ly0, lx1, ly1 := x0, y0, x1, y1
		if len(cv.clips) > 0 {
			c := cv.clips[len(cv.clips) - 1]
			lx0, ly0, lx1, ly1 = max(lx0, c[0]), max(ly0, c[1]), min(lx1, c[2]), min(ly1, c[3])
		}
		ix0 = max(0, int(math.floor(lx0)))
		iy0 = max(0, int(math.floor(ly0)))
		ix1 = min(cv.w, int(math.ceil(lx1)))
		iy1 = min(cv.h, int(math.ceil(ly1)))
		return
	}

	@(private)
	snap_blend :: proc(cv: ^Canvas, x, y: int, c: Color, coverage: f32) {
		a := coverage * c.a / 255
		if a <= 0 {return}
		p := &cv.px[y * cv.w + x]
		p^ = p^ + (c.rgb - p^) * a
	}

	// Signed distance from a point to a rounded rectangle with a radius per corner.
	@(private)
	snap_sdf :: proc(px, py: f32, b: clay.BoundingBox, r: clay.CornerRadius) -> f32 {
		cx, cy := b.x + b.width / 2, b.y + b.height / 2
		hw, hh := b.width / 2, b.height / 2
		rad := px < cx ? (py < cy ? r.topLeft : r.bottomLeft) : (py < cy ? r.topRight : r.bottomRight)
		rad = min(rad, min(hw, hh))
		qx := abs(px - cx) - hw + rad
		qy := abs(py - cy) - hh + rad
		outside := math.sqrt(max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0))
		return outside + min(max(qx, qy), 0) - rad
	}

	// Fills a rounded rectangle, or with `ring > 0` only its outer ring of that width.
	@(private)
	snap_fill :: proc(cv: ^Canvas, b: clay.BoundingBox, r: clay.CornerRadius, c: Color, ring: f32) {
		if c.a <= 0 || b.width <= 0 || b.height <= 0 {return}
		x0, y0, x1, y1 := snap_span(cv, b.x, b.y, b.x + b.width, b.y + b.height)
		inner := clay.BoundingBox{b.x + ring, b.y + ring, b.width - 2 * ring, b.height - 2 * ring}
		ir := clay.CornerRadius {
			max(r.topLeft - ring, 0),
			max(r.topRight - ring, 0),
			max(r.bottomLeft - ring, 0),
			max(r.bottomRight - ring, 0),
		}
		for y in y0 ..< y1 {
			for x in x0 ..< x1 {
				px, py := f32(x) + 0.5, f32(y) + 0.5
				cov := clamp(0.5 - snap_sdf(px, py, b, r), 0, 1)
				if ring > 0 && cov > 0 {
					cov *= 1 - clamp(0.5 - snap_sdf(px, py, inner, ir), 0, 1)
				}
				snap_blend(cv, x, y, c, cov)
			}
		}
	}

	@(private)
	snap_text :: proc(cv: ^Canvas, s: string, b: clay.BoundingBox, d: clay.TextRenderData) {
		style := TextStyle(d.fontId)
		f := snap_font(style)
		if !f.loaded {return}
		scale := stbtt.ScaleForPixelHeight(&f.info, f32(d.fontSize))
		baseline := math.round(b.y + f.ascent * scale)
		pen := b.x
		for r in s {
			g := snap_glyph(style, d.fontSize, r)
			gx, gy := int(math.round(pen)) + int(g.x), int(baseline) + int(g.y)
			x0, y0, x1, y1 := snap_span(cv, f32(gx), f32(gy), f32(gx + int(g.w)), f32(gy + int(g.h)))
			for y in y0 ..< y1 {
				for x in x0 ..< x1 {
					a := g.alpha[(y - gy) * int(g.w) + (x - gx)]
					snap_blend(cv, x, y, d.textColor, f32(a) / 255)
				}
			}
			adv, lsb: i32
			stbtt.GetCodepointHMetrics(&f.info, r, &adv, &lsb)
			pen += f32(adv) * scale + f32(d.letterSpacing)
		}
	}

	@(private)
	snap_image :: proc(cv: ^Canvas, img: ^SnapImage, b: clay.BoundingBox) {
		if img == nil || img.width == 0 {return}
		x0, y0, x1, y1 := snap_span(cv, b.x, b.y, b.x + b.width, b.y + b.height)
		for y in y0 ..< y1 {
			for x in x0 ..< x1 {
				u := clamp(int((f32(x) + 0.5 - b.x) / b.width * f32(img.width)), 0, img.width - 1)
				v := clamp(int((f32(y) + 0.5 - b.y) / b.height * f32(img.height)), 0, img.height - 1)
				p := img.pixels[v * img.width + u]
				snap_blend(cv, x, y, {f32(p.r), f32(p.g), f32(p.b), f32(p.a)}, 1)
			}
		}
	}
}

// Uses the imports in window builds too, where the code above is not compiled (for -vet).
@(private = "file")
keep_imports :: proc() {
	_, _, _, _ = fmt.println, math.round_f32, os.make_directory_all, strings.clone
	_, _, _ = clay.ID, stbi.write_png, stbtt.InitFont
}
