---
title: The rules
description: Seven rules that hold for every part of the API.
sidebar:
  order: 1
---

Every part of kiln follows these. If something does not, it is a bug (see
[Problems](/problems/)). The original version is at the top of `kiln/kiln.odin`.

## 1. Containers are `if` blocks

```odin
if kiln.card("Profil") {
	if kiln.row() { ... }
}
```

All containers use the same parameter names:

| name      | what                                   | type                             |
| --------- | -------------------------------------- | -------------------------------- |
| `gap`     | space between children                 | [`Space`](/api/theme/#space)     |
| `padding` | space inside the border                | [`Space`](/api/theme/#space)     |
| `fill`    | which axes grow                        | [`Fill`](/api/layout/#fill)      |
| `align`   | cross axis alignment                   | [`Align`](/api/layout/#align)    |
| `width`   | fixed width in units                   | `f32`                            |

## 2. Widgets are controlled

A value widget takes the current value and returns `(new_value, changed)`. The view never writes
to the model, it turns changes into messages:

```odin
if v, ok := kiln.slider(m.volume, 0, 100); ok {append(out, Set_Volume{v})}
if kiln.button("Speichern") {append(out, Save{})}               // actions return bool
if i, ok := kiln.menu("Aktionen", ITEMS[:]); ok { ... }         // menus return (index, ok)
```

- Selections are indices with `-1` for "nothing".
- Choice widgets (`tabs`, `segmented`, `nav`, `select`, `chips`) also take an enum-indexed array
  of labels and then return the enum.
- Strings returned by widgets live until the end of the frame. Clone them in `update`.

## 3. UI state lives in kiln, app state lives in the model

Focus, cursor, scroll offsets, open popups, hover fades, table sorting, expanded tree nodes and
collapsed sections are kept by kiln. You do not store them.

Dialogs and drawers are opened by name:

```odin
if kiln.button("Löschen", .Danger) {kiln.show("confirm")}
if kiln.dialog("confirm", "Wirklich löschen?") { ... kiln.hide() ... }
```

## 4. Item queries refer to the widget declared just before them

```odin
kiln.button("Speichern")
kiln.tooltip("Strg+S")

if kiln.list_item(selected) { ... }
if kiln.clicked() { ... }                                       // clicked, hovered, submitted
if i, ok := kiln.context_menu(ITEMS[:]); ok { ... }
```

`clicked`, `hovered`, `submitted`, `tooltip` and `context_menu` all work like this.

## 5. Identity is automatic

Widgets are identified by their label (or kind) and how often it occurred before in the current
scope, so equal labels never clash.

When a loop draws items of a list that can change, wrap each item in a scope, so its UI state
(hover, open, focus) follows the item and not the position:

```odin
for item in m.items {
	if kiln.scope(item.id) { ... }
}
```

:::caution
Text fields take their id from the placeholder. Two fields with the same placeholder share
cursor and focus. `text_field`, `select`, `date_field` and `slider` take an explicit `key` for
that:

```odin
kiln.text_field(m.from, "Stadt", key = "from")
kiln.text_field(m.to, "Stadt", key = "to")
```
:::

## 6. Values come from the theme

Spacing, radii, sizes, fonts and colors are named steps (`.SM`, `.Raised`, `.Muted`, ...). The
theme decides what they are. Numbers only appear as widths in units (scaled pixels).

See [Theme](/guides/theme/).

## 7. Layouts adapt to the screen

`screen()` classifies the window as `.Compact` (phones), `.Medium` (tablets, narrow windows) or
`.Expanded`. `by_screen(a, b, c)` picks a value per class. Containers also adapt to the space they
actually get. See [Layout](/guides/layout/).
