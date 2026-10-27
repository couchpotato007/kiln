---
title: Widgets
description: All widgets on one page, with links to their arguments.
sidebar:
  order: 4
---

All of them follow [the rules](/guides/rules/): value widgets return `(new_value, changed)`,
buttons return `bool`, menus `(index, ok)`. Click a name for the full argument list.

## Text and display

| widget | example |
| --- | --- |
| [`text`](/api/display/#text) | `text(s, .Caption, .Muted)`, `text(title, ellipsis = true)` |
| [`icon`](/api/icons/#icon) | `icon(FOLDER, .Title)` |
| [`badge`](/api/display/#badge) | `badge("Neu", .Primary)`, `badge("Online", .Success, dot = true)` |
| [`avatar`](/api/display/#avatar) | `avatar(name)` |
| [`stat`](/api/display/#stat) | `stat("Umsatz", "1840 €", delta = "+4 %")` |
| [`progress`](/api/display/#progress) | `progress(v, color = c, thin = true)` |
| [`spinner`](/api/display/#spinner) | `spinner()` |
| [`callout`](/api/display/#callout) | `if kiln.callout(.Danger, "Fehler") { ... }` |
| [`empty_state`](/api/display/#empty_state) | `if kiln.empty_state(title, text) { ... }` |
| [`image`](/api/display/#image) | `image(img)` |

## Buttons and values

| widget | example |
| --- | --- |
| [`button`](/api/controls/#button) | `button("OK")`, `button(kiln.ICON_MENU, .Ghost)`, `button("Suchen", icon = kiln.ICON_SEARCH)`, `button("Entfernen", .Ghost, tone = .Danger)` |
| [`chip`](/api/display/#chip) | `chip("Offen", m.open)` |
| [`checkbox`](/api/controls/#checkbox) | `checkbox(m.notify, "Benachrichtigungen")` |
| [`toggle`](/api/controls/#toggle) | `toggle(m.dark, "Dunkel")` |
| [`radio`](/api/controls/#radio) | `radio(m.size, Size.Large, "Groß")` |
| [`slider`](/api/controls/#slider) | `slider(m.v, 0, 100)` |
| [`text_field`](/api/controls/#text_field) | `text_field(m.s, "Name")`, `text_field(m.pw, "Passwort", password = true)` |

## Choices

Choice widgets take either a slice of labels and return an index, or an enum-indexed array and
return the enum.

| widget | example |
| --- | --- |
| [`tabs`](/api/choices/#tabs) | `tabs(m.tab, TAB_NAMES)` |
| [`segmented`](/api/choices/#segmented) | `segmented(m.range, RANGES, fill = true)` |
| [`nav`](/api/choices/#nav) | `nav(m.page, PAGES, collapsed = true)` |
| [`select`](/api/choices/#select) | `select(m.i, OPTIONS[:])` |
| [`chips`](/api/display/#chips) | `chips(m.i, LABELS[:])` |

## Dates

| widget | example |
| --- | --- |
| [`date_field`](/api/dates/#date_field) | `date_field(m.due, min = kiln.today())` |
| [`calendar`](/api/dates/#calendar) | `calendar(m.day)` |

Plus date math: `date_add_days`, `date_add_months`, `date_diff`, `date_parse`, `date_format`, ...
see [Dates](/api/dates/).

## Data

| widget | example |
| --- | --- |
| [`table`](/api/data/#table) | `table(m.sel, COLUMNS[:], rows)` |
| [`tree`](/api/data/#tree) | `tree(m.sel, nodes)` |

## Charts

| widget | example |
| --- | --- |
| [`bar_chart`](/api/charts/#bar_chart) | `bar_chart(values, labels, format = f, highlight = i)` |
| [`timeline`](/api/charts/#timeline) | `timeline(rows, ticks)` |
| [`legend`](/api/charts/#legend) | `legend(items)` |
| [`swatch`](/api/charts/#swatch) | `swatch(color)` |

`chart_color(i)` gives the i-th categorical color of the theme.

## Overlays

| widget | example |
| --- | --- |
| [`dialog`](/api/overlays/#dialog) | `if kiln.dialog("name", "Titel") { ... }` |
| [`drawer`](/api/overlays/#drawer) | `if kiln.drawer("nav") { ... }` |
| [`show`](/api/state/#show) / [`hide`](/api/state/#hide) | `show("name")`, `hide()` |
| [`menu`](/api/overlays/#menu) | `menu(kiln.ICON_MORE, ITEMS[:])` |
| [`context_menu`](/api/overlays/#context_menu) | `context_menu(ITEMS[:])` after the item |
| [`tooltip`](/api/overlays/#tooltip) | `tooltip("Strg+S")` after the item |
| [`toast`](/api/overlays/#toast) | `toast("Gespeichert", .Success)` |

A dialog, the way it is meant to be used:

```odin
if kiln.button("Löschen", .Danger) {kiln.show("confirm")}

if kiln.dialog("confirm", "Eintrag löschen?") {
	kiln.text("Das kann nicht rückgängig gemacht werden.")
	if kiln.actions() {
		if kiln.button("Abbrechen", .Ghost) {kiln.hide()}
		if kiln.button("Löschen", .Danger) {append(out, Delete{}); kiln.hide()}
	}
}
```

## Everything at once

The "Komponenten" page of the example shows every widget once:

```sh
odin run example -collection:lib=. -define:START_PAGE=5
```
