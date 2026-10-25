extends RefCounted
## Lifetime player statistics. Pure data: the scene decides when to save.
## A finished round is recorded at most once, keyed by its seed, so reloading
## a finished round or replaying lifecycle events never double counts it.

const INT_KEYS = ["best_score", "rounds_played", "rounds_won", "win_streak",
	"best_win_streak", "lines_cleared", "perfect_clears", "best_move"]

var best_score: int = 0
var rounds_played: int = 0
var rounds_won: int = 0
var win_streak: int = 0
var best_win_streak: int = 0
var lines_cleared: int = 0
var perfect_clears: int = 0
var best_move: int = 0
var seen_tutorial: bool = false
var last_round_id: int = -1

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

func win_rate() -> int:
	return 0 if rounds_played == 0 else roundi(100.0 * rounds_won / rounds_played)

func to_dict() -> Dictionary:
	var data: Dictionary = {"version": 1, "seen_tutorial": seen_tutorial, "last_round_id": last_round_id}
	for key in INT_KEYS:
		data[key] = get(key)
	return data

func from_dict(data: Dictionary) -> void:
	for key in INT_KEYS:
		var value = data.get(key)
		set(key, maxi(0, int(value)) if (value is int or value is float) and is_finite(float(value)) else 0)
	seen_tutorial = data.get("seen_tutorial") is bool and data.seen_tutorial
	var round_id = data.get("last_round_id")
	last_round_id = int(round_id) if (round_id is int or round_id is float) and is_finite(float(round_id)) else -1
	if rounds_won > rounds_played:
		rounds_won = rounds_played
	best_win_streak = maxi(best_win_streak, win_streak)

func reset() -> void:
	from_dict({"seen_tutorial": seen_tutorial})
