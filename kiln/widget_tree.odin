package kiln

// Collapsible tree view over a slice of TreeNodes. Expand/closed state is pure UI state
// and kept internally, keyed by the path of each node.

import clay "lib:kiln/clay-odin"

// One node of a tree. Leaves simply have no children.
TreeNode :: struct {
	label:    string,
	children: []TreeNode,
}

// Appearance of a tree. Create it with `style_tree`.
TreeConfig :: struct {
	id:            clay.ElementId,
	row:           clay.ElementDeclaration, // one row (padding, radius)
	text:          clay.TextElementConfig,
	row_hover:     clay.Color,
	row_selected:  clay.Color,
	selected_text: clay.Color,
	arrow_color:   clay.Color,
	indent:        f32, // unscaled horizontal offset per depth level
	default_open:  bool, // initial expand state of nodes with children
}

// Tree look from the current theme: flat rows that highlight on hover and selection.
style_tree :: proc(id: clay.ElementId, default_open := true) -> TreeConfig {
	c := current_theme
	return {
		id = id,
		row = {
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = pad_xy(.SM, .XS),
				childGap = sp(.SM),
				childAlignment = {y = .Center},
			},
			cornerRadius = radius(.SM),
		},
		text = text_style(.Body, c.text),
		row_hover = c.surface_1,
		row_selected = c.surface_2,
		selected_text = c.primary,
		arrow_color = c.text_muted,
		indent = 16,
		default_open = default_open,
	}
}

// Open/closed state of every tree node, keyed by a hash of the node's path.
@(private = "file")
g_tree_open: map[u32]bool

// Declares a tree. `selected` holds the index of the selected node in the flattened list of
// currently visible rows (-1 = none) and is changed when a row is clicked. Returns true in the
// frame in which the selection changed. Clicking the arrow of a parent toggles its children:
//
//   sel := m.selected
//   if kiln.tree(&sel, m.nodes, kiln.style_tree(kiln.id_local("files"))) {
//       append(out, Select_Node{sel})
//   }
tree :: proc(selected: ^int, nodes: []TreeNode, cfg: TreeConfig) -> bool {
	changed := false
	index := 0
	if clay.UI(cfg.id)(
	{
		layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}},
	},
	) {
		tree_walk(nodes, cfg.id.id, 0, 0, &index, selected, cfg, &changed)
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
	cfg: TreeConfig,
	changed: ^bool,
) {
	for node, i in nodes {
		key := path*31 + u32(i) + 1
		open_key := root*31 + key
		row_id := clay.ID("tree_row", open_key)
		arrow_id := clay.ID("tree_arrow", open_key)
		has_children := len(node.children) > 0

		open, known := g_tree_open[open_key]
		if !known {open = cfg.default_open}

		s := interact(row_id)
		if s.clicked && selected^ != index^ {
			selected^ = index^
			changed^ = true
		}
		current := selected^ == index^

		row := cfg.row
		if current {
			row.backgroundColor = cfg.row_selected
		} else if s.hovered {
			row.backgroundColor = cfg.row_hover
		}
		row.layout.padding.left = px16(cfg.indent * f32(depth)) + sp(.SM)

		if clay.UI(row_id)(row) {
			// Fixed-width arrow column keeps labels aligned across depths.
			if clay.UI_AutoId()(
			{
				layout = {
					sizing = {clay.SizingFixed(px(cfg.indent)), clay.SizingFixed(0)},
					childAlignment = {x = .Center},
				},
			}) {
				if has_children {
					as := interact(arrow_id)
					if as.clicked {g_tree_open[open_key] = !open}
					clay.Text(open ? "v" : ">", text_style(.Body, cfg.arrow_color))
				}
			}
			text := cfg.text
			if current {text.textColor = cfg.selected_text}
			clay.Text(node.label, text)
		}

		index^ += 1
		if has_children && open {
			tree_walk(node.children, root, key, depth + 1, index, selected, cfg, changed)
		}
	}
}
