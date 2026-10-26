> [!CAUTION]
> This hole repo is vibecoded
> The API is utterly garbage

# What is it

It is a small ui framework library build with
[clay](https://github.com/nicbarker/clay) and
[raylib](https://github.com/raysan5/raylib)

It is designed to be used by me

# Usage

The whole library is one package: `kiln`. Apps import it once (no raylib, no
clay), the `lib` collection points at the repo root.

```odin
import "lib:kiln"

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card("Profil") {
		if t, ok := kiln.text_field(m.name, "Name"); ok {append(out, Set_Name{t})}
		if kiln.submitted() {append(out, Save{})}

		if v, ok := kiln.slider(m.volume, 0, 100); ok {append(out, Set_Volume{v})}

		if kiln.actions() {
			if kiln.button("Löschen", .Danger) {kiln.show("confirm")}
			if kiln.button("Speichern") {append(out, Save{})}
		}
	}

	if kiln.dialog("confirm", "Wirklich löschen?") {
		if kiln.actions() {
			if kiln.button("Abbrechen", .Ghost) {kiln.hide()}
			if kiln.button("Löschen", .Danger) {append(out, Delete{}); kiln.hide()}
		}
	}
}

main :: proc() {
	kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, {title = "Meine App"})
}
```

The rules, in short (the long version is at the top of `kiln/kiln.odin`):

- Containers are `if` blocks and all take `gap`, `padding`, `fill`, `align`.
- Widgets are controlled: they take the current value and return
  `(new_value, changed)`. Buttons return `bool`, menus `(index, ok)`. The view
  never writes to the model.
- UI state (focus, scroll, open popups, sorting, expanded nodes) lives in
  kiln. Dialogs and drawers open with `kiln.show(name)`.
- `clicked`, `hovered`, `submitted`, `tooltip` and `context_menu` refer to the
  widget declared just before them.
- Ids are automatic. Wrap loop items in `kiln.scope(key)` so their UI state
  follows the item.
- Sizes, colors and spacing are named theme steps, never numbers.

## Different screen sizes

`kiln.screen()` is `.Compact`, `.Medium` or `.Expanded` (breakpoints in the
theme) and `kiln.by_screen(a, b, c)` picks a value for it. The containers adapt
to the space they actually get:

| container            | adapts by                                                   |
| -------------------- | ----------------------------------------------------------- |
| `grid(min_width)`    | as many equal columns as fit, rows balanced                 |
| `adaptive(min_width)`| row when wide, column with full-width children when narrow  |
| `field(label)`       | label beside the control, or above it                       |
| `actions()`          | right-aligned buttons, stacked full width on phones         |
| `table`              | hides columns by `priority` when narrow                     |
| `dialog`             | centered, or a sheet at the bottom on phones                |
| `bar_chart`          | thins out its labels                                        |

Ctrl +/−/0 zooms, which also moves the app between screen classes.

## Example

    odin run example -collection:lib=.

The demo has a sidebar on wide windows, an icon rail on medium ones and a top
bar with a drawer on phones. Pages: dashboard (grid, chart, counter), tasks
(list with menus and filters), people (sortable table with master-detail
editor), files (tree with preview), settings (a form that changes the theme)
and a gallery of all widgets.

## Snapshots

To see a layout at every screen size without resizing windows, render it
headlessly into PNGs (phone, tablet, desktop):

    odin run example -collection:lib=. -define:KILN_SNAPSHOT=true -define:START_PAGE=2

The files land in `snapshots/` (`-define:KILN_SNAPSHOT_DIR=...` to change).

# Problems

There will be problems becaues the hole code was written with claude free

If you find problems clone the repo and fix it. Or dont


# AI Disclamer

Its all vibe

Some say "I guided the AI" I didnt

Some say "I testet the Code" I didnt (the AI did it said its good)
