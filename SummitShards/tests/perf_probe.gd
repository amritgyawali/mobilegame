extends SceneTree
## Development probe: GDScript drawing cost per frame while idle, dragging and
## animating a line clear, per layer. Needs a display (not --headless):
##   godot --path SummitShards --script res://tests/perf_probe.gd
## Numbers are CPU time on the machine running it; repeat on a phone build
## with the Godot profiler for device figures.
var app

func _initialize() -> void:
	call_deferred("run")

func settle(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame

func totals() -> Dictionary:
	var result: Dictionary = {}
	for key in app.perf:
		result[key] = app.perf[key].duplicate()
	return result

func measure(label: String, n: int, step: Callable) -> void:
	var before: Dictionary = totals()
	for i in range(n):
		step.call(i)
		await process_frame
	var passes: int = 0
	var usec: int = 0
	var per_layer: Array = []
	for key in app.perf:
		var d_passes: int = app.perf[key][0] - before[key][0]
		var d_usec: int = app.perf[key][1] - before[key][1]
		passes += d_passes
		usec += d_usec
		if d_passes > 0:
			per_layer.append("%s x%d @%.2fms" % [key, d_passes, d_usec / 1000.0 / d_passes])
	print("%-26s frames=%d  repaints=%-4d draw CPU per frame=%.3f ms  low-power=%s  effects=%s  [%s]" % [
		label, n, passes, usec / 1000.0 / n, OS.low_processor_usage_mode, "full" if app.effects.quality == app.effects.FULL else "lite", ", ".join(per_layer)])

func run() -> void:
	var paths: Array = ["user://perf-round.json", "user://perf-settings.json", "user://perf-profile.json"]
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)
	app = load("res://main.tscn").instantiate()
	app.save_path = paths[0]
	app.settings_path = paths[1]
	app.profile_path = paths[2]
	app.fixed_seed = 20261024
	root.add_child(app)
	await settle(0.5)
	app.activate("start")
	app.dialogs.clear()
	app.close_dialog()
	await settle(0.6)
	await measure("idle", 120, func(i): pass)
	app.pointer_pressed(app.tray_rect(0).get_center())
	await measure("dragging a shard", 120, func(i):
		var t: float = i / 120.0 * TAU
		app.pointer_moved(Vector2(360 + cos(t) * 220, 640 + sin(t) * 220), true))
	app.cancel_gesture()
	app.selected = -1
	app.refresh_view()
	await settle(0.3)
	# Stage a two-line clear and watch the whole animation.
	for x in range(1, 8):
		app.round_state.board[56 + x] = 2
	for y in range(0, 7):
		app.round_state.board[y * 8] = 3
	app.round_state.tray[0] = {"shape": 0, "element": 2}
	app.commit_place(0, Vector2i(0, 7))
	await measure("line-clear animation", 60, func(i): pass)
	await settle(1.0)
	await measure("idle after animation", 60, func(i): pass)
	app.queue_free()
	await process_frame
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)
	quit(0)
