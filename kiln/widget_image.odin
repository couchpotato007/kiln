package kiln

// Displays a raylib texture inside the layout. The renderer stretches the texture to the
// element's bounds, so give it a fixed width and height (unscaled units).

import clay "lib:kiln/clay-odin"
import rl "vendor:raylib"

// Appearance of an image element. Create it with `style_image`.
ImageConfig :: struct {
	id:      clay.ElementId,
	texture: ^rl.Texture2D, // raw pointer, as expected by the renderer
	box:     clay.ElementDeclaration, // sizing + optional background / border / radius
}

// Image look from the current theme: fixed size, optional rounded corners and border.
// The texture is drawn stretched over the element's bounds.
style_image :: proc(
	id: clay.ElementId,
	texture: ^rl.Texture2D,
	width: f32,
	height: f32,
	rounded := true,
) -> ImageConfig {
	c := current_theme
	cfg := ImageConfig {
		id = id,
		texture = texture,
		box = {
			layout = {sizing = {clay.SizingFixed(px(width)), clay.SizingFixed(px(height))}},
			backgroundColor = c.bg_sunken,
		},
	}
	if rounded {cfg.box.cornerRadius = radius(.MD)}
	return cfg
}

// Declares an image from a texture. Pass the texture by pointer (raylib textures are values):
//
//   kiln.image(&m.texture, 120, 80)
//   kiln.image_cfg(kiln.style_image(kiln.id_local("thumb"), &m.texture, 120, 80))
image :: proc {
	image_cfg,
	image_short,
}

// Short form with the common fixed-size case.
image_short :: proc(
	texture: ^rl.Texture2D,
	width: f32,
	height: f32,
	id := clay.ElementId{},
) {
	eid := id
	if eid.id == 0 {eid = id_local("image")}
	image_cfg(style_image(eid, texture, width, height))
}

// Declares an image from a full config. `cfg.texture` must point to a loaded texture.
image_cfg :: proc(cfg: ImageConfig) {
	if cfg.texture == nil {return}
	decl := cfg.box
	decl.image = {imageData = cfg.texture}
	if clay.UI(cfg.id)(decl) {}
}
