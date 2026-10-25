extends SceneTree

const Model = preload("res://scripts/round_model.gd")
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
	for seed_value in range(1000):
		model = Model.new(seed_value)
		var actions: int = 0
		while model.status == Model.PLAYING and actions < 30:
			move = first_move(model)
			if move.is_empty():
				model.try_reroll()
			else:
				model.try_place(move[0], move[1], move[2])
			actions += 1
		check(model.status != Model.PLAYING and actions <= 25, "Seed %d terminates within tray budget" % seed_value)
		if model.status == Model.WON:
			wins += 1
	print("RULES: %d checks, %d failures; 1000 first-fit seeded rounds, %d wins" % [checks, failures, wins])
	quit(0 if failures == 0 else 1)
