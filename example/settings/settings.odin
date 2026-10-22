package settings

import "core:fmt"
import "lib:kiln"

LANGUAGES := [?]string{"Deutsch", "English", "Français", "Español"}

Size :: enum {
	Small,
	Medium,
	Large,
}

SIZE_LABELS := [Size]string {
	.Small  = "Klein",
	.Medium = "Mittel",
	.Large  = "Groß",
}

Model :: struct {
	language: kiln.Select,
	size:     Size,
	notify:   bool,
	volume:   int,
}

Set_Language :: struct {
	language: kiln.Select,
}
Set_Size :: struct {
	size: Size,
}
Set_Notify :: struct {
	on: bool,
}
Set_Volume :: struct {
	volume: int,
}
Reset :: struct {}

Msg :: union #no_nil {
	Set_Language,
	Set_Size,
	Set_Notify,
	Set_Volume,
	Reset,
}

init :: proc() -> Model {
	return {size = .Medium, notify = true, volume = 50}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Set_Language:
		m.language = v.language
	case Set_Size:
		m.size = v.size
	case Set_Notify:
		m.notify = v.on
	case Set_Volume:
		m.volume = v.volume
	case Reset:
		m^ = init()
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	muted := kiln.theme().text_muted

	if kiln.card(.LG, .MD) {
		kiln.label("Einstellungen", .Subtitle)

		if kiln.vstack(.XS) {
			kiln.label("Sprache", .Caption, muted)
			lang := m.language
			if kiln.select(&lang, LANGUAGES[:], "Bitte wählen...") {
				append(out, Set_Language{lang})
			}
		}

		if kiln.vstack(.XS) {
			kiln.label("Schriftgröße", .Caption, muted)
			if kiln.hstack(.LG) {
				for s in Size {
					size := m.size
					if kiln.radio(&size, s, SIZE_LABELS[s], id = kiln.id_local("size", u32(s))) {
						append(out, Set_Size{size})
					}
				}
			}
		}

		notify := m.notify
		if kiln.checkbox(&notify, "Benachrichtigungen") {append(out, Set_Notify{notify})}

		if kiln.vstack(.XS) {
			kiln.label(fmt.tprintf("Lautstärke: %d%%", m.volume), .Caption, muted)
			volume := m.volume
			if kiln.slider(&volume, 0, 100) {append(out, Set_Volume{volume})}
		}

		if kiln.accordion("Erweitert") {
			kiln.label("Hier landen seltene Optionen.", .Caption, muted)
			if kiln.hstack() {
				kiln.spacer()
				if kiln.button("Zurücksetzen", .Danger) {append(out, Reset{})}
			}
		}

		kiln.separator()
		lang_name := "-"
		if i, ok := m.language.?; ok && i < len(LANGUAGES) {
			lang_name = LANGUAGES[i]
		}
		kiln.label(
			fmt.tprintf(
				"%s, %s, Benachrichtigungen %s, Lautstärke %d",
				lang_name,
				SIZE_LABELS[m.size],
				m.notify ? "an" : "aus",
				m.volume,
			),
			.Body,
			kiln.theme().secondary,
		)
	}
}
