---
title: The app loop
description: Model, messages, update, view. Plus embed, tasks and timers.
sidebar:
  order: 2
---

The app loop is The Elm Architecture: the app owns a `Model`, the view only reads it and emits
messages, `update` is the only place that changes it.

```odin
kiln.run(kiln.App(Model, Msg){init = init, update = update, view = view}, {title = "Meine App"})
```

| proc     | signature                                    | what                                 |
| -------- | -------------------------------------------- | ------------------------------------ |
| `init`   | `proc() -> Model`                            | the first model                      |
| `update` | `proc(m: ^Model, msg: Msg)`                  | the only place the model changes     |
| `view`   | `proc(m: ^Model, out: ^[dynamic]Msg)`        | draws, appends messages to `out`     |
| `tick`   | `proc(m: ^Model, dt: f32)`                   | optional, once per frame before view |

The second argument of `run` is a [`Config`](/api/app/#config): title, window size, theme, scale.
Zero values select the defaults.

## Splitting an app into modules

Each page of the example is its own package with its own `Model`, `Msg`, `update` and `view`.
The parent has a variant of its `Msg` union for each child's `Msg` and forwards them:

```odin
Msg :: union {
	Go_To,
	tasks.Msg,
	people.Msg,
}

update :: proc(m: ^Model, msg: Msg) {
	switch v in msg {
	case Go_To:
		m.page = v.page
	case tasks.Msg:
		tasks.update(&m.tasks, v)
	case people.Msg:
		people.update(&m.people, v)
	}
}

view :: proc(m: ^Model, out: ^[dynamic]Msg) {
	switch m.page {
	case .Tasks:
		kiln.embed(out, &m.tasks, tasks.view)
	case .People:
		kiln.embed(out, &m.people, people.view)
	}
}
```

[`embed`](/api/app/#embed) runs the child view and converts its messages into the parent's
message type.

## Tasks

Work that would block the frame (network, disk) goes to [`task`](/api/app/#task). It runs on a
worker thread and comes back as a message, which goes through `update` like one from the view:

```odin
kiln.task(proc(url: string) -> Msg {
	body, err := http_get(url)
	return Loaded{body, err}
}, strings.clone(url))
```

- `work` must not touch the model or kiln's UI state, only `data`.
- It runs with the allocator of the caller of `task`, so `update` can free what it allocated.
- The message type can be a variant of the app's `Msg` at any depth, so modules can start their
  own tasks.
- [`tasks_running()`](/api/app/#tasks_running) counts the ones still out, e.g. for a spinner.
- In snapshot builds tasks run synchronously, so snapshots are deterministic.

## Timers

Timers are for the view and keyed by name, like dialogs:

```odin
if kiln.every("refresh", 300) {append(out, Refresh{})}   // every 5 minutes
if kiln.after("hint", 3) {append(out, Hide_Hint{})}      // once, after 3 seconds
```

They only run while they are called in every frame. [`reset_timer`](/api/state/#reset_timer)
starts one over.

## Other things

| proc                                          | what                                          |
| --------------------------------------------- | --------------------------------------------- |
| [`toast(msg, tone)`](/api/overlays/#toast)    | short message, also callable from `update`    |
| [`key_pressed(key)`](/api/app/#key_pressed)   | a key in this frame, unless a text field has focus |
| [`copy_to_clipboard(s)`](/api/app/#copy_to_clipboard), [`clipboard()`](/api/app/#clipboard) | the system clipboard |
| [`now()`](/api/app/#now), [`frame_time()`](/api/app/#frame_time) | time since start, last frame duration |
| [`quit()`](/api/app/#quit)                    | closes the window at the end of the frame     |
