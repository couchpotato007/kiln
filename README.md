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

## Widgets

| widget | example |
| ------ | ------- |
| containers | `column`, `row`, `center`, `card("Titel")`, `scroll()`, `collapsible("Mehr")`, `list_item(selected)` |
| responsive | `grid(220)`, `adaptive(720)`, `flow()`, `field("Name", help, error)`, `actions()` |
| text | `text(s, .Caption, .Muted)`, `text(title, ellipsis = true)`, `icon(FOLDER, .Title)`, `badge("Neu", .Primary)`, `avatar(name)` |
| buttons | `button("OK")`, `button(kiln.ICON_MENU, .Ghost)`, `button("Suchen", icon = kiln.ICON_SEARCH)`, `button("Entfernen", .Ghost, tone = .Danger)`, `chip("Offen", m.open)` |
| values | `checkbox`, `toggle`, `radio`, `slider(m.v, 0, 100)`, `text_field(m.s, "Name")`, `text_field(m.pw, "Passwort", password = true)` |
| choices | `segmented`, `tabs`, `nav`, `select(m.i, OPTIONS[:])`, `chips(m.i, LABELS[:])` |
| dates | `date_field(m.due, min = kiln.today())`, `calendar(m.day)`, `date_add_months`, `date_parse`, ... |
| data | `table(m.sel, COLUMNS[:], rows)`, `tree(m.sel, nodes)` |
| charts | `bar_chart(values, labels, format = f, highlight = i)`, `timeline(rows, ticks)`, `legend(items)`, `swatch(color)`, `chart_color(i)` |
| feedback | `progress(v, color = c, thin = true)`, `spinner()`, `stat("Umsatz", "1840 €", delta = "+4 %")`, `callout(.Danger, "Fehler")`, `empty_state(title, text)`, `toast("Gespeichert")` |
| overlays | `dialog("name", "Titel")`, `drawer("nav")`, `show(name)` / `hide()`, `menu(kiln.ICON_MORE, ITEMS[:])`, `context_menu(ITEMS[:])`, `tooltip("Strg+S")` |
| other | `image(img)`, `separator()`, `spacer()`, `copy_to_clipboard(s)`, `clipboard()` |
| effects | `task(work, data)` runs `work` on a thread and delivers its message, `every("refresh", 300)` / `after(name, s)` are timers |

Custom widgets are built from `id`, `interact`, `set_last`, `tooltip_on`, `anim`,
`element_width`, `element_rect`, `flow_item` and Clay; see the top of `kiln/kiln.odin`
and `swatch_button` in `example/components`.

## Fonts

kiln compiles subsets of Iosevka (`resources/kiln-regular.ttf`,
`resources/kiln-bold.ttf`, about 80 KB each) into the binary, so apps start from
any directory. `-define:KILN_EMBED_FONTS=false` loads `font_files` at runtime
instead; `font_data` in the theme takes any font file in memory.

Any character a font has can be shown: glyphs are baked on demand the first time
a character is measured (one frame later it is there). Characters the font lacks
come from `font_fallbacks`, a list of fonts in memory that are tried in order,
e.g. a full font, a CJK font or a symbol font:

```odin
theme := kiln.catppuccin(.Mocha)
cjk, _ := os.read_entire_file("fonts/NotoSansSC-Regular.otf", context.allocator)
fallbacks := [?][]u8{#load("fonts/Iosevka-Regular.ttf"), cjk}
theme.font_fallbacks = fallbacks[:] // must stay alive while the app runs
```

TrueType and OpenType files work; font collections (`.ttc`) and color emoji
fonts do not. To make a subset of another font:

    odin run tools/subset_font -- resources/Iosevka-Regular.ttf resources/kiln-regular.ttf
    odin run tools/subset_font -- resources/Iosevka-SemiBold.ttf resources/kiln-bold.ttf

or with fonttools: `pyftsubset Iosevka-Regular.ttf --unicodes=U+20-7E,U+A0-17F,U+2010-205E,U+20AC,U+2190-21FF,U+2212,U+22EF,U+2302,U+25A0-25FF,U+2600-2609,U+2630,U+2699,U+2713-2718 --output-file=kiln-regular.ttf`.

## Icons

An `Icon` is an SVG document, an image or a character of the font. Icons are
plain values, so they can be constants and sit in tables:

```odin
FOLDER :: kiln.Icon{svg = #load("icons/folder.svg", string)}
LOGO   :: kiln.Icon{svg = #load("icons/logo.svg", string)}
STAR   :: kiln.Icon{glyph = "★"}

kiln.icon(FOLDER, .Title, .Primary)                       // sized like text of that style
if kiln.button(kiln.ICON_MENU, .Ghost) {kiln.show("nav")}  // square icon button
kiln.button("Suchen", .Secondary, icon = kiln.ICON_SEARCH) // icon before the label
kiln.menu(kiln.ICON_MORE, ITEMS[:], .Ghost)
NavItem{FOLDER, "Dateien"}, TreeNode{label = "src", icon = FOLDER}, MenuItem{label = "Öffnen", icon = FOLDER}

ic, ok := kiln.load_icon("icons/logo.png") // at runtime: .svg, .png, .jpg, ... (after the window opened)
```

SVGs are rasterized by kiln itself (no extra library) at the exact pixel size
they are drawn at, so they stay sharp at every zoom level. Icons with a single
color, like the ones from Lucide, Tabler, Feather, Heroicons or Material
(`currentColor` or plain black), take the text color of the widget; colorful
ones keep their colors. The same goes for images loaded with `load_icon`.
Supported: `path`, `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`,
groups, fill / stroke (width, caps, joins), `fill-rule`, opacity and transforms.
Not supported: gradients (drawn in the text color), `<use>`, masks, clip paths,
text and CSS classes.

Built in (used by kiln's own widgets too): `ICON_CHECK`, `ICON_CLOSE`,
`ICON_PLUS`, `ICON_MINUS`, `ICON_SEARCH`, `ICON_MENU`, `ICON_MORE`, `ICON_STAR`,
`ICON_CALENDAR`, `ICON_EYE`, `ICON_EYE_OFF`, `ICON_CHEVRON_LEFT` / `RIGHT` / `UP`
/ `DOWN`.

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

The files land in `snapshots/` (`-define:KILN_SNAPSHOT_DIR=...` to change),
`-define:KILN_SNAPSHOT_SIZES=phone,desktop` limits the sizes. `Config` has
snapshot hooks: `snapshot_setup` loads test data after `init`,
`snapshot_open` renders an extra image per dialog / drawer, `snapshot_pointer`
hovers a point (tooltips) and `snapshot_clicks` clicks before rendering (open
popups). Tasks run synchronously in snapshots. The demo exposes two of them:

    odin run example -collection:lib=. -define:KILN_SNAPSHOT=true -define:START_PAGE=4 -define:SNAPSHOT_OPEN=reset

Tests run headlessly: `odin test kiln -define:KILN_SNAPSHOT=true`.

# Problems

There will be problems becaues the hole code was written with claude free

If you find problems clone the repo and fix it. Or dont


# AI Disclamer

Its all vibe

Some say "I guided the AI" I didnt

Some say "I testet the Code" I didnt (the AI did it said its good)
