package kiln


import "core:c"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Editing state of a text field. The zero value is an empty field.
// The text itself lives in `buf`, read it with `text_field_string`.
TextField :: struct {
	buf:      [dynamic]u8,
	cursor:   int,
	anchor:   int,
	scroll:   f32,
	blink:    f32,
	focused:  bool,
	dragging: bool,
}

TextFieldResult :: struct {
	changed:   bool, // the text was edited in this frame
	submitted: bool, // Enter was pressed in this frame
}

text_field_destroy :: proc(tf: ^TextField) {
	delete(tf.buf)
}

text_field_set :: proc(tf: ^TextField, s: string) {
	clear(&tf.buf)
	append(&tf.buf, s)
	tf.cursor = len(tf.buf)
	tf.anchor = tf.cursor
}

text_field_string :: proc(tf: ^TextField) -> string {
	return string(tf.buf[:])
}

// Declares a single-line text field. The state pointer comes first, like in every value widget.
// The cursor blink uses the frame time of raylib, so no delta time has to be passed in.
//
//   res := kiln.text_field(&m.field, "Name...")
//
// Without `id` the ID is derived from the placeholder, so several fields in the same parent
// need an explicit `id`.
text_field :: proc(
	tf: ^TextField,
	placeholder := "",
	id := clay.ElementId{},
) -> TextFieldResult {
	col := current_theme
	eid := resolve_id(id, len(placeholder) > 0 ? placeholder : "textfield")

	text_cfg := text_style(.Body, col.text)
	text_cfg.wrapMode = .None
	ph_cfg := text_style(.Body, col.text_disabled)
	ph_cfg.wrapMode = .None
	pad := pad_xy(.MD, .None)

	tf.blink += rl.GetFrameTime()
	res := handle_input(tf, eid, pad, text_cfg)

	s := string(tf.buf[:])
	data := clay.GetElementData(eid)
	cursor_x := measure(s[:tf.cursor], text_cfg)

	if data.found {
		inner_w := data.boundingBox.width - f32(pad.left) - f32(pad.right)
		if cursor_x - tf.scroll > inner_w - 2 {tf.scroll = cursor_x - inner_w + 2}
		if cursor_x - tf.scroll < 0 {tf.scroll = cursor_x}
		total := measure(s, text_cfg)
		tf.scroll = clamp(tf.scroll, 0, max(0, total - inner_w + 2))
	} else {
		tf.scroll = 0
	}

	line_h := f32(text_cfg.fontSize)
	y_off := f32(pad.top)
	if data.found {
		// The field centers its content vertically.
		inner_h := data.boundingBox.height - f32(pad.top) - f32(pad.bottom)
		y_off += (inner_h - line_h) * 0.5
	}

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), size_control_height()},
			padding = pad,
			childAlignment = {y = .Center},
		},
		backgroundColor = col.bg_sunken,
		cornerRadius = radius(.MD),
		border = border_box(tf.focused ? col.primary : col.border),
		clip = {horizontal = true, childOffset = {-tf.scroll, 0}},
	},
	) {
		if len(s) > 0 {
			clay.Text(s, text_cfg)
		} else if len(placeholder) > 0 {
			clay.Text(placeholder, ph_cfg)
		}

		if tf.focused && has_selection(tf) {
			lo, hi := sel_range(tf)
			x0 := measure(s[:lo], text_cfg)
			x1 := measure(s[:hi], text_cfg)
			if clay.UI()(
			{
				layout = {sizing = {clay.SizingFixed(x1 - x0), clay.SizingFixed(line_h)}},
				backgroundColor = col.selection,
				floating = overlay_floating(f32(pad.left) + x0 - tf.scroll, y_off),
			},
			) {}
		}

		if tf.focused && math.mod(tf.blink, 1.06) < 0.53 {
			if clay.UI()(
			{
				layout = {
					sizing = {clay.SizingFixed(border_px() * 2), clay.SizingFixed(line_h)},
				},
				backgroundColor = col.primary,
				floating = overlay_floating(f32(pad.left) + cursor_x - tf.scroll, y_off),
			},
			) {}
		}
	}

	return res
}


@(private = "file")
overlay_floating :: proc(x, y: f32) -> clay.FloatingElementConfig {
	return {
		attachTo = .Parent,
		clipTo = .AttachedParent,
		attachment = {element = .LeftTop, parent = .LeftTop},
		pointerCaptureMode = .Passthrough,
		offset = {x, y},
	}
}

@(private = "file")
measure :: proc(s: string, cfg: clay.TextElementConfig) -> f32 {
	if len(s) == 0 {return 0}
	cfg := cfg
	chars := cast([^]c.char)raw_data(s)
	slice := clay.StringSlice {
		length    = c.int32_t(len(s)),
		chars     = chars,
		baseChars = chars,
	}
	return measure_text(slice, &cfg, nil).width
}

@(private = "file")
index_at_x :: proc(s: string, cfg: clay.TextElementConfig, x: f32) -> int {
	prev: f32 = 0
	i := 0
	for i < len(s) {
		_, size := utf8.decode_rune_in_string(s[i:])
		next := measure(s[:i + size], cfg)
		if x < (prev + next) * 0.5 {return i}
		prev = next
		i += size
	}
	return len(s)
}

@(private = "file")
prev_rune :: proc(b: []u8, i: int) -> int {
	if i <= 0 {return 0}
	_, size := utf8.decode_last_rune_in_bytes(b[:i])
	return i - size
}

@(private = "file")
next_rune :: proc(b: []u8, i: int) -> int {
	if i >= len(b) {return len(b)}
	_, size := utf8.decode_rune_in_bytes(b[i:])
	return i + size
}

@(private = "file")
sel_range :: proc(tf: ^TextField) -> (lo, hi: int) {
	return min(tf.cursor, tf.anchor), max(tf.cursor, tf.anchor)
}

@(private = "file")
has_selection :: proc(tf: ^TextField) -> bool {
	return tf.cursor != tf.anchor
}

@(private = "file")
move_cursor :: proc(tf: ^TextField, pos: int, extend: bool) {
	tf.cursor = pos
	if !extend {tf.anchor = pos}
}

@(private = "file")
delete_range :: proc(tf: ^TextField, lo, hi: int) {
	if hi <= lo {return}
	remove_range(&tf.buf, lo, hi)
	tf.cursor = lo
	tf.anchor = lo
}

@(private = "file")
delete_selection :: proc(tf: ^TextField) -> bool {
	if !has_selection(tf) {return false}
	lo, hi := sel_range(tf)
	delete_range(tf, lo, hi)
	return true
}

@(private = "file")
insert_string :: proc(tf: ^TextField, s: string) {
	delete_selection(tf)
	bytes := transmute([]u8)s
	inject_at_elems(&tf.buf, tf.cursor, ..bytes)
	tf.cursor += len(bytes)
	tf.anchor = tf.cursor
}

@(private = "file")
key_hit :: proc(k: rl.KeyboardKey) -> bool {
	return rl.IsKeyPressed(k) || rl.IsKeyPressedRepeat(k)
}

@(private = "file")
handle_input :: proc(
	tf: ^TextField,
	id: clay.ElementId,
	pad: clay.Padding,
	text: clay.TextElementConfig,
) -> (
	res: TextFieldResult,
) {
	data := clay.GetElementData(id)
	s := string(tf.buf[:])

	tf.cursor = clamp(tf.cursor, 0, len(tf.buf))
	tf.anchor = clamp(tf.anchor, 0, len(tf.buf))

	shift := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
	altgr := rl.IsKeyDown(.RIGHT_ALT)
	ctrl :=
		(rl.IsKeyDown(.LEFT_CONTROL) ||
			rl.IsKeyDown(.RIGHT_CONTROL) ||
			rl.IsKeyDown(.LEFT_SUPER) ||
			rl.IsKeyDown(.RIGHT_SUPER)) &&
		!altgr

	if data.found {
		mouse := rl.GetMousePosition()
		local_x := mouse.x - data.boundingBox.x - f32(pad.left) + tf.scroll

		if rl.IsMouseButtonPressed(.LEFT) {
			if clay.PointerOver(id) {
				tf.focused = true
				tf.dragging = true
				tf.blink = 0
				move_cursor(tf, index_at_x(s, text, local_x), shift)
			} else {
				tf.focused = false
				tf.dragging = false
			}
		}
		if tf.dragging {
			if rl.IsMouseButtonDown(.LEFT) {
				tf.cursor = index_at_x(s, text, local_x)
				tf.blink = 0
			} else {
				tf.dragging = false
			}
		}
	}

	if !tf.focused {return}

	for {
		r := rl.GetCharPressed()
		if r == 0 {break}
		if ctrl || r < 32 || r == 127 {continue}
		b, n := utf8.encode_rune(r)
		insert_string(tf, string(b[:n]))
		res.changed = true
		tf.blink = 0
	}

	if key_hit(.LEFT) {
		if has_selection(tf) && !shift {
			lo, _ := sel_range(tf)
			move_cursor(tf, lo, false)
		} else {
			move_cursor(tf, prev_rune(tf.buf[:], tf.cursor), shift)
		}
		tf.blink = 0
	}
	if key_hit(.RIGHT) {
		if has_selection(tf) && !shift {
			_, hi := sel_range(tf)
			move_cursor(tf, hi, false)
		} else {
			move_cursor(tf, next_rune(tf.buf[:], tf.cursor), shift)
		}
		tf.blink = 0
	}
	if key_hit(.HOME) {move_cursor(tf, 0, shift); tf.blink = 0}
	if key_hit(.END) {move_cursor(tf, len(tf.buf), shift); tf.blink = 0}

	if key_hit(.BACKSPACE) {
		if !delete_selection(tf) {
			delete_range(tf, prev_rune(tf.buf[:], tf.cursor), tf.cursor)
		}
		res.changed = true
		tf.blink = 0
	}
	if key_hit(.DELETE) {
		if !delete_selection(tf) {
			delete_range(tf, tf.cursor, next_rune(tf.buf[:], tf.cursor))
		}
		res.changed = true
		tf.blink = 0
	}

	if ctrl {
		if rl.IsKeyPressed(.A) {
			tf.anchor = 0
			tf.cursor = len(tf.buf)
		}
		if (rl.IsKeyPressed(.C) || rl.IsKeyPressed(.X)) && has_selection(tf) {
			lo, hi := sel_range(tf)
			rl.SetClipboardText(
				strings.clone_to_cstring(string(tf.buf[lo:hi]), context.temp_allocator),
			)
			if rl.IsKeyPressed(.X) {
				delete_range(tf, lo, hi)
				res.changed = true
			}
		}
		if rl.IsKeyPressed(.V) {
			if clip := rl.GetClipboardText(); clip != nil {
				pasted, _ := strings.replace_all(string(clip), "\r", "", context.temp_allocator)
				pasted, _ = strings.replace_all(pasted, "\n", " ", context.temp_allocator)
				insert_string(tf, pasted)
				res.changed = true
				tf.blink = 0
			}
		}
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {res.submitted = true}
	if rl.IsKeyPressed(.ESCAPE) {tf.focused = false}

	return
}
