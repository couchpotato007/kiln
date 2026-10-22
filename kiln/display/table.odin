package display

import clay "lib:kiln/clay-odin"
import fd "lib:kiln/foundation"
import th "lib:kiln/theme"
import "lib:kiln/layout"

// One column of a table.
TableColumn :: struct {
	title: string,
	width: f32, // unscaled width, 0 = share the remaining space equally with other such columns
	align: clay.LayoutAlignmentX, // horizontal alignment of header and cells
}

// Declares a table of text cells (bordered, raised header, striped rows).
// `rows[i][j]` is the text in row i, column j; missing cells are empty.
// `selected` holds the index of the selected row (-1 = none) and is changed when a row is
// clicked; pass `nil` for a read-only table. Returns true in the frame in which it changed.
table :: proc(
	selected: ^int,
	columns: []TableColumn,
	rows: [][]string,
	id := clay.ElementId{},
) -> bool {
	c := th.current()
	eid := fd.resolve_id(id, "table")
	changed := false
	r := th.radius_px(.MD)

	if clay.UI(eid)(
	{
		layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}},
		backgroundColor = c.bg,
		cornerRadius = th.radius(.MD),
		border = th.border_box(c.border),
	},
	) {
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}},
			backgroundColor = c.surface_0,
			cornerRadius = {topLeft = r, topRight = r},
		},
		) {
			for col in columns {
				cell(col, col.title, th.text_style(.Body, c.text_muted))
			}
		}
		layout.separator()

		for row, ri in rows {
			row_id := fd.child_id(eid, "row", ri)

			bg: clay.Color
			if ri % 2 == 1 {bg = th.color_alpha(c.surface_0, c.stripe_alpha)}
			if selected != nil {
				s := fd.interact(row_id)
				if s.clicked && selected^ != ri {
					selected^ = ri
					changed = true
				}
				if selected^ == ri {
					bg = c.surface_2
				} else if s.hovered {
					bg = c.surface_1
				}
			}

			if clay.UI(row_id)(
			{layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}}, backgroundColor = bg},
			) {
				for col, ci in columns {
					cell(col, ci < len(row) ? row[ci] : "", th.text_style(.Body, c.text))
				}
			}
		}
	}
	return changed
}

@(private)
cell :: proc(col: TableColumn, text: string, style: clay.TextElementConfig) {
	width := col.width > 0 ? clay.SizingFixed(th.px(col.width)) : clay.SizingGrow()
	if clay.UI_AutoId()(
	{
		layout = {
			sizing = {width, clay.SizingFit()},
			padding = th.pad_xy(.MD, .SM),
			childAlignment = {x = col.align},
		},
	},
	) {
		clay.Text(text, style)
	}
}
