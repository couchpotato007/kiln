---
title: Layout
description: Containers and how they adapt to different screen sizes.
sidebar:
  order: 3
---

Containers are `if` blocks. Everything declared inside the block is a child.

```odin
if kiln.column(.LG, max_width = 1180) {
	kiln.text("Übersicht", .Headline)
	if kiln.grid(220) {
		for s in m.stats {
			if kiln.card() {kiln.stat(s.label, s.value)}
		}
	}
}
```

## The containers

| container | what |
| --- | --- |
| [`column`](/api/layout/#column) | children top to bottom, fills the width |
| [`row`](/api/layout/#row) | children left to right, vertically centered |
| [`center`](/api/layout/#center) | fills the space, centers both ways |
| [`card(title)`](/api/layout/#card) | bordered and raised, optional title |
| [`scroll()`](/api/layout/#scroll) | scrolls vertically, fills the space |
| [`collapsible(title)`](/api/layout/#collapsible) | section with a header that opens and closes |
| [`list_item(selected)`](/api/layout/#list_item) | clickable row, ask `clicked()` after it |
| [`grid(min_width)`](/api/layout/#grid) | equal columns |
| [`adaptive(min_width)`](/api/layout/#adaptive) | row when wide, column when narrow |
| [`flow()`](/api/layout/#flow) | wraps children into lines (chips, badges, tags) |
| [`field(label, help, error)`](/api/layout/#field) | a form row with label |
| [`actions()`](/api/layout/#actions) | buttons at the end, e.g. dialog footers |

Inside them: [`spacer()`](/api/layout/#spacer) pushes the following children to the end,
[`separator()`](/api/layout/#separator) draws a line.

## Different screen sizes

`kiln.screen()` is `.Compact`, `.Medium` or `.Expanded` (breakpoints in the theme) and
`kiln.by_screen(a, b, c)` picks a value for it:

```odin
if kiln.scroll(padding = kiln.by_screen(kiln.Space.MD, .LG, .XL)) { ... }
```

The containers adapt to the space they actually get, not just the window:

| container             | adapts by                                                  |
| --------------------- | ---------------------------------------------------------- |
| `grid(min_width)`     | as many equal columns as fit, rows balanced                |
| `adaptive(min_width)` | row when wide, column with full-width children when narrow |
| `field(label)`        | label beside the control, or above it                      |
| `actions()`           | right-aligned buttons, stacked full width on phones        |
| `table`               | hides columns by `priority` when narrow                    |
| `dialog`              | centered, or a sheet at the bottom on phones               |
| `bar_chart`           | thins out its labels                                       |

`Ctrl +/−/0` zooms, which also moves the app between screen classes.

### adaptive

A row while it is at least `min_width` units wide, otherwise a column. When stacked, child
containers fill the width even if they have a fixed `width`:

```odin
if kiln.adaptive(720) {
	if kiln.column(fill = .Width) { ... }     // main content
	if kiln.column(width = 280) { ... }       // side panel, full width when stacked
}
```

[`stacked()`](/api/layout/#stacked) tells you whether the innermost `adaptive` is a column right
now.

### grid

Every container declared directly inside becomes a cell. Cells in a row share its height. The rows
are balanced: 4 cells where 3 columns fit give 2 x 2, not 3 + 1.

### field

```odin
if kiln.field("E-Mail", error = valid(m.email) ? "" : "Keine gültige Adresse") {
	if t, ok := kiln.text_field(m.email, "name@example.com"); ok {append(out, Set_Email{t})}
}
```

A non-empty `error` replaces the help text and gives the text fields, selects and date fields in
the block a danger border.

:::note
Clay cannot wrap. `flow`, `grid` and `adaptive` decide from the widths of the previous frame, so
the very first frame can look wrong. Nobody sees one frame.
:::
