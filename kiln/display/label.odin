package display

import clay "lib:kiln/clay-odin"
import th "lib:kiln/theme"

// Text in a typographic role. `color = {}` uses the theme's text color.
//
//   kiln.label("Hinweis", .Caption, kiln.theme().text_muted)
label :: proc(text: string, role := th.FontRole.Body, color := clay.Color{}) {
	col := color
	if col == {} {col = th.current().text}
	clay.Text(text, th.text_style(role, col))
}
