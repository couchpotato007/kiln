package kiln

// Background tasks: work that would block the frame (network, disk) runs on a worker thread and
// comes back as a message, which goes through `update` like one from the view:
//
//   kiln.task(proc(url: string) -> Msg {
//       body, err := http_get(url)
//       return Loaded{body, err}
//   }, strings.clone(url))
//
// `work` runs on its own thread: it must not touch the model or kiln's UI state, only `data`.
// It runs with the allocator of the caller of `task`, so `update` can free what it allocated.
// The result arrives at the start of a later frame. In snapshot builds tasks run synchronously,
// so snapshots are deterministic.

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:sync"
import "core:thread"

@(private)
TaskResult :: struct {
	msg:       rawptr,
	type:      typeid,
	allocator: runtime.Allocator, // the one `msg` was allocated with
}

@(private)
g_task_mutex: sync.Mutex
@(private)
g_task_done: [dynamic]TaskResult // finished, not yet delivered
@(private)
g_tasks_running: int // started and not yet delivered

// Starts `work(data)` on a worker thread. `M` is the app's message type or a variant of it, at
// any depth (the message type of an embedded module, or one of its variants), so modules can
// start their own tasks.
task :: proc(work: proc(data: $D) -> $M, data: D) {
	Job :: struct {
		work:      proc(data: D) -> M,
		data:      D,
		allocator: runtime.Allocator,
	}
	run :: proc(job: ^Job) {
		context.allocator = job.allocator
		result := new_clone(job.work(job.data))
		sync.mutex_lock(&g_task_mutex)
		if g_task_done.allocator.procedure == nil {g_task_done.allocator = runtime.heap_allocator()}
		append(&g_task_done, TaskResult{result, typeid_of(M), job.allocator})
		sync.mutex_unlock(&g_task_mutex)
		free(job)
	}

	sync.atomic_add(&g_tasks_running, 1)
	job := new_clone(Job{work, data, context.allocator})
	when KILN_SNAPSHOT {
		run(job)
	} else {
		thread.create_and_start_with_poly_data(job, run, self_cleanup = true)
	}
}

// Number of tasks that were started and whose message has not arrived yet, e.g. for a spinner.
tasks_running :: proc() -> int {
	return sync.atomic_load(&g_tasks_running)
}

// Moves the messages of finished tasks into `out`, converted to the app's message type.
@(private)
tasks_drain :: proc(out: ^[dynamic]$Msg) {
	sync.mutex_lock(&g_task_mutex)
	defer sync.mutex_unlock(&g_task_mutex)
	for r in g_task_done {
		m: Msg
		ok := true
		if r.type == typeid_of(Msg) {
			m = (^Msg)(r.msg)^
		} else {
			ok = union_set(any{&m, typeid_of(Msg)}, any{r.msg, r.type})
		}
		if ok {
			append(out, m)
		} else {
			fmt.eprintln("kiln: the result of a task has type", r.type, "which does not fit into", typeid_of(Msg))
		}
		free(r.msg, r.allocator)
		sync.atomic_sub(&g_tasks_running, 1)
	}
	clear(&g_task_done)
}

// Stores `value` in the union `dst`, also when it is a variant of a union nested in `dst`.
@(private)
union_set :: proc(dst: any, value: any) -> bool {
	if reflect.set_union_value(dst, value) {return true}
	info, ok := runtime.type_info_base(type_info_of(dst.id)).variant.(runtime.Type_Info_Union)
	if !ok {return false}
	for v in info.variants {
		if !reflect.is_union(runtime.type_info_base(v)) {continue}
		inner, err := mem.alloc(v.size, v.align, context.temp_allocator)
		if err != nil {return false}
		if union_set(any{inner, v.id}, value) {
			return reflect.set_union_value(dst, any{inner, v.id})
		}
	}
	return false
}

// `task` is generic, so its imports count as unused until an app calls it (for -vet).
@(private = "file")
keep_imports :: proc() {
	_ = thread.create_and_start_with_poly_data
}
