extends RefCounted
## Pure round state: no scene, rendering, time, network or filesystem access.
## Integer-only xorshift32 is pinned here so replay RNG never depends on engine RNG.
##
## A Quick Trail round has no talismans and no hazard rules, and plays exactly
## as before. Expedition rounds add a config: equipped talismans (slot order),
## hazard rules from weather/Guardians, and run-wide counters some talismans
## grow. Scoring follows the design's fixed phases: all +Base, then all +Mult,
## then each xMult in slot order, then the perfect-clear multiplier last.

const SIZE = 8
const PLAYING = 0
const WON = 1
const LOST = 2
const MASK32 = 4294967295
## Tile values: 0 empty, 1-5 elements (Sky, Wind, Fire, Water, Earth), then
## hazards. A clear cracks a Stone; a clear on a Cracked Stone removes it.
const STONE = 6
const CRACKED = 7
const MAX_TILE = 7
const ELEMENTS = 5
const MAX_TALISMANS = 9
## Rule keys a round accepts, with their value types and limits.
const RULE_LIMITS = {
	"stones_start": [0, 20], "rockfall": [0, 12], "frost": [0, 12], "min_cells": [0, 5],
	"streak_cap_halves": [0, 20], "tray_delta": [-3, 3], "fixed_disabled": [0, MAX_TALISMANS - 1],
}
const RULE_FLAGS = ["langur", "crow", "golden_hour"]

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
# Round statistics. Optional in saves so older version-1 snapshots still load.
var moves: int = 0
var lines_total: int = 0
var best_move: int = 0
var perfect_count: int = 0
# Expedition configuration (empty for Quick Trail).
var talismans: Array = []
var rules: Dictionary = {}
var reroll_limit: int = 1
var coins: int = 0
# Counters talismans read or grow during the round.
var coins_found: int = 0
var snowball: int = 0
var glacier_lines: int = 0
var clears_this_round: int = 0
var tray_cleared: bool = false
var stones_broken: int = 0
# Rune effects waiting for the next placements.
var echo_next: bool = false
var still_moves: int = 0
## Runes held by the run that can free a blocked board. While one is held, a
## stuck tray does not end the round. Set by the run; not saved here.
var rescue_runes: int = 0

func _init(seed_value: int = 20261024, goal: int = 300, tray_limit: int = 8, config: Dictionary = {}) -> void:
	shapes = make_shapes()
	board.resize(64)
	board.fill(0)
	tray = [{}, {}, {}]
	seed_initial = seed_value & MASK32
	rng_state = seed_initial if seed_initial != 0 else 2463534242
	target = maxi(1, goal)
	max_trays = maxi(1, tray_limit)
	talismans = config.get("talismans", []).duplicate()
	rules = config.get("rules", {}).duplicate()
	reroll_limit = maxi(0, int(config.get("rerolls", 1)))
	rerolls = reroll_limit
	coins = maxi(0, int(config.get("coins", 0)))
	snowball = maxi(0, int(config.get("snowball", 0)))
	glacier_lines = maxi(0, int(config.get("glacier_lines", 0)))
	rescue_runes = maxi(0, int(config.get("rescues", 0)))
	add_stones(int(rules.get("stones_start", 0)))
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
	var min_cells: int = int(rules.get("min_cells", 0))
	if bag.is_empty():
		for i in range(shapes.size()):
			if shapes[i].cells.size() < min_cells:
				continue
			for weight in range(2 if shapes[i].cells.size() <= 3 else 1):
				bag.append(i)
		for i in range(bag.size() - 1, 0, -1):
			var j: int = random_range(i + 1)
			var swap = bag[i]
			bag[i] = bag[j]
			bag[j] = swap
	var shape: int = bag.pop_back()
	if min_cells <= 1 and 64 - board.count(0) > 38 and shapes[shape].cells.size() >= 5 and random_range(2) == 0:
		shape = 0
	return {"shape": shape, "element": random_range(ELEMENTS) + 1}

## Turns `count` random empty cells into Stone. Picks from the list of empty
## cells (a bounded partial shuffle), never by retrying random positions.
func add_stones(count: int) -> void:
	if count <= 0:
		return
	var empty: Array = []
	for index in range(64):
		if int(board[index]) == 0:
			empty.append(index)
	for i in range(mini(count, empty.size())):
		var j: int = i + random_range(empty.size() - i)
		var swap = empty[i]
		empty[i] = empty[j]
		empty[j] = swap
		board[empty[i]] = STONE

func deal(is_reroll: bool) -> void:
	if not is_reroll:
		# Tray-start hazards and talisman shuffles, before the new shards are
		# drawn so the legality check sees them.
		var next_tray: int = trays_dealt + 1
		if int(rules.get("rockfall", 0)) > 0 and (next_tray == 3 or next_tray == 6):
			add_stones(int(rules.rockfall))
		if int(rules.get("frost", 0)) > 0 and next_tray >= 3 and next_tray % 2 == 1:
			add_stones(int(rules.frost))
		if rules.get("crow", false) and next_tray > 1:
			for i in range(talismans.size() - 1, 0, -1):
				var j: int = random_range(i + 1)
				var swap = talismans[i]
				talismans[i] = talismans[j]
				talismans[j] = swap
		tray_cleared = false
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

## Clears every complete row and column at once. Element tiles are removed;
## Stones crack, and Cracked Stones are removed (`ice_axe`: Stones break at
## once). Crossing tiles count once. With `rainbow`, a line holding all five
## elements counts as pure (reported as element 0).
static func clear_lines(tiles: Array, ice_axe: bool = false, rainbow: bool = false) -> Dictionary:
	var marked: Dictionary = {}
	var lines: int = 0
	var pure: Array = []
	for axis in range(2):
		for line in range(8):
			var complete: bool = true
			var is_pure: bool = true
			var first: int = tiles[line * 8 if axis == 0 else line]
			var seen: Dictionary = {}
			for i in range(8):
				var index: int = line * 8 + i if axis == 0 else i * 8 + line
				var tile: int = int(tiles[index])
				if tile == 0:
					complete = false
				if tile != first:
					is_pure = false
				seen[tile] = true
			if not complete:
				continue
			lines += 1
			if is_pure and first >= 1 and first <= ELEMENTS:
				pure.append(first)
			elif rainbow and seen.size() == ELEMENTS and not seen.has(STONE) and not seen.has(CRACKED):
				pure.append(0)
			for i in range(8):
				marked[line * 8 + i if axis == 0 else i * 8 + line] = true
	var cells: Array = marked.keys()
	cells.sort()
	var stones_hit: int = 0
	for index in cells:
		var tile: int = int(tiles[index])
		if tile == STONE:
			stones_hit += 1
			tiles[index] = 0 if ice_axe else CRACKED
		else:
			if tile == CRACKED:
				stones_hit += 1
			tiles[index] = 0
	return {"lines": lines, "removed": marked.size(), "pure": pure, "cells": cells, "stones_hit": stones_hit,
		"perfect": lines > 0 and tiles.count(0) == 64}

## Base x Mult for one placement. `effects` are the active talisman ids in
## slot order; `ctx` carries what some talismans read (see score_context).
## Returns base, mult, points, lines and the ids that changed the result.
static func calculate_score(placed: int, clear: Dictionary, clear_streak: int, effects: Array = [], ctx: Dictionary = {}) -> Dictionary:
	var lines: int = int(clear.lines)
	var pure_count: int = clear.pure.size()
	var triggered: Array = []
	var echo: int = effects.count("echo_valley")
	var pure_weight: int = 1 + echo
	if echo > 0 and pure_count > 0:
		triggered.append("echo_valley")
	# Phase 1: Base.
	var base_value: int = placed + int(clear.removed) * 10 + pure_count * 50 * pure_weight + (200 if clear.perfect else 0)
	for id in effects:
		var add: int = 0
		match id:
			"climbing_rope":
				add = 20 if lines > 0 else 0
			"porters_basket":
				add = 40 if placed >= 5 else 0
			"little_pebble":
				add = 30 if placed == 1 else 0
			"stone_collector":
				add = 15 * int(clear.get("stones_hit", 0))
		if add > 0:
			base_value += add
			triggered.append(id)
	# Phase 2: +Mult.
	var mult: float = 1.0 + maxi(0, lines - 1) + pure_count * pure_weight
	if lines > 0 and not effects.has("hourglass"):
		var step: float = 1.0 if effects.has("momentum") else 0.5
		var cap: float = 3.0 + 2.0 * effects.count("sturdy_boots")
		if ctx.has("streak_cap_halves"):
			cap = minf(cap, 0.5 * int(ctx.streak_cap_halves))
		var bonus: float = minf(cap, maxi(0, clear_streak) * step)
		mult += bonus
		if bonus > 0.0 and (effects.has("momentum") or effects.has("sturdy_boots")):
			for id in ["momentum", "sturdy_boots"]:
				if effects.has(id) and not triggered.has(id):
					triggered.append(id)
	for id in effects:
		var add_mult: float = 0.0
		match id:
			"tea_thermos":
				add_mult = 2.0 if lines > 0 else 0.0
			"sky_feather", "wind_chime", "ember_heart", "river_pearl", "earth_drum":
				add_mult = 4.0 * clear.pure.count(_element_of(id))
			"camp_lantern":
				add_mult = 3.0 if lines > 0 and not ctx.get("tray_cleared", false) else 0.0
			"avalanche":
				add_mult = float(int(ctx.get("round_lines", 0)))
			"minimalists_stone":
				add_mult = 6.0 if int(ctx.get("tiles_left", 64)) <= 10 else 0.0
			"cairn":
				add_mult = float(int(ctx.get("held", effects.size())))
			"snowball":
				add_mult = float(int(ctx.get("snowball", 0)))
		if add_mult > 0.0:
			mult += add_mult
			triggered.append(id)
	# Phase 3: xMult, in slot order.
	for id in effects:
		var factor: float = 1.0
		match id:
			"twin_rope":
				factor = 2.0 if lines >= 2 else 1.0
			"thunderclap":
				factor = 3.0 if lines >= 3 else 1.0
			"snow_leopard_fang":
				factor = pow(1.5, pure_count)
			"golden_yak":
				factor = 1.0 + int(ctx.get("coins", 0)) / 20.0
			"lantern_festival":
				var clears: int = int(ctx.get("clears", 0))
				factor = 4.0 if lines > 0 and clears > 0 and clears % 5 == 0 else 1.0
			"heart_of_mountain":
				factor = 2.0
			"eternal_glacier":
				factor = 1.0 + 0.05 * int(ctx.get("glacier_lines", 0))
		if factor != 1.0:
			mult *= factor
			triggered.append(id)
	# Phase 4: perfect clear, applied last.
	if clear.perfect:
		mult *= 5.0 if effects.has("clean_slate") else 3.0
		if effects.has("clean_slate"):
			triggered.append("clean_slate")
	return {"base": base_value, "mult": mult, "points": floori(base_value * mult), "lines": lines, "triggered": triggered}

static func _element_of(id: String) -> int:
	return {"sky_feather": 1, "wind_chime": 2, "ember_heart": 3, "river_pearl": 4, "earth_drum": 5}.get(id, -1)

## The talismans that act on scoring this tray, in slot order. The Langur
## disables one slot (moving right every tray); Mirror Lake becomes a copy of
## the enabled talisman to its right, or nothing.
func scoring_talismans() -> Array:
	var disabled: int = disabled_slot()
	var fixed: int = fixed_disabled_slot()
	var list: Array = []
	for i in range(talismans.size()):
		if i == disabled or i == fixed:
			continue
		var id: String = talismans[i]
		if id == "mirror_lake":
			var right: int = i + 1
			if right >= talismans.size() or right == disabled or right == fixed or talismans[right] == "mirror_lake":
				continue
			id = talismans[right]
		list.append(id)
	return list

## Slot Altitude 10 disables for the whole round, or -1.
func fixed_disabled_slot() -> int:
	if not rules.has("fixed_disabled") or talismans.is_empty():
		return -1
	return int(rules.fixed_disabled) % talismans.size()

## Slot index the Langur Trickster disables this tray, or -1.
func disabled_slot() -> int:
	if not rules.get("langur", false) or talismans.is_empty():
		return -1
	return (maxi(1, trays_dealt) - 1) % talismans.size()

## Scores placing `piece` at (x, y) on a copy of the board. Shared by the
## preview and the real move, so the preview always equals the commit.
func evaluate(piece: Dictionary, x: int, y: int) -> Dictionary:
	var tiles: Array = board.duplicate()
	var placed: Array = piece_cells(piece, x, y)
	for index in placed:
		tiles[index] = int(piece.element)
	var effects: Array = scoring_talismans()
	var clear: Dictionary = clear_lines(tiles, effects.has("ice_axe"), effects.has("rainbow_scarf"))
	var lines: int = int(clear.lines)
	var keeps_streak: bool = effects.has("storm_crown") or still_moves > 0
	var next_streak: int = streak + 1 if lines > 0 else (streak if keeps_streak else 0)
	var next_snowball: int = snowball + (effects.count("snowball") if lines >= 3 else 0)
	var next_glacier: int = glacier_lines + (lines if effects.has("eternal_glacier") else 0)
	var ctx: Dictionary = {
		"tray_cleared": tray_cleared, "round_lines": lines_total + lines, "tiles_left": 64 - tiles.count(0),
		"held": talismans.size(), "snowball": next_snowball, "coins": coins + coins_found,
		"clears": clears_this_round + (1 if lines > 0 else 0), "glacier_lines": next_glacier,
	}
	if rules.has("streak_cap_halves"):
		ctx.streak_cap_halves = int(rules.streak_cap_halves)
	var result: Dictionary = calculate_score(placed.size(), clear, next_streak if lines > 0 else 0, effects, ctx)
	if echo_next:
		# Rune of Echo: this placement scores twice.
		result.points = int(result.points) * 2
		result.echo = true
	result.tiles = tiles
	result.clear = clear
	result.placed = placed
	result.cleared = clear.cells
	result.next_streak = next_streak
	result.next_snowball = next_snowball
	result.next_glacier = next_glacier
	return result

func preview(piece: Dictionary, x: int, y: int) -> Dictionary:
	if not can_place(piece, x, y):
		return {}
	var result: Dictionary = evaluate(piece, x, y)
	result.erase("tiles")
	result.erase("clear")
	return result

## Board indices a piece would occupy with its bounding-box origin at (x, y).
func piece_cells(piece: Dictionary, x: int, y: int) -> Array:
	var cells: Array = []
	if piece.is_empty():
		return cells
	for cell in shapes[int(piece.shape)].cells:
		cells.append((y + cell.y) * SIZE + x + cell.x)
	return cells

func try_place(slot: int, x: int, y: int) -> Dictionary:
	if status != PLAYING or slot < 0 or slot >= 3 or not can_place(tray[slot], x, y):
		return {"ok": false}
	var piece: Dictionary = tray[slot]
	var result: Dictionary = evaluate(piece, x, y)
	var clear: Dictionary = result.clear
	var before: Array = board
	board = result.tiles
	streak = result.next_streak
	snowball = result.next_snowball
	glacier_lines = result.next_glacier
	score += int(result.points)
	moves += 1
	lines_total += int(clear.lines)
	best_move = maxi(best_move, int(result.points))
	stones_broken += int(clear.stones_hit)
	echo_next = false
	still_moves = maxi(0, still_moves - 1)
	if int(clear.lines) > 0:
		clears_this_round += 1
		tray_cleared = true
	if clear.perfect:
		perfect_count += 1
	var found: int = 0
	if rules.get("golden_hour", false):
		# Coins are rolled after scoring so the preview stays exact.
		for index in clear.cells:
			var tile: int = int(before[index]) if not result.placed.has(index) else int(piece.element)
			if tile >= 1 and tile <= ELEMENTS and random_range(10) == 0:
				found += 1
		coins_found += found
	result.erase("tiles")
	result.erase("clear")
	result.coins_found = found
	result.pure = clear.pure.size()
	result.perfect = clear.perfect
	result.stones_hit = clear.stones_hit
	result.streak = streak
	result.element = int(piece.element)
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
	if not has_legal_move() and rerolls == 0 and rescue_runes == 0:
		status = LOST

## Applies a round rune. `target` is {"axis": "row" or "col", "index": 0-7}
## for Shattering and {"slot": 0-2} for Shrinking. Returns false, changing
## nothing, if the rune cannot act now; the run then keeps the rune.
func use_rune(id: String, target: Dictionary = {}) -> bool:
	if status != PLAYING:
		return false
	match id:
		"rune_time":
			max_trays += 2
		"rune_shatter":
			var index: int = int(target.get("index", -1))
			var axis: String = String(target.get("axis", ""))
			if index < 0 or index >= SIZE or (axis != "row" and axis != "col"):
				return false
			var cells: Array = []
			for i in range(SIZE):
				cells.append(index * SIZE + i if axis == "row" else i * SIZE + index)
			if cells.all(func(c): return int(board[c]) == 0):
				return false
			for c in cells:
				board[c] = 0
		"rune_thaw":
			if not board.has(STONE) and not board.has(CRACKED):
				return false
			for i in range(64):
				if int(board[i]) == STONE or int(board[i]) == CRACKED:
					board[i] = 0
		"rune_echo":
			if echo_next:
				return false
			echo_next = true
		"rune_shrink":
			var slot: int = int(target.get("slot", -1))
			if slot < 0 or slot >= 3 or tray[slot].is_empty() or int(tray[slot].shape) == 0:
				return false
			tray[slot] = {"shape": 0, "element": int(tray[slot].element)}
		"rune_still":
			still_moves = mini(9, still_moves + 3)
		"dye_sky", "dye_wind", "dye_fire", "dye_water", "dye_earth":
			var element: int = {"dye_sky": 1, "dye_wind": 2, "dye_fire": 3, "dye_water": 4, "dye_earth": 5}[id]
			var changed: bool = false
			for slot in range(3):
				if not tray[slot].is_empty() and int(tray[slot].element) != element:
					tray[slot] = {"shape": int(tray[slot].shape), "element": element}
					changed = true
			if not changed:
				return false
		_:
			return false
	return true

func snapshot() -> Dictionary:
	return {"version": 1, "seed": seed_initial, "rng": rng_state, "board": board.duplicate(),
		"tray": tray.duplicate(true), "bag": bag.duplicate(), "score": score, "target": target,
		"max_trays": max_trays, "trays_dealt": trays_dealt, "rerolls": rerolls,
		"streak": streak, "status": status, "moves": moves, "lines_total": lines_total,
		"best_move": best_move, "perfect_count": perfect_count,
		"config": {"talismans": talismans.duplicate(), "rules": rules.duplicate(), "rerolls": reroll_limit, "coins": coins},
		"counters": {"coins_found": coins_found, "snowball": snowball, "glacier_lines": glacier_lines,
			"clears": clears_this_round, "tray_cleared": tray_cleared, "stones_broken": stones_broken,
			"echo": echo_next, "still": still_moves}}

const OPTIONAL_STATS = ["moves", "lines_total", "best_move", "perfect_count"]
const COUNTER_KEYS = ["coins_found", "snowball", "glacier_lines", "clears", "stones_broken", "still"]

static func integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and floor(value) == value and absf(value) <= 9007199254740991.0)

## Validates an expedition config (talismans, rules, rerolls, coins).
static func valid_config(config: Variant) -> bool:
	if not config is Dictionary:
		return false
	var list = config.get("talismans", [])
	if not list is Array or list.size() > MAX_TALISMANS:
		return false
	for id in list:
		if not id is String or not _known_talisman(id):
			return false
	var rule_set = config.get("rules", {})
	if not rule_set is Dictionary:
		return false
	for key in rule_set:
		if RULE_LIMITS.has(key):
			var limits: Array = RULE_LIMITS[key]
			if not integer_number(rule_set[key]) or int(rule_set[key]) < limits[0] or int(rule_set[key]) > limits[1]:
				return false
		elif RULE_FLAGS.has(key):
			if not rule_set[key] is bool:
				return false
		else:
			return false
	for key in ["rerolls", "coins"]:
		if config.has(key) and (not integer_number(config[key]) or int(config[key]) < 0 or int(config[key]) > 100000):
			return false
	return true

static func _known_talisman(id: String) -> bool:
	return load("res://scripts/content/talismans.gd").exists(id)

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
	var config = data.get("config", {})
	if not valid_config(config):
		return false
	var limit: int = int(config.get("rerolls", 1))
	if int(data.rerolls) < 0 or int(data.rerolls) > limit or int(data.streak) < 0 or int(data.status) < 0 or int(data.status) > 2:
		return false
	if (int(data.status) == WON) != (int(data.score) >= int(data.target)):
		return false
	for tile in data.board:
		if not integer_number(tile) or int(tile) < 0 or int(tile) > MAX_TILE:
			return false
	for piece in data.tray:
		if not piece is Dictionary:
			return false
		if not piece.is_empty() and (not piece.has_all(["shape", "element"]) or not integer_number(piece.shape) or not integer_number(piece.element) or int(piece.shape) < 0 or int(piece.shape) >= 19 or int(piece.element) < 1 or int(piece.element) > ELEMENTS):
			return false
	for index in data.bag:
		if not integer_number(index) or int(index) < 0 or int(index) >= 19:
			return false
	if int(data.status) == PLAYING and data.tray[0].is_empty() and data.tray[1].is_empty() and data.tray[2].is_empty():
		return false
	# Statistics were added after the first saves shipped. Missing keys default
	# to zero; present keys must still be valid non-negative integers.
	for key in OPTIONAL_STATS:
		if data.has(key) and (not integer_number(data[key]) or int(data[key]) < 0):
			return false
	var counters = data.get("counters", {})
	if not counters is Dictionary:
		return false
	for key in COUNTER_KEYS:
		if counters.has(key) and (not integer_number(counters[key]) or int(counters[key]) < 0):
			return false
	if counters.has("tray_cleared") and not counters.tray_cleared is bool:
		return false
	if counters.has("echo") and not counters.echo is bool:
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
	moves = int(data.get("moves", 0))
	lines_total = int(data.get("lines_total", 0))
	best_move = int(data.get("best_move", 0))
	perfect_count = int(data.get("perfect_count", 0))
	talismans = []
	for id in config.get("talismans", []):
		talismans.append(String(id))
	rules = {}
	var rule_set: Dictionary = config.get("rules", {})
	for key in rule_set:
		rules[key] = rule_set[key] if rule_set[key] is bool else int(rule_set[key])
	reroll_limit = limit
	coins = int(config.get("coins", 0))
	coins_found = int(counters.get("coins_found", 0))
	snowball = int(counters.get("snowball", 0))
	glacier_lines = int(counters.get("glacier_lines", 0))
	clears_this_round = int(counters.get("clears", 0))
	tray_cleared = counters.get("tray_cleared", false)
	stones_broken = int(counters.get("stones_broken", 0))
	echo_next = counters.get("echo", false)
	still_moves = int(counters.get("still", 0))
	return true
