package tasks

// A task list with priorities, filters, per-item menus (button and right click) and a summary
// panel that sits beside the list on wide windows and above it on narrow ones.

import "core:fmt"
import "core:strings"
import "lib:kiln"

Priority :: enum {
	Low,
	Medium,
	High,
}

PRIORITY_NAMES := [Priority]string {
	.Low    = "Niedrig",
	.Medium = "Mittel",
	.High   = "Hoch",
}

PRIORITY_TONES := [Priority]kiln.Tone {
	.Low    = .Default,
	.Medium = .Info,
	.High   = .Danger,
}

Filter :: enum {
	All,
	Open,
	Done,
}

FILTER_NAMES := [Filter]string {
	.All  = "Alle",
	.Open = "Offen",
	.Done = "Erledigt",
}

// Entries of the item menu; the index is the action.
ITEM_MENU := [?]kiln.MenuItem {
	{label = "Priorität: Hoch"},
	{label = "Priorität: Mittel"},
	{label = "Priorität: Niedrig"},
	{separator = true},
	{label = "Löschen", danger = true},
}

Task :: struct {
	id:       int,
	text:     string,
	done:     bool,
	priority: Priority,
}

Model :: struct {
	tasks:          [dynamic]Task,
	next_id:        int,
	draft:          string,
	draft_priority: Priority,
	filter:         Filter,
}

Set_Draft :: struct {
	text: string,
}
Set_Draft_Priority :: struct {
	priority: Priority,
}
Add :: struct {}
Toggle :: struct {
	id: int,
}
Item_Action :: struct {
	id, action: int, // index into ITEM_MENU
}
Set_Filter :: struct {
	filter: Filter,
}
Clear_Done :: struct {}

Msg :: union {
	Set_Draft,
	Set_Draft_Priority,
	Add,
	Toggle,
	Item_Action,
	Set_Filter,
	Clear_Done,
}

init :: proc() -> Model {
	m := Model {
		draft_priority = .Medium,
	}
	add(&m, "Clay ausprobieren", .Medium, true)
	add(&m, "Widgets auf dem Handy testen", .High, false)
	add(&m, "README aktualisieren", .Low, false)
	add(&m, "Snapshots für alle Seiten erzeugen", .Medium, false)
	return m
}

add :: proc(m: ^Model, text: string, priority: Priority, done := false) {
	append(&m.tasks, Task{id = m.next_id, text = strings.clone(text), priority = priority, done = done})
	m.next_id += 1
}

find :: proc(m: ^Model, id: int) -> int {
	for t, i in m.tasks {
		if t.id == id {return i}
	}
	return -1
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Set_Draft:
		delete(m.draft)
		m.draft = strings.clone(v.text)
	case Set_Draft_Priority:
		m.draft_priority = v.priority
	case Add:
		text := strings.trim_space(m.draft)
		if len(text) == 0 {return}
		add(m, text, m.draft_priority)
		delete(m.draft)
		m.draft = ""
	case Toggle:
		if i := find(m, v.id); i >= 0 {m.tasks[i].done = !m.tasks[i].done}
	case Item_Action:
		i := find(m, v.id)
		if i < 0 {return}
		switch v.action {
		case 0:
			m.tasks[i].priority = .High
		case 1:
			m.tasks[i].priority = .Medium
		case 2:
			m.tasks[i].priority = .Low
		case 4:
			kiln.toast(fmt.tprintf("„%s“ gelöscht", m.tasks[i].text), .Danger)
			delete(m.tasks[i].text)
			ordered_remove(&m.tasks, i)
		}
	case Set_Filter:
		m.filter = v.filter
	case Clear_Done:
		n := 0
		for i := len(m.tasks) - 1; i >= 0; i -= 1 {
			if m.tasks[i].done {
				delete(m.tasks[i].text)
				ordered_remove(&m.tasks, i)
				n += 1
			}
		}
		kiln.toast(fmt.tprintf("%d erledigte Aufgaben entfernt", n), .Success)
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	done := 0
	for t in m.tasks {
		if t.done {done += 1}
	}

	if kiln.adaptive(800, .LG) {
		if kiln.column(.MD) {
			new_task(m, out)
			task_list(m, out)
		}
		summary(m, out, done)
	}

	if kiln.dialog("clear-done", "Erledigte entfernen?") {
		kiln.text(fmt.tprintf("%d erledigte Aufgaben werden dauerhaft gelöscht.", done), .Body, .Muted)
		if kiln.actions() {
			if kiln.button("Abbrechen", .Ghost) {kiln.hide()}
			if kiln.button("Entfernen", .Danger) {
				append(out, Clear_Done{})
				kiln.hide()
			}
		}
	}
}

new_task :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card() {
		// Input, priority and button in a row; stacked when the card gets narrow.
		if kiln.adaptive(520, .SM) {
			if t, ok := kiln.text_field(m.draft, "Neue Aufgabe ..."); ok {append(out, Set_Draft{t})}
			if kiln.submitted() {append(out, Add{})}
			if kiln.column(width = 150) {
				if p, ok := kiln.select(m.draft_priority, PRIORITY_NAMES); ok {
					append(out, Set_Draft_Priority{p})
				}
			}
			empty := len(strings.trim_space(m.draft)) == 0
			if kiln.button("Hinzufügen", disabled = empty, fill = kiln.stacked()) {append(out, Add{})}
		}
	}
}

task_list :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if f, ok := kiln.segmented(m.filter, FILTER_NAMES, fill = kiln.screen() == .Compact); ok {
		append(out, Set_Filter{f})
	}

	if kiln.card(gap = .XS, padding = .SM) {
		shown := 0
		for t in m.tasks {
			if (m.filter == .Open && t.done) || (m.filter == .Done && !t.done) {continue}
			shown += 1

			// The scope keeps hover and menu state with the task when others are removed.
			if kiln.scope(t.id) {
				if kiln.list_item() {
					if _, ok := kiln.checkbox(t.done); ok {append(out, Toggle{t.id})}
					kiln.text(t.text, .Body, t.done ? .Faint : .Default)
					kiln.spacer()
					kiln.badge(PRIORITY_NAMES[t.priority], PRIORITY_TONES[t.priority])
					if a, ok := kiln.menu("⋯", ITEM_MENU[:], .Ghost); ok {
						append(out, Item_Action{t.id, a})
					}
				}
				if kiln.clicked() {append(out, Toggle{t.id})}
				if a, ok := kiln.context_menu(ITEM_MENU[:]); ok {append(out, Item_Action{t.id, a})}
			}
		}
		if shown == 0 {
			if kiln.column(padding = .LG, align = .Center) {
				kiln.text("Hier gibt es nichts zu tun.", .Body, .Faint)
			}
		}
	}
}

summary :: proc(m: ^Model, out: ^[dynamic]Msg, done: int) {
	if kiln.column(.MD, width = 280) {
		if kiln.card("Fortschritt") {
			total := len(m.tasks)
			kiln.progress(total > 0 ? f32(done) / f32(total) : 0, .Success)
			kiln.text(fmt.tprintf("%d von %d erledigt", done, total), .Caption, .Muted)
			kiln.separator()
			for p in Priority {
				open := 0
				for t in m.tasks {
					if t.priority == p && !t.done {open += 1}
				}
				if kiln.row() {
					kiln.badge(PRIORITY_NAMES[p], PRIORITY_TONES[p])
					kiln.spacer()
					kiln.text(fmt.tprintf("%d offen", open), .Caption, .Muted)
				}
			}
			if kiln.button("Erledigte entfernen", .Secondary, disabled = done == 0, fill = true) {
				kiln.show("clear-done")
			}
		}
		kiln.text("Tipp: Rechtsklick auf eine Aufgabe öffnet ihr Menü.", .Caption, .Faint)
	}
}
