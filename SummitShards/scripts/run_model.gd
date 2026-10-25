extends RefCounted
## Pure expedition state: eight floors of Trail, Ridge and Guardian rounds,
## Coins, talismans and the Camp between rounds. No scene, clock, filesystem
## or engine RNG. Every random choice comes from seeded xorshift32 streams:
## each round derives its own seed from the run seed and encounter, and Camp
## offers and encounter picks use a separate stream, so taking a draft never
## changes which shards a later round deals.

const Model = preload("res://scripts/round_model.gd")
const Talismans = preload("res://scripts/content/talismans.gd")
const Encounters = preload("res://scripts/content/encounters.gd")

const MASK32 = 4294967295
const VERSION = 1
const INTRO = "intro"
const ROUND = "round"
const CAMP = "camp"
const WON = "won"
const LOST = "lost"
const PHASES = [INTRO, ROUND, CAMP, WON, LOST]
const BASE_SLOTS = 5
const START_COINS = 4
const SKIP_COINS = 3
const STAGE_REWARD = [3, 4, 5]
const CLEAR_SKY_BONUS = 2
const INTEREST_STEP = 5
const INTEREST_CAP = 5
const REROLL_COST = 2
const DRAFT_SIZE = 3
const SHOP_SIZE = 3
## Draft rarity odds in percent: Common, Uncommon, Rare, Legendary.
const ODDS = [60, 30, 9, 1]
const GUARDIAN_ODDS = [0, 50, 40, 10]

var run_seed: int = 1
var rng_state: int = 1
var floor_index: int = 0
var stage: int = 0
var phase: String = INTRO
var coins: int = START_COINS
var talismans: Array = []
var hazard: String = ""
var round: RefCounted
var attempt: int = 0
var draft: Array = []
var draft_open: bool = false
var shop: Array = []
var shop_rerolls: int = 0
var reward: Dictionary = {}
var snowball: int = 0
var glacier_lines: int = 0
var beaten: Array = []
var rounds_won: int = 0
var lines: int = 0
var best_move: int = 0
var perfects: int = 0
var last_event: String = ""

func _init(seed_value: int = 1) -> void:
	run_seed = seed_value & MASK32
	rng_state = mix(run_seed ^ 0x9e3779b9)
	start_encounter()

# ---------------------------------------------------------------- randomness

## SplitMix-style 32-bit mixer: turns related seeds into unrelated streams.
static func mix(value: int) -> int:
	var x: int = value & MASK32
	x = ((x ^ (x >> 16)) * 0x45d9f3b) & MASK32
	x = ((x ^ (x >> 16)) * 0x45d9f3b) & MASK32
	x = (x ^ (x >> 16)) & MASK32
	return x if x != 0 else 2463534242

func next_random() -> int:
	rng_state = (rng_state ^ (rng_state << 13)) & MASK32
	rng_state = (rng_state ^ (rng_state >> 17)) & MASK32
	rng_state = (rng_state ^ (rng_state << 5)) & MASK32
	return rng_state

func random_range(bound: int) -> int:
	var limit: int = MASK32 - (MASK32 % bound)
	var value: int = next_random() - 1
	while value >= limit:
		value = next_random() - 1
	return value % bound

# ---------------------------------------------------------------- talismans

## Held talismans with Mirror Lake resolved to the talisman on its right.
## Used for rules outside scoring (rerolls, trays, Coins, slots).
func resolved_talismans() -> Array:
	var list: Array = []
	for i in range(talismans.size()):
		var id: String = talismans[i]
		if id == "mirror_lake":
			if i + 1 >= talismans.size() or talismans[i + 1] == "mirror_lake":
				continue
			id = talismans[i + 1]
		list.append(id)
	return list

func count_effect(id: String) -> int:
	return resolved_talismans().count(id)

func slots() -> int:
	return BASE_SLOTS + 2 * talismans.count("ninth_peak")

func has_room() -> bool:
	return talismans.size() < slots()

# ---------------------------------------------------------------- encounters

func encounter_index() -> int:
	return floor_index * 3 + stage

func is_final() -> bool:
	return floor_index == Encounters.FLOORS - 1 and stage == Encounters.GUARDIAN

func target() -> int:
	return Encounters.target(floor_index, stage)

## Hazard ids active this round (weather, a Guardian, or the Warden's two).
func hazard_ids() -> Array:
	if hazard == "summit_warden":
		var recalled: Array = []
		for i in range(beaten.size() - 1, -1, -1):
			if not recalled.has(beaten[i]) and beaten[i] != "summit_warden":
				recalled.append(beaten[i])
			if recalled.size() == 2:
				break
		if recalled.is_empty():
			recalled.append("stone_yak")
		return recalled
	return [] if hazard == "" else [hazard]

func round_rules() -> Dictionary:
	var rules: Dictionary = {}
	for id in hazard_ids():
		Encounters.add_rules(rules, id)
	return rules

func round_trays() -> int:
	var rules: Dictionary = round_rules()
	return maxi(1, Encounters.STAGE_TRAYS[stage] + int(rules.get("tray_delta", 0)) + 2 * count_effect("hourglass"))

func round_rerolls() -> int:
	return 1 + count_effect("trail_map")

## Weather and Guardians come from the run seed and the encounter alone, so
## Camp choices and Trader rerolls never change what lies ahead.
func start_encounter() -> void:
	hazard = ""
	var pick: int = mix(run_seed ^ (0x2545f491 * (encounter_index() + 1)))
	if stage == Encounters.RIDGE:
		hazard = Encounters.WEATHER_IDS[pick % Encounters.WEATHER_IDS.size()]
	elif stage == Encounters.GUARDIAN:
		var pool: Array = Encounters.guardian_pool(floor_index)
		hazard = pool[pick % pool.size()]
	attempt = 0
	make_round()
	phase = INTRO

func make_round() -> void:
	var rules: Dictionary = round_rules()
	rules.erase("tray_delta")
	var round_seed: int = mix(run_seed + 7919 * (encounter_index() + 1) + 104729 * attempt)
	round = Model.new(round_seed, target(), round_trays(), {
		"talismans": talismans.duplicate(), "rules": rules, "rerolls": round_rerolls(),
		"coins": coins, "snowball": snowball, "glacier_lines": glacier_lines})

func begin() -> bool:
	if phase != INTRO:
		return false
	phase = ROUND
	return true

## Call after every round command. Returns "" while the round goes on, or
## "round_won", "summit", "firebird" or "run_lost".
func after_round_command() -> String:
	last_event = ""
	if phase != ROUND or round.status == Model.PLAYING:
		return last_event
	# Talisman counters persist across rounds.
	snowball = round.snowball
	glacier_lines = round.glacier_lines
	lines += round.lines_total
	best_move = maxi(best_move, round.best_move)
	perfects += round.perfect_count
	if round.status == Model.WON:
		settle_win()
		last_event = "summit" if phase == WON else "round_won"
	elif talismans.has("firebird_feather"):
		talismans.erase("firebird_feather")
		attempt += 1
		make_round()
		phase = INTRO
		last_event = "firebird"
	else:
		phase = LOST
		last_event = "run_lost"
	return last_event

func settle_win() -> void:
	rounds_won += 1
	var unused: int = maxi(0, round.max_trays - round.trays_dealt)
	reward = {
		"round": STAGE_REWARD[stage] + (CLEAR_SKY_BONUS if hazard == "clear_sky" else 0),
		"trays": unused * (1 + count_effect("coin_purse")),
		"interest": mini(INTEREST_CAP, coins / INTEREST_STEP),
		"found": round.coins_found,
	}
	reward.total = int(reward.round) + int(reward.trays) + int(reward.interest) + int(reward.found)
	coins += int(reward.total)
	if stage == Encounters.GUARDIAN:
		beaten.append(hazard)
	if is_final():
		phase = WON
		return
	phase = CAMP
	draft = roll_offers(DRAFT_SIZE, stage == Encounters.GUARDIAN, [])
	draft_open = true
	shop_rerolls = 0
	shop = []
	for id in roll_offers(SHOP_SIZE, false, draft):
		shop.append({"id": id, "sold": false})

## Picks `count` distinct talismans the player does not hold, by rarity odds.
## Falls back through the other rarities when one is used up.
func roll_offers(count: int, guardian: bool, exclude: Array) -> Array:
	var odds: Array = GUARDIAN_ODDS if guardian else ODDS
	var offers: Array = []
	for n in range(count):
		var roll: int = random_range(100)
		var rarity: int = 0
		while rarity < 3 and roll >= odds[rarity]:
			roll -= odds[rarity]
			rarity += 1
		for step in range(4):
			var pool: Array = Talismans.ids_of_rarity((rarity + step) % 4).filter(func(id):
				return not talismans.has(id) and not offers.has(id) and not exclude.has(id))
			if not pool.is_empty():
				offers.append(pool[random_range(pool.size())])
				break
	return offers

# ---------------------------------------------------------------- Camp

func price(id: String) -> int:
	return maxi(1, Talismans.price(id) - count_effect("hagglers_beads"))

func reroll_cost() -> int:
	return REROLL_COST + shop_rerolls

## Takes draft card `index`. When the slots are full, `replace` names the slot
## whose talisman is sold to make room.
func take_draft(index: int, replace: int = -1) -> bool:
	if phase != CAMP or not draft_open or index < 0 or index >= draft.size():
		return false
	if not has_room():
		if replace < 0 or replace >= talismans.size() or talismans[replace] == "ninth_peak":
			return false
		sell(replace)
	talismans.append(draft[index])
	draft_open = false
	return true

func skip_draft() -> bool:
	if phase != CAMP or not draft_open:
		return false
	coins += SKIP_COINS
	draft_open = false
	return true

func buy(index: int) -> bool:
	if phase != CAMP or index < 0 or index >= shop.size() or shop[index].sold or not has_room():
		return false
	var cost: int = price(shop[index].id)
	if coins < cost:
		return false
	coins -= cost
	talismans.append(shop[index].id)
	shop[index].sold = true
	return true

func reroll_shop() -> bool:
	if phase != CAMP or coins < reroll_cost():
		return false
	coins -= reroll_cost()
	shop_rerolls += 1
	shop = []
	for id in roll_offers(SHOP_SIZE, false, draft if draft_open else []):
		shop.append({"id": id, "sold": false})
	return true

## Sells the talisman in `slot` for half its price. The Ninth Peak cannot be
## sold while its extra slots are in use.
func sell(slot: int) -> bool:
	if phase != CAMP or slot < 0 or slot >= talismans.size():
		return false
	var id: String = talismans[slot]
	# Selling the Ninth Peak removes two slots; the rest must still fit.
	if id == "ninth_peak" and talismans.size() - 1 > slots() - 2:
		return false
	talismans.remove_at(slot)
	coins += Talismans.sell_price(id)
	if id == "snowball" and not talismans.has("snowball"):
		snowball = 0
	if id == "eternal_glacier" and not talismans.has("eternal_glacier"):
		glacier_lines = 0
	return true

## Moves the talisman in `slot` one place left (-1) or right (+1).
func move(slot: int, direction: int) -> bool:
	var other: int = slot + direction
	if phase != CAMP or slot < 0 or slot >= talismans.size() or other < 0 or other >= talismans.size():
		return false
	var swap = talismans[slot]
	talismans[slot] = talismans[other]
	talismans[other] = swap
	return true

func leave_camp() -> bool:
	if phase != CAMP or draft_open:
		return false
	if stage == Encounters.GUARDIAN:
		stage = 0
		floor_index += 1
	else:
		stage += 1
	draft = []
	shop = []
	reward = {}
	start_encounter()
	return true

## Highest floor reached, 1-based.
func floor_reached() -> int:
	return floor_index + 1

# ---------------------------------------------------------------- saves

func snapshot() -> Dictionary:
	return {"version": VERSION, "seed": run_seed, "rng": rng_state, "floor": floor_index, "stage": stage,
		"phase": phase, "coins": coins, "talismans": talismans.duplicate(), "hazard": hazard,
		"attempt": attempt, "draft": draft.duplicate(), "draft_open": draft_open,
		"shop": shop.duplicate(true), "shop_rerolls": shop_rerolls, "reward": reward.duplicate(),
		"snowball": snowball, "glacier_lines": glacier_lines, "beaten": beaten.duplicate(),
		"rounds_won": rounds_won, "lines": lines, "best_move": best_move, "perfects": perfects,
		"round": round.snapshot()}

static func _int(value: Variant, low: int, high: int) -> bool:
	return Model.integer_number(value) and int(value) >= low and int(value) <= high

static func _talisman_list(value: Variant, limit: int) -> bool:
	if not value is Array or value.size() > limit:
		return false
	for id in value:
		if not id is String or not Talismans.exists(id):
			return false
	return true

## Restores a saved run after validating every field. Leaves this run
## unchanged and returns false if anything is out of place.
func restore_snapshot(data: Dictionary) -> bool:
	var keys: Array = ["version", "seed", "rng", "floor", "stage", "phase", "coins", "talismans", "hazard", "attempt",
		"draft", "draft_open", "shop", "shop_rerolls", "reward", "snowball", "glacier_lines", "beaten",
		"rounds_won", "lines", "best_move", "perfects", "round"]
	for key in keys:
		if not data.has(key):
			return false
	if not _int(data.version, VERSION, VERSION) or not _int(data.seed, 0, MASK32) or not _int(data.rng, 1, MASK32):
		return false
	if not _int(data.floor, 0, Encounters.FLOORS - 1) or not _int(data.stage, 0, 2) or not PHASES.has(data.phase):
		return false
	for key in ["coins", "attempt", "shop_rerolls", "snowball", "glacier_lines", "rounds_won", "lines", "best_move", "perfects"]:
		if not _int(data[key], 0, 1 << 40):
			return false
	if not _talisman_list(data.talismans, BASE_SLOTS + 4) or not _talisman_list(data.draft, DRAFT_SIZE) or not _talisman_list(data.beaten, 30):
		return false
	if not data.hazard is String or (data.hazard != "" and not Encounters.WEATHERS.has(data.hazard) and not Encounters.GUARDIANS.has(data.hazard)):
		return false
	if not data.draft_open is bool or not data.reward is Dictionary or not data.round is Dictionary:
		return false
	if not data.shop is Array or data.shop.size() > SHOP_SIZE:
		return false
	for offer in data.shop:
		if not offer is Dictionary or not offer.get("id") is String or not Talismans.exists(offer.id) or not offer.get("sold") is bool:
			return false
	for key in data.reward:
		if not _int(data.reward[key], 0, 1 << 40):
			return false
	if data.phase == CAMP and data.draft_open and data.draft.is_empty():
		return false
	var restored_round = Model.new(1)
	if not restored_round.restore_snapshot(data.round):
		return false
	run_seed = int(data.seed)
	rng_state = int(data.rng)
	floor_index = int(data.floor)
	stage = int(data.stage)
	phase = data.phase
	coins = int(data.coins)
	talismans = []
	for id in data.talismans:
		talismans.append(String(id))
	hazard = data.hazard
	attempt = int(data.attempt)
	draft = []
	for id in data.draft:
		draft.append(String(id))
	draft_open = data.draft_open
	shop = []
	for offer in data.shop:
		shop.append({"id": String(offer.id), "sold": offer.sold})
	shop_rerolls = int(data.shop_rerolls)
	reward = {}
	for key in data.reward:
		reward[key] = int(data.reward[key])
	snowball = int(data.snowball)
	glacier_lines = int(data.glacier_lines)
	beaten = []
	for id in data.beaten:
		beaten.append(String(id))
	rounds_won = int(data.rounds_won)
	lines = int(data.lines)
	best_move = int(data.best_move)
	perfects = int(data.perfects)
	round = restored_round
	return true
