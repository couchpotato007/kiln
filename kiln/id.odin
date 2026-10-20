package kiln

import clay "lib:kiln/clay-odin"

// Stable element id derived from a label. Wraps `clay.ID` so apps never have to
// import the clay binding themselves.
id :: clay.ID

// Element id scoped to the currently open element (nested ids in loops).
// Wraps `clay.ID_LOCAL`.
id_local :: clay.ID_LOCAL
