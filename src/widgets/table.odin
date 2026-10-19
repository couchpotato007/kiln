package widgets


import clay "lib:clay-odin"
import "lib:theme"

// One column of a table.
TableColumn :: struct {
	title: string,
	width: f32, // unscaled width, 0 = share the remaining space equally with other such columns
	align: clay.LayoutAlignmentX, // horizontal alignment of header and cells
}

// Appearance of a table. Create it with `style_table`.
TableConfig :: struct {
	id:            clay.ElementId,
	box:           clay.ElementDeclaration, // outer container (border, radius)
	header:        clay.ElementDeclaration, // header row
	row:           clay.ElementDeclaration, // data row
	cell:          clay.ElementDeclaration, // one cell (padding)
	header_text:   clay.TextElementConfig,
	cell_text:     clay.TextElementConfig,
	stripe:        clay.Color, // background of every second row
	row_hover:     clay.Color, // only used when the table is selectable
	row_selected:  clay.Color,
}

// Table look from the current theme: bordered, with a raised header and striped rows.
style_table :: proc(id: clay.ElementId) -> TableConfig {
	c := theme.current
	r := theme.px(theme.RADIUS[.MD])
	return {
		id = id,
		box = {
			layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}},
			backgroundColor = c.bg,
			cornerRadius = theme.radius(.MD),
			border = theme.border_box(c.border),
		},
		header = {
			layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}},
			backgroundColor = c.surface_0,
			cornerRadius = {topLeft = r, topRight = r},
		},
		row = {layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}}},
		cell = {
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFit()},
				padding = theme.pad_xy(.MD, .SM),
			},
		},
		header_text = theme.text_style(.Body, c.text_muted),
		cell_text = theme.text_style(.Body, c.text),
		stripe = theme.color_alpha(c.surface_0, 0.5),
		row_hover = c.surface_1,
		row_selected = c.surface_2,
	}
}

// Declares a table of text cells. `rows[i][j]` is the text in row i, column j; missing cells are empty.
// Pass a pointer as `selected` to make rows clickable: the clicked row index is stored there
// (use -1 for no selection). With `selected = nil` the table is read-only.
// Returns true in the frame in which the selected row changed.
table :: proc(
	columns: []TableColumn,
	rows: [][]string,
	cfg: TableConfig,
	selected: ^int = nil,
) -> bool {
	changed := false

	if clay.UI(cfg.id)(cfg.box) {
		if clay.UI_AutoId()(cfg.header) {
			for col in columns {
				table_cell(col, col.title, cfg.header_text, cfg)
			}
		}
		separator()

		for row, ri in rows {
			row_id := clay.ID("table_row", cfg.id.id * 100000 + u32(ri))

			decl := cfg.row
			if ri % 2 == 1 {decl.backgroundColor = cfg.stripe}
			if selected != nil {
				s := interact(row_id)
				if s.clicked && selected^ != ri {
					selected^ = ri
					changed = true
				}
				if selected^ == ri {
					decl.backgroundColor = cfg.row_selected
				} else if s.hovered {
					decl.backgroundColor = cfg.row_hover
				}
			}

			if clay.UI(row_id)(decl) {
				for col, ci in columns {
					text := ci < len(row) ? row[ci] : ""
					table_cell(col, text, cfg.cell_text, cfg)
				}
			}
		}
	}
	return changed
}

@(private = "file")
table_cell :: proc(col: TableColumn, text: string, style: clay.TextElementConfig, cfg: TableConfig) {
	decl := cfg.cell
	decl.layout.sizing.width = col.width > 0 ? clay.SizingFixed(theme.px(col.width)) : clay.SizingGrow()
	decl.layout.childAlignment.x = col.align
	if clay.UI_AutoId()(decl) {
		clay.Text(text, style)
	}
}
