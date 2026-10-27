---
title: Getting started
description: Clone it, point the lib collection at it, write a view.
---

:::caution
This hole repo is vibecoded. The API is utterly garbage. You have been warned.
:::

## What you need

- [Odin](https://odin-lang.org). raylib comes with Odin (`vendor:raylib`), clay is in
  `kiln/clay-odin`, so there is nothing else to install.
- On NixOS: `nix develop` (or direnv) gives you a shell with Odin, ols, raylib and the libs
  raylib wants at runtime.

## Setup

kiln is not a package you install, it is a folder. Clone the repo and point a collection called
`lib` at the repo root:

```sh
git clone https://github.com/couchpotato007/kiln
odin run example -collection:lib=kiln
```

In your app you then import it like this:

```odin
import "lib:kiln"
```

For ols put the collection into `ols.json`:

```json
{
  "collections": [{ "name": "lib", "path": "path/to/kiln" }]
}
```

## The smallest app

A counter. The model is a struct, the messages are a union, and `view` turns clicks into
messages:

```odin
package main

import "core:fmt"
import "lib:kiln"

Model :: struct {
	count: int,
}

Increment :: struct {}
Reset :: struct {}

Msg :: union {
	Increment,
	Reset,
}

init :: proc() -> Model {return {}}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Increment:
		m.count += 1
	case Reset:
		m.count = 0
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.center() {
		if kiln.card("Zähler") {
			kiln.text(fmt.tprint(m.count), .Headline)
			if kiln.actions() {
				if kiln.button("Reset", .Ghost) {append(out, Reset{})}
				if kiln.button("+1") {append(out, Increment{})}
			}
		}
	}
}

main :: proc() {
	kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, {title = "Zähler"})
}
```

Strings given to widgets only have to live until the end of the frame, so `fmt.tprint` (temp
allocator) is fine there.

Run it:

```sh
odin run . -collection:lib=path/to/kiln
```

`Ctrl +` / `Ctrl −` / `Ctrl 0` zooms. That also moves the app between screen classes, so it is
the fast way to see the phone layout.

## The example

The repo has a bigger demo with six pages: dashboard (grid, chart, counter), tasks (list with
menus and filters), people (sortable table with master-detail editor), files (tree with preview),
settings (a form that changes the theme) and a gallery of all widgets.

```sh
odin run example -collection:lib=.
```

It has a sidebar on wide windows, an icon rail on medium ones and a top bar with a drawer on
phones. Each page is its own module with `Model`, `Msg`, `update` and `view`, glued together
with [`kiln.embed`](/api/app/#embed). Read it if the docs are not enough. They probably are not.

## Next

- [The rules](/guides/rules/): the seven rules every part of the API follows. Read this one.
- [API](/api/): every proc with its arguments.
