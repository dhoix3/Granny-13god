class_name GameUI
extends Control

# Весь интерфейс игры рисуется вручную, как в оригинале:
# заголовок, сложность, помощь, вступление, HUD, дневник, пауза,
# экраны поимки, победы и проигрыша.

var game: GrannyGame
var face_tex: Texture2D

# Ховер и прямоугольники кликов для меню-экранов.
var hover_idx := -1
var hover_row_frac := 0.5
var hover_rects: Array[Rect2] = []
var slider_rects: Array[Rect2] = []
var diff_rects: Array[Rect2] = []
var _saves_cache: Array[SaveSystem.SlotMeta] = []
var _last_ui_state := -1

const BONE := Color(0.90, 0.87, 0.80)
const DIM := Color(0.62, 0.60, 0.55)
const AMBER := Color(0.86, 0.68, 0.30)
const BLOOD := Color(0.72, 0.13, 0.11)
const PAPER := Color(0.89, 0.85, 0.75)

func setup(g: GrannyGame) -> void:
	game = g
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(queue_redraw)
	face_tex = load("res://assets/granny_face.png")

func update_hover(_state: int) -> void:
	if game != null and game.state != _last_ui_state:
		_last_ui_state = game.state
		_refresh_saves_cache()
		hover_idx = -1
		hover_row_frac = 0.5
		return  # ждём перерисовку нового экрана — старые прямоугольники невалидны
	hover_idx = -1
	var mp := get_global_mouse_position()
	for i in hover_rects.size():
		if hover_rects[i].has_point(mp):
			hover_idx = i
			break
	if slider_rects.size() > 0 and hover_idx >= 0 and hover_idx < slider_rects.size():
		var r := slider_rects[hover_idx]
		if r.size.x > 0.0:
			hover_row_frac = clampf((mp.x - r.position.x) / r.size.x, 0.0, 1.0)
		else:
			hover_row_frac = 0.5
	else:
		hover_row_frac = 0.5

func hover_diff_index() -> int:
	var mp := get_global_mouse_position()
	for i in diff_rects.size():
		if diff_rects[i].has_point(mp):
			return i
	return -1

func _refresh_saves_cache() -> void:
	_saves_cache.clear()
	for m in SaveSystem.read_all_metas():
		_saves_cache.append(m)

func _saves_meta(i: int) -> SaveSystem.SlotMeta:
	if i >= 0 and i < _saves_cache.size():
		return _saves_cache[i]
	var m := SaveSystem.SlotMeta.new()
	return m

func _draw() -> void:
	if game == null:
		return
	var W := size.x
	var H := size.y
	if game.state != _last_ui_state:
		_last_ui_state = game.state
		_refresh_saves_cache()
		hover_idx = -1
	match game.state:
		GrannyGame.STATE_TITLE:
			_draw_title(W, H)
		GrannyGame.STATE_DIFF:
			_draw_diff(W, H)
		GrannyGame.STATE_HELP:
			_draw_help(W, H)
		GrannyGame.STATE_SETTINGS:
			_draw_settings(W, H)
		GrannyGame.STATE_SAVE, GrannyGame.STATE_LOAD:
			_draw_saves(W, H)
		GrannyGame.STATE_INTRO:
			_draw_intro(W, H)
		GrannyGame.STATE_PLAY:
			_draw_hud(W, H)
			if game.journal:
				_draw_journal(W, H)
			if game.fade_t > 0.0:
				draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, game.fade_t))
		GrannyGame.STATE_PAUSE:
			_draw_hud(W, H)
			_draw_pause(W, H)
		GrannyGame.STATE_CAUGHT:
			_draw_caught(W, H)
		GrannyGame.STATE_WIN:
			_draw_win(W, H)
		GrannyGame.STATE_OVER:
			_draw_over(W, H)
	if game.debug_on:
		_draw_debug(W, H)

# ------------------------------------------------------------------ helpers

func _f() -> Font:
	return ThemeDB.fallback_font

func _tw(text: String, sz: int) -> float:
	return _f().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x

func _text(x: float, y: float, text: String, sz: int, col: Color) -> void:
	draw_string(_f(), Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _ctext(cx: float, y: float, text: String, sz: int, col: Color) -> void:
	draw_string(_f(), Vector2(cx - _tw(text, sz) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _shadow_text(x: float, y: float, text: String, sz: int, col: Color, off := 3.0) -> void:
	_text(x + off, y + off, text, sz, Color(0, 0, 0, 0.8))
	_text(x, y, text, sz, col)

func _shadow_ctext(cx: float, y: float, text: String, sz: int, col: Color, off := 3.0) -> void:
	_ctext(cx + off, y + off, text, sz, Color(0, 0, 0, 0.8))
	_ctext(cx, y, text, sz, col)

func _panel(r: Rect2, fill: Color, border := Color(0, 0, 0, 0), bw := 1.5) -> void:
	draw_rect(r, fill)
	if border.a > 0.0:
		draw_rect(r, border, false, bw)

func _bar(x: float, y: float, w: float, h: float, v: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, h), Color(0.06, 0.06, 0.08, 0.85))
	draw_rect(Rect2(x, y, w * clampf(v, 0.0, 1.0), h), col)
	draw_rect(Rect2(x, y, w, h), Color(0.55, 0.52, 0.46, 0.35), false, 1.0)

func _lock_icon(x: float, y: float, opened: bool) -> void:
	var col := Color(0.30, 0.62, 0.30) if opened else Color(0.78, 0.22, 0.18)
	draw_rect(Rect2(x, y + 8, 16, 12), col)
	draw_arc(Vector2(x + 8, y + 8), 6.0, PI, TAU, 12, col, 2.0)
	if opened:
		draw_line(Vector2(x + 3, y + 14), Vector2(x + 7, y + 18), Color(0.9, 0.95, 0.9), 1.6)
		draw_line(Vector2(x + 7, y + 18), Vector2(x + 13, y + 10), Color(0.9, 0.95, 0.9), 1.6)

func _draw_debug(W: float, H: float) -> void:
	var p := game.player
	var lv := game.world.levels[p.level]
	var pp := p.global_position - lv.origin
	var lines := [
		"F1 DEBUG",
		"уровень: %d  %s" % [p.level, lv.name],
		"игрок: %.2f, %.2f  угол %.2f" % [pp.x, pp.z, p.angle],
		"гренни: %.2f, %.2f  ур.%d  сост.%d" % [game.granny.x, game.granny.y, game.granny.level, game.granny.state],
		"кошка: %.2f, %.2f  злая:%s  сыта:%s" % [game.cat.x, game.cat.y, str(game.cat.angry), str(game.cat.fed)],
		"шумов: %d  цель: %d  прогресс: %.2f" % [game.noises.size(), game.target_kind, game.interact_prog],
		"капканы: %d  FPS: %d" % [lv.traps.size(), Engine.get_frames_per_second()],
	]
	var r := Rect2(W - 330.0, 92.0, 306.0, 24.0 + lines.size() * 17.0)
	_panel(r, Color(0.01, 0.01, 0.02, 0.82), Color(0.62, 0.58, 0.48, 0.4), 1.0)
	for i in lines.size():
		_text(r.position.x + 10.0, r.position.y + 20.0 + i * 17.0, lines[i], 12, Color(0.78, 0.86, 0.74, 0.9) if i == 0 else Color(0.78, 0.75, 0.68, 0.85))

# ------------------------------------------------------------------ title

func _draw_title(W: float, H: float) -> void:
	hover_rects.clear()
	slider_rects.clear()
	draw_rect(Rect2(0, 0, W, H), Color(0.004, 0.004, 0.008, 0.52))
	for i in 7:
		var t := game.time * 0.05 + i * 1.7
		var x := (sin(t) * 0.5 + 0.5) * W
		var y := (cos(t * 0.7 + i) * 0.5 + 0.5) * H
		draw_circle(Vector2(x, y), 170.0 + i * 34.0, Color(0.32, 0.32, 0.38, 0.018))
	var title_w := _tw("ГРЕННИ", 86)
	_shadow_text(92, 172, "ГРЕННИ", 86, Color(0.90, 0.88, 0.83), 4.0)
	_shadow_text(92 + title_w + 20, 132, "13", 118, Color(0.74, 0.12, 0.11), 4.0)
	_text(96, 220, "ПОБЕГ ОТ БАБУШКИ", 27, Color(0.76, 0.71, 0.63, 0.92))
	draw_line(Vector2(96, 250), Vector2(524, 250), Color(0.74, 0.16, 0.13, 0.55), 2.0)
	_text(98, 274, "пародия на Granny · 4 этажа · 5 сложностей", 14, Color(0.62, 0.59, 0.53, 0.8))
	var my := 296.0
	for i in game.menu_items.size():
		var sel := i == game.menu_idx
		var inactive := (i == 0 or i == 2) and not game.has_saves
		var item_col := Color(0.96, 0.93, 0.87) if sel else (Color(0.40, 0.38, 0.35) if inactive else Color(0.68, 0.65, 0.59))
		var rect := Rect2(82, my - 30, 380, 46)
		hover_rects.append(rect)
		if sel:
			_panel(rect, Color(0.42, 0.10, 0.09, 0.34), Color(0.74, 0.16, 0.13, 0.8), 2.0)
			_text(92, my, "►", 26, BLOOD)
		elif hover_idx == i and not inactive:
			_panel(rect, Color(0.42, 0.10, 0.09, 0.20), Color(0.74, 0.16, 0.13, 0.35), 1.4)
		_text(122, my, game.menu_items[i], 25 if sel else 22, item_col)
		my += 50.0
	_panel(Rect2(92, 620, 430, 54), Color(0.08, 0.08, 0.10, 0.65), Color(0.55, 0.50, 0.42, 0.35), 1.0)
	_text(106, 640, "СЛОЖНОСТЬ:", 12, DIM)
	_text(230, 646, game.diffs[game.diff_index].name, 20, AMBER)
	if game.title_hint_t > 0.0 and game.title_hint != "":
		var hint_a := clampf(game.title_hint_t * 2.0, 0.0, 1.0)
		_ctext(W * 0.5 + 110, 585, game.title_hint, 15, Color(0.90, 0.79, 0.48, hint_a))
	_ctext(W * 0.5 + 110, H - 40, "↑ ↓ — выбор    Enter — подтвердить    мышь — тоже работает", 13, Color(0.58, 0.56, 0.50, 0.8))
	# лёгкая красная рамка-виньетка
	draw_rect(Rect2(0, 0, W, H), Color(0.20, 0.01, 0.01, 0.05), false, 24.0)

# ------------------------------------------------------------------ difficulty

func _draw_diff(W: float, H: float) -> void:
	diff_rects.clear()
	draw_rect(Rect2(0, 0, W, H), Color(0.012, 0.012, 0.018, 0.98))
	_shadow_ctext(W * 0.5, 66, "ВЫБЕРИ СЛОЖНОСТЬ", 34, Color(0.93, 0.90, 0.84), 3.0)
	_ctext(W * 0.5, 108, "чем сложнее — тем быстрее бабушка и тем меньше у тебя дней", 14, DIM)
	var n := game.diffs.size()
	var gap := 12.0
	var margin := 30.0
	var cw := (W - margin * 2.0 - gap * (n - 1)) / n
	var total := n * cw + gap * (n - 1)
	var x0 := (W - total) * 0.5
	for i in n:
		var d = game.diffs[i]
		var x := x0 + i * (cw + gap)
		var y := 150.0
		var h := 438.0
		diff_rects.append(Rect2(x, y, cw, h))
		var sel := i == game.diff_idx_menu
		var cur := i == game.diff_index
		_panel(Rect2(x, y, cw, h), Color(0.09, 0.05, 0.06, 0.9) if sel else Color(0.055, 0.055, 0.07, 0.9), BLOOD if sel else Color(0.35, 0.33, 0.30, 0.55), 3.0 if sel else 1.4)
		if cur:
			_text(x + 12, y + 20, "ТЕКУЩАЯ", 11, AMBER)
		_ctext(x + cw * 0.5, y + 56, d.name, 20, BONE if sel else Color(0.75, 0.72, 0.66))
		var by := y + 92.0
		_diff_bar(x + 22, by, cw - 44, "СКОРОСТЬ", (d.run - 1.6) / 1.6, BLOOD)
		by += 48.0
		_diff_bar(x + 22, by, cw - 44, "СЛУХ", (d.hear_mul - 0.6) / 1.1, AMBER)
		by += 48.0
		_diff_bar(x + 22, by, cw - 44, "ЗРЕНИЕ", (d.sight - 6.0) / 10.0, Color(0.45, 0.58, 0.82))
		by += 48.0
		_diff_bar(x + 22, by, cw - 44, "КАПКАНЫ", float(d.traps) / 8.0, Color(0.66, 0.43, 0.24))
		by += 46.0
		_text(x + 22, by, "ДНЕЙ: " + str(d.days), 16, BONE)
		by += 34.0
		draw_multiline_string(_f(), Vector2(x + 20, by), d.desc, HORIZONTAL_ALIGNMENT_LEFT, cw - 40, 12, -1, Color(0.68, 0.64, 0.58))
		if sel:
			draw_rect(Rect2(x - 4, y - 4, cw + 8, h + 8), Color(0.74, 0.16, 0.13, 0.9), false, 2.0)
	_ctext(W * 0.5, H - 42, "← → / мышь — выбрать      Enter — играть      Esc — назад", 14, Color(0.66, 0.62, 0.56))

func _diff_bar(x: float, y: float, w: float, label: String, v: float, col: Color) -> void:
	_text(x, y, label, 10, Color(0.66, 0.62, 0.56))
	draw_rect(Rect2(x, y + 8, w, 8), Color(0.12, 0.12, 0.14, 0.9))
	draw_rect(Rect2(x, y + 8, w * clampf(v, 0.0, 1.0), 8), col)
	for i in range(1, 10):
		draw_line(Vector2(x + w * i / 10.0, y + 8), Vector2(x + w * i / 10.0, y + 16), Color(0, 0, 0, 0.35), 1.0)

# ------------------------------------------------------------------ help

func _draw_help(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.008, 0.008, 0.013, 0.98))
	_shadow_ctext(W * 0.5, 64, "КАК ИГРАТЬ", 36, BONE, 3.0)
	var keys := [
		"W A S D / стрелки — ходить",
		"Мышь — осматриваться",
		"SHIFT — бежать (тратит выносливость и ОЧЕНЬ шумит)",
		"CTRL / C — красться (тихо, но медленно)",
		"E — открыть дверь, обыскать шкаф, спрятаться, лезть на чердак",
		"F — фонарик (свет видит Гренни), M — карта",
		"G — бросить бутылку: звон стекла уводит её в другую комнату",
		"Q — выстрел из арбалета стрелой с транквилизатором (ПКМ — прицел)",
		"TAB — дневник: что найдено, что открыто, что помнить",
		"ПРОБЕЛ — вырваться из капкана",
		"ESC — пауза, F11 — полный экран",
	]
	var y := 136.0
	for s in keys:
		_text(112, y, "•", 20, BLOOD)
		_text(140, y, s, 15, Color(0.80, 0.77, 0.71))
		y += 34.0
	y += 8.0
	_panel(Rect2(96, y, W - 192, 150), Color(0.14, 0.07, 0.06, 0.55), Color(0.62, 0.22, 0.18, 0.45), 1.4)
	_text(120, y + 32, "ЦЕЛЬ: открыть три замка на входной двери", 20, AMBER)
	_text(124, y + 72, "1. Висячий замок   — ключ от замка", 15, BONE)
	_text(124, y + 100, "2. Ржавый засов    — монтировка", 15, BONE)
	_text(124, y + 128, "3. Кодовый замок   — записка с кодом (она на чердаке)", 15, BONE)
	_ctext(W * 0.5, H - 34, "Enter / Esc — назад", 14, DIM)

# ------------------------------------------------------------------ intro

func _draw_intro(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.006, 0.006, 0.010, 0.98))
	for i in 7:
		var t := game.time * 0.04 + i * 1.9
		var x := (sin(t) * 0.5 + 0.5) * W
		var y := (cos(t * 0.6 + i) * 0.5 + 0.5) * H
		draw_circle(Vector2(x, y), 200.0 + i * 38.0, Color(0.30, 0.30, 0.36, 0.02))
	_shadow_ctext(W * 0.5, 104, "ДЕНЬ 1", 40, Color(0.80, 0.16, 0.13), 3.0)
	_ctext(W * 0.5, 210, "Ты приехал к бабушке на выходные. Остался ночевать.", 23, Color(0.88, 0.84, 0.78))
	_ctext(W * 0.5, 258, "Утром дверь оказалась заперта снаружи, а на кухне кто-то точил нож.", 23, Color(0.88, 0.84, 0.78))
	_ctext(W * 0.5, 322, "У тебя " + str(game.diff.days) + " дней, чтобы найти ключи, открыть дверь и унести ноги.", 23, Color(0.90, 0.59, 0.24))
	_ctext(W * 0.5, 390, "На чердаке живёт её кошка Маруся. Она очень громкая.", 16, Color(0.68, 0.65, 0.59))
	_panel(Rect2(W * 0.5 - 300, 470, 600, 128), Color(0.14, 0.06, 0.055, 0.65), Color(0.62, 0.20, 0.17, 0.45), 1.4)
	_ctext(W * 0.5, 506, "НЕ БЕГИ БЕЗ ПРИЧИНЫ.", 21, BLOOD)
	_ctext(W * 0.5, 542, "Она слышит каждый шаг.", 15, BONE)
	_ctext(W * 0.5, 570, "Она ставит капканы.", 15, BONE)
	var pulse := 0.72 + 0.28 * sin(game.time * 3.0)
	_ctext(W * 0.5, 662, "Нажми Enter, чтобы начать", 16, Color(0.90, 0.79, 0.48, pulse))

# ------------------------------------------------------------------ HUD

func _draw_hud(W: float, H: float) -> void:
	var p := game.player
	# прицел
	draw_circle(Vector2(W * 0.5, H * 0.5), 1.6, Color(1, 1, 1, 0.35))
	# индикатор обнаружения
	if game.detect_fx > 0.02:
		var a := clampf(game.detect_fx, 0.0, 1.0)
		draw_arc(Vector2(W * 0.5, 92), 30.0, PI * 0.15, PI * 0.85, 20, Color(0.85, 0.15, 0.12, a), 2.6)
		draw_arc(Vector2(W * 0.5, 92), 30.0, PI * 1.15, PI * 1.85, 20, Color(0.85, 0.15, 0.12, a), 2.6)
		_ctext(W * 0.5, 78, "!", 26, Color(0.90, 0.25, 0.20, a))
	# замки
	_text(24, 30, "ЗАМКИ", 11, DIM)
	for i in 3:
		_lock_icon(24 + i * 24, 38, game.locks[i])
	_text(24, 76, str(game.count_locks()) + "/3" + ("  + код" if game.lock4 else ""), 14, BONE)
	# день
	var day_text := "ДЕНЬ " + str(game.day) + " / " + str(game.max_days)
	_text(W - 24 - _tw(day_text, 19), 34, day_text, 19, BONE)
	var lock_text := "замки: " + str(game.count_locks()) + "/3"
	_text(W - 24 - _tw(lock_text, 12), 54, lock_text, 12, DIM)
	# миникарта
	if game.minimap:
		_draw_minimap(W, H)
	# полосы
	var bx := 24.0
	var by := H - 152.0
	_text(bx, by - 6, "ЗДОРОВЬЕ", 10, DIM)
	_bar(bx, by, 180, 8, p.health, Color(0.62, 0.14, 0.12))
	_text(bx, by + 26, "ВЫНОСЛИВОСТЬ", 10, DIM)
	_bar(bx, by + 32, 180, 8, p.stamina, Color(0.28, 0.55, 0.28))
	_text(bx + 200, by - 6, "ФОНАРИК", 10, DIM)
	_bar(bx + 200, by, 130, 8, p.battery, Color(0.80, 0.62, 0.24))
	# инвентарь
	var ix := 24.0
	var iy := H - 78.0
	_text(ix, iy - 10, "В КАРМАНАХ:", 10, DIM)
	if game.inv.is_empty():
		_text(ix, iy + 24, "пусто", 13, Color(0.55, 0.52, 0.47))
	else:
		var shown := mini(game.inv.size(), 9)
		for i in shown:
			var id: int = game.inv[i]
			var r := Rect2(ix + i * 46, iy, 40, 40)
			draw_rect(r, Color(0.06, 0.06, 0.08, 0.72))
			draw_rect(r, Color(0.55, 0.50, 0.42, 0.30), false, 1.0)
			draw_texture_rect(Items.icon_texture(id), Rect2(r.position + Vector2(3, 3), Vector2(34, 34)), false)
		if game.inv.size() > shown:
			_text(ix + shown * 46 + 6, iy + 26, "+" + str(game.inv.size() - shown), 14, BONE)
	# подсказка взаимодействия
	var prompt_y := H - 92.0
	if game.interact_label != "":
		_text(W * 0.5 - _tw(game.interact_label, 15) * 0.5, prompt_y - 28, game.interact_label, 15, AMBER)
		_bar(W * 0.5 - 110, prompt_y - 18, 220, 7, game.interact_prog, AMBER)
	if game.prompt != "":
		var tw := _tw(game.prompt, 17)
		_panel(Rect2(W * 0.5 - tw * 0.5 - 18, prompt_y - 18, tw + 36, 34), Color(0.03, 0.03, 0.04, 0.72), Color(0.55, 0.50, 0.42, 0.35), 1.0)
		_ctext(W * 0.5, prompt_y + 5, game.prompt, 17, Color(0.92, 0.88, 0.80))
	# субтитры
	var sy := H - 128.0
	for i in range(game.subs.size()):
		var s = game.subs[i]
		var col := Color(0.92, 0.55, 0.48) if bool(s.granny) else Color(0.88, 0.85, 0.78)
		_ctext(W * 0.5, sy - (game.subs.size() - 1 - i) * 22.0, str(s.text), 15, col)
	# тост
	if game.toast_t > 0.0 and game.toast != "":
		var a := clampf(game.toast_t * 2.0, 0.0, 1.0)
		var col := AMBER
		if game.toast_kind == GrannyGame.TK_OK:
			col = Color(0.45, 0.78, 0.42)
		elif game.toast_kind == GrannyGame.TK_ERR:
			col = Color(0.88, 0.30, 0.24)
		var tw2 := _tw(game.toast, 16)
		_panel(Rect2(W * 0.5 - tw2 * 0.5 - 16, 118, tw2 + 32, 32), Color(0.02, 0.02, 0.03, 0.72 * a), Color(col.r, col.g, col.b, 0.35 * a), 1.0)
		_ctext(W * 0.5, 140, game.toast, 16, Color(col.r, col.g, col.b, a))
	# подобранный предмет
	if game.pickup_t > 0.0 and game.pickup_item != Items.NONE:
		var t := 2.4 - game.pickup_t
		var rise := clampf(t / 0.45, 0.0, 1.0)
		var fade := clampf(game.pickup_t / 0.6, 0.0, 1.0)
		var y := H * 0.62 - rise * 80.0 + sin(game.pickup_t * 14.0) * 3.0 * fade
		var sz := 92.0
		draw_texture_rect(Items.icon_texture(game.pickup_item), Rect2(W * 0.5 - sz * 0.5, y, sz, sz), false, Color(1, 1, 1, fade))
		_ctext(W * 0.5, y + sz + 24, Items.display_name(game.pickup_item), 18, Color(0.92, 0.87, 0.78, fade))
	# капкан
	if p.trap_stuck > 0.0:
		_ctext(W * 0.5, H * 0.38, "ПРОБЕЛ — вырваться!", 24, Color(0.95, 0.30, 0.24, 0.7 + 0.3 * sin(game.time * 12.0)))
	# спрятался
	if p.hidden:
		_ctext(W * 0.5, H - 160, "E — выйти", 14, Color(0.75, 0.72, 0.66))
	# вспышки
	if game.hit_flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 0.85, 0.80, game.hit_flash * 0.35))
	if game.lightning_fx > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.75, 0.80, 1.0, game.lightning_fx * 0.30))

func _draw_minimap(W: float, H: float) -> void:
	var lv: LevelData = game.world.levels[game.player.level]
	var panel := Rect2(W - 132, 66, 108, 108)
	_panel(panel, Color(0.02, 0.02, 0.03, 0.65), Color(0.50, 0.46, 0.40, 0.35), 1.0)
	var cell := 96.0 / float(maxi(lv.w, lv.h))
	var ox := panel.position.x + 6.0
	var oy := panel.position.y + 6.0
	for y in lv.h:
		for x in lv.w:
			var t := lv.get_tile(x, y)
			var c := Color(0.09, 0.09, 0.10, 0.9)
			if not LevelData.SOLID[t]:
				c = Color(0.30, 0.29, 0.26, 0.85)
			if t == LevelData.DOOR or t == LevelData.FRONT:
				c = Color(0.52, 0.35, 0.18, 0.95)
			elif t == LevelData.HOLE:
				c = Color(0.02, 0.02, 0.02, 0.95)
			elif t == LevelData.GARAGE_DOOR:
				c = Color(0.38, 0.39, 0.40, 0.95)
			draw_rect(Rect2(ox + x * cell, oy + y * cell, cell + 0.4, cell + 0.4), c)
	var pl := game.player_local()
	var px := ox + pl.x * cell
	var py := oy + pl.y * cell
	var a := game.player.angle
	var pts := PackedVector2Array([
		Vector2(px + cos(a) * 5.0, py + sin(a) * 5.0),
		Vector2(px + cos(a + 2.5) * 4.0, py + sin(a + 2.5) * 4.0),
		Vector2(px + cos(a - 2.5) * 4.0, py + sin(a - 2.5) * 4.0),
	])
	draw_colored_polygon(pts, Color(0.95, 0.28, 0.20))
	if game.granny.level == game.player.level:
		var gp := Vector2(ox + game.granny.x * cell, oy + game.granny.y * cell)
		draw_circle(gp, 2.6, Color(0.85, 0.12, 0.10, 0.85))

# ------------------------------------------------------------------ journal

func _draw_journal(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.01, 0.02, 0.82))
	var pw := minf(940.0, W - 60.0)
	var ph := minf(540.0, H - 60.0)
	var px := W * 0.5 - pw * 0.5
	var py := H * 0.5 - ph * 0.5
	_panel(Rect2(px, py, pw, ph), Color(0.89, 0.85, 0.75, 0.97), Color(0.50, 0.39, 0.24, 0.9), 3.0)
	var line_y := py + 74.0
	while line_y < py + ph - 20.0:
		draw_line(Vector2(px + 24, line_y), Vector2(px + pw - 24, line_y), Color(0.36, 0.43, 0.52, 0.15), 1.0)
		line_y += 28.0
	_text(px + 26, py + 38, "ДНЕВНИК БЕГЛЕЦА", 22, Color(0.16, 0.13, 0.12))
	var stat := "день " + str(game.day) + " из " + str(game.max_days) + "    замки: " + str(game.count_locks()) + "/3"
	_text(px + pw - 26 - _tw(stat, 14), py + 38, stat, 14, Color(0.43, 0.27, 0.22))
	var lx := px + 30.0
	var rx := px + pw * 0.53
	var y0 := py + 86.0
	_text(lx, y0, "В карманах:", 17, Color(0.27, 0.16, 0.12))
	y0 += 32.0
	if game.inv.is_empty():
		_text(lx + 8, y0, "пусто", 13, Color(0.36, 0.28, 0.20))
	for i in game.inv.size():
		if y0 > py + ph - 80.0:
			break
		var id: int = game.inv[i]
		draw_texture_rect(Items.icon_texture(id), Rect2(lx, y0 - 20, 28, 28), false)
		_text(lx + 38, y0, Items.display_name(id), 14, Color(0.20, 0.16, 0.13))
		_text(lx + 38, y0 + 18, Items.hint(id), 11, Color(0.39, 0.32, 0.24))
		y0 += 48.0
	var y1 := py + 86.0
	_text(rx, y1, "Входная дверь:", 17, Color(0.27, 0.16, 0.12))
	y1 += 30.0
	var lock_names := ["висячий замок — ключ", "ржавый засов — монтировка", "кодовый замок — код 137"]
	for i in 3:
		var mark := "✔  " if game.locks[i] else "✖  "
		var col := Color(0.12, 0.43, 0.16) if game.locks[i] else Color(0.59, 0.17, 0.12)
		_text(rx + 4, y1, mark + lock_names[i], 13, col)
		y1 += 26.0
	y1 += 18.0
	_text(rx, y1, "Помни:", 17, Color(0.27, 0.16, 0.12))
	y1 += 30.0
	var tips := [
		"код от двери лежит на чердаке у Маруси",
		"молоко успокаивает кошку",
		"бутылка (G) отвлекает Гренни",
		"шкаф и кровать спасают, если она не видела",
		"бег слышно через весь дом",
		"капкан выдаст тебя с головой",
	]
	for s in tips:
		_text(rx + 4, y1, "— " + s, 12, Color(0.39, 0.32, 0.24))
		y1 += 23.0
	_ctext(W * 0.5, py + ph - 18, "Tab — закрыть дневник", 12, Color(0.35, 0.27, 0.19))

# ------------------------------------------------------------------ pause

func _draw_pause(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.008, 0.008, 0.013, 0.92))
	_shadow_ctext(W * 0.5, 150, "ПАУЗА", 40, BONE, 3.0)
	var y := 228.0
	for i in game.pause_items.size():
		var sel := i == game.pause_idx
		var rect := Rect2(W * 0.5 - 240, y - 34, 480, 50)
		if sel:
			_panel(rect, Color(0.42, 0.10, 0.09, 0.42), BLOOD, 2.0)
		_ctext(W * 0.5, y, game.pause_items[i], 25 if sel else 21, BONE if sel else Color(0.65, 0.62, 0.57))
		y += 58.0
	_ctext(W * 0.5, H - 80, "День " + str(game.day) + " из " + str(game.max_days) + "   ·   замки: " + str(game.count_locks()) + "/3", 13, DIM)

# ------------------------------------------------------------------ settings

func _settings_rows() -> Array:
	var s := game.settings
	var pct := func(v: float) -> String: return str(int(round(v * 100.0))) + "%"
	return [
		["ГРОМКОСТЬ ОБЩАЯ", pct.call(s.master_volume), true],
		["ГРОМКОСТЬ МУЗЫКИ", pct.call(s.music_volume), true],
		["ГРОМКОСТЬ ЗВУКОВ", pct.call(s.sfx_volume), true],
		["ЧУВСТВИТЕЛЬНОСТЬ МЫШИ", pct.call(s.mouse_sensitivity), true],
		["ИНВЕРСИЯ ОСИ Y", "ВКЛ" if s.invert_y else "ВЫКЛ", false],
		["ПОЛНЫЙ ЭКРАН", "ВКЛ" if s.fullscreen else "ВЫКЛ", false],
		["ТЕНИ ФОНАРИКА", "ВКЛ" if s.flashlight_shadows else "ВЫКЛ", false],
		["СГЛАЖИВАНИЕ", s.msaa_label(), false],
		["← НАЗАД", "", false],
	]

func _draw_settings(W: float, H: float) -> void:
	hover_rects.clear()
	slider_rects.clear()
	draw_rect(Rect2(0, 0, W, H), Color(0.008, 0.008, 0.013, 0.98))
	_shadow_ctext(W * 0.5, 64, "НАСТРОЙКИ", 34, BONE, 3.0)
	_ctext(W * 0.5, 100, "стрелки ← → меняют значение    Esc — выйти", 14, DIM)
	var rows := _settings_rows()
	var pw := minf(760.0, W - 80.0)
	var px := W * 0.5 - pw * 0.5
	var row_h := 52.0
	var y0 := 132.0
	var y := y0
	for i in rows.size():
		var r: Array = rows[i]
		var sel := i == game.settings_idx
		var rect := Rect2(px, y, pw, row_h)
		hover_rects.append(rect)
		if sel:
			_panel(rect, Color(0.42, 0.10, 0.09, 0.30), Color(0.74, 0.16, 0.13, 0.75), 1.6)
		elif hover_idx == i:
			_panel(rect, Color(0.42, 0.10, 0.09, 0.16), Color(0.74, 0.16, 0.13, 0.3), 1.2)
		var label: String = r[0]
		var val: String = r[1]
		var is_slider: bool = r[2]
		var txt_col := Color(0.92, 0.88, 0.80) if sel else Color(0.72, 0.69, 0.63)
		_text(px + 24, y + 33, label, 18, txt_col)
		if is_slider:
			var bar := Rect2(px + pw - 260, y + 21, 230, 12)
			slider_rects.append(bar)
			var frac := 0.5
			match i:
				0: frac = game.settings.master_volume
				1: frac = game.settings.music_volume
				2: frac = game.settings.sfx_volume
				3: frac = (game.settings.mouse_sensitivity - 0.2) / 2.3
			_bar(bar.position.x, bar.position.y, bar.size.x, bar.size.y, frac, AMBER)
			_text(bar.end.x + 12, y + 33, val, 15, AMBER)
		elif val != "":
			var tw := _tw(val, 16)
			_panel(Rect2(px + pw - 130 - tw * 0.5 - 14, y + 12, tw + 28, 26), Color(0.05, 0.05, 0.08, 0.8), Color(0.55, 0.50, 0.42, 0.4), 1.0)
			_ctext(px + pw - 130, y + 33, val, 16, BONE if val == "ВКЛ" else DIM)
		y += row_h
	_ctext(W * 0.5, y + 34, "мышь: клик по переключателю · клик по полосе ставит значение", 13, Color(0.58, 0.56, 0.50, 0.8))

# ------------------------------------------------------------------ save/load

func _draw_saves(W: float, H: float) -> void:
	hover_rects.clear()
	slider_rects.clear()
	draw_rect(Rect2(0, 0, W, H), Color(0.008, 0.008, 0.013, 0.96))
	var is_save := game.state == GrannyGame.STATE_SAVE
	_shadow_ctext(W * 0.5, 70, "СОХРАНИТЬ ИГРУ" if is_save else "ЗАГРУЗИТЬ ИГРУ", 34, BONE, 3.0)
	_ctext(W * 0.5, 106, "выбери слот" if is_save else "загрузка заменит текущий день", 14, DIM)
	var pw := minf(680.0, W - 80.0)
	var px := W * 0.5 - pw * 0.5
	var card_h := 96.0
	var y := 136.0
	for i in SaveSystem.ALL_SLOTS.size():
		var m := _saves_meta(i)
		var sel := i == game.save_idx
		var rect := Rect2(px, y, pw, card_h)
		hover_rects.append(rect)
		var border := Color(0.74, 0.16, 0.13, 0.85) if sel else Color(0.45, 0.42, 0.38, 0.5)
		var fill := Color(0.09, 0.05, 0.06, 0.92) if sel else Color(0.055, 0.055, 0.07, 0.92)
		if not m.exists and not is_save:
			fill = Color(0.04, 0.04, 0.05, 0.92)
		_panel(rect, fill, border, 2.4 if sel else 1.4)
		var name_col := BONE if m.exists else DIM
		_text(px + 20, y + 34, SaveSystem.slot_label(SaveSystem.ALL_SLOTS[i]), 18, name_col)
		if m.exists:
			var played := str(int(m.play_time) / 60) + ":" + str(int(m.play_time) % 60).pad_zeros(2)
			var line := "%s · день %d/%d · замки %d/3 · время %s · %s" % [
				m.diff_name, m.day, m.max_days, m.locks, played, _fmt_saved(m.saved_unix),
			]
			_text(px + 20, y + 62, line, 13, Color(0.72, 0.68, 0.60))
		else:
			_text(px + 20, y + 62, "— пусто —", 13, Color(0.42, 0.40, 0.37))
		y += card_h + 14.0
	_ctext(W * 0.5, y + 26, "Enter — " + ("записать" if is_save else "загрузить") + "    Esc — назад", 14, DIM)

func _fmt_saved(unix: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d.%02d %02d:%02d" % [dt.day, dt.month, dt.hour, dt.minute]

# ------------------------------------------------------------------ caught

func _draw_caught(W: float, H: float) -> void:
	var t := game.caught_t
	draw_rect(Rect2(0, 0, W, H), Color(0.035, 0.004, 0.006, 1.0))
	if face_tex != null:
		var sc := 1.32 + t * 0.30
		var fh := H * sc
		var fw := fh * float(face_tex.get_width()) / float(face_tex.get_height())
		var jx := sin(t * 47.0) * 16.0 * maxf(0.0, 1.0 - t * 0.7)
		var jy := cos(t * 39.0) * 13.0 * maxf(0.0, 1.0 - t * 0.7)
		var fx := W * 0.5 - fw * 0.5 + jx
		var fy := H * 0.46 - fh * 0.30 + jy
		draw_texture_rect(face_tex, Rect2(fx, fy, fw, fh), false, Color(1.05, 0.48, 0.44))
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.0, 0.0, 0.12), false, 70.0)
	var flash := maxf(0.0, 1.0 - t * 3.0)
	if flash > 0.01:
		draw_rect(Rect2(0, 0, W, H), Color(0.66, 0.05, 0.04, flash * 0.55))
	for i in 72:
		var bt := float(i) / 71.0
		var alpha := 0.90 * bt * bt
		draw_rect(Rect2(0, H - 260 + i * 260.0 / 72.0, W, 260.0 / 72.0 + 2.0), Color(0.03, 0.0, 0.0, alpha))
	_shadow_ctext(W * 0.5, H - 188, "ОНА ТЕБЯ ПОЙМАЛА", 36, Color(0.94, 0.90, 0.84), 4.0)
	_ctext(W * 0.5, H - 142, "День " + str(game.day) + " закончился", 22, Color(0.84, 0.26, 0.21))
	if game.day < game.max_days:
		_ctext(W * 0.5, H - 100, "Осталось дней: " + str(maxi(0, game.max_days - game.day)), 15, Color(0.74, 0.70, 0.64))
	else:
		_ctext(W * 0.5, H - 100, "Это был последний день. Завтра она придёт за тобой.", 15, Color(0.86, 0.36, 0.32))

# ------------------------------------------------------------------ win

func _draw_win(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.03, 0.035, 0.97))
	draw_rect(Rect2(0, 0, W, H), Color(0.10, 0.25, 0.13, 0.10))
	var title := "ТЫ СБЕЖАЛ!"
	var story := "Дверь хлопнула. Морозный воздух. Свобода."
	var tail := "Гренни осталась одна. С кошкой. И с капканами."
	if game.last_win == GrannyGame.WIN_SECRET:
		title = "ТЫ СБЕЖАЛ. И ДАЖЕ ТЕДДИ."
		story = "Ты положил Тедди в колыбель. Гренни замерла. Ты вышел. Она не пошла за тобой."
		tail = "Гренни осталась одна. С Тедди. С кошкой. И с капканами."
	elif game.last_win == GrannyGame.WIN_CAR:
		title = "ТЫ УЕХАЛ!"
		story = "Ты уехал на бабушкиной машине. Она даже не заметила."
		tail = "Гренни ещё долго лезла под капот с гаечным ключом."
	_shadow_ctext(W * 0.5, 112, title, 38, BONE, 4.0)
	_ctext(W * 0.5, 188, story, 21, Color(0.86, 0.83, 0.77))
	_panel(Rect2(W * 0.5 - 300, 244, 600, 230), Color(0.10, 0.13, 0.10, 0.75), Color(0.48, 0.62, 0.48, 0.45), 1.4)
	var lx := W * 0.5 - 250
	var vx := W * 0.5 + 40
	var y := 282.0
	_text(lx, y, "СЛОЖНОСТЬ", 12, DIM)
	_text(vx, y, game.diff.name, 18, AMBER)
	y += 42.0
	_text(lx, y, "ДНЕЙ ПОТРАЧЕНО", 12, DIM)
	_text(vx, y, str(game.day) + " из " + str(game.max_days), 18, BONE)
	y += 42.0
	_text(lx, y, "ВРЕМЯ", 12, DIM)
	_text(vx, y, str(int(game.play_time) / 60) + ":" + str(int(game.play_time) % 60).pad_zeros(2), 18, BONE)
	y += 42.0
	_text(lx, y, "СМЕРТЕЙ", 12, DIM)
	_text(vx, y, str(game.deaths), 18, BONE)
	_ctext(W * 0.5, 538, tail, 15, Color(0.66, 0.63, 0.57))
	var pulse := 0.70 + 0.30 * sin(game.time * 3.0)
	_ctext(W * 0.5, 640, "Enter — в главное меню", 16, Color(0.90, 0.79, 0.48, pulse))

# ------------------------------------------------------------------ over

func _draw_over(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.035, 0.006, 0.010, 0.98))
	if face_tex != null:
		var fw := W * 0.46
		var fh := fw * float(face_tex.get_height()) / float(face_tex.get_width())
		draw_texture_rect(face_tex, Rect2(W * 0.64 - fw * 0.5, H * 0.5 - fh * 0.5, fw, fh), false, Color(0.48, 0.16, 0.15, 0.85))
	_shadow_text(92, 208, "ДНЕЙ БОЛЬШЕ НЕТ", 42, Color(0.80, 0.14, 0.12), 4.0)
	_text(96, 292, "Она дождалась. Ты остался у неё на ужин.", 23, Color(0.79, 0.75, 0.69))
	_text(96, 354, "Сложность: " + game.diff.name, 15, DIM)
	_text(96, 386, "Продержался: " + str(game.day) + " дн. · " + str(int(game.play_time) / 60) + ":" + str(int(game.play_time) % 60).pad_zeros(2), 15, DIM)
	var pulse := 0.70 + 0.30 * sin(game.time * 3.0)
	_text(96, 474, "Enter — в главное меню", 16, Color(0.90, 0.79, 0.48, pulse))
