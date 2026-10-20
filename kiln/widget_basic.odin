package kiln

// Einfache, zustandslose Bausteine: label, separator, progress, scroll_clip

import clay "lib:kiln/clay-odin"

// Text in Theme-Farbe. color = {} -> Standard-Textfarbe.
// Beispiel: label("Hinweis", .Caption, kiln.current_theme.text_muted)
label :: proc(text: string, role := FontRole.Body, color := clay.Color{}) {
	col := color
	if col == {} {col = current_theme.text}
	clay.Text(text, text_style(role, col))
}

separator :: proc(vertical := false) {
	w := border_px()
	sizing :=
		vertical ? clay.Sizing{clay.SizingFixed(w), clay.SizingGrow()} : clay.Sizing{clay.SizingGrow(), clay.SizingFixed(w)}
	if clay.UI_AutoId()({layout = {sizing = sizing}, backgroundColor = current_theme.border}) {}
}

// Clip-Config für scrollbare Container. Direkt in der Deklaration verwenden:
//   if clay.UI_AutoId()({ layout = {...}, clip = scroll_clip() }) { ... }
scroll_clip :: proc(vertical := true, horizontal := false) -> clay.ClipElementConfig {
	return {horizontal = horizontal, vertical = vertical, childOffset = clay.GetScrollOffset()}
}

// Fortschrittsbalken, value in [0, 1]. Der Wert wird weich nachgeführt.
//   kiln.progress(0.4)
progress :: proc(value: f32, id := clay.ElementId{}) {
	c := current_theme
	eid := resolve_id(id, "progress")
	v := anim(eid, 0, clamp(value, 0, 1))
	h := size_px(.SM)
	r := clay.CornerRadiusAll(h / 2)
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(h)}},
		backgroundColor = c.surface_1,
		cornerRadius = r,
	},
	) {
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingPercent(v), clay.SizingGrow()}},
			backgroundColor = c.primary,
			cornerRadius = r,
		},
		) {}
	}
}
