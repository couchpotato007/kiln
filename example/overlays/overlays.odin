package overlays

import "core:fmt"
import "lib:kiln"

MODE_NAMES := [?]string{"Liste", "Kacheln", "Raster"}

CONTEXT_ITEMS := [?]kiln.MenuItem {
	{label = "Öffnen"},
	{label = "Umbenennen"},
	{separator = true},
	{label = "Duplizieren"},
	{separator = true},
	{label = "Löschen", danger = true},
}

Model :: struct {
	mode:          int,
	confirm_open:  bool,
	deleted:       bool,
	last_action:   string,
}

Set_Mode :: struct {
	mode: int,
}
Confirm_Delete :: struct {}
Context_Action :: struct {
	index: int,
}

Msg :: union #no_nil {
	Set_Mode,
	Confirm_Delete,
	Context_Action,
}

init :: proc() -> Model {
	return {mode = 0}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Set_Mode:
		m.mode = v.mode
	case Confirm_Delete:
		m.confirm_open = false
		m.deleted = true
		m.last_action = "Eintrag gelöscht"
	case Context_Action:
		switch v.index {
		case 0:
			m.last_action = "Geöffnet"
		case 1:
			m.last_action = "Umbenannt"
		case 3:
			m.last_action = "Dupliziert"
		case 5:
			m.last_action = "Kontextmenü: Löschen"
		}
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	muted := kiln.current_theme.text_muted

	if kiln.card() {
		kiln.label("Ansichtsmodus", .Subtitle)
		mode := m.mode
		if kiln.segmented(&mode, MODE_NAMES[:], kiln.style_segmented(kiln.id_local("mode"))) {
			append(out, Set_Mode{mode})
		}
		kiln.label(fmt.tprintf("Modus: %s", MODE_NAMES[m.mode]), .Caption, muted)
		kiln.separator()
	}

	if kiln.card() {
		kiln.label("Dialog", .Subtitle)
		kiln.label("Öffnet einen modalen Bestätigungsdialog.", .Caption, muted)
		if kiln.button("Eintrag löschen", .Danger, disabled = m.deleted) {
			m.confirm_open = true
		}
		if m.deleted {
			kiln.badge("Gelöscht", .Danger)
		}
		kiln.separator()
	}

	if kiln.card() {
		kiln.label("Kontextmenü", .Subtitle)
		kiln.label("Rechtsklick auf die Zeile.", .Caption, muted)

		row_id := kiln.id_local("row")
		if kiln.button("projekt.odin", .Secondary, id = row_id) {}
		kiln.tooltip(kiln.style_tooltip(row_id, "Rechtsklick öffnet das Kontextmenü"))
		if i, ok := kiln.context_menu(CONTEXT_ITEMS[:], kiln.style_context_menu(row_id)); ok {
			append(out, Context_Action{i})
		}

		if len(m.last_action) > 0 {
			kiln.label(m.last_action, .Caption, kiln.current_theme.secondary)
		}
	}

	// Modal is declared last so it floats above everything else in this view.
	if kiln.modal("Eintrag löschen?", &m.confirm_open, kiln.style_modal(kiln.id("confirm"))) {
		kiln.label("Der Eintrag wird dauerhaft entfernt.", .Body, muted)
		kiln.label("Dieser Schritt kann nicht rückgängig gemacht werden.", .Caption, muted)
		if kiln.hstack(.SM) {
			kiln.spacer()
			if kiln.button("Abbrechen", .Ghost) {m.confirm_open = false}
			if kiln.button("Löschen", .Danger) {append(out, Confirm_Delete{})}
		}
	}
}
