extends SceneTree
## Runes, Altitudes, unlocks, Expedition XP and levels, the Codex and the
## Daily Climb. Pure models only.

const Model = preload("res://scripts/round_model.gd")
const Run = preload("res://scripts/run_model.gd")
const Profile = preload("res://scripts/profile_model.gd")
const Runes = preload("res://scripts/content/runes.gd")
const Talismans = preload("res://scripts/content/talismans.gd")
const Encounters = preload("res://scripts/content/encounters.gd")
const Progression = preload("res://scripts/content/progression.gd")
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_all")

func first_move(round) -> Array:
	for slot in range(3):
		for y in range(8):
			for x in range(8):
				if round.can_place(round.tray[slot], x, y):
					return [slot, x, y]
	return []

func step(run) -> void:
	var move: Array = first_move(run.round)
	if move.is_empty():
		run.round.try_reroll()
	else:
		run.round.try_place(move[0], move[1], move[2])
	run.after_round_command()

func play_to_camp(run) -> void:
	for i in range(400):
		if run.phase == Run.INTRO:
			run.begin()
		elif run.phase == Run.ROUND:
			step(run)
		else:
			return

func run_all() -> void:
	check_round_runes()
	check_run_runes()
	check_altitudes()
	check_unlocks_and_xp()
	check_daily_and_codex()
	print("META: %d rune/altitude/progression checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check_round_runes() -> void:
	var round = Model.new(12, 99999, 8)
	var trays: int = round.max_trays
	check(round.use_rune("rune_time") and round.max_trays == trays + 2, "Rune of Time adds two trays")
	# Shattering: needs something to destroy; removes Stones too; keeps streak.
	round.board[8 * 3 + 2] = 4
	round.board[8 * 3 + 5] = Model.STONE
	round.streak = 2
	var empty_row: int = 6
	for i in range(8):
		round.board[empty_row * 8 + i] = 0
	check(not round.use_rune("rune_shatter", {"axis": "row", "index": empty_row}), "Shattering an empty line is refused")
	check(not round.use_rune("rune_shatter", {"axis": "diagonal", "index": 3}) and not round.use_rune("rune_shatter", {"axis": "row", "index": 8}), "Shattering needs a real row or column")
	check(round.use_rune("rune_shatter", {"axis": "row", "index": 3}) and round.board.slice(24, 32).all(func(t): return t == 0) and round.streak == 2, "Shattering clears the row, Stones included, and keeps the streak")
	round.board[2] = 1
	round.board[2 + 8 * 5] = 3
	check(round.use_rune("rune_shatter", {"axis": "col", "index": 2}) and round.board[2] == 0 and round.board[42] == 0, "Shattering a column")
	# Thaw.
	check(not round.use_rune("rune_thaw"), "Thaw needs Stones")
	round.board[10] = Model.STONE
	round.board[11] = Model.CRACKED
	round.board[12] = 2
	check(round.use_rune("rune_thaw") and round.board[10] == 0 and round.board[11] == 0 and round.board[12] == 2, "Thaw removes only Stones")
	# Echo: the next placement scores twice; the preview shows it too.
	var echo = Model.new(30, 99999, 8)
	var move: Array = first_move(echo)
	var plain: int = echo.preview(echo.tray[move[0]], move[1], move[2]).points
	check(echo.use_rune("rune_echo") and not echo.use_rune("rune_echo"), "Echo cannot stack")
	var echoed: Dictionary = echo.preview(echo.tray[move[0]], move[1], move[2])
	var result: Dictionary = echo.try_place(move[0], move[1], move[2])
	check(echoed.points == plain * 2 and result.points == plain * 2 and not echo.echo_next, "Echo doubles exactly one placement")
	# Shrinking.
	var shrink = Model.new(31, 99999, 8)
	var slot: int = -1
	for i in range(3):
		if int(shrink.tray[i].shape) != 0:
			slot = i
	var element: int = int(shrink.tray[slot].element)
	check(shrink.use_rune("rune_shrink", {"slot": slot}) and shrink.tray[slot] == {"shape": 0, "element": element}, "Shrinking turns a shard into a dot")
	check(not shrink.use_rune("rune_shrink", {"slot": slot}) and not shrink.use_rune("rune_shrink", {"slot": 5}), "Shrinking needs a real, larger shard")
	# Stillness: three non-clearing placements keep the streak.
	var still = Model.new(1, 99999, 8)
	still.streak = 4
	check(still.use_rune("rune_still") and still.still_moves == 3, "Stillness protects three placements")
	var protected: bool = true
	for i in range(3):
		var m: Array = first_move(still)
		var lines_before: int = still.lines_total
		still.try_place(m[0], m[1], m[2])
		if still.lines_total == lines_before:
			protected = protected and still.streak >= 4
	check(protected and still.still_moves == 0, "Stillness keeps the streak, then expires")
	# Dyes.
	var dye = Model.new(33, 99999, 8)
	check(dye.use_rune("dye_fire") and dye.tray.all(func(p): return p.is_empty() or int(p.element) == 3), "Fire Dye makes every shard Fire")
	check(not dye.use_rune("dye_fire"), "A Dye that changes nothing is refused")
	check(not Model.new(1).use_rune("rune_wealth") and not Model.new(1).use_rune("nonsense"), "Round-level runes only")
	# A rescue rune keeps a blocked round alive.
	# Isolated empty cells and a tray of 3x3 squares: nothing fits.
	var stuck = Model.new(40, 99999, 8, {"rerolls": 0, "rescues": 1})
	for i in range(64):
		stuck.board[i] = 0 if (i % 8 + i / 8) % 2 == 0 else 1 + (i % 5)
	var square: int = stuck.shapes.size() - 1
	stuck.tray = [{"shape": square, "element": 1}, {"shape": square, "element": 2}, {"shape": square, "element": 3}]
	stuck.status = Model.PLAYING
	stuck.update_blocked()
	check(not stuck.has_legal_move() and stuck.status == Model.PLAYING, "Holding a rescue rune keeps a stuck round playable")
	check(stuck.use_rune("rune_shrink", {"slot": 0}) and stuck.has_legal_move(), "Shrinking frees the stuck round")
	stuck.tray[0] = {"shape": square, "element": 1}
	stuck.rescue_runes = 0
	stuck.update_blocked()
	check(stuck.status == Model.LOST, "Without a rescue rune, a stuck round is lost")
	# Saves keep Echo and Stillness.
	var saved = Model.new(50, 99999, 8)
	saved.use_rune("rune_echo")
	saved.use_rune("rune_still")
	var copy = Model.new(1)
	check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(saved.snapshot()))) and copy.echo_next and copy.still_moves == 3, "Rune effects survive a save")
	var damaged: Dictionary = saved.snapshot()
	damaged.counters.echo = 1
	check(not copy.restore_snapshot(damaged), "A damaged rune counter is rejected")

func check_run_runes() -> void:
	var run = Run.new(606)
	play_to_camp(run)
	check(run.phase == Run.CAMP and run.rune_shop.size() == 2 and run.rune_shop[0].id != run.rune_shop[1].id, "Camp offers two different runes")
	run.skip_draft()
	run.coins = 20
	check(run.rune_price() == 3 and run.buy_rune(0) and run.coins == 17 and run.runes.size() == 1 and not run.buy_rune(0), "Buying a rune once")
	check(run.buy_rune(1) and run.runes.size() == 2, "Two rune slots")
	run.rune_shop[0].sold = false
	check(not run.buy_rune(0), "No third rune")
	run.runes = ["rune_wealth", "rune_echo"]
	run.coins = 12
	check(run.use_rune(0) and run.coins == 24 and run.runes == ["rune_echo"], "Wealth doubles Coins at Camp")
	run.coins = 40
	run.runes.push_front("rune_wealth")
	check(run.use_rune(0) and run.coins == 55, "Wealth adds at most 15")
	check(not run.use_rune(0) and run.runes == ["rune_echo"], "Round runes wait for a round")
	var cost: int = run.reroll_cost()
	var offers_before: String = JSON.stringify(run.rune_shop)
	run.coins = 50
	run.reroll_shop()
	check(run.coins == 50 - cost and run.rune_shop.size() == 2, "A Trader reroll refreshes the runes too")
	run.leave_camp()
	run.begin()
	check(run.round.rescue_runes == 0, "Echo is not a rescue rune")
	check(run.use_rune(0) and run.runes.is_empty() and run.round.echo_next, "Echo used in a round")
	run.runes = ["rune_shatter"]
	run.round.rescue_runes = run.rescue_count()
	check(run.round.rescue_runes == 1, "Shattering counts as a rescue")
	check(not run.use_rune(0, {"axis": "row", "index": 9}) and run.runes == ["rune_shatter"], "A failed rune is kept")
	var copy = Run.new(1)
	check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(run.snapshot()))) and copy.runes == ["rune_shatter"] and copy.round.rescue_runes == 1, "Runes survive a run save")
	for bad in [["runes", ["rune_teleport"]], ["runes", ["rune_time", "rune_time", "rune_time"]], ["rune_shop", [{"id": "rune_time"}]], ["altitude", 11], ["kind", "weekly"]]:
		var damaged: Dictionary = run.snapshot()
		damaged[bad[0]] = bad[1]
		check(not copy.restore_snapshot(damaged), "Damaged run field rejected: %s" % bad[0])
	var legacy: Dictionary = run.snapshot()
	for key in ["altitude", "kind", "talisman_pool", "rune_pool", "runes", "rune_shop"]:
		legacy.erase(key)
	check(copy.restore_snapshot(legacy) and copy.altitude == 0 and copy.kind == "expedition" and copy.runes.is_empty() and copy.talisman_pool.size() == Talismans.ALL.size(), "A 0.4 run save loads with defaults")

func check_altitudes() -> void:
	var base = Run.new(77)
	var hard = Run.new(77, {"altitude": 10})
	check(hard.round.target == 600 and base.round.target == 300, "Altitude 10 doubles targets")
	check(Run.new(77, {"altitude": 1}).round.target == 375 and Run.new(77, {"altitude": 6}).round.target == 450, "Altitude 1 and 6 target multipliers")
	check(hard.round.rerolls == 0 and base.round.rerolls == 1, "Altitude 5+: no starting reroll")
	check(hard.round.max_trays == 7 and base.round.max_trays == 8, "Altitude 9+: 7-tray Trails")
	check(hard.round.rules.has("fixed_disabled") and not base.round.rules.has("fixed_disabled"), "Altitude 10 disables a talisman")
	hard.talismans = ["climbing_rope", "tea_thermos", "cairn"]
	hard.make_round()
	check(hard.round.scoring_talismans().size() == 2, "The disabled talisman does not score")
	check(hard.price("cairn") == Talismans.price("cairn") + 1 and hard.rune_price() == 4, "Altitude 2+: Trader prices +1")
	check(hard.draft_size() == 2 and base.draft_size() == 3, "Altitude 3+: drafts of two")
	check(hard.interest_cap() == 3 and base.interest_cap() == 5, "Altitude 8+: interest capped at 3")
	var ridge = Run.new(78, {"altitude": 4})
	ridge.stage = 1
	ridge.start_encounter()
	var plain_ridge = Run.new(78)
	plain_ridge.stage = 1
	plain_ridge.start_encounter()
	check(int(ridge.round_rules().get("stones_start", 0)) == int(plain_ridge.round_rules().get("stones_start", 0)) + 2, "Altitude 4+: Ridges add 2 Stones")
	var boss = Run.new(79, {"altitude": 7})
	boss.stage = 2
	boss.floor_index = 2
	boss.start_encounter()
	var ids: Array = boss.hazard_ids()
	check(ids.size() == 2 and ids[0] == boss.hazard and ids[1] != boss.hazard and Encounters.GUARDIANS.has(ids[1]), "Altitude 7+: Guardians bring a second rule")
	var full_run = Run.new(80, {"altitude": 3})
	play_to_camp(full_run)
	check(full_run.phase != Run.CAMP or full_run.draft.size() == 2, "The draft really shows two cards at Altitude 3")

func check_unlocks_and_xp() -> void:
	check(Progression.xp_for_level(2) == 60 and Progression.xp_for_level(5) == 420 and Progression.xp_for_level(6) == 600 and Progression.xp_for_level(11) == 1620, "Level thresholds follow the design")
	check(Progression.level_for_xp(0) == 1 and Progression.level_for_xp(59) == 1 and Progression.level_for_xp(60) == 2 and Progression.level_for_xp(420) == 5, "Levels from XP")
	var increasing: bool = true
	for level in range(2, Progression.MAX_LEVEL + 1):
		increasing = increasing and Progression.xp_for_level(level) > Progression.xp_for_level(level - 1)
	check(increasing and Progression.level_for_xp(1 << 30) == Progression.MAX_LEVEL, "Thresholds increase to level 50")
	var starters: Array = Progression.unlocked(1, "talismans")
	check(starters.size() == 19 and not starters.has("thunderclap") and starters.has("twin_rope"), "The starter set")
	var everything: Array = Progression.unlocked(10, "talismans")
	everything.sort()
	var all_ids: Array = Talismans.ALL.keys()
	all_ids.sort()
	check(everything == all_ids, "Level 10 unlocks every talisman")
	var all_runes: Array = Progression.unlocked(10, "runes")
	all_runes.sort()
	check(all_runes == Runes.ids() and not Progression.unlocked(1, "runes").has("rune_shatter"), "Runes unlock by level 4")
	var fresh = Run.new(81, {"talisman_pool": starters, "rune_pool": Progression.unlocked(1, "runes")})
	var only_starters: bool = true
	for n in range(40):
		for id in fresh.roll_offers(3, true, []):
			only_starters = only_starters and starters.has(id)
	check(only_starters, "Offers come only from unlocked talismans")
	var profile = Profile.new()
	var summary: Dictionary = profile.record_run(1, false, 3, 5, 1)
	check(summary.xp == 5 * 10 + 25 and profile.xp == 75 and profile.level() == 2 and summary.unlocks.has("Daily Climb"), "XP for rounds and Guardians; level 2 unlocks the Daily Climb")
	check(profile.record_run(1, false, 3, 5, 1).is_empty() and profile.xp == 75, "A run's XP is counted once")
	summary = profile.record_run(2, true, 8, 24, 8, 0)
	check(summary.xp == 240 + 200 + 100 and summary.altitude_unlocked and profile.max_altitude == 1, "A summit gives 100 XP and unlocks Altitude 1")
	check(not profile.record_run(3, true, 8, 24, 8, 0).altitude_unlocked and profile.max_altitude == 1, "Only a summit at the highest Altitude unlocks the next")
	check(profile.record_run(4, true, 8, 24, 8, 1).altitude_unlocked and profile.max_altitude == 2, "Altitude 1 summit unlocks Altitude 2")
	check(not profile.record_run(5, true, 8, 24, 8, 2, "daily").altitude_unlocked, "Daily Climbs never unlock Altitudes")
	profile.chosen_altitude = 2
	var stored = Profile.new()
	stored.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	check(stored.to_dict() == profile.to_dict(), "Progression round trip")
	stored.from_dict({"xp": -9, "max_altitude": 99, "chosen_altitude": 50, "discovered": [1, "cairn", "cairn", "x".repeat(80)], "daily_date": 5})
	check(stored.xp == 0 and stored.max_altitude == 10 and stored.chosen_altitude == 10 and stored.discovered == ["cairn"] and stored.daily_date == "", "Damaged progression values are cleaned")
	var xp_before: int = profile.xp
	profile.reset()
	check(profile.runs_played == 0 and profile.xp == xp_before and profile.max_altitude == 2, "Reset statistics keeps progression")

func check_daily_and_codex() -> void:
	var profile = Profile.new()
	check(profile.discover("twin_rope") and not profile.discover("twin_rope") and profile.xp == Progression.XP_DISCOVERY, "A first discovery is worth XP once")
	check(not profile.discover(""), "Empty ids are not discoveries")
	check(profile.start_daily("2026-10-26") and not profile.start_daily("2026-10-26") and profile.start_daily("2026-10-27") and profile.dailies_played == 2, "One Daily Climb per date")
	profile.record_run(77, false, 4, 7, 2, 0, "daily")
	check(profile.daily_floor == 4 and not profile.daily_won, "Daily result stored")
	# The same date gives every player the same run, whatever they unlocked.
	var seed_value: int = Run.mix(int("2026-10-26".replace("-", "")) ^ 0x5eed)
	var a = Run.new(seed_value, {"kind": "daily"})
	var b = Run.new(seed_value, {"kind": "daily"})
	play_to_camp(a)
	play_to_camp(b)
	check(JSON.stringify(a.snapshot()) == JSON.stringify(b.snapshot()) and a.kind == "daily" and a.altitude == 0, "Daily runs are identical for the same date")
	var other = Run.new(Run.mix(int("2026-10-27".replace("-", "")) ^ 0x5eed), {"kind": "daily"})
	check(other.round.seed_initial != a.round.seed_initial, "Another date, another climb")
