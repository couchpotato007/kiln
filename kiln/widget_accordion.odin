package kiln

import clay "lib:kiln/clay-odin"

@(private = "file")
close_two :: proc() {
	clay._CloseElement()
	clay._CloseElement()
}

// Open/closed state of every accordion, keyed by the header ID. This is pure UI state,
// so it lives here and not in the caller's model (same as popups and animations).
@(private = "file")
g_accordion_open: map[u32]bool

// Declares a collapsible section (bordered card with a clickable header).
// Clicking the header toggles it; `default_open` is only the initial state, afterwards the
// widget remembers the user's choice.
// Returns the open state, so use it like `clay.UI` and put the content into the block:
//
//   if kiln.accordion("Title") {
//       kiln.label("Only visible while open")
//   }
//
// Without `id` the ID is derived from the title, so equal titles in the same parent need an `id`.
@(deferred_none = close_two)
accordion :: proc(title: string, default_open := false, id := clay.ElementId{}) -> bool {
	c := current_theme
	eid := resolve_id(id, title)

	open, known := g_accordion_open[eid.id]
	if !known {open = default_open}

	clay._OpenElement()
	clay.ConfigureOpenElement(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
			},
			backgroundColor = c.surface_0,
			cornerRadius = radius(.MD),
			border = border_box(c.border),
		},
	)

	s := interact(eid)
	if s.clicked {open = !open}
	g_accordion_open[eid.id] = open
	h := anim(eid, 0, s.hovered ? 1 : 0)

	// Keep the header corners in line with the outer border radius.
	r := radius(.MD).topLeft
	hover_bg := color_lerp(color_alpha(c.surface_1, 0), c.surface_1, h)
	corners := open ? clay.CornerRadius{topLeft = r, topRight = r} : clay.CornerRadiusAll(r)

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			padding = pad_xy(.MD, .SM),
			childGap = sp(.SM),
			childAlignment = {y = .Center},
		},
		backgroundColor = hover_bg,
		cornerRadius = corners,
	},
	) {
		clay.Text(title, text_style(.Body, c.text))
		if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(0)}}}) {}
		clay.Text(open ? "v" : ">", text_style(.Body, c.text_muted))
	}

	// The content container always exists so that the deferred close stays balanced.
	// While closed it has no padding and no children and therefore takes no space.
	content := clay.ElementDeclaration {
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
		},
	}
	if open {
		content.layout.padding = pad_xy(.MD, .SM)
		content.layout.childGap = sp(.SM)
	}
	clay._OpenElement()
	clay.ConfigureOpenElement(content)
	return open
}
