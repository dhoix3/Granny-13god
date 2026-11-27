class_name TouchControls
extends CanvasLayer

# Сенсорное управление (Android/тач-экраны): плавающий виртуальный
# джойстик слева, зона осмотра справа, мультитач-кнопки действий.
# Виден только в STATE_PLAY. Все действия идут через существующие
# обработчики game._on_key / флаги — дублирования логики нет.

var game: GrannyGame
var ui_scale := 1.0
var paint: Control

# состояние (читается player.gd/game.gd через game.touch / game.get(...))
var joy_vec := Vector2.ZERO
var joy_idx := -1
var joy_center := Vector2.ZERO
var look_idx := -1

var _btns: Array[Dictionary] = []
var _pressed: Dictionary = {}  # touch index -> button key (String)
var _joy_k := 0.0  # сглаженное рисование джойстика

func setup(g: GrannyGame) -> void:
	game = g
	layer = 12
	var s := g.settings
	ui_scale = clampf(s.touch_scale, 0.75, 1.8)
	_build_buttons()
	set_process_input(true)
	if paint == null:
		paint = Control.new()
		paint.name = "Paint"
		paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(paint)
		paint.draw.connect(_paint)
	paint.queue_redraw()

func _build_buttons() -> void:
	_btns.clear()
	# key, label, якорь (право/низ в долях экрана), радиус, hold-кнопка?
	_btns.append({"k": "E", "label": "E", "ax": 0.86, "ay": 0.72, "r": 34.0, "hold": true})
	_btns.append({"k": "RUN", "label": "БЕГ", "ax": 0.74, "ay": 0.84, "r": 28.0, "hold": true})
	_btns.append({"k": "CROUCH", "label": "ТШЕ", "ax": 0.86, "ay": 0.90, "r": 26.0, "hold": false})
	_btns.append({"k": "F", "label": "СВЕТ", "ax": 0.74, "ay": 0.62, "r": 24.0, "hold": false})
	_btns.append({"k": "AIM", "label": "ПРЦ", "ax": 0.62, "ay": 0.72, "r": 24.0, "hold": true})
	_btns.append({"k": "G", "label": "БЫТ", "ax": 0.62, "ay": 0.88, "r": 24.0, "hold": false})
	_btns.append({"k": "Q", "label": "ВЫСТР", "ax": 0.50, "ay": 0.80, "r": 26.0, "hold": false})
	_btns.append({"k": "X", "label": "ОСМ", "ax": 0.50, "ay": 0.62, "r": 22.0, "hold": false})
	_btns.append({"k": "TAB", "label": "ДНЕВ", "ax": 0.90, "ay": 0.12, "r": 24.0, "hold": false})
	_btns.append({"k": "ESC", "label": "II", "ax": 0.10, "ay": 0.12, "r": 24.0, "hold": false})

func _radius(b: Dictionary) -> float:
	return float(b.r) * ui_scale

func _btn_rect(b: Dictionary) -> Rect2:
	var vs := game.ui.get_viewport().get_visible_rect().size
	var c := Vector2(vs.x * float(b.ax), vs.y * float(b.ay))
	return Rect2(c - Vector2.ONE * _radius(b), Vector2.ONE * _radius(b) * 2.0)

func _btn_at(p: Vector2) -> String:
	for b in _btns:
		if _btn_rect(b).has_point(p):
			return str(b.k)
	return ""

func _input(event: InputEvent) -> void:
	if game == null or not visible:
		return
	if game.state != game.STATE_PLAY:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var k := _btn_at(st.position)
			var vs := game.ui.get_viewport().get_visible_rect().size
			if k != "":
				_pressed[st.index] = k
				_press(k, true)
			elif st.position.x < vs.x * 0.45 and st.position.y > vs.y * 0.35 and joy_idx == -1:
				# зона джойстика: левый низ
				joy_idx = st.index
				joy_center = st.position
			elif look_idx == -1:
				look_idx = st.index
				game.touch_look_enabled = true
		else:
			if _pressed.has(st.index):
				_press(str(_pressed[st.index]), false)
				_pressed.erase(st.index)
			elif st.index == joy_idx:
				joy_idx = -1
				joy_vec = Vector2.ZERO
			elif st.index == look_idx:
				look_idx = -1
				game.touch_look_enabled = false
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if dr.index == joy_idx:
			var v := (dr.position - joy_center) / (60.0 * ui_scale)
			if v.length() > 1.0:
				v = v.normalized()
			joy_vec = v
		# зона осмотра обрабатывается player._unhandled_input

func _press(k: String, down: bool) -> void:
	match k:
		"E":
			game.touch_e = down
		"RUN":
			game.touch_run = down
		"CROUCH":
			if down:
				game.touch_crouch = not game.touch_crouch
		"AIM":
			game.touch_aim = down
		"F":
			if down:
				game._on_key(KEY_F)
		"G":
			if down:
				game._on_key(KEY_G)
		"Q":
			if down:
				game._on_key(KEY_Q)
		"TAB":
			if down:
				game._on_key(KEY_TAB)
		"ESC":
			if down:
				game._on_key(KEY_ESCAPE)
		"X":
			if down and game.player != null:
				game.player.start_inspect()

func _process(dt: float) -> void:
	visible = game != null and game.state == game.STATE_PLAY and not game.journal
	if visible:
		_joy_k = lerpf(_joy_k, 1.0 if joy_idx != -1 else 0.0, dt * 10.0)
		paint.queue_redraw()

func _paint() -> void:
	if not visible or paint == null:
		return
	var vs := game.ui.get_viewport().get_visible_rect().size
	# джойстик
	if joy_idx != -1:
		_draw_circle2(joy_center, 52.0 * ui_scale, Color(0.9, 0.9, 0.95, 0.14), Color(0.9, 0.9, 0.95, 0.35))
		_draw_circle2(joy_center + joy_vec * 52.0 * ui_scale, 24.0 * ui_scale, Color(0.95, 0.9, 0.8, 0.30), Color(1, 1, 1, 0.5))
	else:
		var hint := Vector2(vs.x * 0.16, vs.y * 0.72)
		_draw_circle2(hint, 46.0 * ui_scale, Color(0.9, 0.9, 0.95, 0.06), Color(0.9, 0.9, 0.95, 0.18))
	# кнопки
	for b in _btns:
		var r := _btn_rect(b)
		var c := r.get_center()
		var act := false
		if b.k in ["E", "RUN", "AIM"]:
			act = bool(game.get("touch_" + str(b.k).to_lower()))
		elif b.k == "CROUCH":
			act = game.touch_crouch
		var base := Color(0.92, 0.90, 0.86, 0.16 if not act else 0.34)
		var border := Color(0.95, 0.92, 0.85, 0.4 if not act else 0.8)
		_draw_circle2(c, _radius(b), base, border)
		var col := Color(0.95, 0.93, 0.88, 0.9 if act else 0.6)
		var f: Font = game.ui.font_bold
		var sz := int(_radius(b) * (0.52 if str(b.label).length() < 2 else 0.42))
		paint.draw_string(f, c - Vector2(game.ui.text_w(str(b.label), f, sz) * 0.5, -sz * 0.36), str(b.label), HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _draw_circle2(c: Vector2, r: float, fill: Color, border: Color) -> void:
	paint.draw_circle(c, r, fill)
	paint.draw_arc(c, r, 0, TAU, 40, border, 1.6)
