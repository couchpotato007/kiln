package icons

// The demo's icons: SVG files next to this one, compiled into the binary. Icons are plain
// values, so they can be constants and sit in tables like `kiln.NavItem`.

import "lib:kiln"

GRID :: kiln.Icon{svg = #load("grid.svg", string)}
TASKS :: kiln.Icon{svg = #load("tasks.svg", string)}
USER :: kiln.Icon{svg = #load("user.svg", string)}
FOLDER :: kiln.Icon{svg = #load("folder.svg", string)}
FILE :: kiln.Icon{svg = #load("file.svg", string)}
SLIDERS :: kiln.Icon{svg = #load("sliders.svg", string)}
SHAPES :: kiln.Icon{svg = #load("shapes.svg", string)}
PEN :: kiln.Icon{svg = #load("pen.svg", string)}

// A colorful SVG keeps its own colors instead of taking the text color.
LOGO :: kiln.Icon{svg = #load("logo.svg", string)}
