package people

// Master-detail view over a list of people.
//   Medium / Expanded  sortable table (columns hide by priority when narrow) with the editor
//                      beside it, or below it when there is not enough room
//   Compact            a list; selecting a person replaces it with the editor and a back button

import "core:fmt"
import "core:strings"
import "lib:kiln"

Team :: enum {
	Research,
	Engineering,
	Operations,
}

TEAM_NAMES := [Team]string {
	.Research    = "Forschung",
	.Engineering = "Entwicklung",
	.Operations  = "Betrieb",
}

// "All teams" plus the teams, for the filter select.
TEAM_FILTER := [?]string{"Alle Teams", "Forschung", "Entwicklung", "Betrieb"}

COLUMNS := [?]kiln.Column {
	{title = "Name", min_width = 160},
	{title = "Rolle", min_width = 150, priority = 2},
	{title = "Team", width = 130, priority = 3},
	{title = "Stadt", width = 120, priority = 4},
	{title = "Status", width = 100, priority = 1},
}

Person :: struct {
	id:                      int,
	name, role, city, email: string,
	team:                    Team,
	active:                  bool,
}

Model :: struct {
	people:   [dynamic]Person,
	next_id:  int,
	selected: int, // person id, -1 = none
	query:    string,
	team:     int, // index into TEAM_FILTER
}

Field :: enum {
	Name,
	Role,
	City,
	Email,
}

Select :: struct {
	id: int,
}
Set_Query :: struct {
	text: string,
}
Set_Team_Filter :: struct {
	index: int,
}
Edit :: struct {
	id:    int,
	field: Field,
	text:  string,
}
Set_Team :: struct {
	id:   int,
	team: Team,
}
Set_Active :: struct {
	id:     int,
	active: bool,
}
Add :: struct {}
Duplicate :: struct {
	id: int,
}
Delete :: struct {
	id: int,
}

Msg :: union {
	Select,
	Set_Query,
	Set_Team_Filter,
	Edit,
	Set_Team,
	Set_Active,
	Add,
	Duplicate,
	Delete,
}

init :: proc() -> Model {
	m := Model {
		selected = -1,
	}
	seed := [?]Person {
		{name = "Ada Lovelace", role = "Mathematikerin", city = "London", team = .Research, active = true},
		{name = "Alan Turing", role = "Informatiker", city = "Wilmslow", team = .Research, active = true},
		{name = "Grace Hopper", role = "Admiralin", city = "New York", team = .Engineering, active = true},
		{name = "Konrad Zuse", role = "Ingenieur", city = "Berlin", team = .Engineering, active = false},
		{name = "Margaret Hamilton", role = "Softwareingenieurin", city = "Boston", team = .Engineering, active = true},
		{name = "Edsger Dijkstra", role = "Informatiker", city = "Nuenen", team = .Research, active = false},
		{name = "Barbara Liskov", role = "Professorin", city = "Cambridge", team = .Research, active = true},
		{name = "Ken Thompson", role = "Entwickler", city = "Berkeley", team = .Operations, active = true},
		{name = "Frances Allen", role = "Compilerbauerin", city = "Peru (NY)", team = .Engineering, active = true},
		{name = "Dennis Ritchie", role = "Entwickler", city = "Bronxville", team = .Operations, active = false},
	}
	for p in seed {
		email := fmt.aprintf("%s@example.org", strings.to_lower(strings.fields(p.name, context.temp_allocator)[0], context.temp_allocator))
		add(&m, p, email)
	}
	return m
}

// Adds a copy of `p` with its own strings and a new id.
add :: proc(m: ^Model, p: Person, email: string = "") -> int {
	c := p
	c.id = m.next_id
	c.name = strings.clone(p.name)
	c.role = strings.clone(p.role)
	c.city = strings.clone(p.city)
	c.email = len(email) > 0 ? email : strings.clone(p.email)
	append(&m.people, c)
	m.next_id += 1
	return c.id
}

find :: proc(m: ^Model, id: int) -> int {
	for p, i in m.people {
		if p.id == id {return i}
	}
	return -1
}

field_ptr :: proc(p: ^Person, f: Field) -> ^string {
	switch f {
	case .Name:
		return &p.name
	case .Role:
		return &p.role
	case .City:
		return &p.city
	case .Email:
		return &p.email
	}
	return nil
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Select:
		m.selected = v.id
	case Set_Query:
		delete(m.query)
		m.query = strings.clone(v.text)
	case Set_Team_Filter:
		m.team = v.index
	case Edit:
		if i := find(m, v.id); i >= 0 {
			s := field_ptr(&m.people[i], v.field)
			delete(s^)
			s^ = strings.clone(v.text)
		}
	case Set_Team:
		if i := find(m, v.id); i >= 0 {m.people[i].team = v.team}
	case Set_Active:
		if i := find(m, v.id); i >= 0 {m.people[i].active = v.active}
	case Add:
		team := m.team > 0 ? Team(m.team - 1) : .Research
		m.selected = add(m, {name = "Neue Person", role = "", city = "", team = team, active = true})
	case Duplicate:
		if i := find(m, v.id); i >= 0 {
			p := m.people[i]
			m.selected = add(m, p)
			kiln.toast(fmt.tprintf("%s dupliziert", p.name), .Success)
		}
	case Delete:
		if i := find(m, v.id); i >= 0 {
			p := m.people[i]
			kiln.toast(fmt.tprintf("%s gelöscht", p.name), .Danger)
			delete(p.name)
			delete(p.role)
			delete(p.city)
			delete(p.email)
			ordered_remove(&m.people, i)
			if m.selected == v.id {m.selected = -1}
		}
	}
}

// Indices into m.people that match the search and the team filter.
visible :: proc(m: ^Model) -> []int {
	q := strings.to_lower(strings.trim_space(m.query), context.temp_allocator)
	out := make([dynamic]int, context.temp_allocator)
	for p, i in m.people {
		if m.team > 0 && int(p.team) != m.team - 1 {continue}
		if len(q) > 0 {
			hay := strings.to_lower(strings.join({p.name, p.role, p.city}, " ", context.temp_allocator), context.temp_allocator)
			if !strings.contains(hay, q) {continue}
		}
		append(&out, i)
	}
	return out[:]
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	compact := kiln.screen() == .Compact
	sel := find(m, m.selected)

	// Compact: the editor replaces the list.
	if compact && sel >= 0 {
		if kiln.row() {
			if kiln.button("← Zurück", .Ghost) {append(out, Select{-1})}
		}
		editor(m, out, &m.people[sel])
		confirm_delete(m, out)
		return
	}

	shown := visible(m)
	toolbar(m, out, len(shown))

	if compact {
		person_list(m, out, shown)
	} else {
		if kiln.adaptive(960, .LG) {
			if kiln.column() {person_table(m, out, shown)}
			if sel >= 0 {
				if kiln.column(width = 340) {editor(m, out, &m.people[sel])}
			}
		}
	}
	confirm_delete(m, out)
}

toolbar :: proc(m: ^Model, out: ^[dynamic]Msg, count: int) {
	if kiln.adaptive(640, .SM) {
		if t, ok := kiln.text_field(m.query, "Suchen nach Name, Rolle, Stadt ..."); ok {
			append(out, Set_Query{t})
		}
		if kiln.column(width = 180) {
			if i, ok := kiln.select(m.team, TEAM_FILTER[:]); ok {append(out, Set_Team_Filter{i})}
		}
		if kiln.button("Neue Person", fill = kiln.stacked()) {append(out, Add{})}
	}
	if count < len(m.people) {
		kiln.text(fmt.tprintf("%d von %d Personen", count, len(m.people)), .Caption, .Muted)
	} else {
		kiln.text(fmt.tprintf("%d Personen", count), .Caption, .Muted)
	}
}

person_table :: proc(m: ^Model, out: ^[dynamic]Msg, shown: []int) {
	rows := make([][]string, len(shown), context.temp_allocator)
	selected := -1
	for pi, r in shown {
		p := m.people[pi]
		rows[r] = make([]string, len(COLUMNS), context.temp_allocator)
		rows[r][0], rows[r][1], rows[r][2], rows[r][3] = p.name, p.role, TEAM_NAMES[p.team], p.city
		rows[r][4] = p.active ? "aktiv" : "inaktiv"
		if p.id == m.selected {selected = r}
	}
	if r, ok := kiln.table(selected, COLUMNS[:], rows); ok {
		append(out, Select{m.people[shown[r]].id})
	}
}

person_list :: proc(m: ^Model, out: ^[dynamic]Msg, shown: []int) {
	if kiln.card(gap = .XS, padding = .XS) {
		for pi in shown {
			p := m.people[pi]
			if kiln.scope(p.id) {
				if kiln.list_item() {
					kiln.avatar(p.name)
					if kiln.column(.None) {
						kiln.text(p.name)
						kiln.text(fmt.tprintf("%s · %s", p.role, TEAM_NAMES[p.team]), .Caption, .Muted)
					}
					if !p.active {kiln.badge("inaktiv")}
					kiln.icon(kiln.ICON_CHEVRON_RIGHT, .Body, .Faint)
				}
				if kiln.clicked() {append(out, Select{p.id})}
			}
		}
		if len(shown) == 0 {
			if kiln.column(padding = .LG, align = .Center) {kiln.text("Niemand gefunden.", .Body, .Faint)}
		}
	}
}

editor :: proc(m: ^Model, out: ^[dynamic]Msg, p: ^Person) {
	if kiln.card(gap = .MD, padding = .LG) {
		if kiln.row(.MD) {
			kiln.avatar(p.name, large = true)
			if kiln.column(.XS) {
				kiln.text(p.name, .Title)
				if kiln.row(.XS) {
					kiln.badge(TEAM_NAMES[p.team], .Info)
					kiln.badge(p.active ? "aktiv" : "inaktiv", p.active ? .Success : .Default, dot = true)
				}
			}
		}
		kiln.separator()

		// Scoped by id: switching people must not carry over the text fields' editing state.
		if kiln.scope(p.id) {
			labels := [Field]string {
				.Name  = "Name",
				.Role  = "Rolle",
				.City  = "Stadt",
				.Email = "E-Mail",
			}
			for f in Field {
				if kiln.field(labels[f]) {
					if t, ok := kiln.text_field(field_ptr(p, f)^, labels[f]); ok {
						append(out, Edit{p.id, f, t})
					}
				}
			}
			if kiln.field("Team") {
				if t, ok := kiln.select(p.team, TEAM_NAMES); ok {append(out, Set_Team{p.id, t})}
			}
			if kiln.field("Aktiv", "Inaktive Personen bekommen keine Aufgaben.") {
				if a, ok := kiln.toggle(p.active); ok {append(out, Set_Active{p.id, a})}
			}
		}

		if kiln.actions() {
			if kiln.button("Duplizieren", .Secondary) {append(out, Duplicate{p.id})}
			if kiln.button("Löschen", .Danger) {kiln.show("delete-person")}
		}
	}
}

confirm_delete :: proc(m: ^Model, out: ^[dynamic]Msg) {
	i := find(m, m.selected)
	if i < 0 {return}
	if kiln.dialog("delete-person", "Person löschen?") {
		kiln.text(fmt.tprintf("%s wird dauerhaft entfernt.", m.people[i].name), .Body, .Muted)
		if kiln.actions() {
			if kiln.button("Abbrechen", .Ghost) {kiln.hide()}
			if kiln.button("Löschen", .Danger) {
				append(out, Delete{m.selected})
				kiln.hide()
			}
		}
	}
}
