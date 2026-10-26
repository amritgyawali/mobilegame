extends SceneTree
## Drives an expedition through the real scene: Home, round intro, play,
## round cleared, Camp draft and Trader, relaunch, Firebird, run over and
## abandoning, plus Back on every expedition screen.

const Scene = preload("res://main.tscn")
const Store = preload("res://scripts/persistence/json_store.gd")
const Model = preload("res://scripts/round_model.gd")
const PATHS = ["user://exp-scene-round.json", "user://exp-scene-settings.json", "user://exp-scene-profile.json", "user://exp-scene-run.json"]
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
	for path in PATHS:
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

func back() -> void:
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame

func make_app() -> void:
	app = Scene.instantiate()
	app.save_path = PATHS[0]
	app.settings_path = PATHS[1]
	app.profile_path = PATHS[2]
	app.run_path = PATHS[3]
	app.fixed_seed = 6100
	root.add_child(app)
	await process_frame

func first_move() -> Array:
	for slot in range(3):
		for y in range(8):
			for x in range(8):
				if app.round_state.can_place(app.round_state.tray[slot], x, y):
					return [slot, Vector2i(x, y)]
	return []

## Plays first-fit moves until the round ends.
func play_round() -> void:
	for i in range(80):
		if app.round_state.status != Model.PLAYING:
			return
		var move: Array = first_move()
		if move.is_empty():
			click_button("reroll")
		else:
			app.commit_place(move[0], move[1])

func run() -> void:
	cleanup()
	await make_app()
	app.settings.set_value("reduced_motion", true)
	app.apply_settings()

	# A Quick Trail in progress survives an expedition.
	click_button("quick")
	back()
	var quick_move: Array = first_move()
	app.commit_place(quick_move[0], quick_move[1])
	var quick_state: String = JSON.stringify(app.quick_round.snapshot())
	click_button("pause")
	click_button("home")

	# Start: the tutorial sits on top of the first round's intro.
	app.profile.seen_tutorial = false
	check(click_button("run_new") and app.mode == app.RUN and app.route == app.PLAY, "Start Expedition opens the first round")
	check(app.dialogs == ["intro", "help"], "First expedition shows How to Play over the round intro")
	back()
	check(app.dialogs == ["intro"] and app.run.phase == app.Run.INTRO, "Closing the tutorial reveals the intro")
	check(app.round_state == app.run.round and app.round_state.target == 300, "The board shows the Floor 1 Trail round")
	back()
	check(app.dialogs.is_empty() and app.run.phase == app.Run.ROUND, "Back on the intro begins the round")
	check(ids().has("talismans") and ids().has("reroll") and not ids().has("new"), "Expedition play shows the talisman bar")
	click_button("talismans")
	check(app.dialogs == ["talismans"], "The talisman bar opens the talisman list")
	click_button("done")

	# Win the round, then on to Camp.
	play_round()
	check(app.round_state.status == Model.WON and app.dialogs == ["round_won"] and app.run.phase == app.Run.CAMP, "Winning shows Round Cleared")
	var coins: int = app.run.coins
	check(coins == 4 + int(app.run.reward.total), "Coins include the round reward")
	back()
	check(app.route == app.CAMP and app.dialogs.is_empty(), "Back on Round Cleared goes to Camp")
	check(ids().has("draft:0") and ids().has("draft:2") and ids().has("skip") and ids().has("pause") and not ids().has("leave"), "Camp starts with the free draft")
	var card: String = app.run.draft[1]
	click_button("draft:1")
	check(app.run.talismans == [card] and not app.run.draft_open and ids().has("leave") and ids().has("buy:0"), "Taking a card opens the Trader")
	app.run.coins = 50
	app.refresh_view()
	var offer: String = app.run.shop[0].id
	click_button("buy:0")
	check(app.run.talismans == [card, offer] and app.run.coins == 50 - app.run.price(offer), "Buying from the Trader")
	click_button("slot:0")
	check(app.camp_selected == 0 and ids().has("sell") and ids().has("move_right"), "Selecting a talisman shows move and sell")
	click_button("move_right")
	check(app.run.talismans == [offer, card] and app.camp_selected == 1, "Move right reorders")
	back()
	check(app.camp_selected == -1 and app.dialogs.is_empty(), "Back clears the Camp selection")
	back()
	check(app.dialogs == ["pause"], "Back in Camp opens Pause")
	click_button("resume")
	click_button("pause")
	check(app.dialogs == ["pause"], "Camp has an on-screen menu button")
	click_button("resume")
	coins = app.run.coins
	click_button("slot:1")
	click_button("sell")
	check(app.run.talismans == [offer] and app.run.coins == coins + app.Talismans.sell_price(card), "Selling from Camp")

	# Relaunch in Camp: everything comes back.
	var camp_state: String = JSON.stringify(app.run.snapshot())
	app.queue_free()
	await process_frame
	await make_app()
	check(app.route == app.HOME and ids().has("run_continue") and ids().has("run_new"), "Home offers to continue the expedition")
	check(JSON.stringify(app.quick_round.snapshot()) == quick_state, "The Quick Trail was kept")
	click_button("run_continue")
	check(app.mode == app.RUN and app.route == app.CAMP and JSON.stringify(app.run.snapshot()) == camp_state, "Continue returns to Camp unchanged")
	app.settings.set_value("reduced_motion", true)
	app.apply_settings()
	click_button("leave")
	check(app.route == app.PLAY and app.dialogs == ["intro"] and app.run.stage == 1 and app.run.hazard != "", "Leaving Camp announces the Ridge and its weather")
	click_button("begin")

	# Talismans light up when they change a score.
	app.round_state.talismans = ["heart_of_mountain"]
	app.run.talismans = ["heart_of_mountain"]
	var move: Array = first_move()
	app.commit_place(move[0], move[1])
	check(app.effects.flashes.has(0) and app.notice.contains(" x "), "Scoring talismans flash, and the breakdown is shown")

	# Firebird: a second chance, once.
	app.run.talismans = ["firebird_feather"]
	app.round_state.status = Model.LOST
	app.after_command()
	check(app.dialogs.back() == "intro" and app.run.phase == app.Run.INTRO and app.run.talismans.is_empty(), "Firebird restarts the round")
	check(app.round_state == app.run.round and app.round_state.status == Model.PLAYING, "The board shows the restarted round")
	click_button("begin")

	# Losing ends the run once; Back on the summary goes Home.
	var runs: int = app.profile.runs_played
	app.round_state.status = Model.LOST
	app.after_command()
	check(app.dialogs.back() == "run_over" and app.run.phase == app.Run.LOST and app.profile.runs_played == runs + 1, "A lost round ends the run and counts it")
	check(app.profile.best_floor >= 1, "Best floor recorded")
	app.load_run()
	check(app.profile.runs_played == runs + 1, "Reloading a finished run never counts it twice")
	back()
	check(app.route == app.HOME and not ids().has("run_continue") and ids().has("run_new"), "A finished run leaves Home ready for a new one")

	# Abandoning from Pause counts the run and keeps the Quick Trail. A new
	# seed: the relaunch above reset the test seed, and runs are counted per seed.
	app.fixed_seed = 7100
	click_button("run_new")
	back()
	play_round()
	runs = app.profile.runs_played
	if app.dialogs.back() == "round_won":
		click_button("to_camp")
	click_button("pause")
	check(app.current_buttons().filter(func(b): return b.id == "restart")[0].label == "ABANDON RUN", "Pause offers Abandon during an expedition")
	click_button("restart")
	check(app.dialogs.back() == "confirm_abandon", "Abandon asks first")
	click_button("confirm_abandon")
	check(app.route == app.HOME and not app.run_active() and app.profile.runs_played == runs + 1, "Abandoning ends and counts the run")
	click_button("quick")
	check(app.mode == app.QUICK and JSON.stringify(app.quick_round.snapshot()) == quick_state, "Quick Trail resumes where it was")

	# Every expedition control is a 48 dp target on screen.
	var small: Array = []
	var screen = Rect2(0, 0, 720, 1280)
	app.start_run()
	app.dialogs.clear()
	app.close_dialog()
	for route in [app.PLAY, app.CAMP]:
		app.route = route
		if route == app.CAMP:
			app.run.phase = app.Run.CAMP
			app.run.draft = ["cairn", "twin_rope", "avalanche"]
			app.run.shop = [{"id": "momentum", "sold": false}]
		for draft_open in [true, false]:
			app.run.draft_open = draft_open
			app.camp_selected = -1 if draft_open else 0
			app.run.talismans = ["climbing_rope", "tea_thermos"]
			for dialog in [[], ["intro"], ["round_won"], ["run_over"], ["talismans"], ["confirm_abandon"], ["confirm_run_new"]]:
				app.dialogs = dialog.duplicate()
				for entry in app.current_buttons():
					var too_small: bool = entry.rect.size.y < app.BUTTON_H and entry.kind != "chip"
					if too_small or not screen.encloses(entry.rect):
						small.append("%s/%s/%s" % [route, dialog, entry.id])
	check(small.is_empty(), "Expedition touch targets are 48 dp and on screen: %s" % [small])
	app.dialogs.clear()

	app.queue_free()
	await process_frame
	cleanup()
	print("EXPEDITION SCENE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
