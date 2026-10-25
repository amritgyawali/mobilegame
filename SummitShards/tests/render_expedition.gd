extends SceneTree
## Captures the expedition screens from the real scene (needs a display):
## intro, play with talismans and Stones, round cleared, Camp draft, Trader,
## talisman list and run over. Writes PNGs under ../Builds/.

const PATHS = ["user://preview-x-round.json", "user://preview-x-settings.json", "user://preview-x-profile.json", "user://preview-x-run.json"]
var app: Control

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String, settle: float = 0.45) -> void:
	await create_timer(settle).timeout
	for i in range(3):
		await process_frame
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = ProjectSettings.globalize_path("res://../Builds/SummitShards-%dx%d-run-%s.png" % [size.x, size.y, name])
	print("Captured ", path, " result=", root.get_texture().get_image().save_png(path))

func cleanup() -> void:
	for path in PATHS:
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)

func first_move() -> Array:
	for slot in range(3):
		for y in range(8):
			for x in range(8):
				if app.round_state.can_place(app.round_state.tray[slot], x, y):
					return [slot, Vector2i(x, y)]
	return []

func capture() -> void:
	cleanup()
	app = load("res://main.tscn").instantiate()
	app.save_path = PATHS[0]
	app.settings_path = PATHS[1]
	app.profile_path = PATHS[2]
	app.run_path = PATHS[3]
	app.fixed_seed = 4242
	root.add_child(app)
	await shot("home-new")
	app.profile.seen_tutorial = true
	app.settings.set_value("reduced_motion", true)
	app.apply_settings()
	app.activate("run_new")
	await shot("intro")
	app.activate("begin")
	# Play until the first round is won.
	var guard: int = 0
	while app.run.phase == app.Run.ROUND and guard < 60:
		guard += 1
		var move: Array = first_move()
		if move.is_empty():
			app.activate("reroll")
		else:
			app.commit_place(move[0], move[1])
	await shot("round-won")
	app.activate("to_camp")
	await shot("camp-draft")
	app.activate("draft:0")
	app.run.coins += 14
	app.refresh_view()
	app.activate("buy:0")
	app.activate("slot:0")
	await shot("camp-trader")
	app.activate("slot:0")
	app.activate("leave")
	await shot("intro-ridge")
	app.activate("begin")
	# Show a fuller build and some Stones mid-round.
	app.run.talismans = ["climbing_rope", "ember_heart", "cairn", "twin_rope", "heart_of_mountain"]
	app.round_state.talismans = app.run.talismans.duplicate()
	app.round_state.target = 999999
	app.round_state.add_stones(5)
	for i in range(3):
		var move: Array = first_move()
		if not move.is_empty():
			app.commit_place(move[0], move[1])
	app.round_state.board[app.round_state.board.find(app.round_state.STONE)] = app.round_state.CRACKED
	app.effects.clear_all()
	for slot in [1, 3]:
		app.effects.add_flash(slot)
	app.refresh_view()
	app.set_process(false)
	app.fx_layer.queue_redraw()
	await shot("play", 0.0)
	app.set_process(true)
	app.activate("talismans")
	await shot("talismans")
	app.activate("done")
	app.run.phase = app.Run.LOST
	app.record_run()
	app.open_dialog("run_over")
	app.refresh_view()
	await shot("over")
	app.dialogs.clear()
	app.close_dialog()
	app.go_home()
	await shot("home-continue")
	app.queue_free()
	await process_frame
	cleanup()
	quit(0)
