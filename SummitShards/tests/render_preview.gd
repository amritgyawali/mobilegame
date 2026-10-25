extends SceneTree
## Runs the real rendered scene, captures each screen's viewport, then exits.
## Needs a real display/GPU (not --headless). Writes PNGs under ../Builds/.

const TEMP_PATHS = ["user://preview-round.json", "user://preview-settings.json", "user://preview-profile.json"]
var app: Control

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for i in range(count):
		app.queue_redraw()
		await process_frame
	# Low-processor mode draws only when something is dirty.
	app.queue_redraw()
	await RenderingServer.frame_post_draw

## Waits for transitions to settle, then saves the viewport. File names carry
## the window size so captures from several phone shapes can sit together.
func shot(name: String, settle: float = 0.45) -> bool:
	if settle > 0.0:
		await create_timer(settle).timeout
	await frames(3)
	var path: String = ProjectSettings.globalize_path("res://../Builds/SummitShards-%dx%d-%s.png" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y, name])
	var result: int = root.get_texture().get_image().save_png(path)
	print("Captured ", path, " result=", result)
	return result == OK

func cleanup() -> void:
	for path in TEMP_PATHS:
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)

func capture() -> void:
	cleanup()
	app = load("res://main.tscn").instantiate()
	app.save_path = TEMP_PATHS[0]
	app.settings_path = TEMP_PATHS[1]
	app.profile_path = TEMP_PATHS[2]
	app.fixed_seed = 20261024
	root.add_child(app)
	await frames(5)
	var warm_styles: int = app._style_cache.size()
	# Exercise the actual renderer repeatedly, rather than measuring a mock.
	await frames(20)
	if app._style_cache.size() != warm_styles:
		push_error("Style cache grew during repeated unchanged rendering")
		quit(1)
		return
	print("RENDER: stable style cache across 20 redraws (", warm_styles, " resources)")
	var ok: bool = await shot("preview-home")
	app.profile.seen_tutorial = false
	app.activate("start")
	ok = await shot("preview-help") and ok
	app.activate("done")
	# Play a few first-fit moves so the board has content.
	for step in range(6):
		var move: Array = first_move()
		if move.is_empty():
			break
		app.commit_place(move[0], Vector2i(move[1], move[2]))
	app.effects.clear_all()
	app.display_score = app.round_state.score
	# Start a drag over the board to show the floating shard and its preview.
	for slot in range(3):
		var move: Array = first_move_for(slot)
		if not move.is_empty():
			var finger: Vector2 = app.finger_for_anchor(slot, Vector2i(move[0], move[1]))
			app.pointer_pressed(app.tray_rect(slot).get_center())
			app.pointer_moved(finger, true)
			break
	ok = await shot("preview-play") and ok
	app.cancel_gesture()
	app.activate("pause")
	ok = await shot("preview-pause") and ok
	app.activate("settings")
	ok = await shot("preview-settings") and ok
	app.dialogs.clear()
	# A staged pure-line clear, captured mid-animation.
	for x in range(1, 8):
		app.round_state.board[56 + x] = 2
	app.round_state.board[56] = 0
	app.round_state.tray[0] = {"shape": 0, "element": 2}
	app.commit_place(0, Vector2i(0, 7))
	# Freeze the effects 0.12 s in.
	app.set_process(false)
	app.effects.update(0.12)
	app.fx_layer.queue_redraw()
	ok = await shot("preview-clear", 0.0) and ok
	app.effects.clear_all()
	app.start_animation()
	app.dialogs.clear()
	app.settings.set_value("reduced_motion", true)
	app.apply_settings()
	while app.round_state.status == app.Model.PLAYING:
		var move: Array = first_move()
		if move.is_empty():
			if not app.round_state.try_reroll():
				break
			continue
		app.commit_place(move[0], Vector2i(move[1], move[2]))
	if app.dialogs != ["result"]:
		app.dialogs.clear()
		app.open_dialog("result")
		app.refresh_view()
	ok = await shot("preview-result") and ok
	app.queue_free()
	await process_frame
	cleanup()
	quit(0 if ok else 1)

func first_move() -> Array:
	for slot in range(3):
		var move: Array = first_move_for(slot)
		if not move.is_empty():
			return [slot, move[0], move[1]]
	return []

func first_move_for(slot: int) -> Array:
	for y in range(8):
		for x in range(8):
			if app.round_state.can_place(app.round_state.tray[slot], x, y):
				return [x, y]
	return []
