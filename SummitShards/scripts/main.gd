extends Control
## Portrait touch adapter. Rules live in round_model.gd; drawing never changes them.
const Model = preload("res://scripts/round_model.gd")
const INK = Color("18383d")
const CREAM = Color("f4f0df")
const MUTED = Color("a9b9af")
const GOLD = Color("e7bf73")
const COLORS = [Color("2a484a"), Color("7bbde2"), Color("e6e4cd"), Color("ed9781"), Color("85bca1"), Color("d8ba78")]
const SYMBOLS = ["", "+", "o", "^", "~", "#"]
const BOARD_RECT = Rect2(56, 330, 608, 608)
const NEW_RECT = Rect2(40, 1170, 310, 96)
const REROLL_RECT = Rect2(370, 1170, 310, 96)

var round_state: RefCounted
var selected: int = -1
var hover_cell = Vector2i(-1, -1)
var notice: String = "Choose a shard, then tap its top-left cell."
var save_path: String = "user://round-v1.json"
var layout_scale: float = 1.0
var layout_offset = Vector2.ZERO
var font: Font
var _style_cache: Dictionary = {}
var _last_saved_sha: String = ""
var _loaded_from_backup: bool = false

func _ready() -> void:
	font = ThemeDB.fallback_font
	round_state = Model.new(20261024)
	load_round()
	get_tree().auto_accept_quit = false
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_round()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if selected >= 0:
			selected = -1
			hover_cell = Vector2i(-1, -1)
			notice = "Choose a shard, then tap its top-left cell."
			queue_redraw()
		else:
			save_round()
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_round()
		hover_cell = Vector2i(-1, -1)
	elif what == NOTIFICATION_RESIZED or what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		queue_redraw()

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

func label_at(text: String, point: Vector2, font_size: int, color: Color = CREAM) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func centered(text: String, rect: Rect2, font_size: int, color: Color = CREAM) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	label_at(text, Vector2(rect.get_center().x - width * 0.5, rect.get_center().y + font_size * 0.34), font_size, color)

func tile_at(rect: Rect2, element: int, ghost: bool = false) -> void:
	var color: Color = COLORS[element]
	if ghost:
		color.a = 0.55
	draw_style_box(panel(color, 8), rect)
	if element != 0:
		centered(SYMBOLS[element], rect, maxi(16, int(rect.size.y * 0.45)), INK)

func panel(color: Color, radius: int, border_color: Color = Color.TRANSPARENT, border: int = 0) -> StyleBoxFlat:
	# Reuse immutable drawing resources instead of allocating a style per tile
	# on every preview, tap or animation frame.
	var key: String = "%d:%d:%d:%d" % [color.to_rgba32(), radius, border_color.to_rgba32(), border]
	if _style_cache.has(key):
		return _style_cache[key]
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border_color
	style.set_border_width_all(border)
	_style_cache[key] = style
	return style

func tray_rect(slot: int) -> Rect2:
	return Rect2(40 + slot * 222, 1030, 204, 122)

func _draw() -> void:
	if round_state == null or font == null:
		return
	update_layout()
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_set_transform(layout_offset, 0, Vector2.ONE * layout_scale)
	draw_colored_polygon(PackedVector2Array([Vector2(390, 174), Vector2(545, 24), Vector2(710, 174)]), Color("264b4e"))
	draw_colored_polygon(PackedVector2Array([Vector2(520, 48), Vector2(545, 24), Vector2(576, 52), Vector2(549, 45)]), CREAM.darkened(0.18))
	label_at("S U M M I T  S H A R D S", Vector2(40, 48), 24, GOLD)
	label_at("A little higher.", Vector2(40, 113), 48)
	label_at("FLOOR 01   /   TRAIL", Vector2(40, 157), 24, MUTED)
	draw_style_box(panel(Color("24464a"), 16), Rect2(40, 192, 640, 112))
	label_at("ALTITUDE", Vector2(60, 224), 21, MUTED)
	label_at(str(round_state.score), Vector2(60, 268), 40)
	label_at("/ %d" % round_state.target, Vector2(195, 266), 25, MUTED)
	label_at("TRAY %d / %d" % [round_state.trays_dealt, round_state.max_trays], Vector2(462, 234), 24, CREAM)
	draw_style_box(panel(Color("345457"), 4), Rect2(60, 283, 600, 7))
	var progress: float = clampf(float(round_state.score) / round_state.target, 0, 1)
	if progress > 0:
		draw_style_box(panel(GOLD, 4), Rect2(60, 283, 600 * progress, 7))
	draw_style_box(panel(Color("122d32"), 14), BOARD_RECT.grow(10))
	for y in range(8):
		for x in range(8):
			tile_at(Rect2(59 + x * 76, 333 + y * 76, 70, 70), int(round_state.board[y * 8 + x]))
	if selected >= 0 and round_state.status == Model.PLAYING and hover_cell.x >= 0:
		var piece: Dictionary = round_state.tray[selected]
		if round_state.can_place(piece, hover_cell.x, hover_cell.y):
			for cell in round_state.shapes[int(piece.shape)].cells:
				tile_at(Rect2(59 + (cell.x + hover_cell.x) * 76, 333 + (cell.y + hover_cell.y) * 76, 70, 70), int(piece.element), true)
			var preview: Dictionary = round_state.preview(piece, hover_cell.x, hover_cell.y)
			centered("+%d altitude" % preview.points, Rect2(40, 950, 640, 55), 26, GOLD)
		else:
			centered(notice, Rect2(40, 950, 640, 55), 24, MUTED)
	else:
		centered(notice, Rect2(40, 950, 640, 55), 24, GOLD if round_state.status != Model.PLAYING else MUTED)
	for slot in range(3):
		var rect = tray_rect(slot)
		draw_style_box(panel(Color("24464a"), 14, GOLD if selected == slot else Color("345457"), 3 if selected == slot else 1), rect)
		var piece: Dictionary = round_state.tray[slot]
		if piece.is_empty():
			centered("PLACED", rect, 22, MUTED)
			continue
		var cells: Array = round_state.shapes[int(piece.shape)].cells
		var extent = Vector2i.ONE
		for cell in cells:
			extent = extent.max(cell + Vector2i.ONE)
		var pitch: float = minf(28, 90.0 / extent.y)
		var origin: Vector2 = rect.get_center() - Vector2(extent) * pitch * 0.5
		for cell in cells:
			tile_at(Rect2(origin + Vector2(cell) * pitch, Vector2.ONE * (pitch - 3)), int(piece.element))
	draw_style_box(panel(CREAM, 14), NEW_RECT)
	centered("NEW ROUND", NEW_RECT, 25, INK)
	var enabled: bool = round_state.status == Model.PLAYING and round_state.rerolls > 0
	draw_style_box(panel(Color("345457") if enabled else Color("213c40"), 14, GOLD if enabled else MUTED, 1), REROLL_RECT)
	centered("REROLL  %d" % round_state.rerolls, REROLL_RECT, 25, GOLD if enabled else MUTED)
	draw_set_transform(Vector2.ZERO)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		update_layout()
		handle_click((event.position - layout_offset) / layout_scale)
	elif event is InputEventMouseMotion:
		if selected < 0 or round_state.status != Model.PLAYING:
			return
		update_layout()
		var local: Vector2 = (event.position - layout_offset) / layout_scale
		var next_cell = Vector2i((local - BOARD_RECT.position) / 76.0) if BOARD_RECT.has_point(local) else Vector2i(-1, -1)
		if next_cell != hover_cell:
			hover_cell = next_cell
			queue_redraw()

func handle_click(point: Vector2) -> void:
	if NEW_RECT.has_point(point):
		round_state = Model.new(int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec())
		selected = -1
		hover_cell = Vector2i(-1, -1)
		notice = "Choose a shard, then tap its top-left cell."
		save_round()
	elif REROLL_RECT.has_point(point):
		if round_state.try_reroll():
			selected = -1
			notice = "Fresh shards. Make them count."
			save_round()
	elif round_state.status == Model.PLAYING:
		for slot in range(3):
			if tray_rect(slot).has_point(point) and not round_state.tray[slot].is_empty():
				selected = slot
				notice = "Tap the board to place the top-left corner."
				hover_cell = Vector2i(-1, -1)
		if selected >= 0 and BOARD_RECT.has_point(point):
			var cell = Vector2i((point - BOARD_RECT.position) / 76.0)
			var result: Dictionary = round_state.try_place(selected, cell.x, cell.y)
			if result.ok:
				selected = -1
				notice = "+%d altitude  /  %d lines" % [result.points, result.lines]
				save_round()
			else:
				notice = "That shard needs a little more room."
	set_end_notice()
	queue_redraw()

func set_end_notice() -> void:
	if round_state.status == Model.WON:
		notice = "Trail complete. The summit can wait."
	elif round_state.status == Model.LOST:
		notice = "Rest here. A fresh trail is one tap away."

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
			notice = "Your trail is right where you left it."
			set_end_notice()
			return true
	return false
