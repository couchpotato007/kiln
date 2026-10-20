package kiln

// Shared foundations for all widgets:
//  - interact(): mouse interaction (hover / pressed / held / clicked)
//  - anim():     per-widget tween for purely visual state (hover fade, toggle, ...)
//  - popup_*():  which dropdown (select / menu) is currently open
//
// Logical state (checked, value, text, ...) is owned by the caller,
// visual state (animation values, open popup) lives here.

import "core:math"
import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Mouse state of a widget in the current frame, returned by `interact`.
Interaction :: struct {
	hovered:  bool, // pointer is over the element
	pressed:  bool, // mouse is down AND the pointer is still over the element
	held:     bool, // mouse is down, regardless of where the pointer is (e.g. slider drag)
	clicked:  bool, // released over the element in this frame
	disabled: bool,
}

@(private = "file")
g_active: u32

// Tracks hover/press/click for an element ID. Call once per frame per widget, before declaring it.
// A click only counts if the press started on the same element. Disabled widgets never react.
interact :: proc(id: clay.ElementId, disabled := false) -> (s: Interaction) {
	s.disabled = disabled
	if disabled {
		if g_active == id.id {g_active = 0}
		return
	}

	s.hovered = clay.PointerOver(id)

	if rl.IsMouseButtonPressed(.LEFT) {
		if s.hovered {
			g_active = id.id
		} else if g_active == id.id {
			g_active = 0
		}
	}

	if g_active == id.id {
		s.held = rl.IsMouseButtonDown(.LEFT)
		s.pressed = s.hovered && s.held
		if rl.IsMouseButtonReleased(.LEFT) {
			s.clicked = s.hovered
			g_active = 0
		}
	}
	return
}

// ---------------------------------------------------------------------------
// Popups
// ---------------------------------------------------------------------------

// Only one popup (select list, menu) can be open at a time, so a single ID is enough.
// This keeps the open/closed state out of the caller's model.
@(private = "file")
g_popup: u32

popup_is_open :: proc(id: clay.ElementId) -> bool {
	return id.id != 0 && g_popup == id.id
}

// Opens the popup of `id` (closing any other one) or closes it if it is the open one.
popup_set :: proc(id: clay.ElementId, open: bool) {
	if open {
		g_popup = id.id
	} else if g_popup == id.id {
		g_popup = 0
	}
}

// ---------------------------------------------------------------------------
// Tween
// ---------------------------------------------------------------------------

@(private = "file")
g_anim: map[u64]f32

// Moves the value stored for (id, slot) exponentially towards `target` and returns it.
// `slot` (0..255) lets one widget animate several values. `speed` is the rate per second.
// Call once per slot and frame. On the first call the value jumps straight to `target`
// so widgets do not animate when they first appear.
anim :: proc(id: clay.ElementId, slot: u32, target: f32, speed: f32 = 14) -> f32 {
	key := u64(id.id) << 8 | u64(slot & 0xFF)
	v, ok := g_anim[key]
	if !ok {v = target}
	v += (target - v) * (1 - math.exp(-speed * rl.GetFrameTime()))
	if abs(target - v) < 0.001 {v = target}
	g_anim[key] = v
	return v
}

// Like `kiln.color_mix`, but interpolates the alpha channel as well.
color_lerp :: proc(a, b: clay.Color, t: f32) -> clay.Color {
	return a + (b - a) * t
}
