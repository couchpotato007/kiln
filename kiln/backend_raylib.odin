package kiln

// The raylib backend: window, input, fonts, text measurement, images and the renderer for
// Clay's render commands. Not compiled into snapshot builds.

import "core:math"
import "core:strings"
import clay "clay-odin"
import rl "vendor:raylib"

when !KILN_SNAPSHOT {

	// Opens the window and runs the app until the window is closed or `quit` is called.
	//
	//   kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, {title = "Meine App"})
	run :: proc(a: App($Model, $Msg), config := Config{}) {
		cfg := app_init(config)

		rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
		rl.InitWindow(cfg.width, cfg.height, cfg.title)
		defer rl.CloseWindow()
		rl.SetWindowMinSize(cfg.min_width, cfg.min_height)
		rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
		rl.SetExitKey(.KEY_NULL) // Escape closes popups and dialogs, not the app
		defer rl_unload_fonts()

		model := a.init()
		for !rl.WindowShouldClose() && !g_quit {
			defer free_all(context.temp_allocator)
			commands, msgs := app_frame(a, &model, rl_poll_input(), cfg)

			rl.BeginDrawing()
			rl.ClearBackground(rl_color(g_theme.window))
			rl_draw(&commands)
			rl.EndDrawing()

			app_update(a, &model, msgs)
		}
	}

	// Creates an image from RGBA pixels (row by row, top to bottom).
	create_image :: proc(width, height: int, pixels: []Pixel) -> Image {
		img := rl.Image {
			data    = raw_data(pixels),
			width   = i32(width),
			height  = i32(height),
			mipmaps = 1,
			format  = .UNCOMPRESSED_R8G8B8A8,
		}
		tex := new(rl.Texture2D)
		tex^ = rl.LoadTextureFromImage(img)
		rl.SetTextureFilter(tex^, .BILINEAR)
		return {tex, width, height}
	}

	// Loads an image file (PNG, JPG, ...).
	load_image :: proc(path: string) -> (Image, bool) {
		t := rl.LoadTexture(strings.clone_to_cstring(path, context.temp_allocator))
		if t.id == 0 {return {}, false}
		rl.SetTextureFilter(t, .BILINEAR)
		tex := new(rl.Texture2D)
		tex^ = t
		return {tex, int(t.width), int(t.height)}, true
	}

	destroy_image :: proc(img: ^Image) {
		if img.handle == nil {return}
		tex := (^rl.Texture2D)(img.handle)
		rl.UnloadTexture(tex^)
		free(tex)
		img^ = {}
	}

	// -------------------------------------------------------------------------
	// Input
	// -------------------------------------------------------------------------

	@(private)
	RL_KEYS := [Key]rl.KeyboardKey {
		.Left      = .LEFT,
		.Right     = .RIGHT,
		.Up        = .UP,
		.Down      = .DOWN,
		.Home      = .HOME,
		.End       = .END,
		.Page_Up   = .PAGE_UP,
		.Page_Down = .PAGE_DOWN,
		.Backspace = .BACKSPACE,
		.Delete    = .DELETE,
		.Enter     = .ENTER,
		.Escape    = .ESCAPE,
		.Tab       = .TAB,
		.A         = .A,
		.C         = .C,
		.V         = .V,
		.X         = .X,
		.Equal     = .EQUAL,
		.Minus     = .MINUS,
		.Zero      = .ZERO,
	}

	// Pixels scrolled per wheel step and unit of UI scale.
	@(private)
	RL_WHEEL_PIXELS :: 40

	@(private)
	rl_poll_input :: proc() -> (in_: Input) {
		hit :: proc(k: rl.KeyboardKey) -> bool {return rl.IsKeyPressed(k) || rl.IsKeyPressedRepeat(k)}
		for k in Key {
			if hit(RL_KEYS[k]) {in_.keys += {k}}
		}
		if hit(.KP_ENTER) {in_.keys += {.Enter}}
		if hit(.KP_ADD) {in_.keys += {.Equal}}
		if hit(.KP_SUBTRACT) {in_.keys += {.Minus}}

		chars := make([dynamic]rune, context.temp_allocator)
		for r := rl.GetCharPressed(); r != 0; r = rl.GetCharPressed() {append(&chars, r)}
		in_.chars = chars[:]

		in_.shift = rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
		altgr := rl.IsKeyDown(.RIGHT_ALT)
		in_.ctrl =
			!altgr &&
			(rl.IsKeyDown(.LEFT_CONTROL) ||
					rl.IsKeyDown(.RIGHT_CONTROL) ||
					rl.IsKeyDown(.LEFT_SUPER) ||
					rl.IsKeyDown(.RIGHT_SUPER))

		buttons := [MouseButton]rl.MouseButton {
			.Left  = .LEFT,
			.Right = .RIGHT,
		}
		for b in MouseButton {
			if rl.IsMouseButtonDown(buttons[b]) {in_.down += {b}}
			if rl.IsMouseButtonPressed(buttons[b]) {in_.pressed += {b}}
			if rl.IsMouseButtonReleased(buttons[b]) {in_.released += {b}}
		}
		in_.mouse = rl.GetMousePosition()
		in_.wheel = rl.GetMouseWheelMoveV() * RL_WHEEL_PIXELS * g_scale_factor

		in_.dt = rl.GetFrameTime()
		in_.time = rl.GetTime()
		in_.window = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		in_.dpi = rl.GetWindowScaleDPI().x
		return
	}

	@(private)
	backend_get_clipboard :: proc() -> string {
		clip := rl.GetClipboardText()
		if clip == nil {return ""}
		return strings.clone(string(clip), context.temp_allocator)
	}

	@(private)
	backend_set_clipboard :: proc(s: string) {
		rl.SetClipboardText(strings.clone_to_cstring(s, context.temp_allocator))
	}

	// -------------------------------------------------------------------------
	// Fonts
	// -------------------------------------------------------------------------

	// Fonts are rasterized at this multiple of their size for sharper text.
	@(private)
	RL_OVERSAMPLE :: 2

	@(private)
	rl_fonts: [TextStyle]rl.Font

	// Everything the loaded fonts depend on; if it changes, they are reloaded.
	@(private)
	RlFontState :: struct {
		sizes: [TextStyle]u16,
		faces: [TextStyle]FontFace,
		files: [FontFace]cstring,
		data:  [FontFace]rawptr,
	}

	@(private)
	rl_loaded: RlFontState
	@(private)
	rl_has_fonts: bool

	@(private)
	backend_sync_fonts :: proc() {
		want := RlFontState {
			faces = g_theme.font_faces,
			files = g_theme.font_files,
		}
		for face in FontFace {want.data[face] = raw_data(g_theme.font_data[face])}
		for s in TextStyle {want.sizes[s] = font_size(s)}
		if rl_has_fonts && want == rl_loaded {return}

		rl_unload_fonts()
		cps := codepoints()
		for s in TextStyle {
			face := want.faces[s]
			px_size := i32(want.sizes[s]) * RL_OVERSAMPLE
			f: rl.Font
			if data := g_theme.font_data[face]; len(data) > 0 {
				f = rl.LoadFontFromMemory(".ttf", raw_data(data), i32(len(data)), px_size, raw_data(cps), i32(len(cps)))
			} else {
				f = rl.LoadFontEx(want.files[face], px_size, raw_data(cps), i32(len(cps)))
			}
			rl.SetTextureFilter(f.texture, .BILINEAR)
			rl_fonts[s] = f
		}
		rl_loaded = want
		rl_has_fonts = true
		clay.ResetMeasureTextCache()
	}

	@(private)
	rl_unload_fonts :: proc() {
		if !rl_has_fonts {return}
		for s in TextStyle {rl.UnloadFont(rl_fonts[s])}
		rl_has_fonts = false
	}

	@(private)
	backend_measure :: proc(text: string, style: TextStyle, font_size: u16) -> [2]f32 {
		f := rl_fonts[style]
		if f.glyphs == nil {return {0, f32(font_size)}}
		w: f32 = 0
		for r in text {
			gi := rl.GetGlyphIndex(f, r)
			g := f.glyphs[gi]
			w += g.advanceX != 0 ? f32(g.advanceX) : f.recs[gi].width + f32(g.offsetX)
		}
		return {w * f32(font_size) / f32(f.baseSize), f32(font_size)}
	}

	// -------------------------------------------------------------------------
	// Renderer
	// -------------------------------------------------------------------------

	@(private)
	rl_color :: proc(c: Color) -> rl.Color {
		return {u8(c.r), u8(c.g), u8(c.b), u8(c.a)}
	}

	@(private)
	rl_draw :: proc(commands: ^clay.ClayArray(clay.RenderCommand)) {
		tints := make([dynamic]Color, context.temp_allocator)
		scissors := make([dynamic]rl.Rectangle, context.temp_allocator)

		for i in 0 ..< commands.length {
			cmd := clay.RenderCommandArray_Get(commands, i)
			b := cmd.boundingBox

			switch cmd.commandType {
			case .None, .Custom:
			case .Text:
				d := cmd.renderData.text
				s := string(d.stringContents.chars[:d.stringContents.length])
				rl.DrawTextEx(
					rl_fonts[TextStyle(d.fontId)],
					strings.clone_to_cstring(s, context.temp_allocator),
					{math.round(b.x), math.round(b.y)},
					f32(d.fontSize),
					f32(d.letterSpacing),
					rl_color(d.textColor),
				)
			case .Image:
				// Clay passes the element's background color as tint; none means untinted.
				tint := cmd.renderData.image.backgroundColor
				if tint == {} {tint = len(tints) > 0 ? tints[len(tints) - 1] : Color{255, 255, 255, 255}}
				tex := (^rl.Texture2D)(cmd.renderData.image.imageData)
				rl.DrawTexturePro(
					tex^,
					{0, 0, f32(tex.width), f32(tex.height)},
					{b.x, b.y, b.width, b.height},
					{},
					0,
					rl_color(tint),
				)
			case .ScissorStart:
				r := rl.Rectangle{b.x, b.y, b.width, b.height}
				if len(scissors) > 0 {r = rl_intersect(r, scissors[len(scissors) - 1])}
				append(&scissors, r)
				rl_scissor(r)
			case .ScissorEnd:
				if len(scissors) > 0 {pop(&scissors)}
				if len(scissors) > 0 {
					rl_scissor(scissors[len(scissors) - 1])
				} else {
					rl.EndScissorMode()
				}
			case .Rectangle:
				d := cmd.renderData.rectangle
				rl_rect_rounded(b, d.cornerRadius, rl_color(d.backgroundColor))
			case .Border:
				rl_border(b, cmd.renderData.border)
			case .OverlayColorStart:
				append(&tints, cmd.renderData.overlayColor.color)
			case .OverlayColorEnd:
				if len(tints) > 0 {pop(&tints)}
			}
		}
	}

	@(private)
	rl_intersect :: proc(a, b: rl.Rectangle) -> rl.Rectangle {
		x0, y0 := max(a.x, b.x), max(a.y, b.y)
		x1, y1 := min(a.x + a.width, b.x + b.width), min(a.y + a.height, b.y + b.height)
		return {x0, y0, max(0, x1 - x0), max(0, y1 - y0)}
	}

	@(private)
	rl_scissor :: proc(r: rl.Rectangle) {
		rl.BeginScissorMode(
			i32(math.round(r.x)),
			i32(math.round(r.y)),
			i32(math.round(r.width)),
			i32(math.round(r.height)),
		)
	}

	@(private)
	rl_rect :: proc(x, y, w, h: f32, color: rl.Color) {
		if w <= 0 || h <= 0 {return}
		rl.DrawRectangleRec({x, y, w, h}, color)
	}

	// A rectangle with its own radius per corner: corner sectors plus the rectangles between.
	@(private)
	rl_rect_rounded :: proc(b: clay.BoundingBox, cr: clay.CornerRadius, color: rl.Color) {
		half := min(b.width, b.height) / 2
		tl, tr := min(cr.topLeft, half), min(cr.topRight, half)
		bl, br := min(cr.bottomLeft, half), min(cr.bottomRight, half)
		x, y, w, h := b.x, b.y, b.width, b.height

		if tl == 0 && tr == 0 && bl == 0 && br == 0 {
			rl_rect(x, y, w, h, color)
			return
		}
		if tl == tr && tl == bl && tl == br {
			rl.DrawRectangleRounded({x, y, w, h}, tl / half, 12, color)
			return
		}

		l, r := max(tl, bl), max(tr, br)
		rl_rect(x + l, y, w - l - r, h, color) // middle band
		rl_rect(x, y + tl, l, h - tl - bl, color) // left band
		rl_rect(x + tl, y, l - tl, tl, color)
		rl_rect(x + bl, y + h - bl, l - bl, bl, color)
		rl_rect(x + w - r, y + tr, r, h - tr - br, color) // right band
		rl_rect(x + w - r, y, r - tr, tr, color)
		rl_rect(x + w - r, y + h - br, r - br, br, color)

		if tl > 0 {rl.DrawCircleSector({x + tl, y + tl}, tl, 180, 270, 12, color)}
		if tr > 0 {rl.DrawCircleSector({x + w - tr, y + tr}, tr, 270, 360, 12, color)}
		if br > 0 {rl.DrawCircleSector({x + w - br, y + h - br}, br, 0, 90, 12, color)}
		if bl > 0 {rl.DrawCircleSector({x + bl, y + h - bl}, bl, 90, 180, 12, color)}
	}

	@(private)
	rl_border :: proc(b: clay.BoundingBox, d: clay.BorderRenderData) {
		r, w := d.cornerRadius, d.width
		col := rl_color(d.color)
		half := min(b.width, b.height) / 2
		tl, tr := min(r.topLeft, half), min(r.topRight, half)
		bl, br := min(r.bottomLeft, half), min(r.bottomRight, half)

		if w.left > 0 {rl_rect(b.x, b.y + tl, f32(w.left), b.height - tl - bl, col)}
		if w.right > 0 {
			rl_rect(b.x + b.width - f32(w.right), b.y + tr, f32(w.right), b.height - tr - br, col)
		}
		if w.top > 0 {rl_rect(b.x + tl, b.y, b.width - tl - tr, f32(w.top), col)}
		if w.bottom > 0 {
			rl_rect(b.x + bl, b.y + b.height - f32(w.bottom), b.width - bl - br, f32(w.bottom), col)
		}

		ring :: proc(x, y, outer, width, from, to: f32, color: rl.Color) {
			rl.DrawRing({x, y}, max(0, outer - width), outer, from, to, 12, color)
		}
		if tl > 0 {ring(b.x + tl, b.y + tl, tl, f32(w.top), 180, 270, col)}
		if tr > 0 {ring(b.x + b.width - tr, b.y + tr, tr, f32(w.top), 270, 360, col)}
		if bl > 0 {ring(b.x + bl, b.y + b.height - bl, bl, f32(w.bottom), 90, 180, col)}
		if br > 0 {ring(b.x + b.width - br, b.y + b.height - br, br, f32(w.bottom), 0, 90, col)}
	}
}

// Codepoints baked into the fonts: Latin, punctuation, arrows, geometric shapes and a few
// symbols that work as icons (▸ ▾ ✓ ✕ ☰ ⚙ ★ …).
@(private)
g_codepoints: [dynamic]rune

@(private)
codepoints :: proc() -> []rune {
	if len(g_codepoints) > 0 {return g_codepoints[:]}
	ranges := [?][2]rune {
		{0x20, 0x7E}, // ASCII
		{0xA0, 0x17F}, // Latin-1, Latin Extended-A
		{0x2010, 0x205E}, // general punctuation
		{0x20AC, 0x20AC}, // €
		{0x2190, 0x21FF}, // arrows
		{0x2212, 0x2212}, // minus
		{0x22EF, 0x22EF}, // ⋯
		{0x2302, 0x2302}, // ⌂
		{0x25A0, 0x25FF}, // geometric shapes
		{0x2600, 0x2609}, // ☀ ★ ☆ …
		{0x2630, 0x2630}, // ☰
		{0x2699, 0x2699}, // ⚙
		{0x2713, 0x2718}, // ✓ ✔ ✕ ✖ ✗ ✘
	}
	for rg in ranges {
		for r in rg[0] ..= rg[1] {append(&g_codepoints, r)}
	}
	return g_codepoints[:]
}


// Uses the imports in snapshot builds too, where the code above is not compiled (for -vet).
// Never called, so raylib is not linked into snapshot builds.
@(private = "file")
keep_imports :: proc() {
	_, _, _, _ = math.round_f32, strings.clone, clay.ID, rl.InitWindow
}
