package layout

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"

// Open/closed state of every accordion, keyed by the header id. This is pure UI state,
// so it lives here and not in the caller's model (same as popups and animations).
@(private)
g_open: map[u32]bool

@(private)
close_accordion :: proc(title: string, default_open: bool, id: clay.ElementId, open: bool) {
	if open {clay._CloseElement()} // content
	clay._CloseElement() // card
}

// Declares a collapsible section (bordered card with a clickable header).
// Clicking the header toggles it; `default_open` is only the initial state, afterwards the
// widget remembers the user's choice. Returns the open state, so use it like `clay.UI`
// and put the content into the block:
//
//   if kiln.accordion("Title") {
//       kiln.label("Only visible while open")
//   }
//
// Without `id` the id is derived from the title, so equal titles in the same parent need an `id`.
@(deferred_in_out = close_accordion)
accordion :: proc(title: string, default_open := false, id := clay.ElementId{}) -> bool {
	c := th.current()
	eid := fd.resolve_id(id, title)

	open, known := g_open[eid.id]
	if !known {open = default_open}

	open_element(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
			},
			backgroundColor = c.surface_0,
			cornerRadius = th.radius(.MD),
			border = th.border_box(c.border),
		},
	)

	s := fd.interact(eid)
	if s.clicked {open = !open}
	g_open[eid.id] = open
	h := fd.anim(eid, 0, s.hovered ? 1 : 0)

	// Keep the header corners in line with the outer border radius.
	r := th.radius(.MD).topLeft
	corners := open ? clay.CornerRadius{topLeft = r, topRight = r} : clay.CornerRadiusAll(r)

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			padding = th.pad_xy(.MD, .SM),
			childGap = th.sp(.SM),
			childAlignment = {y = .Center},
		},
		backgroundColor = th.color_mix(th.color_alpha(c.surface_1, 0), c.surface_1, h),
		cornerRadius = corners,
	},
	) {
		clay.Text(title, th.text_style(.Body, c.text))
		spacer()
		clay.Text(open ? "v" : ">", th.text_style(.Body, c.text_muted))
	}

	// The content container only exists while open, `close_accordion` mirrors that.
	if open {
		open_element(
			{
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {clay.SizingGrow(), clay.SizingFit()},
					padding = th.pad_xy(.MD, .SM),
					childGap = th.sp(.SM),
				},
			},
		)
	}
	return open
}
