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
| [`interact`](/api/state/#interact) | hover / press / click of an element, call before declaring it; also the pointer position in the element and the start / end of a press |
| [`pointer_events`](/api/state/#pointer_events) | the raw pointer events of the frame that belong to an element (moves, presses, releases, wheel) |
| [`widget_state`](/api/state/#widget_state) | a `^T` per element that kiln keeps between frames (a drag in progress, a cache) |
| [`drawing`](/api/draw/#drawing), [`draw`](/api/draw/#draw) and the [drawing procs](/api/draw/) | vector graphics in an element: paths, fills, strokes, images, text, transforms, clips, opacity |
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

## Drawing and pointer input

kiln has no canvas, chart or graph widget kind of its own to extend. Like GTK's `snapshot` and
event controllers, it gives every custom widget two general tools, and the widget decides what
they mean.

### Input: pointer events

`pointer_events(eid)` returns what the pointer did in this frame, in order, as far as it belongs
to the element: everything while a press that started on it goes on (even outside of it),
otherwise what happens over it while it is the topmost interactive element. Call `interact` for
the element first.

| field | what |
| --- | --- |
| `kind` | `.Move`, `.Press`, `.Release` or `.Wheel` |
| `button` | for presses and releases |
| `pos` | pixels, relative to the element's top left corner |
| `wheel` | pixels to scroll |
| `pressure` | 0..1, 1 for a mouse |
| `modifiers`, `time` | Shift / Ctrl, and seconds since the app started |

Several moves in one frame are the pointer's path between frames, so fast strokes keep their
shape where the platform reports it (the raylib backend reports one position per frame). With
`pointer_events(eid, wheel = true)` the element takes the mouse wheel: the scroll containers
around it do not scroll while the pointer is over it.

`interact` stays the short way for the common cases: `held`, `started` and `released` of the
left button, and `pos`.

### Output: drawings

A drawing records vector graphics for one frame, like a Cairo context or a `GtkSnapshot`, and
`custom = kiln.draw(d)` shows it in an element: behind the element's border and children, cut
off at its bounds.

- **Paths:** `move_to`, `line_to`, `quad_to`, `curve_to`, `arc`, `close_path`, and the shortcuts
  `rect_path` (with corner radius) and `circle_path`.
- **Painting a path:** `fill_path` (nonzero or even-odd) and `stroke_path` (width, caps, joins).
  Both use up the path.
- **More:** `draw_image` and `draw_text` (filled letter outlines, so text turns and scales too).
- **Blocks** like containers: `transform` (move, turn, scale), `clip` (to the current path) and
  `opacity` (the content is blended once, so overlapping parts do not show through).
- **Offscreen:** `render_image` draws a drawing into an image once, for pictures that are
  expensive and change rarely.

With `drawing(kiln.scale_factor())` coordinates are in units, so a drawing follows the zoom.
Drawings render the same in the window and in snapshots, and the window keeps a drawing's
pixels in a texture until the drawing changes.

```odin
Draft :: struct {points: [dynamic][2]f32}

sketch :: proc(color: kiln.Color) -> (points: [][2]f32, done: bool) {
	eid := kiln.id("sketch")
	s := kiln.interact(eid)
	draft, _ := kiln.widget_state(eid, Draft, proc(d: ^Draft) {delete(d.points)})
	scale := kiln.scale_factor()

	for e in kiln.pointer_events(eid) {
		#partial switch e.kind {
		case .Press:
			clear(&draft.points)
			append(&draft.points, e.pos / scale)
		case .Move:
			if s.held {append(&draft.points, e.pos / scale)}
		case .Release:
			points, done = draft.points[:], true // copy it in `update`
		}
	}

	d := kiln.drawing(scale)
	for p, i in draft.points {
		if i == 0 {kiln.move_to(d, p)} else {kiln.line_to(d, p)}
	}
	kiln.stroke_path(d, color, width = 3)
	if clay.UI(eid)({
		layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(kiln.px(240))}},
		backgroundColor = kiln.theme().sunken,
		custom = kiln.draw(d),
	}) {}
	kiln.set_last(eid, s)
	return
}
```

The finished drawing belongs to the model: the widget returns a stroke when the pointer is
released, and `update` stores it. That gives undo and saving for free. The full version, with
colors, a brush preview, the wheel for the pen width, Ctrl+Z and an image of the finished
strokes, is the "Zeichnen" page of the demo (`example/canvas`). kiln's own bar chart draws its
value axis the same way.
