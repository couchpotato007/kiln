package layout

// Layout helpers that replace the `clay.UI_AutoId()({layout = {...}})` boilerplate.
// All of them are used like `clay.UI`, as the condition of an `if` that holds the children:
//
//   if kiln.vstack(.MD) {
//       kiln.label("Title", .Title)
//       if kiln.hstack(.SM) {
//           kiln.button(...)
//           kiln.spacer()
//           kiln.button(...)
//       }
//   }

import clay "lib:kiln/clay-odin"
import th "lib:kiln/theme"

@(private)
close_element :: proc() {
	clay._CloseElement()
}

@(private)
open_element :: proc(decl: clay.ElementDeclaration) {
	clay._OpenElement()
	clay.ConfigureOpenElement(decl)
}

// Which axes of a stack fill the available space. All other axes fit the content.
Fill :: enum {
	None,
	Width,
	Height,
	Both,
}

@(private)
fill_sizing :: proc(f: Fill) -> clay.Sizing {
	w := (f == .Width || f == .Both) ? clay.SizingGrow() : clay.SizingFit()
	h := (f == .Height || f == .Both) ? clay.SizingGrow() : clay.SizingFit()
	return {w, h}
}

@(private)
stack :: proc(
	dir: clay.LayoutDirection,
	gap, padding: th.Space,
	fill: Fill,
	align: clay.ChildAlignment,
	bg: th.Surface,
	round: th.Radius,
) {
	open_element(
		{
			layout = {
				sizing = fill_sizing(fill),
				padding = th.pad_all(padding),
				childGap = th.sp(gap),
				childAlignment = align,
				layoutDirection = dir,
			},
			backgroundColor = th.surface_color(bg),
			cornerRadius = th.radius(round),
		},
	)
}

// Vertical stack: children are placed top to bottom with `gap` between them.
// By default it fills the available width and is as tall as its content.
@(deferred_none = close_element)
vstack :: proc(
	gap := th.Space.SM,
	padding := th.Space.None,
	fill := Fill.Width,
	align := clay.ChildAlignment{},
	bg := th.Surface.None,
	round := th.Radius.None,
) -> bool {
	stack(.TopToBottom, gap, padding, fill, align, bg, round)
	return true
}

// Horizontal stack: children are placed left to right with `gap` between them.
// By default it fills the available width, is as tall as its content and centers children vertically.
@(deferred_none = close_element)
hstack :: proc(
	gap := th.Space.SM,
	padding := th.Space.None,
	fill := Fill.Width,
	align := clay.ChildAlignment{y = .Center},
	bg := th.Surface.None,
	round := th.Radius.None,
) -> bool {
	stack(.LeftToRight, gap, padding, fill, align, bg, round)
	return true
}

// Container that fills the available space and centers its children both ways.
@(deferred_none = close_element)
center :: proc() -> bool {
	open_element(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				childAlignment = {x = .Center, y = .Center},
			},
		},
	)
	return true
}

// Empty element that grows to fill all remaining space.
// In an `hstack` it pushes the following children to the right, in a `vstack` to the bottom.
spacer :: proc() {
	if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingGrow()}}}) {}
}

// Bordered, rounded container with a raised background.
// Fills the available width, children are stacked vertically.
@(deferred_none = close_element)
card :: proc(padding := th.Space.MD, gap := th.Space.SM) -> bool {
	c := th.current()
	open_element(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = th.pad_all(padding),
				childGap = th.sp(gap),
				layoutDirection = .TopToBottom,
			},
			backgroundColor = c.surface_0,
			cornerRadius = th.radius(.MD),
			border = th.border_box(c.border),
		},
	)
	return true
}

// Clip config for scrollable containers, to use directly in a declaration:
//   if clay.UI_AutoId()({layout = {...}, clip = kiln.scroll_clip()}) { ... }
scroll_clip :: proc(vertical := true, horizontal := false) -> clay.ClipElementConfig {
	return {horizontal = horizontal, vertical = vertical, childOffset = clay.GetScrollOffset()}
}

// Vertically scrollable container (mouse wheel). `height` is in unscaled units,
// 0 fills the available height.
@(deferred_none = close_element)
scroll_view :: proc(height: f32 = 0, gap := th.Space.XS, padding := th.Space.None) -> bool {
	open_element(
		{
			layout = {
				sizing = {
					clay.SizingGrow(),
					height > 0 ? clay.SizingFixed(th.px(height)) : clay.SizingGrow(),
				},
				padding = th.pad_all(padding),
				childGap = th.sp(gap),
				layoutDirection = .TopToBottom,
			},
			clip = scroll_clip(),
		},
	)
	return true
}

// Thin divider line in the theme's border color.
separator :: proc(vertical := false) {
	w := th.border_px()
	sizing :=
		vertical ? clay.Sizing{clay.SizingFixed(w), clay.SizingGrow()} : clay.Sizing{clay.SizingGrow(), clay.SizingFixed(w)}
	if clay.UI_AutoId()({layout = {sizing = sizing}, backgroundColor = th.current().border}) {}
}
