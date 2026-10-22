> [!CAUTION]
> This hole repo is vibecoded
> The API is utterly garbage

# What is it

It is a small ui framework library build with
[clay](https://github.com/nicbarker/clay) and
[raylib](https://github.com/raysan5/raylib)

It is designed to be used by me

# Usage

The whole library is one package: `kiln`. Apps import it once, the
`lib` collection points at the repo root.

```odin
import "lib:kiln"

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card() {
		kiln.label("Hallo", .Title, kiln.current_theme.primary)
		if kiln.button("Los") {append(out, Submit{})}
	}
}

main :: proc() {
	kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, title = "Meine App")
}
```

Layout ids come from `kiln.id` / `kiln.id_local`, so no clay import is needed
for normal apps.

Run the example from the repo root:

    odin run example -collection:lib=.

Look into the example directory it uses the elm mvu architecture to build
composable ui apps

# Problems

There will be problems becaues the hole code was written with claude free

If you find problems clone the repo and fix it. Or dont


# AI Disclamer

Its all vibe

Some say "I guided the AI" I didnt

Some say "I testet the Code" I didnt (the AI did it said its good)
