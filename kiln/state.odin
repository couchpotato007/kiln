package kiln

// The UI state kiln keeps between frames:
//  - ids and scopes: stable element ids without the app passing any
//  - interaction: hover / press / click, resolved to the topmost element under the pointer
//  - the last item: what `clicked`, `hovered`, `submitted`, `tooltip` and `context_menu` refer to
//  - tweens for purely visual state (hover fades, toggles, open animations)
//  - popups (select lists, menus) and overlays (dialogs, drawers)

import "core:math"
import clay "clay-odin"

Id :: clay.ElementId

@(private)
g_frame: u64

// ---------------------------------------------------------------------------
// Ids and scopes
// ---------------------------------------------------------------------------

@(private)
Scope :: struct {
	seed: u32,
	seen: map[u32]u32, // how often each base id was handed out in this scope (this frame)
}

@(private)
g_scopes: [dynamic]Scope

@(private)
ids_begin :: proc() {
	clear(&g_scopes)
	append(&g_scopes, Scope{seen = make(map[u32]u32, context.temp_allocator)})
}

// The id of an element labeled `label` in the current scope. The n-th use of the same label in a
// scope gets its own id, so equal labels never clash.
id :: proc(label: string) -> Id {
	return unique(clay.ID(label, current_seed()), label)
}

// Like `id`, for the `index`-th element of a kind (list rows, tabs, ...).
id_indexed :: proc(label: string, index: int) -> Id {
	return unique(
		clay.ID(label, seed_with(current_seed(), u32(index))),
		label,
	)
}

@(private)
current_seed :: proc() -> u32 {
	return g_scopes[len(g_scopes) - 1].seed
}

@(private)
unique :: proc(base: Id, label: string) -> Id {
	s := &g_scopes[len(g_scopes) - 1]
	n := s.seen[base.id]
	s.seen[base.id] = n + 1
	if n == 0 {return base}
	return clay.ID(label, seed_with(base.id, n))
}

// Combines a hash seed with an index (murmur3 finalizer), for ids of numbered elements.
@(private)
seed_with :: proc(seed, index: u32) -> u32 {
	h := seed ~ (index + 0x9E3779B9 + (seed << 6) + (seed >> 2))
	h ~= h >> 16
	h *= 0x85EBCA6B
	h ~= h >> 13
	h *= 0xC2B2AE35
	h ~= h >> 16
	return h
}

// Id of a part of a widget (list entry, segment, popup, ...), derived from the widget's id.
sub_id :: proc(parent: Id, name: string, index := 0) -> Id {
	return clay.ID(name, seed_with(parent.id, u32(index)))
}

// Opens an id scope: elements inside get ids that depend on `key` instead of their position.
// Use it in loops over data that can change, so the UI state of an item follows the item:
//
//   for p in m.people {
//       if kiln.scope(p.id) { ... }
//   }
scope :: proc {
	scope_int,
	scope_string,
}

@(deferred_none = scope_end)
scope_int :: proc(key: int) -> bool {
	scope_push(id_indexed("#scope", key))
	return true
}

@(deferred_none = scope_end)
scope_string :: proc(key: string) -> bool {
	scope_push(id(key))
	return true
}

@(private)
scope_push :: proc(key: Id) {
	append(&g_scopes, Scope{seed = key.id, seen = make(map[u32]u32, context.temp_allocator)})
}

@(private)
scope_end :: proc() {
	if len(g_scopes) > 1 {pop(&g_scopes)}
}

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------

// Pointer state of an element in the current frame, returned by `interact`.
Interaction :: struct {
	hovered:       bool, // the pointer is over the element
	pressed:       bool, // the left button went down on the element and is down over it
	held:          bool, // the left button went down on the element and is still down (anywhere)
	clicked:       bool, // released over the element in this frame
	right_clicked: bool, // the right button went down on the element in this frame
	started:       bool, // the left button went down on the element in this frame (a drag starts)
	released:      bool, // the left button that went down on the element was released in this frame, anywhere
	disabled:      bool,
	pos:           [2]f32, // pointer position in pixels, relative to the element's top left corner (as laid out in the previous frame)
}

@(private)
g_active: u32 // element that owns the current left press
@(private)
g_right: u32 // element the right button went down on in this frame
@(private)
g_interactive, g_interactive_prev: map[u32]bool

// Tracks the pointer for an element. Call it once per frame before declaring the element.
// A press goes to the topmost interactive element under the pointer, so a button inside a
// clickable list item takes the click and the item does not. Disabled elements never react.
interact :: proc(eid: Id, disabled := false) -> (s: Interaction) {
	s.disabled = disabled
	if disabled {
		if g_active == eid.id {g_active = 0}
		return
	}
	g_interactive[eid.id] = true

	s.hovered = clay.PointerOver(eid)
	if g_active == eid.id {
		s.held = .Left in g_in.down
		s.pressed = s.hovered && s.held
		s.clicked = s.hovered && .Left in g_in.released
		s.started = .Left in g_in.pressed
		s.released = .Left in g_in.released
	}
	d := clay.GetElementData(eid)
	s.pos = g_in.mouse - {d.boundingBox.x, d.boundingBox.y}
	s.right_clicked = g_right == eid.id
	return
}

@(private)
interaction_begin :: proc() {
	g_interactive, g_interactive_prev = g_interactive_prev, g_interactive
	clear(&g_interactive)
	g_right = 0

	g_hot = topmost_interactive()

	if g_in.pressed == {} {return}
	target := g_hot
	if .Left in g_in.pressed {
		g_active = target
		if target != g_focus {g_focus = 0}
	}
	if .Right in g_in.pressed {g_right = target}
}

@(private)
interaction_end :: proc() {
	if .Left not_in g_in.down {g_active = 0}
}

// Clay lists the elements under the pointer from the root down, so the last one that was
// interactive in the previous frame is the topmost.
@(private)
topmost_interactive :: proc() -> u32 {
	over := clay.GetPointerOverIds()
	for i := over.length - 1; i >= 0; i -= 1 {
		pid := over.internalArray[i].id
		if g_interactive_prev[pid] {return pid}
	}
	return 0
}

// ---------------------------------------------------------------------------
// Pointer events
// ---------------------------------------------------------------------------

Pointer_Event_Kind :: enum {
	Move,
	Press,
	Release,
	Wheel,
}

// One thing the pointer did, in the order it happened. Several moves in one frame are the
// pointer's path between frames, if the platform reports it.
Pointer_Event :: struct {
	kind:      Pointer_Event_Kind,
	button:    MouseButton, // Press and Release
	pos:       [2]f32, // pixels, relative to the element's top left corner (window for the backend)
	wheel:     [2]f32, // Wheel: pixels to scroll
	pressure:  f32, // 0..1; 1 for devices without pressure, like a mouse
	modifiers: bit_set[Modifier],
	time:      f64, // seconds since the app started
}

@(private)
g_events: []Pointer_Event // this frame's events, window coordinates
@(private)
g_hot: u32 // the topmost interactive element under the pointer
@(private)
g_wheel_claims, g_wheel_claims_prev: map[u32]bool

// The pointer events of this frame that belong to an element: all of them while a press that
// started on it goes on (even outside of it), otherwise those over it while it is the topmost
// interactive element. Call `interact` for the element before, every frame. With `wheel`, the
// element takes the mouse wheel: scroll containers around it do not scroll while the pointer
// is over it. The events live until the end of the frame.
//
//   for e in kiln.pointer_events(eid) {
//       if e.kind == .Move && s.held {append(&points, e.pos)}
//   }
pointer_events :: proc(eid: Id, wheel := false) -> []Pointer_Event {
	if wheel {g_wheel_claims[eid.id] = true}
	if g_active != eid.id && !(g_active == 0 && g_hot == eid.id) {return nil}
	d := clay.GetElementData(eid)
	origin := [2]f32{d.boundingBox.x, d.boundingBox.y}
	out := make([]Pointer_Event, len(g_events), context.temp_allocator)
	for e, i in g_events {
		out[i] = e
		out[i].pos -= origin
	}
	return out
}

// The events of a frame from the backend's input, for backends that do not report them one by
// one: a move to the new position, then presses, the wheel and releases.
@(private)
events_from_input :: proc(prev, in_: Input) -> []Pointer_Event {
	out := make([dynamic]Pointer_Event, context.temp_allocator)
	mods := bit_set[Modifier]{}
	if in_.shift {mods += {.Shift}}
	if in_.ctrl {mods += {.Ctrl}}
	base := Pointer_Event {
		pos       = in_.mouse,
		pressure  = 1,
		modifiers = mods,
		time      = in_.time,
	}
	if in_.mouse != prev.mouse {
		e := base
		e.kind = .Move
		append(&out, e)
	}
	for b in in_.pressed {
		e := base
		e.kind, e.button = .Press, b
		append(&out, e)
	}
	if in_.wheel != {} {
		e := base
		e.kind, e.wheel = .Wheel, in_.wheel
		append(&out, e)
	}
	for b in in_.released {
		e := base
		e.kind, e.button = .Release, b
		append(&out, e)
	}
	return out[:]
}

// ---------------------------------------------------------------------------
// The last item
// ---------------------------------------------------------------------------

@(private)
Item :: struct {
	id:        Id,
	state:     Interaction,
	submitted: bool,
}

@(private)
g_last: Item

// Makes a custom widget the last item, so `clicked`, `hovered`, `submitted`, `tooltip` and
// `context_menu` after it refer to it. Pass the `Interaction` from `interact`.
set_last :: proc(eid: Id, state := Interaction{}, submitted := false) {
	g_last = {eid, state, submitted}
}

// True if the last widget or container was clicked in this frame.
clicked :: proc() -> bool {
	return g_last.state.clicked
}

// True if the pointer is over the last widget or container.
hovered :: proc() -> bool {
	return g_last.id.id != 0 && clay.PointerOver(g_last.id)
}

// True if Enter was pressed in the last text field in this frame.
submitted :: proc() -> bool {
	return g_last.submitted
}

// The id of the last widget or container, e.g. to attach custom floating elements to it.
last_id :: proc() -> Id {
	return g_last.id
}

// ---------------------------------------------------------------------------
// Tweens
// ---------------------------------------------------------------------------

@(private)
Tween :: struct {
	value: f32,
	frame: u64, // last frame the tween was used
}

@(private)
g_tweens: map[u64]Tween

// Moves the value stored for (id, slot) exponentially towards `target` and returns it.
// `slot` lets one widget animate several values, `speed` is the rate per second
// (0 = the theme's `anim_speed`). The first value of a new tween is `target`, or `from` if
// given (e.g. `from = 0` for things that fade in when they appear).
anim :: proc(eid: Id, slot: u32, target: f32, speed: f32 = 0, from: Maybe(f32) = nil) -> f32 {
	rate := speed > 0 ? speed : g_theme.anim_speed
	key := u64(eid.id) << 8 | u64(slot & 0xFF)
	t, ok := g_tweens[key]
	v := t.value
	if !ok || t.frame + 1 < g_frame {
		// New, or not shown in the previous frame: start over.
		v = from.? or_else target
	}
	v += (target - v) * (1 - math.exp(-rate * g_in.dt))
	if abs(target - v) < 0.001 {v = target}
	g_tweens[key] = {v, g_frame}
	return v
}

// ---------------------------------------------------------------------------
// Popups and overlays
// ---------------------------------------------------------------------------

// Only one popup (select list, menu) is open at a time, keyed by the id of its owner.
@(private)
g_popup: u32

@(private)
popup_is_open :: proc(owner: Id) -> bool {
	return owner.id != 0 && g_popup == owner.id
}

@(private)
popup_set :: proc(owner: Id, open: bool) {
	if open {
		g_popup = owner.id
	} else if g_popup == owner.id {
		g_popup = 0
	}
}

// Closes the popup of `owner` on Escape or on a press outside of `list` (and of the owner,
// which toggles itself, unless `keep_owner` is false).
@(private)
popup_dismiss :: proc(owner, list: Id, keep_owner := true) {
	if !popup_is_open(owner) {return}
	outside :=
		g_in.pressed != {} &&
		!clay.PointerOver(list) &&
		!(keep_owner && clay.PointerOver(owner))
	if outside || .Escape in g_in.keys {
		popup_set(owner, false)
		g_in.keys -= {.Escape} // consumed
	}
}

// One overlay (dialog, drawer) is shown at a time.
@(private)
g_overlay: u32

// Shows the dialog or drawer with this name (replacing the one that is shown).
show :: proc(name: string) {
	g_overlay = clay.ID(name).id
	g_popup = 0
}

// Hides the shown dialog or drawer.
hide :: proc() {
	g_overlay = 0
}

is_shown :: proc(name: string) -> bool {
	return g_overlay != 0 && g_overlay == clay.ID(name).id
}

// ---------------------------------------------------------------------------
// Timers
// ---------------------------------------------------------------------------

@(private)
Timer :: struct {
	start: f64,
	frame: u64, // last frame the timer was asked
	fired: bool, // `after`: already returned true
}

@(private)
g_timers: map[u32]Timer

// The timer called `name`, started now if it is new or was not asked in the previous frame
// (e.g. its page was not shown), so timers stop with the view that asks them.
@(private)
timer :: proc(name: string) -> ^Timer {
	key := clay.ID(name).id
	t, ok := g_timers[key]
	if !ok || t.frame + 1 < g_frame {t = {start = g_in.time}}
	t.frame = g_frame
	g_timers[key] = t
	return &g_timers[key]
}

// True once every `seconds` (the first time `seconds` after the first call) while it is called
// in every frame. Timers are keyed by name like dialogs, not by position:
//
//   if kiln.every("refresh", 300) {append(out, Refresh{})}
every :: proc(name: string, seconds: f64) -> bool {
	t := timer(name)
	if g_in.time - t.start < seconds {return false}
	t.start += seconds
	if g_in.time - t.start >= seconds {t.start = g_in.time} // fell behind: no burst of ticks
	return true
}

// True once, `seconds` after the first call (while it is called in every frame).
after :: proc(name: string, seconds: f64) -> bool {
	t := timer(name)
	if t.fired || g_in.time - t.start < seconds {return false}
	t.fired = true
	return true
}

// Starts the timer `name` over.
reset_timer :: proc(name: string) {
	delete_key(&g_timers, clay.ID(name).id)
}

// ---------------------------------------------------------------------------
// Widget state
// ---------------------------------------------------------------------------

@(private)
Widget_State :: struct {
	data:    rawptr,
	type:    typeid,
	destroy: proc(_: rawptr),
	frame:   u64, // last frame the state was asked for
}

@(private)
g_widget_states: map[u32]Widget_State

// UI state of a custom widget that kiln keeps between frames, one `T` per element id (a drag
// in progress, a scroll position, a cache). It starts zeroed (`created` is true then) and is
// freed when the widget was not shown for a while; `destroy` frees what `T` owns:
//
//   Draft :: struct {points: [dynamic][2]f32}
//   draft, _ := kiln.widget_state(eid, Draft, proc(d: ^Draft) {delete(d.points)})
widget_state :: proc(eid: Id, $T: typeid, destroy: proc(_: ^T) = nil) -> (state: ^T, created: bool) {
	w, ok := &g_widget_states[eid.id]
	if !ok {
		w = map_insert(&g_widget_states, eid.id, Widget_State{data = new(T), type = T, destroy = auto_cast destroy})
		created = true
	}
	assert(w.type == T, "kiln.widget_state: an id is used with two different types")
	w.frame = g_frame
	return (^T)(w.data), created
}

@(private)
widget_state_free :: proc(w: Widget_State) {
	if w.destroy != nil {w.destroy(w.data)}
	free(w.data)
}

// Frees the state of every widget, e.g. before a fresh snapshot run.
@(private)
widget_states_clear :: proc() {
	for _, w in g_widget_states {widget_state_free(w)}
	clear(&g_widget_states)
}

// ---------------------------------------------------------------------------
// Garbage collection of per-element state
// ---------------------------------------------------------------------------

@(private)
STALE_FRAMES :: 256

@(private)
collect_garbage :: proc() {
	for key, t in g_tweens {
		if t.frame + STALE_FRAMES < g_frame {delete_key(&g_tweens, key)}
	}
	for key, e in g_edits {
		if e.frame + STALE_FRAMES < g_frame && key != g_focus {
			delete(e.buf)
			free(e)
			delete_key(&g_edits, key)
		}
	}
	for key, t in g_hover_start {
		if t.frame + STALE_FRAMES < g_frame {delete_key(&g_hover_start, key)}
	}
	for key, t in g_timers {
		if t.frame + STALE_FRAMES < g_frame {delete_key(&g_timers, key)}
	}
	for key, w in g_widget_states {
		if w.frame + STALE_FRAMES < g_frame {
			widget_state_free(w)
			delete_key(&g_widget_states, key)
		}
	}
	for key, cal in g_calendars {
		if cal.frame + STALE_FRAMES < g_frame {delete_key(&g_calendars, key)}
	}
	icons_collect()
}
