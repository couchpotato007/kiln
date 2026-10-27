---
title: Problems
description: There will be problems.
---

There will be problems becaues the hole code was written with claude free.

If you find problems clone the repo and fix it. Or dont.

## Problems I know about

Not a complete list. A complete list would be longer.

- **The API changes.** Whenever I need something different I change it. There are no versions
  and no changelog. Pin a commit.
- **Clay cannot wrap.** `flow` builds its lines from the widths of the children in the
  previous frame, so in the very first frame everything is in one line. Same for `grid`,
  `adaptive` and everything else that looks at `element_width`. One frame later it is fine.
- **Glyphs are baked on demand.** A character the font has never shown before appears one frame
  after it is first measured.
- **Fonts.** TrueType and OpenType work. Font collections (`.ttc`) and color emoji fonts do not.
- **SVG.** kiln rasterizes SVGs itself. Gradients (drawn in the text color), `<use>`, masks,
  clip paths, text and CSS classes are not supported.
- **Ids from labels.** Two text fields with the same placeholder share cursor and focus unless
  you give them a `key`. Lists that change need `kiln.scope(item.id)`, otherwise hover and open
  state stick to the position, not the item. See [the rules](/guides/rules/#5-identity-is-automatic).
- **Strings from widgets** live until the end of the frame. Clone them in `update` or they are
  gone.
- **Made on Linux.** clay is shipped for Windows and macOS too. No idea if it works there.
- **Everything in the examples is German.** "Speichern", "Strg+S", `locale_de`. The library
  itself defaults to `locale_en`.

## Reporting them

You can open an issue on [GitHub](https://github.com/couchpotato007/kiln/issues). I might read
it. A pull request with the fix is better.
