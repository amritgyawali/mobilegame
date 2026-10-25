extends SceneTree
## Expedition rules: talisman scoring, Stones, hazards, Camp economy, Firebird,
## the summit, deterministic seeds and save/restore. Pure models only.

const Model = preload("res://scripts/round_model.gd")
const Run = preload("res://scripts/run_model.gd")
const Talismans = preload("res://scripts/content/talismans.gd")
const Encounters = preload("res://scripts/content/encounters.gd")
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_all")

func clear(lines: int, removed: int = 8, pure: Array = [], perfect: bool = false, stones: int = 0) -> Dictionary:
	return {"lines": lines, "removed": removed, "pure": pure, "perfect": perfect, "stones_hit": stones}

func score(effects: Array, c: Dictionary, streak: int = 0, ctx: Dictionary = {}, placed: int = 4) -> Dictionary:
	return Model.calculate_score(placed, c, streak, effects, ctx)

func first_move(round) -> Array:
	for slot in range(3):
		for y in range(8):
			for x in range(8):
				if round.can_place(round.tray[slot], x, y):
					return [slot, x, y]
	return []

## Plays one move (or a reroll) of the current round, first-fit.
func step(run) -> void:
	var move: Array = first_move(run.round)
	if move.is_empty():
		run.round.try_reroll()
	else:
		run.round.try_place(move[0], move[1], move[2])
	run.after_round_command()

## Plays rounds until the run reaches Camp, ends, or `limit` actions pass.
func play_to_camp(run, limit: int = 400) -> void:
	for i in range(limit):
		if run.phase == Run.INTRO:
			run.begin()
		elif run.phase == Run.ROUND:
			step(run)
		else:
			return

func run_all() -> void:
	check_scoring()
	check_tiles_and_rules()
	check_round_invariants()
	check_run()
	check_camp()
	check_saves()
	print("RUN: %d expedition checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check_scoring() -> void:
	var base: Dictionary = score([], clear(1))
	check(base.base == 84 and base.mult == 1.0, "No talismans: 4 + 80 Base, x1")
	check(score(["climbing_rope"], clear(1)).base == 104 and score(["climbing_rope"], clear(0, 0)).base == 4, "Climbing Rope adds Base only on clears")
	check(score(["tea_thermos"], clear(1)).mult == 3.0 and score(["tea_thermos"], clear(0, 0)).mult == 1.0, "Tea Thermos +2 Mult on clears")
	for id in Talismans.ELEMENT_BONUS:
		var element: int = Talismans.ELEMENT_BONUS[id]
		var other: int = 1 + element % 5
		check(score([id], clear(1, 8, [element])).mult == 6.0 and score([id], clear(1, 8, [other])).mult == 2.0, "%s counts only its element" % id)
	check(score(["porters_basket"], clear(0, 0), 0, {}, 5).base == 45 and score(["porters_basket"], clear(0, 0), 0, {}, 4).base == 4, "Porter's Basket on 5+ cells")
	check(score(["little_pebble"], clear(0, 0), 0, {}, 1).base == 31, "Little Pebble on 1-cell shards")
	check(score(["stone_collector"], clear(1, 8, [], false, 2)).base == 114, "Stone Collector +15 per Stone hit")
	check(score([], clear(1), 99).mult == 4.0 and score(["sturdy_boots"], clear(1), 99).mult == 6.0, "Sturdy Boots raise the streak cap to +5")
	check(score(["momentum"], clear(1), 2).mult == 3.0 and score([], clear(1), 2).mult == 2.0, "Momentum doubles each streak step")
	check(score(["hourglass"], clear(1), 4).mult == 1.0, "Hourglass removes the streak bonus")
	check(score([], clear(1), 4, {"streak_cap_halves": 1}).mult == 1.5, "Thunder Kite caps the streak at +0.5")
	check(score(["camp_lantern"], clear(1), 0, {"tray_cleared": false}).mult == 4.0 and score(["camp_lantern"], clear(1), 0, {"tray_cleared": true}).mult == 1.0, "Camp Lantern: first clear of a tray")
	check(score(["avalanche"], clear(1), 0, {"round_lines": 5}).mult == 6.0, "Avalanche +1 per line this round")
	check(score(["minimalists_stone"], clear(0, 0), 0, {"tiles_left": 10}).mult == 7.0 and score(["minimalists_stone"], clear(0, 0), 0, {"tiles_left": 11}).mult == 1.0, "Minimalist's Stone at 10 tiles or fewer")
	check(score(["cairn"], clear(0, 0), 0, {"held": 4}).mult == 5.0, "Cairn +1 per held talisman")
	check(score(["snowball"], clear(0, 0), 0, {"snowball": 3}).mult == 4.0, "Snowball adds its stacks")
	var echo: Dictionary = score(["echo_valley"], clear(1, 8, [2]))
	check(echo.base == 184 and echo.mult == 3.0, "Echo Valley counts pure bonuses twice")
	check(score(["twin_rope"], clear(2, 15)).mult == 4.0 and score(["twin_rope"], clear(1)).mult == 1.0, "Twin Rope x2 on 2+ lines")
	check(score(["thunderclap"], clear(3, 22)).mult == 9.0 and score(["thunderclap"], clear(2, 15)).mult == 2.0, "Thunderclap x3 on 3+ lines")
	check(is_equal_approx(score(["snow_leopard_fang"], clear(2, 15, [1, 1])).mult, 4.0 * 2.25), "Snow Leopard's Fang x1.5 per pure line")
	check(score(["golden_yak"], clear(1), 0, {"coins": 30}).mult == 2.5, "Golden Yak x(1 + coins/20)")
	check(score(["lantern_festival"], clear(1), 0, {"clears": 5}).mult == 4.0 and score(["lantern_festival"], clear(1), 0, {"clears": 4}).mult == 1.0, "Lantern Festival on every 5th clear")
	check(score(["heart_of_mountain"], clear(0, 0)).mult == 2.0, "Heart of the Mountain x2 always")
	check(is_equal_approx(score(["eternal_glacier"], clear(1), 0, {"glacier_lines": 10}).mult, 1.5), "Eternal Glacier x(1 + 0.05 per line)")
	check(score(["clean_slate"], clear(1, 8, [], true)).mult == 5.0 and score([], clear(1, 8, [], true)).mult == 3.0, "Clean Slate: perfect clears x5")
	# Phases: all +Mult before any xMult, whatever the slot order.
	var a: Dictionary = score(["twin_rope", "tea_thermos"], clear(2, 15))
	var b: Dictionary = score(["tea_thermos", "twin_rope"], clear(2, 15))
	check(a.mult == 8.0 and b.mult == 8.0, "Additive phase precedes multipliers regardless of order")
	check(a.triggered.has("twin_rope") and a.triggered.has("tea_thermos") and not score(["twin_rope"], clear(1)).triggered.has("twin_rope"), "Triggered talismans are reported")
	# The design's worked example still holds through the full pipeline.
	var gdd: Dictionary = score(["ember_heart", "twin_rope"], {"removed": 16, "pure": [3], "lines": 2, "perfect": false}, 3)
	check(gdd.base == 214 and gdd.mult == 17.0 and gdd.points == 3638, "GDD 214 x 17 = 3,638")

func board_with(rows: Dictionary) -> Array:
	var tiles: Array = []
	tiles.resize(64)
	tiles.fill(0)
	for row in rows:
		for x in range(8):
			tiles[row * 8 + x] = rows[row][x]
	return tiles

func check_tiles_and_rules() -> void:
	var tiles: Array = board_with({0: [6, 1, 1, 1, 1, 1, 1, 7]})
	var result: Dictionary = Model.clear_lines(tiles)
	check(result.lines == 1 and result.stones_hit == 2 and result.pure.is_empty(), "Stones complete a line, never a pure one")
	check(tiles[0] == Model.CRACKED and tiles[7] == 0 and tiles[1] == 0, "Clear cracks Stone and breaks Cracked Stone")
	check(not result.perfect, "A cracked Stone left behind is not a perfect clear")
	tiles = board_with({0: [6, 1, 1, 1, 1, 1, 1, 1]})
	Model.clear_lines(tiles, true)
	check(tiles[0] == 0, "Ice Axe breaks Stone in one clear")
	tiles = board_with({0: [1, 2, 3, 4, 5, 1, 2, 3]})
	check(Model.clear_lines(tiles.duplicate()).pure.is_empty() and Model.clear_lines(tiles, false, true).pure == [0], "Rainbow Scarf: all five elements count as pure")
	# Hazards set up by rules.
	var stony = Model.new(77, 300, 8, {"rules": {"stones_start": 6}})
	check(stony.board.count(Model.STONE) == 6, "Stone Yak: 6 Stones at the start")
	check(JSON.stringify(Model.new(77, 300, 8, {"rules": {"stones_start": 6}}).snapshot()) == JSON.stringify(stony.snapshot()), "Stones are seeded")
	var bear = Model.new(5, 99999, 30, {"rules": {"min_cells": 4}})
	var small: int = 0
	for n in range(40):
		for piece in bear.tray:
			if not piece.is_empty() and bear.shapes[int(piece.shape)].cells.size() < 4:
				small += 1
		bear.try_reroll()
		bear.rerolls = 1
		bear.status = Model.PLAYING
	check(small == 0, "Moon Bear: no shards under 4 cells")
	var rocky = Model.new(9, 99999, 8, {"rules": {"rockfall": 3}})
	var stones_by_tray: Dictionary = {}
	for i in range(200):
		if rocky.status != Model.PLAYING:
			break
		stones_by_tray[rocky.trays_dealt] = rocky.board.count(Model.STONE) + rocky.board.count(Model.CRACKED)
		var move: Array = first_move(rocky)
		if move.is_empty():
			break
		rocky.try_place(move[0], move[1], move[2])
	check(stones_by_tray.get(1, -1) == 0 and stones_by_tray.get(3, 0) >= 1, "Rockfall: Stones arrive at tray 3")
	var langur = Model.new(3, 300, 8, {"talismans": ["climbing_rope", "tea_thermos", "cairn"], "rules": {"langur": true}})
	check(langur.disabled_slot() == 0 and langur.scoring_talismans() == ["tea_thermos", "cairn"], "Langur disables the first slot on tray 1")
	langur.trays_dealt = 2
	check(langur.disabled_slot() == 1 and langur.scoring_talismans() == ["climbing_rope", "cairn"], "Langur moves one slot right each tray")
	var mirror = Model.new(3, 300, 8, {"talismans": ["mirror_lake", "twin_rope", "mirror_lake"]})
	check(mirror.scoring_talismans() == ["twin_rope", "twin_rope"], "Mirror Lake copies its right neighbour; at the end it copies nothing")
	var crow = Model.new(11, 99999, 8, {"talismans": ["climbing_rope", "tea_thermos", "cairn", "twin_rope", "avalanche"], "rules": {"crow": true}})
	var orders: Dictionary = {}
	for i in range(80):
		orders[str(crow.talismans)] = true
		var move: Array = first_move(crow)
		if move.is_empty() or crow.status != Model.PLAYING:
			break
		crow.try_place(move[0], move[1], move[2])
	check(orders.size() > 1 and crow.talismans.size() == 5, "Crow shuffles the talisman order between trays")
	# On an empty board the first move cannot clear a line.
	var crowned = Model.new(1, 99999, 8, {"talismans": ["storm_crown"]})
	var plain = Model.new(1, 99999, 8)
	crowned.streak = 3
	plain.streak = 3
	var no_clear: Array = first_move(crowned)
	crowned.try_place(no_clear[0], no_clear[1], no_clear[2])
	plain.try_place(no_clear[0], no_clear[1], no_clear[2])
	check(crowned.lines_total == 0 and crowned.streak == 3 and plain.streak == 0, "Storm Crown keeps the streak through a non-clearing move")

func check_round_invariants() -> void:
	# With a rich build and every hazard, the preview always equals the move.
	var build: Array = ["climbing_rope", "ember_heart", "avalanche", "snowball", "twin_rope", "golden_yak", "lantern_festival", "eternal_glacier", "camp_lantern"]
	var mismatches: int = 0
	var golden_found: int = 0
	for seed_value in range(40):
		var round = Model.new(seed_value, 99999, 8, {"talismans": build, "coins": 12,
			"rules": {"golden_hour": true, "rockfall": 3, "frost": 2, "stones_start": 2}})
		for i in range(60):
			if round.status != Model.PLAYING:
				break
			var move: Array = first_move(round)
			if move.is_empty():
				round.try_reroll()
				continue
			var preview: Dictionary = round.preview(round.tray[move[0]], move[1], move[2])
			var result: Dictionary = round.try_place(move[0], move[1], move[2])
			if preview.points != result.points or preview.cleared != result.cleared:
				mismatches += 1
		golden_found += round.coins_found
	check(mismatches == 0, "Expedition previews equal the committed move")
	check(golden_found > 0, "Golden Hour drops Coins")
	# Mid-round save and restore continue identically.
	var live = Model.new(21, 99999, 8, {"talismans": ["snowball", "eternal_glacier", "camp_lantern"], "rules": {"crow": true, "frost": 2}, "rerolls": 2, "coins": 7})
	for i in range(6):
		var move: Array = first_move(live)
		live.try_place(move[0], move[1], move[2])
	var copy = Model.new(1)
	check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(live.snapshot()))), "Expedition round save round trip")
	var same: bool = true
	for i in range(30):
		same = same and JSON.stringify(live.snapshot()) == JSON.stringify(copy.snapshot())
		if live.status != Model.PLAYING:
			break
		var move: Array = first_move(live)
		if move.is_empty():
			live.try_reroll()
			copy.try_reroll()
		else:
			live.try_place(move[0], move[1], move[2])
			copy.try_place(move[0], move[1], move[2])
	check(same, "Restored expedition round continues identically")
	for bad in [{"talismans": ["not_a_talisman"]}, {"rules": {"teleport": 1}}, {"rules": {"min_cells": 9}}, {"rules": {"langur": 1}}, {"rerolls": -1}]:
		var damaged: Dictionary = live.snapshot()
		var config: Dictionary = damaged.config.duplicate(true)
		config.merge(bad, true)
		damaged.config = config
		check(not copy.restore_snapshot(damaged), "Invalid round config rejected: %s" % [bad])
	var too_many: Dictionary = live.snapshot()
	too_many.rerolls = 3
	check(not copy.restore_snapshot(too_many), "Rerolls above the round's limit rejected")

func check_run() -> void:
	var run = Run.new(123)
	check(run.phase == Run.INTRO and run.floor_reached() == 1 and run.stage == 0 and run.coins == 4, "A run starts at Floor 1 Trail with 4 Coins")
	check(run.round.target == 300 and run.round.max_trays == 8 and run.round.rerolls == 1, "Floor 1 Trail: 300 in 8 trays")
	check(not run.leave_camp() and run.begin() and run.phase == Run.ROUND and not run.begin(), "Begin starts the round once")
	# Targets and structure follow the design table.
	check(Encounters.target(0, 1) == 450 and Encounters.target(3, 2) == 3200 and Encounters.target(7, 2) == 30000, "Design targets")
	check(Encounters.guardian_pool(0) == ["stone_yak", "moon_bear"] and Encounters.guardian_pool(7) == ["summit_warden"], "Guardian pools by floor")
	for f in range(7):
		check(not Encounters.guardian_pool(f).is_empty(), "Floor %d has Guardians" % (f + 1))
	# Same seed, same run.
	var a = Run.new(555)
	var b = Run.new(555)
	play_to_camp(a)
	play_to_camp(b)
	check(JSON.stringify(a.snapshot()) == JSON.stringify(b.snapshot()), "Runs are deterministic per seed")
	check(a.phase == Run.CAMP and a.rounds_won == 1, "Winning the first round reaches Camp")
	var unused: int = a.round.max_trays - a.round.trays_dealt
	check(a.reward.round == 3 and a.reward.trays == unused and a.reward.interest == 0 and a.coins == 4 + a.reward.total, "Round reward, unused trays and interest")
	# Upcoming hazards and shards ignore Camp choices.
	var c = Run.new(555)
	play_to_camp(c)
	a.skip_draft()
	c.take_draft(0)
	c.coins = 100
	c.reroll_shop()
	c.reroll_shop()
	a.leave_camp()
	c.leave_camp()
	check(a.hazard == c.hazard and JSON.stringify(a.round.tray) == JSON.stringify(c.round.tray), "Camp choices never change the next round's hazard or shards")
	# Full runs end, and a final win is a summit.
	var finished: int = 0
	for seed_value in range(6):
		var r = Run.new(900 + seed_value)
		for i in range(5000):
			if r.phase == Run.WON or r.phase == Run.LOST:
				break
			if r.phase == Run.CAMP:
				if r.draft_open and not r.take_draft(0):
					r.skip_draft()
				r.leave_camp()
			elif r.phase == Run.INTRO:
				r.begin()
			else:
				step(r)
		if r.phase == Run.WON or r.phase == Run.LOST:
			finished += 1
	check(finished == 6, "Every bot run reaches an ending")
	var summit = Run.new(31)
	summit.floor_index = 7
	summit.stage = 2
	summit.beaten = ["moon_bear", "frostmane", "langur"]
	summit.start_encounter()
	check(summit.hazard == "summit_warden" and summit.hazard_ids() == ["langur", "frostmane"], "The Warden recalls the last two Guardians")
	check(summit.round.target == 30000 and summit.round.max_trays == 9 and summit.round.rules.get("langur", false), "Warden round: 30,000 in 9 trays with recalled rules")
	summit.begin()
	summit.round.score = summit.round.target
	summit.round.status = Model.WON
	check(summit.after_round_command() == "summit" and summit.phase == Run.WON, "Beating the Warden reaches the summit")
	# Firebird Feather: one second chance.
	var bird = Run.new(42)
	bird.talismans = ["firebird_feather", "cairn"]
	bird.make_round()
	bird.begin()
	bird.round.status = Model.LOST
	check(bird.after_round_command() == "firebird" and bird.phase == Run.INTRO and bird.talismans == ["cairn"], "Firebird restarts the round and burns away")
	check(bird.round.status == Model.PLAYING and bird.round.score == 0 and bird.round.talismans == ["cairn"], "The restarted round is fresh")
	bird.begin()
	bird.round.status = Model.LOST
	check(bird.after_round_command() == "run_lost" and bird.phase == Run.LOST, "Without a Firebird, a lost round ends the run")
	# Talisman effects outside scoring.
	var kit = Run.new(8)
	kit.talismans = ["trail_map", "hourglass", "mirror_lake", "trail_map"]
	kit.make_round()
	# Two Trail Maps plus Mirror Lake copying one: three extra rerolls.
	check(kit.round.rerolls == 4 and kit.round.max_trays == 10, "Trail Map (copied by Mirror Lake) and Hourglass adjust the round")
	kit.talismans = ["ninth_peak"]
	check(kit.slots() == 7, "The Ninth Peak adds two slots")

func check_camp() -> void:
	var run = Run.new(2024)
	play_to_camp(run)
	check(run.phase == Run.CAMP and run.draft_open and run.draft.size() == 3, "Camp opens with a draft of three")
	var distinct: Dictionary = {}
	for id in run.draft:
		distinct[id] = true
	check(distinct.size() == 3, "Draft offers are distinct")
	check(not run.leave_camp(), "The draft must be taken or skipped before leaving")
	var first: String = run.draft[0]
	check(run.take_draft(0) and run.talismans == [first] and not run.draft_open and not run.take_draft(1), "Take one free talisman")
	for offer in run.shop:
		check(not run.talismans.has(offer.id), "Trader never offers a held talisman")
	run.coins = 3
	check(not run.buy(0) and run.coins == 3 and not run.shop[0].sold, "Cannot buy without enough Coins")
	run.coins = 40
	var cost: int = run.price(run.shop[0].id)
	check(run.buy(0) and run.coins == 40 - cost and run.shop[0].sold and not run.buy(0), "Buying deducts the price once")
	check(run.reroll_cost() == 2 and run.reroll_shop() and run.reroll_cost() == 3 and run.reroll_shop() and run.coins == 40 - cost - 5, "Trader reroll costs 2, then 3")
	run.talismans.append("hagglers_beads")
	var id: String = run.shop[1].id
	check(run.price(id) == maxi(1, Talismans.price(id) - 1), "Haggler's Beads discount")
	var held: int = run.talismans.size()
	var sold_id: String = run.talismans[0]
	var coins: int = run.coins
	check(run.sell(0) and run.talismans.size() == held - 1 and run.coins == coins + Talismans.sell_price(sold_id), "Selling returns half the price")
	run.talismans = ["climbing_rope", "tea_thermos", "cairn"]
	check(run.move(0, 1) and run.talismans == ["tea_thermos", "climbing_rope", "cairn"] and not run.move(0, -1), "Reorder talismans")
	# Full slots: a draft card swaps out a held talisman.
	var full = Run.new(77)
	play_to_camp(full)
	full.talismans = ["climbing_rope", "tea_thermos", "cairn", "avalanche", "momentum"]
	var card: String = full.draft[0]
	check(not full.take_draft(0) and full.draft_open, "A full build cannot take a card without a swap")
	coins = full.coins
	check(full.take_draft(0, 1) and full.talismans.size() == 5 and full.talismans.has(card) and not full.talismans.has("tea_thermos") and full.coins == coins + 2, "Swapping sells the old talisman")
	full.talismans = ["climbing_rope", "tea_thermos", "cairn", "avalanche", "momentum"]
	check(not full.buy(0), "No buying with full slots")
	full.talismans = ["ninth_peak", "climbing_rope", "tea_thermos", "cairn", "avalanche", "momentum", "twin_rope"]
	check(not full.sell(0), "The Ninth Peak cannot be sold while its slots are used")
	# Skipping pays, and Guardian drafts are rarer.
	var skipper = Run.new(99)
	play_to_camp(skipper)
	coins = skipper.coins
	check(skipper.skip_draft() and skipper.coins == coins + 3 and skipper.leave_camp() and skipper.stage == 1 and skipper.phase == Run.INTRO, "Skip for +3 Coins, then on to the Ridge")
	check(Encounters.WEATHER_IDS.has(skipper.hazard), "Ridge rounds have weather")
	skipper.stage = 2
	skipper.start_encounter()
	check(Encounters.guardian_pool(0).has(skipper.hazard), "Guardian rounds draw from the floor's pool")
	var rare_only: bool = true
	for n in range(30):
		for offer_id in skipper.roll_offers(3, true, []):
			rare_only = rare_only and int(Talismans.info(offer_id).rarity) >= Talismans.UNCOMMON
	check(rare_only, "Guardian drafts offer Uncommon or better")
	# Selling growth talismans resets their stacks.
	var grower = Run.new(5)
	play_to_camp(grower)
	grower.talismans = ["snowball"]
	grower.snowball = 4
	grower.sell(0)
	check(grower.snowball == 0, "Selling Snowball clears its stacks")

func check_saves() -> void:
	var run = Run.new(4242)
	play_to_camp(run)
	run.take_draft(1)
	var copy = Run.new(1)
	check(copy.restore_snapshot(JSON.parse_string(JSON.stringify(run.snapshot()))), "Run save round trip in Camp")
	check(JSON.stringify(copy.snapshot()) == JSON.stringify(run.snapshot()), "Restored run matches")
	run.leave_camp()
	copy.leave_camp()
	run.begin()
	copy.begin()
	for i in range(8):
		step(run)
		step(copy)
	var mid = Run.new(1)
	check(mid.restore_snapshot(JSON.parse_string(JSON.stringify(run.snapshot()))), "Run save round trip mid-round")
	for i in range(40):
		step(run)
		step(mid)
		if run.phase != Run.ROUND:
			break
	check(JSON.stringify(mid.snapshot()) == JSON.stringify(run.snapshot()) and JSON.stringify(copy.snapshot()) != "", "Restored run continues identically")
	var prior: String = JSON.stringify(copy.snapshot())
	for change in [["phase", "teleport"], ["coins", -3], ["talismans", ["nope"]], ["floor", 9], ["hazard", "dragon"], ["shop", [{"id": "cairn"}]], ["round", {}]]:
		var damaged: Dictionary = run.snapshot()
		damaged[change[0]] = change[1]
		check(not copy.restore_snapshot(damaged) and JSON.stringify(copy.snapshot()) == prior, "Damaged run save rejected atomically: %s" % change[0])
