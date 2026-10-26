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
	for path in PATHS + [PATHS[3] + ".daily"]:
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
	app.daily_path = PATHS[3] + ".daily"
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

	# --- 0.5: Codex, Altitudes, Daily Climb, runes and XP -----------------
	app.go_home()
	app.settings.set_value("reduced_motion", true)
	app.apply_settings()
	check(ids().has("codex") and not ids().has("alt_up"), "Home has the Codex; no Altitude choice before a summit")
	click_button("codex")
	check(app.dialogs == ["codex"] and ids().has("tab:runes") and ids().has("codex:twin_rope"), "The Codex opens on talismans")
	click_button("tab:hazards")
	check(app.codex_tab == "hazards" and ids().has("codex:stone_yak") and ids().has("codex:summit_warden"), "Codex tabs switch")
	click_button("codex:stone_yak")
	check(app.codex_pick == "stone_yak", "Codex entries can be inspected")
	click_button("done")
	check(app.dialogs.is_empty(), "Done closes the Codex")
	check(app.profile.discovered.size() > 0 and app.profile.xp >= app.profile.discovered.size() * 15, "Talismans, weather and Guardians met were added to the Codex with XP")

	# Altitude selector after a summit.
	app.profile.max_altitude = 2
	app.refresh_view()
	check(ids().has("alt_up") and ids().has("alt_down"), "Altitude arrows appear once unlocked")
	click_button("alt_up")
	click_button("alt_up")
	click_button("alt_up")
	check(app.profile.chosen_altitude == 2, "Altitude choice stops at the highest unlocked")
	click_button("alt_down")
	check(app.profile.chosen_altitude == 1, "Altitude goes back down")
	app.fixed_seed = 8100
	click_button("run_new")
	if app.dialogs.back() == "confirm_run_new":
		click_button("confirm_run_new")
	check(app.run.altitude == 1 and app.run.round.target == 375 and app.run.kind == "expedition", "A new expedition uses the chosen Altitude")
	check(app.run.talisman_pool.size() < app.Talismans.ALL.size() or app.profile.level() >= 10, "Offers come from the unlocked talismans")
	var expedition_seed: int = app.run.run_seed
	back()

	# Runes during a round: instant, line-targeted and slot-targeted.
	app.run.runes = ["rune_time", "rune_shatter"]
	app.round_state.rescue_runes = app.run.rescue_count()
	app.refresh_view()
	check(ids().has("rune:0") and ids().has("rune:1"), "Held runes show in the round header")
	var trays: int = app.round_state.max_trays
	click_button("rune:0")
	check(app.dialogs == ["rune"] and app.dialog_buttons("rune")[1].get("enabled", true), "Tapping a rune asks before using it")
	click_button("use_rune")
	check(app.round_state.max_trays == trays + 2 and app.run.runes == ["rune_shatter"], "Rune of Time used once")
	var row_cell: Vector2i = Vector2i(4, 5)
	app.round_state.board[row_cell.y * 8 + 1] = 2
	click_button("rune:0")
	click_button("use_rune")
	check(app.rune_targeting.get("kind", "") == "line" and app.dialogs.is_empty(), "Shattering waits for a cell")
	back()
	check(app.rune_targeting.is_empty() and app.run.runes == ["rune_shatter"], "Back cancels targeting and keeps the rune")
	click_button("rune:0")
	click_button("use_rune")
	app.handle_click(app.board_rect().position + (Vector2(row_cell) + Vector2(0.5, 0.5)) * app.CELL)
	check(app.dialogs == ["line_choice"], "Tapping a cell asks row or column")
	click_button("line:row")
	var row_clear: bool = true
	for x in range(8):
		row_clear = row_clear and app.round_state.board[row_cell.y * 8 + x] == 0
	check(row_clear and app.run.runes.is_empty() and app.dialogs.is_empty(), "Shattering cleared the row and was spent")
	app.run.runes = ["rune_shrink"]
	app.refresh_view()
	var big_slot: int = -1
	for i in range(3):
		if not app.round_state.tray[i].is_empty() and int(app.round_state.tray[i].shape) != 0:
			big_slot = i
	if big_slot >= 0:
		click_button("rune:0")
		click_button("use_rune")
		app.handle_click(app.tray_rect(big_slot).get_center())
		check(int(app.round_state.tray[big_slot].shape) == 0 and app.run.runes.is_empty(), "Shrinking a tapped shard")
	app.run.runes = ["rune_wealth"]
	app.refresh_view()
	var coins_before: int = app.run.coins
	click_button("rune:0")
	click_button("use_rune")
	check(app.run.coins == coins_before + mini(coins_before, 15), "Wealth works in a round")

	# Camp: rune offers and Wealth at Camp.
	app.round_state.status = Model.WON
	app.round_state.score = app.round_state.target
	app.after_command()
	click_button("to_camp")
	if app.run.draft_open:
		click_button("skip")
	check(ids().has("buy_rune:0") and ids().has("buy_rune:1"), "The Trader sells runes")
	app.run.coins = 30
	app.refresh_view()
	click_button("buy_rune:0")
	check(app.run.runes.size() == 1 and app.run.coins == 30 - app.run.rune_price(), "Buying a rune at Camp")
	app.run.runes = ["rune_wealth"]
	app.refresh_view()
	click_button("camp_rune:0")
	coins_before = app.run.coins
	click_button("use_rune")
	check(app.run.coins == coins_before + mini(coins_before, 15) and app.run.runes.is_empty(), "Wealth works at Camp")

	# The summary shows XP; a summit at the top Altitude unlocks the next.
	var xp_before: int = app.profile.xp
	click_button("pause")
	click_button("restart")
	click_button("confirm_abandon")
	check(app.profile.xp > xp_before and app.route == app.HOME, "An abandoned expedition still earns its XP")

	# Daily Climb: level 2, one attempt per date, alongside an expedition.
	app.profile.xp = 0
	app.today_override = "2026-10-26"
	app.refresh_view()
	var daily_entry: Dictionary = app.current_buttons().filter(func(b): return b.id == "daily")[0]
	check(not daily_entry.get("enabled", true), "The Daily Climb is locked before level 2")
	app.profile.xp = 60
	app.fixed_seed = 8200
	click_button("run_new")
	back()
	var expedition_state: String = JSON.stringify(app.expedition_run.snapshot())
	click_button("pause")
	click_button("home")
	check(app.run_active() and click_button("daily") and app.run.kind == "daily" and app.dialogs.back() == "intro", "Daily Climb starts while an expedition waits")
	check(app.run.run_seed == app.daily_seed("2026-10-26") and app.profile.daily_date == "2026-10-26", "Today's seed, attempt recorded")
	back()
	click_button("pause")
	click_button("home")
	check(app.daily_active() and app.current_buttons().filter(func(b): return b.id == "daily")[0].label == "CONTINUE DAILY", "Home offers to continue the Daily Climb")
	click_button("run_continue")
	check(app.run.kind == "expedition" and JSON.stringify(app.expedition_run.snapshot()) == expedition_state, "The expedition was kept")
	click_button("pause")
	click_button("home")
	click_button("daily")
	click_button("pause")
	click_button("restart")
	click_button("confirm_abandon")
	check(not app.daily_active() and app.current_buttons().filter(func(b): return b.id == "daily")[0].label == "DAILY DONE", "One Daily Climb per day")
	app.today_override = "2026-10-27"
	app.refresh_view()
	check(app.current_buttons().filter(func(b): return b.id == "daily")[0].label == "DAILY CLIMB", "Tomorrow brings a new climb")
	app.queue_free()
	await process_frame
	await make_app()
	check(app.run_active() and not app.daily_active() and app.expedition_run.run_seed != expedition_seed, "Both run slots reload")
	app.dialogs.clear()

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
			app.run.runes = ["rune_time", "rune_echo"]
			app.run.rune_shop = [{"id": "rune_thaw", "sold": false}, {"id": "dye_fire", "sold": false}]
			app.rune_dialog_index = 0
			for dialog in [[], ["intro"], ["round_won"], ["run_over"], ["talismans"], ["confirm_abandon"], ["confirm_run_new"], ["codex"], ["rune"], ["line_choice"]]:
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
