package main

// Demo app: one shell with navigation and six pages, each a self-contained Elm-style module.
//
// The shell adapts to the window:
//   Expanded  sidebar with icons and labels
//   Medium    narrow rail with icons (labels as tooltips)
//   Compact   top bar with a menu button that opens the navigation in a drawer
//
//   odin run example -collection:lib=.
//   odin run example -collection:lib=. -define:KILN_SNAPSHOT=true -define:START_PAGE=2

import "components"
import "dashboard"
import "files"
import "lib:kiln"
import "people"
import "settings"
import "tasks"

// First page shown (index into `Page`), handy for snapshots of a specific page.
START_PAGE :: #config(START_PAGE, 0)

Page :: enum {
	Dashboard,
	Tasks,
	People,
	Files,
	Settings,
	Components,
}

PAGES := [Page]kiln.NavItem {
	.Dashboard  = {"◆", "Übersicht"},
	.Tasks      = {"✓", "Aufgaben"},
	.People     = {"●", "Personen"},
	.Files      = {"■", "Dateien"},
	.Settings   = {"⚙", "Einstellungen"},
	.Components = {"★", "Komponenten"},
}

SUBTITLES := [Page]string {
	.Dashboard  = "Kennzahlen, Verlauf und Systemstatus auf einen Blick.",
	.Tasks      = "Aufgaben anlegen, priorisieren und abhaken.",
	.People     = "Suchen, sortieren und bearbeiten. Schmale Fenster zeigen eine Liste.",
	.Files      = "Ein Dateibaum mit Vorschau.",
	.Settings   = "Ein Formular, dessen Beschriftungen bei wenig Platz über die Felder wandern.",
	.Components = "Alle Widgets in einer Übersicht.",
}

SIDEBAR_WIDTH :: 232
RAIL_WIDTH :: 64
CONTENT_MAX_WIDTH :: 1180

Go_To :: struct {
	page: Page,
}

Msg :: union {
	Go_To,
	dashboard.Msg,
	tasks.Msg,
	people.Msg,
	files.Msg,
	settings.Msg,
	components.Msg,
}

Model :: struct {
	page:       Page,
	dashboard:  dashboard.Model,
	tasks:      tasks.Model,
	people:     people.Model,
	files:      files.Model,
	settings:   settings.Model,
	components: components.Model,
}

init :: proc() -> Model {
	return {
		page = Page(START_PAGE),
		dashboard = dashboard.init(),
		tasks = tasks.init(),
		people = people.init(),
		files = files.init(),
		settings = settings.init(),
		components = components.init(),
	}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Go_To:
		m.page = v.page
	case dashboard.Msg:
		dashboard.update(&m.dashboard, v)
	case tasks.Msg:
		tasks.update(&m.tasks, v)
	case people.Msg:
		people.update(&m.people, v)
	case files.Msg:
		files.update(&m.files, v)
	case settings.Msg:
		settings.update(&m.settings, v)
	case components.Msg:
		components.update(&m.components, v)
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	screen := kiln.screen()

	if kiln.row(gap = .None, fill = .Both, align = .Start) {
		if screen != .Compact {sidebar(m, out, collapsed = screen == .Medium)}

		if kiln.column(gap = .None, fill = .Both) {
			if screen == .Compact {top_bar(m)}

			if kiln.scroll(padding = kiln.by_screen(kiln.Space.MD, .LG, .XL)) {
				if kiln.column(align = .Center) {
					if kiln.column(.LG, max_width = CONTENT_MAX_WIDTH) {
						if kiln.column(.XS) {
							kiln.text(PAGES[m.page].label, .Headline)
							kiln.text(SUBTITLES[m.page], .Body, .Muted)
						}
						page(m, out)
					}
				}
			}
		}
	}

	// Navigation for compact screens.
	if kiln.drawer("nav") {
		brand(collapsed = false)
		if p, ok := kiln.nav(m.page, PAGES); ok {
			append(out, Go_To{p})
			kiln.hide()
		}
	}
}

page :: proc(m: ^Model, out: ^[dynamic]Msg) {
	switch m.page {
	case .Dashboard:
		kiln.embed(out, &m.dashboard, dashboard.view)
	case .Tasks:
		kiln.embed(out, &m.tasks, tasks.view)
	case .People:
		kiln.embed(out, &m.people, people.view)
	case .Files:
		kiln.embed(out, &m.files, files.view)
	case .Settings:
		kiln.embed(out, &m.settings, settings.view)
	case .Components:
		kiln.embed(out, &m.components, components.view)
	}
}

sidebar :: proc(m: ^Model, out: ^[dynamic]Msg, collapsed: bool) {
	if kiln.column(
		.SM,
		.MD,
		fill = .Height,
		width = collapsed ? RAIL_WIDTH : SIDEBAR_WIDTH,
		bg = .Sunken,
	) {
		brand(collapsed)
		if p, ok := kiln.nav(m.page, PAGES, collapsed); ok {append(out, Go_To{p})}
		kiln.spacer()
		if !collapsed {kiln.text("Strg +/− ändert den Zoom", .Caption, .Faint)}
	}
	kiln.separator()
}

brand :: proc(collapsed: bool) {
	if kiln.row(.SM, padding = .SM) {
		kiln.text("◆", .Title, .Primary)
		if !collapsed {kiln.text("Kiln Demo", .Title)}
	}
}

top_bar :: proc(m: ^Model) {
	if kiln.row(.SM, padding = .SM, bg = .Sunken) {
		if kiln.button("☰", .Ghost) {kiln.show("nav")}
		kiln.text("Kiln Demo", .Subtitle)
		kiln.spacer()
		kiln.badge(PAGES[m.page].label, .Primary)
	}
	kiln.separator()
}

main :: proc() {
	kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, {title = "Kiln Demo"})
}
