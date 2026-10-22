package display

// Collapsible tree view over a slice of TreeNodes.
//
// Nodes are identified by their index in a depth-first walk over ALL nodes, collapsed ones
// included (see `tree_find`). The index of a node therefore does not change when other
// branches are expanded or collapsed, so `selected` stays valid. The expand state is pure UI
// state and kept internally, keyed by the tree id and that index.

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"

// One node of a tree. Leaves simply have no children.
TreeNode :: struct {
	label:    string,
	children: []TreeNode,
}

@(private)
g_open: map[u64]bool

// Declares a tree. `selected` is the depth-first index of the selected node (-1 = none) and is
// changed when a row is clicked. The arrow of a parent toggles its children without selecting it.
// `default_open` is the initial expand state of nodes with children. Returns true in the frame
// in which the selection changed:
//
//   sel := m.selected
//   if kiln.tree(&sel, m.nodes) { append(out, Select_Node{sel}) }
tree :: proc(
	selected: ^int,
	nodes: []TreeNode,
	default_open := true,
	id := clay.ElementId{},
) -> bool {
	eid := fd.resolve_id(id, "tree")
	changed := false
	index := 0
	if clay.UI(eid)(
	{
		layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}},
	},
	) {
		walk(nodes, eid, 0, &index, selected, default_open, &changed)
	}
	return changed
}

// Returns the node with the given depth-first index, e.g. to show the selected node's label.
tree_find :: proc(nodes: []TreeNode, index: int) -> (node: TreeNode, ok: bool) {
	i := 0
	return find(nodes, index, &i)
}

@(private)
find :: proc(nodes: []TreeNode, target: int, i: ^int) -> (node: TreeNode, ok: bool) {
	for n in nodes {
		if i^ == target {return n, true}
		i^ += 1
		if found, hit := find(n.children, target, i); hit {return found, true}
	}
	return {}, false
}

@(private)
count :: proc(nodes: []TreeNode) -> int {
	n := len(nodes)
	for node in nodes {n += count(node.children)}
	return n
}

@(private)
walk :: proc(
	nodes: []TreeNode,
	root: clay.ElementId,
	depth: int,
	index: ^int,
	selected: ^int,
	default_open: bool,
	changed: ^bool,
) {
	c := th.current()
	for node in nodes {
		mine := index^
		index^ += 1

		row_id := fd.child_id(root, "row", mine)
		arrow_id := fd.child_id(root, "arrow", mine)
		key := u64(root.id) << 32 | u64(mine)
		has_children := len(node.children) > 0

		open, known := g_open[key]
		if !known {open = default_open}

		// The row first, then the arrow: the last `interact` wins a press, so a click on the
		// arrow only toggles and does not select the row.
		rs := fd.interact(row_id)
		if has_children {
			if fd.interact(arrow_id).clicked {
				open = !open
				g_open[key] = open
			}
		}
		if rs.clicked && selected^ != mine {
			selected^ = mine
			changed^ = true
		}

		is_selected := selected^ == mine
		bg: clay.Color
		if is_selected {
			bg = c.surface_2
		} else if rs.hovered {
			bg = c.surface_1
		}

		padding := th.pad_xy(.SM, .XS)
		padding.left = u16(th.size_px(.Mark)) * u16(depth) + th.sp(.SM)

		if clay.UI(row_id)(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = padding,
				childGap = th.sp(.SM),
				childAlignment = {y = .Center},
			},
			backgroundColor = bg,
			cornerRadius = th.radius(.SM),
		},
		) {
			// Fixed-width arrow column keeps the labels aligned across depths.
			if clay.UI(arrow_id)(
			{
				layout = {
					sizing = {clay.SizingFixed(th.size_px(.Mark)), clay.SizingFit()},
					childAlignment = {x = .Center},
				},
			},
			) {
				if has_children {
					clay.Text(open ? "v" : ">", th.text_style(.Body, c.text_muted))
				}
			}
			clay.Text(node.label, th.text_style(.Body, is_selected ? c.primary : c.text))
		}

		if has_children {
			if open {
				walk(node.children, root, depth + 1, index, selected, default_open, changed)
			} else {
				index^ += count(node.children) // keep the indices of the following nodes stable
			}
		}
	}
}
