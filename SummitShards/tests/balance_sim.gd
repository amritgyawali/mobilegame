extends SceneTree
## Balance probe: bots play full expeditions and report how far they get.
##   godot --headless --path SummitShards --script res://tests/balance_sim.gd -- [runs] [policy] [altitude] [pool]
## policy "greedy" (default) picks the highest-scoring placement; "first" takes
## the first legal one, as a weak-player stand-in. Camp policy: take the
## rarest draft card, buy what is affordable, keep xMult talismans rightmost.
## A development tool, not part of the automated checks.

const Run = preload("res://scripts/run_model.gd")
const Model = preload("res://scripts/round_model.gd")
const Talismans = preload("res://scripts/content/talismans.gd")
const Progression = preload("res://scripts/content/progression.gd")
const MULTIPLIERS = ["twin_rope", "thunderclap", "snow_leopard_fang", "golden_yak", "lantern_festival", "heart_of_mountain", "eternal_glacier"]

func _initialize() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var runs: int = int(args[0]) if args.size() > 0 else 30
	var policy: String = args[1] if args.size() > 1 else "greedy"
	var altitude: int = int(args[2]) if args.size() > 2 else 0
	# "starter": only the talismans and runes a new player has unlocked.
	var options: Dictionary = {"altitude": altitude}
	if args.size() > 3 and args[3] == "starter":
		options.talisman_pool = Progression.unlocked(1, "talismans")
		options.rune_pool = Progression.unlocked(1, "runes")
	var floors: Array = []
	floors.resize(9)
	floors.fill(0)
	var losses: Dictionary = {}
	var started: int = Time.get_ticks_msec()
	var summits: int = 0
	var talisman_wins: Dictionary = {}
	for n in range(runs):
		var run = Run.new(1000 + n * 7919, options)
		var guard: int = 0
		while run.phase != Run.WON and run.phase != Run.LOST and guard < 2000:
			guard += 1
			match run.phase:
				Run.INTRO:
					run.begin()
				Run.ROUND:
					play_move(run.round, policy)
					run.after_round_command()
				Run.CAMP:
					camp(run)
		floors[run.floor_reached()] += 1
		if run.phase == Run.WON:
			summits += 1
			for id in run.talismans:
				talisman_wins[id] = talisman_wins.get(id, 0) + 1
		else:
			var key: String = "F%d %s %s" % [run.floor_reached(), ["Trail", "Ridge", "Guardian"][run.stage], run.hazard]
			losses[key] = losses.get(key, 0) + 1
	print("BALANCE (%s, altitude %d, %s pool, %d runs, %.1f s): summits %d" % [policy, altitude, "starter" if options.has("talisman_pool") else "full", runs, (Time.get_ticks_msec() - started) / 1000.0, summits])
	for f in range(1, 9):
		print("  ended on floor %d: %d" % [f, floors[f]])
	var keys: Array = losses.keys()
	keys.sort_custom(func(a, b): return losses[a] > losses[b])
	print("  most common losses: ", keys.slice(0, 8).map(func(k): return "%s x%d" % [k, losses[k]]))
	if summits > 0:
		print("  talismans in summit runs: ", talisman_wins)
	quit(0)

func play_move(round, policy: String) -> void:
	var best: Array = []
	var best_value: float = -INF
	for slot in range(3):
		var piece: Dictionary = round.tray[slot]
		if piece.is_empty():
			continue
		for y in range(8):
			for x in range(8):
				if not round.can_place(piece, x, y):
					continue
				if policy == "first":
					round.try_place(slot, x, y)
					return
				var preview: Dictionary = round.evaluate(piece, x, y)
				var value: float = float(preview.points) - (64 - preview.tiles.count(0)) * 0.5
				if value > best_value:
					best_value = value
					best = [slot, x, y]
	if best.is_empty():
		round.try_reroll()
	else:
		round.try_place(best[0], best[1], best[2])

func camp(run) -> void:
	if run.draft_open:
		var pick: int = 0
		for i in range(run.draft.size()):
			if Talismans.info(run.draft[i]).rarity > Talismans.info(run.draft[pick]).rarity:
				pick = i
		if not run.take_draft(pick):
			run.skip_draft()
	for i in range(run.shop.size()):
		if not run.shop[i].sold and run.coins - run.price(run.shop[i].id) >= 5:
			run.buy(i)
	# Additive talismans first, multipliers last.
	run.talismans.sort_custom(func(a, b): return int(MULTIPLIERS.has(a)) < int(MULTIPLIERS.has(b)))
	run.leave_camp()
