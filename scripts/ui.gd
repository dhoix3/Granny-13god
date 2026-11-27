class_name GameUI
extends Control

# Весь интерфейс рисуется вручную: заголовок, сложность, помощь,
# вступление, HUD, дневник, пауза, экраны поимки, победы и проигрыша.
# Переработка: шрифты DejaVu (обычный/жирный), масштаб под любые
# разрешения и соотношения сторон, анимации наведения и переходов,
# атмосферные слои (туман, виньетка, киношное зерно).

var game: GrannyGame
var face_tex: Texture2D
var font_reg: Font
var font_bold: Font
var vignette_tex: Texture2D
var fog_tex: Texture2D
var grain_tex: Texture2D
var granny_tex: Texture2D

# Ховер и прямоугольники кликов для меню-экранов.
var hover_idx := -1
var hover_row_frac := 0.5
var hover_rects: Array[Rect2] = []
var slider_rects: Array[Rect2] = []
var diff_rects: Array[Rect2] = []
var _hover_anim: Dictionary = {}
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
	granny_tex = load("res://assets/granny.png")
	font_reg = load("res://assets/fonts/DejaVuSans.ttf")
	font_bold = load("res://assets/fonts/DejaVuSans-Bold.ttf")
	vignette_tex = Mats.tex("vignette")
	fog_tex = Mats.tex("fogblob")
	grain_tex = Mats.tex("grain")

func text_w(text: String, f: Font, sz: int) -> float:
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x

func update_hover(_state: int) -> void:
	if game != null and game.state != _last_ui_state:
		_last_ui_state = game.state
		_refresh_saves_cache()
		hover_idx = -1
		hover_row_frac = 0.5
		return  # ждём перерисовку нового экрана — старые прямоугольники невалидны
	var prev := hover_idx
	hover_idx = -1
	var mp := get_global_mouse_position()
	for i in hover_rects.size():
		if hover_rects[i].has_point(mp):
			hover_idx = i
			break
	if hover_idx != prev and hover_idx >= 0:
		Audio.play("ui_move", 0.22, 1.35)
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

# ------------------------------------------------------------------ helpers

func _u() -> float:
	# масштаб интерфейса: привязка к высоте 720, ограничение снизу/сверху
	var h := size.y
	var w := size.x
	return clampf(minf(h / 720.0, w / 1280.0), 0.72, 1.7)

func _f() -> Font:
	return font_reg

func _fb() -> Font:
	return font_bold

func _tw(text: String, sz: int) -> float:
	return text_w(text, font_reg, sz)

func _twb(text: String, sz: int) -> float:
	return text_w(text, font_bold, sz)

func _text(x: float, y: float, text: String, sz: int, col: Color) -> void:
	draw_string(font_reg, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _btext(x: float, y: float, text: String, sz: int, col: Color) -> void:
	draw_string(font_bold, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _ctext(cx: float, y: float, text: String, sz: int, col: Color) -> void:
	draw_string(font_reg, Vector2(cx - _tw(text, sz) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _bctext(cx: float, y: float, text: String, sz: int, col: Color) -> void:
	draw_string(font_bold, Vector2(cx - _twb(text, sz) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _shadow_text(x: float, y: float, text: String, sz: int, col: Color, off := 3.0) -> void:
	_text(x + off, y + off, text, sz, Color(0, 0, 0, 0.8))
	_text(x, y, text, sz, col)

func _shadow_ctext(cx: float, y: float, text: String, sz: int, col: Color, off := 3.0) -> void:
	_ctext(cx + off, y + off, text, sz, Color(0, 0, 0, 0.8))
	_ctext(cx, y, text, sz, col)

func _shadow_btext(x: float, y: float, text: String, sz: int, col: Color, off := 3.0) -> void:
	_btext(x + off, y + off, text, sz, Color(0, 0, 0, 0.85))
	_btext(x, y, text, sz, col)

func _shadow_bctext(cx: float, y: float, text: String, sz: int, col: Color, off := 3.0) -> void:
	_bctext(cx + off, y + off, text, sz, Color(0, 0, 0, 0.85))
	_bctext(cx, y, text, sz, col)

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

func _hover_boost(i: int) -> float:
	# плавная анимация подсветки строки меню
	var target := 1.0 if i == hover_idx else 0.0
	var cur := float(_hover_anim.get(i, 0.0))
	cur = lerpf(cur, target, 0.18)
	_hover_anim[i] = cur
	return cur

# --- атмосферные слои ---

func _fog_layer(W: float, H: float, k: float, seed_off := 0.0) -> void:
	for i in 6:
		var t := game.time * (0.030 + 0.012 * i) + i * 1.9 + seed_off
		var x := (sin(t) * 0.5 + 0.5) * W
		var y := (cos(t * 0.63 + i * 2.1) * 0.5 + 0.5) * H
		var s := (280.0 + i * 90.0) * _u()
		draw_texture_rect(fog_tex, Rect2(x - s * 0.5, y - s * 0.5, s, s), false, Color(1, 1, 1, k * (0.20 - i * 0.02)))

func _vignette(W: float, H: float, k := 1.0) -> void:
	draw_texture_rect(vignette_tex, Rect2(0, 0, W, H), false, Color(1, 1, 1, k))

func _grain(W: float, H: float, k := 0.05) -> void:
	var t := game.time * 13.0
	var off_x := fposmod(t * 17.0, 128.0)
	var off_y := fposmod(t * 29.0, 128.0)
	draw_texture_rect(grain_tex, Rect2(-off_x, -off_y, W + 128.0, H + 128.0), true, Color(1, 1, 1, k))

func _transition(W: float, H: float) -> void:
	# затемнение при смене экрана (задаётся game.transition_a)
	if game.transition_a > 0.004:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, clampf(game.transition_a, 0.0, 1.0)))

func _menu_bg(W: float, H: float, base: Color) -> void:
	draw_rect(Rect2(0, 0, W, H), base)
	_fog_layer(W, H, 1.0)
	_grain(W, H, 0.045)
	_vignette(W, H, 0.85)

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
	_transition(W, H)

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
	var u := _u()
	hover_rects.clear()
	slider_rects.clear()
	_menu_bg(W, H, Color(0.004, 0.004, 0.008, 0.55))
	# силуэт Гренни справа — «она ждёт»
	if granny_tex != null:
		var gh := H * (0.78 + 0.012 * sin(game.time * 0.7))
		var gw := gh * float(granny_tex.get_width()) / float(granny_tex.get_height())
		var gx := W - gw * 0.62 + sin(game.time * 0.23) * 6.0
		draw_texture_rect(granny_tex, Rect2(gx, H - gh - H * 0.02, gw, gh), false, Color(0.42, 0.38, 0.40, 0.5))
	var lm := maxf(64.0, W * 0.065)  # левый отступ
	var title_sz := int(86 * u)
	var title_w := _twb("ГРЕННИ", title_sz)
	_shadow_btext(lm, 172 * u + (H - 720 * u) * 0.25, "ГРЕННИ", title_sz, Color(0.90, 0.88, 0.83), 4.0 * u)
	_shadow_btext(lm + title_w + 20 * u, 132 * u + (H - 720 * u) * 0.25, "13", int(118 * u), Color(0.74, 0.12, 0.11), 4.0 * u)
	_text(lm + 4, 220 * u + (H - 720 * u) * 0.25, "ПОБЕГ ОТ БАБУШКИ", int(27 * u), Color(0.76, 0.71, 0.63, 0.92))
	draw_line(Vector2(lm, 250 * u + (H - 720 * u) * 0.25), Vector2(lm + 428 * u, 250 * u + (H - 720 * u) * 0.25), Color(0.74, 0.16, 0.13, 0.55), 2.0)
	_text(lm + 2, 274 * u + (H - 720 * u) * 0.25, "пародия на Granny · 4 этажа · 5 сложностей", int(14 * u), Color(0.62, 0.59, 0.53, 0.8))
	var my := 296 * u + (H - 720 * u) * 0.25
	for i in game.menu_items.size():
		var sel := i == game.menu_idx
		var inactive := (i == 0 or i == 2) and not game.has_saves
		var hk := _hover_boost(i + (1000 if sel else 0))
		var item_col := Color(0.96, 0.93, 0.87) if sel else (Color(0.40, 0.38, 0.35) if inactive else Color(0.68, 0.65, 0.59))
		var rect := Rect2(lm - 10 * u, my - 30 * u, 400 * u, 46 * u)
		hover_rects.append(rect)
		if sel:
			var pulse := 0.36 + 0.06 * sin(game.time * 3.0)
			_panel(rect, Color(0.42, 0.10, 0.09, pulse), BLOOD, 2.0)
			_text(lm, my, "►", int(26 * u), BLOOD)
		elif hk > 0.02 and not inactive:
			_panel(rect, Color(0.42, 0.10, 0.09, 0.22 * hk), Color(0.74, 0.16, 0.13, 0.4 * hk), 1.4)
		var slide := 8.0 * u * hk if not sel else 0.0
		_text(lm + 30 * u + slide, my, game.menu_items[i], int((25 if sel else 22) * u), item_col)
		my += 50.0 * u
	_panel(Rect2(lm, 620 * u + (H - 720 * u) * 0.25, 430 * u, 54 * u), Color(0.08, 0.08, 0.10, 0.65), Color(0.55, 0.50, 0.42, 0.35), 1.0)
	_text(lm + 14 * u, 640 * u + (H - 720 * u) * 0.25, "СЛОЖНОСТЬ:", int(12 * u), DIM)
	_btext(lm + 138 * u, 646 * u + (H - 720 * u) * 0.25, game.diffs[game.diff_index].name, int(20 * u), AMBER)
	if game.title_hint_t > 0.0 and game.title_hint != "":
		var hint_a := clampf(game.title_hint_t * 2.0, 0.0, 1.0)
		_ctext(W * 0.5 + 110 * u, 585 * u, game.title_hint, int(15 * u), Color(0.90, 0.79, 0.48, hint_a))
	_ctext(W * 0.5 + 110 * u, H - 40.0 * u, "↑ ↓ — выбор    Enter — подтвердить    мышь — тоже работает", int(13 * u), Color(0.58, 0.56, 0.50, 0.8))

# ------------------------------------------------------------------ difficulty

func _draw_diff(W: float, H: float) -> void:
	var u := _u()
	hover_rects.clear()
	slider_rects.clear()
	diff_rects.clear()
	_menu_bg(W, H, Color(0.012, 0.012, 0.018, 0.98))
	_shadow_bctext(W * 0.5, 66 * u, "ВЫБЕРИ СЛОЖНОСТЬ", int(34 * u), Color(0.93, 0.90, 0.84), 3.0)
	_ctext(W * 0.5, 108 * u, "чем сложнее — тем быстрее бабушка и тем меньше у тебя дней", int(14 * u), DIM)
	var n := game.diffs.size()
	var gap := 12.0 * u
	var margin := 30.0 * u
	var cw := (W - margin * 2.0 - gap * (n - 1)) / n
	var total := n * cw + gap * (n - 1)
	var x0 := (W - total) * 0.5
	var y := 150.0 * u
	var h := H - y - 70.0 * u
	for i in n:
		var d = game.diffs[i]
		var x := x0 + i * (cw + gap)
		diff_rects.append(Rect2(x, y, cw, h))
		var sel := i == game.diff_idx_menu
		var cur := i == game.diff_index
		_panel(Rect2(x, y, cw, h), Color(0.09, 0.05, 0.06, 0.9) if sel else Color(0.055, 0.055, 0.07, 0.9), BLOOD if sel else Color(0.35, 0.33, 0.30, 0.55), 3.0 if sel else 1.4)
		if cur:
			_text(x + 12, y + 20 * u, "ТЕКУЩАЯ", int(11 * u), AMBER)
		_bctext(x + cw * 0.5, y + 56 * u, d.name, int(20 * u), BONE if sel else Color(0.75, 0.72, 0.66))
		var by := y + 92.0 * u
		_diff_bar(x + 22 * u, by, cw - 44 * u, "СКОРОСТЬ", (float(d.run) - 1.6) / 1.6, BLOOD, u)
		by += 48.0 * u
		_diff_bar(x + 22 * u, by, cw - 44 * u, "СЛУХ", (float(d.hear_mul) - 0.6) / 1.1, AMBER, u)
		by += 48.0 * u
		_diff_bar(x + 22 * u, by, cw - 44 * u, "ЗРЕНИЕ", (float(d.sight) - 6.0) / 10.0, Color(0.45, 0.58, 0.82), u)
		by += 48.0 * u
		_diff_bar(x + 22 * u, by, cw - 44 * u, "КАПКАНЫ", float(d.traps) / 8.0, Color(0.66, 0.43, 0.24), u)
		by += 46.0 * u
		_text(x + 22 * u, by, "ДНЕЙ: " + str(d.days), int(16 * u), BONE)
		by += 34.0 * u
		draw_multiline_string(font_reg, Vector2(x + 20 * u, by), d.desc, HORIZONTAL_ALIGNMENT_LEFT, cw - 40 * u, int(12 * u), -1, Color(0.68, 0.64, 0.58))
		if sel:
			draw_rect(Rect2(x - 4, y - 4, cw + 8, h + 8), Color(0.74, 0.16, 0.13, 0.9), false, 2.0)
	_ctext(W * 0.5, H - 42.0 * u, "← → / мышь — выбрать      Enter — играть      Esc — назад", int(14 * u), Color(0.66, 0.62, 0.56))

func _diff_bar(x: float, y: float, w: float, label: String, v: float, col: Color, u: float) -> void:
	_text(x, y, label, int(10 * u), Color(0.66, 0.62, 0.56))
	draw_rect(Rect2(x, y + 8 * u, w, 8 * u), Color(0.12, 0.12, 0.14, 0.9))
	draw_rect(Rect2(x, y + 8 * u, w * clampf(v, 0.0, 1.0), 8 * u), col)
	for i in range(1, 10):
		draw_line(Vector2(x + w * i / 10.0, y + 8 * u), Vector2(x + w * i / 10.0, y + 16 * u), Color(0, 0, 0, 0.35), 1.0)

# ------------------------------------------------------------------ help

func _draw_help(W: float, H: float) -> void:
	var u := _u()
	hover_rects.clear()
	slider_rects.clear()
	diff_rects.clear()
	_menu_bg(W, H, Color(0.008, 0.008, 0.013, 0.98))
	_shadow_bctext(W * 0.5, 64 * u, "КАК ИГРАТЬ", int(36 * u), BONE, 3.0)
	var keys := [
		"W A S D / стрелки — ходить",
		"Мышь — осматриваться",
		"SHIFT — бежать (тратит выносливость и ОЧЕНЬ шумит)",
		"CTRL / C — красться (тихо, но медленно)",
		"E — открыть дверь, обыскать шкаф, спрятаться, лезть по лестнице",
		"F — фонарик (свет видит Гренни)",
		"G — положить предмет на пол; бутылка в руках — бросить и отвлечь",
		"Q — выстрел из арбалета (стрелы заряжаются, поднимая их с арбалетом в руках)",
		"X — осмотреть предмет (он парит перед глазами)",
		"TAB — дневник: что найдено, что открыто, что помнить",
		"ПРОБЕЛ — вырваться из капкана",
		"ESC — пауза, F11 — полный экран",
	]
	var y := 116.0 * u
	for s in keys:
		_text(112 * u, y, "•", int(20 * u), BLOOD)
		_text(140 * u, y, s, int(15 * u), Color(0.80, 0.77, 0.71))
		y += 30.0 * u
	y += 8.0
	_panel(Rect2(96 * u, y, W - 192 * u, 150 * u), Color(0.14, 0.07, 0.06, 0.55), Color(0.62, 0.22, 0.18, 0.45), 1.4)
	_btext(120 * u, y + 32 * u, "ЦЕЛЬ: открыть три замка на входной двери — и унести ноги", int(20 * u), AMBER)
	_text(124 * u, y + 72 * u, "1. Висячий замок   — ключ от замка", int(15 * u), BONE)
	_text(124 * u, y + 100 * u, "2. Ржавый засов    — монтировка", int(15 * u), BONE)
	_text(124 * u, y + 128 * u, "3. Кодовый замок   — записка с кодом (она на чердаке)", int(15 * u), BONE)
	_ctext(W * 0.5, H - 34.0 * u, "Enter / Esc — назад", int(14 * u), DIM)

# ------------------------------------------------------------------ intro

func _draw_intro(W: float, H: float) -> void:
	var u := _u()
	hover_rects.clear()
	slider_rects.clear()
	_menu_bg(W, H, Color(0.006, 0.006, 0.010, 0.98))
	_shadow_bctext(W * 0.5, 104 * u, "ДЕНЬ 1", int(40 * u), Color(0.80, 0.16, 0.13), 3.0)
	_ctext(W * 0.5, 210 * u, "Ты приехал к бабушке на выходные. Остался ночевать.", int(23 * u), Color(0.88, 0.84, 0.78))
	_ctext(W * 0.5, 258 * u, "Утром дверь оказалась заперта снаружи, а на кухне кто-то точил нож.", int(23 * u), Color(0.88, 0.84, 0.78))
	_ctext(W * 0.5, 322 * u, "У тебя " + str(game.diff.days) + " дней, чтобы найти ключи, открыть дверь и унести ноги.", int(23 * u), Color(0.90, 0.59, 0.24))
	_ctext(W * 0.5, 390 * u, "На чердаке живёт её кошка Маруся. Она очень громкая.", int(16 * u), Color(0.68, 0.65, 0.59))
	_panel(Rect2(W * 0.5 - 300 * u, 470 * u, 600 * u, 128 * u), Color(0.14, 0.06, 0.055, 0.65), Color(0.62, 0.20, 0.17, 0.45), 1.4)
	_bctext(W * 0.5, 506 * u, "НЕ БЕГИ БЕЗ ПРИЧИНЫ.", int(21 * u), BLOOD)
	_ctext(W * 0.5, 542 * u, "Она слышит каждый шаг.", int(15 * u), BONE)
	_ctext(W * 0.5, 570 * u, "Она ставит капканы.", int(15 * u), BONE)
	var pulse := 0.72 + 0.28 * sin(game.time * 3.0)
	_ctext(W * 0.5, 662 * u, "Нажми Enter, чтобы начать", int(16 * u), Color(0.90, 0.79, 0.48, pulse))

# ------------------------------------------------------------------ HUD

func _draw_hud(W: float, H: float) -> void:
	var u := _u()
	var p := game.player
	# прицел
	draw_circle(Vector2(W * 0.5, H * 0.5), 1.6 * u, Color(1, 1, 1, 0.35))
	# индикатор обнаружения
	if game.detect_fx > 0.02:
		var a := clampf(game.detect_fx, 0.0, 1.0)
		draw_arc(Vector2(W * 0.5, 92 * u), 30.0 * u, PI * 0.15, PI * 0.85, 20, Color(0.85, 0.15, 0.12, a), 2.6)
		draw_arc(Vector2(W * 0.5, 92 * u), 30.0 * u, PI * 1.15, PI * 1.85, 20, Color(0.85, 0.15, 0.12, a), 2.6)
		_bctext(W * 0.5, 78 * u, "!", int(26 * u), Color(0.90, 0.25, 0.20, a))
	# замки
	_text(24 * u, 30 * u, "ЗАМКИ", int(11 * u), DIM)
	for i in 3:
		_lock_icon(24 * u + float(i) * 24.0 * u, 38 * u, game.locks[i])
	_text(24 * u, 76 * u, str(game.count_locks()) + "/3" + ("  + код" if game.lock4 else ""), int(14 * u), BONE)
	# день
	var day_text := "ДЕНЬ " + str(game.day) + " / " + str(game.max_days)
	_text(W - 24.0 * u - _tw(day_text, int(19 * u)), 34 * u, day_text, int(19 * u), BONE)
	var lock_text := "замки: " + str(game.count_locks()) + "/3"
	_text(W - 24.0 * u - _tw(lock_text, int(12 * u)), 54 * u, lock_text, int(12 * u), DIM)
	# полосы
	var bx := 24.0 * u
	var by := H - 152.0 * u
	_text(bx, by - 6 * u, "ЗДОРОВЬЕ", int(10 * u), DIM)
	_bar(bx, by, 180 * u, 8 * u, p.health, Color(0.62, 0.14, 0.12))
	_text(bx, by + 26 * u, "ВЫНОСЛИВОСТЬ", int(10 * u), DIM)
	_bar(bx, by + 32 * u, 180 * u, 8 * u, p.stamina, Color(0.28, 0.55, 0.28))
	_text(bx + 200 * u, by - 6 * u, "ФОНАРИК", int(10 * u), DIM)
	_bar(bx + 200 * u, by, 130 * u, 8 * u, p.battery, Color(0.80, 0.62, 0.24))
	# предмет в руках (единственный): иконка + имя + подсказка
	var hx := W - 152.0 * u
	var hy := H - 118.0 * u
	if game.held_item != Items.NONE:
		var hr := Rect2(hx, hy, 40 * u, 40 * u)
		var pulse := 0.72 + 0.06 * sin(game.time * 2.6)
		draw_rect(hr, Color(0.05, 0.05, 0.07, 0.78))
		draw_rect(hr, Color(0.86, 0.68, 0.30, pulse), false, 1.4)
		draw_texture_rect(Items.icon_texture(game.held_item), Rect2(hr.position + Vector2(3, 3) * u, Vector2(34, 34) * u), false)
		_text(hx, hy + 58 * u, Items.display_name(game.held_item), int(12 * u), BONE)
		var hhint := "G — положить" if game.held_item != Items.BOTTLE else "G — бросить"
		_text(hx, hy + 74 * u, hhint, int(10 * u), DIM)
		if game.held_item == Items.CROSSBOW:
			_text(hx, hy + 88 * u, "стрелы: " + str(game.dart_ammo) + "/3", int(10 * u), Color(0.80, 0.62, 0.24))
	else:
		_text(hx, hy + 44 * u, "руки пусты", int(11 * u), Color(0.45, 0.43, 0.40, 0.8))
	# подсказка взаимодействия
	var prompt_y := H - 92.0 * u
	if game.interact_label != "":
		_text(W * 0.5 - _tw(game.interact_label, int(15 * u)) * 0.5, prompt_y - 28 * u, game.interact_label, int(15 * u), AMBER)
		_bar(W * 0.5 - 110 * u, prompt_y - 18 * u, 220 * u, 7 * u, game.interact_prog, AMBER)
	if game.prompt != "":
		var tw := _tw(game.prompt, int(17 * u))
		_panel(Rect2(W * 0.5 - tw * 0.5 - 18 * u, prompt_y - 18 * u, tw + 36 * u, 34 * u), Color(0.03, 0.03, 0.04, 0.72), Color(0.55, 0.50, 0.42, 0.35), 1.0)
		_ctext(W * 0.5, prompt_y + 5 * u, game.prompt, int(17 * u), Color(0.92, 0.88, 0.80))
	# субтитры
	var sy := H - 128.0 * u
	for i in range(game.subs.size()):
		var s = game.subs[i]
		var col := Color(0.92, 0.55, 0.48) if bool(s.granny) else Color(0.88, 0.85, 0.78)
		_ctext(W * 0.5, sy - float(game.subs.size() - 1 - i) * 22.0 * u, str(s.text), int(15 * u), col)
	# тост
	if game.toast_t > 0.0 and game.toast != "":
		var a2 := clampf(game.toast_t * 2.0, 0.0, 1.0)
		var col2 := AMBER
		if game.toast_kind == GrannyGame.TK_OK:
			col2 = Color(0.45, 0.78, 0.42)
		elif game.toast_kind == GrannyGame.TK_ERR:
			col2 = Color(0.88, 0.30, 0.24)
		var tw2 := _tw(game.toast, int(16 * u))
		_panel(Rect2(W * 0.5 - tw2 * 0.5 - 16 * u, 118 * u, tw2 + 32 * u, 32 * u), Color(0.02, 0.02, 0.03, 0.72 * a2), Color(col2.r, col2.g, col2.b, 0.35 * a2), 1.0)
		_ctext(W * 0.5, 140 * u, game.toast, int(16 * u), Color(col2.r, col2.g, col2.b, a2))
	# подобранный предмет
	if game.pickup_t > 0.0 and game.pickup_item != Items.NONE:
		var t := 2.4 - game.pickup_t
		var rise := clampf(t / 0.45, 0.0, 1.0)
		var fade := clampf(game.pickup_t / 0.6, 0.0, 1.0)
		var yy := H * 0.62 - rise * 80.0 * u + sin(game.pickup_t * 14.0) * 3.0 * fade
		var sz := 92.0 * u
		draw_texture_rect(Items.icon_texture(game.pickup_item), Rect2(W * 0.5 - sz * 0.5, yy, sz, sz), false, Color(1, 1, 1, fade))
		_ctext(W * 0.5, yy + sz + 24 * u, Items.display_name(game.pickup_item), int(18 * u), Color(0.92, 0.87, 0.78, fade))
	# капкан
	if p.trap_stuck > 0.0:
		_bctext(W * 0.5, H * 0.38, "ПРОБЕЛ — вырваться!", int(24 * u), Color(0.95, 0.30, 0.24, 0.7 + 0.3 * sin(game.time * 12.0)))
	# спрятался
	if p.hidden:
		_ctext(W * 0.5, H - 160.0 * u, "E — выйти", int(14 * u), Color(0.75, 0.72, 0.66))
	# вспышки
	if game.hit_flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 0.85, 0.80, game.hit_flash * 0.35))
	if game.lightning_fx > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.75, 0.80, 1.0, game.lightning_fx * 0.30))
	_vignette(W, H, 0.55)

# ------------------------------------------------------------------ journal

func _draw_journal(W: float, H: float) -> void:
	var u := _u()
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.01, 0.02, 0.82))
	var pw := minf(940.0 * u, W - 60.0)
	var ph := minf(540.0 * u, H - 60.0)
	var px := W * 0.5 - pw * 0.5
	var py := H * 0.5 - ph * 0.5
	_panel(Rect2(px, py, pw, ph), Color(0.89, 0.85, 0.75, 0.97), Color(0.50, 0.39, 0.24, 0.9), 3.0)
	var line_y := py + 74.0 * u
	while line_y < py + ph - 20.0:
		draw_line(Vector2(px + 24 * u, line_y), Vector2(px + pw - 24 * u, line_y), Color(0.36, 0.43, 0.52, 0.15), 1.0)
		line_y += 28.0 * u
	_btext(px + 26 * u, py + 38 * u, "ДНЕВНИК БЕГЛЕЦА", int(22 * u), Color(0.16, 0.13, 0.12))
	var stat := "день " + str(game.day) + " из " + str(game.max_days) + "    замки: " + str(game.count_locks()) + "/3"
	_text(px + pw - 26 * u - _tw(stat, int(14 * u)), py + 38 * u, stat, int(14 * u), Color(0.43, 0.27, 0.22))
	var lx := px + 30.0 * u
	var rx := px + pw * 0.53
	var y0 := py + 86.0 * u
	_btext(lx, y0, "В руках:", int(17 * u), Color(0.27, 0.16, 0.12))
	y0 += 32.0 * u
	if game.held_item == Items.NONE:
		_text(lx + 8 * u, y0, "пусто", int(13 * u), Color(0.36, 0.28, 0.20))
	else:
		draw_texture_rect(Items.icon_texture(game.held_item), Rect2(lx, y0 - 20 * u, 28 * u, 28 * u), false)
		_text(lx + 38 * u, y0, Items.display_name(game.held_item), int(14 * u), Color(0.20, 0.16, 0.13))
		_text(lx + 38 * u, y0 + 18 * u, Items.hint(game.held_item), int(11 * u), Color(0.39, 0.32, 0.24))
	if game.held_item == Items.CROSSBOW:
		y0 += 30.0 * u
		_text(lx + 38 * u, y0, "Заряжено стрел: " + str(game.dart_ammo) + "/3", int(12 * u), Color(0.55, 0.40, 0.20))
	y0 += 30.0 * u
	_text(lx + 8 * u, y0, "Носить можно только одно. Остальное лежит на полу, где ты его положил.", int(11 * u), Color(0.39, 0.32, 0.24))
	y0 += 22.0 * u
	_text(lx + 8 * u, y0, "Планируй маршрут: за ключом, потом за монтировкой — и не попадись по дороге.", int(11 * u), Color(0.39, 0.32, 0.24))
	var y1 := py + 86.0 * u
	_btext(rx, y1, "Входная дверь:", int(17 * u), Color(0.27, 0.16, 0.12))
	y1 += 30.0 * u
	var lock_names := ["висячий замок — ключ", "ржавый засов — монтировка", "кодовый замок — код 137"]
	for i in 3:
		var mark := "✔  " if game.locks[i] else "✖  "
		var col := Color(0.12, 0.43, 0.16) if game.locks[i] else Color(0.59, 0.17, 0.12)
		_text(rx + 4 * u, y1, mark + lock_names[i], int(13 * u), col)
		y1 += 26.0 * u
	y1 += 18.0 * u
	_btext(rx, y1, "Помни:", int(17 * u), Color(0.27, 0.16, 0.12))
	y1 += 30.0 * u
	var tips := [
		"код от двери лежит на чердаке у Маруси",
		"молоко успокаивает кошку",
		"бутылка (G) отвлекает Гренни",
		"шкаф и кровать спасают, если она не видела",
		"бег слышно через весь дом",
		"капкан выдаст тебя с головой",
	]
	for s in tips:
		_text(rx + 4 * u, y1, "— " + s, int(12 * u), Color(0.39, 0.32, 0.24))
		y1 += 23.0 * u
	_ctext(W * 0.5, py + ph - 18.0 * u, "Tab — закрыть дневник", int(12 * u), Color(0.35, 0.27, 0.19))

# ------------------------------------------------------------------ pause

func _draw_pause(W: float, H: float) -> void:
	var u := _u()
	hover_rects.clear()
	slider_rects.clear()
	draw_rect(Rect2(0, 0, W, H), Color(0.008, 0.008, 0.013, 0.92))
	_fog_layer(W, H, 0.7)
	_grain(W, H, 0.04)
	_vignette(W, H, 0.9)
	_shadow_bctext(W * 0.5, 150 * u, "ПАУЗА", int(40 * u), BONE, 3.0)
	var y := 228.0 * u
	for i in game.pause_items.size():
		var sel := i == game.pause_idx
		var hk := _hover_boost(i)
		var rect := Rect2(W * 0.5 - 240.0 * u, y - 34.0 * u, 480.0 * u, 50.0 * u)
		hover_rects.append(rect)
		if sel:
			var pulse := 0.42 + 0.06 * sin(game.time * 3.0)
			_panel(rect, Color(0.42, 0.10, 0.09, pulse), BLOOD, 2.0)
		elif hk > 0.02:
			_panel(rect, Color(0.42, 0.10, 0.09, 0.22 * hk), Color(0.74, 0.16, 0.13, 0.4 * hk), 1.4)
		var slide := 10.0 * u * hk
		_ctext(W * 0.5 + slide, y, game.pause_items[i], int((25 if sel else 21) * u), BONE if sel else Color(0.65, 0.62, 0.57))
		y += 58.0 * u
	_ctext(W * 0.5, H - 80.0 * u, "День " + str(game.day) + " из " + str(game.max_days) + "   ·   замки: " + str(game.count_locks()) + "/3", int(13 * u), DIM)

# ------------------------------------------------------------------ settings

func _settings_rows() -> Array:
	var s := game.settings
	var pct := func(v: float) -> String: return str(int(round(v * 100.0))) + "%"
	var rows := [
		["ГРОМКОСТЬ ОБЩАЯ", pct.call(s.master_volume), true],
		["ГРОМКОСТЬ МУЗЫКИ", pct.call(s.music_volume), true],
		["ГРОМКОСТЬ ЗВУКОВ", pct.call(s.sfx_volume), true],
		["ЧУВСТВИТЕЛЬНОСТЬ ВЗГЛЯДА", pct.call(s.mouse_sensitivity), true],
		["КАЧЕСТВО ГРАФИКИ", Mats.QUALITY_LABELS[clampi(s.quality, 0, 2)], false],
		["ИНВЕРСИЯ ОСИ Y", "ВКЛ" if s.invert_y else "ВЫКЛ", false],
		["ПОЛНЫЙ ЭКРАН", "ВКЛ" if s.fullscreen else "ВЫКЛ", false],
		["ТЕНИ ФОНАРИКА", "ВКЛ" if s.flashlight_shadows else "ВЫКЛ", false],
		["СГЛАЖИВАНИЕ", s.msaa_label(), false],
		["← НАЗАД", "", false],
	]
	if s.is_touch:
		rows.insert(9, ["РАЗМЕР ТАЧ-ЭЛЕМЕНТОВ", pct.call(s.touch_scale), true])
	return rows

func _draw_settings(W: float, H: float) -> void:
	var u := _u()
	hover_rects.clear()
	slider_rects.clear()
	_menu_bg(W, H, Color(0.008, 0.008, 0.013, 0.98))
	_shadow_bctext(W * 0.5, 64 * u, "НАСТРОЙКИ", int(34 * u), BONE, 3.0)
	_ctext(W * 0.5, 100 * u, "стрелки ← → меняют значение    Esc — выйти", int(14 * u), DIM)
	var rows := _settings_rows()
	var pw := minf(760.0 * u, W - 80.0)
	var px := W * 0.5 - pw * 0.5
	var row_h := minf(52.0 * u, (H - 200.0 * u) / float(rows.size()))
	var y0 := 132.0 * u
	var y := y0
	for i in rows.size():
		var r: Array = rows[i]
		if str(r[0]) == "":
			continue
		var sel := i == game.settings_idx
		var rect := Rect2(px, y, pw, row_h)
		hover_rects.append(rect)
		if sel:
			_panel(rect, Color(0.42, 0.10, 0.09, 0.30), Color(0.74, 0.16, 0.13, 0.75), 1.6)
		elif hover_idx == i:
			var hk := _hover_boost(i)
			_panel(rect, Color(0.42, 0.10, 0.09, 0.16 * hk), Color(0.74, 0.16, 0.13, 0.3 * hk), 1.2)
		var label: String = r[0]
		var val: String = r[1]
		var is_slider: bool = r[2]
		var txt_col := Color(0.92, 0.88, 0.80) if sel else Color(0.72, 0.69, 0.63)
		_text(px + 24 * u, y + row_h * 0.63, label, int(18 * u), txt_col)
		if is_slider:
			var bar := Rect2(px + pw - 320.0 * u, y + row_h * 0.4, 230.0 * u, 12.0 * u)
			slider_rects.append(bar)
			var frac := 0.5
			match i:
				0: frac = game.settings.master_volume
				1: frac = game.settings.music_volume
				2: frac = game.settings.sfx_volume
				3: frac = (game.settings.mouse_sensitivity - 0.2) / 2.3
				9: frac = (game.settings.touch_scale - 0.75) / 1.05
			_bar(bar.position.x, bar.position.y, bar.size.x, bar.size.y, frac, AMBER)
			_text(bar.end.x + 14 * u, y + row_h * 0.63, val, int(15 * u), AMBER)
		elif val != "":
			var tw := _tw(val, int(16 * u))
			_panel(Rect2(px + pw - 130.0 * u - tw * 0.5 - 14.0 * u, y + row_h * 0.23, tw + 28.0 * u, 26.0 * u), Color(0.05, 0.05, 0.08, 0.8), Color(0.55, 0.50, 0.42, 0.4), 1.0)
			_ctext(px + pw - 130.0 * u, y + row_h * 0.63, val, int(16 * u), BONE if val == "ВКЛ" else DIM)
		y += row_h
	_ctext(W * 0.5, y + 34.0 * u, "мышь: клик по переключателю · клик по полосе ставит значение", int(13 * u), Color(0.58, 0.56, 0.50, 0.8))

# ------------------------------------------------------------------ save/load

func _draw_saves(W: float, H: float) -> void:
	var u := _u()
	hover_rects.clear()
	slider_rects.clear()
	_menu_bg(W, H, Color(0.008, 0.008, 0.013, 0.96))
	var is_save := game.state == GrannyGame.STATE_SAVE
	_shadow_bctext(W * 0.5, 70 * u, "СОХРАНИТЬ ИГРУ" if is_save else "ЗАГРУЗИТЬ ИГРУ", int(34 * u), BONE, 3.0)
	_ctext(W * 0.5, 106 * u, "выбери слот" if is_save else "загрузка заменит текущий день", int(14 * u), DIM)
	var pw := minf(680.0 * u, W - 80.0)
	var px := W * 0.5 - pw * 0.5
	var card_h := minf(96.0 * u, (H - 200.0 * u) / 4.0 - 14.0)
	var y := 136.0 * u
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
		_btext(px + 20 * u, y + card_h * 0.36, SaveSystem.slot_label(SaveSystem.ALL_SLOTS[i]), int(18 * u), name_col)
		if m.exists:
			var played := str(int(m.play_time) / 60) + ":" + str(int(m.play_time) % 60).pad_zeros(2)
			var line := "%s · день %d/%d · замки %d/3 · время %s · %s" % [
				m.diff_name, m.day, m.max_days, m.locks, played, _fmt_saved(m.saved_unix),
			]
			_text(px + 20 * u, y + card_h * 0.66, line, int(13 * u), Color(0.72, 0.68, 0.60))
		else:
			_text(px + 20 * u, y + card_h * 0.66, "— пусто —", int(13 * u), Color(0.42, 0.40, 0.37))
		y += card_h + 14.0
	_ctext(W * 0.5, y + 26.0 * u, "Enter — " + ("записать" if is_save else "загрузить") + "    Esc — назад", int(14 * u), DIM)

func _fmt_saved(unix: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d.%02d %02d:%02d" % [dt.day, dt.month, dt.hour, dt.minute]

# ------------------------------------------------------------------ caught

func _draw_caught(W: float, H: float) -> void:
	var u := _u()
	var t := game.caught_t
	draw_rect(Rect2(0, 0, W, H), Color(0.035, 0.004, 0.006, 1.0))
	_grain(W, H, 0.08)
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
	_vignette(W, H, 0.8)
	var flash := maxf(0.0, 1.0 - t * 3.0)
	if flash > 0.01:
		draw_rect(Rect2(0, 0, W, H), Color(0.66, 0.05, 0.04, flash * 0.55))
	for i in 72:
		var bt := float(i) / 71.0
		var alpha := 0.90 * bt * bt
		draw_rect(Rect2(0, H - 260 * u + float(i) * 260.0 * u / 72.0, W, 260.0 * u / 72.0 + 2.0), Color(0.03, 0.0, 0.0, alpha))
	_shadow_bctext(W * 0.5, H - 188.0 * u, "ОНА ТЕБЯ ПОЙМАЛА", int(36 * u), Color(0.94, 0.90, 0.84), 4.0)
	_ctext(W * 0.5, H - 142.0 * u, "День " + str(game.day) + " закончился", int(22 * u), Color(0.84, 0.26, 0.21))
	if game.day < game.max_days:
		_ctext(W * 0.5, H - 100.0 * u, "Осталось дней: " + str(maxi(0, game.max_days - game.day)), int(15 * u), Color(0.74, 0.70, 0.64))
	else:
		_ctext(W * 0.5, H - 100.0 * u, "Это был последний день. Завтра она придёт за тобой.", int(15 * u), Color(0.86, 0.36, 0.32))

# ------------------------------------------------------------------ win

func _draw_win(W: float, H: float) -> void:
	var u := _u()
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.03, 0.035, 0.97))
	_grain(W, H, 0.05)
	_vignette(W, H, 0.75)
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
	_shadow_bctext(W * 0.5, 112 * u, title, int(38 * u), BONE, 4.0)
	_ctext(W * 0.5, 188 * u, story, int(21 * u), Color(0.86, 0.83, 0.77))
	_panel(Rect2(W * 0.5 - 300 * u, 244 * u, 600 * u, 230 * u), Color(0.10, 0.13, 0.10, 0.75), Color(0.48, 0.62, 0.48, 0.45), 1.4)
	var lx := W * 0.5 - 250.0 * u
	var vx := W * 0.5 + 40.0 * u
	var y := 282.0 * u
	_text(lx, y, "СЛОЖНОСТЬ", int(12 * u), DIM)
	_btext(vx, y, game.diff.name, int(18 * u), AMBER)
	y += 42.0 * u
	_text(lx, y, "ДНЕЙ ПОТРАЧЕНО", int(12 * u), DIM)
	_btext(vx, y, str(game.day) + " из " + str(game.max_days), int(18 * u), BONE)
	y += 42.0 * u
	_text(lx, y, "ВРЕМЯ", int(12 * u), DIM)
	_btext(vx, y, str(int(game.play_time) / 60) + ":" + str(int(game.play_time) % 60).pad_zeros(2), int(18 * u), BONE)
	y += 42.0 * u
	_text(lx, y, "СМЕРТЕЙ", int(12 * u), DIM)
	_btext(vx, y, str(game.deaths), int(18 * u), BONE)
	_ctext(W * 0.5, 538 * u, tail, int(15 * u), Color(0.66, 0.63, 0.57))
	var pulse := 0.70 + 0.30 * sin(game.time * 3.0)
	_ctext(W * 0.5, 640 * u, "Enter — в главное меню", int(16 * u), Color(0.90, 0.79, 0.48, pulse))

# ------------------------------------------------------------------ over

func _draw_over(W: float, H: float) -> void:
	var u := _u()
	draw_rect(Rect2(0, 0, W, H), Color(0.035, 0.006, 0.010, 0.98))
	_grain(W, H, 0.07)
	_vignette(W, H, 0.85)
	if face_tex != null:
		var fw := W * 0.46
		var fh := fw * float(face_tex.get_height()) / float(face_tex.get_width())
		draw_texture_rect(face_tex, Rect2(W * 0.64 - fw * 0.5, H * 0.5 - fh * 0.5, fw, fh), false, Color(0.48, 0.16, 0.15, 0.85))
	_shadow_btext(92 * u, 208 * u, "ДНЕЙ БОЛЬШЕ НЕТ", int(42 * u), Color(0.80, 0.14, 0.12), 4.0)
	_text(96 * u, 292 * u, "Она дождалась. Ты остался у неё на ужин.", int(23 * u), Color(0.79, 0.75, 0.69))
	_text(96 * u, 354 * u, "Сложность: " + game.diff.name, int(15 * u), DIM)
	_text(96 * u, 386 * u, "Продержался: " + str(game.day) + " дн. · " + str(int(game.play_time) / 60) + ":" + str(int(game.play_time) % 60).pad_zeros(2), int(15 * u), DIM)
	var pulse := 0.70 + 0.30 * sin(game.time * 3.0)
	_text(96 * u, 474 * u, "Enter — в главное меню", int(16 * u), Color(0.90, 0.79, 0.48, pulse))
