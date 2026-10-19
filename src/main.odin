package main


import "core:c"
import "core:fmt"
import "core:strconv"
import clay "lib:clay-odin"
import "lib:renderer"
import "lib:theme"
import "lib:widgets"
import "vendor:raylib"

windowWidth: i32 = 1024
windowHeight: i32 = 768

animationLerpValue: f32 = -1.0

// Widget state is owned by the app.
demo_tab := 0
demo_tab_names := [?]string{"Inputs", "Navigation"}

name_field: widgets.TextField
demo_checked := true
demo_radio := 1
demo_slider: f32 = 0.4
demo_select := widgets.Select {
	index = -1,
}
demo_options := [?]string{"Apfel", "Birne", "Kirsche", "Mango"}
demo_sizes := [?]string{"Klein", "Mittel", "Groß"}

demo_menu: widgets.Menu
demo_menu_last := -1
demo_menu_items := [?]widgets.MenuItem {
	{label = "Neu"},
	{label = "Öffnen"},
	{separator = true},
	{label = "Löschen", danger = true},
	{label = "Gesperrt", disabled = true},
}

demo_acc := [2]bool{true, false}

demo_cols := [?]widgets.TableColumn {
	{title = "Name"},
	{title = "Alter", width = 80, align = .Right},
	{title = "Stadt", width = 140},
}
demo_rows := [?][]string {
	[]string{"Anna", "31", "Berlin"},
	[]string{"Ben", "27", "Hamburg"},
	[]string{"Clara", "45", "München"},
	[]string{"David", "38", "Köln"},
}
demo_row_sel := -1


page_inputs :: proc(lerpValue: f32, frametime: f32) {
	widgets.text_field(
		&name_field,
		widgets.style_textfield(clay.ID("NameField"), "Name..."),
		frametime,
	)
	widgets.label(
		fmt.tprintf("Hallo %s", widgets.text_field_string(&name_field)),
		.Subtitle,
		theme.current.secondary,
	)

	widgets.select(
		&demo_select,
		demo_options[:],
		widgets.style_select(clay.ID("Fruit"), "Obst wählen..."),
	)

	widgets.checkbox(
		&demo_checked,
		widgets.style_checkbox(clay.ID("Check"), "Ich bin eine Checkbox"),
	)

	if widgets.hstack(.LG) {
		for opt, i in demo_sizes {
			widgets.radio(&demo_radio, i, widgets.style_radio(clay.ID("Size", u32(i)), opt))
		}
	}

	widgets.slider(&demo_slider, widgets.style_slider(clay.ID("Slider")))
	widgets.label(fmt.tprintf("Wert: %.2f", demo_slider), .Caption, theme.current.text_muted)

	widgets.progress(lerpValue, widgets.style_progress(clay.ID("Progress")))
}

page_navigation :: proc() {
	if widgets.hstack(.MD) {
		picked := widgets.menu(
			&demo_menu,
			demo_menu_items[:],
			widgets.style_menu(clay.ID("FileMenu"), "Datei"),
		)
		if picked >= 0 {demo_menu_last = picked}
		if demo_menu_last >= 0 {
			widgets.label(
				fmt.tprintf("Gewählt: %s", demo_menu_items[demo_menu_last].label),
				.Caption,
				theme.current.text_muted,
			)
		}
	}

	if widgets.accordion(&demo_acc[0], "Was ist das?", widgets.style_accordion(clay.ID("Acc0"))) {
		widgets.label("Eine kleine Widget-Bibliothek auf Clay und Raylib.")
	}
	if widgets.accordion(&demo_acc[1], "Scrollbereich", widgets.style_accordion(clay.ID("Acc1"))) {
		if widgets.scroll_view(70, .XS) {
			for i in 1 ..= 12 {
				widgets.label(fmt.tprintf("Eintrag %d", i))
			}
		}
	}

	widgets.table(
		demo_cols[:],
		demo_rows[:],
		widgets.style_table(clay.ID("People")),
		&demo_row_sel,
	)
	if demo_row_sel >= 0 {
		widgets.label(
			fmt.tprintf("Zeile: %s", demo_rows[demo_row_sel][0]),
			.Caption,
			theme.current.text_muted,
		)
	}
}


createLayout :: proc(lerpValue: f32, frametime: f32) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	if clay.UI(clay.ID("RootContainer"))(
	{
		layout = {sizing = {clay.SizingGrow(), clay.SizingGrow()}, padding = theme.pad_all(.LG)},
		backgroundColor = theme.current.bg,
	},
	) {
		if widgets.vstack(.MD, fill = .Both) {
			// Title and theme switcher
			if widgets.hstack(.SM) {
				widgets.label("Widget-Demo", .Title, theme.current.primary)
				widgets.spacer()
				for f in theme.Flavor {
					name := fmt.tprintf("%v", f)
					if widgets.button(
						widgets.style_button(clay.ID("Flavor", u32(f)), name, .Ghost),
					) {
						theme.set_flavor(f)
					}
				}
			}

			widgets.tabs(&demo_tab, demo_tab_names[:], widgets.style_tabs(clay.ID("Tabs")))

			switch demo_tab {
			case 0:
				page_inputs(lerpValue, frametime)
			case 1:
				page_navigation()
			}

			widgets.spacer()

			// Buttons at the bottom, split evenly.
			if widgets.hstack(.SM) {
				cool := widgets.style_button(clay.ID("NiceButton"), "Cool", .Primary)
				cool.box.layout.sizing.width = clay.SizingGrow()
				if widgets.button(cool) {
				}

				mega := widgets.style_button(clay.ID("MegaButton"), "Mega Geil", .Secondary)
				mega.box.layout.sizing.width = clay.SizingGrow()
				if widgets.button(mega) {
				}

				reset := widgets.style_button(clay.ID("ResetButton"), "Zurücksetzen", .Danger)
				reset.box.layout.sizing.width = clay.SizingGrow()
				if widgets.button(reset) {
					demo_checked = true
					demo_radio = 1
					demo_slider = 0.4
					demo_select.index = -1
					demo_row_sel = -1
					widgets.text_field_set(&name_field, "")
				}
			}
		}
	}

	return clay.EndLayout(frametime)
}

errorHandler :: proc "c" (errorData: clay.ErrorData) {
	if (errorData.errorType == clay.ErrorType.DuplicateId) {
		// etc
	}
}

main :: proc() {
	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(
		arena,
		{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
		{handler = errorHandler},
	)
	clay.SetMeasureTextFunction(renderer.measure_text, nil)

	raylib.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	raylib.InitWindow(windowWidth, windowHeight, "Raylib Odin Example")
	raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(0))

	theme.init(
		.Mocha,
		{regular = "resources/Iosevka-Regular.ttf", bold = "resources/Iosevka-SemiBold.ttf"},
	)

	debugModeEnabled: bool = false

	for !raylib.WindowShouldClose() {
		defer free_all(context.temp_allocator)
		animationLerpValue += raylib.GetFrameTime()
		if animationLerpValue > 1 {
			animationLerpValue = animationLerpValue - 2
		}
		windowWidth = raylib.GetScreenWidth()
		windowHeight = raylib.GetScreenHeight()
		when ODIN_DEBUG {
			if (raylib.IsKeyPressed(.D)) {
				debugModeEnabled = !debugModeEnabled
				clay.SetDebugModeEnabled(debugModeEnabled)
			}
		}
		clay.SetPointerState(
			transmute(clay.Vector2)raylib.GetMousePosition(),
			raylib.IsMouseButtonDown(raylib.MouseButton.LEFT),
		)
		clay.UpdateScrollContainers(
			false,
			transmute(clay.Vector2)raylib.GetMouseWheelMoveV(),
			raylib.GetFrameTime(),
		)
		clay.SetLayoutDimensions(
			{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
		)
		theme.begin_frame()
		renderCommands := createLayout(
			animationLerpValue < 0 ? (animationLerpValue + 1) : (1 - animationLerpValue),
			raylib.GetFrameTime(),
		)
		raylib.BeginDrawing()
		renderer.clay_raylib_render(&renderCommands)
		raylib.EndDrawing()
	}
}
