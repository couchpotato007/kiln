package treeview

import "core:fmt"
import "lib:kiln"

NODES := []kiln.TreeNode {
	{
		label = "src",
		children = []kiln.TreeNode {
			{label = "main.odin"},
			{
				label = "counter",
				children = []kiln.TreeNode{{label = "counter.odin"}},
			},
		},
	},
	{
		label = "lib",
		children = []kiln.TreeNode {
			{
				label = "kiln",
				children = []kiln.TreeNode {
					{label = "kiln.odin"},
					{
						label = "theme",
						children = []kiln.TreeNode {
							{label = "theme.odin"},
							{label = "units.odin"},
						},
					},
					{
						label = "controls",
						children = []kiln.TreeNode {
							{label = "button.odin"},
							{label = "slider.odin"},
						},
					},
				},
			},
		},
	},
	{
		label = "resources",
		children = []kiln.TreeNode{{label = "Iosevka-Regular.ttf"}, {label = "Iosevka-SemiBold.ttf"}},
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
	return {nodes = NODES, selected = -1}
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
	muted := kiln.theme().text_muted

	if kiln.card() {
		kiln.label("Dateibaum", .Subtitle)
		kiln.label("Pfeil klappt auf/zu, Zeile wählt aus.", .Caption, muted)

		if kiln.scroll_view(260) {
			selected := m.selected
			if kiln.tree(&selected, m.nodes) {append(out, Select_Node{selected})}
		}

		kiln.separator()
		if node, ok := kiln.tree_find(m.nodes, m.selected); ok {
			if kiln.hstack() {
				kiln.label(fmt.tprintf("Ausgewählt: %s", node.label), .Body, kiln.theme().secondary)
				kiln.spacer()
				if kiln.button("Auswahl aufheben", .Ghost) {append(out, Clear_Selection{})}
			}
		} else {
			kiln.label("Nichts ausgewählt.", .Body, muted)
		}
	}
}
