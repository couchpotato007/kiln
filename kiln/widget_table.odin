package kiln


import clay "lib:kiln/clay-odin"

// One column of a table.
TableColumn :: struct {
	title: string,
	width: f32, // unscaled width, 0 = share the remaining space equally with other such columns
	align: clay.LayoutAlignmentX, // horizontal alignment of header and cells
}

// Declares a table of text cells (bordered, raised header, striped rows).
// `rows[i][j]` is the text in row i, column j; missing cells are empty.
// Like every value widget it takes the state pointer first: `selected` holds the index of the
// selected row (-1 = none) and is changed when a row is clicked. Pass `nil` for a read-only table.
// Returns true in the frame in which the selected row changed.
table :: proc(
	selected: ^int,
	columns: []TableColumn,
	rows: [][]string,
	id := clay.ElementId{},
) -> bool {
	c := current_theme
	eid := resolve_id(id, "table")
	changed := false
	r := radius_px(.MD)

	if clay.UI(eid)(
	{
		layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}},
		backgroundColor = c.bg,
		cornerRadius = radius(.MD),
		border = border_box(c.border),
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
				table_cell(col, col.title, text_style(.Body, c.text_muted))
			}
		}
		separator()

		for row, ri in rows {
			row_id := clay.ID("table_row", eid.id * 100000 + u32(ri))

			bg: clay.Color
			if ri % 2 == 1 {bg = color_alpha(c.surface_0, 0.5)}
			if selected != nil {
				s := interact(row_id)
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
					text := ci < len(row) ? row[ci] : ""
					table_cell(col, text, text_style(.Body, c.text))
				}
			}
		}
	}
	return changed
}

@(private = "file")
table_cell :: proc(col: TableColumn, text: string, style: clay.TextElementConfig) {
	width := col.width > 0 ? clay.SizingFixed(px(col.width)) : clay.SizingGrow()
	if clay.UI_AutoId()(
	{
		layout = {
			sizing = {width, clay.SizingFit()},
			padding = pad_xy(.MD, .SM),
			childAlignment = {x = col.align},
		},
	},
	) {
		clay.Text(text, style)
	}
}
