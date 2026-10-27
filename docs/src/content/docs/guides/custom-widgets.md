---
title: Custom widgets
description: Building widgets from Clay elements that behave like kiln's own.
sidebar:
  order: 7
---

Widgets are plain procs that declare Clay elements. Import clay from inside kiln:

```odin
import clay "lib:kiln/clay-odin"
```

These building blocks make them behave like kiln's own:

| proc | what |
| --- | --- |
| [`id`](/api/state/#id), [`sub_id`](/api/state/#sub_id) | stable ids (`id` counts equal labels, `sub_id` for parts of a widget) |
| [`interact`](/api/state/#interact) | hover / press / click of an element, call before declaring it |
| [`set_last`](/api/state/#set_last) | makes `clicked`, `hovered`, `tooltip`, `context_menu` refer to it |
| [`tooltip_on`](/api/overlays/#tooltip_on) | a tooltip for any element, e.g. one bar of a chart |
| [`anim`](/api/state/#anim) | smooth values for hover fades and transitions |
| [`element_width`](/api/layout/#element_width) | width of an element in the previous frame (responsive layout) |
| [`element_rect`](/api/layout/#element_rect) | position and size in the previous frame (placing floating children) |
| [`rule`](/api/layout/#rule) | a line inside a custom layout |
| [`flow_item`](/api/layout/#flow_item) | lets the widget wrap inside a `flow` (call before opening it) |
| [`px`](/api/theme/#px), [`space`](/api/theme/#space-1), [`inset`](/api/theme/#inset), [`radius`](/api/theme/#radius-1), [`corners`](/api/theme/#corners), [`size`](/api/theme/#size-1), [`outline`](/api/theme/#outline), [`font`](/api/theme/#font), [`measure`](/api/theme/#measure) | theme values in pixels |
| [`tone_color`](/api/theme/#tone_color), [`mix`](/api/theme/#mix), [`fade`](/api/theme/#fade) | colors |

## Example

A colored square that you can click, with a hover fade and a tooltip. This is `swatch_button` from
`example/components`:

```odin
swatch_button :: proc(color: kiln.Color, name: string) -> bool {
	eid := kiln.id(name)
	s := kiln.interact(eid)
	d := kiln.size(.Control)
	if clay.UI(eid)({
		layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
		backgroundColor = kiln.mix(color, kiln.theme().text, 0.25 * kiln.anim(eid, 0, s.hovered ? 1 : 0)),
		cornerRadius = kiln.corners(.MD),
	}) {}
	kiln.tooltip_on(eid, name)
	kiln.set_last(eid, s)
	return s.clicked
}
```

The order matters:

1. `id` first, so the widget has a stable id.
2. `interact` before the element is declared.
3. `set_last` at the end, so `kiln.clicked()` and friends after your widget refer to it.

:::note
A press goes to the topmost interactive element under the pointer, so a button inside a
clickable list item takes the click and the item does not.
:::
