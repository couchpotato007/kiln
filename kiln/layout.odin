package kiln

// Containers. All of them are used as the condition of an `if` that holds the children:
//
//   if kiln.column(.MD) {
//       kiln.text("Titel", .Title)
//       if kiln.row() {
//           kiln.button("Abbrechen", .Ghost)
//           kiln.spacer()
//           kiln.button("OK")
//       }
//   }
//
// Responsive containers measure the width they got in the previous frame:
//   grid      as many equal columns as fit, every child container becomes a cell
//   adaptive  a row, or a column (with full-width children) when narrower than `min_width`
//   field     label left of the control, or above it when narrow
//   actions   right-aligned buttons, stacked and full width on compact screens

import clay "clay-odin"

// Which axes of a container grow to fill the available space; the others fit the content.
Fill :: enum {
	None,
	Width,
	Height,
	Both,
}

// Alignment of the children on the cross axis (horizontal in a column, vertical in a row).
Align :: enum {
	Start,
	Center,
	End,
}

// ---------------------------------------------------------------------------
// Box stack
// ---------------------------------------------------------------------------

@(private)
BoxKind :: enum {
	Plain,
	Grid,
	Flow,
	Adaptive,
	Actions,
	Field,
}

@(private)
Box :: struct {
	id:         Id,
	state:      Interaction,
	kind:       BoxKind,
	horizontal: bool,
	extra:      int, // inner elements that are closed together with the box
	stacked:    bool, // Adaptive / Actions: children are stacked vertically and fill the width
	columns:    int, // Grid
	count:      int, // Grid: cells so far; Flow: children so far
	gap:        u16, // Grid, Flow
	error:      bool, // Field: the controls inside get a danger border
	line:       u32, // Flow: the element children go into (the current line)
	line_x:     f32, // Flow: width taken in the current line
	avail:      f32, // Flow: width of the flow in the previous frame
}

@(private)
g_boxes: [dynamic]Box

// Number of cells of each grid in the previous frame, to balance the rows.
@(private)
g_grid_cells: map[u32]int

// z-index for floating elements declared inside the current overlay / popup.
@(private)
g_z: i16

@(private)
Z_POPUP :: 100
@(private)
Z_OVERLAY :: 200
@(private)
Z_TOAST :: 900
@(private)
Z_TOOLTIP :: 1000

@(private)
parent_box :: proc() -> ^Box {
	if len(g_boxes) == 0 {return nil}
	return &g_boxes[len(g_boxes) - 1]
}

// Opens a container and pushes it on the box stack. Children of a grid become cells, children
// of a stacked adaptive / actions fill the width. Clipping containers scroll.
@(private)
open_box :: proc(
	eid: Id,
	decl: clay.ElementDeclaration,
	state := Interaction{},
	kind := BoxKind.Plain,
) -> ^Box {
	d := decl
	if p := parent_box(); p != nil {
		switch p.kind {
		case .Grid:
			if p.count % p.columns == 0 {
				if p.count > 0 {clay._CloseElement()}
				clay._OpenElement()
				clay.ConfigureOpenElement(
					{layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, childGap = p.gap}},
				)
			}
			p.count += 1
			d.layout.sizing = {clay.SizingPercent(1 / f32(p.columns)), clay.SizingGrow()}
		case .Flow:
			flow_item(eid)
		case .Adaptive, .Actions:
			if p.stacked {d.layout.sizing.width = clay.SizingGrow()}
		case .Plain, .Field:
		}
	}

	clay._OpenElementWithId(eid)
	// The scroll offset refers to the open element, so it can only be read after opening.
	if d.clip.vertical || d.clip.horizontal {d.clip.childOffset = clay.GetScrollOffset()}
	clay.ConfigureOpenElement(d)

	append(
		&g_boxes,
		Box {
			id = eid,
			state = state,
			kind = kind,
			horizontal = d.layout.layoutDirection == .LeftToRight,
		},
	)
	return &g_boxes[len(g_boxes) - 1]
}

@(private)
close_box :: proc() {
	b := pop(&g_boxes)
	if b.kind == .Grid {
		// Empty cells fill up the last row: Clay takes percentages of the width without the
		// gaps between the children, so a shorter row would get wider cells.
		if b.count > 0 && b.count % b.columns != 0 {
			for _ in 0 ..< b.columns - b.count % b.columns {
				w := clay.SizingPercent(1 / f32(b.columns))
				if clay.UI()({layout = {sizing = {w, clay.SizingFit()}}}) {}
			}
		}
		if b.count > 0 {clay._CloseElement()} // last row
		g_grid_cells[b.id.id] = b.count
	}
	if b.kind == .Flow && b.count > 0 {clay._CloseElement()} // last line
	for _ in 0 ..< b.extra {clay._CloseElement()}
	clay._CloseElement()
	g_last = {id = b.id, state = b.state}
}

@(private)
close_box_if :: proc(ok: bool) {
	if ok {close_box()}
}

// Width of an element in the previous frame in pixels (the window width before it first
// appeared). Responsive widgets decide their layout from it.
element_width :: proc(eid: Id) -> f32 {
	d := clay.GetElementData(eid)
	return d.found ? d.boundingBox.width : g_in.window.x
}

// Position and size of an element in the previous frame in pixels, e.g. for widgets that place
// floating children themselves. `found` is false before the element was first laid out.
element_rect :: proc(eid: Id) -> (x, y, w, h: f32, found: bool) {
	d := clay.GetElementData(eid)
	b := d.boundingBox
	return b.x, b.y, b.width, b.height, d.found
}

@(private)
fill_sizing :: proc(fill: Fill, width: f32 = 0, max_width: f32 = 0) -> clay.Sizing {
	s := clay.Sizing{clay.SizingFit(), clay.SizingFit()}
	if fill == .Width || fill == .Both {
		s.width = clay.SizingGrow({max = max_width > 0 ? px(max_width) : 0})
	}
	if fill == .Height || fill == .Both {s.height = clay.SizingGrow()}
	if width > 0 {s.width = clay.SizingFixed(px(width))}
	return s
}

@(private)
align_x :: proc(a: Align) -> clay.LayoutAlignmentX {
	switch a {
	case .Start:
		return .Left
	case .Center:
		return .Center
	case .End:
		return .Right
	}
	return .Left
}

@(private)
align_y :: proc(a: Align) -> clay.LayoutAlignmentY {
	switch a {
	case .Start:
		return .Top
	case .Center:
		return .Center
	case .End:
		return .Bottom
	}
	return .Top
}

// ---------------------------------------------------------------------------
// Basic containers
// ---------------------------------------------------------------------------

// Children top to bottom. Fills the width and fits the content's height by default;
// `width` (units) gives it a fixed width instead, `max_width` caps a growing width.
@(deferred_none = close_box)
column :: proc(
	gap := Space.SM,
	padding := Space.None,
	fill := Fill.Width,
	align := Align.Start,
	width: f32 = 0,
	bg := Surface.None,
	max_width: f32 = 0,
) -> bool {
	open_box(
		id("column"),
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = fill_sizing(fill, width, max_width),
				padding = inset(padding),
				childGap = space(gap),
				childAlignment = {x = align_x(align)},
			},
			backgroundColor = surface_color(bg),
		},
	)
	return true
}

// Children left to right, vertically centered by default.
@(deferred_none = close_box)
row :: proc(
	gap := Space.SM,
	padding := Space.None,
	fill := Fill.Width,
	align := Align.Center,
	width: f32 = 0,
	bg := Surface.None,
) -> bool {
	open_box(
		id("row"),
		{
			layout = {
				layoutDirection = .LeftToRight,
				sizing = fill_sizing(fill, width),
				padding = inset(padding),
				childGap = space(gap),
				childAlignment = {y = align_y(align)},
			},
			backgroundColor = surface_color(bg),
		},
	)
	return true
}

// Fills the available space and centers its children both ways.
@(deferred_none = close_box)
center :: proc(gap := Space.SM) -> bool {
	open_box(
		id("center"),
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				childGap = space(gap),
				childAlignment = {x = .Center, y = .Center},
			},
		},
	)
	return true
}

// Takes all remaining space: in a row it pushes the following children to the right,
// in a column to the bottom.
spacer :: proc() {
	if clay.UI()({layout = {sizing = {clay.SizingGrow(), clay.SizingGrow()}}}) {}
}

// A thin line in the border color; vertical inside a row, horizontal everywhere else.
separator :: proc() {
	p := parent_box()
	rule(vertical = p != nil && p.horizontal)
}

// A line in the border color for widgets that build their insides with Clay directly (there is
// no box to ask for the direction, so it is given).
rule :: proc(vertical := false) {
	w := line_width()
	sizing := clay.Sizing{clay.SizingGrow(), clay.SizingFixed(w)}
	if vertical {sizing = {clay.SizingFixed(w), clay.SizingGrow()}}
	if clay.UI()({layout = {sizing = sizing}, backgroundColor = g_theme.border}) {}
}

// A bordered, raised container with an optional title. Fills the width.
@(deferred_none = close_box)
card :: proc(title := "", gap := Space.SM, padding := Space.MD) -> bool {
	c := &g_theme
	open_box(
		id(len(title) > 0 ? title : "card"),
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = inset(padding),
				childGap = space(gap),
			},
			backgroundColor = c.surface,
			cornerRadius = corners(.MD),
			border = outline(c.border),
		},
	)
	if len(title) > 0 {text(title, .Subtitle)}
	return true
}

// A vertically scrolling container (mouse wheel or the scroll bar). It fills the available
// space; `height` (units) gives it a fixed height instead.
@(deferred_none = scroll_end)
scroll :: proc(gap := Space.SM, padding := Space.None, height: f32 = 0) -> bool {
	eid := id("scroll")
	h := height > 0 ? clay.SizingFixed(px(height)) : clay.SizingGrow()
	// The outer element carries the scroll bar, the inner one clips and scrolls.
	b := open_box(eid, {layout = {sizing = {clay.SizingGrow(), h}}})
	b.extra = 1
	content := sub_id(eid, "content")
	scrollable(content)
	clay._OpenElementWithId(content)
	clay.ConfigureOpenElement(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				padding = inset(padding),
				childGap = space(gap),
			},
			clip = {vertical = true, childOffset = clay.GetScrollOffset()},
		},
	)
	return true
}

@(private)
scroll_end :: proc() {
	b := &g_boxes[len(g_boxes) - 1]
	clay._CloseElement() // content
	b.extra = 0
	scroll_bar(b.id, sub_id(b.id, "content"))
	close_box()
}

// Vertical scroll containers of this and the previous frame. kiln routes the mouse wheel itself:
// Clay gives it to the innermost clipping element, which may only clip horizontally (a table,
// a text field) and would swallow it.
@(private)
g_scrollers, g_scrollers_prev: map[u32]bool

@(private)
scrollable :: proc(eid: Id) {
	g_scrollers[eid.id] = true
}

// Scrolls the innermost vertical scroll container under the pointer that can still move;
// at its end the wheel goes on to the container around it.
@(private)
wheel_scroll :: proc() {
	g_scrollers, g_scrollers_prev = g_scrollers_prev, g_scrollers
	clear(&g_scrollers)
	if g_in.wheel.y == 0 {return}

	over := clay.GetPointerOverIds()
	for i := over.length - 1; i >= 0; i -= 1 {
		eid := over.internalArray[i]
		if !g_scrollers_prev[eid.id] {continue}
		d := clay.GetScrollContainerData(eid)
		if !d.found || d.scrollPosition == nil {continue}
		lowest := min(0, d.scrollContainerDimensions.height - d.contentDimensions.height)
		y := clamp(d.scrollPosition.y + g_in.wheel.y, lowest, 0)
		if y != d.scrollPosition.y {
			d.scrollPosition.y = y
			return
		}
	}
}

@(private)
g_thumb_grab: f32 // where the scroll thumb was grabbed, relative to its top

// A thumb on the right edge of `outer` that shows and drags the position of `content`.
@(private)
scroll_bar :: proc(outer, content: Id) {
	data := clay.GetScrollContainerData(content)
	if !data.found || data.scrollPosition == nil {return}
	view := data.scrollContainerDimensions.height
	total := data.contentDimensions.height
	if total <= view + 1 {return}

	thumb := max(px(28), view * view / total)
	travel := view - thumb
	range := total - view
	pos := clamp(-data.scrollPosition.y, 0, range)

	tid := sub_id(outer, "thumb")
	s := interact(tid)
	if s.held {
		top := clay.GetElementData(outer).boundingBox.y
		if .Left in g_in.pressed {g_thumb_grab = g_in.mouse.y - (top + pos / range * travel)}
		t := clamp((g_in.mouse.y - top - g_thumb_grab) / max(travel, 1), 0, 1)
		pos = t * range
		data.scrollPosition.y = -pos
	}

	h := anim(tid, 0, (s.hovered || s.held) ? 1 : 0)
	w := px(6)
	if clay.UI(tid)(
	{
		layout = {sizing = {clay.SizingFixed(w), clay.SizingFixed(thumb)}},
		backgroundColor = fade(g_theme.border_strong, 0.45 + 0.55 * h),
		cornerRadius = clay.CornerRadiusAll(w / 2),
		floating = {
			attachTo = .Parent,
			attachment = {element = .RightTop, parent = .RightTop},
			offset = {-px(2), pos / range * travel},
			zIndex = g_z + 1,
		},
	},
	) {}
}

// ---------------------------------------------------------------------------
// Responsive containers
// ---------------------------------------------------------------------------

// A grid of equal columns, each at least `min_width` units wide. Every container declared
// directly inside (card, column, list_item, ...) becomes a cell; cells in a row share its height.
// The rows are balanced: 4 cells where 3 columns fit give 2 x 2, not 3 + 1.
//
//   if kiln.grid(220) {
//       for s in stats {
//           if kiln.card(s.title) { ... }
//       }
//   }
@(deferred_none = close_box)
grid :: proc(min_width: f32, gap := Space.MD) -> bool {
	eid := id("grid")
	g := space(gap)
	columns := max(1, int((element_width(eid) + f32(g)) / (px(min_width) + f32(g))))
	if n := g_grid_cells[eid.id]; n > 0 {
		rows := (n + columns - 1) / columns
		columns = (n + rows - 1) / rows
	}
	b := open_box(
		eid,
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				childGap = g,
			},
		},
		kind = .Grid,
	)
	b.columns = columns
	b.gap = g
	return true
}

// A row of children while it is at least `min_width` units wide, otherwise a column. When
// stacked, child containers fill the width even if they have a fixed `width` in row mode:
//
//   if kiln.adaptive(720) {
//       if kiln.column(fill = .Width) { ... }     // main content
//       if kiln.column(width = 280) { ... }       // side panel, full width when stacked
//   }
@(deferred_none = close_box)
adaptive :: proc(min_width: f32, gap := Space.MD, fill := Fill.Width) -> bool {
	eid := id("adaptive")
	stacked := element_width(eid) < px(min_width)
	b := open_box(
		eid,
		{
			layout = {
				layoutDirection = stacked ? .TopToBottom : .LeftToRight,
				sizing = fill_sizing(fill),
				childGap = space(gap),
			},
		},
		kind = .Adaptive,
	)
	b.stacked = stacked
	return true
}

// True inside a `field` that shows an error; its controls draw a danger border.
@(private)
field_error :: proc() -> bool {
	#reverse for b in g_boxes {
		if b.kind == .Field {return b.error}
	}
	return false
}

// Children left to right; a child that does not fit into the line any more starts a new one
// (chips, badges, legends, tags). Clay cannot wrap, so the lines are built from the children's
// widths in the previous frame; in the first frame everything is in one line.
//
// Containers and these widgets declared directly inside take part: button, badge, chip, avatar,
// checkbox, toggle, radio, swatch, spinner and text.
//
//   if kiln.flow() {
//       for t in m.tags {kiln.badge(t, .Primary)}
//   }
@(deferred_none = close_box)
flow :: proc(gap := Space.SM, row_gap := Space.SM) -> bool {
	eid := id("flow")
	d := clay.GetElementData(eid)
	b := open_box(
		eid,
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				childGap = space(row_gap),
			},
			// Without the clip an overlong line would widen the flow, and it would never wrap.
			clip = {horizontal = true},
		},
		kind = .Flow,
	)
	b.gap = space(gap)
	b.avail = d.found ? d.boundingBox.width : max(f32)
	b.line = clay.GetOpenElementId()
	return true
}

// Places the next child of a flow: opens a new line when it would not fit into the current one.
// kiln's widgets call it themselves; custom widgets call it before opening their element so
// they wrap inside a `flow` too. `width` < 0 takes the element's width from the previous frame.
// Only children declared directly in the flow's current line count, so widgets used inside
// other widgets are not affected.
flow_item :: proc(eid: Id, width: f32 = -1) {
	p := parent_box()
	if p == nil || p.kind != .Flow || clay.GetOpenElementId() != p.line {return}
	w := width
	if w < 0 {
		d := clay.GetElementData(eid)
		w = d.found ? d.boundingBox.width : 0
	}
	gap := f32(p.gap)
	if p.count == 0 || p.line_x + gap + w > p.avail {
		if p.count > 0 {clay._CloseElement()}
		clay._OpenElement()
		clay.ConfigureOpenElement(
			{layout = {sizing = {clay.SizingFit(), clay.SizingFit()}, childGap = p.gap, childAlignment = {y = .Center}}},
		)
		p.line = clay.GetOpenElementId()
		p.line_x = w
	} else {
		p.line_x += gap + w
	}
	p.count += 1
}

// True while the innermost `adaptive` is stacked (a column), e.g. to choose a different layout.
stacked :: proc() -> bool {
	#reverse for b in g_boxes {
		if b.kind == .Adaptive {return b.stacked}
	}
	return false
}

// A form row: the label (and an optional help text) on the left and the controls declared in
// the block on the right. When the row is narrow, the label moves above the controls.
//
//   if kiln.field("Sprache", "Gilt für alle Fenster") {
//       if v, ok := kiln.select(m.language, LANGUAGES[:]); ok { ... }
//   }
//
// A non-empty `error` is shown instead of the help text, in the danger color, and gives the text
// fields, selects and date fields in the block a danger border:
//
//   if kiln.field("E-Mail", error = valid(m.email) ? "" : "Keine gültige Adresse") { ... }
@(deferred_none = close_box)
field :: proc(label: string, help := "", error := "") -> bool {
	eid := id(label)
	label_w := size(.Control) * 6 // room for about 20 characters of body text
	narrow := element_width(eid) < label_w * 2.4

	b := open_box(
		eid,
		{
			layout = {
				layoutDirection = narrow ? .TopToBottom : .LeftToRight,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				childGap = narrow ? space(.XS) : space(.LG),
			},
		},
		kind = .Field,
	)
	b.error = len(error) > 0

	// In a row, center the first label line on the first control line.
	top: u16 = 0
	if !narrow {top = u16(max(0, (size(.Control) - f32(font_size(.Body))) / 2))}
	if clay.UI(sub_id(eid, "label"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {narrow ? clay.SizingGrow() : clay.SizingFixed(label_w), clay.SizingFit()},
			padding = {top = top},
			childGap = space(.XS) / 2,
		},
	},
	) {
		text(label, .Body)
		if len(error) > 0 {
			text(error, .Caption, .Danger)
		} else if len(help) > 0 {
			text(help, .Caption, .Muted)
		}
	}

	clay._OpenElement()
	clay.ConfigureOpenElement(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				childGap = space(.SM),
			},
		},
	)
	b.extra = 1
	return true
}

// A row of buttons aligned to the end (dialog and form footers). On compact screens the buttons
// are stacked and fill the width.
@(deferred_none = close_box)
actions :: proc() -> bool {
	stacked := screen() == .Compact
	b := open_box(
		id("actions"),
		{
			layout = {
				layoutDirection = stacked ? .TopToBottom : .LeftToRight,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				childGap = space(.SM),
				childAlignment = {x = .Right, y = .Center},
			},
		},
		kind = .Actions,
	)
	b.stacked = stacked
	return true
}

// ---------------------------------------------------------------------------
// Interactive containers
// ---------------------------------------------------------------------------

// Open state of collapsible sections, keyed by id. It survives the section being hidden.
@(private)
g_expanded: map[u32]bool

// A bordered section with a clickable header that shows or hides the content. `open` is the
// initial state, afterwards the section remembers the user's choice. Returns whether it is open:
//
//   if kiln.collapsible("Erweitert") { ... }
@(deferred_none = close_box)
collapsible :: proc(title: string, open := false) -> bool {
	c := &g_theme
	eid := id(title)
	header := sub_id(eid, "header")

	is_open, known := g_expanded[eid.id]
	if !known {is_open = open}
	s := interact(header)
	if s.clicked {is_open = !is_open}
	g_expanded[eid.id] = is_open
	h := anim(header, 0, s.hovered ? 1 : 0)

	b := open_box(
		eid,
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
			},
			backgroundColor = c.surface,
			cornerRadius = corners(.MD),
			border = outline(c.border),
		},
	)

	r := radius(.MD)
	if clay.UI(header)(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			padding = inset(.MD, .SM),
			childGap = space(.SM),
			childAlignment = {y = .Center},
		},
		backgroundColor = mix(fade(c.surface_hover, 0), c.surface_hover, h),
		cornerRadius = is_open ? {topLeft = r, topRight = r} : clay.CornerRadiusAll(r),
	},
	) {
		icon_element(is_open ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT, .Caption, g_theme.text_muted)
		text(title, .Body)
	}

	if is_open {
		clay._OpenElement()
		clay.ConfigureOpenElement(
			{
				layout = {
					layoutDirection = .TopToBottom,
					sizing = {clay.SizingGrow(), clay.SizingFit()},
					padding = inset(.MD),
					childGap = space(.SM),
				},
			},
		)
		b.extra = 1
	}
	return is_open
}

// A clickable row (list entries, navigation, master lists). Ask `kiln.clicked()` after the block:
//
//   if kiln.list_item(i == m.selected) {
//       kiln.avatar(p.name)
//       kiln.text(p.name)
//   }
//   if kiln.clicked() {append(out, Select{i})}
@(deferred_none = close_box)
list_item :: proc(selected := false, disabled := false) -> bool {
	c := &g_theme
	eid := id("list_item")
	s := interact(eid, disabled)
	h := anim(eid, 0, s.hovered ? 1 : 0)

	bg := mix(fade(c.surface_hover, 0), c.surface_hover, h)
	if selected {bg = mix(tone_tint(.Primary), fade(c.primary, c.tint_alpha * 1.6), h)}
	if s.pressed {bg = c.surface_active}

	open_box(
		eid,
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = inset(.MD, .SM),
				childGap = space(.MD),
				childAlignment = {y = .Center},
			},
			backgroundColor = bg,
			cornerRadius = corners(.MD),
		},
		s,
	)
	return true
}
