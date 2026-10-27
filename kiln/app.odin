package kiln

// The application loop in the style of The Elm Architecture: the app owns a `Model`, the view
// only reads it and emits messages, `update` is the only place that changes it.
//
//   kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, {title = "Meine App"})
//
// The loop itself (`run`) lives in the backend files; this file has everything they share.

import "base:runtime"
import "core:c"
import "core:fmt"
import clay "clay-odin"

// Build with `-define:KILN_SNAPSHOT=true` to render PNG snapshots instead of opening a window.
KILN_SNAPSHOT :: #config(KILN_SNAPSHOT, false)

App :: struct($Model, $Msg: typeid) {
	init:   proc() -> Model,
	update: proc(m: ^Model, msg: Msg),
	view:   proc(m: ^Model, out: ^[dynamic]Msg),
	tick:   proc(m: ^Model, dt: f32), // optional, called once per frame before the view
}

// Window and look of the app. Zero values select the defaults.
Config :: struct {
	title:        cstring, // default "App"
	width:        i32, // default 1100
	height:       i32, // default 760
	min_width:    i32, // default 320
	min_height:   i32, // default 420
	theme:        Maybe(Theme), // default: Catppuccin Mocha
	scale:        Scale,
	no_zoom_keys: bool, // disable Ctrl +/-/0

	// Only used by snapshot builds (`-define:KILN_SNAPSHOT=true`):
	snapshot_setup:   proc(model: rawptr), // called after `init` (the model as ^Model), e.g. to load test data
	snapshot_open:    []string, // dialogs / drawers to show; each gets its own extra image per size
	snapshot_pointer: [2]f32, // pointer position in units, to capture a hover or tooltip (zero = outside)
	snapshot_clicks:  [][2]f32, // left clicks in units before rendering, e.g. to open a popup
}

// Runs the view of a sub-model and forwards its messages, converted to the parent's message type:
//
//   kiln.embed(out, &m.todo, todo.view)
embed :: proc(out: ^[dynamic]$To, model: ^$M, view: proc(m: ^M, out: ^[dynamic]$From)) {
	sub := make([dynamic]From, context.temp_allocator)
	view(model, &sub)
	for msg in sub {
		append(out, To(msg))
	}
}

// Closes the window at the end of the current frame.
quit :: proc() {
	g_quit = true
}

// Duration of the last frame in seconds.
frame_time :: proc() -> f32 {
	return g_in.dt
}

// Seconds since the app started.
now :: proc() -> f64 {
	return g_in.time
}

// Puts text on the system clipboard.
copy_to_clipboard :: proc(s: string) {
	backend_set_clipboard(s)
}

// The text on the system clipboard, valid until the end of the frame.
clipboard :: proc() -> string {
	return backend_get_clipboard()
}

// True if `key` was pressed (or auto-repeated) in this frame and no text field has the focus.
key_pressed :: proc(key: Key) -> bool {
	return g_focus == 0 && key in g_in.keys
}

// ---------------------------------------------------------------------------
// Input, filled by the backend once per frame
// ---------------------------------------------------------------------------

MouseButton :: enum {
	Left,
	Right,
}

Key :: enum {
	Left,
	Right,
	Up,
	Down,
	Home,
	End,
	Page_Up,
	Page_Down,
	Backspace,
	Delete,
	Enter,
	Escape,
	Tab,
	A,
	C,
	V,
	X,
	Equal,
	Minus,
	Zero,
}

@(private)
Input :: struct {
	mouse:                   [2]f32,
	wheel:                   [2]f32, // pixels to scroll
	down, pressed, released: bit_set[MouseButton],
	keys:                    bit_set[Key], // pressed or repeated in this frame
	shift, ctrl:             bool,
	chars:                   []rune, // typed text
	dt:                      f32,
	time:                    f64,
	window:                  [2]f32, // pixels
	dpi:                     f32,
}

@(private)
g_in: Input
@(private)
g_quit: bool

// ---------------------------------------------------------------------------
// Shared frame logic
// ---------------------------------------------------------------------------

@(private)
app_init :: proc(config: Config) -> Config {
	cfg := config
	if cfg.title == nil {cfg.title = "App"}
	if cfg.width <= 0 {cfg.width = 1100}
	if cfg.height <= 0 {cfg.height = 760}
	if cfg.min_width <= 0 {cfg.min_width = 320}
	if cfg.min_height <= 0 {cfg.min_height = 420}

	clay.SetMaxElementCount(32768)
	mem_size := c.size_t(clay.MinMemorySize())
	arena := clay.CreateArenaWithCapacityAndMemory(mem_size, make([^]u8, mem_size))
	clay.Initialize(arena, {f32(cfg.width), f32(cfg.height)}, {handler = on_clay_error})
	clay.SetMeasureTextFunction(measure_text_callback, nil)

	set_theme(cfg.theme.? or_else catppuccin(.Mocha))
	set_scale(cfg.scale)
	return cfg
}

// Builds the layout of one frame. The backend draws the commands and then applies the messages
// with `app_update` (in this order: the commands may point at strings the update frees).
@(private)
app_frame :: proc(
	a: App($Model, $Msg),
	model: ^Model,
	input: Input,
	cfg: Config,
) -> (
	clay.ClayArray(clay.RenderCommand),
	[dynamic]Msg,
) {
	frame_begin(input, cfg)
	backend_sync_fonts()

	msgs := make([dynamic]Msg, context.temp_allocator)
	tasks_drain(&msgs)

	if a.tick != nil {a.tick(model, input.dt)}

	clay.BeginLayout()
	if clay.UI(clay.ID("kiln-root"))(
	{
		layout = {sizing = {clay.SizingGrow(), clay.SizingGrow()}, layoutDirection = .TopToBottom},
		backgroundColor = g_theme.window,
	},
	) {
		a.view(model, &msgs)
		toasts_view()
	}
	commands := clay.EndLayout(input.dt)
	frame_end()
	return commands, msgs
}

@(private)
app_update :: proc(a: App($Model, $Msg), model: ^Model, msgs: [dynamic]Msg) {
	for msg in msgs {
		a.update(model, msg)
	}
}

@(private)
frame_begin :: proc(input: Input, cfg: Config) {
	g_in = input
	g_frame += 1

	if !cfg.no_zoom_keys && g_in.ctrl {
		if .Equal in g_in.keys {set_zoom(zoom() + 0.1)}
		if .Minus in g_in.keys {set_zoom(zoom() - 0.1)}
		if .Zero in g_in.keys {set_zoom(1)}
	}
	update_scale()

	clay.SetLayoutDimensions({g_in.window.x, g_in.window.y})
	clay.SetPointerState(g_in.mouse, .Left in g_in.down)
	clay.UpdateScrollContainers(false, {}, g_in.dt) // the wheel is routed by `wheel_scroll`
	wheel_scroll()

	ids_begin()
	interaction_begin()
	clear(&g_boxes)
	g_last = {}
}

@(private)
frame_end :: proc() {
	focus_end()
	interaction_end()
	if g_frame % 256 == 0 {collect_garbage()}
}

@(private)
measure_text_callback :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()
	d := backend_measure(string(text.chars[:text.length]), TextStyle(config.fontId), config.fontSize)
	return {d.x, d.y}
}

// Clay reports some errors (e.g. duplicate ids) every frame; print each one only once.
@(private)
g_reported: map[string]bool

@(private)
on_clay_error :: proc "c" (e: clay.ErrorData) {
	context = runtime.default_context()
	msg := string(e.errorText.chars[:e.errorText.length])
	if g_reported[msg] {return}
	g_reported[msg] = true
	fmt.eprintln("clay:", e.errorType, msg)
}
