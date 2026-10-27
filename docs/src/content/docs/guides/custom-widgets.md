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
| [`interact`](/api/state/#interact) | hover / press / click of an element, call before declaring it; also the pointer position in the element, its movement and the start / end of a drag |
| [`widget_state`](/api/state/#widget_state) | a `^T` per element that kiln keeps between frames (a drag in progress, a cache) |
| [`painter`](/api/paint/#painter), [`paint`](/api/paint/#paint), [`paint_line`](/api/paint/#paint_line), [`paint_circle`](/api/paint/#paint_circle), [`paint_image`](/api/paint/#paint_image) | lines, circles and images drawn into an element |
| [`key_pressed`](/api/app/#key_pressed), [`modifiers`](/api/app/#modifiers) | keyboard shortcuts |
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

## Drawing and dragging

A widget that the pointer drags across (a drawing surface, a color wheel, a splitter) needs more
than `clicked`. The `Interaction` from `interact` also has:

| field | what |
| --- | --- |
| `started` | the left button went down on the element in this frame |
| `held` | the press that started on the element goes on, even outside of it |
| `released` | that press ended in this frame, wherever the pointer is |
| `pos` | the pointer in pixels, relative to the element's top left corner |
| `delta` | how far the pointer moved since the previous frame, in pixels |

State that belongs to the widget and not to the app, like the stroke that is being drawn, goes
into `widget_state`. It is zeroed the first time, and freed when the widget has not been shown
for a while; the `destroy` proc frees what it owns.

Shapes are drawn with a painter. It collects lines, circles and images for this frame, and
`custom = kiln.paint(p)` hands it to an element, which draws its background, then the shapes
(cut off at its bounds), then its border and children. With `painter(kiln.scale_factor())` the
coordinates are in units, so the drawing follows the zoom:

```odin
Draft :: struct {points: [dynamic][2]f32}

sketch :: proc(color: kiln.Color) -> (points: [][2]f32, done: bool) {
	eid := kiln.id("sketch")
	s := kiln.interact(eid)
	draft, _ := kiln.widget_state(eid, Draft, proc(d: ^Draft) {delete(d.points)})

	if s.started {clear(&draft.points)}
	if s.held {append(&draft.points, s.pos / kiln.scale_factor())}
	if s.released {points, done = draft.points[:], true} // copy it in `update`

	p := kiln.painter(kiln.scale_factor())
	kiln.paint_line(p, draft.points[:], 3, color)
	if clay.UI(eid)({
		layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(kiln.px(240))}},
		backgroundColor = kiln.theme().sunken,
		custom = kiln.paint(p),
	}) {}
	kiln.set_last(eid, s)
	return
}
```

The finished drawing belongs to the model: the widget returns a stroke when the pointer is
released, and `update` stores it. That gives undo and saving for free. The full version, with
colors, a brush preview and Ctrl+Z, is the "Zeichnen" page of the demo (`example/canvas`).
