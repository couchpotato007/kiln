package kiln

// Data table: sortable by clicking a header, selectable rows, and responsive columns. When the
// table is narrower than its columns need, columns are hidden by `priority` (highest first).

import "core:slice"
import "core:strconv"
import "core:strings"
import clay "clay-odin"

Column :: struct {
	title:     string,
	width:     f32, // fixed width in units; 0 = share the remaining width
	min_width: f32, // flexible columns: the width they need (default 120 units)
	align:     Align,
	numeric:   bool, // sort by the number at the start of the cell text
	priority:  int, // 0 = always shown; higher numbers are hidden first when space runs out
}

@(private)
TableSort :: struct {
	column:     int, // -1 = original order
	descending: bool,
}

@(private)
g_sorts: map[u32]TableSort

// A table of text cells. `rows[i][j]` is the text of row i in column j. `selected` is the index
// of the selected row in `rows` (-1 = none); clicking a row returns its index (also when the
// table is sorted):
//
//   if i, ok := kiln.table(m.selected, COLUMNS[:], rows); ok {append(out, Select{i})}
table :: proc(selected: int, columns: []Column, rows: [][]string) -> (int, bool) {
	c := &g_theme
	eid := id("table")
	result, changed := selected, false

	sort, has_sort := g_sorts[eid.id]
	if !has_sort {sort.column = -1}

	// Column widths from the width of the previous frame; hide columns until the rest fits.
	inner := element_width(eid) - 2 * line_width()
	need := make([]f32, len(columns), context.temp_allocator)
	visible := make([]bool, len(columns), context.temp_allocator)
	total: f32 = 0
	for col, i in columns {
		need[i] = px(col.width > 0 ? col.width : (col.min_width > 0 ? col.min_width : 120))
		visible[i] = true
		total += need[i]
	}
	for total > inner {
		hide_i := -1
		for col, i in columns {
			if visible[i] && col.priority > 0 && (hide_i < 0 || col.priority > columns[hide_i].priority) {
				hide_i = i
			}
		}
		if hide_i < 0 {break}
		visible[hide_i] = false
		total -= need[hide_i]
	}

	// Flexible columns share what the fixed ones leave; the last one takes the rounding rest.
	fixed: f32 = 0
	flexible, last_flexible := 0, -1
	for col, i in columns {
		if !visible[i] {continue}
		if col.width > 0 {
			fixed += need[i]
		} else {
			flexible += 1
			last_flexible = i
		}
	}
	flex_w := flexible > 0 ? max(0, (inner - fixed) / f32(flexible)) : 0
	widths := make([]clay.SizingAxis, len(columns), context.temp_allocator)
	for col, i in columns {
		switch {
		case col.width > 0:
			widths[i] = clay.SizingFixed(need[i])
		case i == last_flexible:
			widths[i] = clay.SizingGrow()
		case:
			widths[i] = clay.SizingFixed(flex_w)
		}
	}

	order := make([]int, len(rows), context.temp_allocator)
	for i in 0 ..< len(rows) {order[i] = i}
	if sort.column >= 0 && sort.column < len(columns) {
		g_sort_rows, g_sort_by = rows, sort
		g_sort_numeric = columns[sort.column].numeric
		slice.stable_sort_by(order, row_less)
	}

	r := radius(.MD)
	if clay.UI(eid)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			padding = clay.PaddingAll(u16(line_width())),
		},
		backgroundColor = c.window,
		cornerRadius = corners(.MD),
		border = outline(c.border),
		// Clipping keeps the cells (sized from the previous frame) from widening the table,
		// so it always measures the width its parent offers.
		clip = {horizontal = true},
	},
	) {
		// Header: clicking cycles ascending, descending, unsorted.
		if clay.UI()(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}},
			backgroundColor = c.surface,
			cornerRadius = {topLeft = r, topRight = r},
		},
		) {
			for col, i in columns {
				if !visible[i] {continue}
				hid := sub_id(eid, "head", i)
				s := interact(hid)
				if s.clicked {
					switch {
					case sort.column != i:
						sort = {i, false}
					case !sort.descending:
						sort.descending = true
					case:
						sort = {-1, false}
					}
					g_sorts[eid.id] = sort
				}
				title := col.title
				if sort.column == i {
					title = strings.concatenate({col.title, sort.descending ? " ▼" : " ▲"}, context.temp_allocator)
				}
				h := anim(hid, 0, s.hovered ? 1 : 0)
				if clay.UI(hid)(cell_decl(widths[i], col.align, mix(fade(c.surface_hover, 0), c.surface_hover, h))) {
					clay.TextDynamic(title, font(.Body, sort.column == i ? c.text : c.text_muted))
				}
			}
		}
		rule()

		if len(rows) == 0 {
			if clay.UI()({layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, padding = inset(.LG), childAlignment = {x = .Center}}}) {
				text("Keine Einträge", .Body, .Faint)
			}
		}

		for ri, n in order {
			row := rows[ri]
			rid := sub_id(eid, "row", ri)
			s := interact(rid)
			if s.clicked && ri != selected {
				result, changed = ri, true
			}

			bg: Color
			if n % 2 == 1 {bg = fade(c.surface, c.stripe_alpha)}
			if s.hovered {bg = c.surface_hover}
			if ri == result {bg = tone_tint(.Primary)}
			last := n == len(order) - 1

			if clay.UI(rid)(
			{
				layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}},
				backgroundColor = bg,
				cornerRadius = last ? {bottomLeft = r, bottomRight = r} : {},
			},
			) {
				for col, ci in columns {
					if !visible[ci] {continue}
					if clay.UI()(cell_decl(widths[ci], col.align, {})) {
						if ci < len(row) {
							clay.TextDynamic(row[ci], font(.Body, ri == result ? c.primary : c.text))
						}
					}
				}
			}
		}
	}
	set_last(eid)
	return result, changed
}

@(private)
cell_decl :: proc(width: clay.SizingAxis, align: Align, bg: Color) -> clay.ElementDeclaration {
	return {
		layout = {
			sizing = {width, clay.SizingFit()},
			padding = inset(.MD, .SM),
			childAlignment = {x = align_x(align)},
		},
		backgroundColor = bg,
	}
}

// Sort state for `row_less` (slice sorting takes no user data).
@(private)
g_sort_rows: [][]string
@(private)
g_sort_by: TableSort
@(private)
g_sort_numeric: bool

@(private)
row_less :: proc(a, b: int) -> bool {
	col := g_sort_by.column
	ra, rb := g_sort_rows[a], g_sort_rows[b]
	ta := col < len(ra) ? ra[col] : ""
	tb := col < len(rb) ? rb[col] : ""
	less, greater: bool
	if g_sort_numeric {
		na, nb := leading_number(ta), leading_number(tb)
		less, greater = na < nb, na > nb
	} else {
		cmp := strings.compare(strings.to_lower(ta, context.temp_allocator), strings.to_lower(tb, context.temp_allocator))
		less, greater = cmp < 0, cmp > 0
	}
	return g_sort_by.descending ? greater : less
}

// The number at the start of `s` ("12.5 %" -> 12.5, "1.200 €" -> 1.2), 0 if there is none.
@(private)
leading_number :: proc(s: string) -> f64 {
	t := strings.trim_space(s)
	end := 0
	for end < len(t) && (t[end] == '-' || t[end] == '.' || (t[end] >= '0' && t[end] <= '9')) {
		end += 1
	}
	v, _ := strconv.parse_f64(t[:end])
	return v
}
