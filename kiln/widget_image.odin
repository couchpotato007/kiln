package kiln

// Displays a raylib texture inside the layout. The renderer stretches the texture to the
// element's bounds, so the image has a fixed width and height (unscaled units).

import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Declares an image from a texture, with rounded corners unless `rounded = false`.
// Pass the texture by pointer (raylib textures are values):
//
//   kiln.image(&m.texture, 120, 80)
//   kiln.image(&m.texture, 120, 80, id = kiln.id_local("thumb", u32(i)))   // in loops
image :: proc(
	texture: ^rl.Texture2D,
	width, height: f32,
	rounded := true,
	id := clay.ElementId{},
) {
	if texture == nil {return}
	eid := resolve_id(id, "image")
	decl := clay.ElementDeclaration {
		layout = {sizing = {clay.SizingFixed(px(width)), clay.SizingFixed(px(height))}},
		backgroundColor = current_theme.bg_sunken,
		image = {imageData = texture},
	}
	if rounded {decl.cornerRadius = radius(.MD)}
	if clay.UI(eid)(decl) {}
}
