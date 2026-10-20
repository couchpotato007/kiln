package kiln

import clay "lib:kiln/clay-odin"

// Appearance of a tab bar. Create it with `style_tabs`.
TabsConfig :: struct {
	id:               clay.ElementId, // base ID, every tab derives its own ID from it
	box:              clay.ElementDeclaration, // whole bar (tabs + bottom line)
	tab:              clay.ElementDeclaration, // padding container around one tab label
	text:             clay.TextElementConfig, // style of inactive tabs
	text_hover:       clay.Color,
	text_active:      clay.Color,
	indicator:        clay.Color, // underline of the selected tab
	indicator_height: f32, // unscaled
	line:             clay.Color, // line under the whole bar
}

// Tab bar look from the current theme: muted labels, primary-colored underline on the selected tab.
style_tabs :: proc(id: clay.ElementId) -> TabsConfig {
	c := current_theme
	return {
		id = id,
		box = {layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingGrow(), clay.SizingFit()}}},
		tab = {layout = {padding = pad_xy(.LG, .SM)}},
		text = text_style(.Body, c.text_muted),
		text_hover = c.text,
		text_active = c.primary,
		indicator = c.primary,
		indicator_height = 2,
		line = c.border,
	}
}

// Declares a tab bar. Clicking a tab stores its index in `selected`; showing the matching
// content is up to the caller (e.g. a `switch selected`). Tab IDs are derived from `cfg.id`,
// so every tab bar needs its own ID. Returns true in the frame in which the selection changed.
tabs :: proc(selected: ^int, labels: []string, cfg: TabsConfig) -> bool {
	changed := false

	if clay.UI(cfg.id)(cfg.box) {
		if clay.UI_AutoId()({layout = {childGap = sp(.XS)}}) {
			for label, i in labels {
				tab_id := clay.ID("tab", cfg.id.id * 1000 + u32(i))
				s := interact(tab_id)
				if s.clicked && selected^ != i {
					selected^ = i
					changed = true
				}

				a := anim(tab_id, 0, selected^ == i ? 1 : 0)
				h := anim(tab_id, 1, s.hovered ? 1 : 0)
				text := cfg.text
				text.textColor = color_lerp(
					color_lerp(cfg.text.textColor, cfg.text_hover, h),
					cfg.text_active,
					a,
				)

				if clay.UI(tab_id)(
				{layout = {layoutDirection = .TopToBottom, sizing = {clay.SizingFit(), clay.SizingFit()}}},
				) {
					if clay.UI_AutoId()(cfg.tab) {
						clay.Text(label, text)
					}
					// Underline fades in and out with the selection.
					if clay.UI_AutoId()(
					{
						layout = {
							sizing = {
								clay.SizingGrow(),
								clay.SizingFixed(px(cfg.indicator_height)),
							},
						},
						backgroundColor = color_lerp(
							color_alpha(cfg.indicator, 0),
							cfg.indicator,
							a,
						),
					},
					) {}
				}
			}
		}
		if clay.UI_AutoId()(
		{
			layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(px(BORDER_WIDTH))}},
			backgroundColor = cfg.line,
		},
		) {}
	}
	return changed
}
