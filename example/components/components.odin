package components

// Every widget once, in a grid of cards that reflows from one to three columns.
// Replaces the old gallery, overlays and greeter examples.

import "core:fmt"
import "core:math"
import "core:strings"
import "lib:kiln"

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

Msg :: union {
	Set_Tab,
	Step_Progress,
	Set_Name,
	Greet,
	Menu_Picked,
	Favorite,
}

init :: proc() -> Model {
	return {picture = make_picture(), progress = 0.4, favorites = 3}
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
