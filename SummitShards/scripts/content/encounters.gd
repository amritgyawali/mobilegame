extends RefCounted
## Expedition structure: floors, targets, Ridge weather and Guardians, and
## the round rules each one imposes. Targets are the design document's table
## (not a formula) so every listed value is reproduced exactly.

const FLOORS = 8
const TRAIL = 0
const RIDGE = 1
const GUARDIAN = 2
const STAGE_NAMES = ["Trail", "Ridge", "Guardian"]
const STAGE_TRAYS = [8, 8, 9]
const FLOOR_NAMES = ["Rhododendron Forest", "Prayer-Flag Bridge", "Yak Pastures", "Glacier Gate",
	"Storm Ridge", "Ice Cathedral", "Death Zone", "The Summit"]
const TARGETS = [[300, 450, 600], [525, 790, 1050], [920, 1380, 1840], [1600, 2400, 3200],
	[2800, 4200, 5600], [4900, 7350, 9800], [8600, 12900, 17200], [15000, 22500, 30000]]

const WEATHER_IDS = ["clear_sky", "thin_air", "rockfall", "snowfall", "golden_hour"]
const WEATHERS = {
	"clear_sky": {"name": "Clear Sky", "text": "No hazard. +2 Coins when you win."},
	"thin_air": {"name": "Thin Air", "text": "Only 7 trays this round."},
	"rockfall": {"name": "Rockfall", "text": "3 Stones fall at the start of trays 3 and 6."},
	"snowfall": {"name": "Snowfall", "text": "4 cells start buried under Stone."},
	"golden_hour": {"name": "Golden Hour", "text": "Each cleared tile has a 1 in 10 chance to drop a Coin."},
}

const GUARDIAN_IDS = ["stone_yak", "moon_bear", "frostmane", "thunder_kite", "langur", "crow"]
## first/last floor (1-based) each Guardian can appear on.
const GUARDIANS = {
	"stone_yak": {"name": "The Stone Yak", "floors": [1, 3], "text": "The round starts with 6 Stones on the board."},
	"moon_bear": {"name": "The Moon Bear", "floors": [1, 4], "text": "No shards smaller than 4 cells."},
	"frostmane": {"name": "Frostmane", "floors": [2, 5], "text": "2 Stones appear at the start of every odd tray from tray 3."},
	"thunder_kite": {"name": "Thunder Kite", "floors": [2, 6], "text": "Streak bonus is capped at +0.5 Mult."},
	"langur": {"name": "The Langur Trickster", "floors": [3, 7], "text": "One talisman is disabled. It moves one slot right every tray."},
	"crow": {"name": "The Crow of Lights", "floors": [5, 7], "text": "Your talisman order is shuffled every tray."},
	"summit_warden": {"name": "The Summit Warden", "floors": [8, 8], "text": "Brings back the rules of the last two Guardians you beat."},
}
const STONE_TEXT = "Stone fills a cell. A clear cracks it; a second clear breaks it."

static func target(floor_index: int, stage: int) -> int:
	return TARGETS[clampi(floor_index, 0, FLOORS - 1)][clampi(stage, 0, 2)]

## Guardians allowed on a 0-based floor (floor 8 is always the Warden).
static func guardian_pool(floor_index: int) -> Array:
	if floor_index >= FLOORS - 1:
		return ["summit_warden"]
	var pool: Array = []
	for id in GUARDIAN_IDS:
		var span: Array = GUARDIANS[id].floors
		if floor_index + 1 >= span[0] and floor_index + 1 <= span[1]:
			pool.append(id)
	return pool

## The rules one hazard id adds to a round, merged into `rules`.
static func add_rules(rules: Dictionary, id: String) -> void:
	match id:
		"thin_air":
			rules.tray_delta = int(rules.get("tray_delta", 0)) - 1
		"rockfall":
			rules.rockfall = int(rules.get("rockfall", 0)) + 3
		"snowfall":
			rules.stones_start = int(rules.get("stones_start", 0)) + 4
		"golden_hour":
			rules.golden_hour = true
		"stone_yak":
			rules.stones_start = int(rules.get("stones_start", 0)) + 6
		"moon_bear":
			rules.min_cells = 4
		"frostmane":
			rules.frost = int(rules.get("frost", 0)) + 2
		"thunder_kite":
			rules.streak_cap_halves = 1
		"langur":
			rules.langur = true
		"crow":
			rules.crow = true

static func hazard_name(id: String) -> String:
	if WEATHERS.has(id):
		return WEATHERS[id].name
	return GUARDIANS.get(id, {"name": ""}).name

static func hazard_text(id: String) -> String:
	if WEATHERS.has(id):
		return WEATHERS[id].text
	return GUARDIANS.get(id, {"text": ""}).text
