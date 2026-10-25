extends SceneTree
## Drives the real scene through taps, drags, Android lifecycle events,
## navigation and saves. Rules are covered separately in rules_test.gd.

const Scene = preload("res://main.tscn")
const Settings = preload("res://scripts/settings_model.gd")
const Profile = preload("res://scripts/profile_model.gd")
const Store = preload("res://scripts/persistence/json_store.gd")
const ROUND_PATH = "user://automated-scene-test.json"
const SETTINGS_PATH = "user://automated-scene-settings.json"
const PROFILE_PATH = "user://automated-scene-profile.json"
var failures: int = 0
var checks: int = 0
var app: Control

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func cleanup() -> void:
	for path in [ROUND_PATH, SETTINGS_PATH, PROFILE_PATH]:
		Store.remove(path)

func ids() -> Array:
	return app.current_buttons().map(func(b): return b.id)

func click_button(id: String) -> bool:
	for entry in app.current_buttons():
		if entry.id == id:
			app.handle_click(entry.rect.get_center())
			return true
	push_error("Button not on screen: " + id)
	return false

func state() -> String:
	return JSON.stringify(app.round_state.snapshot())

func cell_center(cell: Vector2i) -> Vector2:
	return app.BOARD_RECT.position + (Vector2(cell) + Vector2(0.5, 0.5)) * app.CELL

## First legal [slot, cell] in reading order, or [] when none fits.
func first_move() -> Array:
	for slot in range(3):
		for y in range(8):
			for x in range(8):
				if app.round_state.can_place(app.round_state.tray[slot], x, y):
					return [slot, Vector2i(x, y)]
	return []

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame

func make_app() -> void:
	app = Scene.instantiate()
	app.save_path = ROUND_PATH
	app.settings_path = SETTINGS_PATH
	app.profile_path = PROFILE_PATH
	app.fixed_seed = 4100
	root.add_child(app)
	await process_frame

func run() -> void:
	cleanup()
	await make_app()

	# Fresh install: home screen, first start shows the tutorial once.
	check(app.route == app.HOME and ids().has("start") and not ids().has("continue"), "Fresh install opens Home with Start")
	check(click_button("start") and app.route == app.PLAY, "Start opens the round")
	check(app.dialogs == ["help"] and app.profile.seen_tutorial, "First start shows How to Play")
	check(Store.read(PROFILE_PATH).get("seen_tutorial") == true, "Tutorial flag is saved")
	var untouched: String = state()
	# Tap the tray strip below the dialog's button, then the board.
	check(app.button_at(Vector2(130, 1150)).is_empty(), "Probe point is outside the dialog's buttons")
	app.handle_click(Vector2(130, 1150))
	app.handle_click(cell_center(Vector2i(0, 0)))
	check(app.selected == -1 and state() == untouched and app.dialogs == ["help"], "Dialog blocks tray and board beneath it")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.dialogs.is_empty() and app.route == app.PLAY, "Back closes the top dialog")

	# Tap to select, tap to place.
	app.handle_click(Vector2(130, 1080))
	check(app.selected == 0, "Tray tap selects a piece")
	app.handle_click(app.tray_rect(0).get_center())
	check(app.selected == -1, "Tapping the selected piece again deselects it")
	app.handle_click(Vector2(130, 1080))
	app.handle_click(Vector2(65, 340))
	check(app.round_state.score > 0 and app.selected == -1 and app.round_state.moves == 1, "Board tap places selected piece")
	var saved: String = state()
	# A second actual command creates a previous-move backup. Repeated pause
	# events must not replace it with redundant copies of the current state.
	click_button("reroll")
	check(app.round_state.rerolls == 0, "Reroll button wired")
	var latest: String = state()
	check(FileAccess.file_exists(ROUND_PATH + ".bak"), "Second command creates backup")
	var backup: String = FileAccess.get_file_as_string(ROUND_PATH + ".bak")
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(FileAccess.get_file_as_string(ROUND_PATH + ".bak") == backup, "Pause/focus skip unchanged disk writes and preserve prior move")
	check(app.dialogs == ["pause"], "Leaving the app mid-round opens Pause")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.dialogs.is_empty(), "Back resumes from Pause")
	app.round_state.score += 10
	check(app.load_round() and state() == latest, "Scene resumes saved round")
	var file = FileAccess.open(ROUND_PATH, FileAccess.WRITE)
	file.store_string("{broken save")
	file.close()
	check(app.load_round() and state() == saved, "Corrupt primary recovers backup")
	check(app.save_round() and FileAccess.get_file_as_string(ROUND_PATH + ".bak") == backup, "Recovery repairs primary while preserving good backup")
	check(app.load_round() and not app._loaded_from_backup, "Repaired primary loads normally")

	# Drag and drop: the preview shown while dragging is exactly what commits.
	var move: Array = first_move()
	var slot: int = move[0]
	var target: Vector2i = move[1]
	var finger: Vector2 = app.finger_for_anchor(slot, target)
	var score_before: int = app.round_state.score
	app.pointer_pressed(app.tray_rect(slot).get_center())
	app.pointer_moved(app.tray_rect(slot).get_center() + Vector2(4, -4), true)
	check(not app.dragging, "Small finger jitter is not a drag")
	app.pointer_moved(finger, true)
	check(app.dragging and app.selected == slot and app.hover_cell == target, "Drag tracks the cell under the floating shard")
	var preview: Dictionary = app.current_preview()
	check(not preview.is_empty(), "Drag shows a legal placement preview")
	app.pointer_released(finger)
	check(not app.dragging and app.selected == -1 and app.round_state.moves == 2, "Release commits exactly one placement")
	check(app.round_state.score == score_before + int(preview.points), "Committed score equals the drag preview")

	# A drag released somewhere illegal returns the shard.
	move = first_move()
	var before_cancel: String = state()
	app.pointer_pressed(app.tray_rect(move[0]).get_center())
	app.pointer_moved(Vector2(360, 60), true)
	app.pointer_released(Vector2(360, 60))
	check(state() == before_cancel and app.selected == -1 and not app.dragging, "Drag off the board never consumes a piece")
	# Leaving the app mid-drag cancels it; a late release does nothing.
	app.pointer_pressed(app.tray_rect(move[0]).get_center())
	app.pointer_moved(app.finger_for_anchor(move[0], move[1]), true)
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.pointer_released(app.finger_for_anchor(move[0], move[1]))
	check(state() == before_cancel and not app.dragging and app.selected == -1, "Pause cancels an active drag without placing")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	# Hold on the board to preview, slide, release to place.
	app.handle_click(app.tray_rect(move[0]).get_center())
	app.pointer_pressed(cell_center(Vector2i(7, 7)))
	app.pointer_moved(cell_center(move[1]), true)
	check(app.hover_cell == move[1] and not app.current_preview().is_empty(), "Holding on the board previews the placement")
	var moves_before: int = app.round_state.moves
	app.pointer_released(cell_center(move[1]))
	check(app.round_state.moves == moves_before + 1, "Releasing the held preview places the piece")

	# Back hierarchy and navigation.
	app.handle_click(app.tray_rect(first_move()[0]).get_center())
	var before_back: String = state()
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.selected == -1 and state() == before_back and app.dialogs.is_empty(), "Android Back cancels selection without consuming a move")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.dialogs == ["pause"], "Back during play opens Pause")
	click_button("home")
	check(app.route == app.HOME and app.dialogs.is_empty() and ids().has("continue"), "Home offers Continue for a trail in progress")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.dialogs == ["confirm_exit"], "Back on Home asks before exiting")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.dialogs.is_empty() and app.route == app.HOME, "Back dismisses the exit question")
	click_button("continue")
	check(app.route == app.PLAY and app.dialogs.is_empty() and state() == before_back, "Continue resumes without a tutorial")

	# Starting over asks first, and counts the abandoned trail once.
	var played_before: int = app.profile.rounds_played
	click_button("new")
	check(app.dialogs == ["confirm_new"], "New Trail mid-round asks for confirmation")
	click_button("cancel")
	check(app.dialogs.is_empty() and state() == before_back, "Cancel keeps the trail")
	click_button("new")
	click_button("confirm_new")
	check(app.round_state.score == 0 and app.round_state.moves == 0 and app.round_state.rerolls == 1 and app.dialogs.is_empty(), "Confirmed New Trail starts fresh")
	check(app.profile.rounds_played == played_before + 1 and app.profile.win_streak == 0, "Abandoned trail counts as played")
	click_button("new")
	check(app.dialogs.is_empty() and app.round_state.moves == 0, "An untouched trail restarts without asking")

	# Settings persist on their own and survive a new trail.
	click_button("pause")
	click_button("settings")
	check(app.dialogs == ["pause", "settings"], "Settings opens over Pause")
	click_button("toggle:sound")
	click_button("toggle:reduced_motion")
	check(not app.settings.get_value("sound") and not app.sfx.enabled, "Sound toggle mutes effects")
	check(app.settings.get_value("reduced_motion") and app.effects.reduced_motion, "Reduced motion toggle applies")
	var reloaded = Settings.new()
	reloaded.from_dict(Store.read(SETTINGS_PATH))
	check(not reloaded.get_value("sound") and reloaded.get_value("reduced_motion") and reloaded.get_value("clear_preview"), "Settings are saved")
	click_button("done")
	click_button("resume")
	check(app.dialogs.is_empty(), "Done and Resume close both dialogs")
	app.effects.add_text("probe", Vector2.ZERO, Color.WHITE, 20)
	app.effects.add_pop([0, 1])
	check(app.effects.pops.is_empty() and app.effects.texts[-1].rise == 0.0, "Reduced motion removes pops and floating movement")
	app.effects.clear_all()

	# Play the trail to the end: the result appears and is recorded once.
	var guard: int = 0
	var rejected: int = 0
	while app.round_state.status == app.Model.PLAYING and guard < 40:
		guard += 1
		move = first_move()
		if move.is_empty():
			click_button("reroll")
		elif not app.commit_place(move[0], move[1]):
			rejected += 1
	check(rejected == 0, "Every legal first-fit move commits")
	check(app.round_state.status != app.Model.PLAYING, "Trail finishes")
	check(app.dialogs == ["result"] and app.dialog_ready(), "Result shows at once with reduced motion")
	var played: int = app.profile.rounds_played
	check(played == played_before + 2, "Finished trail recorded")
	check(app.profile.best_score >= app.round_state.score, "Best altitude updated")
	app.record_if_finished()
	app.load_round()
	app.record_if_finished()
	check(app.profile.rounds_played == played, "Reloading a finished trail never counts it twice")
	var stored = Profile.new()
	stored.from_dict(Store.read(PROFILE_PATH))
	check(stored.rounds_played == played and stored.best_score == app.profile.best_score, "Profile is saved")
	app.handle_click(cell_center(Vector2i(3, 3)))
	check(app.dialogs == ["result"], "Board is locked under the result")
	click_button("next")
	check(app.dialogs.is_empty() and app.round_state.status == app.Model.PLAYING and app.round_state.moves == 0, "Next Trail starts a new round")
	check(app.profile.rounds_played == played, "Next Trail after a finish adds no extra play")

	# With motion on, the result waits for its entrance before accepting taps.
	click_button("pause")
	click_button("settings")
	click_button("toggle:reduced_motion")
	app.dialogs.clear()
	app.open_dialog("result")
	var round_id: int = app.round_state.seed_initial
	app.handle_click(app.dialog_buttons("result")[1].rect.get_center())
	check(app.round_state.seed_initial == round_id and app.dialogs == ["result"], "Result ignores taps during its entrance")
	app.effects.time += 2.0
	check(app.dialog_ready(), "Result accepts taps after its entrance")
	app.dialogs.clear()

	# Reset statistics keeps settings, the current trail and the tutorial flag.
	var trail: String = state()
	click_button("pause")
	click_button("settings")
	click_button("reset_stats")
	check(app.dialogs.back() == "confirm_reset", "Reset asks first")
	click_button("confirm_reset")
	check(app.profile.rounds_played == 0 and app.profile.best_score == 0 and app.profile.seen_tutorial, "Reset clears statistics only")
	check(state() == trail and not app.settings.get_value("sound"), "Reset keeps trail and settings")
	app.dialogs.clear()

	# A relaunch restores everything from disk.
	app.queue_free()
	await process_frame
	await make_app()
	check(app.route == app.HOME and state() == trail, "Relaunch restores the trail")
	check(not app.settings.get_value("sound") and not app.sfx.enabled, "Relaunch restores settings")
	check(app.profile.seen_tutorial and app.profile.rounds_played == 0, "Relaunch restores the profile")

	# Smoothness: still screens paint nothing; motion moves layers instead of
	# repainting them; battery-saving low-processor mode returns when still.
	check(click_button("start") and app.route == app.PLAY, "Start resumes the untouched trail")
	await wait(0.5)
	check(app.content.modulate.a == 1.0 and app.content.position == app.layout_offset, "Screen transition settles")
	var passes: int = app.draw_passes()
	for i in range(30):
		await process_frame
	check(app.draw_passes() == passes, "A still screen repaints nothing")
	check(OS.low_processor_usage_mode and not app.is_processing(), "A still screen is in low-power mode")
	move = first_move()
	var board_passes: int = app.draw_passes(["board"])
	var drag_passes: int = app.draw_passes(["drag"])
	finger = app.finger_for_anchor(move[0], move[1])
	app.pointer_pressed(app.tray_rect(move[0]).get_center())
	app.pointer_moved(finger, true)
	check(app.dragging and not OS.low_processor_usage_mode and app.is_processing(), "Dragging lifts low-power mode")
	await wait(0.3)
	passes = app.draw_passes()
	for i in range(10):
		app.pointer_moved(finger + Vector2(i % 3, -(i % 2)), true)
		await process_frame
	check(app.draw_passes() == passes, "Moving within one cell repaints nothing")
	check(app.drag_layer.position == finger + Vector2(0, -1) and app.drag_layer.scale == Vector2.ONE, "The shard follows the finger at board size")
	var static_layers: Array = ["chrome", "board", "hud", "drag", "slot0", "slot1", "slot2"]
	var static_passes: int = app.draw_passes(static_layers)
	var light_passes: int = app.draw_passes(["preview", "score"])
	var step: Vector2 = Vector2(-app.CELL, 0) if move[1].x > 0 else Vector2(app.CELL, 0)
	app.pointer_moved(finger + step, true)
	await process_frame
	check(app.draw_passes(static_layers) == static_passes and app.draw_passes(["preview", "score"]) > light_passes, "A new cell repaints only the preview and hint")
	app.pointer_moved(finger, true)
	app.pointer_released(finger)
	check(app.draw_passes(["drag"]) == drag_passes + 1, "The dragged shard paints once per drag")
	await wait(1.2)
	check(app.draw_passes(["board"]) - board_passes <= 2, "A move repaints the board at most twice")
	check(OS.low_processor_usage_mode and not app.is_processing(), "Low-power mode returns after the animation")
	# A shard dropped off the board flies home, then the slot shows it again.
	move = first_move()
	app.pointer_pressed(app.tray_rect(move[0]).get_center())
	app.pointer_moved(Vector2(360, 60), true)
	app.pointer_released(Vector2(360, 60))
	check(app.drag_layer.visible and app.slot_layers[move[0]].self_modulate.a < 1.0, "A cancelled drag flies back to its slot")
	await wait(0.4)
	check(not app.drag_layer.visible and app.slot_layers[move[0]].self_modulate.a == 1.0, "The shard is back in its slot")
	# New shards pop into the tray without repainting each frame.
	var slot_passes: int = app.draw_passes(["slot0", "slot1", "slot2"])
	check(click_button("reroll") and app.round_state.rerolls == 0, "Reroll for the refill check")
	await wait(0.6)
	check(app.draw_passes(["slot0", "slot1", "slot2"]) - slot_passes <= 3, "Refilled shards paint once each")
	check(app.slot_layers.all(func(l): return l.scale == Vector2.ONE and l.modulate.a == 1.0), "Refill animation settles")
	# A winning move: the result stays hidden and unpainted during the clear.
	for x in range(1, 8):
		app.round_state.board[56 + x] = 2
	app.round_state.board[56] = 0
	app.round_state.tray[0] = {"shape": 0, "element": 2}
	app.round_state.score = app.round_state.target - 1
	var overlay_passes: int = app.draw_passes(["overlay"])
	check(app.commit_place(0, Vector2i(0, 7)) and app.dialogs == ["result"], "Winning move opens the result")
	await process_frame
	await process_frame
	check(not app.overlay_layer.visible and app.draw_passes(["overlay"]) == overlay_passes and not app.dialog_ready(), "Result waits, unpainted, while lines clear")
	await wait(1.3)
	check(app.overlay_layer.visible and app.overlay_layer.modulate.a == 1.0 and app.draw_passes(["overlay"]) == overlay_passes + 1 and app.dialog_ready(), "Result fades in once, then accepts taps")
	click_button("home")
	await wait(0.4)
	check(app.route == app.HOME and app.dialogs.is_empty() and not app.board_layer.visible and app.content.modulate.a == 1.0, "Home after a result")

	# Any phone shape: the layout fills the width of tall screens, sits low
	# for the thumb with a margin above the bottom edge, and centres on wide ones.
	var original_size: Vector2 = app.size
	app.size = Vector2(720, 1600)
	app.update_layout()
	var bottom: float = app.layout_offset.y + 1280 * app.layout_scale
	check(app.layout_scale == 1.0 and app.layout_offset.y > 160 and bottom < 1600 - 60, "Tall screen: full width, lower placement, bottom margin")
	app.size = Vector2(960, 1280)
	app.update_layout()
	check(app.layout_scale == 1.0 and app.layout_offset == Vector2(120, 0), "Wide screen: centred")
	app.size = original_size
	app.update_layout()

	# Every control on every screen is a 48 dp target inside the layout.
	var small: Array = []
	var screen = Rect2(0, 0, 720, 1280)
	for route in [app.HOME, app.PLAY]:
		app.route = route
		for dialog in [[], ["pause"], ["settings"], ["help"], ["result"], ["confirm_new"], ["confirm_exit"], ["confirm_reset"]]:
			app.dialogs = dialog.duplicate()
			for entry in app.current_buttons():
				if entry.rect.size.y < app.BUTTON_H or not screen.encloses(entry.rect):
					small.append("%s/%s/%s" % [route, dialog, entry.id])
	app.dialogs.clear()
	app.route = app.HOME
	check(small.is_empty(), "Touch targets are at least 48 dp and on screen: %s" % [small])

	# Bounded resources.
	var first_style: StyleBoxFlat = app.panel(Color("24464a"), 14)
	for i in range(500):
		app.panel(Color("24464a"), 14)
	check(app.panel(Color("24464a"), 14) == first_style, "Tile/card styles reuse one cached resource")
	var cached: int = app._style_cache.size()
	for i in range(256):
		app.panel(Color(1, 1, 1, i / 255.0), 10)
	check(app._style_cache.size() <= cached + 17, "Fading styles reuse a bounded set")
	app.settings.set_value("reduced_motion", false)
	app.apply_settings()
	for i in range(500):
		app.effects.add_clear(i % 64, 1, Vector2.ZERO, Color.WHITE)
		app.effects.add_text("x", Vector2.ZERO, Color.WHITE, 20)
	check(app.effects.particles.size() <= app.effects.MAX_PARTICLES and app.effects.texts.size() <= app.effects.MAX_TEXTS, "Effect pools stay bounded")
	app.effects.update(5.0)
	check(not app.effects.active(), "Effects expire")
	check(app.sfx.has_sound("clear") and app.sfx.has_sound("win"), "Sound effects are synthesized")

	app.queue_free()
	await process_frame
	cleanup()
	print("SCENE: %d interaction/navigation/lifecycle/save checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
