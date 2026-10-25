extends SceneTree

const Scene = preload("res://main.tscn")
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = Scene.instantiate()
	app.save_path = "user://automated-scene-test.json"
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(app.save_path + suffix):
			DirAccess.remove_absolute(app.save_path + suffix)
	root.add_child(app)
	await process_frame
	app.handle_click(Vector2(130, 1080))
	check(app.selected == 0, "Tray tap selects a piece")
	app.handle_click(Vector2(65, 340))
	check(app.round_state.score > 0 and app.selected == -1, "Board tap places selected piece")
	var saved: String = JSON.stringify(app.round_state.snapshot())
	# A second actual command creates a previous-move backup. Repeated pause
	# events must not replace it with redundant copies of the current state.
	app.handle_click(Vector2(500, 1210))
	var latest: String = JSON.stringify(app.round_state.snapshot())
	check(FileAccess.file_exists(app.save_path + ".bak"), "Second command creates backup")
	var backup: String = FileAccess.get_file_as_string(app.save_path + ".bak")
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(FileAccess.get_file_as_string(app.save_path + ".bak") == backup, "Pause/focus skip unchanged disk writes and preserve prior move")
	app.round_state.score += 10
	check(app.load_round() and JSON.stringify(app.round_state.snapshot()) == latest, "Scene resumes saved round")
	var file = FileAccess.open(app.save_path, FileAccess.WRITE)
	file.store_string("{broken save")
	file.close()
	check(app.load_round() and JSON.stringify(app.round_state.snapshot()) == saved, "Corrupt primary recovers backup")
	check(app.save_round() and FileAccess.get_file_as_string(app.save_path + ".bak") == backup, "Recovery repairs primary while preserving good backup")
	check(app.load_round() and not app._loaded_from_backup, "Repaired primary loads normally")
	app.handle_click(Vector2(500, 1210))
	check(app.round_state.rerolls == 0, "Reroll button wired")
	app.handle_click(Vector2(160, 1210))
	check(app.round_state.score == 0 and app.round_state.rerolls == 1, "New round button wired")
	app.handle_click(Vector2(130, 1080))
	var before_back: String = JSON.stringify(app.round_state.snapshot())
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.selected == -1 and JSON.stringify(app.round_state.snapshot()) == before_back, "Android Back cancels selection without consuming a move")
	var first_style: StyleBoxFlat = app.panel(Color("24464a"), 14)
	for i in range(500):
		app.panel(Color("24464a"), 14)
	check(app.panel(Color("24464a"), 14) == first_style, "Tile/card styles reuse one cached resource")
	app.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute("user://automated-scene-test.json" + suffix)
	print("SCENE: %d interaction/lifecycle/save/cache checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
