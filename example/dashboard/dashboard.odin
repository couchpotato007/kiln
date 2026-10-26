package dashboard

// Key figures in a responsive grid (1 to 4 columns), a chart next to a side column that moves
// below it on narrow windows, and the counter from the old examples.

import "core:fmt"
import "core:math"
import "lib:kiln"

Range :: enum {
	Week,
	Month,
	Year,
}

RANGE_NAMES := [Range]string {
	.Week  = "Woche",
	.Month = "Monat",
	.Year  = "Jahr",
}

WEEKDAYS := [?]string{"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"}
MONTHS := [?]string{"Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"}

Server :: struct {
	name: string,
	load: f32,
}

SERVERS := [?]Server{{"api-1", 0.42}, {"api-2", 0.67}, {"datenbank", 0.91}, {"cache", 0.18}}

Activity :: struct {
	who, what, ago: string,
}

ACTIVITY := [?]Activity {
	{"Ada Lovelace", "hat die Analyse abgeschlossen", "vor 4 Min."},
	{"Grace Hopper", "hat einen Fehler im Compiler gefunden", "vor 12 Min."},
	{"Alan Turing", "hat 3 Aufgaben erledigt", "vor 1 Std."},
	{"Konrad Zuse", "hat die Z3 neu gestartet", "gestern"},
}

Model :: struct {
	range:   Range,
	counter: int,
	step:    int,
}

Set_Range :: struct {
	range: Range,
}
Count :: struct {
	delta: int,
}
Set_Step :: struct {
	step: int,
}
Reset_Counter :: struct {}

Msg :: union {
	Set_Range,
	Count,
	Set_Step,
	Reset_Counter,
}

init :: proc() -> Model {
	return {range = .Week, step = 1}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Set_Range:
		m.range = v.range
	case Count:
		m.counter += v.delta
	case Set_Step:
		m.step = v.step
	case Reset_Counter:
		m.counter = 0
		kiln.toast("Zähler zurückgesetzt")
	}
}

// Made-up but stable numbers for the chart.
visitors :: proc(r: Range) -> (values: []f32, labels: []string) {
	n: int
	switch r {
	case .Week:
		n, labels = 7, WEEKDAYS[:]
	case .Month:
		n = 30
		l := make([]string, n, context.temp_allocator)
		for i in 0 ..< n {l[i] = fmt.tprint(i + 1)}
		labels = l
	case .Year:
		n, labels = 12, MONTHS[:]
	}
	values = make([]f32, n, context.temp_allocator)
	for i in 0 ..< n {
		t := f32(i) / f32(n)
		values[i] = math.round(400 + 250 * math.sin(t * 6 + f32(r)) + 120 * math.sin(f32(i) * 2.3))
	}
	return
}

Stat :: struct {
	title, value, delta: string,
	up:                  bool,
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	compact := kiln.screen() == .Compact

	if kiln.row() {
		if r, ok := kiln.segmented(m.range, RANGE_NAMES, fill = compact); ok {
			append(out, Set_Range{r})
		}
		if !compact {
			kiln.spacer()
			kiln.text("Alle Zahlen sind Beispieldaten", .Caption, .Faint)
		}
	}

	f := f32(m.range) + 1
	stats := [?]Stat {
		{"Besucher", fmt.tprintf("%.0f", 3120 * f * f), "+12 %", true},
		{"Umsatz", fmt.tprintf("%.0f €", 1840 * f * f), "+4 %", true},
		{"Konversion", fmt.tprintf("%.1f %%", 3.4 - 0.3 * f), "−0,3 %", false},
		{"Tickets offen", fmt.tprint(17 * int(f)), "+2", false},
	}
	if kiln.grid(200) {
		for s in stats {
			if kiln.card(gap = .XS) {
				kiln.text(s.title, .Caption, .Muted)
				kiln.text(s.value, .Title)
				if kiln.row(.XS) {
					kiln.badge(s.delta, s.up ? .Success : .Danger)
					kiln.text("ggü. Vorperiode", .Caption, .Faint)
				}
			}
		}
	}

	if kiln.adaptive(820) {
		if kiln.card("Besucher") {
			values, labels := visitors(m.range)
			kiln.bar_chart(values, labels, height = 200)
		}
		if kiln.column(.MD, width = 320) {
			counter_card(m, out)
			servers_card()
		}
	}

	if kiln.card("Letzte Aktivitäten") {
		for a in ACTIVITY {
			if kiln.list_item() {
				kiln.avatar(a.who)
				if kiln.column(.None) {
					kiln.text(a.who)
					kiln.text(a.what, .Caption, .Muted)
				}
				kiln.text(a.ago, .Caption, .Faint)
			}
		}
	}
}

counter_card :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Zähler") {
		if kiln.row() {
			kiln.text(fmt.tprint(m.counter), .Headline, .Primary)
			kiln.spacer()
			if kiln.button("−", .Secondary) {append(out, Count{-m.step})}
			if kiln.button("+") {append(out, Count{m.step})}
		}
		kiln.text(fmt.tprintf("Schrittweite: %d", m.step), .Caption, .Muted)
		if v, ok := kiln.slider(m.step, 1, 10); ok {append(out, Set_Step{v})}
		if kiln.actions() {
			if kiln.button("Zurücksetzen", .Ghost, disabled = m.counter == 0) {
				append(out, Reset_Counter{})
			}
		}
	}
}

servers_card :: proc() {
	if kiln.card("Server") {
		for s in SERVERS {
			if kiln.row() {
				kiln.text(s.name)
				kiln.spacer()
				switch {
				case s.load > 0.85:
					kiln.badge("ausgelastet", .Danger, dot = true)
				case s.load > 0.6:
					kiln.badge("hoch", .Warning, dot = true)
				case:
					kiln.badge("ok", .Success, dot = true)
				}
			}
			kiln.progress(s.load, s.load > 0.85 ? .Danger : .Primary)
			kiln.tooltip(fmt.tprintf("%.0f %% Last", s.load * 100))
		}
		if kiln.row() {
			kiln.spinner()
			kiln.text("Messwerte werden aktualisiert ...", .Caption, .Muted)
		}
	}
}
