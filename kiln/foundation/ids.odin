package foundation

// Element ids. Every widget has an `id` parameter (always the last one). Without it the id is
// derived from the widget's label/kind and the parent element, so widgets that are declared
// several times in the same parent (loops, identical labels) need an explicit id.

import clay "lib:kiln/clay-odin"

// Stable element id derived from a label. Wraps `clay.ID`.
id :: clay.ID

// Element id scoped to the currently open element (use inside loops). Wraps `clay.ID_LOCAL`.
//
//   kiln.button("x", .Ghost, id = kiln.id_local("del", u32(i)))
id_local :: clay.ID_LOCAL

// Uses `explicit` if given, otherwise derives an id from `fallback` and the parent element.
resolve_id :: proc(explicit: clay.ElementId, fallback: string) -> clay.ElementId {
	if explicit.id != 0 {return explicit}
	return id_local(fallback)
}

// Derives an id for a part of a widget (list item, tab, segment, ...) from the widget's id.
child_id :: proc(parent: clay.ElementId, name: string, index := 0) -> clay.ElementId {
	return clay.ID(name, parent.id + u32(index + 1) * 0x9E3779B1)
}

// Stacking order of floating elements.
Z_POPUP :: 100 // dropdown lists, menus
Z_TOOLTIP :: 200
Z_MODAL :: 250
