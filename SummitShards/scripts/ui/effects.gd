extends RefCounted
## Presentation-only animation state. The game state is already final when an
## effect starts, so skipping, interrupting or disabling effects never changes
## a score, a save or a move. Every list is capped.

const MAX_PARTICLES = 144
const MAX_TEXTS = 6
const POP_TIME = 0.18
const CLEAR_TIME = 0.38

var time: float = 0.0
var reduced_motion: bool = false
var pops: Dictionary = {}       # board index -> start time
var clears: Array = []          # {index, element, start}
var particles: Array = []       # {pos, vel, color, start, life, size}
var texts: Array = []           # {text, pos, color, size, start, life, rise}
var flashes: Dictionary = {}    # talisman slot -> start time
const FLASH_TIME = 0.6
var shake_start: float = -10.0
var shake_strength: float = 0.0
var _rng = RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 7

func active() -> bool:
	return not pops.is_empty() or not clears.is_empty() or not particles.is_empty() \
		or not texts.is_empty() or not flashes.is_empty() or time - shake_start < 0.3

func clear_all() -> void:
	pops.clear()
	clears.clear()
	particles.clear()
	texts.clear()
	flashes.clear()
	shake_start = -10.0

func update(delta: float) -> void:
	time += delta
	for index in pops.keys():
		if time - pops[index] > POP_TIME:
			pops.erase(index)
	clears = clears.filter(func(c): return time - c.start < CLEAR_TIME)
	particles = particles.filter(func(p): return time - p.start < p.life)
	texts = texts.filter(func(t): return time - t.start < t.life)
	for slot in flashes.keys():
		if time - flashes[slot] > FLASH_TIME:
			flashes.erase(slot)

## Lights up a talisman slot that changed a score. Kept with reduced motion:
## it carries information, and it fades rather than moves.
func add_flash(slot: int) -> void:
	flashes[slot] = time

func flash_alpha(slot: int) -> float:
	if not flashes.has(slot):
		return 0.0
	return clampf(1.0 - (time - flashes[slot]) / FLASH_TIME, 0.0, 1.0)

func add_pop(indices: Array) -> void:
	if reduced_motion:
		return
	for index in indices:
		pops[index] = time

func pop_scale(index: int) -> float:
	if not pops.has(index):
		return 1.0
	var t: float = clampf((time - pops[index]) / POP_TIME, 0.0, 1.0)
	# Overshoot slightly, then settle.
	return 0.72 + 0.28 * t + sin(t * PI) * 0.12

func add_clear(index: int, element: int, center: Vector2, color: Color) -> void:
	clears.append({"index": index, "element": element, "start": time})
	if reduced_motion:
		return
	for i in range(3):
		if particles.size() >= MAX_PARTICLES:
			particles.pop_front()
		var angle: float = _rng.randf_range(0.0, TAU)
		var speed: float = _rng.randf_range(140.0, 420.0)
		particles.append({"pos": center, "vel": Vector2(cos(angle), sin(angle)) * speed - Vector2(0, 160),
			"color": color, "start": time, "life": _rng.randf_range(0.45, 0.8), "size": _rng.randf_range(7.0, 14.0)})

func clear_progress(entry: Dictionary) -> float:
	return clampf((time - entry.start) / CLEAR_TIME, 0.0, 1.0)

func add_text(text: String, pos: Vector2, color: Color, font_size: int, life: float = 1.0, rise: float = 70.0) -> void:
	if texts.size() >= MAX_TEXTS:
		texts.pop_front()
	texts.append({"text": text, "pos": pos, "color": color, "size": font_size, "start": time,
		"life": life, "rise": 0.0 if reduced_motion else rise})

func text_state(entry: Dictionary) -> Dictionary:
	var t: float = clampf((time - entry.start) / entry.life, 0.0, 1.0)
	var alpha: float = clampf(t / 0.12, 0.0, 1.0) * clampf((1.0 - t) / 0.3, 0.0, 1.0)
	var grow: float = 1.0 if reduced_motion else 0.8 + 0.2 * clampf(t / 0.15, 0.0, 1.0)
	return {"pos": entry.pos - Vector2(0, entry.rise * (1.0 - pow(1.0 - t, 2.0))), "alpha": alpha, "scale": grow}

func particle_state(entry: Dictionary) -> Dictionary:
	var age: float = time - entry.start
	var pos: Vector2 = entry.pos + entry.vel * age + Vector2(0, 900.0) * age * age * 0.5
	return {"pos": pos, "alpha": clampf(1.0 - age / entry.life, 0.0, 1.0)}

func shake(strength: float) -> void:
	if reduced_motion:
		return
	shake_start = time
	shake_strength = strength

func shake_offset() -> Vector2:
	var age: float = time - shake_start
	if age >= 0.3 or reduced_motion:
		return Vector2.ZERO
	var fade: float = 1.0 - age / 0.3
	return Vector2(sin(age * 95.0), cos(age * 77.0)) * shake_strength * fade
