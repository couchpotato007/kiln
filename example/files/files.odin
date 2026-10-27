package files

// A file tree with a preview pane: side by side on wide windows, stacked on medium ones, and
// one at a time (tree, then preview with a back button) on compact screens.

import "core:fmt"
import "core:strings"
import "../icons"
import "lib:kiln"

DIR :: icons.FOLDER
FILE :: icons.FILE

NODES := []kiln.TreeNode {
	{
		label = "example",
		icon = DIR,
		children = []kiln.TreeNode {
			{label = "main.odin", icon = FILE},
			{label = "dashboard", icon = DIR, children = []kiln.TreeNode{{label = "dashboard.odin", icon = FILE}}},
			{label = "tasks", icon = DIR, children = []kiln.TreeNode{{label = "tasks.odin", icon = FILE}}},
		},
	},
	{
		label = "kiln",
		icon = DIR,
		children = []kiln.TreeNode {
			{label = "kiln.odin", icon = FILE},
			{label = "layout.odin", icon = FILE},
			{label = "controls.odin", icon = FILE},
			{label = "table.odin", icon = FILE},
			{label = "clay-odin", icon = DIR, children = []kiln.TreeNode{{label = "clay.odin", icon = FILE}}},
		},
	},
	{
		label = "resources",
		icon = DIR,
		children = []kiln.TreeNode {
			{label = "Iosevka-Regular.ttf", icon = FILE},
			{label = "Iosevka-SemiBold.ttf", icon = FILE},
		},
	},
	{label = "README.md", icon = FILE},
	{label = "flake.nix", icon = FILE},
}

// A few lines of made-up content per file.
PREVIEW := [?][2]string {
	{"main.odin", "package main\n\nimport \"lib:kiln\"\n\nmain :: proc() {\n    kiln.run(app, {title = \"Kiln Demo\"})\n}"},
	{"kiln.odin", "package kiln\n\n// kiln: a small immediate-mode UI library\n// on top of Clay, with a raylib backend."},
	{"layout.odin", "@(deferred_none = close_box)\ngrid :: proc(min_width: f32, gap := Space.MD) -> bool {\n    ...\n}"},
	{"README.md", "# What is it\n\nA small UI framework built with clay and raylib."},
	{"flake.nix", "{\n  description = \"Eine einfache Nix dev shell\";\n}"},
}

preview_text :: proc(name: string) -> (string, bool) {
	for p in PREVIEW {
		if p[0] == name {return p[1], true}
	}
	return "(keine Vorschau verfügbar)", false
}

Model :: struct {
	selected: int, // depth-first index into NODES, -1 = none
}

Select :: struct {
	index: int,
}

Msg :: union {
	Select,
}

init :: proc() -> Model {
	return {selected = 1}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Select:
		m.selected = v.index
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.screen() == .Compact {
		if m.selected >= 0 {
			if kiln.button("← Alle Dateien", .Ghost) {append(out, Select{-1})}
			preview(m, out)
		} else {
			tree_card(m, out)
		}
		return
	}

	if kiln.adaptive(760, .LG) {
		if kiln.column(width = 300) {tree_card(m, out)}
		if kiln.column() {preview(m, out)}
	}
}

tree_card :: proc(m: ^Model, out: ^[dynamic]Msg) {
	if kiln.card(padding = .SM) {
		if i, ok := kiln.tree(m.selected, NODES); ok {append(out, Select{i})}
	}
}

preview :: proc(m: ^Model, out: ^[dynamic]Msg) {
	path := kiln.tree_path(NODES, m.selected)
	if len(path) == 0 {
		if kiln.card() {
			if kiln.column(padding = .XL, align = .Center) {
				kiln.text("Wähle links eine Datei aus.", .Body, .Faint)
			}
		}
		return
	}
	node := path[len(path) - 1]

	names := make([]string, len(path), context.temp_allocator)
	for n, i in path {names[i] = n.label}

	if kiln.card(gap = .MD) {
		kiln.text(strings.join(names, " / ", context.temp_allocator), .Caption, .Muted)
		if kiln.row(.SM) {
			kiln.text(node.label, .Title)
			kiln.spacer()
			if len(node.children) > 0 {
				kiln.badge(fmt.tprintf("%d Einträge", len(node.children)), .Info)
			} else {
				kiln.badge(extension(node.label), .Primary)
			}
		}
		kiln.separator()

		if len(node.children) > 0 {
			// A folder: its entries, clickable.
			child := m.selected + 1
			for c in node.children {
				if kiln.list_item() {
					kiln.icon(c.icon, .Body, .Muted)
					kiln.text(c.label)
				}
				if kiln.clicked() {append(out, Select{child})}
				child += 1 + count(c.children)
			}
		} else {
			content, ok := preview_text(node.label)
			if kiln.column(.None, padding = .MD, bg = .Sunken) {
				for line in strings.split_lines(content, context.temp_allocator) {
					kiln.text(len(line) > 0 ? line : "\u00A0", .Body, ok ? .Default : .Faint) // keep empty lines
				}
			}
		}
	}
}

count :: proc(nodes: []kiln.TreeNode) -> int {
	n := len(nodes)
	for c in nodes {n += count(c.children)}
	return n
}

extension :: proc(name: string) -> string {
	i := strings.last_index_byte(name, '.')
	return i >= 0 ? strings.to_upper(name[i + 1:], context.temp_allocator) : "Datei"
}
