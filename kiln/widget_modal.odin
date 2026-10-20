package kiln

// Modal dialog: a centered card over a dimmed backdrop that blocks the rest of the UI.
// The open flag belongs to the caller; while open, the dialog's content goes into the block.

import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

@(private = "file")
close_modal :: proc() {
	clay._CloseElement() // content
	clay._CloseElement() // dialog
	clay._CloseElement() // backdrop
}

// Declares a modal dialog (width `sizes[.XL]`). While `open^` is true it draws the backdrop
// and the dialog card and returns true; put the body into the block. Set `open^` to false
// (via a button, a click on the backdrop, Escape or the close button) to hide it:
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
// Like `accordion`, the three elements are opened every frame so the deferred close stays
// balanced. While hidden they are zero-sized, transparent and not floating.
@(deferred_none = close_modal)
modal :: proc(title: string, open: ^bool, id := clay.ElementId{}) -> bool {
	c := current_theme
	eid := resolve_id(id, "modal")
	dialog_id := clay.ID("modal_card", eid.id)

	if open^ {
		if rl.IsKeyPressed(.ESCAPE) {open^ = false}
		if rl.IsMouseButtonPressed(.LEFT) && !clay.PointerOver(dialog_id) {
			open^ = false
		}
	}
	was_open := open^

	// Backdrop covers the whole layout and swallows clicks (pointer capture).
	// When hidden it collapses to zero size so it cannot block anything.
	backdrop := clay.ElementDeclaration {
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingGrow()},
			childAlignment = {x = .Center, y = .Center},
		},
		backgroundColor = color_alpha(c.bg, 0.6),
	}
	if was_open {
		backdrop.floating = {
			attachTo           = .Root,
			attachment         = {element = .CenterCenter, parent = .CenterCenter},
			zIndex             = 250,
			pointerCaptureMode = .Capture,
		}
	} else {
		backdrop.layout.sizing = {clay.SizingFixed(0), clay.SizingFixed(0)}
		backdrop.backgroundColor = {}
	}
	clay._OpenElement()
	clay.ConfigureOpenElement(backdrop)

	box := clay.ElementDeclaration {
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingFixed(size_px(.XL)), clay.SizingFit()},
		},
		backgroundColor = c.surface_0,
		cornerRadius = radius(.LG),
		border = border_box(c.border_strong),
	}
	if !was_open {
		box.layout.sizing = {clay.SizingFixed(0), clay.SizingFixed(0)}
		box.backgroundColor = {}
		box.border = {}
	}
	// The card needs its ID, otherwise `clay.PointerOver(dialog_id)` above never matches.
	clay._OpenElementWithId(dialog_id)
	clay.ConfigureOpenElement(box)

	// Title row with a close button on the right.
	// NOTE: not `was_open && clay.UI_AutoId()(...)` — the deferred open/close of UI_AutoId
	// must sit in its own `if` so it is skipped entirely while the modal is hidden.
	if was_open {
		if clay.UI_AutoId()(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = pad_xy(.LG, .MD),
				childGap = sp(.SM),
				childAlignment = {y = .Center},
			},
		},
		) {
			clay.Text(title, text_style(.Subtitle, c.text))
			if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(0)}}}) {}

			close_id := clay.ID("modal_x", eid.id)
			s := interact(close_id)
			if s.clicked {open^ = false}
			h := anim(close_id, 0, s.hovered ? 1 : 0)
			if clay.UI(close_id)(
			{
				layout = {
					sizing = {clay.SizingFit(), clay.SizingFit()},
					padding = pad_xy(.SM, .SM),
					childAlignment = {x = .Center, y = .Center},
				},
				backgroundColor = color_lerp(color_alpha(c.surface_1, 0), c.surface_1, h),
				cornerRadius = radius(.SM),
			},
			) {
				clay.Text("x", text_style(.Body, c.text_muted))
			}
		}
	}

	// Content container stays open until the deferred close at the caller's scope end.
	// While hidden it is empty and zero-sized, so the `if` body is skipped anyway.
	content := clay.ElementDeclaration {
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			padding = pad_xy(.LG, .MD),
			childGap = sp(.SM),
		},
	}
	if !was_open {
		content.layout.sizing = {clay.SizingFixed(0), clay.SizingFixed(0)}
		content.layout.padding = {}
	}
	clay._OpenElement()
	clay.ConfigureOpenElement(content)
	return was_open
}
