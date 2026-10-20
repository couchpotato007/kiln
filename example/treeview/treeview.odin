package treeview

import "core:fmt"
import "lib:kiln"

NODES := []kiln.TreeNode {
	{
		label = "src",
		children = []kiln.TreeNode {
			{label = "main.odin"},
			{label = "app.odin"},
			{
				label = "kiln",
				children = []kiln.TreeNode {
					{label = "widget_button.odin"},
					{label = "widget_slider.odin"},
					{label = "widget_tree.odin"},
					{label = "theme.odin"},
				},
			},
		},
	},
	{
		label = "resources",
		children = []kiln.TreeNode {
			{label = "Iosevka-Regular.ttf"},
			{label = "Iosevka-SemiBold.ttf"},
		},
	},
	{label = "README.md"},
	{label = "flake.nix"},
}

Model :: struct {
	nodes:    []kiln.TreeNode,
	selected: int,
}

Select_Node :: struct {
	index: int,
}
Clear_Selection :: struct {}

Msg :: union #no_nil {
	Select_Node,
	Clear_Selection,
}

init :: proc() -> Model {
	return {nodes = NODES[:], selected = -1}
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Select_Node:
		m.selected = v.index
	case Clear_Selection:
		m.selected = -1
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	muted := kiln.current_theme.text_muted

	if kiln.card() {
		kiln.label("Dateibaum", .Subtitle)
		kiln.label("Pfeil klappt zu, Zeile wählt.", .Caption, muted)

		if kiln.scroll_view(260) {
			sel := m.selected
			if kiln.tree(&sel, m.nodes, kiln.style_tree(kiln.id_local("files"))) {
				append(out, Select_Node{sel})
			}
		}

		kiln.separator()
		if m.selected >= 0 {
			if kiln.hstack(.SM) {
				kiln.label(fmt.tprintf("Ausgewählt: Index %d", m.selected), .Body, kiln.current_theme.secondary)
				kiln.spacer()
				if kiln.button("Auswahl aufheben", .Ghost) {append(out, Clear_Selection{})}
			}
		} else {
			kiln.label("Nichts ausgewählt.", .Body, muted)
		}
	}
}
