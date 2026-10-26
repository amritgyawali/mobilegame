extends RefCounted
## Expedition XP, levels, unlocks and Altitudes, from the design document
## (sections 14 and 15). Data only.

const XP_ROUND = 10
const XP_GUARDIAN = 25
const XP_SUMMIT = 100
const XP_DISCOVERY = 15
const MAX_LEVEL = 50
## Cumulative XP for levels 2-5; then +180 per level to 10, +300 to 30,
## +450 to 50.
const EARLY_LEVELS = [0, 0, 60, 150, 270, 420]

## Talismans available from the first run: the design's starter set (marked
## with a star) among those implemented.
const STARTER_TALISMANS = ["climbing_rope", "tea_thermos", "sky_feather", "wind_chime", "ember_heart",
	"river_pearl", "earth_drum", "trail_map", "coin_purse", "sturdy_boots", "camp_lantern", "porters_basket",
	"little_pebble", "hagglers_beads", "stone_collector", "twin_rope", "avalanche", "clean_slate", "momentum"]
const STARTER_RUNES = ["rune_time", "rune_thaw", "rune_wealth", "rune_echo", "rune_still",
	"dye_sky", "dye_wind", "dye_fire", "dye_water", "dye_earth"]
## level -> {"talismans": [...], "runes": [...], "modes": [...]}
const UNLOCKS = {
	2: {"modes": ["daily"]},
	3: {"talismans": ["snowball", "minimalists_stone", "cairn"]},
	4: {"talismans": ["rainbow_scarf", "echo_valley"], "runes": ["rune_shatter", "rune_shrink"]},
	5: {"talismans": ["ice_axe", "thunderclap", "snow_leopard_fang"]},
	6: {"talismans": ["golden_yak", "hourglass"]},
	7: {"talismans": ["lantern_festival", "mirror_lake"]},
	8: {"talismans": ["heart_of_mountain", "storm_crown"]},
	9: {"talismans": ["eternal_glacier", "ninth_peak"]},
	10: {"talismans": ["firebird_feather"]},
}

## Altitude rules are cumulative; targets use the latest multiplier.
const ALTITUDES = [
	"Normal climb.",
	"Targets x1.25.",
	"Trader prices +1 Coin.",
	"Talisman drafts show only 2 choices.",
	"Every Ridge also starts with 2 Stones.",
	"Rounds start with 0 rerolls.",
	"Targets x1.5.",
	"Guardians bring a second rule.",
	"Interest is capped at 3 Coins.",
	"Trail and Ridge rounds have 7 trays.",
	"Death Zone: targets x2 and one talisman is disabled each round.",
]
const MAX_ALTITUDE = 10

static func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level <= 5:
		return EARLY_LEVELS[level]
	if level <= 10:
		return 420 + 180 * (level - 5)
	if level <= 30:
		return 1320 + 300 * (level - 10)
	return 7320 + 450 * (mini(level, MAX_LEVEL) - 30)

static func level_for_xp(xp: int) -> int:
	var level: int = 1
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
	return level

## Everything unlocked by `level`.
static func unlocked(level: int, kind: String) -> Array:
	var list: Array = (STARTER_TALISMANS if kind == "talismans" else STARTER_RUNES if kind == "runes" else []).duplicate()
	for at in UNLOCKS:
		if at <= level:
			list.append_array(UNLOCKS[at].get(kind, []))
	return list

## What reaching `level` newly unlocks, as display names.
static func unlock_names(level: int) -> Array:
	var names: Array = []
	var entry: Dictionary = UNLOCKS.get(level, {})
	for id in entry.get("talismans", []):
		names.append(load("res://scripts/content/talismans.gd").info(id).name)
	for id in entry.get("runes", []):
		names.append(load("res://scripts/content/runes.gd").info(id).name)
	if entry.get("modes", []).has("daily"):
		names.append("Daily Climb")
	return names

static func target_multiplier(altitude: int) -> float:
	if altitude >= 10:
		return 2.0
	if altitude >= 6:
		return 1.5
	if altitude >= 1:
		return 1.25
	return 1.0

## A short summary of everything an Altitude adds, for Home and the intro.
static func altitude_summary(altitude: int) -> String:
	if altitude <= 0:
		return ALTITUDES[0]
	return ALTITUDES[clampi(altitude, 0, MAX_ALTITUDE)] + (" Plus every lower Altitude." if altitude > 1 else "")
