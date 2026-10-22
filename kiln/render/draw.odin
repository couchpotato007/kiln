package render

// Draws Clay's render commands with raylib.

import "core:math"
import "core:strings"
import clay "lib:kiln/clay-odin"
import th "lib:kiln/theme"
import rl "vendor:raylib"

@(private)
to_rl :: proc(color: clay.Color) -> rl.Color {
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

// Executes all render commands of a frame. Call between `rl.BeginDrawing` and `rl.EndDrawing`.
// Temporary strings are allocated with `allocator`, which the caller frees once per frame.
draw :: proc(
	commands: ^clay.ClayArray(clay.RenderCommand),
	allocator := context.temp_allocator,
) {
	overlays := make([dynamic]clay.Color, allocator)

	for i in 0 ..< commands.length {
		cmd := clay.RenderCommandArray_Get(commands, i)
		bounds := cmd.boundingBox

		switch cmd.commandType {
		case .None:
		case .Text:
			d := cmd.renderData.text
			text := string(d.stringContents.chars[:d.stringContents.length])
			rl.DrawTextEx(
				fonts[th.FontRole(d.fontId)],
				strings.clone_to_cstring(text, allocator),
				{bounds.x, bounds.y},
				f32(d.fontSize),
				f32(d.letterSpacing),
				to_rl(d.textColor),
			)
		case .Image:
			d := cmd.renderData.image
			tint: clay.Color = {255, 255, 255, 255}
			if len(overlays) > 0 {tint = overlays[len(overlays) - 1]}
			texture := (^rl.Texture2D)(d.imageData)
			rl.DrawTexturePro(
				texture^,
				{0, 0, f32(texture.width), f32(texture.height)},
				{bounds.x, bounds.y, bounds.width, bounds.height},
				{0, 0},
				0,
				to_rl(tint),
			)
		case .ScissorStart:
			rl.BeginScissorMode(
				i32(math.round(bounds.x)),
				i32(math.round(bounds.y)),
				i32(math.round(bounds.width)),
				i32(math.round(bounds.height)),
			)
		case .ScissorEnd:
			rl.EndScissorMode()
		case .Rectangle:
			d := cmd.renderData.rectangle
			if d.cornerRadius.topLeft > 0 {
				rect_rounded(bounds, d.cornerRadius.topLeft, d.backgroundColor)
			} else {
				rect(bounds.x, bounds.y, bounds.width, bounds.height, d.backgroundColor)
			}
		case .Border:
			border(bounds, cmd.renderData.border)
		case .OverlayColorStart:
			append(&overlays, cmd.renderData.overlayColor.color)
		case .OverlayColorEnd:
			if len(overlays) > 0 {pop(&overlays)}
		case .Custom:
		}
	}
}

@(private)
border :: proc(b: clay.BoundingBox, d: clay.BorderRenderData) {
	r := d.cornerRadius
	w := d.width
	if w.left > 0 {
		rect(b.x, b.y + r.topLeft, f32(w.left), b.height - r.topLeft - r.bottomLeft, d.color)
	}
	if w.right > 0 {
		rect(
			b.x + b.width - f32(w.right),
			b.y + r.topRight,
			f32(w.right),
			b.height - r.topRight - r.bottomRight,
			d.color,
		)
	}
	if w.top > 0 {
		rect(b.x + r.topLeft, b.y, b.width - r.topLeft - r.topRight, f32(w.top), d.color)
	}
	if w.bottom > 0 {
		rect(
			b.x + r.bottomLeft,
			b.y + b.height - f32(w.bottom),
			b.width - r.bottomLeft - r.bottomRight,
			f32(w.bottom),
			d.color,
		)
	}

	if r.topLeft > 0 {
		arc(b.x + r.topLeft, b.y + r.topLeft, r.topLeft, f32(w.top), 180, 270, d.color)
	}
	if r.topRight > 0 {
		arc(b.x + b.width - r.topRight, b.y + r.topRight, r.topRight, f32(w.top), 270, 360, d.color)
	}
	if r.bottomLeft > 0 {
		arc(
			b.x + r.bottomLeft,
			b.y + b.height - r.bottomLeft,
			r.bottomLeft,
			f32(w.bottom),
			90,
			180,
			d.color,
		)
	}
	if r.bottomRight > 0 {
		arc(
			b.x + b.width - r.bottomRight,
			b.y + b.height - r.bottomRight,
			r.bottomRight,
			f32(w.bottom),
			0,
			90,
			d.color,
		)
	}
}

@(private)
arc :: proc(x, y, outer: f32, width: f32, from, to: f32, color: clay.Color) {
	rl.DrawRing(
		{math.round(x), math.round(y)},
		max(0, math.round(outer - width)),
		outer,
		from,
		to,
		12,
		to_rl(color),
	)
}

@(private)
rect :: proc(x, y, w, h: f32, color: clay.Color) {
	rl.DrawRectangle(
		i32(math.round(x)),
		i32(math.round(y)),
		i32(math.round(w)),
		i32(math.round(h)),
		to_rl(color),
	)
}

@(private)
rect_rounded :: proc(b: clay.BoundingBox, radius: f32, color: clay.Color) {
	roundness := min(1, radius * 2 / max(1, min(b.width, b.height)))
	rl.DrawRectangleRounded({b.x, b.y, b.width, b.height}, roundness, 12, to_rl(color))
}
