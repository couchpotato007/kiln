package settings

import "core:fmt"
import clay "lib:clay-odin"
import "lib:theme"
import "lib:widgets"

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
	language: widgets.Select, // nil = nichts gewählt (Platzhalter)
	size:     Size,
	notify:   bool,
	volume:   int,
}

Set_Language :: struct {
	language: widgets.Select,
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
	muted := theme.current.text_muted

	if widgets.card(.LG, .MD) {
		widgets.label("Einstellungen", .Subtitle)

		if widgets.vstack(.XS) {
			widgets.label("Sprache", .Caption, muted)
			lang := m.language
			cfg := widgets.style_select(clay.ID_LOCAL("lang"), "Bitte wählen...")
			if widgets.select(&lang, LANGUAGES[:], cfg) {
				append(out, Set_Language{lang})
			}
		}

		if widgets.vstack(.XS) {
			widgets.label("Schriftgröße", .Caption, muted)
			if widgets.hstack(.LG) {
				for s in Size {
					size := m.size
					cfg := widgets.style_radio(clay.ID_LOCAL("size", u32(s)), SIZE_LABELS[s])
					if widgets.radio(&size, s, cfg) {append(out, Set_Size{size})}
				}
			}
		}

		notify := m.notify
		cb := widgets.style_checkbox(clay.ID_LOCAL("notify"), "Benachrichtigungen")
		if widgets.checkbox(&notify, cb) {append(out, Set_Notify{notify})}

		if widgets.vstack(.XS) {
			widgets.label(fmt.tprintf("Lautstärke: %d%%", m.volume), .Caption, muted)
			vol := m.volume
			if widgets.slider(&vol, 0, 100, widgets.style_slider(clay.ID_LOCAL("vol"))) {
				append(out, Set_Volume{vol})
			}
		}

		if widgets.accordion("Erweitert", widgets.style_accordion(clay.ID_LOCAL("advanced"))) {
			widgets.label("Hier landen seltene Optionen.", .Caption, muted)
			if widgets.hstack(.SM) {
				widgets.spacer()
				if widgets.button("Zurücksetzen", .Danger) {append(out, Reset{})}
			}
		}

		widgets.separator()
		lang_name := "-"
		if i, ok := m.language.?; ok && i < len(LANGUAGES) {
			lang_name = LANGUAGES[i]
		}
		widgets.label(
			fmt.tprintf(
				"%s, %s, Benachrichtigungen %s, Lautstärke %d",
				lang_name,
				SIZE_LABELS[m.size],
				m.notify ? "an" : "aus",
				m.volume,
			),
			.Body,
			theme.current.secondary,
		)
	}
}
