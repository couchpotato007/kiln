---
title: Snapshots and tests
description: Render the app headlessly into PNGs at phone, tablet and desktop size.
sidebar:
  order: 8
---

To see a layout at every screen size without resizing windows, render it headlessly into PNGs
(phone, tablet, desktop):

```sh
odin run example -collection:lib=. -define:KILN_SNAPSHOT=true -define:START_PAGE=2
```

The files land in `snapshots/`. No window opens.

| define | what |
| --- | --- |
| `KILN_SNAPSHOT=true` | snapshot build instead of a window |
| `KILN_SNAPSHOT_DIR=...` | where the PNGs go (default `snapshots`) |
| `KILN_SNAPSHOT_SIZES=phone,desktop` | which sizes to render (default `phone,tablet,desktop`) |

## Hooks

[`Config`](/api/app/#config) has snapshot hooks:

| field | what |
| --- | --- |
| `snapshot_setup` | loads test data after `init` (gets the model as `rawptr`) |
| `snapshot_open` | renders an extra image per dialog / drawer |
| `snapshot_pointer` | hovers a point (tooltips) |
| `snapshot_clicks` | clicks before rendering (open popups) |

Tasks run synchronously in snapshots, so the images are the same every time.

The demo exposes two of them:

```sh
odin run example -collection:lib=. -define:KILN_SNAPSHOT=true -define:START_PAGE=4 -define:SNAPSHOT_OPEN=reset
```

## Tests

Tests run headlessly too:

```sh
odin test kiln -define:KILN_SNAPSHOT=true
```
