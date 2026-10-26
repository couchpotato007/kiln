package kiln

// Overlays: dialog, drawer and toasts.
//
// Dialogs and drawers are shown by name with `show(name)` and hidden with `hide()` (or by
// Escape, a click on the backdrop or the close button). Only one is shown at a time.

import "core:strings"
import clay "clay-odin"

// ---------------------------------------------------------------------------
// Dialog
// ---------------------------------------------------------------------------

// A modal dialog with a title and a close button over a dimmed backdrop. While shown it returns
// true; put the body into the block. On compact screens it becomes a sheet at the bottom.
//
//   if kiln.button("Löschen", .Danger) {kiln.show("confirm")}
//
//   if kiln.dialog("confirm", "Eintrag löschen?") {
//       kiln.text("Das kann nicht rückgängig gemacht werden.")
//       if kiln.actions() {
//           if kiln.button("Abbrechen", .Ghost) {kiln.hide()}
//           if kiln.button("Löschen", .Danger) {append(out, Delete{}); kiln.hide()}
//       }
//   }
@(deferred_out = overlay_end)
dialog :: proc(name: string, title: string) -> bool {
	if !overlay_begin(name) {return false}
	c := &g_theme
	eid := clay.ID(name)
	sheet := screen() == .Compact
	t := anim(eid, 0, 1, from = 0)

	margin := f32(space(.LG))
	w := sheet ? g_in.window.x : min(size(.Dialog), g_in.window.x - 2 * margin)
	max_h := g_in.window.y - (sheet ? f32(space(.XL)) * 2 : 2 * margin)
	r := radius(.LG)

	backdrop(eid, sheet ? Align.End : Align.Center, t)

	box := sub_id(eid, "box")
	interact(box) // presses inside the dialog do not reach the backdrop
	clay._OpenElementWithId(box)
	clay.ConfigureOpenElement(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingFixed(w), clay.SizingFit({max = max_h})},
			},
			backgroundColor = c.surface,
			cornerRadius = sheet ? {topLeft = r, topRight = r} : clay.CornerRadiusAll(r),
			border = outline(c.border_strong),
		},
	)

	if clay.UI()(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			padding = {space(.LG), space(.SM), space(.MD), space(.XS)},
			childGap = space(.SM),
			childAlignment = {y = .Center},
		},
	},
	) {
		text(title, .Subtitle)
		spacer()
		if button("✕", .Ghost) {hide()}
	}

	content := sub_id(eid, "content")
	scrollable(content)
	clay._OpenElementWithId(content)
	clay.ConfigureOpenElement(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = {space(.LG), space(.LG), space(.XS), space(.LG)},
				childGap = space(.MD),
			},
			clip = {vertical = true, childOffset = clay.GetScrollOffset()},
		},
	)
	g_boxes[len(g_boxes) - 1].extra = 2
	return true
}

// ---------------------------------------------------------------------------
// Drawer
// ---------------------------------------------------------------------------

// A panel that slides in from the left edge over a dimmed backdrop, e.g. the navigation on
// compact screens. While shown it returns true; put the content into the block.
@(deferred_out = overlay_end)
drawer :: proc(name: string) -> bool {
	if !overlay_begin(name) {return false}
	c := &g_theme
	eid := clay.ID(name)
	t := anim(eid, 0, 1, from = 0, speed = 18)
	w := min(size(.Drawer), g_in.window.x * 0.85)

	backdrop(eid, .Start, t)

	box := sub_id(eid, "box")
	interact(box)
	clay._OpenElementWithId(box)
	clay.ConfigureOpenElement(
		{
			layout = {sizing = {clay.SizingFixed(w), clay.SizingFixed(g_in.window.y)}},
			backgroundColor = c.sunken,
			border = {color = c.border, width = {right = u16(line_width())}},
			floating = {
				attachTo = .Root,
				attachment = {element = .LeftTop, parent = .LeftTop},
				offset = {-(1 - t) * w, 0},
				zIndex = Z_OVERLAY + 1,
				pointerCaptureMode = .Capture,
			},
		},
	)

	content := sub_id(eid, "content")
	scrollable(content)
	clay._OpenElementWithId(content)
	clay.ConfigureOpenElement(
		{
			layout = {
				layoutDirection = .TopToBottom,
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				padding = inset(.MD),
				childGap = space(.SM),
			},
			clip = {vertical = true, childOffset = clay.GetScrollOffset()},
		},
	)
	g_boxes[len(g_boxes) - 1].extra = 2
	return true
}

// The overlay being declared; `hide()` inside its body must not change which one is closed.
@(private)
g_overlay_built: Id

// Shared start of dialog and drawer: visibility and the ways to close it.
@(private)
overlay_begin :: proc(name: string) -> bool {
	if !is_shown(name) {return false}
	eid := clay.ID(name)
	g_overlay_built = eid
	// Escape goes to an open popup or a focused text field first.
	if .Escape in g_in.keys && g_popup == 0 && g_focus == 0 {
		g_in.keys -= {.Escape}
		hide()
		return false
	}
	if interact(sub_id(eid, "backdrop")).clicked {
		hide()
		return false
	}
	return true
}

// The dimmed, click-blocking backdrop. It becomes the box of the overlay.
@(private)
backdrop :: proc(eid: Id, align: Align, t: f32) {
	g_z = Z_OVERLAY
	open_box(
		sub_id(eid, "backdrop"),
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				childAlignment = {x = .Center, y = align_y(align)},
				padding = align == .Center ? inset(.LG) : {},
			},
			backgroundColor = {0, 0, 0, 255 * g_theme.backdrop_alpha * t},
			floating = {
				attachTo = .Root,
				attachment = {element = .CenterCenter, parent = .CenterCenter},
				zIndex = Z_OVERLAY,
				pointerCaptureMode = .Capture,
			},
		},
	)
}

// Closes content, panel and backdrop; the panel gets a scroll bar if the content is too tall.
@(private)
overlay_end :: proc(ok: bool) {
	if !ok {return}
	b := &g_boxes[len(g_boxes) - 1]
	eid := g_overlay_built
	clay._CloseElement() // content
	scroll_bar(sub_id(eid, "box"), sub_id(eid, "content"))
	b.extra = 1 // the panel
	close_box()
	g_z = 0
}

// ---------------------------------------------------------------------------
// Toasts
// ---------------------------------------------------------------------------

@(private)
Toast :: struct {
	text: string,
	tone: Tone,
	born: f64,
}

@(private)
g_toasts: [dynamic]Toast

@(private)
TOAST_FADE :: 0.25

// Shows a short message for the theme's `toast_duration`: bottom right, or at the top on compact
// screens (where sheets and buttons live at the bottom).
// Can be called from anywhere, also from `update`:
//
//   kiln.toast("Gespeichert", .Success)
toast :: proc(message: string, tone := Tone.Default) {
	append(&g_toasts, Toast{strings.clone(message), tone, g_in.time})
}

// Declared by the app loop after the view.
@(private)
toasts_view :: proc() {
	c := &g_theme
	life := f64(c.toast_duration)
	for i := len(g_toasts) - 1; i >= 0; i -= 1 {
		if g_in.time - g_toasts[i].born > life + TOAST_FADE {
			delete(g_toasts[i].text)
			ordered_remove(&g_toasts, i)
		}
	}
	if len(g_toasts) == 0 {return}

	compact := screen() == .Compact
	margin := f32(space(.LG))
	w := compact ? g_in.window.x - 2 * margin : min(size(.Toast), g_in.window.x - 2 * margin)

	if clay.UI(clay.ID("kiln-toasts"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingFixed(w), clay.SizingFit()},
			childGap = space(.SM),
		},
		floating = {
			attachTo = .Root,
			attachment = compact ? {element = .CenterTop, parent = .CenterTop} : {element = .RightBottom, parent = .RightBottom},
			offset = compact ? {0, margin} : {-margin, -margin},
			zIndex = Z_TOAST,
		},
	},
	) {
		for &t, i in g_toasts {
			age := g_in.time - t.born
			alpha := f32(clamp(min(age / TOAST_FADE, (life + TOAST_FADE - age) / TOAST_FADE), 0, 1))
			tid := clay.ID("kiln-toast", u32(i))
			if interact(tid).clicked {t.born = min(t.born, g_in.time - life)} // fade out now

			accent := t.tone == .Default ? c.text_muted : tone_color(t.tone)
			if clay.UI(tid)(
			{
				layout = {
					sizing = {clay.SizingGrow(), clay.SizingFit()},
					padding = inset(.MD),
					childGap = space(.SM),
					childAlignment = {y = .Center},
				},
				backgroundColor = fade(c.surface_hover, alpha),
				cornerRadius = corners(.MD),
				border = outline(fade(c.border_strong, alpha)),
			},
			) {
				d := size(.Dot)
				if clay.UI()(
				{
					layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
					backgroundColor = fade(accent, alpha),
					cornerRadius = clay.CornerRadiusAll(d / 2),
				},
				) {}
				clay.TextDynamic(t.text, font(.Body, fade(c.text, alpha)))
			}
		}
	}
}
