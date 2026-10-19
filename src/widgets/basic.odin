package widgets

// Einfache, zustandslose Bausteine: label, separator, progress, scroll_clip

import clay "lib:clay-odin"
import "lib:theme"

// Text in Theme-Farbe. color = {} -> Standard-Textfarbe.
// Beispiel: label("Hinweis", .Caption, theme.current.text_muted)
label :: proc(text: string, role := theme.FontRole.Body, color := clay.Color{}) {
	col := color
	if col == {} {col = theme.current.text}
	clay.Text(text, theme.text_style(role, col))
}

separator :: proc(vertical := false) {
	w := theme.px(theme.BORDER_WIDTH)
	sizing :=
		vertical ? clay.Sizing{clay.SizingFixed(w), clay.SizingGrow()} : clay.Sizing{clay.SizingGrow(), clay.SizingFixed(w)}
	if clay.UI_AutoId()({layout = {sizing = sizing}, backgroundColor = theme.current.border}) {}
}

// Clip-Config für scrollbare Container. Direkt in der Deklaration verwenden:
//   if clay.UI_AutoId()({ layout = {...}, clip = scroll_clip() }) { ... }
scroll_clip :: proc(vertical := true, horizontal := false) -> clay.ClipElementConfig {
	return {horizontal = horizontal, vertical = vertical, childOffset = clay.GetScrollOffset()}
}

ProgressConfig :: struct {
	id:         clay.ElementId,
	box:        clay.ElementDeclaration, // Track
	fill_color: clay.Color,
	speed:      f32, // Glättung des Wertes
}

style_progress :: proc(id: clay.ElementId) -> ProgressConfig {
	c := theme.current
	height: f32 = 8
	return {
		id = id,
		box = {
			layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(theme.px(height))}},
			backgroundColor = c.surface_1,
			cornerRadius = clay.CornerRadiusAll(theme.px(height) / 2),
		},
		fill_color = c.primary,
		speed = 10,
	}
}

// value in [0, 1]
progress :: proc(value: f32, cfg: ProgressConfig) {
	v := anim(cfg.id, 0, clamp(value, 0, 1), cfg.speed)
	if clay.UI(cfg.id)(cfg.box) {
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingPercent(v), clay.SizingGrow()}},
			backgroundColor = cfg.fill_color,
			cornerRadius = cfg.box.cornerRadius,
		},
		) {}
	}
}
