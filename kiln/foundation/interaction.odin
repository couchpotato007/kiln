package foundation

// Shared state of all widgets:
//  - interact(): mouse interaction (hover / pressed / held / clicked)
//  - anim():     per-widget tween for purely visual state (hover fade, toggle, ...)
//  - popup_*():  which popup (select list, menu) is currently open
//
// Logical state (checked, value, text, ...) is owned by the caller,
// visual state (animation values, open popup) lives here.

import "core:math"
import clay "lib:kiln/clay-odin"
import th "lib:kiln/theme"
import rl "vendor:raylib"

// Mouse state of a widget in the current frame, returned by `interact`.
Interaction :: struct {
	hovered:  bool, // pointer is over the element
	pressed:  bool, // mouse is down AND the pointer is still over the element
	held:     bool, // mouse is down, regardless of where the pointer is (e.g. slider drag)
	clicked:  bool, // released over the element in this frame
	disabled: bool,
}

@(private)
g_active: u32

// Tracks hover/press/click for an element id. Call once per frame per widget, before declaring it.
// A click only counts if the press started on the same element. Disabled widgets never react.
// If elements are nested, call `interact` for the outer one first: the last call wins a press.
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

// Only one popup can be open at a time, so a single id is enough. This keeps the
// open/closed state out of the caller's model.
@(private)
g_popup: u32

popup_is_open :: proc(owner: clay.ElementId) -> bool {
	return owner.id != 0 && g_popup == owner.id
}

// Opens the popup of `owner` (closing any other one) or closes it if it is the open one.
popup_set :: proc(owner: clay.ElementId, open: bool) {
	if open {
		g_popup = owner.id
	} else if g_popup == owner.id {
		g_popup = 0
	}
}

// Closes the popup of `owner` on Escape or on a mouse press outside of its `list`.
// With `keep_owner` a press on the owner itself does not count as outside (the owner toggles itself).
popup_dismiss :: proc(owner, list: clay.ElementId, keep_owner := true) {
	if !popup_is_open(owner) {return}
	pressed := rl.IsMouseButtonPressed(.LEFT) || rl.IsMouseButtonPressed(.RIGHT)
	outside := pressed && !clay.PointerOver(list) && !(keep_owner && clay.PointerOver(owner))
	if outside || rl.IsKeyPressed(.ESCAPE) {popup_set(owner, false)}
}

// ---------------------------------------------------------------------------
// Tween
// ---------------------------------------------------------------------------

@(private)
g_anim: map[u64]f32

// Moves the value stored for (id, slot) exponentially towards `target` and returns it.
// `slot` (0..255) lets one widget animate several values. `speed` is the rate per second
// (0 = the theme's `anim_speed`).
// Call once per slot and frame. On the first call the value jumps straight to `target`
// so widgets do not animate when they first appear.
anim :: proc(id: clay.ElementId, slot: u32, target: f32, speed: f32 = 0) -> f32 {
	rate := speed > 0 ? speed : th.current().anim_speed
	key := u64(id.id) << 8 | u64(slot & 0xFF)
	v, ok := g_anim[key]
	if !ok {v = target}
	v += (target - v) * (1 - math.exp(-rate * rl.GetFrameTime()))
	if abs(target - v) < 0.001 {v = target}
	g_anim[key] = v
	return v
}
