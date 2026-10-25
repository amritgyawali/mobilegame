extends Control
## Portrait touch adapter: screens, input, drawing, sound and local saves.
## Rules live in round_model.gd. Drawing and effects never change them: a move
## is committed and saved first, then animated.
##
## Drawing is split into layers that repaint only when their own content
## changes. Motion (drag, shake, fades, slides, tray refills) moves or fades a
## layer instead of repainting it, which keeps per-frame CPU work small on
## budget Android phones.

const Model = preload("res://scripts/round_model.gd")
const Settings = preload("res://scripts/settings_model.gd")
const Profile = preload("res://scripts/profile_model.gd")
const Store = preload("res://scripts/persistence/json_store.gd")
const Effects = preload("res://scripts/ui/effects.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")
const Run = preload("res://scripts/run_model.gd")
const Talismans = preload("res://scripts/content/talismans.gd")
const Encounters = preload("res://scripts/content/encounters.gd")

const INK = Color("18383d")
const DEEP = Color("122d32")
const CARD = Color("24464a")
const EDGE = Color("345457")
const EMPTY = Color("2a484a")
const CREAM = Color("f4f0df")
const MUTED = Color("a9b9af")
const GOLD = Color("e7bf73")
const CORAL = Color("ed9781")
# Tile colours: empty, Sky, Wind, Fire, Water, Earth, Stone, Cracked Stone.
const COLORS = [Color("2a484a"), Color("7bbde2"), Color("e6e4cd"), Color("ed9781"), Color("85bca1"), Color("d8ba78"), Color("7d8a86"), Color("66716e")]
const SYMBOLS = ["", "+", "o", "^", "~", "#", "", ""]

const HOME = "home"
const PLAY = "play"
const CAMP = "camp"
const QUICK = "quick"
const RUN = "run"
## Dialogs that wait for the clear animation before fading in.
const DELAYED_DIALOGS = ["result", "round_won", "run_over"]
const BOARD_RECT = Rect2(56, 330, 608, 608)
const CELL = 76.0
const TILE = 70.0
const PAUSE_RECT = Rect2(588, 20, 96, 96)
const HINT_RECT = Rect2(40, 944, 640, 50)
# 96 reference pixels = 48 dp at the 360 dp reference width: the minimum touch target.
const BUTTON_H = 96.0
const NEW_RECT = Rect2(40, 1172, 310, BUTTON_H)
const REROLL_RECT = Rect2(370, 1172, 310, BUTTON_H)
const TALISMAN_BAR = Rect2(40, 1172, 470, BUTTON_H)
const RUN_REROLL_RECT = Rect2(526, 1172, 154, BUTTON_H)
const BASE_TALISMAN_ICONS = 5
const CAMP_CHIPS_Y = 846.0
const DRAG_LIFT = 130.0
const DRAG_THRESHOLD = 14.0
const TRAY_PITCH_MAX = 36.0
const SCREEN_FADE = 0.18
const DIALOG_FADE = 0.16
## Glyphs drawn once, invisibly, shortly after launch so the first big clear
## or result screen does not stall while the font rasterizes them.
const PREWARM_TEXT = "+0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ x/"
const PREWARM_SIZES = [34, 42, 44, 46, 60, 92]
const SETTING_ROWS = [
	["sound", "Sound effects", "Chimes for placing and clearing."],
	["clear_preview", "Line preview", "Outline the lines a placement will clear."],
	["reduced_motion", "Reduced motion", "No shaking, bursts or floating text."],
	["battery_saver", "Battery saver", "Cap the game at 30 FPS."],
]
const HELP_LINES = [
	"Drag a shard onto the board. Or tap it, then tap where its top-left corner goes.",
	"Fill a row or column to clear it. Score = Base x Mult.",
	"More lines at once, pure lines (one symbol) and back-to-back clears raise Mult.",
	"Reach each round's target within its trays. An Expedition is 8 floors of Trail, Ridge and Guardian rounds.",
	"At Camp, take a free talisman, buy more, sell or reorder them. All +Base and +Mult count before any xMult.",
	"Stone fills a cell. A clear cracks it; a second clear breaks it.",
]
const STARS = [Vector2(70, 60), Vector2(160, 140), Vector2(250, 40), Vector2(330, 110), Vector2(420, 70),
	Vector2(480, 180), Vector2(640, 50), Vector2(690, 150), Vector2(110, 230), Vector2(600, 260),
	Vector2(370, 220), Vector2(40, 330), Vector2(520, 120), Vector2(210, 300), Vector2(680, 330)]

var round_state: RefCounted
var settings: RefCounted
var profile: RefCounted
var effects: RefCounted
var sfx: Node
var route: String = HOME
var mode: String = QUICK
## The Quick Trail round, kept while an expedition is being played.
var quick_round: RefCounted
var run: RefCounted
var run_path: String = "user://run-v1.json"
var last_run_summary: Dictionary = {}
## Camp: selected held talisman slot, and a draft card waiting for a slot.
var camp_selected: int = -1
var camp_pending: int = -1
var dialogs: Array = []
var dialog_opened_at: float = 0.0
var result_delay: float = 0.0
var last_summary: Dictionary = {}
var selected: int = -1
var hover_cell = Vector2i(-1, -1)
var notice: String = ""
var save_path: String = "user://round-v1.json"
var settings_path: String = "user://settings-v1.json"
var profile_path: String = "user://profile-v1.json"
## Tests set this to make new trails reproducible; negative means clock-seeded.
var fixed_seed: int = -1
var layout_scale: float = 1.0
var layout_offset = Vector2.ZERO
var font: Font
var bold: Font
var display_score: float = 0.0
var _style_cache: Dictionary = {}
var _last_saved_sha: String = ""
var _loaded_from_backup: bool = false
var _fits: Array = [true, true, true]
# Single-pointer gesture state. Touch emulates one mouse pointer, so a second
# finger never starts a second gesture.
var pointer_down: bool = false
var press_kind: String = ""
var press_id: String = ""
var press_slot: int = -1
var press_pos = Vector2.ZERO
var dragging: bool = false
var drag_point = Vector2.ZERO

# Drawing layers, back to front. All but the overlay sit under `content`,
# which carries the layout transform and the screen fade. They are Node2D
# because a Control repaints when scaled; a Node2D just moves on the GPU.
var content: Node2D
var chrome_layer: Node2D
var board_layer: Node2D
var preview_layer: Node2D
var hud_layer: Node2D
var score_layer: Node2D
var slot_layers: Array = []
var fx_layer: Node2D
var drag_layer: Node2D
var overlay_root: Node2D
var overlay_layer: Node2D
var canvas: CanvasItem
## Cumulative drawing cost per layer: {name: [passes, usec]}. Read by tests
## and tests/perf_probe.gd; costs two clock reads per repaint.
var perf: Dictionary = {}
var _low_power_default: bool = true
var _boost_until: float = 0.0
var _content_slide: float = 0.0
var _shown_score: int = -1
var _had_pops: bool = false
var _fx_dirty: bool = false
var _prewarm_pending: bool = false
var _returning_slot: int = -1
# True while a delayed dialog (the result) waits for its entrance. It stays
# hidden, and so unpainted, until then, keeping that paint out of the clear
# animation's frames.
var _overlay_waiting: bool = false
var _slot_pieces: Array = [{}, {}, {}]
var _preview_key: Array = []
var _preview: Dictionary = {}
var _tweens: Dictionary = {}

func _ready() -> void:
	font = ThemeDB.fallback_font
	var heavy = FontVariation.new()
	heavy.base_font = font
	heavy.variation_embolden = 0.8
	bold = heavy
	effects = Effects.new()
	sfx = Sfx.new()
	add_child(sfx)
	# From the project setting, not the live flag: an earlier scene may have
	# left it lifted mid-animation.
	_low_power_default = ProjectSettings.get_setting("application/run/low_processor_mode", true)
	build_layers()
	settings = Settings.new()
	settings.from_dict(Store.read(settings_path))
	profile = Profile.new()
	profile.from_dict(Store.read(profile_path))
	round_state = Model.new(20261024)
	quick_round = round_state
	load_round()
	load_run()
	# A round that finished just before the app was closed is counted on the
	# next launch; record_round ignores rounds already counted.
	record_if_finished()
	apply_settings()
	display_score = round_state.score
	refresh_derived()
	reset_notice()
	set_end_notice()
	get_tree().auto_accept_quit = false
	set_process(false)
	update_layout()
	refresh_view()
	# Warm the font cache once the first frame is on screen.
	get_tree().create_timer(0.3).timeout.connect(func():
		_prewarm_pending = true
		chrome_layer.queue_redraw())

func make_layer(parent: Node, layer_name: String, painter: Callable) -> Node2D:
	var layer = Node2D.new()
	layer.name = layer_name
	perf[layer_name] = [0, 0]
	layer.draw.connect(func(): paint(layer, layer_name, painter))
	parent.add_child(layer)
	return layer

func paint(layer: Node2D, layer_name: String, painter: Callable) -> void:
	var start: int = Time.get_ticks_usec()
	canvas = layer
	painter.call()
	perf[layer_name][0] += 1
	perf[layer_name][1] += Time.get_ticks_usec() - start

func build_layers() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content = Node2D.new()
	content.name = "Content"
	add_child(content)
	chrome_layer = make_layer(content, "chrome", paint_chrome)
	board_layer = make_layer(content, "board", paint_board)
	preview_layer = make_layer(content, "preview", paint_preview)
	hud_layer = make_layer(content, "hud", paint_hud)
	score_layer = make_layer(content, "score", paint_score)
	for slot in range(3):
		var layer: Node2D = make_layer(content, "slot%d" % slot, paint_slot.bind(slot))
		layer.position = tray_rect(slot).get_center()
		slot_layers.append(layer)
	fx_layer = make_layer(content, "fx", paint_fx)
	drag_layer = make_layer(content, "drag", paint_drag)
	drag_layer.visible = false
	overlay_root = Node2D.new()
	overlay_root.name = "Overlay"
	add_child(overlay_root)
	overlay_layer = make_layer(overlay_root, "overlay", paint_overlay)
	overlay_layer.visible = false

## Total repaint passes so far for the named layers (all layers if empty).
func draw_passes(names: Array = []) -> int:
	var total: int = 0
	for key in perf:
		if names.is_empty() or names.has(key):
			total += perf[key][0]
	return total

## Repaints every layer whose content may have changed after a command.
## Called once per tap or command, never per frame.
func refresh_view() -> void:
	_preview_key = []
	var playing_route: bool = route == PLAY
	board_layer.visible = playing_route
	preview_layer.visible = playing_route
	score_layer.visible = playing_route
	fx_layer.visible = playing_route
	for layer in slot_layers:
		# Hidden layers skip painting, so repaint slots when they reappear.
		if playing_route and not layer.visible:
			layer.queue_redraw()
		layer.visible = playing_route
	if not playing_route or (not dragging and _returning_slot < 0):
		drag_layer.visible = false
	overlay_layer.visible = not dialogs.is_empty() and not _overlay_waiting
	chrome_layer.queue_redraw()
	board_layer.queue_redraw()
	preview_layer.queue_redraw()
	hud_layer.queue_redraw()
	score_layer.queue_redraw()
	overlay_layer.queue_redraw()
	refresh_slots()
	_shown_score = int(display_score)

## Repaints a tray slot only when its shard changes, and animates new shards in.
func refresh_slots() -> void:
	for slot in range(3):
		var piece: Dictionary = round_state.tray[slot]
		var layer: Node2D = slot_layers[slot]
		if piece == _slot_pieces[slot]:
			continue
		_slot_pieces[slot] = piece.duplicate()
		layer.queue_redraw()
		if piece.is_empty() or route != PLAY or settings.get_value("reduced_motion"):
			stop_tween("slot%d" % slot)
			layer.scale = Vector2.ONE
			layer.modulate.a = 1.0
			continue
		layer.scale = Vector2.ONE * 0.55
		layer.modulate.a = 0.0
		var tween: Tween = restart_tween("slot%d" % slot)
		tween.set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(layer, "scale", Vector2.ONE, 0.26).set_delay(slot * 0.06)
		tween.tween_property(layer, "modulate:a", 1.0, 0.16).set_delay(slot * 0.06)
		boost(0.3 + slot * 0.06)
	update_slot_states()

## Dims shards that are being dragged, flying home or have no room. Uses
## self_modulate so it combines with the refill fade on modulate.
func update_slot_states() -> void:
	for slot in range(3):
		var layer: Node2D = slot_layers[slot]
		var dim: float = 1.0
		var lifted: float = 0.0
		if (dragging and selected == slot) or _returning_slot == slot:
			dim = 0.25
		elif not _fits[slot] and round_state.status == Model.PLAYING:
			dim = 0.35
			lifted = 6.0
		layer.self_modulate.a = dim
		layer.position = tray_rect(slot).get_center() - Vector2(0, lifted)

## Stops the named animation, if running, so a new one can take over.
func stop_tween(key: String) -> void:
	if _tweens.has(key):
		if _tweens[key].is_valid():
			_tweens[key].kill()
		_tweens.erase(key)

func restart_tween(key: String) -> Tween:
	stop_tween(key)
	var tween: Tween = create_tween()
	_tweens[key] = tween
	return tween

## Keeps frames flowing at full rate for `seconds` of tween-driven motion.
func boost(seconds: float) -> void:
	_boost_until = maxf(_boost_until, effects.time + seconds)
	start_animation()

## Fades and slides the whole screen in after Home <-> Play navigation.
func play_screen_transition() -> void:
	content.modulate.a = 0.0
	_content_slide = 0.0 if settings.get_value("reduced_motion") else 22.0
	place_content()
	var tween: Tween = restart_tween("screen")
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "modulate:a", 1.0, SCREEN_FADE)
	tween.tween_method(set_content_slide, _content_slide, 0.0, SCREEN_FADE)
	boost(SCREEN_FADE + 0.05)

func set_content_slide(value: float) -> void:
	_content_slide = value
	place_content()

## Fades and lifts the top dialog in, after the result screen's short delay.
func play_dialog_entrance() -> void:
	overlay_layer.modulate.a = 0.0
	overlay_layer.position = Vector2(0, 0 if settings.get_value("reduced_motion") else 26)
	var tween: Tween = restart_tween("dialog")
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_overlay_waiting = result_delay > 0.0
	overlay_layer.visible = not _overlay_waiting
	if _overlay_waiting:
		tween.tween_interval(result_delay)
		tween.tween_callback(reveal_overlay)
	tween.tween_property(overlay_layer, "modulate:a", 1.0, DIALOG_FADE)
	tween.parallel().tween_property(overlay_layer, "position", Vector2.ZERO, DIALOG_FADE + 0.04)
	boost(result_delay + DIALOG_FADE + 0.1)

func reveal_overlay() -> void:
	_overlay_waiting = false
	overlay_layer.visible = not dialogs.is_empty()
	overlay_layer.queue_redraw()
	hud_layer.queue_redraw()

# ---------------------------------------------------------------- lifecycle

func _exit_tree() -> void:
	OS.low_processor_usage_mode = _low_power_default

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_active()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif round_state == null:
		return
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_gesture()
		save_active()
		if what == NOTIFICATION_APPLICATION_PAUSED and route == PLAY and dialogs.is_empty() and round_state.status == Model.PLAYING:
			open_dialog("pause")
		refresh_view()
	elif what == NOTIFICATION_RESIZED:
		cancel_gesture()
		update_layout()
		refresh_view()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Safe areas can change while the app is away (rotation, cutout mode).
		update_layout()
		refresh_view()

## Android Back: cancel a gesture or selection, then close the top dialog, then
## pause gameplay, and finally ask before leaving from the home screen.
func handle_back() -> void:
	if dragging or pointer_down:
		cancel_gesture()
		selected = -1
		reset_notice()
	elif selected >= 0:
		selected = -1
		hover_cell = Vector2i(-1, -1)
		reset_notice()
	elif not dialogs.is_empty():
		# Dialogs that lead somewhere continue there instead of stranding the
		# player on a finished board.
		var forward: Dictionary = {"intro": "begin", "round_won": "to_camp", "run_over": "home"}
		if forward.has(dialogs.back()):
			if dialog_ready():
				activate(forward[dialogs.back()])
			return
		close_dialog()
	elif route == CAMP and (camp_selected >= 0 or camp_pending >= 0):
		camp_selected = -1
		camp_pending = -1
	elif route == PLAY or route == CAMP:
		save_active()
		open_dialog("pause")
	else:
		open_dialog("confirm_exit")
	refresh_view()

## Runs only while something moves. Each frame repaints just the effects layer
## and, when the shown number changes, the score; everything else is moved.
func _process(delta: float) -> void:
	effects.update(delta)
	var target: float = round_state.score
	if settings.get_value("reduced_motion") or absf(target - display_score) < 1.0:
		display_score = target
	else:
		display_score = move_toward(display_score, target, maxf(absf(target - display_score) * delta * 9.0, 60.0 * delta))
	if int(display_score) != _shown_score:
		_shown_score = int(display_score)
		score_layer.queue_redraw()
	var shake: Vector2 = effects.shake_offset()
	board_layer.position = shake
	preview_layer.position = shake
	fx_layer.position = shake
	var has_pops: bool = not effects.pops.is_empty()
	if _had_pops and not has_pops:
		board_layer.queue_redraw()
	_had_pops = has_pops
	var fx_active: bool = effects.active()
	if fx_active or _fx_dirty:
		fx_layer.queue_redraw()
	_fx_dirty = fx_active
	if not is_animating() and not dragging:
		set_process(false)
		OS.low_processor_usage_mode = _low_power_default

func is_animating() -> bool:
	return effects.active() or display_score != round_state.score or effects.time < _boost_until \
		or (not dialogs.is_empty() and effects.time - dialog_opened_at < result_delay + 0.3)

## Low-processor mode sleeps a little every frame to save battery. That suits
## a still board but costs smoothness, so it is lifted while anything animates
## or a finger drags, and restored as soon as everything is still.
func start_animation() -> void:
	OS.low_processor_usage_mode = false
	set_process(true)

func apply_settings() -> void:
	sfx.enabled = settings.get_value("sound")
	effects.reduced_motion = settings.get_value("reduced_motion")
	Engine.max_fps = 30 if settings.get_value("battery_saver") else 60

# ---------------------------------------------------------------- navigation

func open_dialog(id: String) -> void:
	dialogs.append(id)
	dialog_opened_at = effects.time
	result_delay = 0.0
	if DELAYED_DIALOGS.has(id) and not settings.get_value("reduced_motion"):
		result_delay = 0.8
	overlay_layer.queue_redraw()
	play_dialog_entrance()

func close_dialog() -> void:
	if not dialogs.is_empty():
		dialogs.pop_back()
	# The dialog beneath, if any, is already in place: show it without a replay.
	stop_tween("dialog")
	_overlay_waiting = false
	overlay_layer.modulate.a = 1.0
	overlay_layer.position = Vector2.ZERO
	overlay_layer.visible = not dialogs.is_empty()
	overlay_layer.queue_redraw()

func go_home() -> void:
	cancel_gesture()
	selected = -1
	dialogs.clear()
	close_dialog()
	save_active()
	route = HOME
	play_screen_transition()
	refresh_view()

func enter_play() -> void:
	if route != PLAY:
		route = PLAY
		play_screen_transition()
	reset_notice()
	set_end_notice()
	show_tutorial_once()

## Opens How to Play the first time any game starts, on top of everything.
func show_tutorial_once() -> void:
	if not profile.seen_tutorial:
		profile.seen_tutorial = true
		save_profile()
		open_dialog("help")

## A Quick Trail with progress on it.
func can_continue() -> bool:
	return quick_round.status == Model.PLAYING and (quick_round.moves > 0 or quick_round.rerolls == 0)

func next_seed() -> int:
	var seed_value: int = fixed_seed if fixed_seed >= 0 else int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	if fixed_seed >= 0:
		fixed_seed += 1
	return seed_value

## Switches to Quick Trail, keeping any expedition saved for later.
func enter_quick() -> void:
	if mode == RUN:
		save_run()
	mode = QUICK
	round_state = quick_round
	display_score = round_state.score
	effects.clear_all()
	refresh_derived()
	if round_state.status != Model.PLAYING:
		start_new_round()
	enter_play()

## Starts a fresh expedition at Floor 1.
func start_run() -> void:
	cancel_gesture()
	if mode == QUICK:
		save_round()
	run = Run.new(next_seed())
	last_run_summary = {}
	mode = RUN
	dialogs.clear()
	close_dialog()
	sync_run_round()
	save_run()
	route = PLAY
	play_screen_transition()
	open_dialog("intro")
	show_tutorial_once()

## Resumes the saved expedition where it stopped.
func enter_run() -> void:
	if run == null:
		return
	if mode == QUICK:
		save_round()
	mode = RUN
	dialogs.clear()
	close_dialog()
	sync_run_round()
	if run.phase == Run.CAMP:
		route = CAMP
		play_screen_transition()
	else:
		route = PLAY
		play_screen_transition()
		if run.phase == Run.INTRO:
			open_dialog("intro")
		show_tutorial_once()

## Points the board at the expedition's current round.
func sync_run_round() -> void:
	round_state = run.round
	selected = -1
	hover_cell = Vector2i(-1, -1)
	effects.clear_all()
	display_score = round_state.score
	_slot_pieces = [{}, {}, {}]
	refresh_derived()
	reset_notice()
	set_end_notice()

func record_run() -> void:
	if run == null:
		return
	var summary: Dictionary = profile.record_run(run.run_seed, run.phase == Run.WON, run.floor_reached(), run.rounds_won)
	if not summary.is_empty():
		last_run_summary = summary
		save_profile()

## Ending an expedition early counts as a played, lost run once it has begun.
func abandon_run() -> void:
	if run_active() and (run.rounds_won > 0 or run.round.moves > 0):
		run.phase = Run.LOST
		record_run()
	if run != null:
		run.phase = Run.LOST
		save_run()

## Starts a new Quick Trail round.
func start_new_round() -> void:
	cancel_gesture()
	quick_round = Model.new(next_seed())
	round_state = quick_round
	selected = -1
	hover_cell = Vector2i(-1, -1)
	effects.clear_all()
	display_score = 0
	last_summary = {}
	refresh_derived()
	reset_notice()
	save_round()

## Leaving a trail with moves on it counts as a played, lost trail.
func abandon_round() -> void:
	if round_state.status == Model.PLAYING and round_state.moves > 0:
		profile.record_round(round_state.seed_initial, false, round_state.score,
			round_state.lines_total, round_state.perfect_count, round_state.best_move)
		save_profile()

func activate(id: String) -> void:
	if id != "pause":
		sfx.play("tap")
	if id.begins_with("toggle:"):
		settings.toggle(id.substr(7))
		apply_settings()
		save_settings()
		refresh_view()
		return
	if route == CAMP and dialogs.is_empty() and camp_action(id):
		save_run()
		refresh_view()
		return
	match id:
		"quick":
			enter_quick()
		"run_new":
			if run_active() and (run.rounds_won > 0 or run.round.moves > 0):
				open_dialog("confirm_run_new")
			else:
				start_run()
		"confirm_run_new", "run_again":
			abandon_run()
			start_run()
		"run_continue":
			enter_run()
		"begin":
			if run != null and run.begin():
				save_run()
			close_dialog()
			reset_notice()
		"talismans":
			open_dialog("talismans")
		"to_camp":
			dialogs.clear()
			close_dialog()
			camp_selected = -1
			camp_pending = -1
			route = CAMP
			play_screen_transition()
		"confirm_abandon":
			abandon_run()
			last_run_summary = {}
			go_home()
		"continue":
			enter_play()
		"start":
			if round_state.status != Model.PLAYING:
				start_new_round()
			enter_play()
		"restart":
			if mode == RUN:
				open_dialog("confirm_abandon")
			elif round_state.status == Model.PLAYING and round_state.moves > 0:
				open_dialog("confirm_new")
			else:
				dialogs.clear()
				close_dialog()
				start_new_round()
				enter_play()
		"new":
			if round_state.status == Model.PLAYING and round_state.moves > 0:
				open_dialog("confirm_new")
			else:
				dialogs.clear()
				close_dialog()
				start_new_round()
				enter_play()
		"confirm_new", "next":
			abandon_round()
			dialogs.clear()
			close_dialog()
			start_new_round()
			enter_play()
		"pause":
			cancel_gesture()
			selected = -1
			save_active()
			open_dialog("pause")
		"reroll":
			reroll()
		"help":
			open_dialog("help")
		"settings":
			open_dialog("settings")
		"reset_stats":
			open_dialog("confirm_reset")
		"confirm_reset":
			profile.reset()
			save_profile()
			close_dialog()
		"home":
			go_home()
		"confirm_exit":
			save_active()
			get_tree().quit()
		"resume", "cancel", "done":
			close_dialog()
	refresh_view()

# ---------------------------------------------------------------- game commands

func commit_place(slot: int, cell: Vector2i) -> bool:
	var before: Array = round_state.board.duplicate()
	var result: Dictionary = round_state.try_place(slot, cell.x, cell.y)
	if not result.ok:
		notice = "That shard needs a little more room."
		sfx.play("invalid")
		return false
	selected = -1
	hover_cell = Vector2i(-1, -1)
	save_active()
	refresh_derived()
	play_move_feedback(result, before)
	after_command()
	refresh_view()
	return true

func reroll() -> void:
	if round_state.try_reroll():
		selected = -1
		cancel_gesture()
		notice = "Fresh shards. Make them count."
		sfx.play("select", 0.8)
		save_active()
		refresh_derived()
		after_command()
		refresh_view()

## Runs after every committed command: records a finished round exactly once
## and shows its result.
func after_command() -> void:
	if mode == RUN:
		after_run_command()
		return
	if round_state.status == Model.PLAYING:
		return
	set_end_notice()
	record_if_finished()
	sfx.play("win" if round_state.status == Model.WON else "lose")
	if dialogs.is_empty() or dialogs.back() != "result":
		open_dialog("result")

## Expedition rounds settle through the run: Camp, the next round after a
## Firebird save, or the end of the run.
func after_run_command() -> void:
	match run.after_round_command():
		"round_won":
			sfx.play("win")
			set_end_notice()
			open_dialog("round_won")
		"summit":
			sfx.play("win")
			record_run()
			open_dialog("run_over")
		"firebird":
			sfx.play("big", 0.8)
			sync_run_round()
			notice = "The Firebird Feather burns away. Try the round again."
			open_dialog("intro")
		"run_lost":
			sfx.play("lose")
			set_end_notice()
			record_run()
			open_dialog("run_over")
	save_run()

func record_if_finished() -> void:
	var quick = quick_round if quick_round != null else round_state
	if quick.status == Model.PLAYING:
		return
	var summary: Dictionary = profile.record_round(quick.seed_initial, quick.status == Model.WON,
		quick.score, quick.lines_total, quick.perfect_count, quick.best_move)
	if not summary.is_empty():
		last_summary = summary
		save_profile()

func play_move_feedback(result: Dictionary, before: Array) -> void:
	var placed: Array = result.placed
	var cleared: Array = result.cleared
	var center = Vector2.ZERO
	for index in placed:
		center += cell_rect(index).get_center()
	center /= maxf(1.0, placed.size())
	# Keep the popup inside the board so it never clips at an edge.
	center = center.clamp(BOARD_RECT.position + Vector2(90, 60), BOARD_RECT.end - Vector2(90, 30))
	var lines: int = int(result.lines)
	var survivors: Array = placed.filter(func(i): return not cleared.has(i))
	effects.add_pop(survivors)
	_had_pops = not effects.pops.is_empty()
	for index in cleared:
		var element: int = int(before[index]) if int(before[index]) != 0 else int(result.element)
		effects.add_clear(index, element, cell_rect(index).get_center(), COLORS[element])
	effects.add_text("+%d" % int(result.points), center, GOLD, 44, 0.9, 80.0)
	var callouts: Array = []
	if result.perfect:
		callouts.append("PERFECT CLEAR")
	if lines >= 2:
		callouts.append(["", "", "DOUBLE", "TRIPLE", "QUADRUPLE"][lines] if lines <= 4 else "%d LINES" % lines)
	if int(result.pure) > 0:
		callouts.append("PURE LINE" if int(result.pure) == 1 else "PURE x%d" % int(result.pure))
	if int(result.streak) >= 2:
		callouts.append("STREAK x%d" % int(result.streak))
	for i in range(callouts.size()):
		effects.add_text(callouts[i], BOARD_RECT.get_center() + Vector2(0, -40 + i * 64), CREAM if i > 0 else GOLD, 46 if i == 0 else 34, 1.2, 30.0)
	if result.perfect:
		effects.shake(16.0)
		sfx.play("big", 1.12)
	elif lines >= 2:
		effects.shake(minf(14.0, 5.0 * lines))
		sfx.play("big")
	elif lines == 1:
		sfx.play("clear", 1.0 + 0.06 * mini(6, int(result.streak)))
	else:
		sfx.play("place")
	# Show why: Base x Mult, and light up the talismans that changed it.
	notice = "+%s  =  %s x %s" % [fmt_int(result.points), fmt_int(result.base), fmt_mult(result.mult)]
	if lines > 0:
		notice += "  /  %d %s" % [lines, "line" if lines == 1 else "lines"]
	if int(result.get("coins_found", 0)) > 0:
		notice += "  /  +%d coin" % result.coins_found
	if mode == RUN:
		var triggered: Array = result.get("triggered", [])
		for slot in range(round_state.talismans.size()):
			var id: String = round_state.talismans[slot]
			if id == "mirror_lake" and slot + 1 < round_state.talismans.size():
				id = round_state.talismans[slot + 1]
			if triggered.has(id) and slot != round_state.disabled_slot():
				effects.add_flash(slot)
	_fx_dirty = true
	fx_layer.queue_redraw()
	start_animation()

## Camp buttons. Returns true when `id` was a Camp action.
func camp_action(id: String) -> bool:
	if run == null or run.phase != Run.CAMP:
		return false
	if id.begins_with("draft:"):
		var index: int = int(id.substr(6))
		if run.has_room():
			if run.take_draft(index):
				sfx.play("select")
				camp_pending = -1
		else:
			# Full: the next tapped slot is sold to make room.
			camp_pending = index if camp_pending != index else -1
			camp_selected = -1
		return true
	if id.begins_with("slot:"):
		var slot: int = int(id.substr(5))
		if camp_pending >= 0 and run.draft_open:
			if run.take_draft(camp_pending, slot):
				sfx.play("select")
			camp_pending = -1
			camp_selected = -1
		else:
			camp_selected = slot if camp_selected != slot else -1
		return true
	if id.begins_with("buy:"):
		if run.buy(int(id.substr(4))):
			sfx.play("select")
		else:
			sfx.play("invalid")
		return true
	match id:
		"skip":
			run.skip_draft()
			camp_pending = -1
		"reroll_shop":
			if not run.reroll_shop():
				sfx.play("invalid")
		"sell":
			if camp_selected >= 0 and run.sell(camp_selected):
				camp_selected = -1
		"move_left":
			if run.move(camp_selected, -1):
				camp_selected -= 1
		"move_right":
			if run.move(camp_selected, 1):
				camp_selected += 1
		"leave":
			if run.leave_camp():
				camp_selected = -1
				camp_pending = -1
				sync_run_round()
				route = PLAY
				play_screen_transition()
				open_dialog("intro")
		_:
			return false
	return true

## "1,234" for whole numbers.
static func fmt_int(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

## A multiplier with at most two decimals and no trailing zeros.
static func fmt_mult(value: float) -> String:
	var text: String = "%.2f" % value
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	return text.trim_suffix(".")

## Recomputes which tray pieces still fit, and the blocked-tray hint.
func refresh_derived() -> void:
	for slot in range(3):
		var piece: Dictionary = round_state.tray[slot]
		_fits[slot] = piece.is_empty() or round_state.fits_anywhere(piece)

func reset_notice() -> void:
	notice = "Drag a shard onto the board, or tap it, then tap a cell."
	if round_state != null and round_state.status == Model.PLAYING and not round_state.has_legal_move() and round_state.rerolls > 0:
		notice = "No room for these shards. Use your reroll."

func set_end_notice() -> void:
	if round_state.status == Model.WON:
		notice = "Trail complete. The summit can wait."
	elif round_state.status == Model.LOST:
		notice = "Rest here. A fresh trail is one tap away."

# ---------------------------------------------------------------- input

## Layout is cached and updated on resize/resume, so pointer events never
## query the display (a JNI round trip on Android) per motion event.
func to_reference(point: Vector2) -> Vector2:
	return (point - layout_offset) / layout_scale

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_pressed(to_reference(event.position))
		else:
			pointer_released(to_reference(event.position))
	elif event is InputEventMouseMotion:
		pointer_moved(to_reference(event.position), (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)

## A complete tap at a reference-layout point.
func handle_click(point: Vector2) -> void:
	pointer_pressed(point)
	pointer_released(point)

func pointer_pressed(point: Vector2) -> void:
	pointer_down = true
	press_pos = point
	press_kind = ""
	dragging = false
	var hit: Dictionary = button_at(point)
	if not hit.is_empty():
		if hit.get("enabled", true) and dialog_ready():
			press_kind = "button"
			press_id = hit.id
			repaint_controls()
		return
	if not dialogs.is_empty() or route != PLAY or round_state.status != Model.PLAYING:
		return
	var slot: int = slot_at(point)
	if slot >= 0 and not round_state.tray[slot].is_empty():
		press_kind = "slot"
		press_slot = slot
		drag_point = point
	elif selected >= 0 and BOARD_RECT.has_point(point):
		press_kind = "board"
		set_hover(board_cell(point))

func pointer_moved(point: Vector2, held: bool) -> void:
	if not held or not pointer_down:
		# Mouse hover previews the selected shard on desktop development builds.
		if route == PLAY and dialogs.is_empty() and selected >= 0 and round_state.status == Model.PLAYING:
			set_hover(board_cell(point) if BOARD_RECT.has_point(point) else Vector2i(-1, -1))
		return
	if press_kind == "slot":
		if not dragging and point.distance_to(press_pos) > DRAG_THRESHOLD:
			begin_drag(point)
		if dragging:
			# Moving the finger only moves the drag layer; the board and the
			# score hint repaint just when the snapped cell changes.
			drag_point = point
			drag_layer.position = point
			set_hover(drag_anchor(press_slot, point))
	elif press_kind == "board":
		set_hover(board_cell(point) if BOARD_RECT.has_point(point) else Vector2i(-1, -1))

func pointer_released(point: Vector2) -> void:
	if not pointer_down:
		return
	pointer_down = false
	var kind: String = press_kind
	press_kind = ""
	if kind == "button":
		var hit: Dictionary = button_at(point)
		if not hit.is_empty() and hit.id == press_id:
			activate(press_id)
	elif kind == "slot":
		if dragging:
			dragging = false
			var cell: Vector2i = drag_anchor(press_slot, point)
			if round_state.can_place(round_state.tray[press_slot], cell.x, cell.y) and commit_place(press_slot, cell):
				drag_layer.visible = false
			else:
				selected = -1
				hover_cell = Vector2i(-1, -1)
				notice = "No room there. The shard is back in your tray."
				sfx.play("invalid")
				return_drag_to_tray(press_slot)
		elif selected == press_slot:
			selected = -1
			reset_notice()
		else:
			selected = press_slot
			hover_cell = Vector2i(-1, -1)
			notice = "Tap where its top-left corner goes. Hold to preview."
			sfx.play("select")
	elif kind == "board" and selected >= 0:
		if BOARD_RECT.has_point(point):
			commit_place(selected, board_cell(point))
		hover_cell = Vector2i(-1, -1)
	refresh_view()

## Lifts a tray shard under the finger: it grows from tray size to board size
## as it rises above the finger.
func begin_drag(point: Vector2) -> void:
	dragging = true
	selected = press_slot
	drag_point = point
	sfx.play("select")
	_returning_slot = -1
	drag_layer.position = point
	drag_layer.modulate.a = 1.0
	drag_layer.visible = true
	drag_layer.queue_redraw()
	start_animation()
	stop_tween("drag")
	if settings.get_value("reduced_motion"):
		drag_layer.scale = Vector2.ONE
	else:
		drag_layer.scale = Vector2.ONE * tray_pitch(round_state.tray[press_slot]) / CELL
		var tween: Tween = restart_tween("drag")
		tween.tween_property(drag_layer, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	update_slot_states()
	hud_layer.queue_redraw()

## Flies a released, unplaceable shard back into its tray slot.
func return_drag_to_tray(slot: int) -> void:
	if settings.get_value("reduced_motion") or not drag_layer.visible:
		stop_tween("drag")
		drag_layer.visible = false
		return
	_returning_slot = slot
	var tray_scale: float = tray_pitch(round_state.tray[slot]) / CELL
	# The layer draws the shard DRAG_LIFT above its origin, scaled with it.
	var target: Vector2 = tray_rect(slot).get_center() + Vector2(0, DRAG_LIFT * tray_scale)
	var tween: Tween = restart_tween("drag")
	tween.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(drag_layer, "position", target, 0.18)
	tween.tween_property(drag_layer, "scale", Vector2.ONE * tray_scale, 0.18)
	tween.chain().tween_callback(finish_drag_return)
	boost(0.25)

func finish_drag_return() -> void:
	drag_layer.visible = false
	_returning_slot = -1
	update_slot_states()

## Cancels an in-progress gesture without consuming a piece.
func cancel_gesture() -> void:
	if dragging:
		selected = -1
		stop_tween("drag")
		drag_layer.visible = false
	pointer_down = false
	press_kind = ""
	dragging = false
	hover_cell = Vector2i(-1, -1)
	if _returning_slot >= 0:
		stop_tween("drag")
		finish_drag_return()
	update_slot_states()

func set_hover(cell: Vector2i) -> void:
	if cell != hover_cell:
		hover_cell = cell
		preview_layer.queue_redraw()
		score_layer.queue_redraw()

## Repaints whichever layer holds the visible buttons (press feedback).
func repaint_controls() -> void:
	if dialogs.is_empty():
		hud_layer.queue_redraw()
	else:
		overlay_layer.queue_redraw()

func dialog_ready() -> bool:
	return dialogs.is_empty() or effects.time - dialog_opened_at >= result_delay

func board_cell(point: Vector2) -> Vector2i:
	return Vector2i(clampi(int((point.x - BOARD_RECT.position.x) / CELL), 0, 7), clampi(int((point.y - BOARD_RECT.position.y) / CELL), 0, 7))

func slot_at(point: Vector2) -> int:
	for slot in range(3):
		if tray_rect(slot).has_point(point):
			return slot
	return -1

func piece_extent(piece: Dictionary) -> Vector2i:
	var extent = Vector2i.ONE
	if piece.is_empty():
		return extent
	for cell in round_state.shapes[int(piece.shape)].cells:
		extent = extent.max(cell + Vector2i.ONE)
	return extent

## Cell pitch for a shard shown in a tray slot.
func tray_pitch(piece: Dictionary) -> float:
	var extent: Vector2i = piece_extent(piece)
	return minf(TRAY_PITCH_MAX, 130.0 / maxi(extent.x, extent.y))

## The board cell under a dragged shard's top-left corner. The shard floats
## above the finger so the finger never hides where it will land.
func drag_anchor(slot: int, finger: Vector2) -> Vector2i:
	var extent: Vector2 = Vector2(piece_extent(round_state.tray[slot])) * CELL
	var top_left: Vector2 = finger - Vector2(extent.x * 0.5, extent.y * 0.5 + DRAG_LIFT)
	var cell: Vector2 = ((top_left - BOARD_RECT.position) / CELL).round()
	return Vector2i(int(cell.x), int(cell.y))

## Inverse of drag_anchor: where a finger must be for a shard to land at `cell`.
func finger_for_anchor(slot: int, cell: Vector2i) -> Vector2:
	var extent: Vector2 = Vector2(piece_extent(round_state.tray[slot])) * CELL
	return BOARD_RECT.position + Vector2(cell) * CELL + Vector2(extent.x * 0.5, extent.y * 0.5 + DRAG_LIFT)

# ---------------------------------------------------------------- buttons

func make_button(id: String, rect: Rect2, label: String, kind: String = "ghost", extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"id": id, "rect": rect, "label": label, "kind": kind}
	data.merge(extra)
	return data

## The tappable controls on screen. Drawing and hit-testing share this list,
## and only the top dialog's controls exist while a dialog is open.
func current_buttons() -> Array:
	if not dialogs.is_empty():
		return dialog_buttons(dialogs.back())
	return screen_buttons()

func screen_buttons() -> Array:
	if route == HOME:
		var list: Array = []
		if run_active():
			list.append(make_button("run_continue", Rect2(80, 830, 560, 112), "CONTINUE EXPEDITION", "primary",
				{"sub": run_progress_text()}))
			list.append(make_button("run_new", Rect2(80, 958, 272, BUTTON_H), "NEW RUN", "secondary"))
			list.append(make_button("quick", Rect2(368, 958, 272, BUTTON_H), "QUICK TRAIL"))
		else:
			list.append(make_button("run_new", Rect2(80, 830, 560, 112), "START EXPEDITION", "primary",
				{"sub": "8 floors  -  talismans  -  Guardians"}))
			list.append(make_button("quick", Rect2(80, 958, 560, BUTTON_H), "CONTINUE QUICK TRAIL" if can_continue() else "QUICK TRAIL"))
		list.append(make_button("help", Rect2(80, 1070, 272, BUTTON_H), "HOW TO PLAY"))
		list.append(make_button("settings", Rect2(368, 1070, 272, BUTTON_H), "SETTINGS"))
		return list
	if route == CAMP:
		return camp_buttons()
	var playing: bool = round_state.status == Model.PLAYING
	if mode == RUN:
		return [
			make_button("pause", PAUSE_RECT, "", "icon"),
			make_button("talismans", TALISMAN_BAR, "", "talisman_bar"),
			make_button("reroll", RUN_REROLL_RECT, "REROLL %d" % round_state.rerolls, "secondary", {"enabled": playing and round_state.rerolls > 0}),
		]
	return [
		make_button("pause", PAUSE_RECT, "", "icon"),
		make_button("new", NEW_RECT, "NEW TRAIL", "primary"),
		make_button("reroll", REROLL_RECT, "REROLL  %d" % round_state.rerolls, "secondary", {"enabled": playing and round_state.rerolls > 0}),
	]

func run_progress_text() -> String:
	if run == null:
		return ""
	return "Floor %d %s  -  %s coins  -  %d talismans" % [run.floor_reached(), Encounters.STAGE_NAMES[run.stage],
		fmt_int(run.coins), run.talismans.size()]

## Where held talisman `slot` sits in a row of `count` chips across `area`.
func chip_rect(area: Rect2, slot: int, count: int, max_size: float) -> Rect2:
	var gap: float = 10.0
	var width: float = minf(max_size, (area.size.x - gap * (count - 1)) / maxi(1, count))
	return Rect2(area.position.x + slot * (width + gap), area.position.y, width, area.size.y)

func talisman_icon_rect(slot: int) -> Rect2:
	var count: int = maxi(BASE_TALISMAN_ICONS, round_state.talismans.size())
	var area = Rect2(TALISMAN_BAR.position + Vector2(12, 16), Vector2(TALISMAN_BAR.size.x - 24, TALISMAN_BAR.size.y - 32))
	var rect: Rect2 = chip_rect(area, slot, count, 76)
	return Rect2(rect.position, Vector2(rect.size.x, area.size.y))

func camp_buttons() -> Array:
	var list: Array = [make_button("pause", PAUSE_RECT, "", "icon")]
	if run == null:
		return list
	var held: int = run.talismans.size()
	var chip_area = Rect2(40, CAMP_CHIPS_Y, 640, 112)
	for slot in range(held):
		list.append(make_button("slot:%d" % slot, chip_rect(chip_area, slot, run.slots(), 112), "", "chip",
			{"talisman": run.talismans[slot], "selected": camp_selected == slot or camp_pending >= 0}))
	if run.draft_open:
		for i in range(run.draft.size()):
			list.append(make_button("draft:%d" % i, Rect2(40, 210 + i * 204, 640, 190), "", "card",
				{"talisman": run.draft[i], "selected": camp_pending == i, "tag": "FREE" if run.has_room() else "SWAP"}))
		list.append(make_button("skip", Rect2(40, 1172, 640, BUTTON_H), "SKIP  +%d COINS" % Run.SKIP_COINS, "secondary"))
		return list
	list.append(make_button("reroll_shop", Rect2(480, 132, 200, BUTTON_H), "REROLL %d" % run.reroll_cost(), "secondary",
		{"enabled": run.coins >= run.reroll_cost()}))
	for i in range(run.shop.size()):
		var offer: Dictionary = run.shop[i]
		var cost: int = run.price(offer.id)
		var tag: String = "SOLD" if offer.sold else ("FULL" if not run.has_room() else "%d" % cost)
		list.append(make_button("buy:%d" % i, Rect2(40, 244 + i * 176, 640, 160), "", "offer",
			{"talisman": offer.id, "tag": tag, "enabled": not offer.sold and run.has_room() and run.coins >= cost}))
	if camp_selected >= 0 and camp_selected < held:
		list.append(make_button("move_left", Rect2(40, 1060, 140, BUTTON_H), "<", "ghost", {"enabled": camp_selected > 0}))
		list.append(make_button("move_right", Rect2(196, 1060, 140, BUTTON_H), ">", "ghost", {"enabled": camp_selected < held - 1}))
		var id: String = run.talismans[camp_selected]
		var can_sell: bool = id != "ninth_peak" or held - 1 <= run.slots() - 2
		list.append(make_button("sell", Rect2(352, 1060, 328, BUTTON_H), "SELL  +%d" % Talismans.sell_price(id), "danger", {"enabled": can_sell}))
	var next_stage: int = (run.stage + 1) % 3
	var next_floor: int = run.floor_index + (1 if run.stage == Encounters.GUARDIAN else 0) + 1
	list.append(make_button("leave", Rect2(40, 1172, 640, BUTTON_H), "CLIMB ON  -  FLOOR %d %s" % [next_floor, Encounters.STAGE_NAMES[next_stage].to_upper()], "primary"))
	return list

func dialog_card(id: String) -> Rect2:
	match id:
		"pause":
			return Rect2(90, 270, 540, 740)
		"settings":
			return Rect2(50, 200, 620, 880)
		"help":
			return Rect2(50, 110, 620, 1060)
		"result", "run_over":
			return Rect2(70, 230, 580, 820)
		"intro":
			return Rect2(70, 250, 580, 760)
		"round_won":
			return Rect2(70, 280, 580, 700)
		"talismans":
			return Rect2(40, 120, 640, 1040)
	return Rect2(90, 440, 540, 400)

func dialog_buttons(id: String) -> Array:
	var card: Rect2 = dialog_card(id)
	var x: float = card.position.x + 40
	var width: float = card.size.x - 80
	match id:
		"pause":
			var list: Array = []
			var entries = [["resume", "RESUME", "primary"], ["help", "HOW TO PLAY", "ghost"], ["settings", "SETTINGS", "ghost"],
				["restart", "ABANDON RUN" if mode == RUN else "NEW TRAIL", "ghost"], ["home", "HOME", "ghost"]]
			for i in range(entries.size()):
				list.append(make_button(entries[i][0], Rect2(x, card.position.y + 160 + i * 110, width, BUTTON_H), entries[i][1], entries[i][2]))
			return list
		"settings":
			var list: Array = []
			for i in range(SETTING_ROWS.size()):
				var row = SETTING_ROWS[i]
				list.append(make_button("toggle:" + row[0], Rect2(x, card.position.y + 120 + i * 128, width, 112), row[1], "toggle",
					{"sub": row[2], "value": settings.get_value(row[0])}))
			list.append(make_button("reset_stats", Rect2(x, card.end.y - 228, width, BUTTON_H), "RESET STATISTICS", "danger"))
			list.append(make_button("done", Rect2(x, card.end.y - 120, width, BUTTON_H), "DONE", "primary"))
			return list
		"help":
			return [make_button("done", Rect2(x, card.end.y - 120, width, BUTTON_H), "GOT IT", "primary")]
		"result":
			var half: float = (width - 20) * 0.5
			return [make_button("home", Rect2(x, card.end.y - 120, half, BUTTON_H), "HOME", "ghost"),
				make_button("next", Rect2(x + half + 20, card.end.y - 120, half, BUTTON_H), "NEXT TRAIL", "primary")]
		"run_over":
			var half: float = (width - 20) * 0.5
			return [make_button("home", Rect2(x, card.end.y - 120, half, BUTTON_H), "HOME", "ghost"),
				make_button("run_again", Rect2(x + half + 20, card.end.y - 120, half, BUTTON_H), "NEW RUN", "primary")]
		"intro":
			return [make_button("begin", Rect2(x, card.end.y - 120, width, BUTTON_H), "BEGIN", "primary")]
		"round_won":
			return [make_button("to_camp", Rect2(x, card.end.y - 120, width, BUTTON_H), "TO CAMP", "primary")]
		"talismans":
			return [make_button("done", Rect2(x, card.end.y - 120, width, BUTTON_H), "DONE", "primary")]
	var confirm_label: String = {"confirm_new": "START NEW", "confirm_exit": "EXIT", "confirm_reset": "RESET",
		"confirm_run_new": "START NEW", "confirm_abandon": "ABANDON"}.get(id, "OK")
	var half_width: float = (width - 20) * 0.5
	return [make_button("cancel", Rect2(x, card.end.y - 120, half_width, BUTTON_H), "CANCEL", "ghost"),
		make_button(id, Rect2(x + half_width + 20, card.end.y - 120, half_width, BUTTON_H), confirm_label, "danger" if id != "confirm_exit" else "primary")]

func button_at(point: Vector2) -> Dictionary:
	for entry in current_buttons():
		if entry.rect.has_point(point):
			return entry
	return {}

# ---------------------------------------------------------------- layout

## Fits the 720x1280 reference layout into the Android safe area. Only runs on
## start, resize and resume; the result is applied as layer transforms.
func update_layout() -> void:
	var safe = Rect2(Vector2.ZERO, size)
	if OS.get_name() == "Android":
		var physical = Vector2(DisplayServer.window_get_size())
		var area = DisplayServer.get_display_safe_area()
		if physical.x > 0 and physical.y > 0:
			var conversion = size / physical
			safe = Rect2(Vector2(area.position) * conversion, Vector2(area.size) * conversion)
	if safe.size.x <= 0 or safe.size.y <= 0:
		safe = Rect2(Vector2.ZERO, Vector2(720, 1280))
	layout_scale = minf(safe.size.x / 720.0, safe.size.y / 1280.0)
	# Centre horizontally. On screens taller than 9:16, sit a little low so
	# the tray and buttons are nearer the thumb, while keeping some room above
	# the system's bottom-edge gesture area.
	var spare: Vector2 = safe.size - Vector2(720, 1280) * layout_scale
	layout_offset = safe.position + Vector2(spare.x * 0.5, spare.y * 0.65)
	place_content()
	overlay_root.position = layout_offset
	overlay_root.scale = Vector2.ONE * layout_scale
	queue_redraw()

func place_content() -> void:
	content.position = layout_offset + Vector2(0, _content_slide * layout_scale)
	content.scale = Vector2.ONE * layout_scale

# ---------------------------------------------------------------- drawing helpers
# All helpers draw on `canvas`, the layer currently being painted.

func label_at(text: String, point: Vector2, font_size: int, color: Color = CREAM, heavy: bool = false) -> void:
	canvas.draw_string(bold if heavy else font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func text_width(text: String, font_size: int, heavy: bool = false) -> float:
	return (bold if heavy else font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func centered(text: String, rect: Rect2, font_size: int, color: Color = CREAM, heavy: bool = false) -> void:
	label_at(text, Vector2(rect.get_center().x - text_width(text, font_size, heavy) * 0.5, rect.get_center().y + font_size * 0.34), font_size, color, heavy)

func right_aligned(text: String, right: float, baseline: float, font_size: int, color: Color = CREAM, heavy: bool = false) -> void:
	label_at(text, Vector2(right - text_width(text, font_size, heavy), baseline), font_size, color, heavy)

func wrapped(text: String, origin: Vector2, width: float, font_size: int, color: Color = CREAM) -> float:
	canvas.draw_multiline_string(font, origin + Vector2(0, font_size), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, color)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y

func panel(color: Color, radius: int, border_color: Color = Color.TRANSPARENT, border: int = 0) -> StyleBoxFlat:
	# Reuse immutable drawing resources instead of allocating a style per tile
	# on every frame. Alpha is quantized so fades reuse a bounded set, and the
	# key is a value type so lookups do not build strings.
	color.a = snappedf(color.a, 0.0625)
	border_color.a = snappedf(border_color.a, 0.0625)
	var key = Vector4i(color.to_rgba32(), radius, border_color.to_rgba32(), border)
	var cached = _style_cache.get(key)
	if cached != null:
		return cached
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border_color
	style.set_border_width_all(border)
	style.anti_aliasing = true
	_style_cache[key] = style
	return style

func with_alpha(color: Color, alpha: float) -> Color:
	color.a *= alpha
	return color

func tile_at(rect: Rect2, element: int, alpha: float = 1.0, grow_scale: float = 1.0) -> void:
	if grow_scale != 1.0:
		rect = rect.grow(rect.size.x * (grow_scale - 1.0) * 0.5)
	var radius: int = 10 if rect.size.x > 40 else 5
	canvas.draw_style_box(panel(with_alpha(COLORS[element], alpha), radius), rect)
	if element == 0:
		return
	if element >= Model.STONE:
		# Stone: a few chiselled marks. Cracked Stone: a jagged split.
		var a: Vector2 = rect.position
		var w: float = rect.size.x
		var ink: Color = with_alpha(Color(0.12, 0.15, 0.15), 0.55 * alpha)
		if element == Model.STONE:
			canvas.draw_line(a + Vector2(w * 0.22, w * 0.3), a + Vector2(w * 0.45, w * 0.3), ink, 3, true)
			canvas.draw_line(a + Vector2(w * 0.55, w * 0.62), a + Vector2(w * 0.8, w * 0.62), ink, 3, true)
			canvas.draw_line(a + Vector2(w * 0.25, w * 0.75), a + Vector2(w * 0.4, w * 0.75), ink, 3, true)
		else:
			canvas.draw_polyline(PackedVector2Array([a + Vector2(w * 0.5, w * 0.08), a + Vector2(w * 0.38, w * 0.38),
				a + Vector2(w * 0.6, w * 0.55), a + Vector2(w * 0.42, w * 0.92)]), ink, 4, true)
		return
	# A soft top highlight gives each shard a little depth.
	canvas.draw_style_box(panel(Color(1, 1, 1, 0.2 * alpha), radius), Rect2(rect.position + Vector2(4, 3), Vector2(rect.size.x - 8, rect.size.y * 0.3)))
	var symbol_size: int = maxi(14, int(rect.size.y / grow_scale * 0.45))
	centered(SYMBOLS[element], rect, symbol_size, with_alpha(INK, alpha), true)

func cell_rect(index: int) -> Rect2:
	return Rect2(BOARD_RECT.position + Vector2(index % 8, index / 8) * CELL + Vector2(3, 3), Vector2(TILE, TILE))

func tray_rect(slot: int) -> Rect2:
	return Rect2(40 + slot * 222, 1002, 204, 156)

func draw_button(entry: Dictionary) -> void:
	var rect: Rect2 = entry.rect
	var enabled: bool = entry.get("enabled", true)
	var pressed: bool = pointer_down and press_kind == "button" and press_id == entry.id
	if pressed:
		rect = rect.grow(-3)
	var kind: String = entry.kind if enabled or entry.kind == "offer" else "disabled"
	match kind:
		"card":
			draw_talisman_card(entry, rect)
		"offer":
			draw_offer(entry, rect, enabled)
		"chip":
			var selected_chip: bool = entry.get("selected", false)
			draw_badge(rect.grow(-2), entry.talisman)
			if selected_chip:
				canvas.draw_style_box(panel(Color.TRANSPARENT, 18, GOLD, 4), rect.grow(2))
		"talisman_bar":
			draw_talisman_bar(rect)
		"primary":
			canvas.draw_style_box(panel(CREAM.darkened(0.08) if pressed else CREAM, 18), rect)
			centered(entry.label, rect if not entry.has("sub") else Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.62)), 28, INK, true)
			if entry.has("sub"):
				centered(entry.sub, Rect2(rect.position + Vector2(0, rect.size.y * 0.5), Vector2(rect.size.x, rect.size.y * 0.42)), 20, EDGE)
		"secondary":
			canvas.draw_style_box(panel(EDGE, 18, GOLD, 2), rect)
			centered(entry.label, rect, 26, GOLD, true)
		"danger":
			canvas.draw_style_box(panel(Color("3a3436"), 18, CORAL, 2), rect)
			centered(entry.label, rect, 24, CORAL, true)
		"disabled":
			canvas.draw_style_box(panel(Color("213c40"), 18, with_alpha(MUTED, 0.5), 1), rect)
			centered(entry.label, rect, 26, MUTED, true)
		"icon":
			rect = rect.grow(-8)
			canvas.draw_style_box(panel(CARD, 20, EDGE, 2), rect)
			var c: Vector2 = rect.get_center()
			canvas.draw_style_box(panel(CREAM, 3), Rect2(c + Vector2(-14, -16), Vector2(9, 32)))
			canvas.draw_style_box(panel(CREAM, 3), Rect2(c + Vector2(5, -16), Vector2(9, 32)))
		"toggle":
			canvas.draw_style_box(panel(DEEP, 16), rect)
			label_at(entry.label, rect.position + Vector2(24, 46), 27, CREAM, true)
			label_at(entry.sub, rect.position + Vector2(24, 84), 19, MUTED)
			var track = Rect2(rect.end.x - 112, rect.get_center().y - 22, 88, 44)
			canvas.draw_style_box(panel(GOLD if entry.value else EDGE, 22), track)
			var knob_x: float = track.end.x - 40 if entry.value else track.position.x + 4
			canvas.draw_style_box(panel(CREAM if entry.value else MUTED, 18), Rect2(knob_x, track.position.y + 4, 36, 36))
		_:
			canvas.draw_style_box(panel(CARD, 18, EDGE, 2), rect)
			centered(entry.label, rect, 25, CREAM, true)

## A talisman's badge: archetype colour, rarity rim and its two letters.
func draw_badge(rect: Rect2, id: String, alpha: float = 1.0) -> void:
	var info: Dictionary = Talismans.info(id)
	var radius: int = int(clampf(rect.size.y * 0.22, 6, 20))
	canvas.draw_style_box(panel(with_alpha(Talismans.color(id), alpha), radius, with_alpha(Talismans.RARITY_COLORS[int(info.rarity)], alpha), 3), rect)
	centered(info.code, rect, int(clampf(minf(rect.size.x, rect.size.y) * 0.38, 12, 40)), with_alpha(INK, alpha), true)

func draw_talisman_card(entry: Dictionary, rect: Rect2) -> void:
	var id: String = entry.talisman
	var info: Dictionary = Talismans.info(id)
	var picked: bool = entry.get("selected", false)
	canvas.draw_style_box(panel(Color("2b5054") if picked else CARD, 20, GOLD if picked else with_alpha(Talismans.RARITY_COLORS[int(info.rarity)], 0.7), 3 if picked else 2), rect)
	draw_badge(Rect2(rect.position + Vector2(20, 22), Vector2(96, 96)), id)
	label_at(info.name, rect.position + Vector2(136, 50), 29, CREAM, true)
	label_at("%s  -  %s" % [Talismans.RARITY_NAMES[int(info.rarity)], info.group], rect.position + Vector2(136, 80), 19, MUTED)
	wrapped(info.text, rect.position + Vector2(136, 90), rect.size.x - 160, 22, CREAM)
	if entry.has("tag"):
		var tag = Rect2(rect.end.x - 92, rect.position.y + 16, 76, 30)
		canvas.draw_style_box(panel(with_alpha(GOLD, 0.2), 15, GOLD, 1), tag)
		centered(entry.tag, tag, 16, GOLD, true)

func draw_offer(entry: Dictionary, rect: Rect2, enabled: bool) -> void:
	var id: String = entry.talisman
	var info: Dictionary = Talismans.info(id)
	var sold: bool = entry.tag == "SOLD"
	var alpha: float = 0.45 if sold else 1.0
	canvas.draw_style_box(panel(CARD, 18, EDGE, 1), rect)
	draw_badge(Rect2(rect.position + Vector2(16, (rect.size.y - 84) * 0.5), Vector2(84, 84)), id, alpha)
	label_at(info.name, rect.position + Vector2(118, 48), 26, with_alpha(CREAM, alpha), true)
	label_at("%s  -  %s" % [Talismans.RARITY_NAMES[int(info.rarity)], info.group], rect.position + Vector2(118, 76), 18, with_alpha(MUTED, alpha))
	wrapped(info.text, rect.position + Vector2(118, 84), rect.size.x - 270, 20, with_alpha(CREAM, alpha))
	var tag = Rect2(rect.end.x - 136, rect.position.y + (rect.size.y - 72) * 0.5, 120, 72)
	if sold or entry.tag == "FULL":
		centered(entry.tag, tag, 22, MUTED, true)
		return
	canvas.draw_style_box(panel(GOLD if enabled else Color("3a3436"), 16, GOLD if enabled else CORAL, 2), tag)
	draw_coin(tag.position + Vector2(34, 36), 15)
	label_at(entry.tag, tag.position + Vector2(58, 47), 30, INK if enabled else CORAL, true)

func draw_coin(center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius, GOLD.darkened(0.15))
	canvas.draw_circle(center, radius * 0.68, GOLD.lightened(0.25))

func draw_talisman_bar(rect: Rect2) -> void:
	canvas.draw_style_box(panel(CARD, 18, EDGE, 2), rect)
	var held: Array = round_state.talismans
	if held.is_empty():
		centered("NO TALISMANS YET", rect, 20, MUTED, true)
		return
	var disabled: int = round_state.disabled_slot()
	for slot in range(maxi(BASE_TALISMAN_ICONS, held.size())):
		var icon: Rect2 = talisman_icon_rect(slot)
		if slot >= held.size():
			canvas.draw_style_box(panel(DEEP, 12), icon)
			continue
		draw_badge(icon, held[slot], 0.3 if slot == disabled else 1.0)
		if slot == disabled:
			canvas.draw_line(icon.position + Vector2(8, 8), icon.end - Vector2(8, 8), CORAL, 4, true)
			canvas.draw_line(Vector2(icon.end.x - 8, icon.position.y + 8), Vector2(icon.position.x + 8, icon.end.y - 8), CORAL, 4, true)

func draw_piece(piece: Dictionary, center: Vector2, pitch: float, alpha: float = 1.0) -> void:
	var extent: Vector2 = Vector2(piece_extent(piece))
	var origin: Vector2 = center - extent * pitch * 0.5
	var gap: float = maxf(2.0, pitch * 0.08)
	for cell in round_state.shapes[int(piece.shape)].cells:
		tile_at(Rect2(origin + Vector2(cell) * pitch, Vector2.ONE * (pitch - gap)), int(piece.element), alpha)

## The selected shard's placement at the hovered cell, if it is legal. Cached
## until the selection, hovered cell or round changes.
func current_preview() -> Dictionary:
	if selected < 0 or hover_cell.x < 0 or round_state.status != Model.PLAYING:
		return {}
	var key: Array = [selected, hover_cell, round_state.seed_initial, round_state.moves, round_state.rerolls, round_state.trays_dealt]
	if key == _preview_key:
		return _preview
	_preview_key = key
	_preview = {}
	var piece: Dictionary = round_state.tray[selected]
	if round_state.can_place(piece, hover_cell.x, hover_cell.y):
		_preview = round_state.preview(piece, hover_cell.x, hover_cell.y)
		_preview.cells = round_state.piece_cells(piece, hover_cell.x, hover_cell.y)
		_preview.element = int(piece.element)
	return _preview

# ---------------------------------------------------------------- layers

## Background only; repaints on resize.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)

## Things that change only with the screen or the profile.
func paint_chrome() -> void:
	if _prewarm_pending:
		# Invisible and off-screen: only fills the glyph cache.
		_prewarm_pending = false
		for font_size in PREWARM_SIZES:
			label_at(PREWARM_TEXT, Vector2(0, -400), font_size, Color(1, 1, 1, 0), true)
	if round_state == null:
		return
	if route == HOME:
		paint_home()
		return
	if route == CAMP:
		paint_camp_chrome()
		return
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(330, 116), Vector2(455, 22), Vector2(590, 116)]), Color("264b4e"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(433, 39), Vector2(455, 22), Vector2(479, 40), Vector2(456, 34)]), CREAM.darkened(0.18))
	if mode == RUN and run != null:
		label_at("FLOOR %d  /  %s" % [run.floor_reached(), Encounters.STAGE_NAMES[run.stage].to_upper()], Vector2(40, 62), 24, GOLD, true)
		var subtitle: String = Encounters.FLOOR_NAMES[run.floor_index]
		if run.hazard != "":
			subtitle = Encounters.hazard_name(run.hazard)
		label_at(subtitle, Vector2(40, 100), 22, CORAL if run.stage == Encounters.GUARDIAN else MUTED, run.stage == Encounters.GUARDIAN)
	else:
		label_at("SUMMIT SHARDS", Vector2(40, 62), 24, GOLD, true)
		label_at("QUICK TRAIL", Vector2(40, 100), 22, MUTED)
	canvas.draw_style_box(panel(CARD, 18), Rect2(40, 124, 640, 182))
	label_at("ALTITUDE", Vector2(64, 164), 20, MUTED)
	canvas.draw_style_box(panel(EDGE, 7), Rect2(64, 264, 592, 14))

func paint_camp_chrome() -> void:
	# A low ridge and a small fire: the expedition's camp.
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-400, 140), Vector2(120, 60), Vector2(260, 110), Vector2(400, 30),
		Vector2(560, 100), Vector2(1120, 40), Vector2(1120, 140)]), Color("1f4245"))
	label_at("CAMP", Vector2(40, 82), 46, CREAM, true)
	if run != null:
		label_at("Floor %d  -  %s cleared" % [run.floor_reached(), Encounters.STAGE_NAMES[run.stage]], Vector2(40, 118), 21, MUTED)

func draw_mountains(base_y: float, scale_y: float) -> void:
	# The ranges run well past the reference width so wide screens see slopes,
	# not cut edges.
	var far = PackedVector2Array([Vector2(-400, base_y), Vector2(-260, base_y - 120 * scale_y), Vector2(-120, base_y - 40 * scale_y),
		Vector2(90, base_y - 150 * scale_y), Vector2(200, base_y - 70 * scale_y),
		Vector2(330, base_y - 230 * scale_y), Vector2(470, base_y - 110 * scale_y), Vector2(600, base_y - 200 * scale_y), Vector2(740, base_y - 60 * scale_y),
		Vector2(900, base_y - 170 * scale_y), Vector2(1120, base_y - 40 * scale_y), Vector2(1120, base_y)])
	canvas.draw_colored_polygon(far, Color("1f4245"))
	var peak = Vector2(420, base_y - 330 * scale_y)
	var near = PackedVector2Array([Vector2(-400, base_y + 40), Vector2(-180, base_y - 60 * scale_y), Vector2(-20, base_y + 10),
		Vector2(160, base_y - 120 * scale_y), Vector2(260, base_y - 60 * scale_y),
		peak, Vector2(560, base_y - 150 * scale_y), Vector2(640, base_y - 100 * scale_y), Vector2(740, base_y - 10 * scale_y),
		Vector2(920, base_y - 90 * scale_y), Vector2(1120, base_y + 10), Vector2(1120, base_y + 40)])
	canvas.draw_colored_polygon(near, Color("2b5356"))
	var cap: float = 70 * scale_y
	canvas.draw_colored_polygon(PackedVector2Array([peak, peak + Vector2(cap * 0.85, cap), peak + Vector2(cap * 0.35, cap * 0.78),
		peak + Vector2(0, cap * 1.05), peak + Vector2(-cap * 0.45, cap * 0.8), peak + Vector2(-cap * 0.95, cap)]), CREAM.darkened(0.08))

func paint_home() -> void:
	for star in STARS:
		canvas.draw_rect(Rect2(star, Vector2(4, 4)), with_alpha(CREAM, 0.55))
		# Mirror the sky beyond the sides for wide screens.
		canvas.draw_rect(Rect2(star + Vector2(720, 40), Vector2(4, 4)), with_alpha(CREAM, 0.4))
		canvas.draw_rect(Rect2(star - Vector2(720, -40), Vector2(4, 4)), with_alpha(CREAM, 0.4))
	canvas.draw_circle(Vector2(590, 150), 46, Color("e9dfb9"))
	canvas.draw_circle(Vector2(610, 138), 42, INK)
	draw_mountains(540, 1.0)
	# The ground runs past the reference layout so tall screens show no seam.
	canvas.draw_rect(Rect2(-400, 560, 1520, 1600), Color("1d3f43"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-400, 546), Vector2(0, 540), Vector2(720, 520), Vector2(1120, 514), Vector2(1120, 600), Vector2(-400, 600)]), Color("1d3f43"))
	centered("SUMMIT SHARDS", Rect2(0, 586, 720, 70), 64, CREAM, true)
	centered("A little higher.", Rect2(0, 652, 720, 44), 28, GOLD)
	var stats_rect = Rect2(80, 704, 560, 104)
	canvas.draw_style_box(panel(CARD, 20, EDGE, 1), stats_rect)
	var stats = [["BEST FLOOR", str(profile.best_floor)], ["SUMMITS", str(profile.summits)],
		["RUNS", str(profile.runs_played)], ["BEST TRAIL", fmt_int(profile.best_score)]]
	for i in range(stats.size()):
		var column = Rect2(stats_rect.position.x + i * 140, stats_rect.position.y, 140, stats_rect.size.y)
		centered(stats[i][1], Rect2(column.position + Vector2(0, 8), Vector2(column.size.x, 56)), 36, CREAM, true)
		centered(stats[i][0], Rect2(column.position + Vector2(0, 60), Vector2(column.size.x, 30)), 18, MUTED)
	centered("v%s  -  plays fully offline" % ProjectSettings.get_setting("application/config/version", ""), Rect2(0, 1196, 720, 40), 18, with_alpha(MUTED, 0.7))

## Score, progress, hint, tray cards and the screen's buttons.
func paint_hud() -> void:
	if round_state == null:
		return
	if route == PLAY:
		paint_play_hud()
	elif route == CAMP:
		paint_camp()
	# Buttons stay on screen while a delayed dialog waits for its entrance.
	if dialogs.is_empty() or _overlay_waiting:
		for entry in screen_buttons():
			draw_button(entry)

## The counting altitude and its progress bar: the only text repainted while
## the score animates.
func paint_score() -> void:
	if round_state == null or route != PLAY:
		return
	var shown: String = fmt_int(int(display_score))
	label_at(shown, Vector2(64, 232), 60, CREAM, true)
	label_at("/ %s" % fmt_int(round_state.target), Vector2(76 + text_width(shown, 60, true), 230), 26, MUTED)
	var bar = Rect2(64, 264, 592, 14)
	var preview: Dictionary = current_preview()
	if not preview.is_empty():
		var projected: float = clampf(float(round_state.score + int(preview.points)) / round_state.target, 0, 1)
		canvas.draw_style_box(panel(with_alpha(GOLD, 0.4), 7), Rect2(bar.position, Vector2(bar.size.x * projected, bar.size.y)))
	var progress: float = clampf(display_score / round_state.target, 0, 1)
	if progress > 0:
		canvas.draw_style_box(panel(GOLD, 7), Rect2(bar.position, Vector2(maxf(14, bar.size.x * progress), bar.size.y)))
	if not preview.is_empty():
		var lines: int = int(preview.lines)
		centered("+%d altitude%s" % [preview.points, "" if lines == 0 else "  /  %d %s" % [lines, "line" if lines == 1 else "lines"]], HINT_RECT, 27, GOLD, true)
	else:
		centered(notice, HINT_RECT, 23, GOLD if round_state.status != Model.PLAYING else MUTED)

func paint_play_hud() -> void:
	var playing: bool = round_state.status == Model.PLAYING
	if mode == RUN and run != null:
		var coin_text: String = fmt_int(run.coins + round_state.coins_found)
		right_aligned(coin_text, 656, 166, 24, GOLD, true)
		draw_coin(Vector2(656 - text_width(coin_text, 24, true) - 20, 158), 11)
	else:
		right_aligned("BEST %s" % fmt_int(profile.best_score), 656, 164, 20, MUTED)
	right_aligned("TRAY %d / %d" % [round_state.trays_dealt, round_state.max_trays], 656, 204, 22, CREAM, true)
	for i in range(round_state.max_trays):
		var pip = Rect2(656 - (round_state.max_trays - i) * 22 + 4, 218, 14, 14)
		canvas.draw_style_box(panel(GOLD if i < round_state.trays_dealt else EDGE, 7), pip)
	if round_state.streak > 0 and playing:
		var chip_text: String = "STREAK x%d" % round_state.streak
		var chip = Rect2(318, 140, text_width(chip_text, 18, true) + 28, 34)
		canvas.draw_style_box(panel(with_alpha(GOLD, 0.18), 17, GOLD, 1), chip)
		centered(chip_text, chip, 18, GOLD, true)
	for slot in range(3):
		var rect: Rect2 = tray_rect(slot)
		var is_selected: bool = selected == slot
		canvas.draw_style_box(panel(Color("2b5054") if is_selected else CARD, 18, GOLD if is_selected else EDGE, 3 if is_selected else 1), rect)
		if round_state.tray[slot].is_empty():
			centered("PLACED", rect, 20, with_alpha(MUTED, 0.6))
		elif not _fits[slot] and playing:
			centered("NO ROOM", Rect2(rect.position.x, rect.end.y - 34, rect.size.x, 26), 17, CORAL, true)

## Camp: coins, section titles, the empty talisman slots and the details of
## whatever is selected. The cards and chips themselves are buttons.
func paint_camp() -> void:
	if run == null:
		return
	var chip = Rect2(392, 30, 180, 76)
	canvas.draw_style_box(panel(CARD, 20, GOLD, 1), chip)
	draw_coin(chip.position + Vector2(40, 38), 18)
	label_at(fmt_int(run.coins), chip.position + Vector2(70, 50), 34, CREAM, true)
	if run.draft_open:
		label_at("FREE TALISMAN", Vector2(40, 164), 26, GOLD, true)
		label_at("Choose one, or skip it for +%d Coins." % Run.SKIP_COINS if run.has_room() else "Slots full: pick a card, then a talisman to swap out.", Vector2(40, 196), 20, MUTED)
	else:
		label_at("TRADER", Vector2(40, 170), 26, GOLD, true)
		label_at("Coins kept earn +1 per 5 (max 5) each round.", Vector2(40, 206), 19, MUTED)
		if run.reward.has("total"):
			label_at("Last round: +%d Coins" % run.reward.total, Vector2(40, 232), 18, with_alpha(MUTED, 0.8))
	label_at("YOUR TALISMANS  %d / %d" % [run.talismans.size(), run.slots()], Vector2(40, CAMP_CHIPS_Y - 14), 20, MUTED, true)
	var chip_area = Rect2(40, CAMP_CHIPS_Y, 640, 112)
	for slot in range(run.talismans.size(), run.slots()):
		canvas.draw_style_box(panel(DEEP, 18, EDGE, 1), chip_rect(chip_area, slot, run.slots(), 112).grow(-2))
	var detail = Vector2(40, 976)
	if camp_pending >= 0 and camp_pending < run.draft.size():
		wrapped("Tap one of your talismans to swap it for %s. The old one sells for half its price." % Talismans.info(run.draft[camp_pending]).name, detail, 640, 21, GOLD)
	elif camp_selected >= 0 and camp_selected < run.talismans.size():
		var info: Dictionary = Talismans.info(run.talismans[camp_selected])
		label_at(info.name, detail + Vector2(0, 18), 24, CREAM, true)
		wrapped(info.text, detail + Vector2(0, 26), 640, 20, MUTED)
	elif run.talismans.is_empty():
		wrapped("Talismans change how every placement scores. Take the free one!", detail, 640, 21, MUTED)
	else:
		wrapped("Tap a talisman to read, move or sell it. Every +Base and +Mult adds first, then every xMult multiplies. Mirror Lake copies its right-hand neighbour.", detail, 640, 21, MUTED)

## Board tiles. Repaints when a move changes the board, and once when
## placement pops finish; never while a shard is dragged across it.
func paint_board() -> void:
	if round_state == null or route != PLAY:
		return
	canvas.draw_style_box(panel(DEEP, 16), BOARD_RECT.grow(10))
	for index in range(64):
		# Popping tiles are drawn, scaled, by the effects layer.
		tile_at(cell_rect(index), 0 if effects.pops.has(index) else int(round_state.board[index]))

## The ghost of the selected shard at the hovered cell, the lines it would
## clear, or where it collides. A handful of tiles: cheap to repaint each
## time the snapped cell changes.
func paint_preview() -> void:
	if round_state == null or route != PLAY:
		return
	var preview: Dictionary = current_preview()
	if not preview.is_empty():
		for index in preview.cells:
			tile_at(cell_rect(index), preview.element, 0.55)
		if settings.get_value("clear_preview"):
			for index in preview.cleared:
				canvas.draw_style_box(panel(with_alpha(GOLD, 0.16), 10, GOLD, 3), cell_rect(index).grow(1))
	elif selected >= 0 and hover_cell.x >= 0 and hover_cell.y >= 0 and hover_cell.x < 8 and hover_cell.y < 8 and round_state.status == Model.PLAYING:
		# Show where an illegal placement collides, in coral.
		var piece: Dictionary = round_state.tray[selected]
		for cell in round_state.shapes[int(piece.shape)].cells:
			var p: Vector2i = hover_cell + cell
			if p.x < 8 and p.y < 8:
				canvas.draw_style_box(panel(with_alpha(CORAL, 0.18), 10, CORAL, 3), cell_rect(p.y * 8 + p.x))

## One tray shard, centered on the layer's origin.
func paint_slot(slot: int) -> void:
	if round_state == null:
		return
	var piece: Dictionary = round_state.tray[slot]
	if not piece.is_empty():
		draw_piece(piece, Vector2.ZERO, tray_pitch(piece))

## Short-lived effects; the only layer repainted every animation frame.
func paint_fx() -> void:
	if round_state == null:
		return
	for index in effects.pops:
		tile_at(cell_rect(index), int(round_state.board[index]), 1.0, effects.pop_scale(index))
	for entry in effects.clears:
		var t: float = effects.clear_progress(entry)
		var rect: Rect2 = cell_rect(entry.index)
		tile_at(rect, entry.element, 1.0 - t, 1.0 - 0.45 * t)
		if t < 0.4:
			canvas.draw_style_box(panel(Color(1, 1, 1, 0.7 * (1.0 - t / 0.4)), 10), rect)
	for entry in effects.particles:
		var state: Dictionary = effects.particle_state(entry)
		canvas.draw_rect(Rect2(state.pos - Vector2.ONE * entry.size * 0.5, Vector2.ONE * entry.size), with_alpha(entry.color, state.alpha))
	if mode == RUN:
		# The fx layer shakes with the board; flashes sit on the steady bar.
		canvas.draw_set_transform(-fx_layer.position)
		for slot in effects.flashes:
			var glow: float = effects.flash_alpha(slot)
			canvas.draw_style_box(panel(with_alpha(GOLD, 0.35 * glow), 14, with_alpha(GOLD, glow), 4), talisman_icon_rect(slot).grow(5))
		canvas.draw_set_transform(Vector2.ZERO)
	for entry in effects.texts:
		var state: Dictionary = effects.text_state(entry)
		canvas.draw_set_transform(state.pos, 0, Vector2.ONE * state.scale)
		var width: float = text_width(entry.text, entry.size, true)
		label_at(entry.text, Vector2(-width * 0.5 + 3, entry.size * 0.34 + 3), entry.size, Color(0, 0, 0, 0.45 * state.alpha), true)
		label_at(entry.text, Vector2(-width * 0.5, entry.size * 0.34), entry.size, with_alpha(entry.color, state.alpha), true)
	canvas.draw_set_transform(Vector2.ZERO)

## The dragged shard, drawn once per drag: its centre floats DRAG_LIFT above
## the layer origin, and the layer itself follows the finger.
func paint_drag() -> void:
	if round_state == null or press_slot < 0 or press_slot > 2:
		return
	var piece: Dictionary = round_state.tray[press_slot]
	if not piece.is_empty():
		draw_piece(piece, Vector2(0, -DRAG_LIFT), CELL, 0.85)

## The top dialog. Its fade and lift move the layer; nothing repaints.
func paint_overlay() -> void:
	if dialogs.is_empty() or round_state == null:
		return
	var id: String = dialogs.back()
	# Oversized so the entrance lift never uncovers the screen edge.
	var screen = Rect2(-layout_offset / layout_scale, size / layout_scale).grow(80)
	canvas.draw_rect(screen, Color(0.02, 0.07, 0.08, 0.74))
	var card: Rect2 = dialog_card(id)
	canvas.draw_style_box(panel(INK, 26, EDGE, 2), card)
	var top: float = card.position.y
	var inner = Rect2(card.position.x + 40, top, card.size.x - 80, card.size.y)
	match id:
		"pause":
			centered("PAUSED", Rect2(card.position.x, top + 36, card.size.x, 56), 44, CREAM, true)
			var where: String = "Altitude %s / %s  -  Tray %d / %d" % [fmt_int(round_state.score), fmt_int(round_state.target), round_state.trays_dealt, round_state.max_trays]
			if mode == RUN and route == CAMP:
				where = "Camp on floor %d  -  %s Coins" % [run.floor_reached(), fmt_int(run.coins)]
			elif mode == RUN:
				where = "Floor %d %s  -  %s" % [run.floor_reached(), Encounters.STAGE_NAMES[run.stage], where]
			centered(where, Rect2(card.position.x, top + 100, card.size.x, 36), 20, MUTED)
		"settings":
			centered("SETTINGS", Rect2(card.position.x, top + 30, card.size.x, 60), 40, CREAM, true)
		"help":
			centered("HOW TO PLAY", Rect2(card.position.x, top + 30, card.size.x, 60), 40, CREAM, true)
			var y: float = top + 120
			for i in range(HELP_LINES.size()):
				var badge = Rect2(inner.position.x, y + 2, 44, 44)
				canvas.draw_style_box(panel(GOLD, 22), badge)
				centered(str(i + 1), badge, 22, INK, true)
				y += maxf(56.0, wrapped(HELP_LINES[i], Vector2(inner.position.x + 64, y), inner.size.x - 64, 24, CREAM)) + 22
			var sample_y: float = minf(y + 6, card.end.y - 250)
			label_at("ELEMENTS", Vector2(inner.position.x, sample_y + 20), 18, MUTED)
			for e in range(1, 6):
				var sample = Rect2(inner.position.x + (e - 1) * 90, sample_y + 34, 56, 56)
				tile_at(sample, e)
				centered(Talismans.ELEMENT_NAMES[e], Rect2(sample.position.x - 12, sample.end.y + 4, 80, 24), 16, MUTED)
		"result":
			var won: bool = round_state.status == Model.WON
			centered("SUMMIT REACHED" if won else "TRAIL ENDS", Rect2(card.position.x, top + 34, card.size.x, 60), 42, GOLD if won else CREAM, true)
			centered("Floor 01 Trail complete." if won else "Out of moves. Every climb teaches.", Rect2(card.position.x, top + 96, card.size.x, 36), 22, MUTED)
			centered(str(round_state.score), Rect2(card.position.x, top + 140, card.size.x, 110), 92, CREAM, true)
			centered("ALTITUDE  /  %d" % round_state.target, Rect2(card.position.x, top + 250, card.size.x, 30), 20, MUTED)
			if last_summary.get("new_best", false):
				var badge = Rect2(card.get_center().x - 90, top + 296, 180, 42)
				canvas.draw_style_box(panel(GOLD, 21), badge)
				centered("NEW BEST", badge, 22, INK, true)
			var rows = [["Lines cleared", str(round_state.lines_total)], ["Best move", "+%d" % round_state.best_move],
				["Trays used", "%d / %d" % [round_state.trays_dealt, round_state.max_trays]], ["Summit streak", str(profile.win_streak)]]
			for i in range(rows.size()):
				var row_y: float = top + 380 + i * 70
				canvas.draw_style_box(panel(DEEP, 14), Rect2(inner.position.x, row_y, inner.size.x, 58))
				label_at(rows[i][0], Vector2(inner.position.x + 22, row_y + 38), 23, MUTED)
				right_aligned(rows[i][1], inner.end.x - 22, row_y + 39, 25, CREAM, true)
		"intro":
			paint_intro(card, inner)
		"round_won":
			paint_round_won(card, inner)
		"run_over":
			paint_run_over(card, inner)
		"talismans":
			paint_talisman_list(card, inner)
		_:
			var titles = {"confirm_new": "Start a new trail?", "confirm_exit": "Leave Summit Shards?", "confirm_reset": "Reset statistics?",
				"confirm_run_new": "Start a new expedition?", "confirm_abandon": "Abandon this expedition?"}
			var bodies = {"confirm_new": "This trail ends here and counts as played.",
				"confirm_exit": "Your game is saved. Pick up where you left off next time.",
				"confirm_reset": "Best floor, summits, runs and trail records go back to zero. Your games in progress and settings stay.",
				"confirm_run_new": "Your current expedition ends here and counts as a run.",
				"confirm_abandon": "The expedition ends here and counts as a run. Your talismans are lost."}
			centered(titles.get(id, ""), Rect2(card.position.x, top + 34, card.size.x, 60), 36, CREAM, true)
			wrapped(bodies.get(id, ""), Vector2(inner.position.x, top + 110), inner.size.x, 24, MUTED)
	for entry in dialog_buttons(id):
		draw_button(entry)

## Before each expedition round: where you are, the target and the rule.
func paint_intro(card: Rect2, inner: Rect2) -> void:
	if run == null:
		return
	var top: float = card.position.y
	var guardian: bool = run.stage == Encounters.GUARDIAN
	centered("FLOOR %d  /  %s" % [run.floor_reached(), Encounters.STAGE_NAMES[run.stage].to_upper()], Rect2(card.position.x, top + 30, card.size.x, 50), 32, CORAL if guardian else GOLD, true)
	centered(Encounters.FLOOR_NAMES[run.floor_index], Rect2(card.position.x, top + 80, card.size.x, 34), 22, MUTED)
	centered("TARGET", Rect2(card.position.x, top + 128, card.size.x, 30), 20, MUTED)
	centered(fmt_int(run.round.target), Rect2(card.position.x, top + 150, card.size.x, 90), 76, CREAM, true)
	centered("%d trays  -  %d %s  -  %d talismans" % [run.round.max_trays, run.round.rerolls, "reroll" if run.round.rerolls == 1 else "rerolls", run.talismans.size()],
		Rect2(card.position.x, top + 244, card.size.x, 34), 21, MUTED)
	var box = Rect2(inner.position.x, top + 296, inner.size.x, 300)
	canvas.draw_style_box(panel(DEEP, 18, CORAL if guardian else EDGE, 2 if guardian else 1), box)
	var y: float = box.position.y + 20
	if notice.begins_with("The Firebird"):
		y += wrapped(notice, Vector2(box.position.x + 20, y), box.size.x - 40, 22, GOLD) + 12
	if run.hazard == "":
		label_at("A clear trail", Vector2(box.position.x + 20, y + 26), 26, CREAM, true)
		wrapped("No hazards. Bank Coins and build your combo.", Vector2(box.position.x + 20, y + 40), box.size.x - 40, 22, MUTED)
		return
	label_at(Encounters.hazard_name(run.hazard), Vector2(box.position.x + 20, y + 26), 27, CORAL if guardian else CREAM, true)
	y += 40
	for id in run.hazard_ids() if run.hazard == "summit_warden" else [run.hazard]:
		var text: String = Encounters.hazard_text(id)
		if run.hazard == "summit_warden":
			text = "%s: %s" % [Encounters.hazard_name(id), text]
		y += wrapped(text, Vector2(box.position.x + 20, y), box.size.x - 40, 22, CREAM) + 8
	var rules: Dictionary = run.round.rules
	if int(rules.get("stones_start", 0)) + int(rules.get("rockfall", 0)) + int(rules.get("frost", 0)) > 0:
		wrapped(Encounters.STONE_TEXT, Vector2(box.position.x + 20, y + 4), box.size.x - 40, 19, MUTED)

func paint_round_won(card: Rect2, inner: Rect2) -> void:
	var top: float = card.position.y
	centered("ROUND CLEARED", Rect2(card.position.x, top + 34, card.size.x, 56), 40, GOLD, true)
	centered("Floor %d %s  -  %s / %s" % [run.floor_reached(), Encounters.STAGE_NAMES[run.stage], fmt_int(run.round.score), fmt_int(run.round.target)],
		Rect2(card.position.x, top + 92, card.size.x, 34), 21, MUTED)
	var rows: Array = [["Round reward", int(run.reward.get("round", 0))], ["Unused trays", int(run.reward.get("trays", 0))],
		["Interest", int(run.reward.get("interest", 0))]]
	if int(run.reward.get("found", 0)) > 0:
		rows.append(["Found on the board", int(run.reward.found)])
	for i in range(rows.size()):
		var y: float = top + 150 + i * 66
		canvas.draw_style_box(panel(DEEP, 14), Rect2(inner.position.x, y, inner.size.x, 54))
		label_at(rows[i][0], Vector2(inner.position.x + 22, y + 35), 22, MUTED)
		right_aligned("+%d" % rows[i][1], inner.end.x - 22, y + 36, 24, CREAM, true)
	var total_y: float = top + 160 + rows.size() * 66
	draw_coin(Vector2(card.get_center().x - 92, total_y + 34), 20)
	label_at("+%d COINS" % int(run.reward.get("total", 0)), Vector2(card.get_center().x - 62, total_y + 48), 36, GOLD, true)
	centered("You have %s Coins. Spend them at Camp." % fmt_int(run.coins), Rect2(card.position.x, total_y + 70, card.size.x, 34), 20, MUTED)

func paint_run_over(card: Rect2, inner: Rect2) -> void:
	var top: float = card.position.y
	var won: bool = run.phase == Run.WON
	centered("SUMMIT REACHED" if won else "EXPEDITION ENDS", Rect2(card.position.x, top + 34, card.size.x, 60), 40, GOLD if won else CREAM, true)
	centered("All eight floors climbed." if won else "%s  -  Floor %d %s" % [Encounters.FLOOR_NAMES[run.floor_index], run.floor_reached(), Encounters.STAGE_NAMES[run.stage]],
		Rect2(card.position.x, top + 96, card.size.x, 36), 21, MUTED)
	centered("SUMMIT" if won else "FLOOR %d" % run.floor_reached(), Rect2(card.position.x, top + 140, card.size.x, 110), 80, CREAM, true)
	if last_run_summary.get("new_best_floor", false):
		var badge = Rect2(card.get_center().x - 110, top + 262, 220, 42)
		canvas.draw_style_box(panel(GOLD, 21), badge)
		centered("NEW BEST FLOOR", badge, 21, INK, true)
	var rows = [["Rounds won", str(run.rounds_won)], ["Lines cleared", fmt_int(run.lines)], ["Best move", "+" + fmt_int(run.best_move)]]
	for i in range(rows.size()):
		var y: float = top + 326 + i * 66
		canvas.draw_style_box(panel(DEEP, 14), Rect2(inner.position.x, y, inner.size.x, 54))
		label_at(rows[i][0], Vector2(inner.position.x + 22, y + 35), 22, MUTED)
		right_aligned(rows[i][1], inner.end.x - 22, y + 36, 24, CREAM, true)
	var badge_y: float = top + 536
	label_at("YOUR BUILD", Vector2(inner.position.x, badge_y), 18, MUTED, true)
	if run.talismans.is_empty():
		label_at("No talismans", Vector2(inner.position.x, badge_y + 40), 21, MUTED)
	for slot in range(run.talismans.size()):
		draw_badge(chip_rect(Rect2(inner.position.x, badge_y + 14, inner.size.x, 70), slot, maxi(5, run.talismans.size()), 70), run.talismans[slot])

## Every held talisman with its rule, in slot order (the order xMult uses).
func paint_talisman_list(card: Rect2, inner: Rect2) -> void:
	var top: float = card.position.y
	var held: Array = round_state.talismans
	var slot_count: int = run.slots() if run != null else BASE_TALISMAN_ICONS
	centered("TALISMANS  %d / %d" % [held.size(), slot_count], Rect2(card.position.x, top + 28, card.size.x, 56), 36, CREAM, true)
	if held.is_empty():
		wrapped("None yet. Win a round to reach Camp, where you can take a free talisman and buy more.", Vector2(inner.position.x, top + 110), inner.size.x, 23, MUTED)
		return
	var disabled: int = round_state.disabled_slot()
	var row_h: float = minf(116.0, 760.0 / held.size())
	for slot in range(held.size()):
		var y: float = top + 100 + slot * row_h
		var info: Dictionary = Talismans.info(held[slot])
		draw_badge(Rect2(inner.position.x, y + 6, row_h - 20, row_h - 20), held[slot], 0.35 if slot == disabled else 1.0)
		var x: float = inner.position.x + row_h + 4
		label_at(info.name + ("   (disabled this tray)" if slot == disabled else ""), Vector2(x, y + 30), 23, CORAL if slot == disabled else CREAM, true)
		wrapped(info.text, Vector2(x, y + 36), inner.end.x - x, 19, MUTED)
	wrapped("Scoring adds every +Base, then every +Mult, then applies every xMult. Mirror Lake copies the talisman to its right.", Vector2(inner.position.x, card.end.y - 196), inner.size.x, 19, with_alpha(MUTED, 0.85))

# ---------------------------------------------------------------- persistence

func save_settings() -> bool:
	return Store.write(settings_path, settings.to_dict())

func save_profile() -> bool:
	return Store.write(profile_path, profile.to_dict())

## Saves whichever game is being played.
func save_active() -> bool:
	return save_run() if mode == RUN else save_round()

func save_run() -> bool:
	if run == null:
		return false
	return Store.write(run_path, run.snapshot())

## Loads a saved expedition. A run saved between a finished round and its
## settlement is settled now; a finished run is counted once.
func load_run() -> bool:
	var data: Dictionary = Store.read(run_path)
	if data.is_empty():
		return false
	var restored = Run.new(1)
	if not restored.restore_snapshot(data):
		return false
	run = restored
	if run.phase == Run.ROUND and run.round.status != Model.PLAYING:
		run.after_round_command()
		save_run()
	if run.phase == Run.WON or run.phase == Run.LOST:
		record_run()
	return true

func run_active() -> bool:
	return run != null and run.phase != Run.WON and run.phase != Run.LOST

func save_round() -> bool:
	if quick_round == null:
		return false
	var payload: String = JSON.stringify(quick_round.snapshot())
	var checksum: String = payload.sha256_text()
	# Pause/focus callbacks often arrive together. Do not rewrite an unchanged
	# round or rotate its useful previous-move backup for those notifications.
	if not _loaded_from_backup and checksum == _last_saved_sha and FileAccess.file_exists(save_path):
		return true
	var envelope: String = JSON.stringify({"payload": payload, "sha256": checksum})
	var file = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(envelope)
	file.flush()
	file.close()
	if FileAccess.file_exists(save_path):
		if _loaded_from_backup:
			# Retain the known-good backup while replacing a corrupt primary.
			if DirAccess.remove_absolute(save_path) != OK:
				return false
		else:
			if FileAccess.file_exists(save_path + ".bak"):
				DirAccess.remove_absolute(save_path + ".bak")
			if DirAccess.rename_absolute(save_path, save_path + ".bak") != OK:
				return false
	if DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		return false
	_last_saved_sha = checksum
	_loaded_from_backup = false
	return true

func load_round() -> bool:
	for path in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var envelope = parser.data
		if not envelope is Dictionary or not envelope.has_all(["payload", "sha256"]) or not envelope.payload is String:
			continue
		if envelope.payload.sha256_text() != envelope.sha256:
			continue
		if parser.parse(envelope.payload) != OK:
			continue
		var data = parser.data
		if data is Dictionary and quick_round.restore_snapshot(data):
			_loaded_from_backup = path != save_path
			_last_saved_sha = JSON.stringify(quick_round.snapshot()).sha256_text()
			if mode != QUICK:
				return true
			selected = -1
			cancel_gesture()
			effects.clear_all()
			display_score = round_state.score
			refresh_derived()
			notice = "Your trail is right where you left it."
			set_end_notice()
			if settings != null:
				refresh_view()
			return true
	return false
