package main

import "counter"
import "greeter"
import "lib:kiln"
import "people"
import "settings"
import "todo"

Tab_Selected :: distinct int

Set_Flavor :: struct {
	flavor: kiln.Flavor,
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

FLAVOR_NAMES := [kiln.Flavor]string {
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
		kiln.set_flavor(v.flavor)
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

		tab := m.tab
		if kiln.tabs(&tab, tab_names[:], kiln.style_tabs(kiln.id("Tabs"))) {
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
		}
	}
}

main :: proc() {
	kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, title = "Meine App")
}
