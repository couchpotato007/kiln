package main

import "counter"
import "gallery"
import "greeter"
import "lib:kiln"
import "overlays"
import "people"
import "settings"
import "todo"
import "treeview"

Tab_Selected :: distinct int

Set_Flavor :: struct {
	flavor: kiln.Flavor,
}

Set_Look :: struct {
	look: int,
}

// Presets that only change the theme's metrics, no widget code is involved.
Look :: enum {
	Standard,
	Eckig,
	Rund,
	Kompakt,
}

LOOK_NAMES := [?]string{"Standard", "Eckig", "Rund", "Kompakt"}

apply_look :: proc(look: Look) {
	t := kiln.current_theme
	t.metrics = kiln.default_metrics()
	switch look {
	case .Standard:
	case .Eckig:
		t.radii = {.None = 0, .SM = 0, .MD = 0, .LG = 0, .Full = 0}
	case .Rund:
		t.radii = {.None = 0, .SM = 8, .MD = 16, .LG = 24, .Full = 9999}
		t.sizes[.LG] = 40
	case .Kompakt:
		for s in kiln.Space {t.spacing[s] *= 0.7}
		t.sizes[.LG] = 28
		t.font_base = 14
	}
	kiln.set_theme(t)
}

Msg :: union #no_nil {
	counter.Msg,
	greeter.Msg,
	todo.Msg,
	settings.Msg,
	people.Msg,
	gallery.Msg,
	treeview.Msg,
	overlays.Msg,
	Tab_Selected,
	Set_Flavor,
	Set_Look,
}

Model :: struct {
	tab:      int,
	look:     int,
	counter:  counter.Model,
	greeter:  greeter.Model,
	todo:     todo.Model,
	settings: settings.Model,
	people:   people.Model,
	gallery:  gallery.Model,
	treeview: treeview.Model,
	overlays: overlays.Model,
}

tab_names := [?]string {
	"Zähler",
	"Begrüßung",
	"Aufgaben",
	"Einstellungen",
	"Personen",
	"Galerie",
	"Dateibaum",
	"Overlays",
}

FLAVOR_NAMES := [kiln.Flavor]string {
	.Mocha     = "Mocha",
	.Macchiato = "Macchiato",
	.Frappe    = "Frappé",
	.Latte     = "Latte",
}

init :: proc() -> Model {
	return {
		tab = 0,
		counter = counter.init(),
		greeter = greeter.init(),
		todo = todo.init(),
		settings = settings.init(),
		people = people.init(),
		gallery = gallery.init(),
		treeview = treeview.init(),
		overlays = overlays.init(),
	}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case counter.Msg:
		counter.update(&m.counter, v)
	case greeter.Msg:
		greeter.update(&m.greeter, v)
	case todo.Msg:
		todo.update(&m.todo, v)
	case settings.Msg:
		settings.update(&m.settings, v)
	case people.Msg:
		people.update(&m.people, v)
	case gallery.Msg:
		gallery.update(&m.gallery, v)
	case treeview.Msg:
		treeview.update(&m.treeview, v)
	case overlays.Msg:
		overlays.update(&m.overlays, v)
	case Tab_Selected:
		m.tab = int(v)
	case Set_Flavor:
		kiln.set_flavor(v.flavor)
	case Set_Look:
		m.look = v.look
		apply_look(Look(v.look))
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.vstack(.MD, fill = .Both) {
		if kiln.hstack(.SM) {
			kiln.label("Meine App", .Title, kiln.current_theme.primary)
			kiln.spacer()
			for f in kiln.Flavor {
				variant := kiln.ButtonVariant.Secondary
				if f == kiln.current_flavor {variant = .Primary}
				if kiln.button(FLAVOR_NAMES[f], variant) {append(out, Set_Flavor{f})}
			}
		}

		if kiln.hstack(.SM) {
			kiln.label("Stil", .Caption, kiln.current_theme.text_muted)
			look := m.look
			if kiln.segmented(&look, LOOK_NAMES[:]) {append(out, Set_Look{look})}
		}

		tab := m.tab
		if kiln.tabs(&tab, tab_names[:]) {
			append(out, Tab_Selected(tab))
		}

		switch m.tab {
		case 0:
			kiln.embed(out, &m.counter, counter.view)
		case 1:
			kiln.embed(out, &m.greeter, greeter.view)
		case 2:
			kiln.embed(out, &m.todo, todo.view)
		case 3:
			kiln.embed(out, &m.settings, settings.view)
		case 4:
			kiln.embed(out, &m.people, people.view)
		case 5:
			kiln.embed(out, &m.gallery, gallery.view)
		case 6:
			kiln.embed(out, &m.treeview, treeview.view)
		case 7:
			kiln.embed(out, &m.overlays, overlays.view)
		}
	}
}

main :: proc() {
	kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, title = "Meine App")
}
