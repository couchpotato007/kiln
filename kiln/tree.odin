package kiln

// Collapsible tree view.
//
// Nodes are identified by their index in a depth-first walk over ALL nodes (collapsed ones
// included), so an index stays valid while branches open and close. The open state of a branch
// is UI state and kept here, keyed by the labels on the path to it.

import clay "clay-odin"

// One node of a tree; leaves have no children. `icon` is an optional glyph before the label.
TreeNode :: struct {
	label:    string,
	icon:     string,
	children: []TreeNode,
}

@(private)
g_tree_open: map[u32]bool

// A tree. `selected` is the depth-first index of the selected node (-1 = none); clicking a row
// selects it, the arrow opens / closes a branch. `expanded` is the initial state of branches.
//
//   if i, ok := kiln.tree(m.selected, m.nodes); ok {append(out, Select{i})}
tree :: proc(selected: int, nodes: []TreeNode, expanded := true) -> (int, bool) {
	eid := id("tree")
	w := TreeWalk {
		root     = eid,
		selected = selected,
		result   = selected,
		expanded = expanded,
	}
	if clay.UI(eid)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			childGap = 1,
		},
	},
	) {
		tree_walk(&w, nodes, eid.id, 0)
	}
	set_last(eid)
	return w.result, w.result != selected
}

// The node with the given depth-first index.
tree_find :: proc(nodes: []TreeNode, index: int) -> (node: TreeNode, ok: bool) {
	path := tree_path(nodes, index, context.temp_allocator)
	if len(path) == 0 {return {}, false}
	return path[len(path) - 1], true
}

// The nodes from the root down to the node with the given depth-first index (e.g. breadcrumbs).
tree_path :: proc(nodes: []TreeNode, index: int, allocator := context.temp_allocator) -> []TreeNode {
	path := make([dynamic]TreeNode, allocator)
	i := 0
	find :: proc(nodes: []TreeNode, target: int, i: ^int, path: ^[dynamic]TreeNode) -> bool {
		for n in nodes {
			append(path, n)
			if i^ == target {return true}
			i^ += 1
			if find(n.children, target, i, path) {return true}
			pop(path)
		}
		return false
	}
	find(nodes, index, &i, &path)
	return path[:]
}

@(private)
TreeWalk :: struct {
	root:               Id,
	selected, result:   int,
	index:              int,
	expanded:           bool,
}

@(private)
tree_count :: proc(nodes: []TreeNode) -> int {
	n := len(nodes)
	for node in nodes {n += tree_count(node.children)}
	return n
}

@(private)
tree_walk :: proc(w: ^TreeWalk, nodes: []TreeNode, parent_key: u32, depth: int) {
	c := &g_theme
	for node in nodes {
		mine := w.index
		w.index += 1
		key := clay.ID(node.label, parent_key).id
		branch := len(node.children) > 0

		open, known := g_tree_open[key]
		if !known {open = w.expanded}

		row := sub_id(w.root, "row", mine)
		arrow := sub_id(w.root, "arrow", mine)
		s := interact(row)
		if branch && interact(arrow).clicked {
			open = !open
			g_tree_open[key] = open
		}
		if s.clicked && w.result != mine {w.result = mine}

		on := w.result == mine
		h := anim(row, 0, s.hovered ? 1 : 0)
		bg := mix(fade(c.surface_hover, 0), c.surface_hover, h)
		if on {bg = tone_tint(.Primary)}

		m := size(.Mark)
		padding := inset(.XS, .XS)
		padding.left = u16(m * f32(depth)) + space(.XS)

		if clay.UI(row)(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = padding,
				childGap = space(.XS),
				childAlignment = {y = .Center},
			},
			backgroundColor = bg,
			cornerRadius = corners(.SM),
		},
		) {
			// A fixed arrow column keeps labels aligned across depths.
			if clay.UI(arrow)(
			{
				layout = {
					sizing = {clay.SizingFixed(m), clay.SizingFixed(m)},
					childAlignment = {.Center, .Center},
				},
			},
			) {
				if branch {clay.TextDynamic(open ? "▾" : "▸", font(.Body, c.text_muted))}
			}
			if len(node.icon) > 0 {
				clay.TextDynamic(node.icon, font(.Body, on ? c.primary : c.text_muted))
			}
			clay.TextDynamic(node.label, font(.Body, on ? c.primary : c.text))
		}

		if branch {
			if open {
				tree_walk(w, node.children, key, depth + 1)
			} else {
				w.index += tree_count(node.children) // keep the indices of later nodes stable
			}
		}
	}
}
