package kiln

// Collapsible tree view over a slice of TreeNodes. Expand/closed state is pure UI state
// and kept internally, keyed by the path of each node.

import clay "lib:kiln/clay-odin"

// One node of a tree. Leaves simply have no children.
TreeNode :: struct {
	label:    string,
	children: []TreeNode,
}

// Open/closed state of every tree node, keyed by a hash of the node's path.
@(private = "file")
g_tree_open: map[u32]bool

// Declares a tree. `selected` holds the index of the selected node in the flattened list of
// currently visible rows (-1 = none) and is changed when a row is clicked. Returns true in the
// frame in which the selection changed. Clicking the arrow of a parent toggles its children.
// `default_open` is the initial expand state of nodes with children:
//
//   sel := m.selected
//   if kiln.tree(&sel, m.nodes) { append(out, Select_Node{sel}) }
tree :: proc(
	selected: ^int,
	nodes: []TreeNode,
	default_open := true,
	id := clay.ElementId{},
) -> bool {
	eid := resolve_id(id, "tree")
	changed := false
	index := 0
	if clay.UI(eid)(
	{
		layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}},
	},
	) {
		tree_walk(nodes, eid.id, 0, 0, &index, selected, default_open, &changed)
	}
	return changed
}

@(private = "file")
tree_walk :: proc(
	nodes: []TreeNode,
	root: u32,
	path: u32,
	depth: int,
	index: ^int,
	selected: ^int,
	default_open: bool,
	changed: ^bool,
) {
	c := current_theme
	for node, i in nodes {
		key := path * 31 + u32(i) + 1
		open_key := root * 31 + key
		row_id := clay.ID("tree_row", open_key)
		arrow_id := clay.ID("tree_arrow", open_key)
		has_children := len(node.children) > 0

		open, known := g_tree_open[open_key]
		if !known {open = default_open}

		s := interact(row_id)
		if s.clicked && selected^ != index^ {
			selected^ = index^
			changed^ = true
		}
		current := selected^ == index^

		bg: clay.Color
		if current {
			bg = c.surface_2
		} else if s.hovered {
			bg = c.surface_1
		}

		padding := pad_xy(.SM, .XS)
		padding.left = u16(size_px(.MD)) * u16(depth) + sp(.SM)

		if clay.UI(row_id)(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = padding,
				childGap = sp(.SM),
				childAlignment = {y = .Center},
			},
			backgroundColor = bg,
			cornerRadius = radius(.SM),
		},
		) {
			// Fixed-width arrow column keeps labels aligned across depths.
			if clay.UI_AutoId()(
			{
				layout = {
					sizing = {clay.SizingFixed(size_px(.MD)), clay.SizingFixed(0)},
					childAlignment = {x = .Center},
				},
			},
			) {
				if has_children {
					as := interact(arrow_id)
					if as.clicked {g_tree_open[open_key] = !open}
					clay.Text(open ? "v" : ">", text_style(.Body, c.text_muted))
				}
			}
			clay.Text(node.label, text_style(.Body, current ? c.primary : c.text))
		}

		index^ += 1
		if has_children && open {
			tree_walk(node.children, root, key, depth + 1, index, selected, default_open, changed)
		}
	}
}
