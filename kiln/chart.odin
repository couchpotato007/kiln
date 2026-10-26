package kiln

// A simple bar chart. Bars share the width; the labels below thin out when the chart gets too
// narrow for all of them. Hovering a bar shows its label and value.

import "core:fmt"
import "core:math"
import clay "clay-odin"

// `labels[i]` belongs to `values[i]`; values are drawn relative to the largest one.
// `height` is in units.
bar_chart :: proc(values: []f32, labels: []string = nil, height: f32 = 160, tone := Tone.Primary) {
	c := &g_theme
	eid := id("bar_chart")
	n := len(values)
	if n == 0 {return}

	top: f32 = 0
	for v in values {top = max(top, v)}
	if top <= 0 {top = 1}

	// Show every k-th label so that neighbouring labels do not touch.
	k := 1
	if len(labels) > 0 {
		widest: f32 = 0
		for l in labels {widest = max(widest, measure(l, .Caption))}
		slot := last_width(eid) / f32(n)
		k = max(1, int(math.ceil((widest + f32(space(.SM))) / max(slot, 1))))
	}

	share := 1 / f32(n)
	gap := space(.XS)
	accent := tone_color(tone)

	if clay.UI(eid)(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {clay.SizingGrow(), clay.SizingFit()},
			childGap = space(.XS),
		},
	},
	) {
		if clay.UI()(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFixed(px(height))},
				childGap = gap,
				childAlignment = {y = .Bottom},
			},
		},
		) {
			for v, i in values {
				bid := sub_id(eid, "bar", i)
				s := interact(bid)
				h := anim(bid, 0, s.hovered ? 1 : 0)
				grow := anim(bid, 1, max(v, 0) / top, from = 0, speed = 8)
				if clay.UI(bid)(
				{
					layout = {sizing = {clay.SizingPercent(share), clay.SizingGrow()}, childAlignment = {y = .Bottom}},
				},
				) {
					if clay.UI()(
					{
						layout = {sizing = {clay.SizingGrow(), clay.SizingPercent(grow)}},
						backgroundColor = mix(accent, c.text, 0.25 * h),
						cornerRadius = {topLeft = radius(.SM), topRight = radius(.SM)},
					},
					) {}
				}
				label := i < len(labels) ? labels[i] : ""
				tooltip_on(bid, fmt.tprintf("%s%s%v", label, len(label) > 0 ? ": " : "", v), .Top)
			}
		}
		rule()
		if len(labels) > 0 {
			if clay.UI()({layout = {sizing = {clay.SizingGrow(), clay.SizingFit()}, childGap = gap}}) {
				for i in 0 ..< n {
					if clay.UI()(
					{
						layout = {
							sizing = {clay.SizingPercent(share), clay.SizingFit()},
							childAlignment = {x = .Center},
						},
					},
					) {
						if i % k == 0 && i < len(labels) {
							style := font(.Caption, c.text_muted)
							style.wrapMode = .None
							clay.TextDynamic(labels[i], style)
						}
					}
				}
			}
		}
	}
	set_last(eid)
}
