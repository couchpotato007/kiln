package main

import "counter"
import "greeter"
import "lib:app"
import clay "lib:clay-odin"
import "lib:theme"
import "lib:widgets"
import "people"
import "settings"
import "todo"

Tab_Selected :: distinct int

Set_Flavor :: struct {
	flavor: theme.Flavor,
}

Msg :: union #no_nil {
	counter.Msg,
	greeter.Msg,
	todo.Msg,
	settings.Msg,
	people.Msg,
	Tab_Selected,
	Set_Flavor,
}

Model :: struct {
	tab:      int,
	counter:  counter.Model,
	greeter:  greeter.Model,
	todo:     todo.Model,
	settings: settings.Model,
	people:   people.Model,
}

tab_names := [?]string{"Zähler", "Begrüßung", "Aufgaben", "Einstellungen", "Personen"}

FLAVOR_NAMES := [theme.Flavor]string {
	.Mocha     = "Mocha",
	.Macchiato = "Macchiato",
	.Frappe    = "Frappé",
	.Latte     = "Latte",
}

init :: proc() -> Model {
	return {
		counter = counter.init(),
		greeter = greeter.init(),
		todo = todo.init(),
		settings = settings.init(),
		people = people.init(),
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
	case Tab_Selected:
		m.tab = int(v)
	case Set_Flavor:
		theme.set_flavor(v.flavor)
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if widgets.vstack(.MD, fill = .Both) {
		if widgets.hstack(.SM) {
			widgets.label("Meine App", .Title, theme.current.primary)
			widgets.spacer()
			for f in theme.Flavor {
				variant := widgets.ButtonVariant.Secondary
				if f == theme.current_flavor {variant = .Primary}
				if widgets.button(FLAVOR_NAMES[f], variant) {append(out, Set_Flavor{f})}
			}
		}

		tab := m.tab
		if widgets.tabs(&tab, tab_names[:], widgets.style_tabs(clay.ID("Tabs"))) {
			append(out, Tab_Selected(tab))
		}

		switch m.tab {
		case 0:
			app.embed(out, &m.counter, counter.view)
		case 1:
			app.embed(out, &m.greeter, greeter.view)
		case 2:
			app.embed(out, &m.todo, todo.view)
		case 3:
			app.embed(out, &m.settings, settings.view)
		case 4:
			app.embed(out, &m.people, people.view)
		}
	}
}

main :: proc() {
	app.run(app.App(Model, Msg){init = init, update = update, view = view}, title = "Meine App")
}
