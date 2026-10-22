package display

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"
import rl "vendor:raylib"

// Displays a raylib texture inside the layout. The renderer stretches the texture to the
// element's bounds, so the image has a fixed width and height (unscaled units).
// Pass the texture by pointer (raylib textures are values):
//
//   kiln.image(&m.texture, 120, 80)
//   kiln.image(&m.texture, 120, 80, id = kiln.id_local("thumb", u32(i)))   // in loops
image :: proc(texture: ^rl.Texture2D, width, height: f32, id := clay.ElementId{}) {
	if texture == nil {return}
	eid := fd.resolve_id(id, "image")
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingFixed(th.px(width)), clay.SizingFixed(th.px(height))}},
		backgroundColor = th.current().bg_sunken,
		image = {imageData = texture},
	},
	) {}
}
