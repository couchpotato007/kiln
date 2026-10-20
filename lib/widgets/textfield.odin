package widgets


import "core:c"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import clay "lib:clay-odin"
import "lib:renderer"
import "lib:theme"
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

TextFieldConfig :: struct {
	id:               clay.ElementId,
	box:              clay.ElementDeclaration,
	text:             clay.TextElementConfig,
	placeholder:      string,
	placeholder_text: clay.TextElementConfig,
	border_focus:     clay.Color,
	cursor_color:     clay.Color,
	cursor_width:     f32,
	selection_color:  clay.Color,
}

TextFieldResult :: struct {
	changed:   bool, // the text was edited in this frame
	submitted: bool, // Enter was pressed in this frame
}

style_textfield :: proc(id: clay.ElementId, placeholder := "") -> TextFieldConfig {
	c := theme.current
	return {
		id = id,
		box = {
			layout = {
				sizing = {clay.SizingGrow(), theme.size_control_height()},
				padding = theme.pad_xy(.MD, .None),
				childAlignment = {y = .Center},
			},
			backgroundColor = c.bg_sunken,
			cornerRadius = theme.radius(.MD),
			border = theme.border_box(c.border),
		},
		text = theme.text_style(.Body, c.text),
		placeholder = placeholder,
		placeholder_text = theme.text_style(.Body, c.text_disabled),
		border_focus = c.primary,
		cursor_color = c.primary,
		cursor_width = theme.px(2),
		selection_color = c.selection,
	}
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
text_field :: proc(tf: ^TextField, cfg: TextFieldConfig) -> TextFieldResult {
	cfg := cfg

	tf.blink += rl.GetFrameTime()
	res := handle_input(tf, &cfg)

	s := string(tf.buf[:])
	pad := cfg.box.layout.padding
	data := clay.GetElementData(cfg.id)
	cursor_x := measure(s[:tf.cursor], cfg.text)

	if data.found {
		inner_w := data.boundingBox.width - f32(pad.left) - f32(pad.right)
		if cursor_x - tf.scroll > inner_w - 2 {tf.scroll = cursor_x - inner_w + 2}
		if cursor_x - tf.scroll < 0 {tf.scroll = cursor_x}
		total := measure(s, cfg.text)
		tf.scroll = clamp(tf.scroll, 0, max(0, total - inner_w + 2))
	} else {
		tf.scroll = 0
	}

	decl := cfg.box
	decl.clip = {
		horizontal  = true,
		childOffset = {-tf.scroll, 0},
	}
	if tf.focused && cfg.border_focus != {} {
		decl.border.color = cfg.border_focus
	}

	text_cfg := cfg.text
	text_cfg.wrapMode = .None
	ph_cfg := cfg.placeholder_text
	ph_cfg.wrapMode = .None

	line_h := f32(cfg.text.fontSize)
	y_off := f32(pad.top)
	if data.found {
		inner_h := data.boundingBox.height - f32(pad.top) - f32(pad.bottom)
		#partial switch decl.layout.childAlignment.y {
		case .Center:
			y_off += (inner_h - line_h) * 0.5
		case .Bottom:
			y_off += inner_h - line_h
		}
	}

	if clay.UI(cfg.id)(decl) {
		if len(s) > 0 {
			clay.Text(s, text_cfg)
		} else if len(cfg.placeholder) > 0 {
			clay.Text(cfg.placeholder, ph_cfg)
		}

		if tf.focused && has_selection(tf) {
			lo, hi := sel_range(tf)
			x0 := measure(s[:lo], cfg.text)
			x1 := measure(s[:hi], cfg.text)
			if clay.UI()(
			{
				layout = {sizing = {clay.SizingFixed(x1 - x0), clay.SizingFixed(line_h)}},
				backgroundColor = cfg.selection_color,
				floating = overlay_floating(f32(pad.left) + x0 - tf.scroll, y_off),
			},
			) {}
		}

		if tf.focused && math.mod(tf.blink, 1.06) < 0.53 {
			w := cfg.cursor_width > 0 ? cfg.cursor_width : 2
			col := cfg.cursor_color != {} ? cfg.cursor_color : cfg.text.textColor
			if clay.UI()(
			{
				layout = {sizing = {clay.SizingFixed(w), clay.SizingFixed(line_h)}},
				backgroundColor = col,
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
	return renderer.measure_text(slice, &cfg, nil).width
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
handle_input :: proc(tf: ^TextField, cfg: ^TextFieldConfig) -> (res: TextFieldResult) {
	pad := cfg.box.layout.padding
	data := clay.GetElementData(cfg.id)
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
			if clay.PointerOver(cfg.id) {
				tf.focused = true
				tf.dragging = true
				tf.blink = 0
				move_cursor(tf, index_at_x(s, cfg.text, local_x), shift)
			} else {
				tf.focused = false
				tf.dragging = false
			}
		}
		if tf.dragging {
			if rl.IsMouseButtonDown(.LEFT) {
				tf.cursor = index_at_x(s, cfg.text, local_x)
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
				text, _ := strings.replace_all(string(clip), "\r", "", context.temp_allocator)
				text, _ = strings.replace_all(text, "\n", " ", context.temp_allocator)
				insert_string(tf, text)
				res.changed = true
				tf.blink = 0
			}
		}
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {res.submitted = true}
	if rl.IsKeyPressed(.ESCAPE) {tf.focused = false}

	return
}
