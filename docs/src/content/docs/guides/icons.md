---
title: Icons
description: SVGs, images and font glyphs as plain values.
sidebar:
  order: 6
---

An [`Icon`](/api/icons/#icon) is an SVG document, an image or a character of the font. Icons are
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

## Colors

SVGs are rasterized by kiln itself (no extra library) at the exact pixel size they are drawn at,
so they stay sharp at every zoom level.

Icons with a single color, like the ones from Lucide, Tabler, Feather, Heroicons or Material
(`currentColor` or plain black), take the text color of the widget. Colorful ones keep their
colors. The same goes for images loaded with `load_icon`.

## What SVG can do here

Supported: `path`, `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, groups, fill /
stroke (width, caps, joins), `fill-rule`, opacity and transforms.

:::caution
Not supported: gradients (drawn in the text color), `<use>`, masks, clip paths, text and CSS
classes.
:::

## Built in

Used by kiln's own widgets too:

`ICON_CHECK`, `ICON_CLOSE`, `ICON_PLUS`, `ICON_MINUS`, `ICON_SEARCH`, `ICON_MENU`, `ICON_MORE`,
`ICON_STAR`, `ICON_CALENDAR`, `ICON_EYE`, `ICON_EYE_OFF`, `ICON_CHEVRON_LEFT` / `RIGHT` / `UP` /
`DOWN`.
