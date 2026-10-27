package settings

// A settings form built from `field` rows: label left on wide cards, label above on narrow ones.
// The appearance settings change the theme at runtime.

import "core:fmt"
import "core:math"
import "core:strings"
import "lib:kiln"

LANGUAGES := [?]string{"Deutsch", "English", "Français", "Español"}

FLAVOR_NAMES := [kiln.Flavor]string {
	.Mocha     = "Mocha (dunkel)",
	.Macchiato = "Macchiato (dunkel)",
	.Frappe    = "Frappé (dunkel)",
	.Latte     = "Latte (hell)",
}

// Presets that only change the theme's metrics; no widget code is involved.
Look :: enum {
	Standard,
	Square,
	Round,
	Compact,
}

LOOK_NAMES := [Look]string {
	.Standard = "Standard",
	.Square   = "Eckig",
	.Round    = "Rund",
	.Compact  = "Kompakt",
}

TextSize :: enum {
	Small,
	Medium,
	Large,
}

SIZE_NAMES := [TextSize]string {
	.Small  = "Klein",
	.Medium = "Mittel",
	.Large  = "Groß",
}

Model :: struct {
	flavor:    kiln.Flavor,
	look:      Look,
	text_size: TextSize,
	language:  int,
	notify:    bool,
	sounds:    bool,
	volume:    int,
	name:      string,
	email:     string,
	password:  string,
	birthday:  kiln.Date,
}

Set_Flavor :: struct {
	flavor: kiln.Flavor,
}
Set_Look :: struct {
	look: Look,
}
Set_Zoom :: struct {
	percent: int,
}
Set_Text_Size :: struct {
	size: TextSize,
}
Set_Language :: struct {
	index: int,
}
Set_Notify :: struct {
	on: bool,
}
Set_Sounds :: struct {
	on: bool,
}
Set_Volume :: struct {
	volume: int,
}
Set_Name :: struct {
	text: string,
}
Set_Email :: struct {
	text: string,
}
Set_Password :: struct {
	text: string,
}
Set_Birthday :: struct {
	date: kiln.Date,
}
Save :: struct {}
Reset :: struct {}

Msg :: union {
	Set_Flavor,
	Set_Look,
	Set_Zoom,
	Set_Text_Size,
	Set_Language,
	Set_Notify,
	Set_Sounds,
	Set_Volume,
	Set_Name,
	Set_Email,
	Set_Password,
	Set_Birthday,
	Save,
	Reset,
}

init :: proc() -> Model {
	return {
		flavor = .Mocha,
		text_size = .Medium,
		language = 0,
		notify = true,
		sounds = true,
		volume = 60,
		name = strings.clone("Max Mustermann"),
		email = strings.clone("max@example.org"),
		birthday = {1990, 5, 17},
	}
}

// Applies flavor, look and text size to the theme.
apply_theme :: proc(m: ^Model) {
	metrics := kiln.default_metrics()
	switch m.look {
	case .Standard:
	case .Square:
		metrics.radii = {}
	case .Round:
		metrics.radii = {.None = 0, .SM = 8, .MD = 16, .LG = 24, .Full = 9999}
		metrics.sizes[.Control] = 40
	case .Compact:
		for s in kiln.Space {metrics.spacing[s] *= 0.7}
		metrics.sizes[.Control] = 30
	}
	switch m.text_size {
	case .Small:
		metrics.font_base -= 2
	case .Medium:
	case .Large:
		metrics.font_base += 2
	}
	metrics.locale = m.language == 0 ? kiln.locale_de() : kiln.locale_en()
	kiln.set_theme({colors = kiln.catppuccin_colors(m.flavor), metrics = metrics})
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Set_Flavor:
		m.flavor = v.flavor
		apply_theme(m)
	case Set_Look:
		m.look = v.look
		apply_theme(m)
	case Set_Text_Size:
		m.text_size = v.size
		apply_theme(m)
	case Set_Zoom:
		kiln.set_zoom(f32(v.percent) / 100)
	case Set_Language:
		m.language = v.index
		apply_theme(m) // month names in the calendar
	case Set_Notify:
		m.notify = v.on
	case Set_Sounds:
		m.sounds = v.on
	case Set_Volume:
		m.volume = v.volume
	case Set_Name:
		delete(m.name)
		m.name = strings.clone(v.text)
	case Set_Email:
		delete(m.email)
		m.email = strings.clone(v.text)
	case Set_Password:
		delete(m.password)
		m.password = strings.clone(v.text)
	case Set_Birthday:
		m.birthday = v.date
	case Save:
		kiln.toast("Konto gespeichert", .Success)
	case Reset:
		delete(m.name)
		delete(m.email)
		delete(m.password)
		m^ = init()
		apply_theme(m)
		kiln.set_zoom(1)
		kiln.toast("Alle Einstellungen zurückgesetzt")
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	compact := kiln.screen() == .Compact

	if kiln.card("Darstellung", gap = .MD, padding = .LG) {
		if kiln.field("Farbschema") {
			if f, ok := kiln.select(m.flavor, FLAVOR_NAMES); ok {append(out, Set_Flavor{f})}
		}
		if kiln.field("Stil", "Ändert nur die Maße des Themes.") {
			if l, ok := kiln.segmented(m.look, LOOK_NAMES, fill = compact); ok {append(out, Set_Look{l})}
		}
		if kiln.field("Schriftgröße") {
			if kiln.row(.LG) {
				for s in TextSize {
					if v, ok := kiln.radio(m.text_size, s, SIZE_NAMES[s]); ok {
						append(out, Set_Text_Size{v})
					}
				}
			}
		}
		if kiln.field("Zoom", "Auch mit Strg +, Strg − und Strg 0.") {
			percent := int(math.round(kiln.zoom() * 100))
			if kiln.row(.MD) {
				if v, ok := kiln.slider(percent, 50, 200); ok {append(out, Set_Zoom{v})}
				kiln.text(fmt.tprintf("%d %%", percent), .Body, .Muted)
			}
		}
	}

	if kiln.card("Allgemein", gap = .MD, padding = .LG) {
		if kiln.field("Sprache") {
			if i, ok := kiln.select(m.language, LANGUAGES[:]); ok {append(out, Set_Language{i})}
		}
		if kiln.field("Benachrichtigungen", "Hinweise bei neuen Aufgaben.") {
			if on, ok := kiln.toggle(m.notify); ok {append(out, Set_Notify{on})}
		}
		if kiln.field("Töne") {
			if on, ok := kiln.checkbox(m.sounds, "Ton abspielen", disabled = !m.notify); ok {
				append(out, Set_Sounds{on})
			}
		}
		if kiln.field("Lautstärke") {
			if kiln.row(.MD) {
				if v, ok := kiln.slider(m.volume, 0, 100, disabled = !m.notify || !m.sounds); ok {
					append(out, Set_Volume{v})
				}
				kiln.text(fmt.tprintf("%d %%", m.volume), .Body, .Muted)
			}
		}
	}

	if kiln.card("Konto", gap = .MD, padding = .LG) {
		if kiln.field("Name") {
			if t, ok := kiln.text_field(m.name, "Dein Name"); ok {append(out, Set_Name{t})}
		}
		email_ok := strings.contains(m.email, "@")
		if kiln.field(
			"E-Mail",
			"Wird nie veröffentlicht.",
			error = email_ok ? "" : "Das sieht nicht nach einer E-Mail-Adresse aus.",
		) {
			if t, ok := kiln.text_field(m.email, "name@example.org"); ok {append(out, Set_Email{t})}
		}
		if kiln.field("Passwort", "Mindestens 8 Zeichen.") {
			if t, ok := kiln.text_field(m.password, "Passwort", password = true); ok {
				append(out, Set_Password{t})
			}
		}
		if kiln.field("Geburtstag") {
			if d, ok := kiln.date_field(m.birthday, max = kiln.today(), placeholder = "Datum wählen"); ok {
				append(out, Set_Birthday{d})
			}
		}
		if kiln.actions() {
			if kiln.button("Speichern", disabled = !email_ok) {append(out, Save{})}
		}
	}

	if kiln.collapsible("Erweitert") {
		kiln.text("Setzt Darstellung, Zoom und alle Felder auf die Standardwerte zurück.", .Body, .Muted)
		if kiln.actions() {
			if kiln.button("Zurücksetzen", .Danger) {kiln.show("reset")}
		}
	}

	kiln.text(
		fmt.tprintf(
			"%s · %s · Benachrichtigungen %s · Lautstärke %d %%",
			LANGUAGES[m.language],
			SIZE_NAMES[m.text_size],
			m.notify ? "an" : "aus",
			m.volume,
		),
		.Caption,
		.Faint,
	)

	if kiln.dialog("reset", "Alles zurücksetzen?") {
		kiln.text("Alle Einstellungen gehen verloren.", .Body, .Muted)
		if kiln.actions() {
			if kiln.button("Abbrechen", .Ghost) {kiln.hide()}
			if kiln.button("Zurücksetzen", .Danger) {
				append(out, Reset{})
				kiln.hide()
			}
		}
	}
}
