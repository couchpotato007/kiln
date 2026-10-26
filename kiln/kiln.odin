package kiln

// kiln: a small immediate-mode UI library on top of Clay, with a raylib backend.
//
// Apps import only this package. The rules below hold for every part of the API.
//
// 1. Containers are `if` blocks
//
//      if kiln.card("Profil") {
//          if kiln.row() { ... }
//      }
//
//    All containers use the same parameter names: `gap` and `padding` (named `Space` steps),
//    `fill` (which axes grow), `align` (cross axis) and `width` (fixed width in units).
//
// 2. Widgets are controlled
//
//    A value widget takes the current value and returns `(new_value, changed)`. The view never
//    writes to the model, it turns changes into messages:
//
//      if v, ok := kiln.slider(m.volume, 0, 100); ok {append(out, Set_Volume{v})}
//      if kiln.button("Speichern") {append(out, Save{})}               // actions return bool
//      if i, ok := kiln.menu("Aktionen", ITEMS[:]); ok { ... }         // menus return (index, ok)
//
//    Selections are indices with -1 for "nothing". Choice widgets (`tabs`, `segmented`, `nav`,
//    `select`) also accept an enum-indexed array of labels and then return the enum.
//    Strings returned by widgets live until the end of the frame: clone them in `update`.
//
// 3. UI state lives in kiln, app state lives in the model
//
//    Focus, cursor, scroll offsets, open popups, hover fades, table sorting, expanded tree
//    nodes and collapsed sections are kept here. Dialogs and drawers are opened by name:
//
//      if kiln.button("Löschen", .Danger) {kiln.show("confirm")}
//      if kiln.dialog("confirm", "Wirklich löschen?") { ... kiln.hide() ... }
//
// 4. Item queries refer to the widget declared just before them
//
//      kiln.button("Speichern")
//      kiln.tooltip("Strg+S")
//      if kiln.list_item(selected) { ... }
//      if kiln.clicked() { ... }                                       // clicked, hovered, submitted
//      if i, ok := kiln.context_menu(ITEMS[:]); ok { ... }
//
// 5. Identity is automatic
//
//    Widgets are identified by their label (or kind) and how often it occurred before in the
//    current scope, so equal labels never clash. When a loop draws items of a list that can
//    change, wrap each item in a scope so its UI state (hover, open, focus) follows the item:
//
//      for item in m.items {
//          if kiln.scope(item.id) { ... }
//      }
//
// 6. Values come from the theme
//
//    Spacing, radii, sizes, fonts and colors are named steps (`.SM`, `.Raised`, `.Muted`, ...).
//    The theme decides what they are; numbers only appear as widths in units (scaled pixels).
//
// 7. Layouts adapt to the screen
//
//    `screen()` classifies the window as `.Compact` (phones), `.Medium` (tablets, narrow windows)
//    or `.Expanded`; `by_screen(a, b, c)` picks a value per class. Containers also adapt to the
//    space they actually get: `grid` changes its column count, `adaptive` switches between a
//    row and a column, `field` moves its label above the control, `actions` stacks its buttons
//    and `table` hides low-priority columns.
//
// Building blocks for custom widgets (`id`, `interact`, `anim`, `px`, `space`, `font`, ...)
// are public as well; combine them with Clay (`import clay "lib:kiln/clay-odin"`).
//
// Build with `-define:KILN_SNAPSHOT=true` to render the app headlessly into PNG files at phone,
// tablet and desktop size instead of opening a window (see backend_snapshot.odin).
