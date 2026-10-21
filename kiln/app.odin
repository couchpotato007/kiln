package kiln

import "base:runtime"
import "core:c"
import "core:fmt"
import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

App :: struct($Model, $Msg: typeid) {
	init:   proc() -> Model,
	update: proc(m: ^Model, msg: Msg),
	view:   proc(m: ^Model, out: ^[dynamic]Msg),
	tick:   proc(m: ^Model, dt: f32),
}

@(private)
g_quit: bool

quit :: proc() {
	g_quit = true
}

dt :: proc() -> f32 {
	return rl.GetFrameTime()
}

embed :: proc(out: ^[dynamic]$To, model: ^$M, view: proc(m: ^M, out: ^[dynamic]$From)) {
	sub := make([dynamic]From, context.temp_allocator)
	view(model, &sub)
	for msg in sub {
		append(out, To(msg))
	}
}

@(private)
on_clay_error :: proc "c" (e: clay.ErrorData) {
	context = runtime.default_context()
	fmt.eprintln("clay:", e.errorType, string(e.errorText.chars[:e.errorText.length]))
}

// Opens the window and runs the app. The look comes from `theme` if given, otherwise from
// the Catppuccin `flavor` with the default metrics. It can be changed at any time with
// `set_theme` / `set_flavor`.
run :: proc(
	a: App($Model, $Msg),
	title: cstring = "App",
	width: i32 = 1024,
	height: i32 = 768,
	flavor := Flavor.Mocha,
	fonts := ThemeFonts {
		regular = "resources/Iosevka-Regular.ttf",
		bold = "resources/Iosevka-SemiBold.ttf",
	},
	theme: Maybe(Theme) = nil,
) {
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(width, height, title)
	defer rl.CloseWindow()
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))

	mem_size := c.size_t(clay.MinMemorySize())
	arena := clay.CreateArenaWithCapacityAndMemory(mem_size, make([^]u8, mem_size))
	clay.Initialize(
		arena,
		{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
		{handler = on_clay_error},
	)
	clay.SetMeasureTextFunction(measure_text, nil)
	init_theme(flavor, fonts)
	if t, ok := theme.?; ok {set_theme(t)}

	model := a.init()
	debug := false

	for !rl.WindowShouldClose() && !g_quit {
		defer free_all(context.temp_allocator)
		frame := rl.GetFrameTime()

		when ODIN_DEBUG {
			if rl.IsKeyPressed(.F12) {
				debug = !debug
				clay.SetDebugModeEnabled(debug)
			}
		}

		clay.SetPointerState(
			transmute(clay.Vector2)rl.GetMousePosition(),
			rl.IsMouseButtonDown(.LEFT),
		)
		clay.UpdateScrollContainers(false, transmute(clay.Vector2)rl.GetMouseWheelMoveV(), frame)
		clay.SetLayoutDimensions({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())})
		begin_frame()

		if a.tick != nil {a.tick(&model, frame)}

		msgs := make([dynamic]Msg, context.temp_allocator)
		clay.BeginLayout()
		if clay.UI(clay.ID("AppRoot"))(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingGrow()}, padding = pad_all(.LG)},
			backgroundColor = current_theme.bg,
		},
		) {
			a.view(&model, &msgs)
		}
		cmds := clay.EndLayout(frame)

		rl.BeginDrawing()
		clay_raylib_render(&cmds)
		rl.EndDrawing()

		for msg in msgs {
			a.update(&model, msg)
		}
	}
}
