package gallery

import "core:fmt"
import "lib:kiln"
import rl "vendor:raylib"

Model :: struct {
	texture:     rl.Texture2D,
	have_texture: bool,
	favorites:   int,
}

Add_Favorite :: struct {}
Remove_Favorite :: struct {}

Msg :: union #no_nil {
	Add_Favorite,
	Remove_Favorite,
}

init :: proc() -> Model {
	m: Model
	// Procedural texture so the example needs no asset files.
	img := rl.GenImageGradientRadial(160, 160, 0.1, {40, 40, 60, 255}, {203, 166, 247, 255})
	m.texture = rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	m.have_texture = true
	m.favorites = 3
	return m
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Add_Favorite:
		m.favorites += 1
	case Remove_Favorite:
		if m.favorites > 0 {m.favorites -= 1}
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	muted := kiln.current_theme.text_muted

	if kiln.card() {
		kiln.label("Abzeichen", .Subtitle)
		if kiln.vstack(.XS) {
			if kiln.hstack(.SM) {
				kiln.badge("Neutral")
				kiln.badge("Neu", .Primary)
				kiln.badge("Info", .Info)
				kiln.badge("Fehler", .Danger)
			}
			if kiln.hstack(.SM) {
				dot := kiln.style_badge(kiln.id_local("status"), "Online", .Primary)
				dot.dot = true
				kiln.badge_cfg(dot)
				kiln.badge("3", .Info, id = kiln.id_local("count"))
				kiln.badge("99+", .Danger)
			}
		}
		kiln.separator()
	}

	if kiln.card() {
		kiln.label("Ladeanzeige", .Subtitle)
		if kiln.hstack(.SM) {
			kiln.spinner(kiln.style_spinner(kiln.id_local("spin")))
			kiln.label("Wird geladen ...", .Body, muted)
		}
		kiln.separator()
	}

	if kiln.card() {
		kiln.label("Bild", .Subtitle)
		if kiln.hstack(.LG, align = {y = .Top}) {
			if m.have_texture {
				kiln.image(&m.texture, 140, 140)
			}
			if kiln.vstack(.XS) {
				kiln.label("Prozedural erzeugte Textur,", .Body, muted)
				kiln.label("als Element in das Layout eingebettet.", .Body, muted)
				kiln.label(fmt.tprintf("%d x %d px", m.texture.width, m.texture.height), .Caption, muted)
			}
		}
		kiln.separator()
	}

	if kiln.card() {
		kiln.label("Tooltips", .Subtitle)
		kiln.label("Maus kurz über einen Knopf halten.", .Caption, muted)
		if kiln.hstack(.SM) {
			speichern := kiln.id_local("save")
			if kiln.button("Speichern", .Secondary, id = speichern) {}
			kiln.tooltip(kiln.style_tooltip(speichern, "Strg+S"))

			laden := kiln.id_local("load")
			if kiln.button("Neu laden", .Secondary, id = laden) {}
			kiln.tooltip(kiln.style_tooltip(laden, "Strg+R"))

			fav := kiln.id_local("fav")
			fav_cfg := kiln.style_button(fav, fmt.tprintf("Favoriten (%d)", m.favorites))
			if kiln.button_cfg(fav_cfg) {}
			kiln.tooltip(kiln.style_tooltip(fav, "Zu Favoriten hinzufügen"))
		}
		if kiln.hstack(.SM) {
			kiln.spacer()
			if kiln.button("Plus", .Ghost, id = kiln.id_local("plus")) {append(out, Add_Favorite{})}
			if kiln.button("Minus", .Ghost, id = kiln.id_local("minus")) {append(out, Remove_Favorite{})}
		}
	}
}
