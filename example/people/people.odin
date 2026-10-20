package people

import "core:fmt"
import clay "lib:clay-odin"
import "lib:theme"
import "lib:widgets"

Person :: struct {
	name, role, city: string,
}

COLUMNS := [?]widgets.TableColumn {
	{title = "Name"},
	{title = "Rolle"},
	{title = "Stadt", width = 140, align = .Right},
}

// Indizes werden in `update` ausgewertet: 0 Bearbeiten, 1 Duplizieren, 2 Trenner, 3 Löschen.
MENU_ITEMS := [?]widgets.MenuItem {
	{label = "Bearbeiten"},
	{label = "Duplizieren"},
	{separator = true},
	{label = "Löschen", danger = true},
}

Model :: struct {
	people:      [dynamic]Person,
	selected:    int,
	last_action: string,
}

Select_Row :: struct {
	index: int,
}
Menu_Action :: struct {
	index: int,
}

Msg :: union #no_nil {
	Select_Row,
	Menu_Action,
}

init :: proc() -> Model {
	m := Model {
		selected = -1,
	}
	append(
		&m.people,
		Person{"Ada Lovelace", "Mathematikerin", "London"},
		Person{"Alan Turing", "Informatiker", "Wilmslow"},
		Person{"Grace Hopper", "Admiralin", "New York"},
		Person{"Konrad Zuse", "Ingenieur", "Berlin"},
	)
	return m
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Select_Row:
		m.selected = v.index
	case Menu_Action:
		if m.selected < 0 || m.selected >= len(m.people) {return}
		p := m.people[m.selected]
		label: string
		switch v.index {
		case 0:
			label = "Bearbeiten"
		case 1:
			label = "Dupliziert"
			append(&m.people, p)
		case 3:
			label = "Gelöscht"
			ordered_remove(&m.people, m.selected)
			m.selected = -1
		}
		delete(m.last_action)
		m.last_action = fmt.aprintf("%s: %s", label, p.name)
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	has_selection := m.selected >= 0 && m.selected < len(m.people)

	if widgets.card() {
		if widgets.hstack(.SM) {
			widgets.label("Personen", .Subtitle)
			widgets.spacer()
			cfg := widgets.style_menu(clay.ID_LOCAL("actions"), "Aktionen", !has_selection)
			if i, ok := widgets.menu(MENU_ITEMS[:], cfg); ok {
				append(out, Menu_Action{i})
			}
		}

		// Die Tabelle erwartet [][]string, deshalb jeden Frame aufbauen (temp allocator).
		rows := make([][]string, len(m.people), context.temp_allocator)
		for p, i in m.people {
			rows[i] = make([]string, 3, context.temp_allocator)
			rows[i][0], rows[i][1], rows[i][2] = p.name, p.role, p.city
		}

		sel := m.selected
		if widgets.table(&sel, COLUMNS[:], rows, widgets.style_table(clay.ID_LOCAL("table"))) {
			append(out, Select_Row{sel})
		}

		if len(m.last_action) > 0 {
			widgets.label(m.last_action, .Caption, theme.current.text_muted)
		}
	}
}
