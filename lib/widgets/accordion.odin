package widgets

import clay "lib:clay-odin"
import "lib:theme"

@(private = "file")
close_two :: proc() {
	clay._CloseElement()
	clay._CloseElement()
}

// Open/closed state of every accordion, keyed by the header ID. This is pure UI state,
// so it lives here and not in the caller's model (same as popups and animations).
@(private = "file")
g_accordion_open: map[u32]bool

// Appearance of an accordion section. Create it with `style_accordion`.
AccordionConfig :: struct {
	id:           clay.ElementId, // ID of the clickable header
	box:          clay.ElementDeclaration, // outer container (background, border, radius)
	header:       clay.ElementDeclaration, // header row layout
	content:      clay.ElementDeclaration, // layout of the content area (padding is dropped while closed)
	text:         clay.TextElementConfig, // title
	arrow_color:  clay.Color,
	header_hover: clay.Color, // header background while hovered (faded in)
	default_open: bool, // initial state, afterwards the widget remembers the user's choice
}

// Accordion look from the current theme: a bordered card with a clickable header.
style_accordion :: proc(id: clay.ElementId, default_open := false) -> AccordionConfig {
	c := theme.current
	return {
		id = id,
		box = {
			layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}},
			backgroundColor = c.surface_0,
			cornerRadius = theme.radius(.MD),
			border = theme.border_box(c.border),
		},
		header = {
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = theme.pad_xy(.MD, .SM),
				childGap = theme.sp(.SM),
				childAlignment = {y = .Center},
			},
		},
		content = {
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = theme.pad_xy(.MD, .SM),
				childGap = theme.sp(.SM),
			},
		},
		text = theme.text_style(.Body, c.text),
		arrow_color = c.text_muted,
		header_hover = c.surface_1,
		default_open = default_open,
	}
}

// Declares a collapsible section. Clicking the header toggles it.
// Returns the open state, so use it like `clay.UI` and put the content into the block:
//
//   if widgets.accordion("Title", widgets.style_accordion(clay.ID_LOCAL("acc"))) {
//       widgets.label("Only visible while open")
//   }
@(deferred_none = close_two)
accordion :: proc(title: string, cfg: AccordionConfig) -> bool {
	open, known := g_accordion_open[cfg.id.id]
	if !known {open = cfg.default_open}

	clay._OpenElement()
	clay.ConfigureOpenElement(cfg.box)

	s := interact(cfg.id)
	if s.clicked {open = !open}
	g_accordion_open[cfg.id.id] = open
	h := anim(cfg.id, 0, s.hovered ? 1 : 0)

	// Keep the header corners in line with the outer border radius.
	r := cfg.box.cornerRadius.topLeft
	hdr := cfg.header
	hdr.backgroundColor = color_lerp(theme.color_alpha(cfg.header_hover, 0), cfg.header_hover, h)
	hdr.cornerRadius = open ? clay.CornerRadius{topLeft = r, topRight = r} : clay.CornerRadiusAll(r)

	if clay.UI(cfg.id)(hdr) {
		clay.Text(title, cfg.text)
		if clay.UI_AutoId()({layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(0)}}}) {}
		clay.Text(open ? "v" : ">", theme.text_style(.Body, cfg.arrow_color))
	}

	// The content container always exists so that the deferred close stays balanced.
	// While closed it has no padding and no children and therefore takes no space.
	content := cfg.content
	if !open {
		content.layout.padding = {}
		content.layout.childGap = 0
	}
	clay._OpenElement()
	clay.ConfigureOpenElement(content)
	return open
}
