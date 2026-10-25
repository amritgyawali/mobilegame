extends RefCounted
## Pure round state: no scene, rendering, time, network or filesystem access.
## Integer-only xorshift32 is pinned here so replay RNG never depends on engine RNG.

const SIZE = 8
const PLAYING = 0
const WON = 1
const LOST = 2
const MASK32 = 4294967295

var shapes: Array = []
var board: Array = []
var tray: Array = []
var bag: Array = []
var seed_initial: int
var rng_state: int
var score: int = 0
var target: int = 300
var max_trays: int = 8
var trays_dealt: int = 0
var rerolls: int = 1
var streak: int = 0
var status: int = PLAYING

func _init(seed_value: int = 20261024, goal: int = 300, tray_limit: int = 8) -> void:
	shapes = make_shapes()
	board.resize(64)
	board.fill(0)
	tray = [{}, {}, {}]
	seed_initial = seed_value & MASK32
	rng_state = seed_initial if seed_initial != 0 else 2463534242
	target = maxi(1, goal)
	max_trays = maxi(1, tray_limit)
	deal(false)

static func make_shapes() -> Array:
	var result: Array = [{"id": "dot", "cells": [Vector2i(0, 0)]}]
	for length in range(2, 6):
		var horizontal: Array = []
		var vertical: Array = []
		for i in range(length):
			horizontal.append(Vector2i(i, 0))
			vertical.append(Vector2i(0, i))
		result.append({"id": "bar_%d_h" % length, "cells": horizontal})
		result.append({"id": "bar_%d_v" % length, "cells": vertical})
	for shape_data in [
		["corner", [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]],
		["big_l", [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3)]]
	]:
		var cells: Array = shape_data[1]
		for rotation in range(4):
			result.append({"id": "%s_%d" % [shape_data[0], rotation], "cells": cells})
			var max_y: int = 0
			for cell in cells:
				max_y = maxi(max_y, cell.y)
			var rotated: Array = []
			for cell in cells:
				rotated.append(Vector2i(max_y - cell.y, cell.x))
			cells = rotated
	for side in [2, 3]:
		var cells: Array = []
		for y in range(side):
			for x in range(side):
				cells.append(Vector2i(x, y))
		result.append({"id": "square_%d" % side, "cells": cells})
	return result

func next_random() -> int:
	rng_state = (rng_state ^ (rng_state << 13)) & MASK32
	rng_state = (rng_state ^ (rng_state >> 17)) & MASK32
	rng_state = (rng_state ^ (rng_state << 5)) & MASK32
	return rng_state

func random_range(bound: int) -> int:
	assert(bound > 0)
	# Rejection sampling removes modulo bias over the nonzero xorshift cycle.
	var limit: int = MASK32 - (MASK32 % bound)
	var value: int = next_random() - 1
	while value >= limit:
		value = next_random() - 1
	return value % bound

func can_place(piece: Dictionary, x: int, y: int, tiles: Array = []) -> bool:
	if piece.is_empty() or x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return false
	var working: Array = board if tiles.is_empty() else tiles
	for cell in shapes[int(piece.shape)].cells:
		var px: int = x + cell.x
		var py: int = y + cell.y
		if px >= SIZE or py >= SIZE or int(working[py * SIZE + px]) != 0:
			return false
	return true

func fits_anywhere(piece: Dictionary) -> bool:
	for y in range(SIZE):
		for x in range(SIZE):
			if can_place(piece, x, y):
				return true
	return false

func has_legal_move() -> bool:
	for piece in tray:
		if not piece.is_empty() and fits_anywhere(piece):
			return true
	return false

func draw_piece() -> Dictionary:
	if bag.is_empty():
		for i in range(shapes.size()):
			for weight in range(2 if shapes[i].cells.size() <= 3 else 1):
				bag.append(i)
		for i in range(bag.size() - 1, 0, -1):
			var j: int = random_range(i + 1)
			var swap = bag[i]
			bag[i] = bag[j]
			bag[j] = swap
	var shape: int = bag.pop_back()
	if 64 - board.count(0) > 38 and shapes[shape].cells.size() >= 5 and random_range(2) == 0:
		shape = 0
	return {"shape": shape, "element": random_range(5) + 1}

func deal(is_reroll: bool) -> void:
	var replace: Array = []
	for i in range(3):
		replace.append(not is_reroll or not tray[i].is_empty())
	for attempt in range(4):
		for i in range(3):
			if replace[i]:
				tray[i] = draw_piece()
		if has_legal_move():
			break
	if not is_reroll:
		trays_dealt += 1
	update_blocked()

static func clear_lines(tiles: Array) -> Dictionary:
	var marked: Dictionary = {}
	var lines: int = 0
	var pure: Array = []
	for axis in range(2):
		for line in range(8):
			var complete: bool = true
			var is_pure: bool = true
			var first: int = tiles[line * 8 if axis == 0 else line]
			for i in range(8):
				var index: int = line * 8 + i if axis == 0 else i * 8 + line
				if int(tiles[index]) == 0:
					complete = false
				if int(tiles[index]) != first:
					is_pure = false
			if not complete:
				continue
			lines += 1
			if is_pure:
				pure.append(first)
			for i in range(8):
				marked[line * 8 + i if axis == 0 else i * 8 + line] = true
	for index in marked:
		tiles[index] = 0
	return {"lines": lines, "removed": marked.size(), "pure": pure,
		"perfect": lines > 0 and tiles.count(0) == 64}

static func calculate_score(placed: int, clear: Dictionary, clear_streak: int, effects: Array = []) -> Dictionary:
	var base_value: int = placed + int(clear.removed) * 10 + clear.pure.size() * 50 + (200 if clear.perfect else 0)
	var mult: float = 1.0 + maxi(0, int(clear.lines) - 1) + clear.pure.size()
	if clear.lines > 0:
		mult += mini(6, maxi(0, clear_streak)) * 0.5
	for effect in effects:
		if effect == "ember_heart":
			mult += clear.pure.count(3) * 4
	for effect in effects:
		if effect == "twin_rope" and clear.lines > 1:
			mult *= 2
	if clear.perfect:
		mult *= 3
	return {"base": base_value, "mult": mult, "points": floori(base_value * mult), "lines": clear.lines}

func preview(piece: Dictionary, x: int, y: int) -> Dictionary:
	if not can_place(piece, x, y):
		return {}
	var tiles: Array = board.duplicate()
	for cell in shapes[int(piece.shape)].cells:
		tiles[(y + cell.y) * 8 + x + cell.x] = int(piece.element)
	var clear: Dictionary = clear_lines(tiles)
	return calculate_score(shapes[int(piece.shape)].cells.size(), clear, streak + 1 if clear.lines > 0 else 0)

func try_place(slot: int, x: int, y: int) -> Dictionary:
	if status != PLAYING or slot < 0 or slot >= 3 or not can_place(tray[slot], x, y):
		return {"ok": false}
	var piece: Dictionary = tray[slot]
	for cell in shapes[int(piece.shape)].cells:
		board[(y + cell.y) * 8 + x + cell.x] = int(piece.element)
	var clear: Dictionary = clear_lines(board)
	streak = streak + 1 if clear.lines > 0 else 0
	var result: Dictionary = calculate_score(shapes[int(piece.shape)].cells.size(), clear, streak)
	score += int(result.points)
	tray[slot] = {}
	if score >= target:
		status = WON
	elif tray[0].is_empty() and tray[1].is_empty() and tray[2].is_empty():
		if trays_dealt >= max_trays:
			status = LOST
		else:
			deal(false)
	else:
		update_blocked()
	result.ok = true
	return result

func try_reroll() -> bool:
	if status != PLAYING or rerolls == 0:
		return false
	rerolls -= 1
	deal(true)
	return true

func update_blocked() -> void:
	if not has_legal_move() and rerolls == 0:
		status = LOST

func snapshot() -> Dictionary:
	return {"version": 1, "seed": seed_initial, "rng": rng_state, "board": board.duplicate(),
		"tray": tray.duplicate(true), "bag": bag.duplicate(), "score": score, "target": target,
		"max_trays": max_trays, "trays_dealt": trays_dealt, "rerolls": rerolls,
		"streak": streak, "status": status}

static func integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and floor(value) == value and absf(value) <= 9007199254740991.0)

func restore_snapshot(data: Dictionary) -> bool:
	for key in ["version", "seed", "rng", "board", "tray", "bag", "score", "target", "max_trays", "trays_dealt", "rerolls", "streak", "status"]:
		if not data.has(key):
			return false
	for key in ["version", "seed", "rng", "score", "target", "max_trays", "trays_dealt", "rerolls", "streak", "status"]:
		if not integer_number(data[key]):
			return false
	if int(data.version) != 1 or not data.board is Array or data.board.size() != 64:
		return false
	if not data.tray is Array or data.tray.size() != 3 or not data.bag is Array or data.bag.size() > 64:
		return false
	if int(data.rng) <= 0 or int(data.rng) > MASK32 or int(data.target) <= 0 or int(data.score) < 0:
		return false
	if int(data.seed) < 0 or int(data.seed) > MASK32:
		return false
	if int(data.max_trays) < 1 or int(data.trays_dealt) < 1 or int(data.trays_dealt) > int(data.max_trays):
		return false
	if int(data.rerolls) < 0 or int(data.rerolls) > 1 or int(data.streak) < 0 or int(data.status) < 0 or int(data.status) > 2:
		return false
	if (int(data.status) == WON) != (int(data.score) >= int(data.target)):
		return false
	for tile in data.board:
		if not integer_number(tile) or int(tile) < 0 or int(tile) > 5:
			return false
	for piece in data.tray:
		if not piece is Dictionary:
			return false
		if not piece.is_empty() and (not piece.has_all(["shape", "element"]) or not integer_number(piece.shape) or not integer_number(piece.element) or int(piece.shape) < 0 or int(piece.shape) >= 19 or int(piece.element) < 1 or int(piece.element) > 5):
			return false
	for index in data.bag:
		if not integer_number(index) or int(index) < 0 or int(index) >= 19:
			return false
	if int(data.status) == PLAYING and data.tray[0].is_empty() and data.tray[1].is_empty() and data.tray[2].is_empty():
		return false
	seed_initial = int(data.seed)
	rng_state = int(data.rng)
	# JSON numbers are floats. Normalize them so a restored snapshot has the
	# same representation and integer-only RNG bag as an uninterrupted run.
	board = []
	for tile in data.board:
		board.append(int(tile))
	tray = []
	for piece in data.tray:
		tray.append({} if piece.is_empty() else {"shape": int(piece.shape), "element": int(piece.element)})
	bag = []
	for index in data.bag:
		bag.append(int(index))
	score = int(data.score)
	target = int(data.target)
	max_trays = int(data.max_trays)
	trays_dealt = int(data.trays_dealt)
	rerolls = int(data.rerolls)
	streak = int(data.streak)
	status = int(data.status)
	return true
