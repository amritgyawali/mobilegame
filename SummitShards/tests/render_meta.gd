extends SceneTree
## Captures the 0.5 screens from the real scene (needs a display): Home with
## Altitude and level, the Codex, runes in a round, the rune and line-choice
## dialogs, the Trader's runes and the run summary with XP.

const PATHS = ["user://preview-m-round.json", "user://preview-m-settings.json", "user://preview-m-profile.json", "user://preview-m-run.json", "user://preview-m-daily.json"]
var app: Control

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String, settle: float = 0.4) -> void:
	await create_timer(settle).timeout
	for i in range(3):
		await process_frame
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = ProjectSettings.globalize_path("res://../Builds/SummitShards-%dx%d-meta-%s.png" % [size.x, size.y, name])
	print("Captured ", path, " result=", root.get_texture().get_image().save_png(path))

func cleanup() -> void:
	for path in PATHS:
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)

func capture() -> void:
	cleanup()
	app = load("res://main.tscn").instantiate()
	app.save_path = PATHS[0]
	app.settings_path = PATHS[1]
	app.profile_path = PATHS[2]
	app.run_path = PATHS[3]
	app.daily_path = PATHS[4]
	app.fixed_seed = 5150
	app.today_override = "2026-10-26"
	root.add_child(app)
	app.profile.seen_tutorial = true
	app.profile.xp = 520
	app.profile.max_altitude = 3
	app.profile.chosen_altitude = 2
	app.profile.runs_played = 9
	app.profile.summits = 1
	app.profile.best_floor = 8
	for id in ["climbing_rope", "twin_rope", "ember_heart", "cairn", "tea_thermos", "heart_of_mountain", "rune_time", "rune_echo", "stone_yak", "moon_bear", "clear_sky", "thin_air"]:
		app.profile.discover(id)
	app.settings.set_value("reduced_motion", true)
	app.apply_settings()
	app.refresh_view()
	await shot("home")
	app.activate("codex")
	app.activate("codex:twin_rope")
	await shot("codex")
	app.activate("done")
	app.activate("run_new")
	app.activate("begin")
	app.run.runes = ["rune_shatter", "dye_fire"]
	app.run.talismans = ["climbing_rope", "twin_rope"]
	app.round_state.talismans = app.run.talismans.duplicate()
	app.refresh_view()
	await shot("play-runes")
	app.activate("rune:0")
	await shot("rune-dialog")
	app.activate("use_rune")
	app.round_state.board[8 * 4 + 3] = 2
	app.handle_click(app.board_rect().position + Vector2(3.5, 4.5) * app.CELL)
	await shot("line-choice")
	app.activate("line:row")
	app.round_state.status = app.Model.WON
	app.round_state.score = app.round_state.target
	app.after_command()
	app.activate("to_camp")
	if app.run.draft_open:
		app.activate("skip")
	app.run.coins = 18
	app.activate("buy_rune:0")
	app.refresh_view()
	await shot("camp-runes")
	app.run.phase = app.Run.LOST
	app.record_run()
	app.open_dialog("run_over")
	app.refresh_view()
	await shot("summary")
	app.queue_free()
	await process_frame
	cleanup()
	quit(0)
