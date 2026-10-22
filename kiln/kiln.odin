package kiln

// kiln: a small immediate-mode UI library on top of Clay and raylib.
//
// This package is only the public API. It re-exports what applications need from the
// sub-packages, so apps import nothing but `lib:kiln`:
//
//   foundation/  element ids, mouse interaction, tweening, popup state
//   theme/       colors, metrics, scale, Catppuccin presets
//   render/      raylib renderer, fonts, text measurement
//   layout/      stacks, card, scroll view, separator, accordion
//   display/     label, badge, progress, spinner, image, table, tree
//   controls/    button, checkbox, radio, slider, segmented, tabs, select, text field
//   overlay/     tooltip, menu, context menu, modal
//   app/         the app loop (`run`)
//
// Conventions shared by all widgets:
//  - Value widgets take a pointer to the value first, then their data, and return true in the
//    frame in which the value changed. Buttons return true when clicked.
//  - Menus return `(index, ok)`.
//  - `disabled` (where it makes sense) and `id` come last; `id` is only needed for widgets
//    that are declared several times in the same parent (`id = kiln.id_local("x", u32(i))`).
//  - Colors, spacing, radii and sizes are never passed as numbers: widgets take named steps
//    (`.SM`, `.MD`, ...) and the theme decides what they are.

import "lib:kiln/app"
import "lib:kiln/controls"
import "lib:kiln/display"
import fd "lib:kiln/foundation"
import "lib:kiln/layout"
import "lib:kiln/overlay"
import th "lib:kiln/theme"

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

App :: app.App
Config :: app.Config
run :: app.run
quit :: app.quit
dt :: app.dt
embed :: app.embed

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

Theme :: th.Theme
Colors :: th.Colors
Metrics :: th.Metrics
Scale :: th.Scale
Space :: th.Space
Radius :: th.Radius
Size :: th.Size
FontRole :: th.FontRole
FontFace :: th.FontFace
Surface :: th.Surface
Flavor :: th.Flavor

// The active theme (a copy). Use it to read colors: `kiln.theme().text_muted`.
theme :: th.current
set_theme :: th.set_theme
set_colors :: th.set_colors
set_metrics :: th.set_metrics
default_metrics :: th.default_metrics
catppuccin :: th.catppuccin
catppuccin_colors :: th.catppuccin_colors

set_scale :: th.set_scale
set_zoom :: th.set_zoom
zoom :: th.zoom

color_mix :: th.color_mix
color_alpha :: th.color_alpha
surface_color :: th.surface_color

// Theme values as scaled pixels, for custom widgets built directly on Clay.
px :: th.px
sp :: th.sp
space_px :: th.space_px
pad_all :: th.pad_all
pad_xy :: th.pad_xy
radius :: th.radius
radius_px :: th.radius_px
size_px :: th.size_px
control_height :: th.control_height
border_px :: th.border_px
border_box :: th.border_box
font_size :: th.font_size
text_style :: th.text_style

// ---------------------------------------------------------------------------
// Ids and widget building blocks (for custom widgets)
// ---------------------------------------------------------------------------

id :: fd.id
id_local :: fd.id_local

Interaction :: fd.Interaction
interact :: fd.interact
anim :: fd.anim

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

Fill :: layout.Fill
vstack :: layout.vstack
hstack :: layout.hstack
center :: layout.center
spacer :: layout.spacer
card :: layout.card
scroll_view :: layout.scroll_view
scroll_clip :: layout.scroll_clip
separator :: layout.separator
accordion :: layout.accordion

// ---------------------------------------------------------------------------
// Display
// ---------------------------------------------------------------------------

label :: display.label
BadgeVariant :: display.BadgeVariant
badge :: display.badge
progress :: display.progress
spinner :: display.spinner
image :: display.image
TableColumn :: display.TableColumn
table :: display.table
TreeNode :: display.TreeNode
tree :: display.tree
tree_find :: display.tree_find

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

ButtonVariant :: controls.ButtonVariant
button :: controls.button
checkbox :: controls.checkbox
radio :: controls.radio
slider :: controls.slider
segmented :: controls.segmented
tabs :: controls.tabs
Select :: controls.Select
select :: controls.select
TextField :: controls.TextField
TextFieldResult :: controls.TextFieldResult
text_field :: controls.text_field
text_field_set :: controls.text_field_set
text_field_string :: controls.text_field_string
text_field_destroy :: controls.text_field_destroy

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

MenuItem :: overlay.MenuItem
menu :: overlay.menu
context_menu :: overlay.context_menu
tooltip :: overlay.tooltip
modal :: overlay.modal
