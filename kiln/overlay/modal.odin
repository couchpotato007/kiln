package overlay

// Modal dialog: a centered card over a dimmed backdrop that blocks the rest of the UI.
// The open flag belongs to the caller; while open, the dialog's content goes into the block.

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"
import rl "vendor:raylib"

@(private)
close_modal :: proc(title: string, open: ^bool, id: clay.ElementId, was_open: bool) {
	if !was_open {return}
	clay._CloseElement() // content
	clay._CloseElement() // dialog
	clay._CloseElement() // backdrop
}

// Declares a modal dialog (width `sizes[.Dialog]`). While `open^` is true it draws the backdrop
// and the dialog card and returns true; put the body into the block. Set `open^` to false
// (via a button, a click on the backdrop, Escape or the close button) to hide it. While hidden
// it returns false and creates no elements at all:
//
//   if kiln.modal("Löschen?", &m.confirm_open) {
//       kiln.label("Der Eintrag wird dauerhaft entfernt.")
//       if kiln.hstack(.SM) {
//           kiln.spacer()
//           if kiln.button("Abbrechen", .Ghost) {m.confirm_open = false}
//           if kiln.button("Löschen", .Danger) {append(out, Delete{})}
//       }
//   }
//
// Declare the modal last in a view so it floats above everything else.
@(deferred_in_out = close_modal)
modal :: proc(title: string, open: ^bool, id := clay.ElementId{}) -> bool {
	if !open^ {return false}

	c := th.current()
	eid := fd.resolve_id(id, "modal")
	dialog_id := fd.child_id(eid, "dialog")

	// Close on Escape or on a press outside the dialog. The dialog has to exist from a previous
	// frame, otherwise the press that opened the modal would close it again.
	if rl.IsKeyPressed(.ESCAPE) {open^ = false}
	if rl.IsMouseButtonPressed(.LEFT) &&
	   clay.GetElementData(dialog_id).found &&
	   !clay.PointerOver(dialog_id) {
		open^ = false
	}
	if !open^ {return false}

	// The backdrop covers the whole layout and swallows clicks (pointer capture).
	clay._OpenElement()
	clay.ConfigureOpenElement(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = th.color_alpha(c.bg, c.backdrop_alpha),
			floating = {
				attachTo = .Root,
				attachment = {element = .CenterCenter, parent = .CenterCenter},
				zIndex = fd.Z_MODAL,
				pointerCaptureMode = .Capture,
			},
		},
	)

	clay._OpenElementWithId(dialog_id)
	clay.ConfigureOpenElement(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingFixed(th.size_px(.Dialog)), clay.SizingFit()},
			},
			backgroundColor = c.surface_0,
			cornerRadius = th.radius(.LG),
			border = th.border_box(c.border_strong),
		},
	)

	// Title row with a close button on the right.
	if clay.UI_AutoId()(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			padding = th.pad_xy(.LG, .MD),
			childGap = th.sp(.SM),
			childAlignment = {y = .Center},
		},
	},
	) {
		clay.Text(title, th.text_style(.Subtitle, c.text))
		if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(0)}}}) {}

		close_id := fd.child_id(eid, "close")
		s := fd.interact(close_id)
		if s.clicked {open^ = false}
		h := fd.anim(close_id, 0, s.hovered ? 1 : 0)
		if clay.UI(close_id)(
		{
			layout = {
				sizing = {clay.SizingFit(), clay.SizingFit()},
				padding = th.pad_all(.SM),
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = th.color_mix(th.color_alpha(c.surface_1, 0), c.surface_1, h),
			cornerRadius = th.radius(.SM),
		},
		) {
			clay.Text("x", th.text_style(.Body, c.text_muted))
		}
	}

	// Content container, closed together with the dialog and the backdrop by `close_modal`.
	clay._OpenElement()
	clay.ConfigureOpenElement(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = th.pad_xy(.LG, .MD),
				childGap = th.sp(.SM),
			},
		},
	)
	return true
}
