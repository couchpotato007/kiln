package kiln

// Charts: a bar chart, a timeline of time ranges, and the categorical palette with a legend.
//
// Bars share the width; the labels below thin out when the chart gets too narrow for all of
// them. Hovering a bar or segment shows its label and value, clicking returns its index.

import "core:fmt"
import "core:math"
import clay "clay-odin"

// ---------------------------------------------------------------------------
// Palette and legend
// ---------------------------------------------------------------------------

// The i-th categorical chart color of the theme (`Colors.chart`); indices outside 0..7 give a
// neutral gray, e.g. for "other".
chart_color :: proc(i: int) -> Color {
	if i < 0 || i >= len(g_theme.chart) {return g_theme.text_faint}
	return g_theme.chart[i]
}

// A small colored square, e.g. in front of a category name.
swatch :: proc(color: Color, size := Size.Dot) {
	eid := id("swatch")
	d := px(g_theme.sizes[size])
	flow_item(eid)
	if clay.UI(eid)(
	{
		layout = {sizing = {clay.SizingFixed(d), clay.SizingFixed(d)}},
		backgroundColor = color,
		cornerRadius = clay.CornerRadiusAll(min(radius(.SM), d / 4)),
	},
	) {}
	set_last(eid)
}

Legend_Item :: struct {
	label: string,
	color: Color,
}

// Swatches with labels that wrap into several lines when there is not enough room.
legend :: proc(items: []Legend_Item) {
	if flow(.MD, .XS) {
		for item in items {
			if row(.XS, fill = .None) {
				swatch(item.color)
				text(item.label, .Caption, .Muted)
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Bar chart
// ---------------------------------------------------------------------------

// `labels[i]` belongs to `values[i]`; values are drawn relative to the largest one. `height` is
// in units. `format` writes a value for the tooltip and the axis (default `%v`). The bar at
// `highlight` (e.g. today) is drawn in `highlight_tone`; `colors` gives every bar its own color
// and wins over both. `value_axis` adds three gridlines with values on the left.
//
//   if i, ok := kiln.bar_chart(m.minutes, DAYS[:], format = format_minutes, highlight = today); ok {
//       append(out, Select_Day{i})
//   }
//
// Returns the index of the clicked bar. `clicked`, `tooltip`, ... after the chart refer to the
// whole chart.
bar_chart :: proc(
	values: []f32,
	labels: []string = nil,
	height: f32 = 160,
	tone := Tone.Primary,
	format: proc(v: f32) -> string = nil,
	highlight := -1,
	highlight_tone := Tone.Info,
	colors: []Color = nil,
	value_axis := false,
) -> (
	clicked: int,
	ok: bool,
) {
	c := &g_theme
	eid := id("bar_chart")
	bars := sub_id(eid, "bars")
	n := len(values)
	clicked = -1
	if n == 0 {return}

	top: f32 = 0
	for v in values {top = max(top, v)}
	if top <= 0 {top = 1}
	write :: proc(format: proc(v: f32) -> string, v: f32) -> string {
		return format != nil ? format(v) : fmt.tprint(v)
	}

	// Pointer states first, so the other bars can fade while one is hovered.
	states := make([]Interaction, n, context.temp_allocator)
	hovered := -1
	for i in 0 ..< n {
		states[i] = interact(sub_id(eid, "bar", i))
		if states[i].hovered {hovered = i}
		if states[i].clicked {clicked = i}
	}

	// The value axis: labels for 1/3, 2/3 and 3/3 of the largest value.
	axis_w: f32 = 0
	axis_gap := f32(space(.SM))
	if value_axis {
		for k in 1 ..= 3 {axis_w = max(axis_w, measure(write(format, top * f32(k) / 3), .Caption))}
	}

	// Show every k-th label so that neighbouring labels do not touch.
	every := 1
	if len(labels) > 0 {
		widest: f32 = 0
		for l in labels {widest = max(widest, measure(l, .Caption))}
		slot := element_width(bars) / f32(n)
		every = max(1, int(math.ceil((widest + f32(space(.SM))) / max(slot, 1))))
	}

	share := 1 / f32(n)
	gap := space(.XS)
	accent := tone_color(tone)
	chart_h := px(height)
	left := u16(value_axis ? axis_w + axis_gap : 0)

	if clay.UI(eid)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			childGap = space(.XS),
		},
	},
	) {
		axis: clay.CustomElementConfig
		// Room above the bars for the top value, which is centered on the top gridline.
		above := value_axis ? u16(math.ceil(f32(font_size(.Caption)) / 2)) : 0
		if value_axis {axis = draw(bar_axis(bars, chart_h, axis_w, f32(left), f32(above), top, format))}
		if clay.UI()({layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, padding = {left = left, top = above}}, custom = axis}) {
			if clay.UI(bars)(
			{
				layout = {
					sizing = {clay.SizingGrow(), clay.SizingFixed(chart_h)},
					childGap = gap,
					childAlignment = {y = .Bottom},
				},
			},
			) {
				for v, i in values {
					bid := sub_id(eid, "bar", i)
					s := states[i]
					h := anim(bid, 0, s.hovered ? 1 : 0)
					dim := anim(bid, 2, hovered >= 0 && hovered != i ? 1 : 0)
					grow := anim(bid, 1, max(v, 0) / top, from = 0, speed = 8)

					col := accent
					if i == highlight {col = tone_color(highlight_tone)}
					if i < len(colors) {col = colors[i]}
					col = fade(mix(col, c.text, 0.25 * h), col.a / 255 * (1 - 0.45 * dim))

					if clay.UI(bid)(
					{
						layout = {sizing = {clay.SizingPercent(share), clay.SizingGrow()}, childAlignment = {y = .Bottom}},
					},
					) {
						if clay.UI()(
						{
							layout = {sizing = {clay.SizingGrow(), clay.SizingPercent(grow)}},
							backgroundColor = col,
							cornerRadius = {topLeft = radius(.SM), topRight = radius(.SM)},
						},
						) {}
					}
					label := i < len(labels) ? labels[i] : ""
					tooltip_on(bid, fmt.tprintf("%s%s%s", label, len(label) > 0 ? ": " : "", write(format, v)), .Top)
				}
			}
		}
		if clay.UI()({layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, padding = {left = left}}}) {rule()}
		if len(labels) > 0 {
			if clay.UI()({layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, padding = {left = left}, childGap = gap}}) {
				for i in 0 ..< n {
					if clay.UI()(
					{
						layout = {
							sizing = {clay.SizingPercent(share), clay.SizingFit()},
							childAlignment = {x = .Center},
						},
					},
					) {
						if i % every == 0 && i < len(labels) {
							style := font(.Caption, i == highlight ? tone_color(highlight_tone) : c.text_muted)
							style.wrapMode = .None
							clay.TextDynamic(labels[i], style)
						}
					}
				}
			}
		}
	}
	set_last(eid)
	return clicked, clicked >= 0
}

// Gridlines behind the bars and their values left of them, drawn on the element around the bars
// (`bars` plus `left` pixels of room for the values and `above` pixels for the top one).
@(private)
bar_axis :: proc(bars: Id, chart_h, axis_w, left, above, top: f32, format: proc(v: f32) -> string) -> ^Drawing {
	c := &g_theme
	w := clay.GetElementData(bars).boundingBox.width
	lw := line_width()
	label_h := f32(font_size(.Caption))
	d := drawing()
	for k in 1 ..= 3 {
		y := above + chart_h * (1 - f32(k) / 3)
		move_to(d, {left, y + lw / 2})
		line_to(d, {left + w, y + lw / 2})
		stroke_path(d, fade(c.border, 0.7), lw, .Butt)
		label := format != nil ? format(top * f32(k) / 3) : fmt.tprint(top * f32(k) / 3)
		draw_text(d, label, {axis_w - measure(label, .Caption), y - label_h / 2}, .Caption, c.text_faint)
	}
	return d
}


// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

// A colored range in a timeline row, e.g. the time an app was in use.
Timeline_Segment :: struct {
	start, end: f64, // in the row's units (ms, minutes, ...)
	color:      Color,
	tooltip:    string,
}

// One row of a timeline: a label and segments over the range `start` .. `end`.
Timeline_Row :: struct {
	label:      string,
	start, end: f64,
	segments:   []Timeline_Segment,
}

// Rows of colored segments over a common range, e.g. the use of apps over a day. Segments may
// overlap (several devices at once). `ticks` are labels spread evenly below the rows
// (`{"0", "6", "12", "18", "24"}`), `row_height` and `label_width` are in units.
//
//   if r, s, ok := kiln.timeline(rows, HOURS[:]); ok {append(out, Show_Details{r, s})}
//
// Returns the clicked row and segment; the segment is -1 when the row label was clicked.
timeline :: proc(
	rows: []Timeline_Row,
	ticks: []string = nil,
	row_height: f32 = 18,
	label_width: f32 = 96,
) -> (
	row, segment: int,
	ok: bool,
) {
	c := &g_theme
	eid := id("timeline")
	row, segment = -1, -1
	rh := px(row_height)
	lw := px(label_width)
	gap := space(.SM)

	if clay.UI(eid)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			childGap = space(.XS),
		},
	},
	) {
		for r, ri in rows {
			rid := sub_id(eid, "row", ri)
			lid := sub_id(rid, "label")
			track := sub_id(rid, "track")
			ls := interact(lid)
			if ls.clicked {row, segment = ri, -1}

			if clay.UI(rid)({layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, childGap = gap, childAlignment = {y = .Center}}}) {
				style := font(.Caption, ls.hovered ? c.text : c.text_muted)
				style.wrapMode = .None
				if clay.UI(lid)(
				{
					layout = {sizing = {clay.SizingFixed(lw), clay.SizingFixed(rh)}, childAlignment = {y = .Center}},
					clip = {horizontal = true},
				},
				) {
					clay.TextDynamic(r.label, style)
				}

				// Segments float at their position in the track's width of the previous frame, so
				// they may overlap. Before the track was laid out once, nothing is drawn.
				td := clay.GetElementData(track)
				w := f64(td.boundingBox.width)
				span := r.end - r.start
				if clay.UI(track)(
				{
					layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(rh)}},
					backgroundColor = c.sunken,
					cornerRadius = corners(.SM),
					clip = {horizontal = true},
				},
				) {
					if td.found && span > 0 {
						for seg, si in r.segments {
							x0 := (seg.start - r.start) / span * w
							x1 := (seg.end - r.start) / span * w
							if x1 < 0 || x0 > w {continue}
							sid := sub_id(rid, "seg", si)
							s := interact(sid)
							if s.clicked {row, segment = ri, si}
							if clay.UI(sid)(
							{
								layout = {sizing = {clay.SizingFixed(max(1, f32(x1 - x0))), clay.SizingFixed(rh)}},
								backgroundColor = s.hovered ? mix(seg.color, c.text, 0.35) : seg.color,
								floating = {
									attachTo = .Parent,
									attachment = {element = .LeftTop, parent = .LeftTop},
									offset = {f32(x0), 0},
									zIndex = g_z + 1,
									clipTo = .AttachedParent,
								},
							},
							) {}
							tooltip_on(sid, seg.tooltip)
						}
					}
				}
			}
		}

		if len(ticks) > 0 {
			area := sub_id(eid, "ticks")
			w := clay.GetElementData(area).boundingBox.width
			style := font(.Caption, c.text_faint)
			style.wrapMode = .None
			if clay.UI()({layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, padding = {left = u16(lw) + gap}}}) {
				if clay.UI(area)({layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(f32(font_size(.Caption)) * 1.3)}}}) {
					n := len(ticks)
					for t, i in ticks {
						x := n > 1 ? w * f32(i) / f32(n - 1) : 0
						at := clay.FloatingAttachPointType.CenterTop
						if i == 0 {at = .LeftTop}
						if i == n - 1 && n > 1 {at = .RightTop}
						if clay.UI()(
						{
							floating = {
								attachTo = .Parent,
								attachment = {element = at, parent = .LeftTop},
								offset = {x, 0},
								zIndex = g_z + 1,
								pointerCaptureMode = .Passthrough,
							},
						},
						) {
							clay.TextDynamic(t, style)
						}
					}
				}
			}
		}
	}
	set_last(eid)
	return row, segment, row >= 0
}
