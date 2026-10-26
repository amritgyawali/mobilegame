extends RefCounted
## Lifetime player statistics and progression (XP, Codex, Altitudes, Daily
## Climb). Pure data: the scene decides when to save.
## A finished round is recorded at most once, keyed by its seed, so reloading
## a finished round or replaying lifecycle events never double counts it.

const INT_KEYS = ["best_score", "rounds_played", "rounds_won", "win_streak",
	"best_win_streak", "lines_cleared", "perfect_clears", "best_move",
	"runs_played", "summits", "best_floor", "run_rounds_won"]
## Progression survives "Reset statistics".
const PROGRESS_INT_KEYS = ["xp", "max_altitude", "chosen_altitude", "daily_floor", "dailies_played"]
const MAX_DISCOVERIES = 256
const Progression = preload("res://scripts/content/progression.gd")

var best_score: int = 0
var rounds_played: int = 0
var rounds_won: int = 0
var win_streak: int = 0
var best_win_streak: int = 0
var lines_cleared: int = 0
var perfect_clears: int = 0
var best_move: int = 0
var runs_played: int = 0
var summits: int = 0
var best_floor: int = 0
var run_rounds_won: int = 0
var seen_tutorial: bool = false
var last_round_id: int = -1
var last_run_id: int = -1
var xp: int = 0
## Codex: ids of talismans, runes, weather and Guardians met so far.
var discovered: Array = []
## Highest Altitude unlocked (each summit at the top unlocked one opens the
## next) and the one chosen for new expeditions.
var max_altitude: int = 0
var chosen_altitude: int = 0
## Daily Climb: the local date of the last attempt and its result.
var daily_date: String = ""
var daily_floor: int = 0
var daily_won: bool = false
var dailies_played: int = 0

func level() -> int:
	return Progression.level_for_xp(xp)

## Adds an id to the Codex. A first discovery is worth XP; returns whether
## it was new.
func discover(id: String) -> bool:
	if id == "" or discovered.has(id) or discovered.size() >= MAX_DISCOVERIES:
		return false
	discovered.append(id)
	xp += Progression.XP_DISCOVERY
	return true

## Records a finished (or abandoned) round. Returns a summary for the result
## screen, or an empty Dictionary if this round was already recorded.
func record_round(round_id: int, won: bool, round_score: int, lines: int, perfects: int, round_best_move: int) -> Dictionary:
	if round_id == last_round_id:
		return {}
	var previous_best: int = best_score
	last_round_id = round_id
	rounds_played += 1
	if won:
		rounds_won += 1
		win_streak += 1
		best_win_streak = maxi(best_win_streak, win_streak)
	else:
		win_streak = 0
	lines_cleared += maxi(0, lines)
	perfect_clears += maxi(0, perfects)
	best_move = maxi(best_move, round_best_move)
	best_score = maxi(best_score, round_score)
	return {"new_best": round_score > previous_best and round_score > 0, "previous_best": previous_best}

## Records a finished or abandoned expedition once, keyed by its seed.
## Returns {new_best_floor} or an empty Dictionary if already recorded.
## Also awards Expedition XP (rounds, Guardians, the summit), and a summit at
## the highest unlocked Altitude opens the next one. The summary lists what
## changed for the run summary screen.
func record_run(run_id: int, won: bool, floor_reached: int, rounds: int, guardians: int = 0, altitude: int = 0, kind: String = "expedition") -> Dictionary:
	if run_id == last_run_id:
		return {}
	last_run_id = run_id
	runs_played += 1
	if won:
		summits += 1
	run_rounds_won += maxi(0, rounds)
	var previous: int = best_floor
	best_floor = maxi(best_floor, clampi(floor_reached, 0, 8))
	var level_before: int = level()
	var earned: int = maxi(0, rounds) * Progression.XP_ROUND + maxi(0, guardians) * Progression.XP_GUARDIAN + (Progression.XP_SUMMIT if won else 0)
	xp += earned
	var altitude_unlocked: bool = false
	if won and kind == "expedition" and altitude >= max_altitude and max_altitude < Progression.MAX_ALTITUDE:
		max_altitude += 1
		altitude_unlocked = true
	if kind == "daily":
		daily_floor = clampi(floor_reached, 0, 8)
		daily_won = won
	var unlocks: Array = []
	for at in range(level_before + 1, level() + 1):
		unlocks.append_array(Progression.unlock_names(at))
	return {"new_best_floor": best_floor > previous, "xp": earned, "level_before": level_before, "level": level(),
		"unlocks": unlocks, "altitude_unlocked": altitude_unlocked}

## Starts today's Daily Climb attempt. Returns false if today's was used.
func start_daily(date: String) -> bool:
	if date == "" or daily_date == date:
		return false
	daily_date = date
	daily_floor = 0
	daily_won = false
	dailies_played += 1
	return true

func win_rate() -> int:
	return 0 if rounds_played == 0 else roundi(100.0 * rounds_won / rounds_played)

func to_dict() -> Dictionary:
	var data: Dictionary = {"version": 1, "seen_tutorial": seen_tutorial, "last_round_id": last_round_id, "last_run_id": last_run_id,
		"discovered": discovered.duplicate(), "daily_date": daily_date, "daily_won": daily_won}
	for key in INT_KEYS + PROGRESS_INT_KEYS:
		data[key] = get(key)
	return data

func from_dict(data: Dictionary) -> void:
	for key in INT_KEYS + PROGRESS_INT_KEYS:
		var value = data.get(key)
		set(key, maxi(0, int(value)) if (value is int or value is float) and is_finite(float(value)) else 0)
	seen_tutorial = data.get("seen_tutorial") is bool and data.seen_tutorial
	var round_id = data.get("last_round_id")
	last_round_id = int(round_id) if (round_id is int or round_id is float) and is_finite(float(round_id)) else -1
	var run_id = data.get("last_run_id")
	last_run_id = int(run_id) if (run_id is int or run_id is float) and is_finite(float(run_id)) else -1
	best_floor = mini(best_floor, 8)
	summits = mini(summits, runs_played)
	max_altitude = mini(max_altitude, Progression.MAX_ALTITUDE)
	chosen_altitude = mini(chosen_altitude, max_altitude)
	daily_floor = mini(daily_floor, 8)
	discovered = []
	var saved = data.get("discovered", [])
	if saved is Array:
		for id in saved:
			if id is String and id.length() <= 40 and not discovered.has(id) and discovered.size() < MAX_DISCOVERIES:
				discovered.append(id)
	daily_date = data.daily_date if data.get("daily_date") is String and data.daily_date.length() <= 10 else ""
	daily_won = data.get("daily_won") is bool and data.daily_won
	if rounds_won > rounds_played:
		rounds_won = rounds_played
	best_win_streak = maxi(best_win_streak, win_streak)

## Clears statistics; level, Codex, Altitudes and today's Daily Climb stay.
func reset() -> void:
	var kept: Dictionary = {"seen_tutorial": seen_tutorial, "discovered": discovered.duplicate(), "daily_date": daily_date, "daily_won": daily_won}
	for key in PROGRESS_INT_KEYS:
		kept[key] = get(key)
	from_dict(kept)
