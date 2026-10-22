package people

import "core:fmt"
import "lib:kiln"

Person :: struct {
	name, role, city: string,
}

COLUMNS := [?]kiln.TableColumn {
	{title = "Name"},
	{title = "Rolle"},
	{title = "Stadt", width = 140, align = .Right},
}

MENU_ITEMS := [?]kiln.MenuItem {
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

	if kiln.card() {
		if kiln.hstack() {
			kiln.label("Personen", .Subtitle)
			kiln.spacer()
			if i, ok := kiln.menu(MENU_ITEMS[:], "Aktionen", !has_selection); ok {
				append(out, Menu_Action{i})
			}
		}

		rows := make([][]string, len(m.people), context.temp_allocator)
		for p, i in m.people {
			rows[i] = make([]string, 3, context.temp_allocator)
			rows[i][0], rows[i][1], rows[i][2] = p.name, p.role, p.city
		}

		selected := m.selected
		if kiln.table(&selected, COLUMNS[:], rows) {append(out, Select_Row{selected})}

		if len(m.last_action) > 0 {
			kiln.label(m.last_action, .Caption, kiln.theme().text_muted)
		}
	}
}
