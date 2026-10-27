package components

// Every widget once, in a grid of cards that reflows from one to three columns.
// Replaces the old gallery, overlays and greeter examples.

import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"
import "lib:kiln"
import clay "lib:kiln/clay-odin"

ACTIONS := [?]kiln.MenuItem {
	{label = "Öffnen"},
	{label = "Umbenennen"},
	{label = "Archivieren", disabled = true},
	{separator = true},
	{label = "Löschen", danger = true},
}

Tab :: enum {
	Overview,
	Details,
	History,
}

TAB_NAMES := [Tab]string {
	.Overview = "Übersicht",
	.Details  = "Details",
	.History  = "Verlauf",
}

TAB_TEXT := [Tab]string {
	.Overview = "Tabs zeigen nur die Leiste; was darunter steht, entscheidet die View.",
	.Details  = "Die Auswahl ist ein Enum, kein Index.",
	.History  = "Unterstrich und Farbe blenden weich über.",
}

Model :: struct {
	picture:    kiln.Image,
	tab:        Tab,
	progress:   f32,
	name:       string,
	greeting:   string,
	last_menu:  string,
	favorites:  int,
	password:   string,
	date:       kiln.Date,
	filter:     int,
	tags:       [len(TAGS)]bool,
	color:      int, // picked in the custom widget, -1 = none
	loads:      int, // tasks started
	loaded:     string, // what the last task returned
	ticks:      int,
}

Set_Tab :: struct {
	tab: Tab,
}
Step_Progress :: struct {
	delta: f32,
}
Set_Name :: struct {
	text: string,
}
Greet :: struct {}
Menu_Picked :: struct {
	source: string,
	index:  int,
}
Favorite :: struct {}
Set_Password :: struct {
	text: string,
}
Set_Date :: struct {
	date: kiln.Date,
}
Set_Filter :: struct {
	index: int,
}
Toggle_Tag :: struct {
	index: int,
}
Pick_Color :: struct {
	index: int,
}
Start_Load :: struct {}
Tick :: struct {}

// Sent by the background task, a variant of `Msg` (which is itself a variant of the app's message).
Loaded :: struct {
	number: int,
}

Msg :: union {
	Set_Tab,
	Step_Progress,
	Set_Name,
	Greet,
	Menu_Picked,
	Favorite,
	Set_Password,
	Set_Date,
	Set_Filter,
	Toggle_Tag,
	Pick_Color,
	Start_Load,
	Loaded,
	Tick,
}

init :: proc() -> Model {
	return {picture = make_picture(), progress = 0.4, favorites = 3, date = {2026, 10, 26}, color = -1, tags = {true, false, true, false, false, false}}
}

// A procedural picture, so the example needs no image files.
make_picture :: proc() -> kiln.Image {
	W, H :: 320, 180
	pixels := make([]kiln.Pixel, W * H, context.temp_allocator)
	for y in 0 ..< H {
		for x in 0 ..< W {
			u, v := f32(x) / W, f32(y) / H
			sun := max(0, 1 - math.sqrt((u - 0.7) * (u - 0.7) * 3 + (v - 0.35) * (v - 0.35) * 9) * 2.5)
			hills := v > 0.62 + 0.08 * math.sin(u * 9) ? f32(1) : 0
			r := 40 + 150 * v + 200 * sun
			g := 40 + 60 * v + 160 * sun - 30 * hills
			b := 90 + 100 * (1 - v) + 60 * sun - 60 * hills
			pixels[y * W + x] = {u8(clamp(r, 0, 255)), u8(clamp(g, 0, 255)), u8(clamp(b, 0, 255)), 255}
		}
	}
	return kiln.create_image(W, H, pixels)
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Set_Tab:
		m.tab = v.tab
	case Step_Progress:
		m.progress = clamp(m.progress + v.delta, 0, 1)
	case Set_Name:
		delete(m.name)
		m.name = strings.clone(v.text)
	case Greet:
		name := strings.trim_space(m.name)
		if len(name) == 0 {return}
		kiln.toast(fmt.tprintf("Hallo %s!", name), .Primary)
		delete(m.greeting)
		m.greeting = strings.clone(name)
		delete(m.name)
		m.name = ""
	case Menu_Picked:
		delete(m.last_menu)
		m.last_menu = fmt.aprintf("%s: %s", v.source, ACTIONS[v.index].label)
	case Set_Password:
		delete(m.password)
		m.password = strings.clone(v.text)
	case Set_Date:
		m.date = v.date
	case Set_Filter:
		m.filter = v.index
	case Toggle_Tag:
		m.tags[v.index] = !m.tags[v.index]
	case Pick_Color:
		m.color = v.index
	case Start_Load:
		m.loads += 1
		kiln.task(load, m.loads)
	case Loaded:
		delete(m.loaded)
		m.loaded = fmt.aprintf("Ergebnis %d ist da", v.number)
	case Tick:
		m.ticks += 1
	case Favorite:
		m.favorites += 1
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.grid(330, .LG) {
		buttons(m, out)
		inputs(m, out)
		badges()
		feedback(m, out)
		picture(m)
		tabs(m, out)
		menus(m, out)
		overlays()
		secrets_and_dates(m, out)
		calendar(m, out)
		chips(m, out)
		callouts()
		stats()
		long_texts()
		chart()
		custom(m, out)
		background(m, out)
	}

	if kiln.dialog("demo", "Ein Dialog") {
		kiln.text("Dialoge sind auf großen Fenstern zentriert und werden auf dem Handy zu einem Blatt am unteren Rand.", .Body, .Muted)
		if t, ok := kiln.text_field(m.name, "Dein Name ..."); ok {append(out, Set_Name{t})}
		if kiln.submitted() {
			append(out, Greet{})
			kiln.hide()
		}
		if kiln.actions() {
			if kiln.button("Schließen", .Ghost) {kiln.hide()}
			if kiln.button("Begrüßen", disabled = len(strings.trim_space(m.name)) == 0) {
				append(out, Greet{})
				kiln.hide()
			}
		}
	}
}

buttons :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Knöpfe") {
		if kiln.row() {
			kiln.button("Primär")
			kiln.button("Sekundär", .Secondary)
		}
		if kiln.row() {
			kiln.button("Ghost", .Ghost)
			kiln.button("Gefahr", .Danger)
			kiln.button("Aus", disabled = true)
		}
		if kiln.row() {
			kiln.button("Entfernen", .Ghost, tone = .Danger)
			kiln.button("Prüfen", .Secondary, tone = .Success)
		}
		if kiln.row() {
			kiln.button("☰", .Secondary)
			kiln.tooltip("Menü")
			kiln.button("⚙", .Secondary)
			kiln.tooltip("Einstellungen")
			if kiln.button("★", .Secondary) {append(out, Favorite{})}
			kiln.tooltip("Favorit hinzufügen")
			kiln.text(fmt.tprintf("%d Favoriten", m.favorites), .Caption, .Muted)
		}
	}
}

inputs :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Begrüßung") {
		kiln.text("Enter oder der Knopf schicken den Namen ab.", .Caption, .Muted)
		if kiln.row() {
			if t, ok := kiln.text_field(m.name, "Name ..."); ok {append(out, Set_Name{t})}
			if kiln.submitted() {append(out, Greet{})}
			if kiln.button("Los", disabled = len(strings.trim_space(m.name)) == 0) {append(out, Greet{})}
		}
		if len(m.greeting) > 0 {
			kiln.text(fmt.tprintf("Zuletzt begrüßt: %s", m.greeting), .Body, .Info)
		}
	}
}

badges :: proc() {
	if kiln.card("Abzeichen und Avatare") {
		if kiln.row(.XS) {
			kiln.badge("Neutral")
			kiln.badge("Primär", .Primary)
			kiln.badge("Info", .Info)
			kiln.badge("Ok", .Success)
		}
		if kiln.row(.XS) {
			kiln.badge("Warnung", .Warning)
			kiln.badge("Fehler", .Danger)
			kiln.badge("Online", .Success, dot = true)
			kiln.badge("99+", .Danger)
		}
		if kiln.row() {
			for name in ([?]string{"Ada Lovelace", "Alan Turing", "Grace Hopper", "Konrad Zuse"}) {
				kiln.avatar(name)
				kiln.tooltip(name)
			}
		}
	}
}

feedback :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Fortschritt") {
		kiln.progress(m.progress)
		kiln.progress(m.progress * 0.6, .Success)
		kiln.progress(1 - m.progress, .Warning)
		for i in 0 ..< 3 {kiln.progress(m.progress * f32(3 - i) / 3, color = kiln.chart_color(i + 4), thin = true)}
		if kiln.row() {
			if kiln.button("−", .Secondary) {append(out, Step_Progress{-0.1})}
			if kiln.button("+", .Secondary) {append(out, Step_Progress{0.1})}
			kiln.text(fmt.tprintf("%.0f %%", m.progress * 100), .Body, .Muted)
			kiln.spacer()
			kiln.spinner()
		}
	}
}

picture :: proc(m: ^Model) {
	if kiln.card("Bild") {
		kiln.image(m.picture)
		kiln.text("Ohne Größe füllt ein Bild die Breite und behält sein Seitenverhältnis.", .Caption, .Muted)
	}
}

tabs :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Tabs") {
		if t, ok := kiln.tabs(m.tab, TAB_NAMES); ok {append(out, Set_Tab{t})}
		kiln.text(TAB_TEXT[m.tab], .Body, .Muted)
	}
}

menus :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Menüs") {
		if kiln.row() {
			if i, ok := kiln.menu("Aktionen", ACTIONS[:]); ok {append(out, Menu_Picked{"Menü", i})}
			if i, ok := kiln.menu("⋯", ACTIONS[:], .Ghost); ok {append(out, Menu_Picked{"Icon-Menü", i})}
		}
		if kiln.list_item() {
			kiln.text("□", .Body, .Muted)
			kiln.text("projekt.odin")
			kiln.spacer()
			kiln.text("Rechtsklick", .Caption, .Faint)
		}
		if i, ok := kiln.context_menu(ACTIONS[:]); ok {append(out, Menu_Picked{"Kontextmenü", i})}
		if len(m.last_menu) > 0 {kiln.text(m.last_menu, .Caption, .Info)}
	}
}

overlays :: proc() {
	if kiln.card("Dialoge und Hinweise") {
		if kiln.button("Dialog öffnen", .Secondary) {kiln.show("demo")}
		if kiln.row(.XS) {
			if kiln.button("Info", .Ghost) {kiln.toast("Eine neutrale Nachricht")}
			if kiln.button("Erfolg", .Ghost) {kiln.toast("Gespeichert", .Success)}
			if kiln.button("Fehler", .Ghost) {kiln.toast("Das hat nicht geklappt", .Danger)}
		}
	}
}

FILTERS := [?]string{"Alle", "Offen", "Erledigt", "Archiv"}
TAGS := [?]string{"Arbeit", "Privat", "Dringend", "Später", "Idee", "Einkauf"}

secrets_and_dates :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Passwort und Datum") {
		short := len(m.password) > 0 && len(m.password) < 8
		if kiln.field("Passwort", "Mindestens 8 Zeichen.", error = short ? "Noch zu kurz." : "") {
			if t, ok := kiln.text_field(m.password, "Passwort", password = true); ok {append(out, Set_Password{t})}
		}
		if kiln.field("Fällig") {
			if d, ok := kiln.date_field(m.date, min = {2026, 1, 1}, max = {2027, 12, 31}); ok {append(out, Set_Date{d})}
		}
		kiln.text(
			fmt.tprintf("%s, Wochentag %d", kiln.date_format(m.date), kiln.date_weekday(m.date) + 1),
			.Caption,
			.Muted,
		)
	}
}

calendar :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Kalender") {
		if d, ok := kiln.calendar(m.date, min = {2026, 1, 1}); ok {append(out, Set_Date{d})}
		kiln.text("Pfeiltasten, Bild auf / ab und Enter, solange der Zeiger darüber ist.", .Caption, .Faint)
	}
}

chips :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Chips und Flow") {
		if i, ok := kiln.chips(m.filter, FILTERS[:]); ok {append(out, Set_Filter{i})}
		kiln.separator()
		if kiln.flow() {
			for tag, i in TAGS {
				if kiln.chip(tag, m.tags[i]) {append(out, Toggle_Tag{i})}
			}
		}
		kiln.text("Zeilen brechen um, wenn die Karte schmal wird.", .Caption, .Faint)
	}
}

callouts :: proc() {
	if kiln.card("Hinweise") {
		if kiln.callout(.Danger, "Konnte nicht laden") {
			kiln.text("Der Server antwortet nicht.", .Body, .Muted)
			if kiln.button("Nochmal", .Secondary) {kiln.toast("Wird erneut versucht ...")}
		}
		if kiln.callout(.Success) {
			kiln.text("Verbunden mit wellbeing.local")
		}
		if kiln.empty_state("Noch nichts da", "Neue Einträge erscheinen hier.") {
			kiln.button("Anlegen", .Secondary)
		}
	}
}

stats :: proc() {
	if kiln.card("Kennzahlen") {
		if kiln.grid(130) {
			kiln.stat("Bildschirmzeit", "5h 8m", delta = "↓ 12 %", delta_tone = .Success, large = true)
			kiln.stat("Entsperrungen", "84", note = "seit 7 Uhr", delta = "↑ 4", delta_tone = .Warning)
		}
	}
}

long_texts :: proc() {
	if kiln.card("Lange Texte") {
		titles := [?]string {
			"kiln — ~/kodieren/odin/app/kiln/layout.odin — Visual Studio Code",
			"Odin Programming Language: Overview of the core library and the vendor packages",
			"Kurz",
		}
		for t in titles {
			if kiln.list_item() {
				kiln.text("□", .Body, .Muted)
				kiln.text(t, ellipsis = true)
			}
		}
		kiln.text("Abgeschnittene Titel zeigen den vollen Text als Tooltip.", .Caption, .Faint)
	}
}

chart :: proc() {
	if kiln.card("Diagramm mit Farben") {
		values := [?]f32{42, 18, 31, 7, 25}
		colors := make([]kiln.Color, len(values), context.temp_allocator)
		items := make([]kiln.Legend_Item, len(values), context.temp_allocator)
		for &c, i in colors {
			c = kiln.chart_color(i)
			items[i] = {TAGS[i], c}
		}
		minutes :: proc(v: f32) -> string {return fmt.tprintf("%.0f min", v)}
		kiln.bar_chart(values[:], TAGS[:len(values)], height = 100, format = minutes, colors = colors)
		kiln.legend(items)
	}
}

// A widget that is not part of kiln, built from its public building blocks: a color square
// that reacts to hover, has a tooltip and answers `kiln.clicked()`.
swatch_button :: proc(color: kiln.Color, name: string, selected: bool) -> bool {
	eid := kiln.id(name)
	s := kiln.interact(eid)
	h := kiln.anim(eid, 0, s.hovered ? 1 : 0)
	d := kiln.size(.Control)
	theme := kiln.theme()
	kiln.flow_item(eid) // wrap like kiln's own widgets inside a `flow`
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
		backgroundColor = kiln.mix(color, theme.text, 0.25 * h),
		cornerRadius = kiln.corners(.MD),
		border = selected ? kiln.outline(theme.text) : {},
	},
	) {}
	kiln.tooltip_on(eid, name)
	kiln.set_last(eid, s)
	return s.clicked
}

custom :: proc(m: ^Model, out: ^[dynamic]Msg) {
	NAMES := [8]string{"Blau", "Pfirsich", "Grün", "Gelb", "Rosa", "Türkis", "Lila", "Rot"}
	if kiln.card("Eigenes Widget") {
		if kiln.flow(.XS, .XS) {
			for name, i in NAMES {
				if swatch_button(kiln.chart_color(i), name, m.color == i) {append(out, Pick_Color{i})}
			}
		}
		if m.color >= 0 {
			if kiln.row(.XS) {
				kiln.swatch(kiln.chart_color(m.color))
				kiln.text(NAMES[m.color], .Caption, .Muted)
			}
		}
		kiln.text("Gebaut aus id, interact, anim, tooltip_on und set_last.", .Caption, .Faint)
	}
}

// Runs on a worker thread: no model, no UI state.
load :: proc(number: int) -> Loaded {
	time.sleep(time.Second)
	return Loaded{number}
}

background :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.every("components-tick", 1) {append(out, Tick{})}
	if kiln.card("Hintergrund") {
		if kiln.row() {
			if kiln.button("Laden (1 s)", .Secondary) {append(out, Start_Load{})}
			if kiln.tasks_running() > 0 {
				kiln.spinner()
				kiln.text(fmt.tprintf("%d läuft", kiln.tasks_running()), .Caption, .Muted)
			}
		}
		if len(m.loaded) > 0 {kiln.text(m.loaded, .Body, .Success)}
		kiln.text(fmt.tprintf("Timer: %d s auf dieser Seite", m.ticks), .Caption, .Faint)
	}
}
