extends SceneTree

const Model = preload("res://scripts/round_model.gd")
const Profile = preload("res://scripts/profile_model.gd")
const Settings = preload("res://scripts/settings_model.gd")
const Store = preload("res://scripts/persistence/json_store.gd")
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func first_move(model: RefCounted) -> Array:
	for slot in range(3):
		for y in range(8):
			for x in range(8):
				if model.can_place(model.tray[slot], x, y):
					return [slot, x, y]
	return []

func run() -> void:
	var model = Model.new(42)
	check(model.shapes.size() == 19, "Exactly 19 shapes")
	var unique: Dictionary = {}
	for shape in model.shapes:
		var cells: Dictionary = {}
		for cell in shape.cells:
			check(cell.x >= 0 and cell.y >= 0, "Nonnegative shape origin")
			cells[cell] = true
		check(cells.size() == shape.cells.size(), "No duplicate shape cells")
		unique[shape.id] = true
	check(unique.size() == 19, "Unique shape identifiers")
	model.rng_state = 1
	for expected in [270369, 67634689, 2647435461, 307599695, 2398689233]:
		check(model.next_random() == expected, "Pinned xorshift32 reference sequence")
	check(not model.can_place({"shape": 0, "element": 1}, -1, 0), "Reject negative position")
	check(not model.can_place({"shape": 0, "element": 1}, 2147483647, 0), "Reject huge position")
	var before = JSON.stringify(model.snapshot())
	check(not model.try_place(0, 8, 0).ok and JSON.stringify(model.snapshot()) == before, "Invalid placement is atomic")
	var tiles: Array = []
	tiles.resize(64)
	tiles.fill(0)
	for i in range(8):
		tiles[i] = 3
		tiles[i * 8] = 3
	tiles[63] = 1
	var clear: Dictionary = Model.clear_lines(tiles)
	check(clear.lines == 2 and clear.removed == 15 and clear.pure.size() == 2, "Crossing lines count 15 unique tiles")
	check(tiles[63] == 1 and tiles[55] == 0, "No gravity")
	check(clear.cells.size() == 15 and clear.cells == [0, 1, 2, 3, 4, 5, 6, 7, 8, 16, 24, 32, 40, 48, 56], "Cleared cells listed once, sorted")
	var worked = Model.calculate_score(4, {"removed": 16, "pure": [3], "lines": 2, "perfect": false}, 1, ["twin_rope", "ember_heart"])
	check(worked.base == 214 and worked.mult == 15 and worked.points == 3210, "Grouped add/multiply effects")
	# The design's worked example uses a three-step streak (+1.5 Mult).
	var gdd = Model.calculate_score(4, {"removed": 16, "pure": [3], "lines": 2, "perfect": false}, 3, ["ember_heart", "twin_rope"])
	check(gdd.base == 214 and gdd.mult == 17 and gdd.points == 3638, "GDD 214 x 17 worked score")
	var perfect = Model.calculate_score(1, {"removed": 8, "pure": [1], "lines": 1, "perfect": true}, 1)
	check(perfect.base == 331 and perfect.mult == 7.5 and perfect.points == 2482, "Perfect clear is last; floor final score")
	var capped = Model.calculate_score(1, {"removed": 8, "pure": [], "lines": 1, "perfect": false}, 99)
	check(capped.mult == 4, "Streak bonus capped at 3")
	model = Model.new(99)
	var move = first_move(model)
	model.try_place(move[0], move[1], move[2])
	var used_slot: int = move[0]
	check(model.try_reroll() and model.tray[used_slot].is_empty() and model.trays_dealt == 1, "Reroll preserves used slots and tray budget")
	check(not model.try_reroll(), "One reroll per round")
	var restored = Model.new(1)
	check(restored.restore_snapshot(JSON.parse_string(JSON.stringify(model.snapshot()))), "JSON save round trip")
	for step in range(30):
		check(JSON.stringify(model.snapshot()) == JSON.stringify(restored.snapshot()), "Restored deterministic continuation")
		if model.status != Model.PLAYING:
			break
		move = first_move(model)
		if move.is_empty():
			model.try_reroll()
			restored.try_reroll()
		else:
			model.try_place(move[0], move[1], move[2])
			restored.try_place(move[0], move[1], move[2])
	var malformed: Dictionary = model.snapshot()
	malformed.board = [6]
	check(not restored.restore_snapshot(malformed), "Malformed save rejected")
	var prior: String = JSON.stringify(restored.snapshot())
	for bad_value in ["3", null, true, 2.5, {}]:
		malformed = model.snapshot()
		malformed.board[0] = bad_value
		check(not restored.restore_snapshot(malformed) and JSON.stringify(restored.snapshot()) == prior, "Invalid cell type rejected atomically")
	malformed = Model.new().snapshot()
	malformed.tray = [{}, {}, {}]
	check(not restored.restore_snapshot(malformed), "Impossible playing round with empty tray rejected")
	var wins: int = 0
	var preview_mismatches: int = 0
	var stat_mismatches: int = 0
	for seed_value in range(1000):
		model = Model.new(seed_value)
		var actions: int = 0
		var lines_seen: int = 0
		var best_seen: int = 0
		while model.status == Model.PLAYING and actions < 30:
			move = first_move(model)
			if move.is_empty():
				model.try_reroll()
			else:
				var piece: Dictionary = model.tray[move[0]]
				var expected: Dictionary = model.preview(piece, move[1], move[2])
				var cells: Array = model.piece_cells(piece, move[1], move[2])
				var result: Dictionary = model.try_place(move[0], move[1], move[2])
				if result.points != expected.points or result.cleared != expected.cleared or result.placed != cells:
					preview_mismatches += 1
				lines_seen += int(result.lines)
				best_seen = maxi(best_seen, int(result.points))
			actions += 1
		if model.lines_total != lines_seen or model.best_move != best_seen:
			stat_mismatches += 1
		check(model.status != Model.PLAYING and actions <= 25, "Seed %d terminates within tray budget" % seed_value)
		if model.status == Model.WON:
			wins += 1
	check(preview_mismatches == 0, "Preview equals the committed points and cells on every seeded move")
	check(stat_mismatches == 0, "Round statistics match the moves played")
	check_saves_and_profile()
	print("RULES: %d checks, %d failures; 1000 first-fit seeded rounds, %d wins" % [checks, failures, wins])
	quit(0 if failures == 0 else 1)

func check_saves_and_profile() -> void:
	# Saves written before statistics existed still load, with zero stats.
	var model = Model.new(7)
	var move: Array = first_move(model)
	model.try_place(move[0], move[1], move[2])
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	for key in Model.OPTIONAL_STATS:
		legacy.erase(key)
	var restored = Model.new(1)
	check(restored.restore_snapshot(legacy) and restored.moves == 0 and restored.score == model.score, "Pre-statistics save loads")
	var with_stats: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(restored.restore_snapshot(with_stats) and restored.moves == 1 and restored.best_move == model.best_move, "Statistics round trip")
	var prior: String = JSON.stringify(restored.snapshot())
	for bad in [-1, 2.5, "3", null]:
		var damaged: Dictionary = model.snapshot()
		damaged.moves = bad
		check(not restored.restore_snapshot(damaged) and JSON.stringify(restored.snapshot()) == prior, "Invalid statistic rejected atomically")

	# Profile: each round counts once; streaks; damaged data is sanitised.
	var profile = Profile.new()
	check(profile.record_round(11, true, 420, 3, 0, 200).new_best, "First win is a new best")
	check(profile.record_round(11, true, 420, 3, 0, 200).is_empty() and profile.rounds_played == 1, "Same round never counts twice")
	profile.record_round(12, true, 310, 2, 1, 150)
	check(profile.win_streak == 2 and profile.best_win_streak == 2 and profile.best_score == 420, "Win streak and best altitude")
	check(not profile.record_round(13, false, 90, 1, 0, 40).new_best and profile.win_streak == 0 and profile.best_win_streak == 2, "A loss ends the streak")
	check(profile.rounds_played == 3 and profile.rounds_won == 2 and profile.lines_cleared == 6 and profile.perfect_clears == 1 and profile.win_rate() == 67, "Totals add up")
	var copy = Profile.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	check(copy.to_dict() == profile.to_dict(), "Profile round trip")
	copy.from_dict({"best_score": -5, "rounds_played": "lots", "rounds_won": 9, "win_streak": INF, "seen_tutorial": "yes", "last_round_id": null})
	check(copy.best_score == 0 and copy.rounds_played == 0 and copy.rounds_won == 0 and not copy.seen_tutorial and copy.last_round_id == -1, "Damaged profile values reset safely")
	profile.seen_tutorial = true
	profile.reset()
	check(profile.rounds_played == 0 and profile.best_score == 0 and profile.seen_tutorial, "Reset keeps the tutorial flag")

	# Settings: defaults for anything missing or of the wrong type.
	var settings = Settings.new()
	settings.from_dict({"sound": false, "reduced_motion": "on", "battery_saver": 1, "unknown": true})
	check(not settings.get_value("sound") and not settings.get_value("reduced_motion") and not settings.get_value("battery_saver") and settings.get_value("clear_preview"), "Settings validate types")
	check(not settings.to_dict().has("unknown"), "Unknown settings dropped")

	# Store: checksummed writes, backup fallback and damage rejection.
	var path: String = "user://automated-store-test.json"
	Store.remove(path)
	check(Store.read(path).is_empty(), "Missing document reads empty")
	check(Store.write(path, {"a": 1}) and Store.write(path, {"a": 2}) and int(Store.read(path).a) == 2, "Latest document wins")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	check(int(Store.read(path).get("a", 0)) == 1, "Damaged primary falls back to the previous write")
	var tampered: String = FileAccess.get_file_as_string(path + ".bak").replace("1", "9")
	file = FileAccess.open(path + ".bak", FileAccess.WRITE)
	file.store_string(tampered)
	file.close()
	check(Store.read(path).is_empty(), "Checksum mismatch rejected")
	Store.remove(path)
