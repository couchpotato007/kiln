package kiln

// Tooltips, menus and context menus. Tooltips and context menus attach to the last item.

import clay "clay-odin"

// ---------------------------------------------------------------------------
// Tooltip
// ---------------------------------------------------------------------------

@(private)
HoverStart :: struct {
	time:  f64,
	frame: u64,
}

@(private)
g_hover_start: map[u32]HoverStart

// Where a tooltip appears: above the anchor (below if there is no room) or to its right.
TooltipSide :: enum {
	Top,
	Right,
}

// Shows `label` in a bubble next to the last item after the pointer rested on it for the
// theme's `tooltip_delay`:
//
//   kiln.button("Speichern")
//   kiln.tooltip("Strg+S")
tooltip :: proc(label: string) {
	tooltip_on(g_last.id, label, .Top)
}

// A tooltip for any element (parts of custom widgets, chart bars, ...), not only the last item.
// Call it every frame after declaring the element.
tooltip_on :: proc(anchor: Id, label: string, side := TooltipSide.Top) {
	if anchor.id == 0 || len(label) == 0 {return}
	if !clay.PointerOver(anchor) || g_active != 0 {
		delete_key(&g_hover_start, anchor.id)
		return
	}
	start, seen := g_hover_start[anchor.id]
	if !seen {start.time = g_in.time}
	g_hover_start[anchor.id] = {start.time, g_frame}
	if g_in.time - start.time < f64(g_theme.tooltip_delay) {return}

	a := clay.GetElementData(anchor)
	if !a.found {return}
	tid := sub_id(anchor, "tooltip")
	tip := clay.GetElementData(tid)
	gap := f32(space(.XS))
	margin := f32(space(.SM))

	// Above the anchor (below if there is no room), kept inside the window horizontally.
	floating := clay.FloatingElementConfig {
		attachTo           = .ElementWithId,
		parentId           = anchor.id,
		zIndex             = Z_TOOLTIP,
		pointerCaptureMode = .Passthrough,
	}
	switch side {
	case .Top:
		above := !tip.found || a.boundingBox.y - tip.boundingBox.height - gap >= 0
		floating.attachment =
			above ? {element = .CenterBottom, parent = .CenterTop} : {element = .CenterTop, parent = .CenterBottom}
		floating.offset.y = above ? -gap : gap
		if tip.found {
			w := tip.boundingBox.width
			left := a.boundingBox.x + a.boundingBox.width / 2 - w / 2
			floating.offset.x = clamp(left, margin, max(margin, g_in.window.x - w - margin)) - left
		}
	case .Right:
		floating.attachment = {element = .LeftCenter, parent = .RightCenter}
		floating.offset.x = gap
	}

	style := font(.Caption, g_theme.text)
	style.wrapMode = .None
	if clay.UI(tid)(
	{
		layout = {padding = inset(.SM, .XS)},
		backgroundColor = g_theme.surface_active,
		cornerRadius = corners(.SM),
		border = outline(g_theme.border_strong),
		floating = floating,
	},
	) {
		clay.TextDynamic(label, style)
	}
}

// ---------------------------------------------------------------------------
// Menus
// ---------------------------------------------------------------------------

// One entry of a menu. A `separator` entry draws a line and ignores the other fields.
MenuItem :: struct {
	label:     string,
	danger:    bool, // drawn in the danger color (e.g. "Löschen")
	disabled:  bool,
	separator: bool,
}

// A button that opens a list of entries below it. Returns the index of the clicked entry:
//
//   if i, ok := kiln.menu("Aktionen", ITEMS[:]); ok { ... }
//
// A single-character label ("⋯") gives a square icon button.
menu :: proc(
	label: string,
	items: []MenuItem,
	variant := ButtonVariant.Secondary,
	disabled := false,
) -> (
	index: int,
	ok: bool,
) {
	if button(label, variant, disabled) {
		popup_set(g_last.id, !popup_is_open(g_last.id))
	}
	trigger := g_last
	list := sub_id(trigger.id, "menu")
	if disabled {popup_set(trigger.id, false)}
	popup_dismiss(trigger.id, list)

	index = -1
	if popup_is_open(trigger.id) {
		b := clay.GetElementData(trigger.id).boundingBox
		menu_data := clay.GetElementData(list)
		// Right-align to the button if the list would leave the window.
		right := menu_data.found && b.x + menu_data.boundingBox.width > g_in.window.x
		index = menu_list(
			items,
			list,
			{
				attachTo = .ElementWithId,
				parentId = trigger.id.id,
				attachment = right ? {element = .RightTop, parent = .RightBottom} : {element = .LeftTop, parent = .LeftBottom},
				offset = {0, f32(space(.XS))},
			},
		)
		if index >= 0 {popup_set(trigger.id, false)}
	}
	g_last = trigger
	return index, index >= 0
}

@(private)
g_context_pos: [2]f32

// Opens a list of entries at the pointer when the last item is right-clicked. Returns the index
// of the clicked entry:
//
//   if kiln.list_item() { ... }
//   if i, ok := kiln.context_menu(ITEMS[:]); ok { ... }
context_menu :: proc(items: []MenuItem) -> (index: int, ok: bool) {
	anchor := g_last
	if anchor.id.id == 0 {return -1, false}
	list := sub_id(anchor.id, "context")

	// Interactive items get the right click through `interact`; plain ones (badges, cards) only
	// when no interactive element is under the pointer.
	opened := anchor.state.right_clicked
	if !g_interactive[anchor.id.id] {
		opened = .Right in g_in.pressed && g_right == 0 && clay.PointerOver(anchor.id)
	}
	if opened {
		g_context_pos = g_in.mouse
		popup_set(anchor.id, true)
	} else {
		popup_dismiss(anchor.id, list, keep_owner = false)
	}

	index = -1
	if popup_is_open(anchor.id) {
		// Keep the list inside the window, using its size from the previous frame.
		pos := g_context_pos
		if d := clay.GetElementData(list); d.found {
			pos.x = min(pos.x, g_in.window.x - d.boundingBox.width - f32(space(.XS)))
			pos.y = min(pos.y, g_in.window.y - d.boundingBox.height - f32(space(.XS)))
		}
		index = menu_list(
			items,
			list,
			{attachTo = .Root, attachment = {element = .LeftTop, parent = .LeftTop}, offset = pos},
		)
		if index >= 0 {popup_set(anchor.id, false)}
	}
	g_last = anchor
	return index, index >= 0
}

// The floating list of a menu with the given placement. Returns the clicked index or -1.
@(private)
menu_list :: proc(items: []MenuItem, list: Id, placement: clay.FloatingElementConfig) -> int {
	c := &g_theme
	picked := -1
	old_z := g_z
	g_z = old_z + Z_POPUP
	defer g_z = old_z

	floating := placement
	floating.zIndex = g_z
	floating.pointerCaptureMode = .Capture

	if clay.UI(list)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingFit({min = size(.Menu)})},
			padding = inset(.XS),
		},
		backgroundColor = c.surface,
		cornerRadius = corners(.MD),
		border = outline(c.border_strong),
		floating = floating,
	},
	) {
		interact(list)
		for item, i in items {
			if item.separator {
				if clay.UI()(
				{
					layout = {
						sizing = {clay.SizingGrow(), clay.SizingFixed(line_width())},
					},
					backgroundColor = c.border,
				},
				) {}
				continue
			}
			iid := sub_id(list, "item", i)
			s := interact(iid, item.disabled)
			if s.clicked {picked = i}

			fg := c.text
			if item.danger {fg = c.danger}
			if item.disabled {fg = c.text_faint}
			style := font(.Body, fg)
			style.wrapMode = .None
			if clay.UI(iid)(
			{
				layout = {
					sizing = {clay.SizingGrow(), clay.SizingFit()},
					padding = inset(.MD, .SM),
				},
				backgroundColor = s.hovered ? c.surface_hover : {},
				cornerRadius = corners(.SM),
			},
			) {
				clay.TextDynamic(item.label, style)
			}
		}
	}
	return picked
}
