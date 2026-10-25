extends Control
## Portrait touch adapter: screens, input, drawing, sound and local saves.
## Rules live in round_model.gd. Drawing and effects never change them: a move
## is committed and saved first, then animated.

const Model = preload("res://scripts/round_model.gd")
const Settings = preload("res://scripts/settings_model.gd")
const Profile = preload("res://scripts/profile_model.gd")
const Store = preload("res://scripts/persistence/json_store.gd")
const Effects = preload("res://scripts/ui/effects.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")

const INK = Color("18383d")
const DEEP = Color("122d32")
const CARD = Color("24464a")
const EDGE = Color("345457")
const EMPTY = Color("2a484a")
const CREAM = Color("f4f0df")
const MUTED = Color("a9b9af")
const GOLD = Color("e7bf73")
const CORAL = Color("ed9781")
const COLORS = [Color("2a484a"), Color("7bbde2"), Color("e6e4cd"), Color("ed9781"), Color("85bca1"), Color("d8ba78")]
const SYMBOLS = ["", "+", "o", "^", "~", "#"]

const HOME = "home"
const PLAY = "play"
const BOARD_RECT = Rect2(56, 330, 608, 608)
const CELL = 76.0
const TILE = 70.0
const PAUSE_RECT = Rect2(588, 20, 96, 96)
const HINT_RECT = Rect2(40, 944, 640, 50)
# 96 reference pixels = 48 dp at the 360 dp reference width: the minimum touch target.
const BUTTON_H = 96.0
const NEW_RECT = Rect2(40, 1172, 310, BUTTON_H)
const REROLL_RECT = Rect2(370, 1172, 310, BUTTON_H)
const DRAG_LIFT = 130.0
const DRAG_THRESHOLD = 14.0
const SETTING_ROWS = [
	["sound", "Sound effects", "Chimes for placing and clearing."],
	["clear_preview", "Line preview", "Outline the lines a placement will clear."],
	["reduced_motion", "Reduced motion", "No shaking, bursts or floating text."],
	["battery_saver", "Battery saver", "Cap the game at 30 FPS."],
]
const HELP_LINES = [
	"Drag a shard onto the board. Or tap it, then tap where its top-left corner goes.",
	"Fill a whole row or column to clear it and climb.",
	"Clear several lines at once to raise the multiplier.",
	"A line of one symbol is a pure line: a big bonus.",
	"Clear on back-to-back moves to build a streak. Empty the board for x3.",
	"Reach the target altitude within 8 trays. You get one reroll per trail.",
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

func _ready() -> void:
	font = ThemeDB.fallback_font
	var heavy = FontVariation.new()
	heavy.base_font = font
	heavy.variation_embolden = 0.8
	bold = heavy
	effects = Effects.new()
	sfx = Sfx.new()
	add_child(sfx)
	settings = Settings.new()
	settings.from_dict(Store.read(settings_path))
	profile = Profile.new()
	profile.from_dict(Store.read(profile_path))
	round_state = Model.new(20261024)
	load_round()
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
	queue_redraw()

# ---------------------------------------------------------------- lifecycle

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_round()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_gesture()
		save_round()
		if what == NOTIFICATION_APPLICATION_PAUSED and route == PLAY and dialogs.is_empty() and round_state.status == Model.PLAYING:
			open_dialog("pause")
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		cancel_gesture()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		queue_redraw()

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
		close_dialog()
	elif route == PLAY:
		save_round()
		open_dialog("pause")
	else:
		open_dialog("confirm_exit")
	queue_redraw()

func _process(delta: float) -> void:
	effects.update(delta)
	var target: float = round_state.score
	if settings.get_value("reduced_motion") or absf(target - display_score) < 1.0:
		display_score = target
	else:
		display_score = move_toward(display_score, target, maxf(absf(target - display_score) * delta * 9.0, 60.0 * delta))
	queue_redraw()
	if not is_animating():
		set_process(false)

func is_animating() -> bool:
	return effects.active() or display_score != round_state.score \
		or (not dialogs.is_empty() and effects.time - dialog_opened_at < result_delay + 0.3)

func start_animation() -> void:
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
	if id == "result" and not settings.get_value("reduced_motion"):
		result_delay = 0.8
	start_animation()

func close_dialog() -> void:
	if not dialogs.is_empty():
		dialogs.pop_back()

func go_home() -> void:
	cancel_gesture()
	selected = -1
	dialogs.clear()
	save_round()
	route = HOME
	queue_redraw()

func enter_play() -> void:
	route = PLAY
	reset_notice()
	set_end_notice()
	if not profile.seen_tutorial:
		profile.seen_tutorial = true
		save_profile()
		open_dialog("help")

func can_continue() -> bool:
	return round_state.status == Model.PLAYING and (round_state.moves > 0 or round_state.rerolls == 0)

func start_new_round() -> void:
	cancel_gesture()
	var seed_value: int = fixed_seed if fixed_seed >= 0 else int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	if fixed_seed >= 0:
		fixed_seed += 1
	round_state = Model.new(seed_value)
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
		queue_redraw()
		return
	match id:
		"continue":
			enter_play()
		"start":
			if round_state.status != Model.PLAYING:
				start_new_round()
			enter_play()
		"new", "restart":
			if round_state.status == Model.PLAYING and round_state.moves > 0:
				open_dialog("confirm_new")
			else:
				dialogs.clear()
				start_new_round()
				enter_play()
		"confirm_new", "next":
			abandon_round()
			dialogs.clear()
			start_new_round()
			enter_play()
		"pause":
			cancel_gesture()
			selected = -1
			save_round()
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
			save_round()
			get_tree().quit()
		"resume", "cancel", "done":
			close_dialog()
	queue_redraw()

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
	save_round()
	refresh_derived()
	play_move_feedback(result, before)
	after_command()
	return true

func reroll() -> void:
	if round_state.try_reroll():
		selected = -1
		cancel_gesture()
		notice = "Fresh shards. Make them count."
		sfx.play("select", 0.8)
		save_round()
		refresh_derived()
		after_command()

## Runs after every committed command: records a finished round exactly once
## and shows its result.
func after_command() -> void:
	if round_state.status == Model.PLAYING:
		return
	set_end_notice()
	record_if_finished()
	sfx.play("win" if round_state.status == Model.WON else "lose")
	if dialogs.is_empty() or dialogs.back() != "result":
		open_dialog("result")

func record_if_finished() -> void:
	if round_state.status == Model.PLAYING:
		return
	var summary: Dictionary = profile.record_round(round_state.seed_initial, round_state.status == Model.WON,
		round_state.score, round_state.lines_total, round_state.perfect_count, round_state.best_move)
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
	if lines > 0:
		notice = "+%d altitude  /  %d %s" % [result.points, lines, "line" if lines == 1 else "lines"]
	else:
		notice = "+%d altitude" % result.points
	start_animation()

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

func to_reference(point: Vector2) -> Vector2:
	update_layout()
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
			dragging = true
			selected = press_slot
			sfx.play("select")
		if dragging:
			drag_point = point
			hover_cell = drag_anchor(press_slot, point)
			queue_redraw()
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
			if not round_state.can_place(round_state.tray[press_slot], cell.x, cell.y) or not commit_place(press_slot, cell):
				selected = -1
				hover_cell = Vector2i(-1, -1)
				notice = "No room there. The shard is back in your tray."
				sfx.play("invalid")
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
	queue_redraw()

## Cancels an in-progress gesture without consuming a piece.
func cancel_gesture() -> void:
	if dragging:
		selected = -1
	pointer_down = false
	press_kind = ""
	dragging = false
	hover_cell = Vector2i(-1, -1)

func set_hover(cell: Vector2i) -> void:
	if cell != hover_cell:
		hover_cell = cell
		queue_redraw()

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
	if route == HOME:
		var list: Array = []
		if can_continue():
			list.append(make_button("continue", Rect2(80, 830, 560, 112), "CONTINUE TRAIL", "primary",
				{"sub": "Altitude %d / %d  -  Tray %d / %d" % [round_state.score, round_state.target, round_state.trays_dealt, round_state.max_trays]}))
			list.append(make_button("new", Rect2(80, 958, 560, BUTTON_H), "NEW TRAIL", "secondary"))
		else:
			list.append(make_button("start", Rect2(80, 830, 560, 112), "START CLIMB", "primary"))
		var row_y: float = 1070.0 if can_continue() else 958.0
		list.append(make_button("help", Rect2(80, row_y, 272, BUTTON_H), "HOW TO PLAY"))
		list.append(make_button("settings", Rect2(368, row_y, 272, BUTTON_H), "SETTINGS"))
		return list
	var playing: bool = round_state.status == Model.PLAYING
	return [
		make_button("pause", PAUSE_RECT, "", "icon"),
		make_button("new", NEW_RECT, "NEW TRAIL", "primary"),
		make_button("reroll", REROLL_RECT, "REROLL  %d" % round_state.rerolls, "secondary", {"enabled": playing and round_state.rerolls > 0}),
	]

func dialog_card(id: String) -> Rect2:
	match id:
		"pause":
			return Rect2(90, 270, 540, 740)
		"settings":
			return Rect2(50, 200, 620, 880)
		"help":
			return Rect2(50, 130, 620, 1020)
		"result":
			return Rect2(70, 230, 580, 820)
	return Rect2(90, 440, 540, 400)

func dialog_buttons(id: String) -> Array:
	var card: Rect2 = dialog_card(id)
	var x: float = card.position.x + 40
	var width: float = card.size.x - 80
	match id:
		"pause":
			var list: Array = []
			var entries = [["resume", "RESUME", "primary"], ["help", "HOW TO PLAY", "ghost"], ["settings", "SETTINGS", "ghost"],
				["restart", "NEW TRAIL", "ghost"], ["home", "HOME", "ghost"]]
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
	var confirm_label: String = {"confirm_new": "START NEW", "confirm_exit": "EXIT", "confirm_reset": "RESET"}.get(id, "OK")
	var half_width: float = (width - 20) * 0.5
	return [make_button("cancel", Rect2(x, card.end.y - 120, half_width, BUTTON_H), "CANCEL", "ghost"),
		make_button(id, Rect2(x + half_width + 20, card.end.y - 120, half_width, BUTTON_H), confirm_label, "danger" if id != "confirm_exit" else "primary")]

func button_at(point: Vector2) -> Dictionary:
	for entry in current_buttons():
		if entry.rect.has_point(point):
			return entry
	return {}

# ---------------------------------------------------------------- drawing helpers

func update_layout() -> void:
	var safe = Rect2(Vector2.ZERO, size)
	if OS.get_name() == "Android":
		var physical = Vector2(DisplayServer.window_get_size())
		var area = DisplayServer.get_display_safe_area()
		if physical.x > 0 and physical.y > 0:
			var conversion = size / physical
			safe = Rect2(Vector2(area.position) * conversion, Vector2(area.size) * conversion)
	layout_scale = minf(safe.size.x / 720.0, safe.size.y / 1280.0)
	layout_offset = safe.position + (safe.size - Vector2(720, 1280) * layout_scale) * 0.5

func label_at(text: String, point: Vector2, font_size: int, color: Color = CREAM, heavy: bool = false) -> void:
	draw_string(bold if heavy else font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func text_width(text: String, font_size: int, heavy: bool = false) -> float:
	return (bold if heavy else font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func centered(text: String, rect: Rect2, font_size: int, color: Color = CREAM, heavy: bool = false) -> void:
	label_at(text, Vector2(rect.get_center().x - text_width(text, font_size, heavy) * 0.5, rect.get_center().y + font_size * 0.34), font_size, color, heavy)

func right_aligned(text: String, right: float, baseline: float, font_size: int, color: Color = CREAM, heavy: bool = false) -> void:
	label_at(text, Vector2(right - text_width(text, font_size, heavy), baseline), font_size, color, heavy)

func wrapped(text: String, origin: Vector2, width: float, font_size: int, color: Color = CREAM) -> float:
	draw_multiline_string(font, origin + Vector2(0, font_size), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, color)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y

func panel(color: Color, radius: int, border_color: Color = Color.TRANSPARENT, border: int = 0) -> StyleBoxFlat:
	# Reuse immutable drawing resources instead of allocating a style per tile
	# on every frame. Alpha is quantized so fades reuse a bounded set.
	color.a = snappedf(color.a, 0.0625)
	border_color.a = snappedf(border_color.a, 0.0625)
	var key: String = "%d:%d:%d:%d" % [color.to_rgba32(), radius, border_color.to_rgba32(), border]
	if _style_cache.has(key):
		return _style_cache[key]
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
	draw_style_box(panel(with_alpha(COLORS[element], alpha), radius), rect)
	if element == 0:
		return
	# A soft top highlight gives each shard a little depth.
	draw_style_box(panel(Color(1, 1, 1, 0.2 * alpha), radius), Rect2(rect.position + Vector2(4, 3), Vector2(rect.size.x - 8, rect.size.y * 0.3)))
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
	var kind: String = entry.kind if enabled else "disabled"
	match kind:
		"primary":
			draw_style_box(panel(CREAM, 18), rect)
			centered(entry.label, rect if not entry.has("sub") else Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.62)), 28, INK, true)
			if entry.has("sub"):
				centered(entry.sub, Rect2(rect.position + Vector2(0, rect.size.y * 0.5), Vector2(rect.size.x, rect.size.y * 0.42)), 20, EDGE)
		"secondary":
			draw_style_box(panel(EDGE, 18, GOLD, 2), rect)
			centered(entry.label, rect, 26, GOLD, true)
		"danger":
			draw_style_box(panel(Color("3a3436"), 18, CORAL, 2), rect)
			centered(entry.label, rect, 24, CORAL, true)
		"disabled":
			draw_style_box(panel(Color("213c40"), 18, with_alpha(MUTED, 0.5), 1), rect)
			centered(entry.label, rect, 26, MUTED, true)
		"icon":
			rect = rect.grow(-8)
			draw_style_box(panel(CARD, 20, EDGE, 2), rect)
			var c: Vector2 = rect.get_center()
			draw_style_box(panel(CREAM, 3), Rect2(c + Vector2(-14, -16), Vector2(9, 32)))
			draw_style_box(panel(CREAM, 3), Rect2(c + Vector2(5, -16), Vector2(9, 32)))
		"toggle":
			draw_style_box(panel(DEEP, 16), rect)
			label_at(entry.label, rect.position + Vector2(24, 46), 27, CREAM, true)
			label_at(entry.sub, rect.position + Vector2(24, 84), 19, MUTED)
			var track = Rect2(rect.end.x - 112, rect.get_center().y - 22, 88, 44)
			draw_style_box(panel(GOLD if entry.value else EDGE, 22), track)
			var knob_x: float = track.end.x - 40 if entry.value else track.position.x + 4
			draw_style_box(panel(CREAM if entry.value else MUTED, 18), Rect2(knob_x, track.position.y + 4, 36, 36))
		_:
			draw_style_box(panel(CARD, 18, EDGE, 2), rect)
			centered(entry.label, rect, 25, CREAM, true)

# ---------------------------------------------------------------- screens

func _draw() -> void:
	if round_state == null or font == null:
		return
	update_layout()
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_set_transform(layout_offset, 0, Vector2.ONE * layout_scale)
	if route == HOME:
		draw_home()
	else:
		draw_play()
	if dialogs.is_empty():
		for entry in current_buttons():
			draw_button(entry)
	else:
		draw_dialog(dialogs.back())
	draw_set_transform(Vector2.ZERO)

func draw_mountains(base_y: float, scale_y: float) -> void:
	var far = PackedVector2Array([Vector2(-20, base_y), Vector2(90, base_y - 150 * scale_y), Vector2(200, base_y - 70 * scale_y),
		Vector2(330, base_y - 230 * scale_y), Vector2(470, base_y - 110 * scale_y), Vector2(600, base_y - 200 * scale_y), Vector2(740, base_y - 60 * scale_y), Vector2(740, base_y)])
	draw_colored_polygon(far, Color("1f4245"))
	var peak = Vector2(420, base_y - 330 * scale_y)
	var near = PackedVector2Array([Vector2(-20, base_y + 40), Vector2(160, base_y - 120 * scale_y), Vector2(260, base_y - 60 * scale_y),
		peak, Vector2(560, base_y - 150 * scale_y), Vector2(640, base_y - 100 * scale_y), Vector2(740, base_y - 10 * scale_y), Vector2(740, base_y + 40)])
	draw_colored_polygon(near, Color("2b5356"))
	var cap: float = 70 * scale_y
	draw_colored_polygon(PackedVector2Array([peak, peak + Vector2(cap * 0.85, cap), peak + Vector2(cap * 0.35, cap * 0.78),
		peak + Vector2(0, cap * 1.05), peak + Vector2(-cap * 0.45, cap * 0.8), peak + Vector2(-cap * 0.95, cap)]), CREAM.darkened(0.08))

func draw_home() -> void:
	for star in STARS:
		draw_rect(Rect2(star, Vector2(4, 4)), with_alpha(CREAM, 0.55))
	draw_circle(Vector2(590, 150), 46, Color("e9dfb9"))
	draw_circle(Vector2(610, 138), 42, INK)
	draw_mountains(540, 1.0)
	draw_rect(Rect2(0, 560, 720, 720), Color("1d3f43"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 540), Vector2(720, 520), Vector2(720, 600), Vector2(0, 600)]), Color("1d3f43"))
	centered("SUMMIT SHARDS", Rect2(0, 586, 720, 70), 64, CREAM, true)
	centered("A little higher.", Rect2(0, 652, 720, 44), 28, GOLD)
	var stats_rect = Rect2(80, 704, 560, 104)
	draw_style_box(panel(CARD, 20, EDGE, 1), stats_rect)
	var stats = [["BEST", str(profile.best_score)], ["SUMMITS", str(profile.rounds_won)],
		["PLAYED", str(profile.rounds_played)], ["STREAK", str(profile.win_streak)]]
	for i in range(stats.size()):
		var column = Rect2(stats_rect.position.x + i * 140, stats_rect.position.y, 140, stats_rect.size.y)
		centered(stats[i][1], Rect2(column.position + Vector2(0, 8), Vector2(column.size.x, 56)), 36, CREAM, true)
		centered(stats[i][0], Rect2(column.position + Vector2(0, 60), Vector2(column.size.x, 30)), 18, MUTED)
	centered("v%s  -  plays fully offline" % ProjectSettings.get_setting("application/config/version", ""), Rect2(0, 1196, 720, 40), 18, with_alpha(MUTED, 0.7))

func draw_play() -> void:
	var playing: bool = round_state.status == Model.PLAYING
	draw_colored_polygon(PackedVector2Array([Vector2(330, 116), Vector2(455, 22), Vector2(590, 116)]), Color("264b4e"))
	draw_colored_polygon(PackedVector2Array([Vector2(433, 39), Vector2(455, 22), Vector2(479, 40), Vector2(456, 34)]), CREAM.darkened(0.18))
	label_at("SUMMIT SHARDS", Vector2(40, 62), 24, GOLD, true)
	label_at("FLOOR 01  /  TRAIL", Vector2(40, 100), 22, MUTED)
	# Score card.
	var card = Rect2(40, 124, 640, 182)
	draw_style_box(panel(CARD, 18), card)
	label_at("ALTITUDE", Vector2(64, 164), 20, MUTED)
	var shown: String = str(int(display_score))
	label_at(shown, Vector2(64, 232), 60, CREAM, true)
	label_at("/ %d" % round_state.target, Vector2(76 + text_width(shown, 60, true), 230), 26, MUTED)
	right_aligned("BEST %d" % profile.best_score, 656, 164, 20, MUTED)
	right_aligned("TRAY %d / %d" % [round_state.trays_dealt, round_state.max_trays], 656, 204, 22, CREAM, true)
	for i in range(round_state.max_trays):
		var pip = Rect2(656 - (round_state.max_trays - i) * 22 + 4, 218, 14, 14)
		draw_style_box(panel(GOLD if i < round_state.trays_dealt else EDGE, 7), pip)
	if round_state.streak > 0 and playing:
		var chip_text: String = "STREAK x%d" % round_state.streak
		var chip = Rect2(318, 140, text_width(chip_text, 18, true) + 28, 34)
		draw_style_box(panel(with_alpha(GOLD, 0.18), 17, GOLD, 1), chip)
		centered(chip_text, chip, 18, GOLD, true)
	var bar = Rect2(64, 264, 592, 14)
	draw_style_box(panel(EDGE, 7), bar)
	var preview: Dictionary = current_preview()
	var progress: float = clampf(display_score / round_state.target, 0, 1)
	if not preview.is_empty():
		var projected: float = clampf(float(round_state.score + int(preview.points)) / round_state.target, 0, 1)
		draw_style_box(panel(with_alpha(GOLD, 0.4), 7), Rect2(bar.position, Vector2(bar.size.x * projected, bar.size.y)))
	if progress > 0:
		draw_style_box(panel(GOLD, 7), Rect2(bar.position, Vector2(maxf(14, bar.size.x * progress), bar.size.y)))
	draw_board(preview)
	# Hint line.
	if not preview.is_empty():
		var lines: int = int(preview.lines)
		centered("+%d altitude%s" % [preview.points, "" if lines == 0 else "  /  %d %s" % [lines, "line" if lines == 1 else "lines"]], HINT_RECT, 27, GOLD, true)
	else:
		centered(notice, HINT_RECT, 23, GOLD if not playing else MUTED)
	draw_tray()
	if dragging and selected >= 0:
		draw_drag_ghost()

## The selected shard's placement at the hovered cell, if it is legal.
func current_preview() -> Dictionary:
	if selected < 0 or hover_cell.x < 0 or round_state.status != Model.PLAYING:
		return {}
	var piece: Dictionary = round_state.tray[selected]
	if not round_state.can_place(piece, hover_cell.x, hover_cell.y):
		return {}
	var result: Dictionary = round_state.preview(piece, hover_cell.x, hover_cell.y)
	result.cells = round_state.piece_cells(piece, hover_cell.x, hover_cell.y)
	result.element = int(piece.element)
	return result

func draw_board(preview: Dictionary) -> void:
	var shake: Vector2 = effects.shake_offset()
	draw_set_transform(layout_offset + shake * layout_scale, 0, Vector2.ONE * layout_scale)
	draw_style_box(panel(DEEP, 16), BOARD_RECT.grow(10))
	for index in range(64):
		tile_at(cell_rect(index), int(round_state.board[index]), 1.0, effects.pop_scale(index))
	if not preview.is_empty():
		for index in preview.cells:
			tile_at(cell_rect(index), preview.element, 0.55)
		if settings.get_value("clear_preview"):
			for index in preview.cleared:
				draw_style_box(panel(with_alpha(GOLD, 0.16), 10, GOLD, 3), cell_rect(index).grow(1))
	elif selected >= 0 and hover_cell.x >= 0 and hover_cell.y >= 0 and hover_cell.x < 8 and hover_cell.y < 8 and round_state.status == Model.PLAYING:
		# Show where an illegal placement collides, in coral.
		var piece: Dictionary = round_state.tray[selected]
		for cell in round_state.shapes[int(piece.shape)].cells:
			var p: Vector2i = hover_cell + cell
			if p.x < 8 and p.y < 8:
				draw_style_box(panel(with_alpha(CORAL, 0.18), 10, CORAL, 3), cell_rect(p.y * 8 + p.x))
	for entry in effects.clears:
		var t: float = effects.clear_progress(entry)
		var rect: Rect2 = cell_rect(entry.index)
		tile_at(rect, entry.element, 1.0 - t, 1.0 - 0.45 * t)
		if t < 0.4:
			draw_style_box(panel(Color(1, 1, 1, 0.7 * (1.0 - t / 0.4)), 10), rect)
	for entry in effects.particles:
		var state: Dictionary = effects.particle_state(entry)
		draw_rect(Rect2(state.pos - Vector2.ONE * entry.size * 0.5, Vector2.ONE * entry.size), with_alpha(entry.color, state.alpha))
	for entry in effects.texts:
		var state: Dictionary = effects.text_state(entry)
		var point: Vector2 = state.pos + shake
		draw_set_transform(layout_offset + point * layout_scale, 0, Vector2.ONE * layout_scale * state.scale)
		var width: float = text_width(entry.text, entry.size, true)
		label_at(entry.text, Vector2(-width * 0.5 + 3, entry.size * 0.34 + 3), entry.size, Color(0, 0, 0, 0.45 * state.alpha), true)
		label_at(entry.text, Vector2(-width * 0.5, entry.size * 0.34), entry.size, with_alpha(entry.color, state.alpha), true)
	draw_set_transform(layout_offset, 0, Vector2.ONE * layout_scale)

func draw_piece(piece: Dictionary, center: Vector2, pitch: float, alpha: float = 1.0) -> void:
	var extent: Vector2 = Vector2(piece_extent(piece))
	var origin: Vector2 = center - extent * pitch * 0.5
	var gap: float = maxf(2.0, pitch * 0.08)
	for cell in round_state.shapes[int(piece.shape)].cells:
		tile_at(Rect2(origin + Vector2(cell) * pitch, Vector2.ONE * (pitch - gap)), int(piece.element), alpha)

func draw_tray() -> void:
	for slot in range(3):
		var rect: Rect2 = tray_rect(slot)
		var piece: Dictionary = round_state.tray[slot]
		var is_selected: bool = selected == slot
		draw_style_box(panel(Color("2b5054") if is_selected else CARD, 18, GOLD if is_selected else EDGE, 3 if is_selected else 1), rect)
		if piece.is_empty():
			centered("PLACED", rect, 20, with_alpha(MUTED, 0.6))
			continue
		var extent: Vector2i = piece_extent(piece)
		var pitch: float = minf(36.0, 130.0 / maxi(extent.x, extent.y))
		var alpha: float = 1.0
		if is_selected and dragging:
			alpha = 0.25
		elif not _fits[slot] and round_state.status == Model.PLAYING:
			alpha = 0.35
		draw_piece(piece, rect.get_center() - Vector2(0, 6 if not _fits[slot] else 0), pitch, alpha)
		if not _fits[slot] and round_state.status == Model.PLAYING:
			centered("NO ROOM", Rect2(rect.position.x, rect.end.y - 34, rect.size.x, 26), 17, CORAL, true)

func draw_drag_ghost() -> void:
	var piece: Dictionary = round_state.tray[selected]
	if piece.is_empty():
		return
	# Same geometry as drag_anchor: the shard's centre floats DRAG_LIFT above the finger.
	draw_piece(piece, drag_point - Vector2(0, DRAG_LIFT), CELL, 0.85)

func draw_dialog(id: String) -> void:
	var alpha: float = 1.0
	if result_delay > 0.0:
		alpha = clampf((effects.time - dialog_opened_at - result_delay) / 0.25, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var screen = Rect2(-layout_offset / layout_scale, size / layout_scale)
	draw_rect(screen, Color(0.02, 0.07, 0.08, 0.74 * alpha))
	var card: Rect2 = dialog_card(id)
	if alpha < 1.0:
		card.position.y += (1.0 - alpha) * 40.0
	draw_style_box(panel(INK, 26, EDGE, 2), card)
	var top: float = card.position.y
	var inner = Rect2(card.position.x + 40, top, card.size.x - 80, card.size.y)
	match id:
		"pause":
			centered("PAUSED", Rect2(card.position.x, top + 36, card.size.x, 56), 44, CREAM, true)
			centered("Altitude %d / %d  -  Tray %d / %d" % [round_state.score, round_state.target, round_state.trays_dealt, round_state.max_trays],
				Rect2(card.position.x, top + 100, card.size.x, 36), 21, MUTED)
		"settings":
			centered("SETTINGS", Rect2(card.position.x, top + 30, card.size.x, 60), 40, CREAM, true)
		"help":
			centered("HOW TO PLAY", Rect2(card.position.x, top + 30, card.size.x, 60), 40, CREAM, true)
			var y: float = top + 120
			for i in range(HELP_LINES.size()):
				var badge = Rect2(inner.position.x, y + 2, 44, 44)
				draw_style_box(panel(GOLD, 22), badge)
				centered(str(i + 1), badge, 22, INK, true)
				y += maxf(56.0, wrapped(HELP_LINES[i], Vector2(inner.position.x + 64, y), inner.size.x - 64, 24, CREAM)) + 22
			var sample_y: float = minf(y + 6, card.end.y - 250)
			label_at("SYMBOLS", Vector2(inner.position.x, sample_y + 20), 18, MUTED)
			for e in range(1, 6):
				tile_at(Rect2(inner.position.x + (e - 1) * 66, sample_y + 36, 56, 56), e)
		"result":
			var won: bool = round_state.status == Model.WON
			centered("SUMMIT REACHED" if won else "TRAIL ENDS", Rect2(card.position.x, top + 34, card.size.x, 60), 42, GOLD if won else CREAM, true)
			centered("Floor 01 Trail complete." if won else "Out of moves. Every climb teaches.", Rect2(card.position.x, top + 96, card.size.x, 36), 22, MUTED)
			centered(str(round_state.score), Rect2(card.position.x, top + 140, card.size.x, 110), 92, CREAM, true)
			centered("ALTITUDE  /  %d" % round_state.target, Rect2(card.position.x, top + 250, card.size.x, 30), 20, MUTED)
			if last_summary.get("new_best", false):
				var badge = Rect2(card.get_center().x - 90, top + 296, 180, 42)
				draw_style_box(panel(GOLD, 21), badge)
				centered("NEW BEST", badge, 22, INK, true)
			var rows = [["Lines cleared", str(round_state.lines_total)], ["Best move", "+%d" % round_state.best_move],
				["Trays used", "%d / %d" % [round_state.trays_dealt, round_state.max_trays]], ["Summit streak", str(profile.win_streak)]]
			for i in range(rows.size()):
				var y: float = top + 380 + i * 70
				draw_style_box(panel(DEEP, 14), Rect2(inner.position.x, y, inner.size.x, 58))
				label_at(rows[i][0], Vector2(inner.position.x + 22, y + 38), 23, MUTED)
				right_aligned(rows[i][1], inner.end.x - 22, y + 39, 25, CREAM, true)
		_:
			var titles = {"confirm_new": "Start a new trail?", "confirm_exit": "Leave Summit Shards?", "confirm_reset": "Reset statistics?"}
			var bodies = {"confirm_new": "This trail ends here and counts as played.",
				"confirm_exit": "Your trail is saved. Pick up where you left off next time.",
				"confirm_reset": "Best altitude, summits and streaks go back to zero. Your current trail and settings stay."}
			centered(titles.get(id, ""), Rect2(card.position.x, top + 34, card.size.x, 60), 36, CREAM, true)
			wrapped(bodies.get(id, ""), Vector2(inner.position.x, top + 110), inner.size.x, 24, MUTED)
	for entry in dialog_buttons(id):
		var rect: Rect2 = entry.rect
		rect.position.y += (1.0 - alpha) * 40.0
		entry.rect = rect
		draw_button(entry)

# ---------------------------------------------------------------- persistence

func save_settings() -> bool:
	return Store.write(settings_path, settings.to_dict())

func save_profile() -> bool:
	return Store.write(profile_path, profile.to_dict())

func save_round() -> bool:
	if round_state == null:
		return false
	var payload: String = JSON.stringify(round_state.snapshot())
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
		if data is Dictionary and round_state.restore_snapshot(data):
			_loaded_from_backup = path != save_path
			_last_saved_sha = JSON.stringify(round_state.snapshot()).sha256_text()
			selected = -1
			cancel_gesture()
			effects.clear_all()
			display_score = round_state.score
			refresh_derived()
			notice = "Your trail is right where you left it."
			set_end_notice()
			return true
	return false
