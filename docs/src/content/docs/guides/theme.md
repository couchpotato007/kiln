---
title: Theme and fonts
description: Colors, metrics, Catppuccin, zoom and fonts.
sidebar:
  order: 5
---

Widgets have no values of their own. They only reference the named steps of the theme, so
changing a value changes every widget.

A [`Theme`](/api/theme/#theme) is [`Colors`](/api/theme/#colors) plus
[`Metrics`](/api/theme/#metrics), and fields of both can be accessed directly:

```odin
t := kiln.catppuccin(.Mocha)
t.radii[.MD] = 2
t.sizes[.Control] = 40
t.locale = kiln.locale_de()
kiln.set_theme(t)
```

Or pass it to `run`:

```odin
kiln.run(app, {title = "Meine App", theme = t})
```

| proc | what |
| --- | --- |
| [`catppuccin(flavor)`](/api/theme/#catppuccin) | complete theme: `.Mocha`, `.Macchiato`, `.Frappe` (dark), `.Latte` (light) |
| [`catppuccin_colors(flavor)`](/api/theme/#catppuccin_colors) | only the colors |
| [`default_metrics()`](/api/theme/#default_metrics) | 4px based spacing, 36px controls, 16px body text, Iosevka |
| [`theme()`](/api/theme/#theme-1) | a copy of the active theme |
| [`set_theme`](/api/theme/#set_theme), [`set_colors`](/api/theme/#set_colors), [`set_metrics`](/api/theme/#set_metrics) | replace all, only colors, only metrics |

The default is Catppuccin Mocha.

## The named steps

| step | values |
| --- | --- |
| [`Space`](/api/theme/#space) | `.None`, `.XS`, `.SM`, `.MD`, `.LG`, `.XL` (0, 4, 8, 12, 16, 24) |
| [`Radius`](/api/theme/#radius) | `.None`, `.SM`, `.MD`, `.LG`, `.Full` |
| [`Size`](/api/theme/#size) | `.Track`, `.Bar`, `.Dot`, `.Mark`, `.Control`, `.Avatar`, `.Drawer`, `.Dialog`, `.Menu`, `.Toast` |
| [`TextStyle`](/api/theme/#textstyle) | `.Caption`, `.Body`, `.Subtitle`, `.Title`, `.Headline` |
| [`Tone`](/api/theme/#tone) | `.Default`, `.Muted`, `.Faint`, `.Primary`, `.Info`, `.Success`, `.Warning`, `.Danger` |
| [`Surface`](/api/theme/#surface) | `.None`, `.Window`, `.Sunken`, `.Raised` |

Font sizes are `font_base * font_ratio^(style - Body)`, so `font_base = 16, font_ratio = 1.25`
gives 12.8, 16, 20, 25 and 31.25.

## Units and zoom

Everything in the theme is in units. The UI scale (monitor DPI times zoom) turns units into
pixels. [`Scale`](/api/theme/#scale) in the `Config` sets the zoom, can scale with the window
height (`fit_height`) or ignore the DPI. `Ctrl +/−/0` changes the zoom unless `no_zoom_keys` is
set.

## Fonts

kiln compiles subsets of Iosevka (`resources/kiln-regular.ttf`, `resources/kiln-bold.ttf`, about
80 KB each) into the binary, so apps start from any directory. `-define:KILN_EMBED_FONTS=false`
loads `font_files` at runtime instead. `font_data` in the theme takes any font file in memory.

Any character a font has can be shown: glyphs are baked on demand the first time a character is
measured (one frame later it is there). Characters the font lacks come from `font_fallbacks`, a
list of fonts in memory that are tried in order, e.g. a full font, a CJK font or a symbol font:

```odin
theme := kiln.catppuccin(.Mocha)
cjk, _ := os.read_entire_file("fonts/NotoSansSC-Regular.otf", context.allocator)
fallbacks := [?][]u8{#load("fonts/Iosevka-Regular.ttf"), cjk}
theme.font_fallbacks = fallbacks[:] // must stay alive while the app runs
```

:::caution
TrueType and OpenType files work. Font collections (`.ttc`) and color emoji fonts do not.
:::

To make a subset of another font:

```sh
odin run tools/subset_font -- resources/Iosevka-Regular.ttf resources/kiln-regular.ttf
odin run tools/subset_font -- resources/Iosevka-SemiBold.ttf resources/kiln-bold.ttf
```

or with fonttools:

```sh
pyftsubset Iosevka-Regular.ttf --unicodes=U+20-7E,U+A0-17F,U+2010-205E,U+20AC,U+2190-21FF,U+2212,U+22EF,U+2302,U+25A0-25FF,U+2600-2609,U+2630,U+2699,U+2713-2718 --output-file=kiln-regular.ttf
```
