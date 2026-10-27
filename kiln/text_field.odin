package kiln

// Single-line text field.
//
// The text belongs to the model; the field keeps its editing state (buffer, cursor, selection,
// scroll) internally. When the model's text changes from outside (e.g. cleared after a submit),
// the field adopts it. Tab / Shift+Tab move the focus between fields.
//
// Password fields show one `•` per character. The buffer always holds the real text; cursor and
// selection are byte offsets into it and are converted wherever the shown text is measured.

import "core:math"
import "core:strings"
import "core:unicode/utf8"
import clay "clay-odin"

@(private)
Edit :: struct {
	buf:            [dynamic]u8,
	cursor, anchor: int, // byte offsets; the selection is between them
	scroll:         f32,
	blink:          f32,
	dragging:       bool,
	revealed:       bool, // password fields: the text is shown instead of dots
	frame:          u64,
}

@(private)
g_edits: map[u32]^Edit
@(private)
g_focus: u32 // the text field that receives keyboard input
@(private)
g_focus_order: [dynamic]u32 // enabled text fields in declaration order (this frame)

@(private)
MASK :: "•"

// A text field. Returns the edited text and whether it changed in this frame; ask
// `kiln.submitted()` afterwards for Enter. The returned string lives until the end of the frame:
//
//   if t, ok := kiln.text_field(m.draft, "Neue Aufgabe..."); ok {append(out, Set_Draft{t})}
//   if kiln.submitted() {append(out, Add{})}
//
// `password` masks the text and adds a button that reveals it; copying is disabled while masked.
// The field is identified by its placeholder; give two fields with the same placeholder a
// distinct `key`.
text_field :: proc(
	value: string,
	placeholder := "",
	disabled := false,
	password := false,
	key := "",
) -> (
	text: string,
	changed: bool,
) {
	c := &g_theme
	eid := id(len(key) > 0 ? key : len(placeholder) > 0 ? placeholder : "text_field")
	e := edit_state(eid)

	if string(e.buf[:]) != value {
		clear(&e.buf)
		append(&e.buf, value)
		e.cursor = min(e.cursor, len(e.buf))
		e.anchor = min(e.anchor, len(e.buf))
	}

	s := interact(eid, disabled)
	if disabled {
		if g_focus == eid.id {g_focus = 0}
		e.dragging = false
	} else {
		append(&g_focus_order, eid.id)
	}

	masked := password && !e.revealed
	style := font(.Body, disabled ? c.text_faint : c.text)
	style.wrapMode = .None
	pad := inset(.MD, .None)
	eye_inset := line_width() + f32(space(.XS))
	eye_size := size(.Control) - 2 * eye_inset
	if password {pad.right = u16(eye_size + eye_inset + f32(space(.XS)))} // room for the reveal button
	data := clay.GetElementData(eid)
	local_x := g_in.mouse.x - data.boundingBox.x - f32(pad.left) + e.scroll

	// Mouse: a press focuses and places the cursor, dragging selects.
	if g_active == eid.id && .Left in g_in.pressed {
		g_focus = eid.id
		e.dragging = true
		move_cursor(e, hit_offset(e, local_x, masked), g_in.shift)
	}
	if e.dragging {
		if .Left in g_in.down {
			e.cursor = hit_offset(e, local_x, masked)
			e.blink = 0
		} else {
			e.dragging = false
		}
	}

	focused := g_focus == eid.id
	submit := false
	if focused {changed, submit = edit_keys(e, masked)}
	changed = changed && string(e.buf[:]) != value
	e.blink += g_in.dt

	// Keep the cursor visible.
	str := string(e.buf[:])
	shown := shown_text(str, masked)
	cursor_x := measure(shown[:shown_offset(str, e.cursor, masked)], .Body)
	if data.found {
		inner := data.boundingBox.width - f32(pad.left) - f32(pad.right)
		if cursor_x - e.scroll > inner - 2 {e.scroll = cursor_x - inner + 2}
		if cursor_x - e.scroll < 0 {e.scroll = cursor_x}
		e.scroll = clamp(e.scroll, 0, max(0, measure(shown, .Body) - inner + 2))
	}

	line_h := f32(style.fontSize)
	y := f32(0)
	if data.found {y = (data.boundingBox.height - line_h) / 2}

	border := mix(c.border, c.border_strong, anim(eid, 0, s.hovered ? 1 : 0))
	if focused {border = c.primary}
	if field_error() {border = c.danger}

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFixed(size(.Control))},
			padding = pad,
			childAlignment = {y = .Center},
		},
		backgroundColor = c.sunken,
		cornerRadius = corners(.MD),
		border = outline(border),
		clip = {horizontal = true, childOffset = {-e.scroll, 0}},
	},
	) {
		if len(shown) > 0 {
			clay.TextDynamic(shown, style)
		} else if len(placeholder) > 0 {
			ph := font(.Body, c.text_faint)
			ph.wrapMode = .None
			clay.TextDynamic(placeholder, ph)
		}

		if focused && e.cursor != e.anchor {
			lo, hi := selection(e)
			x0 := measure(shown[:shown_offset(str, lo, masked)], .Body)
			x1 := measure(shown[:shown_offset(str, hi, masked)], .Body)
			mark_in_field(c.selection, f32(pad.left) + x0 - e.scroll, y, x1 - x0, line_h)
		}
		if focused && math.mod(e.blink, 1.06) < 0.53 {
			mark_in_field(c.primary, f32(pad.left) + cursor_x - e.scroll, y, line_width() * 2, line_h)
		}

		// The reveal button floats over the right end, so it does not scroll with the text. It is
		// inset by `eye_inset`, so its hover background stays inside the field's border.
		if password {
			bid := sub_id(eid, "reveal")
			bs := interact(bid, disabled)
			if bs.clicked {e.revealed = !e.revealed}
			bh := anim(bid, 0, bs.hovered ? 1 : 0)
			bg := mix(fade(c.surface_hover, 0), c.surface_hover, bh)
			if bs.pressed {bg = c.surface_active}
			if clay.UI(bid)(
			{
				layout = {
					sizing = {clay.SizingFixed(eye_size), clay.SizingFixed(eye_size)},
					childAlignment = {.Center, .Center},
				},
				backgroundColor = bg,
				cornerRadius = corners(.SM),
				floating = {
					attachTo = .Parent,
					attachment = {element = .RightCenter, parent = .RightCenter},
					offset = {-eye_inset, 0},
					zIndex = g_z + 1,
				},
			},
			) {
				clay.TextDynamic(e.revealed ? "○" : "◉", font(.Body, disabled ? c.text_faint : c.text_muted))
			}
		}
	}

	set_last(eid, s, submit)
	return strings.clone(str, context.temp_allocator), changed
}

// The text as drawn: the buffer, or one mask glyph per rune.
@(private)
shown_text :: proc(buf: string, masked: bool) -> string {
	if !masked {return buf}
	return strings.repeat(MASK, utf8.rune_count_in_string(buf), context.temp_allocator)
}

// Byte offset in the shown text for a byte offset in the buffer.
@(private)
shown_offset :: proc(buf: string, off: int, masked: bool) -> int {
	if !masked {return off}
	return utf8.rune_count_in_string(buf[:off]) * len(MASK)
}

// Byte offset in the buffer for the position under `x` (pixels from the start of the text).
@(private)
hit_offset :: proc(e: ^Edit, x: f32, masked: bool) -> int {
	buf := string(e.buf[:])
	at := index_at(shown_text(buf, masked), x)
	if !masked {return at}
	i := 0
	for _ in 0 ..< at / len(MASK) {
		if i >= len(buf) {break}
		_, n := utf8.decode_rune_in_string(buf[i:])
		i += n
	}
	return i
}

@(private)
edit_state :: proc(eid: Id) -> ^Edit {
	e, ok := g_edits[eid.id]
	if !ok {
		e = new(Edit)
		g_edits[eid.id] = e
	}
	e.frame = g_frame
	return e
}

// Tab moves the focus to the next / previous field of this frame.
@(private)
focus_end :: proc() {
	defer clear(&g_focus_order)
	if g_focus == 0 || .Tab not_in g_in.keys || len(g_focus_order) == 0 {return}
	for f, i in g_focus_order {
		if f != g_focus {continue}
		n := len(g_focus_order)
		next := g_focus_order[(i + (g_in.shift ? n - 1 : 1)) % n]
		g_focus = next
		if e, ok := g_edits[next]; ok {
			e.anchor, e.cursor = 0, len(e.buf)
			e.blink = 0
		}
		return
	}
}

// A selection highlight or the cursor, floating over the text and clipped by the field.
@(private)
mark_in_field :: proc(color: Color, x, y, w, h: f32) {
	if clay.UI()(
	{
		layout = {sizing = {clay.SizingFixed(w), clay.SizingFixed(h)}},
		backgroundColor = color,
		floating = {
			attachTo = .Parent,
			clipTo = .AttachedParent,
			attachment = {element = .LeftTop, parent = .LeftTop},
			pointerCaptureMode = .Passthrough,
			offset = {x, y},
			zIndex = g_z + 1,
		},
	},
	) {}
}

@(private)
index_at :: proc(s: string, x: f32) -> int {
	prev: f32 = 0
	for i := 0; i < len(s); {
		_, n := utf8.decode_rune_in_string(s[i:])
		next := measure(s[:i + n], .Body)
		if x < (prev + next) / 2 {return i}
		prev = next
		i += n
	}
	return len(s)
}

@(private)
selection :: proc(e: ^Edit) -> (lo, hi: int) {
	return min(e.cursor, e.anchor), max(e.cursor, e.anchor)
}

@(private)
move_cursor :: proc(e: ^Edit, pos: int, extend: bool) {
	e.cursor = pos
	if !extend {e.anchor = pos}
	e.blink = 0
}

@(private)
prev_rune :: proc(b: []u8, i: int) -> int {
	if i <= 0 {return 0}
	_, n := utf8.decode_last_rune_in_bytes(b[:i])
	return i - n
}

@(private)
next_rune :: proc(b: []u8, i: int) -> int {
	if i >= len(b) {return len(b)}
	_, n := utf8.decode_rune_in_bytes(b[i:])
	return i + n
}

@(private)
delete_range :: proc(e: ^Edit, lo, hi: int) {
	if hi <= lo {return}
	remove_range(&e.buf, lo, hi)
	e.cursor, e.anchor = lo, lo
}

@(private)
delete_selection :: proc(e: ^Edit) -> bool {
	if e.cursor == e.anchor {return false}
	lo, hi := selection(e)
	delete_range(e, lo, hi)
	return true
}

@(private)
insert :: proc(e: ^Edit, s: string) {
	delete_selection(e)
	inject_at_elems(&e.buf, e.cursor, ..transmute([]u8)s)
	e.cursor += len(s)
	e.anchor = e.cursor
}

@(private)
edit_keys :: proc(e: ^Edit, masked := false) -> (changed, submitted: bool) {
	keys := g_in.keys
	shift, ctrl := g_in.shift, g_in.ctrl
	e.cursor = clamp(e.cursor, 0, len(e.buf))
	e.anchor = clamp(e.anchor, 0, len(e.buf))

	for r in g_in.chars {
		if ctrl || r < 32 || r == 127 {continue}
		b, n := utf8.encode_rune(r)
		insert(e, string(b[:n]))
		changed = true
		e.blink = 0
	}

	if .Left in keys {
		if e.cursor != e.anchor && !shift {
			lo, _ := selection(e)
			move_cursor(e, lo, false)
		} else {
			move_cursor(e, prev_rune(e.buf[:], e.cursor), shift)
		}
	}
	if .Right in keys {
		if e.cursor != e.anchor && !shift {
			_, hi := selection(e)
			move_cursor(e, hi, false)
		} else {
			move_cursor(e, next_rune(e.buf[:], e.cursor), shift)
		}
	}
	if .Home in keys {move_cursor(e, 0, shift)}
	if .End in keys {move_cursor(e, len(e.buf), shift)}

	if .Backspace in keys {
		if !delete_selection(e) {delete_range(e, prev_rune(e.buf[:], e.cursor), e.cursor)}
		changed = true
		e.blink = 0
	}
	if .Delete in keys {
		if !delete_selection(e) {delete_range(e, e.cursor, next_rune(e.buf[:], e.cursor))}
		changed = true
		e.blink = 0
	}

	if ctrl {
		if .A in keys {
			e.anchor, e.cursor = 0, len(e.buf)
		}
		if (.C in keys || .X in keys) && e.cursor != e.anchor && !masked { // no copying out of a password
			lo, hi := selection(e)
			backend_set_clipboard(string(e.buf[lo:hi]))
			if .X in keys {
				delete_range(e, lo, hi)
				changed = true
			}
		}
		if .V in keys {
			if clip := backend_get_clipboard(); len(clip) > 0 {
				pasted, _ := strings.replace_all(clip, "\r", "", context.temp_allocator)
				pasted, _ = strings.replace_all(pasted, "\n", " ", context.temp_allocator)
				insert(e, pasted)
				changed = true
				e.blink = 0
			}
		}
	}

	if .Enter in keys {submitted = true}
	if .Escape in keys {
		g_focus = 0
		g_in.keys -= {.Escape} // consumed: does not close the dialog around the field
	}
	return
}
