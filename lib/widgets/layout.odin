package widgets

// Layout helpers that replace the `clay.UI_AutoId()({layout = {...}})` boilerplate.
// All of them are used like `clay.UI`, as the condition of an `if` that holds the children:
//
//   if widgets.vstack(.MD) {
//       widgets.label("Title", .Title)
//       if widgets.hstack(.SM) {
//           widgets.button(...)
//           widgets.spacer()
//           widgets.button(...)
//       }
//   }

import clay "lib:clay-odin"
import "lib:theme"

@(private = "file")
close_element :: proc() {
	clay._CloseElement()
}

// Which axes of a stack fill the available space. All other axes fit the content.
Fill :: enum {
	None,
	Width,
	Height,
	Both,
}

@(private = "file")
fill_sizing :: proc(f: Fill) -> clay.Sizing {
	w := (f == .Width || f == .Both) ? clay.SizingGrow() : clay.SizingFit()
	h := (f == .Height || f == .Both) ? clay.SizingGrow() : clay.SizingFit()
	return {w, h}
}

@(private = "file")
stack :: proc(
	dir: clay.LayoutDirection,
	gap, padding: theme.Space,
	sizing: clay.Sizing,
	align: clay.ChildAlignment,
) {
	clay._OpenElement()
	clay.ConfigureOpenElement(
		{
			layout = {
				sizing = sizing,
				padding = theme.pad_all(padding),
				childGap = theme.sp(gap),
				childAlignment = align,
				layoutDirection = dir,
			},
		},
	)
}

// Vertical stack: children are placed top to bottom with `gap` between them.
// By default it fills the available width and is as tall as its content.
// Pass `fill = .Both` to fill the available height as well.
@(deferred_none = close_element)
vstack :: proc(
	gap := theme.Space.SM,
	padding := theme.Space.None,
	fill := Fill.Width,
	align := clay.ChildAlignment{},
) -> bool {
	stack(.TopToBottom, gap, padding, fill_sizing(fill), align)
	return true
}

// Horizontal stack: children are placed left to right with `gap` between them.
// By default it fills the available width, is as tall as its content and centers children vertically.
@(deferred_none = close_element)
hstack :: proc(
	gap := theme.Space.SM,
	padding := theme.Space.None,
	fill := Fill.Width,
	align := clay.ChildAlignment{y = .Center},
) -> bool {
	stack(.LeftToRight, gap, padding, fill_sizing(fill), align)
	return true
}

// Empty element that grows to fill all remaining space.
// In an `hstack` it pushes the following children to the right, in a `vstack` to the bottom.
spacer :: proc() {
	if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingGrow()}}}) {}
}

// Container that fills the available space and centers its children both ways.
@(deferred_none = close_element)
center :: proc() -> bool {
	clay._OpenElement()
	clay.ConfigureOpenElement(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				childAlignment = {x = .Center, y = .Center},
			},
		},
	)
	return true
}

// Bordered, rounded container with a raised background (see `theme.style_panel`).
// Fills the available width, children are stacked vertically.
@(deferred_none = close_element)
card :: proc(padding := theme.Space.MD, gap := theme.Space.SM) -> bool {
	clay._OpenElement()
	decl := theme.style_panel(padding)
	decl.layout.childGap = theme.sp(gap)
	decl.layout.sizing.width = clay.SizingGrow()
	clay.ConfigureOpenElement(decl)
	return true
}

// Vertically scrollable container (mouse wheel). `height` is in unscaled units,
// 0 fills the available height. Requires `clay.UpdateScrollContainers` to run every frame.
@(deferred_none = close_element)
scroll_view :: proc(
	height: f32 = 0,
	gap := theme.Space.XS,
	padding := theme.Space.None,
) -> bool {
	clay._OpenElement()
	h := height > 0 ? clay.SizingFixed(theme.px(height)) : clay.SizingGrow()
	clay.ConfigureOpenElement(
		{
			layout = {
				sizing = {clay.SizingGrow(), h},
				padding = theme.pad_all(padding),
				childGap = theme.sp(gap),
				layoutDirection = .TopToBottom,
			},
			clip = scroll_clip(),
		},
	)
	return true
}
