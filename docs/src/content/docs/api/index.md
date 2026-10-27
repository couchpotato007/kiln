---
title: API overview
description: Every exported proc, type and constant of kiln, generated from the source.
sidebar:
  label: Overview
  order: 1
---

Every page in this section except this one is generated from the doc comments in `kiln/`. Each
page starts with **At a glance**, all signatures in one block, so you can look up which arguments
a proc takes without scrolling. Below that every entry has its full signature, the doc comment,
and a table with the type and default of every argument.

| page | what |
| --- | --- |
| [App](/api/app/) | `run`, `App`, `Config`, `embed`, tasks, keys, clipboard |
| [Layout](/api/layout/) | `column`, `row`, `card`, `grid`, `adaptive`, `flow`, `field`, `actions`, `scroll`, ... |
| [Controls](/api/controls/) | `button`, `checkbox`, `toggle`, `radio`, `slider`, `text_field` |
| [Choices](/api/choices/) | `tabs`, `segmented`, `nav`, `select` |
| [Display](/api/display/) | `text`, `badge`, `avatar`, `progress`, `stat`, `callout`, `chip`, `chips`, ... |
| [Charts](/api/charts/) | `bar_chart`, `timeline`, `legend`, `swatch` |
| [Tables and trees](/api/data/) | `table`, `tree` |
| [Dates](/api/dates/) | `Date`, `date_field`, `calendar`, date math |
| [Overlays](/api/overlays/) | `dialog`, `drawer`, `toast`, `menu`, `context_menu`, `tooltip` |
| [Icons](/api/icons/) | `Icon`, `icon`, `load_icon`, the built-in `ICON_*` |
| [Theme and units](/api/theme/) | `Theme`, `Colors`, `Metrics`, `catppuccin`, the named steps, `px`, `space`, ... |
| [State and ids](/api/state/) | `id`, `scope`, `interact`, `pointer_events`, `widget_state`, `clicked`, `anim`, `show` / `hide`, timers |
| [Drawing](/api/draw/) | `drawing`, `draw`, paths, `fill_path`, `stroke_path`, `draw_image`, `draw_text`, `transform`, `clip`, `opacity`, `render_image` |

## Reading a signature

```odin
slider :: proc(
	value: $T,
	lo, hi: T,
	disabled := false,
	key := "",
) -> (new_value: T, changed: bool) where intrinsics.type_is_integer(T) || intrinsics.type_is_float(T)
```

- `$T` is a generic: here any integer or float, `lo` and `hi` have to be the same type.
- `name := value` is an optional argument with a default, pass it by name:
  `kiln.slider(m.v, 0, 10, key = "volume")`.
- Procedure groups like `button :: proc{button_label, button_icon}` pick the right proc by the
  argument types. Their page lists all members.

## Regenerating

The pages are made by `tools/docgen`, a small Odin program that reads the `.odin-doc` file the
compiler writes:

```sh
cd docs
pnpm api     # odin doc + odin run tools/docgen
pnpm dev     # runs `pnpm api` first, then the dev server
```

:::caution
Do not edit the generated pages, they are overwritten every time. Fix the doc comment in
`kiln/` instead. Private things (`@(private)`) and tests are left out.
:::
