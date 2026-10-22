package app

// Application loop in the style of The Elm Architecture: the app owns a `Model`, the view
// only reads it and emits messages, `update` is the only place that changes it.

import "base:runtime"
import "core:c"
import "core:fmt"
import clay "lib:kiln/clay-odin"
import "lib:kiln/render"
import th "lib:kiln/theme"
import rl "vendor:raylib"

App :: struct($Model, $Msg: typeid) {
	init:   proc() -> Model,
	update: proc(m: ^Model, msg: Msg),
	view:   proc(m: ^Model, out: ^[dynamic]Msg),
	tick:   proc(m: ^Model, dt: f32), // optional, called once per frame before the view
}

// Window and look of the app. Zero values select the defaults.
Config :: struct {
	title:  cstring, // default "App"
	width:  i32, // default 1024
	height: i32, // default 768
	theme:  Maybe(th.Theme), // default: Catppuccin Mocha with the default metrics
	scale:  th.Scale, // zoom / DPI / fit-to-height behaviour
}

@(private)
g_quit: bool

// Closes the window at the end of the current frame.
quit :: proc() {
	g_quit = true
}

// Duration of the last frame in seconds.
dt :: proc() -> f32 {
	return rl.GetFrameTime()
}

// Runs the view of a sub-model and forwards its messages, converted to the parent's message type:
//
//   kiln.embed(out, &m.counter, counter.view)
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

// Opens the window and runs the app until the window is closed or `quit` is called.
//
//   kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, {title = "Meine App"})
run :: proc(a: App($Model, $Msg), config := Config{}) {
	cfg := config
	if cfg.title == nil {cfg.title = "App"}
	if cfg.width <= 0 {cfg.width = 1024}
	if cfg.height <= 0 {cfg.height = 768}

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(cfg.width, cfg.height, cfg.title)
	defer rl.CloseWindow()
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))

	mem_size := c.size_t(clay.MinMemorySize())
	arena := clay.CreateArenaWithCapacityAndMemory(mem_size, make([^]u8, mem_size))
	clay.Initialize(
		arena,
		{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
		{handler = on_clay_error},
	)
	clay.SetMeasureTextFunction(render.measure_text, nil)

	th.set_theme(cfg.theme.? or_else th.catppuccin(.Mocha))
	th.set_scale(cfg.scale)
	defer render.unload_fonts()

	model := a.init()

	for !rl.WindowShouldClose() && !g_quit {
		defer free_all(context.temp_allocator)
		frame := rl.GetFrameTime()

		when ODIN_DEBUG {
			if rl.IsKeyPressed(.F12) {
				clay.SetDebugModeEnabled(!clay.IsDebugModeEnabled())
			}
		}

		screen := clay.Dimensions{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		clay.SetPointerState(rl.GetMousePosition(), rl.IsMouseButtonDown(.LEFT))
		clay.UpdateScrollContainers(false, rl.GetMouseWheelMoveV(), frame)
		clay.SetLayoutDimensions(screen)

		th.update_scale(rl.GetWindowScaleDPI().x, screen.height)
		render.sync_fonts()

		if a.tick != nil {a.tick(&model, frame)}

		bg := th.current().bg
		msgs := make([dynamic]Msg, context.temp_allocator)
		clay.BeginLayout()
		if clay.UI(clay.ID("AppRoot"))(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				padding = th.pad_all(.LG),
			},
			backgroundColor = bg,
		},
		) {
			a.view(&model, &msgs)
		}
		commands := clay.EndLayout(frame)

		rl.BeginDrawing()
		rl.ClearBackground({u8(bg.r), u8(bg.g), u8(bg.b), 255})
		render.draw(&commands)
		rl.EndDrawing()

		for msg in msgs {
			a.update(&model, msg)
		}
	}
}
