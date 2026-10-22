package gallery

import "core:fmt"
import "lib:kiln"
import rl "vendor:raylib"

Model :: struct {
	texture:   rl.Texture2D,
	favorites: int,
}

Add_Favorite :: struct {}
Remove_Favorite :: struct {}

Msg :: union #no_nil {
	Add_Favorite,
	Remove_Favorite,
}

init :: proc() -> Model {
	// Procedural texture so the example needs no asset files.
	img := rl.GenImageGradientRadial(160, 160, 0.1, {40, 40, 60, 255}, {203, 166, 247, 255})
	defer rl.UnloadImage(img)
	return {texture = rl.LoadTextureFromImage(img), favorites = 3}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Add_Favorite:
		m.favorites += 1
	case Remove_Favorite:
		m.favorites = max(0, m.favorites - 1)
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	muted := kiln.theme().text_muted

	if kiln.card() {
		kiln.label("Abzeichen", .Subtitle)
		if kiln.vstack(.XS) {
			if kiln.hstack() {
				kiln.badge("Neutral")
				kiln.badge("Neu", .Primary)
				kiln.badge("Info", .Info)
				kiln.badge("Fehler", .Danger)
			}
			if kiln.hstack() {
				kiln.badge("Online", .Primary, dot = true)
				kiln.badge("3", .Info)
				kiln.badge("99+", .Danger)
			}
		}
	}

	if kiln.card() {
		kiln.label("Ladeanzeige", .Subtitle)
		if kiln.hstack() {
			kiln.spinner()
			kiln.label("Wird geladen ...", .Body, muted)
		}
	}

	if kiln.card() {
		kiln.label("Bild", .Subtitle)
		if kiln.hstack(.LG, align = {y = .Top}) {
			kiln.image(&m.texture, 140, 140)
			if kiln.vstack(.XS) {
				kiln.label("Prozedural erzeugte Textur,", .Body, muted)
				kiln.label("als Element in das Layout eingebettet.", .Body, muted)
				kiln.label(fmt.tprintf("%d x %d px", m.texture.width, m.texture.height), .Caption, muted)
			}
		}
	}

	if kiln.card() {
		kiln.label("Tooltips", .Subtitle)
		kiln.label("Maus kurz über einen Knopf halten.", .Caption, muted)
		if kiln.hstack() {
			save := kiln.id_local("save")
			if kiln.button("Speichern", .Secondary, id = save) {}
			kiln.tooltip(save, "Strg+S")

			reload := kiln.id_local("reload")
			if kiln.button("Neu laden", .Secondary, id = reload) {}
			kiln.tooltip(reload, "Strg+R")

			fav := kiln.id_local("fav")
			if kiln.button(fmt.tprintf("Favoriten (%d)", m.favorites), id = fav) {}
			kiln.tooltip(fav, "Zu Favoriten hinzufügen")
		}
		if kiln.hstack() {
			kiln.spacer()
			if kiln.button("Plus", .Ghost) {append(out, Add_Favorite{})}
			if kiln.button("Minus", .Ghost) {append(out, Remove_Favorite{})}
		}
	}
}
