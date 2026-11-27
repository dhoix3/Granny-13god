class_name GrannyGame
extends Node3D

# Центральный контроллер игры. Порт Game.cs.

const STATE_TITLE := 0
const STATE_DIFF := 1
const STATE_INTRO := 2
const STATE_PLAY := 3
const STATE_PAUSE := 4
const STATE_CAUGHT := 5
const STATE_WIN := 6
const STATE_OVER := 7
const STATE_HELP := 8
const STATE_SETTINGS := 9
const STATE_SAVE := 10
const STATE_LOAD := 11

const WIN_DOOR := 0
const WIN_CAR := 1
const WIN_SECRET := 2

const TK_HINT := 0
const TK_OK := 1
const TK_ERR := 2

# Музыкальные состояния: menu / ambient (обследование) / tension (рядом,
# что-то услышала) / chase (погоня) / return (после погони, «отпустило»).

class DiffData:
	var name := ""
	var desc := ""
	var walk := 1.62
	var run := 2.30
	var sight := 9.0
	var hear_mul := 1.0
	var hide_check := 0.35
	var cat_range := 3.0
	var traps := 3
	var days := 5
	var battery := 170.0
	var stagger := 18.0
	var god_mode := false
	func _init(pname: String, pdesc: String, pwalk: float, prun: float, psight: float, phear: float, phide: float, pcat: float, ptraps: int, pdays: int, pbattery: float, pstagger: float, pgod := false) -> void:
		name = pname
		desc = pdesc
		walk = pwalk
		run = prun
		sight = psight
		hear_mul = phear
		hide_check = phide
		cat_range = pcat
		traps = ptraps
		days = pdays
		battery = pbattery
		stagger = pstagger
		god_mode = pgod

var world: HouseWorld
var player: PlayerBody
var granny: GrannyAI
var cat: CatAI
var ui: GameUI

var state := STATE_TITLE
var diffs: Array[DiffData] = []
var diff_index := 1
var diff: DiffData

var day := 1
var max_days := 5
var time := 0.0
var play_time := 0.0
# ОДИН предмет в руках: 0 = пусто. Уроненные/отложенные предметы лежат
# в мире (ground_items) и сохраняются.
var held_item := 0
var dart_ammo := 0  # стрелы внутри арбалета (арбалет в руках)
var ground_items: Array[Dictionary] = []
var chase_cool := 0.0  # после погони: спокойный трек, пока не отпустит
var locks: Array[bool] = [false, false, false]
var lock4 := false
var last_win := WIN_DOOR
var car_key_installed := false
var car_battery_installed := false
var noises: Array[Dictionary] = []
var subs: Array[Dictionary] = []
var noise_seen := 0.0
var attic_alert_t := 0.0

var target_kind := 0
var target_obj = null
var prompt := ""
var interact_prog := 0.0
var interact_label := ""
var toast := ""
var toast_t := 0.0
var toast_kind := 0
var journal := false

var caught_t := 0.0
var win_t := 0.0
var fade_t := 0.0
var spider_bite_t := -99.0
var photo_taken := false
var lightning_t := 45.0
var lightning_fx := 0.0
var deaths := 0
var title_t := 0.0
var heart_t := 0.0
var ambient_t := 0.0
var shake := 0.0
var hit_flash := 0.0
var climb_fx := 0.0
var pickup_item := 0
var pickup_t := 0.0
var detect_fx := 0.0
var seed := 20261119

var menu_idx := 0
var diff_idx_menu := 1
var pause_idx := 0
var settings_idx := 0
var save_idx := 0
var diff_return := 0
var settings_return := 0
var save_return := 0
var has_saves := false
var title_hint := ""
var title_hint_t := 0.0
var menu_items := ["ПРОДОЛЖИТЬ", "НОВАЯ ИГРА", "ЗАГРУЗИТЬ ИГРУ", "СЛОЖНОСТЬ", "НАСТРОЙКИ", "КАК ИГРАТЬ", "ВЫХОД"]
var pause_items := ["ПРОДОЛЖИТЬ", "СОХРАНИТЬ ИГРУ", "ЗАГРУЗИТЬ ИГРУ", "СЛОЖНОСТЬ", "НАСТРОЙКИ", "В ГЛАВНОЕ МЕНЮ", "ВЫХОД ИЗ ИГРЫ"]
var settings: GameSettings

var throwns: Array[ThrownBottle] = []
var bloods: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var moon: DirectionalLight3D
var _prev_e := false
var e_hit := false
var e_down := false
var mouse_e_down := false
var debug_on := false
var _autotest = null
# --- сенсорное управление (Android) ---
var touch = null  # TouchControls
var touch_e := false
var touch_run := false
var touch_crouch := false
var touch_aim := false
var touch_look_enabled := false
# переход между экранами (анимация затемнения)
var transition_a := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = seed
	settings = GameSettings.load_settings()
	Mats.set_quality(settings.quality)
	_make_diffs()
	diff = diffs[diff_index]
	_setup_environment()

	world = HouseWorld.new()
	world.name = "World"
	add_child(world)
	world.build()

	player = PlayerBody.new()
	player.name = "Player"
	add_child(player)
	player.setup(self)
	player.flashlight.shadow_enabled = settings.flashlight_shadows

	granny = GrannyAI.new()
	granny.name = "Granny"
	add_child(granny)
	granny.setup(self)

	cat = CatAI.new()
	cat.name = "Cat"
	add_child(cat)
	cat.setup(self)

	var cl := CanvasLayer.new()
	cl.name = "UI"
	cl.layer = 10
	add_child(cl)
	ui = GameUI.new()
	ui.name = "GameUI"
	cl.add_child(ui)
	ui.setup(self)

	if DisplayServer.is_touchscreen_available() or OS.has_feature("android"):
		touch = TouchControls.new()
		touch.name = "TouchControls"
		add_child(touch)
		touch.setup(self)

	settings.apply(get_viewport())
	_refresh_save_cache()
	reset_to_title()
	if OS.get_cmdline_user_args().has("--autotest"):
		_autotest = load("res://tests/autotest.gd").new()
		_autotest.run(self)

func _refresh_save_cache() -> void:
	has_saves = SaveSystem.has_any_save()

func look_scale() -> float:
	return settings.mouse_sensitivity if settings != null else 1.0

func invert_look() -> bool:
	return settings.invert_y if settings != null else false

func _make_diffs() -> void:
	diffs = [
		DiffData.new("ЛЕГКО", "Бабушка сегодня добрая: медленная, слепая и почти не ставит капканы.", 1.35, 1.95, 7.0, 0.75, 0.12, 2.2, 1, 7, 240.0, 25.0),
		DiffData.new("НОРМАЛЬНО", "Классика: она слышит шаги, проверяет шкафы и ставит капканы.", 1.62, 2.30, 9.0, 1.0, 0.35, 3.0, 3, 5, 170.0, 18.0),
		DiffData.new("СЛОЖНО", "Она быстрее тебя и знает дом лучше. Молись, чтобы не скрипнула половица.", 1.85, 2.55, 11.0, 1.28, 0.7, 3.6, 5, 4, 120.0, 14.0),
		DiffData.new("КОШМАР", "Ты уже мёртв — просто ещё не знаешь. Один день, ноль шансов на ошибку.", 2.08, 2.85, 13.0, 1.55, 1.1, 4.4, 7, 2, 95.0, 12.0),
		DiffData.new("ТРЕНИРОВКА", "Песочница: бабушка ничего не может сделать. Освой управление и беги.", 1.30, 1.90, 6.0, 0.55, 0.0, 1.2, 0, 99, 480.0, 60.0, true),
	]

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.007, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.26, 0.25, 0.31)
	env.ambient_light_energy = 1.70
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.025, 0.028, 0.04)
	env.fog_light_energy = 0.6
	env.fog_density = 0.018
	env.fog_aerial_perspective = 0.0
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 0.75
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-62, -35, 0)
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.light_energy = 0.12
	moon.shadow_enabled = false
	add_child(moon)

func _process(dt: float) -> void:
	if dt > 0.08:
		dt = 0.08
	time += dt
	var want_e: bool = Input.is_physical_key_pressed(KEY_E) or mouse_e_down or touch_e
	e_down = want_e
	e_hit = e_down and not _prev_e
	_prev_e = e_down
	match state:
		STATE_TITLE:
			_update_title(dt)
		STATE_PLAY:
			_update_play(dt)
		STATE_CAUGHT:
			_update_caught(dt)
		STATE_WIN, STATE_OVER:
			win_t += dt
	if title_hint_t > 0.0:
		title_hint_t = maxf(0.0, title_hint_t - dt)
	if state != STATE_PLAY:
		_update_menu_hover()
	for i in range(subs.size() - 1, -1, -1):
		subs[i].t += dt
		if subs[i].t > subs[i].dur:
			subs.remove_at(i)
	if toast_t > 0.0:
		toast_t -= dt
	fade_t = maxf(0.0, fade_t - dt * 1.6)
	transition_a = maxf(0.0, transition_a - dt * 3.2)
	shake = maxf(0.0, shake - dt * 2.2)
	if player != null and player.camera != null:
		if state == STATE_PLAY:
			player.camera.h_offset = sin(time * 47.0) * shake * 0.035
			player.camera.v_offset = cos(time * 39.0) * shake * 0.035
		else:
			player.camera.h_offset = 0.0
			player.camera.v_offset = 0.0
	if moon != null:
		moon.light_energy = 0.12 + lightning_fx * 2.4
	if ui != null:
		ui.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var k: int = key_event.physical_keycode
			if k == 0:
				k = key_event.keycode
			_on_key(k)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if state == STATE_PLAY:
				if mouse_event.pressed:
					if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
						mouse_e_down = true
					else:
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					mouse_e_down = false
			elif mouse_event.pressed:
				_menu_click()

func _on_key(k: int) -> void:
	if k == KEY_F11:
		# Переключаем настройку детерминированно: чтение win.mode после
		# присваивания ненадёжно (в headless режим всегда WINDOWED,
		# на некоторых платформах применяется асинхронно).
		settings.fullscreen = not settings.fullscreen
		var win := get_window()
		win.mode = Window.MODE_FULLSCREEN if settings.fullscreen else Window.MODE_WINDOWED
		settings.save_settings()
		return
	if k == KEY_F1:
		debug_on = not debug_on
		Audio.play("ui_move", 0.4, 1.2)
		return
	match state:
		STATE_TITLE:
			if k == KEY_UP or k == KEY_W:
				menu_idx = (menu_idx + menu_items.size() - 1) % menu_items.size()
				Audio.play("ui_move", 0.5, 1.0)
			elif k == KEY_DOWN or k == KEY_S:
				menu_idx = (menu_idx + 1) % menu_items.size()
				Audio.play("ui_move", 0.5, 1.0)
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				Audio.play("ui_select", 0.6, 1.0)
				_activate_title_item()
			elif k == KEY_ESCAPE:
				get_tree().quit()
		STATE_DIFF:
			if k == KEY_UP or k == KEY_W or k == KEY_LEFT or k == KEY_A:
				diff_idx_menu = (diff_idx_menu + diffs.size() - 1) % diffs.size()
				Audio.play("ui_move", 0.5, 1.0)
			elif k == KEY_DOWN or k == KEY_S or k == KEY_RIGHT or k == KEY_D:
				diff_idx_menu = (diff_idx_menu + 1) % diffs.size()
				Audio.play("ui_move", 0.5, 1.0)
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				diff_index = diff_idx_menu
				diff = diffs[diff_index]
				Audio.play("ui_select", 0.6, 1.0)
				_set_state(STATE_PAUSE if diff_return == 1 else STATE_TITLE)
			elif k == KEY_ESCAPE:
				_set_state(STATE_PAUSE if diff_return == 1 else STATE_TITLE)
		STATE_HELP:
			if k == KEY_ESCAPE or k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				_set_state(STATE_TITLE)
		STATE_SETTINGS:
			_on_key_settings(k)
		STATE_SAVE, STATE_LOAD:
			_on_key_saves(k)
		STATE_INTRO:
			if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or k == KEY_ESCAPE:
				_set_state(STATE_PLAY)
				fade_t = 1.0
				push_subtitle("Найди три ключа и открой входную дверь.", 4.0, false)
				SaveSystem.save_run(self, SaveSystem.AUTO)
				_refresh_save_cache()
		STATE_PLAY:
			if k == KEY_ESCAPE:
				_set_state(STATE_PAUSE)
				pause_idx = 0
			elif k == KEY_TAB:
				journal = not journal
				player.velocity = Vector3.ZERO
				if not journal and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			elif k == KEY_G:
				# G: бутылка в руках — бросить; другой предмет — положить на пол
				if held_item == Items.BOTTLE:
					throw_bottle()
				elif held_item != Items.NONE:
					drop_held()
				else:
					toast_msg("Руки пусты.", 1.6, TK_HINT)
			elif k == KEY_F:
				toggle_flash()
			elif k == KEY_Q:
				fire_crossbow()
			elif k == KEY_X:
				player.start_inspect()
			elif k == KEY_SPACE:
				if player.trap_stuck > 0.0:
					player.trap_stuck -= 0.22
					player.trap_mash += 0.22
					Audio.play("step2", 0.5, 1.6)
		STATE_PAUSE:
			if k == KEY_ESCAPE or k == KEY_BACKSPACE:
				_set_state(STATE_PLAY)
				pause_idx = 0
			elif k == KEY_UP or k == KEY_W:
				pause_idx = (pause_idx + pause_items.size() - 1) % pause_items.size()
				Audio.play("ui_move", 0.5, 1.0)
			elif k == KEY_DOWN or k == KEY_S:
				pause_idx = (pause_idx + 1) % pause_items.size()
				Audio.play("ui_move", 0.5, 1.0)
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				Audio.play("ui_select", 0.6, 1.0)
				_activate_pause_item()
		STATE_WIN, STATE_OVER:
			if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or k == KEY_ESCAPE:
				reset_to_title()

func _activate_title_item() -> void:
	match menu_idx:
		0:
			var slot := SaveSystem.latest_slot()
			if slot == "":
				title_hint = "Пока нет сохранений. Начни новую игру."
				title_hint_t = 3.5
			elif SaveSystem.load_run(self, slot):
				_refresh_save_cache()
				push_subtitle("Загружено: день " + str(day) + ".", 3.0, false)
			else:
				title_hint = "Не удалось загрузить сохранение."
				title_hint_t = 3.0
		1:
			start_game()
		2:
			save_return = 0
			save_idx = 0
			_set_state(STATE_LOAD)
		3:
			diff_return = 0
			diff_idx_menu = diff_index
			_set_state(STATE_DIFF)
		4:
			settings_return = 0
			settings_idx = 0
			_set_state(STATE_SETTINGS)
		5:
			_set_state(STATE_HELP)
		6:
			get_tree().quit()

func _activate_pause_item() -> void:
	match pause_idx:
		0:
			_set_state(STATE_PLAY)
		1:
			save_return = 1
			save_idx = 0
			_set_state(STATE_SAVE)
		2:
			save_return = 1
			save_idx = 0
			_set_state(STATE_LOAD)
		3:
			diff_return = 1
			diff_idx_menu = diff_index
			_set_state(STATE_DIFF)
		4:
			settings_return = 1
			settings_idx = 0
			_set_state(STATE_SETTINGS)
		5:
			reset_to_title()
		6:
			get_tree().quit()

func _menu_click() -> void:
	match state:
		STATE_TITLE:
			if ui.hover_idx >= 0 and ui.hover_idx < menu_items.size():
				if menu_idx == ui.hover_idx:
					Audio.play("ui_select", 0.6, 1.0)
					_activate_title_item()
				else:
					menu_idx = ui.hover_idx
					Audio.play("ui_move", 0.5, 1.0)
		STATE_DIFF:
			var di := ui.hover_diff_index()
			if di >= 0:
				diff_idx_menu = di
				diff_index = di
				diff = diffs[diff_index]
				Audio.play("ui_select", 0.6, 1.0)
				_set_state(STATE_PAUSE if diff_return == 1 else STATE_TITLE)
		STATE_SETTINGS:
			_click_setting()
		STATE_PAUSE:
			if ui.hover_idx >= 0 and ui.hover_idx < pause_items.size():
				if pause_idx == ui.hover_idx:
					Audio.play("ui_select", 0.6, 1.0)
					_activate_pause_item()
				else:
					pause_idx = ui.hover_idx
					Audio.play("ui_move", 0.5, 1.0)
		STATE_SAVE, STATE_LOAD:
			if ui.hover_idx >= 0 and ui.hover_idx < SaveSystem.ALL_SLOTS.size():
				save_idx = ui.hover_idx
				Audio.play("ui_select", 0.6, 1.0)
				_activate_save_slot()
		STATE_HELP:
			_set_state(STATE_TITLE)
		STATE_WIN, STATE_OVER:
			reset_to_title()

func settings_row_count() -> int:
	return 11 if settings != null and settings.is_touch else 10

func _on_key_settings(k: int) -> void:
	if k == KEY_UP or k == KEY_W:
		settings_idx = (settings_idx + settings_row_count() - 1) % settings_row_count()
		Audio.play("ui_move", 0.5, 1.0)
	elif k == KEY_DOWN or k == KEY_S:
		settings_idx = (settings_idx + 1) % settings_row_count()
		Audio.play("ui_move", 0.5, 1.0)
	elif k == KEY_LEFT or k == KEY_A:
		_adjust_setting(settings_idx, -1.0)
	elif k == KEY_RIGHT or k == KEY_D:
		_adjust_setting(settings_idx, 1.0)
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		_cycle_setting(settings_idx)
	elif k == KEY_ESCAPE or k == KEY_BACKSPACE:
		_close_settings()

func _adjust_setting(row: int, dir: float) -> void:
	var changed := false
	match row:
		0:
			settings.master_volume = clampf(settings.master_volume + dir * 0.05, 0.0, 1.0)
			changed = true
		1:
			settings.music_volume = clampf(settings.music_volume + dir * 0.05, 0.0, 1.0)
			changed = true
		2:
			settings.sfx_volume = clampf(settings.sfx_volume + dir * 0.05, 0.0, 1.0)
			changed = true
		3:
			settings.mouse_sensitivity = clampf(settings.mouse_sensitivity + dir * 0.1, 0.2, 2.5)
			changed = true
		4:
			settings.quality = (settings.quality + (1 if dir >= 0.0 else 2)) % 3
			changed = true
		5:
			settings.invert_y = not settings.invert_y
			changed = true
		6:
			settings.fullscreen = not settings.fullscreen
			changed = true
		7:
			settings.flashlight_shadows = not settings.flashlight_shadows
			changed = true
		8:
			settings.msaa = (settings.msaa + (1 if dir >= 0.0 else 2)) % 3
			changed = true
		9:
			if settings.is_touch:
				settings.touch_scale = clampf(settings.touch_scale + dir * 0.1, 0.75, 1.8)
				changed = true
			else:
				return
		10:
			return
	if not changed:
		return
	_apply_settings_live(row)
	Audio.play("ui_move", 0.55, 1.0 if dir >= 0.0 else 0.9)

func _cycle_setting(row: int) -> void:
	if row == settings_row_count() - 1:
		_close_settings()
		return
	_adjust_setting(row, 1.0)

func _click_setting() -> void:
	var row := ui.hover_idx
	if row < 0 or row >= settings_row_count():
		return
	if row == settings_row_count() - 1:
		Audio.play("ui_select", 0.6, 1.0)
		_close_settings()
		return
	if row <= 3 or (row == 9 and settings.is_touch):
		# слайдер: значение по позиции клика
		var frac := ui.hover_row_frac
		match row:
			0:
				settings.master_volume = clampf(frac, 0.0, 1.0)
			1:
				settings.music_volume = clampf(frac, 0.0, 1.0)
			2:
				settings.sfx_volume = clampf(frac, 0.0, 1.0)
			3:
				settings.mouse_sensitivity = clampf(0.2 + frac * 2.3, 0.2, 2.5)
			9:
				settings.touch_scale = clampf(0.75 + frac * 1.05, 0.75, 1.8)
		_apply_settings_live(row)
		Audio.play("ui_move", 0.55, 1.0)
	else:
		_adjust_setting(row, 1.0)

func _apply_settings_live(row: int) -> void:
	settings.save_settings()
	if row <= 2:
		settings.apply_audio()
	elif row == 4:
		Mats.set_quality(settings.quality)
		settings.apply_video(get_viewport())
		if touch != null:
			touch.setup(self)
	elif row == 6 or row == 8:
		settings.apply_video(get_viewport())
	elif row == 7:
		player.flashlight.shadow_enabled = settings.flashlight_shadows
	elif row == 9:
		if touch != null:
			touch.setup(self)

func _close_settings() -> void:
	settings.save_settings()
	_set_state(STATE_PAUSE if settings_return == 1 else STATE_TITLE)

func _on_key_saves(k: int) -> void:
	var n := SaveSystem.ALL_SLOTS.size()
	if k == KEY_UP or k == KEY_W:
		save_idx = (save_idx + n - 1) % n
		Audio.play("ui_move", 0.5, 1.0)
	elif k == KEY_DOWN or k == KEY_S:
		save_idx = (save_idx + 1) % n
		Audio.play("ui_move", 0.5, 1.0)
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		Audio.play("ui_select", 0.6, 1.0)
		_activate_save_slot()
	elif k == KEY_ESCAPE or k == KEY_BACKSPACE:
		_set_state(STATE_PAUSE if save_return == 1 else STATE_TITLE)

func _activate_save_slot() -> void:
	var slot: String = SaveSystem.ALL_SLOTS[save_idx]
	if state == STATE_SAVE:
		if SaveSystem.save_run(self, slot):
			_refresh_save_cache()
			Audio.play("unlock", 0.6, 1.1)
			if save_return == 1:
				toast_msg("Сохранено: " + SaveSystem.slot_label(slot), 2.6, TK_OK)
			else:
				title_hint = "Сохранено: " + SaveSystem.slot_label(slot)
				title_hint_t = 3.0
			_set_state(STATE_PAUSE if save_return == 1 else STATE_TITLE)
		else:
			toast_msg("Ошибка сохранения.", 2.4, TK_ERR)
	else:
		var m := SaveSystem.read_meta(slot)
		if not m.exists:
			Audio.play("ui_move", 0.4, 0.6)
			return
		if SaveSystem.load_run(self, slot):
			_refresh_save_cache()
			push_subtitle("Загружено: день " + str(day) + ".", 3.0, false)
		else:
			toast_msg("Не удалось загрузить сохранение.", 2.4, TK_ERR)

func _set_state(s: int) -> void:
	state = s
	if s == STATE_PLAY:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		mouse_e_down = false
		touch_e = false
		touch_run = false
		touch_aim = false
		touch_look_enabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	transition_a = 1.0
	_update_music_for_state()

func _update_menu_hover() -> void:
	if ui == null:
		return
	var prev_hover := ui.hover_idx
	ui.update_hover(state)
	match state:
		STATE_TITLE:
			var idx := ui.hover_idx
			if idx >= 0 and idx < menu_items.size() and idx != menu_idx:
				menu_idx = idx
				if prev_hover != idx:
					Audio.play("ui_move", 0.45, 1.0)
		STATE_PAUSE:
			var idx := ui.hover_idx
			if idx >= 0 and idx < pause_items.size() and idx != pause_idx:
				pause_idx = idx
				if prev_hover != idx:
					Audio.play("ui_move", 0.45, 1.0)
		STATE_DIFF:
			var di := ui.hover_diff_index()
			if di >= 0 and di != diff_idx_menu:
				diff_idx_menu = di
				Audio.play("ui_move", 0.45, 1.0)
		STATE_SETTINGS:
			var idx := ui.hover_idx
			if idx >= 0 and idx < settings_row_count() and idx != settings_idx:
				settings_idx = idx
				Audio.play("ui_move", 0.45, 1.0)
		STATE_SAVE, STATE_LOAD:
			var idx := ui.hover_idx
			if idx >= 0 and idx < SaveSystem.ALL_SLOTS.size() and idx != save_idx:
				save_idx = idx
				Audio.play("ui_move", 0.45, 1.0)

func _update_music_for_state() -> void:
	if Audio == null:
		return
	match state:
		STATE_TITLE, STATE_DIFF, STATE_HELP:
			Audio.set_music("music_menu")
			Audio.music_energy = 1.0
		STATE_SETTINGS, STATE_SAVE, STATE_LOAD:
			if settings_return == 0 and state == STATE_SETTINGS or save_return == 0 and (state == STATE_SAVE or state == STATE_LOAD):
				Audio.set_music("music_menu")
			Audio.music_energy = 1.0
		STATE_INTRO, STATE_PLAY, STATE_CAUGHT, STATE_WIN, STATE_OVER:
			Audio.set_music("music_ambient")
			Audio.music_energy = 1.0
		STATE_PAUSE:
			# трек не меняем — приглушаем текущий (после паузы продолжится)
			Audio.music_energy = 0.45

func can_look() -> bool:
	return state == STATE_PLAY and not journal and player != null and not player.dead

func reset_to_title() -> void:
	state = STATE_TITLE
	title_t = 0.0
	journal = false
	mouse_e_down = false
	subs.clear()
	throwns.clear()
	menu_idx = 0
	title_hint = ""
	title_hint_t = 0.0
	_refresh_save_cache()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player.place_at(0, 15.5, 27.2, -PI * 0.5 + 0.06)
	player.pitch = -0.10
	player.flashlight_on = true
	player.battery = 0.95
	player.apply_camera()
	granny.spawn(world.levels[0], 16.55, 23.0, PI * 0.5)
	granny.state = GrannyAI.PATROL
	granny.scream_t = 0.0
	granny.update_transform()

func start_game() -> void:
	diff = diffs[diff_index]
	max_days = diff.days
	day = 1
	held_item = Items.NONE
	dart_ammo = 0
	player.set_held(0)
	clear_ground_items()
	locks = [false, false, false]
	lock4 = false
	last_win = WIN_DOOR
	car_key_installed = false
	car_battery_installed = false
	noises.clear()
	subs.clear()
	play_time = 0.0
	deaths = 0
	target_kind = 0
	target_obj = null
	prompt = ""
	interact_prog = 0.0
	interact_label = ""
	journal = false
	pickup_t = 0.0
	pickup_item = 0
	toast = ""
	toast_t = 0.0
	detect_fx = 0.0
	climb_fx = 0.0
	hit_flash = 0.0
	photo_taken = false
	lightning_t = time + 45.0 + rng.randf() * 15.0
	lightning_fx = 0.0
	caught_t = 0.0
	win_t = 0.0
	fade_t = 0.0
	shake = 0.0
	heart_t = 0.0
	ambient_t = 0.0
	attic_alert_t = 0.0
	chase_cool = 0.0
	for b in bloods:
		if is_instance_valid(b):
			b.queue_free()
	bloods.clear()
	for t in throwns:
		if is_instance_valid(t):
			t.queue_free()
	throwns.clear()
	world.clear_traps()
	# предметы всегда по фиксированному плану — планировка никогда не меняется
	HousePlan.reset_items(world.levels)
	for lv in world.levels:
		for c in lv.containers:
			c.searched = false
		for d in lv.doors:
			d.open = false
			d.open_t = 0.0
	world.set_garage_open(false)
	world.set_front_locks(0)
	world.update_doors(0.0)
	place_starting_traps()
	respawn_player()
	cat.reset()
	_set_state(STATE_INTRO)

func place_starting_traps() -> void:
	# Капканы стоят в заранее спроектированных точках фиксированного плана;
	# сложность задаёт только их количество (первые N списка) — планировка
	# дома и положение капканов никогда не меняются между прохождениями.
	var lv: LevelData = world.levels[0]
	var spots: Array = HousePlan.PLAN["trap_spots"]
	var n := mini(diff.traps, spots.size())
	for i in n:
		var s: Array = spots[i]
		var gx := int(s[0])
		var gy := int(s[1])
		# страховка от опечатки в плане; полноту проверяет logic_check.py
		if lv.solid_at(gx, gy) or lv.door_at(gx, gy) != null:
			continue
		world.add_trap(lv, float(gx) + 0.5, float(gy) + 0.5)

func respawn_player() -> void:
	var lv: LevelData = world.levels[0]
	player.place_at(0, lv.spawn_x, lv.spawn_y, lv.spawn_a)
	player.reset_state()
	var gs: Dictionary = HousePlan.granny_start()
	granny.spawn(world.levels[int(gs["lv"])], float(gs["x"]), float(gs["y"]), float(gs["a"]))
	granny.trap_t = 10.0 + rng.randf() * 8.0
	target_kind = 0
	target_obj = null
	interact_prog = 0.0
	attic_alert_t = 0.0

func _update_title(dt: float) -> void:
	title_t += dt
	var lv: LevelData = world.levels[0]
	var px := 15.5 + sin(title_t * 0.16) * 0.35
	var pz := 27.0
	var a := -PI * 0.5 - 0.14 + sin(title_t * 0.11) * 0.03
	player.level = 0
	player.global_position = lv.origin + Vector3(px, 0.02, pz)
	player.angle = a
	player.pitch = -0.17 + sin(title_t * 0.23) * 0.035
	player.rotation.y = -a - PI * 0.5
	player.camera.position = Vector3(0, 1.55, 0)
	player.camera.rotation.x = player.pitch
	player.camera.fov = 75.0
	player.flashlight_on = true
	player.battery = 0.9 + 0.1 * sin(title_t * 1.7)
	player.apply_camera()
	granny.level = 0
	granny.x = 16.55 + sin(title_t * 0.5) * 0.10
	granny.y = 23.0
	granny.angle = PI * 0.5
	granny.anim_t += dt
	granny.state = GrannyAI.INVESTIGATE if sin(title_t * 0.21) > 0.55 else GrannyAI.PATROL
	granny.update_transform()

func _update_play(dt: float) -> void:
	if player.dead:
		return
	if journal:
		player.velocity = Vector3.ZERO
		return
	play_time += dt
	if climb_fx > 0.0:
		climb_fx = maxf(0.0, climb_fx - dt * 1.7)
	if pickup_t > 0.0:
		pickup_t = maxf(0.0, pickup_t - dt)
	hit_flash = maxf(0.0, hit_flash - dt * 4.0)
	lightning_fx = maxf(0.0, lightning_fx - dt * 2.5)

	world.update_doors(dt)
	_update_thrown(dt)
	_update_atmosphere(dt)
	_update_music_intensity()
	cat.update(dt, self)

	if player.hidden:
		player.angle = clampf(player.angle, -1.1, 1.1)
		if e_hit:
			exit_hide()
		granny.update(dt, self)
		_update_detect(dt)
		return

	update_target_scan()
	update_interaction(dt)
	if state != STATE_PLAY:
		return
	update_traps(dt)
	update_spiders(dt)

	if has_item(Items.TEDDY) and granny.level == player.level and granny.state != GrannyAI.STAGGER:
		granny.notice = minf(1.0, granny.notice + dt * 2.0)
		if granny.notice >= 1.0 and granny.state != GrannyAI.CHASE:
			granny.state = GrannyAI.CHASE
			var pp := player_local()
			granny.target_x = pp.x
			granny.target_y = pp.y

	granny.update(dt, self)
	_update_detect(dt)

	if chase_cool > 0.0:
		chase_cool = maxf(0.0, chase_cool - dt)

	for i in range(noises.size() - 1, -1, -1):
		if time - float(noises[i].time) > 2.5:
			noises.remove_at(i)
	if attic_alert_t > 0.0:
		attic_alert_t -= dt

	var pl := player_local()
	var d := Vector2(pl.x - granny.x, pl.y - granny.y).length()
	var prox := clampf(1.0 - d / 9.0, 0.0, 1.0)
	if granny.level != player.level:
		prox *= 0.15
	Audio.music_energy = 1.0 + detect_fx * 0.5 + prox * 0.25
	heart_t -= dt
	if heart_t <= 0.0 and prox > 0.25:
		Audio.play("heart", 0.35 + prox * 0.55, 1.0 + prox * 0.25)
		heart_t = lerpf(1.25, 0.42, prox)
	if time > lightning_t:
		lightning_fx = 1.0
		lightning_t = time + 30.0 + rng.randf() * 30.0
		Audio.play("thunder", 0.55, 0.7 + rng.randf() * 0.4)

func _update_music_intensity() -> void:
	# Состояния: ambient (осматриваюсь) → tension (она рядом или что-то услышала)
	# → chase (погоня) → return (погоня кончилась, отпустило — музыка выдоха).
	if Audio == null or player == null or granny == null:
		return
	var want := "music_ambient"
	if granny.state == GrannyAI.CHASE and granny.level == player.level:
		want = "music_chase"
		chase_cool = 16.0
	elif chase_cool > 0.0 and granny.level == player.level:
		want = "music_return"
	elif (granny.state == GrannyAI.INVESTIGATE and granny.level == player.level) or granny.notice > 0.35:
		want = "music_tension"
	Audio.set_music(want)

func _update_detect(dt: float) -> void:
	var seen := granny.level == player.level and not player.hidden and (granny.state == GrannyAI.CHASE or granny.notice > 0.15)
	var target := 1.0 if granny.state == GrannyAI.CHASE else 0.5
	detect_fx = move_toward(detect_fx, target if seen else 0.0, dt * 3.0)

func _update_atmosphere(dt: float) -> void:
	# амбиентная петля этажа: ветер в доме / чердак / подвал
	if Audio._amb_target != _ambient_track():
		Audio.set_ambient(_ambient_track())
	ambient_t -= dt
	if ambient_t <= 0.0:
		ambient_t = 11.0 + rng.randf() * 22.0
		var r := rng.randf()
		var pl := player_local()
		if r < 0.22:
			# скрип из случайной точки рядом — создаёт объём
			var ang := rng.randf() * TAU
			var rad := 3.0 + rng.randf() * 5.0
			Audio.play3d("creak", world.get_root(player.level), Vector3(pl.x + cos(ang) * rad, 1.8, pl.y + sin(ang) * rad), 0.24, 0.55 + rng.randf() * 0.4, 4.0)
		elif r < 0.36:
			Audio.play3d("floor_creak2", world.get_root(player.level), Vector3(pl.x + cos(rng.randf() * TAU) * 2.2, 0.1, pl.y + sin(rng.randf() * TAU) * 2.2), 0.20, 0.9 + rng.randf() * 0.3, 3.0)
		elif r < 0.50:
			Audio.play3d("house_settle", world.get_root(player.level), Vector3(pl.x + rng.randf_range(-4, 4), 2.2, pl.y + rng.randf_range(-4, 4)), 0.40, 0.85 + rng.randf() * 0.3, 9.0)
		elif r < 0.62:
			Audio.play("distant_noise", 0.30, 0.85 + rng.randf() * 0.3)
		elif r < 0.72:
			Audio.play3d("something_falls", world.get_root(player.level), Vector3(pl.x + rng.randf_range(-3.5, 3.5), 1.0, pl.y + rng.randf_range(-3.5, 3.5)), 0.42, 0.9 + rng.randf() * 0.25, 7.0)
		elif r < 0.82 and player.level == 0:
			# царапанье окна снаружи — только в доме
			var wins := []
			for y in range(world.levels[0].h):
				for x in range(world.levels[0].w):
					if world.levels[0].get_tile(x, y) == LevelData.WINDOW:
						wins.append(Vector2(x + 0.5, y + 0.5))
			if wins.size() > 0:
				var w2: Vector2 = wins[rng.randi_range(0, wins.size() - 1)]
				Audio.play3d("window_scratch", world.get_root(0), Vector3(w2.x, 1.4, w2.y), 0.38, 0.9 + rng.randf() * 0.2, 5.0)
		elif r < 0.92:
			Audio.play("whisper", 0.25, 0.8)
		else:
			Audio.play("thunder", 0.28, 0.8)

func _ambient_track() -> String:
	match player.level:
		1: return "attic_loop"
		3: return "cellar_loop"
	return "wind_loop"

func _update_caught(dt: float) -> void:
	caught_t += dt
	var lv: LevelData = world.levels[player.level]
	var pl := player_local()
	player.angle = atan2(granny.y - pl.y, granny.x - pl.x)
	var d := maxf(0.42, 1.25 - caught_t * 0.55)
	granny.x = pl.x + cos(player.angle) * d
	granny.y = pl.y + sin(player.angle) * d
	granny.angle = player.angle + PI
	player.rotation.y = -player.angle - PI * 0.5
	player.camera.position = Vector3(0, 1.55, 0)
	player.camera.rotation.x = sin(caught_t * 9.0) * 0.07
	granny.update_transform()
	if caught_t > 2.9:
		day += 1
		if day > max_days:
			_set_state(STATE_OVER)
			win_t = 0.0
			Audio.play("lose", 0.8, 1.0)
		else:
			respawn_player()
			_set_state(STATE_PLAY)
			push_subtitle("День " + str(day) + ". Она снова где-то в доме...", 4.0, false)
			Audio.play("thunder", 0.5, 1.0)
			SaveSystem.save_run(self, SaveSystem.AUTO)
			_refresh_save_cache()

func player_local() -> Vector2:
	var lv: LevelData = world.levels[player.level]
	var p: Vector3 = player.global_position - lv.origin
	return Vector2(p.x, p.z)

func emit_noise(x: float, y: float, r: float, what: String) -> void:
	noises.append({"x": x, "y": y, "radius": r, "what": what, "time": time, "level": player.level})
	if player.level == 1:
		attic_alert_t = maxf(attic_alert_t, 6.0)

func push_subtitle(text: String, dur: float, is_granny: bool) -> void:
	if subs.size() > 0 and str(subs[subs.size() - 1].text) == text:
		subs[subs.size() - 1].t = 0.0
		return
	subs.append({"text": text, "dur": dur, "t": 0.0, "granny": is_granny})
	if subs.size() > 4:
		subs.remove_at(0)

func toast_msg(text: String, dur: float, kind: int) -> void:
	toast = text
	toast_t = dur
	toast_kind = kind

func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)

func has_item(id: int) -> bool:
	return held_item == id

# Взять предмет в руки (руки обязаны быть свободны — проверяет вызывающий).
func give_item(id: int) -> void:
	if id == Items.NONE:
		return
	held_item = int(id)
	player.set_held(held_item)
	pickup_item = held_item
	pickup_t = 2.4
	if held_item == Items.BATTERY:
		player.battery = minf(1.0, player.battery + 0.55)
	if held_item == Items.BANDAGE:
		player.health = minf(1.0, player.health + 0.5)
	if held_item == Items.PHOTO:
		max_days += 1
		photo_taken = true
	if held_item == Items.CROSSBOW:
		dart_ammo = 0

# Освободить руки (использованный/переданный предмет исчезает из мира).
func remove_item(id: int) -> void:
	if held_item != id:
		return
	held_item = Items.NONE
	player.set_held(0)

# Положить предмет на пол в текущей точке: остаётся лежать в мире.
func drop_held(silent := false) -> void:
	if held_item == Items.NONE or player.hidden:
		return
	var pl := player_local()
	# чуть впереди взгляда, чтобы предмет не оказался внутри игрока
	var dx := cos(player.angle) * 0.55
	var dy := sin(player.angle) * 0.55
	var lv: LevelData = world.levels[player.level]
	var gx := pl.x + dx
	var gy := pl.y + dy
	if lv.solid_at(gx, gy):
		gx = pl.x
		gy = pl.y
	spawn_ground_item(held_item, player.level, gx, gy)
	held_item = Items.NONE
	player.set_held(0)
	if not silent:
		Audio.play("item_drop", 0.7, 1.0)
		emit_noise(gx, gy, 2.2, "предмет")

func spawn_ground_item(id: int, level_id: int, x: float, y: float) -> void:
	var lv: LevelData = world.levels[level_id]
	var root := world.get_root(level_id)
	var n := Node3D.new()
	n.name = "GroundItem"
	root.add_child(n)
	n.position = Vector3(x, 0.32, y)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_texture = Items.icon_texture(id)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.35
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	# тень-кружок на полу
	var sh := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(0.30, 0.30)
	sh.mesh = dq
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.30)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh.material_override = sm
	sh.rotation.x = -PI * 0.5
	sh.position = Vector3(0, -0.305, 0)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(sh)
	ground_items.append({"id": id, "level": level_id, "x": x, "y": y, "node": n, "t": rng.randf() * TAU})

func clear_ground_items() -> void:
	for gi in ground_items:
		var n = gi.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
	ground_items.clear()

# Подобрать предмет с пола (руки уже свободны).
func take_ground_item(idx: int) -> void:
	if idx < 0 or idx >= ground_items.size():
		return
	var gi: Dictionary = ground_items[idx]
	var n = gi.get("node")
	if n != null and is_instance_valid(n):
		n.queue_free()
	ground_items.remove_at(idx)
	var id := int(gi["id"])
	if held_item == Items.CROSSBOW and id == Items.DART:
		# стрела заряжается в арбалет, оставаясь в руках у арбалета
		if dart_ammo < 3:
			dart_ammo += 1
			Audio.play("crossbow_reload", 0.6, 1.1)
			toast_msg("Стрела заряжена (%d/3)." % dart_ammo, 2.2, TK_OK)
		else:
			# арбалет полон — стрела остаётся на полу
			spawn_ground_item(id, int(gi["level"]), float(gi["x"]), float(gi["y"]))
			toast_msg("Арбалет уже заряжен.", 2.2, TK_HINT)
		return
	give_item(id)
	Audio.play("pickup", 0.7, 1.0)
	toast_msg("Взято: " + Items.display_name(id), 2.6, TK_OK)
	push_subtitle(Items.hint(id), 3.4, false)

func count_locks() -> int:
	var n := 0
	for v in locks:
		if v:
			n += 1
	return n

func in_spider_web() -> bool:
	if player.level != 3:
		return false
	var lv: LevelData = world.levels[3]
	var pl := player_local()
	for w in lv.webs:
		if w.has_point(pl):
			return true
	return false

func toggle_flash() -> void:
	if player.battery <= 0.02:
		toast_msg("Фонарик сел. Нужна батарейка.", 2.4, TK_ERR)
		return
	player.flashlight_on = not player.flashlight_on
	Audio.play("lock", 0.3, 1.3)

func update_target_scan() -> void:
	target_kind = 0
	target_obj = null
	prompt = ""
	interact_label = ""
	if player.trap_stuck > 0.0:
		target_kind = 8
		prompt = "Снять капкан (удерживать E)"
		return
	var lv: LevelData = world.levels[player.level]
	var pl := player_local()
	var px := pl.x
	var pz := pl.y
	var dirx := cos(player.angle)
	var dirz := sin(player.angle)

	var best = null
	var best_score := 1.0e9
	for d in lv.decos:
		if d.container == null and d.hide == null:
			continue
		var vx: float = d.x - px
		var vy: float = d.y - pz
		var dist := sqrt(vx * vx + vy * vy)
		if dist > 2.8 or dist < 0.01:
			continue
		var dot := (vx * dirx + vy * dirz) / dist
		if dot < 0.45:
			continue
		if not lv.line_of_sight(px, pz, d.x, d.y):
			continue
		var score := dist - dot * 0.8
		if score < best_score:
			best_score = score
			best = d
	if best != null:
		if best.hide != null and (best.container == null or best.container.searched):
			target_kind = 3
			target_obj = best.hide
			prompt = "Спрятаться: " + str(best.hide.label)
			return
		if best.container != null:
			target_kind = 2
			target_obj = best.container
			if best.container.searched:
				if best.container.item_id != Items.NONE:
					if held_item != Items.NONE:
						prompt = "Там: " + Items.display_name(best.container.item_id) + " — руки заняты"
					else:
						prompt = "Поднять: " + Items.display_name(best.container.item_id)
				elif best.hide != null:
					target_kind = 3
					target_obj = best.hide
					prompt = "Спрятаться: " + str(best.hide.label)
					return
				else:
					prompt = str(best.name) + " — пусто"
			else:
				prompt = "Обыскать: " + str(best.container.label)
			return

	# предметы на полу рядом (уроненные/отложенные)
	var gi_best := -1
	var gi_dist := 2.1
	for gi in ground_items.size():
		var gi_d: Dictionary = ground_items[gi]
		if int(gi_d["level"]) != player.level:
			continue
		var vx2: float = float(gi_d["x"]) - px
		var vy2: float = float(gi_d["y"]) - pz
		var dist2 := sqrt(vx2 * vx2 + vy2 * vy2)
		if dist2 < gi_dist:
			gi_dist = dist2
			gi_best = gi
	if gi_best >= 0 and held_item == Items.NONE:
		target_kind = 10
		target_obj = gi_best
		prompt = "Поднять: " + Items.display_name(int(ground_items[gi_best]["id"]))
		return
	elif gi_best >= 0:
		target_kind = 10
		target_obj = gi_best
		prompt = Items.display_name(int(ground_items[gi_best]["id"])) + " — освободи руки (G)"
		return

	var dstep := 0.3
	while dstep <= 2.1:
		var tx := px + dirx * dstep
		var ty := pz + dirz * dstep
		var ix := int(floor(tx))
		var iy := int(floor(ty))
		var t := lv.get_tile(ix, iy)
		if t == LevelData.DOOR:
			var dr = lv.door_at(ix, iy)
			target_kind = 1
			target_obj = dr
			prompt = "Закрыть дверь" if (dr != null and dr.open) else "Открыть дверь"
			return
		if t == LevelData.FRONT:
			target_kind = 5
			target_obj = lv.door_at(ix, iy)
			prompt = "Входная дверь  (" + str(count_locks()) + "/3 замка)"
			return
		if t == LevelData.HOLE:
			target_kind = 4
			var h = hatch_at(lv, ix, iy)
			if h != null:
				prompt = str(h["verb"])
			else:
				prompt = "Лестница"
			return
		if LevelData.SOLID[t]:
			break
		dstep += 0.1

	var car = null
	var car_dist := 1.0e9
	for d in lv.decos:
		if not d.is_car:
			continue
		var vx: float = d.x - px
		var vy: float = d.y - pz
		var dist := sqrt(vx * vx + vy * vy)
		if dist > 3.0 or dist < 0.01:
			continue
		var dot := (vx * dirx + vy * dirz) / dist
		if dot < 0.45:
			continue
		if not lv.line_of_sight(px, pz, d.x, d.y):
			continue
		if dist < car_dist:
			car_dist = dist
			car = d
	if car != null:
		target_kind = 7
		target_obj = car
		if car_key_installed and car_battery_installed:
			prompt = "Завести машину (E)"
		elif car_key_installed:
			prompt = "Нужен аккумулятор (в гараже на стеллаже)"
		elif car_battery_installed:
			prompt = "Нужен ключ от машины"
		elif has_item(Items.CAR_KEY) or has_item(Items.CAR_BATTERY):
			prompt = "Отремонтировать машину (удерживать E)"
		else:
			prompt = "Машина заперта. Нужны ключ и аккумулятор."
		return

	var cradle = null
	var cradle_dist := 1.0e9
	for d in lv.decos:
		if not d.is_cradle:
			continue
		var vx: float = d.x - px
		var vy: float = d.y - pz
		var dist := sqrt(vx * vx + vy * vy)
		if dist > 2.0 or dist < 0.01:
			continue
		var dot := (vx * dirx + vy * dirz) / dist
		if dot < 0.45:
			continue
		if not lv.line_of_sight(px, pz, d.x, d.y):
			continue
		if dist < cradle_dist:
			cradle_dist = dist
			cradle = d
	if cradle != null:
		target_kind = 9
		target_obj = cradle
		prompt = "Положить Тедди в колыбель" if has_item(Items.TEDDY) else "Колыбель"
		return

	if player.level == 1 and cat != null and not cat.fed:
		var cd := Vector2(px - cat.x, pz - cat.y).length()
		if cd < 1.7:
			target_kind = 6
			target_obj = cat
			prompt = "Дать Марусе молока" if has_item(Items.MILK) else "Маруся шипит на тебя"
			return

	for d in lv.decos:
		if d.kind != 0:
			continue
		if Vector2(px - d.x, pz - d.y).length() < 1.9:
			for h in lv.hides:
				if h.is_bed:
					target_kind = 3
					target_obj = h
					prompt = "Спрятаться под кроватью"
					return

func update_interaction(dt: float) -> void:
	match target_kind:
		1:
			var d = target_obj
			if e_hit:
				d.open = not d.open
				Audio.play("creak" if d.open else "door_slam", 0.55, 1.0)
				emit_noise(d.x + 0.5, d.y + 0.5, 7.5, "дверь")
				player.act_push = maxf(player.act_push, 0.8)
		2:
			var c = target_obj
			# найденный раньше предмет можно забрать пустыми руками
			if e_hit and c.searched and c.item_id != Items.NONE and held_item == Items.NONE:
				var taken := int(c.item_id)
				c.item_id = Items.NONE
				give_item(taken)
				Audio.play("pickup", 0.7, 1.0)
				player.act_push = maxf(player.act_push, 0.6)
				toast_msg("Взято: " + Items.display_name(taken), 3.0, TK_OK)
				push_subtitle(Items.hint(taken), 3.4, false)
			elif e_down and not c.searched:
				interact_prog += dt / 0.95
				interact_label = "Обыскиваю..."
				# шелест ящика по ходу обыска
				var prev_prog: float = interact_prog - dt / 0.95
				if int(interact_prog * 4.0) != int(prev_prog * 4.0):
					Audio.play("drawer", 0.30, 0.95 + rng.randf() * 0.15)
				if interact_prog >= 1.0:
					interact_prog = 0.0
					c.searched = true
					Audio.play("search", 0.6, 1.0)
					emit_noise(player_local().x, player_local().y, 3.4, "обыск")
					if c.item_id != Items.NONE:
						if held_item != Items.NONE:
							# руки заняты: показываем находку, предмет остаётся в контейнере
							toast_msg("Там лежит: " + Items.display_name(c.item_id) + ". Освободи руки (G).", 3.6, TK_HINT)
							push_subtitle(Items.hint(c.item_id), 3.4, false)
							player.act_push = maxf(player.act_push, 0.6)
						else:
							var found := int(c.item_id)
							c.item_id = Items.NONE
							give_item(found)
							Audio.play("pickup", 0.7, 1.0)
							player.act_push = maxf(player.act_push, 0.6)
							toast_msg("Взято: " + Items.display_name(found), 3.0, TK_OK)
							push_subtitle(Items.hint(found), 3.4, false)
					else:
						toast_msg("Пусто...", 1.8, TK_HINT)
			else:
				interact_prog = maxf(0.0, interact_prog - dt * 1.6)
		3:
			var h = target_obj
			if e_hit:
				enter_hide(h)
		4:
			if e_down:
				interact_prog += dt / 0.7
				interact_label = "Лезу по лестнице..."
				if interact_prog >= 1.0:
					interact_prog = 0.0
					switch_level()
			else:
				interact_prog = maxf(0.0, interact_prog - dt * 1.6)
		5:
			if diff.god_mode and e_hit:
				win_game(WIN_DOOR)
				return
			var n := count_locks()
			var hard := diff.name == "СЛОЖНО" or diff.name == "КОШМАР"
			var need4 := hard and not lock4
			if n >= 3 and not need4:
				if e_hit:
					win_game(WIN_DOOR)
			else:
				var next_lock := -1
				var need := ""
				var need_item := Items.NONE
				if n < 3:
					for i in 3:
						if not locks[i]:
							next_lock = i
							break
					need = "Ключ от замка" if next_lock == 0 else ("Монтировка" if next_lock == 1 else "Записка с кодом")
					need_item = Items.KEY if next_lock == 0 else (Items.CROWBAR if next_lock == 1 else Items.NOTE)
				else:
					next_lock = 4
					need = "Записка с кодом 2"
					need_item = Items.NOTE2
				if e_down and has_item(need_item):
					interact_prog += dt / 1.4
					interact_label = "Открываю замок..."
					if interact_prog >= 1.0:
						interact_prog = 0.0
						if next_lock == 4:
							lock4 = true
						else:
							locks[next_lock] = true
						remove_item(need_item)  # предмет уходит в замок
						Audio.play("unlock", 0.7, 1.0)
						emit_noise(player_local().x, player_local().y, 7.0, "замок")
						world.set_front_locks(count_locks())
						var total_locks := 4 if hard else 3
						toast_msg("Замок открыт! (" + str(count_locks() + (1 if lock4 else 0)) + "/" + str(total_locks) + ")", 2.6, TK_OK)
				else:
					interact_prog = maxf(0.0, interact_prog - dt * 1.5)
					if e_hit:
						toast_msg("Нужно: " + need, 2.2, TK_ERR)
		6:
			var c = target_obj
			if e_hit:
				if c.fed:
					c.purr_now(self)
				elif has_item(Items.MILK):
					remove_item(Items.MILK)
					c.feed(self)
					toast_msg("Маруся мурчит и засыпает.", 3.0, TK_OK)
				else:
					c.alert(self, "шипение")
					toast_msg("Маруся недовольна. Лучше принести ей молока.", 2.6, TK_ERR)
		7:
			var has_key := has_item(Items.CAR_KEY)
			var has_bat := has_item(Items.CAR_BATTERY)
			var ready := car_key_installed and car_battery_installed
			if ready:
				if e_hit:
					win_game(WIN_CAR)
			elif e_down and has_key and not car_key_installed:
				interact_prog += dt / 2.5
				interact_label = "Вставляю ключ в зажигание..."
				if interact_prog >= 1.0:
					interact_prog = 0.0
					remove_item(Items.CAR_KEY)
					car_key_installed = true
					Audio.play("unlock", 0.8, 0.8)
					emit_noise(player_local().x, player_local().y, 9.0, "машина")
					toast_msg("Ключ сидит в замке зажигания. Теперь аккумулятор.", 3.2, TK_OK)
			elif e_down and has_bat and not car_battery_installed:
				interact_prog += dt / 2.5
				interact_label = "Подключаю аккумулятор..."
				if interact_prog >= 1.0:
					interact_prog = 0.0
					remove_item(Items.CAR_BATTERY)
					car_battery_installed = true
					Audio.play("unlock", 0.8, 0.8)
					emit_noise(player_local().x, player_local().y, 9.0, "машина")
					toast_msg("Аккумулятор на месте. Теперь ключ зажигания.", 3.2, TK_OK)
			else:
				interact_prog = maxf(0.0, interact_prog - dt * 1.6)
				if e_hit:
					toast_msg("Сначала нужны ключ и аккумулятор.", 2.2, TK_ERR)
		8:
			if e_down:
				interact_prog += dt / 1.5
				interact_label = "Снимаю капкан..."
				if interact_prog >= 1.0:
					interact_prog = 0.0
					player.trap_stuck = 0.0
					Audio.play("unlock", 0.7, 1.0)
					emit_noise(player_local().x, player_local().y, 4.0, "капкан")
					toast_msg("Ты вырвался из капкана!", 2.0, TK_OK)
			else:
				interact_prog = maxf(0.0, interact_prog - dt * 1.5)
		9:
			if e_down and has_item(Items.TEDDY):
				interact_prog += dt / 1.5
				interact_label = "Кладу мишку в колыбель..."
				if interact_prog >= 1.0:
					interact_prog = 0.0
					remove_item(Items.TEDDY)
					Audio.play("unlock", 0.7, 1.0)
					emit_noise(player_local().x, player_local().y, 4.0, "колыбель")
					toast_msg("Ты положил Тедди в колыбель. Гренни замерла.", 3.0, TK_OK)
					if count_locks() >= 3 and car_key_installed and car_battery_installed:
						win_game(WIN_SECRET)
			else:
				interact_prog = maxf(0.0, interact_prog - dt * 1.5)
		10:
			# предмет на полу: поднять (руки уже проверены на пустоту)
			if e_hit:
				take_ground_item(int(target_obj))
	if target_kind != 2 and target_kind != 4 and target_kind != 5 and target_kind != 7 and target_kind != 8 and target_kind != 9 and target_kind != 10:
		interact_prog = maxf(0.0, interact_prog - dt * 3.0)

func enter_hide(h) -> void:
	player.enter_hide(h)
	Audio.play("creak", 0.45, 1.15)
	var pl := player_local()
	emit_noise(pl.x, pl.y, 2.2, "шкаф")
	if granny.level == player.level and granny.saw_player:
		granny.state = GrannyAI.CHASE
		granny.target_x = h.x
		granny.target_y = h.y
		granny.say(self, "Я видела, куда ты залез, заинька!", 2.0)
	toast_msg("Сиди тихо. Не двигайся.", 2.6, TK_HINT)

func exit_hide() -> void:
	player.exit_hide()
	Audio.play("creak", 0.45, 0.9)
	var pl := player_local()
	emit_noise(pl.x, pl.y, 2.4, "шкаф")

# Люк (лестница) на тайле: данные фиксированного плана.
func hatch_at(lv: LevelData, x: int, y: int) -> Dictionary:
	for h in lv.hatches:
		if int(h["x"]) == x and int(h["y"]) == y:
			return h
	return {}

func switch_level() -> void:
	var lv: LevelData = world.levels[player.level]
	var pl := player_local()
	var h := hatch_at(lv, int(floor(pl.x)), int(floor(pl.y)))
	if h.is_empty():
		# страховка: ищем ближайший люк в радиусе 1 плитки
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if h.is_empty():
					h = hatch_at(lv, int(floor(pl.x)) + dx, int(floor(pl.y)) + dy)
	if h.is_empty():
		return
	var to := int(h["to"])
	player.place_at(to, float(h["tx"]), float(h["ty"]), float(h["ta"]))
	Audio.play("stairs", 0.6, 0.9 + rng.randf() * 0.15)
	emit_noise(float(h["x"]) + 0.5, float(h["y"]) + 0.5, 6.0, str(h["noise"]))
	if h.has("subtitle") and str(h["subtitle"]) != "":
		push_subtitle(str(h["subtitle"]), 3.2, false)
	if to == 1 and not cat.fed and not cat.angry:
		cat.alert(self, "мяу")
	if to == 3:
		Audio.play("spider_hiss", 0.45, 0.85)
	player.pitch = 0.0
	interact_prog = 0.0
	shake = 0.15
	climb_fx = 1.0
	player.act_push = 0.6
	player.apply_camera()

func update_traps(dt: float) -> void:
	if player.trap_stuck > 0.0:
		return
	var lv: LevelData = world.levels[player.level]
	var pl := player_local()
	var t = lv.trap_near(pl.x, pl.y, 0.20)
	if t != null and t.armed:
		t.armed = false
		t.triggered_t = time
		player.trap_stuck = 2.6
		player.trap_mash = 0.0
		player.health = maxf(0.05, player.health - 0.28)
		Audio.play3d("snap", world.get_root(player.level), Vector3(pl.x, 0.3, pl.y), 0.95, 1.0, 8.0)
		Audio.play("scream", 0.25, 1.9)
		shake = maxf(shake, 1.2)
		emit_noise(pl.x, pl.y, 13.0, "капкан")
		toast_msg("КАТКАН! Жми ПРОБЕЛ, чтобы вырваться!", 3.0, TK_ERR)
		if t.node != null:
			t.node.set_armed(false)

func update_spiders(dt: float) -> void:
	for i in world.spider_nodes.size():
		var n: Node3D = world.spider_nodes[i]
		n.rotation.y = sin(time * 0.7 + i * 2.0) * 0.3
		n.position.y = 0.04 + absf(sin(time * 2.4 + i)) * 0.03
	if diff.god_mode or player.level != 3:
		return
	var pl := player_local()
	var pts: Array[Vector2] = world.levels[3].spiders
	for i in pts.size():
		var s: Vector2 = pts[i]
		var dx := pl.x - s.x
		var dy := pl.y - s.y
		if dx * dx + dy * dy > 0.55 * 0.55:
			continue
		if time - spider_bite_t <= 1.2:
			continue
		spider_bite_t = time
		player.health = maxf(0.05, player.health - 0.22)
		shake = maxf(shake, 0.55)
		Audio.play3d("spider_hiss", world.get_root(player.level), Vector3(s.x, 0.3, s.y), 0.6, 0.9 + rng.randf() * 0.25, 6.0)
		emit_noise(pl.x, pl.y, 5.0, "паук")
		toast_msg("Паук цапнул за щиколотку! Оно может спуститься.", 2.4, TK_ERR)
	var _unused := dt

func throw_bottle() -> void:
	if player.hidden or player.dead:
		return
	if held_item != Items.BOTTLE:
		toast_msg("Нужна бутылка в руках.", 1.6, TK_ERR)
		return
	held_item = Items.NONE
	player.set_held(0)
	var pl := player_local()
	var dirx := cos(player.angle)
	var diry := sin(player.angle)
	var b := ThrownBottle.new()
	throwns.append(b)
	b.setup(self, player.level, pl.x + dirx * 0.45, pl.y + diry * 0.45, 1.23, dirx * 8.2, diry * 8.2, 2.6)
	player.act_throw = 1.0
	Audio.play("step", 0.35, 1.7)
	emit_noise(pl.x, pl.y, 2.0, "бросок")

func break_bottle(b: ThrownBottle) -> void:
	if b.broken:
		return
	b.broken = true
	Audio.play3d("break", world.get_root(b.level), Vector3(b.x, 0.9, b.y), 0.9, 1.0, 9.0)
	emit_noise(b.x, b.y, 15.0, "стекло")
	if granny.level == player.level and granny.state != GrannyAI.CHASE:
		granny.attract(b.x, b.y)
	b.queue_free()

func _update_thrown(dt: float) -> void:
	var i := throwns.size() - 1
	while i >= 0:
		var b := throwns[i]
		if not is_instance_valid(b) or b.broken:
			throwns.remove_at(i)
		else:
			b.update(dt, self)
			if b.broken:
				throwns.remove_at(i)
		i -= 1

func fire_crossbow() -> void:
	if player.hidden or player.dead:
		return
	if not has_item(Items.CROSSBOW):
		toast_msg("Нужен арбалет в руках.", 1.6, TK_ERR)
		return
	if player.reload_t > 0.0:
		return
	if dart_ammo <= 0:
		toast_msg("Нет стрел. Найди и подними (руки должны держать арбалет).", 2.2, TK_ERR)
		return
	dart_ammo -= 1
	player.gun_t = 1.0
	player.reload_t = 1.1
	Audio.play("crossbow_shot", 0.9, 1.0)
	shake = maxf(shake, 0.3)
	var pl := player_local()
	emit_noise(pl.x, pl.y, 5.0, "арбалет")
	var lv: LevelData = world.levels[player.level]
	var dirx := cos(player.angle)
	var diry := sin(player.angle)
	var wall_dist := 12.0
	var d := 0.2
	while d <= 12.0:
		if lv.solid_at(pl.x + dirx * d, pl.y + diry * d):
			wall_dist = d
			break
		d += 0.06
	var hit := false
	if granny.level == player.level:
		var vx := granny.x - pl.x
		var vy := granny.y - pl.y
		var proj := vx * dirx + vy * diry
		if proj > 0.0 and proj < wall_dist:
			var hx := pl.x + dirx * proj
			var hy := pl.y + diry * proj
			if Vector2(hx - granny.x, hy - granny.y).length() < 0.42:
				hit = true
	if hit:
		granny.hit_by_dart(self)
		Audio.play("dart_hit", 0.8, 1.0)
		hit_flash = 1.0
		_spawn_blood(player.level, granny.x + rng.randf_range(-0.15, 0.15), granny.y + rng.randf_range(-0.15, 0.15), 0.55)
		push_subtitle("Тхэк! Гренни повалилась на пол.", 1.8, false)

func _spawn_blood(level: int, x: float, y: float, size: float) -> void:
	var root: Node3D = world.get_root(level)
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.01, 0.01, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(x, 0.025, y)
	mi.rotation.x = -PI * 0.5
	mi.rotation.z = rng.randf() * TAU
	root.add_child(mi)
	bloods.append(mi)
	if bloods.size() > 8:
		var old: Node3D = bloods.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func on_caught() -> void:
	if diff.god_mode:
		return
	if state != STATE_PLAY:
		return
	_set_state(STATE_CAUGHT)
	caught_t = 0.0
	player.dead = true
	deaths += 1
	drop_held(true)  # выронил всё при поимке — предмет остаётся лежать
	shake = 1.5
	Audio.play3d("scream", world.get_root(player.level), Vector3(granny.x, 1.5, granny.y), 1.0, 0.95, 12.0)
	Audio.play("snap", 0.6, 0.7)
	granny.say(self, "ПОПАЛСЯ, СОЛНЫШКО!", 2.0)
	var pl := player_local()
	_spawn_blood(player.level, pl.x + rng.randf_range(-0.12, 0.12), pl.y + rng.randf_range(-0.12, 0.12), 0.95)

func on_caught_in_hide() -> void:
	if state != STATE_PLAY:
		return
	player.hidden = false
	player.hide_spot = null
	var pl := player_local()
	granny.x = pl.x + cos(player.angle) * 0.7
	granny.y = pl.y + sin(player.angle) * 0.7
	granny.angle = player.angle + PI
	on_caught()
	granny.say(self, "Я знала, что ты там!", 2.0)

func win_game(kind: int) -> void:
	if state != STATE_PLAY:
		return
	_set_state(STATE_WIN)
	win_t = 0.0
	last_win = kind
	Audio.play("win", 0.9, 1.0)
	if kind == WIN_CAR:
		var car_lv: LevelData = world.levels[2]
		for d in car_lv.decos:
			if d.is_car:
				Audio.play3d("car_start", world.get_root(2), Vector3(d.x, 0.8, d.y), 0.9, 1.0, 11.0)
				break
		world.set_garage_open(true)
	if kind == WIN_SECRET:
		Audio.play("win", 1.2, 1.3)
	for e in world.door_entries:
		var d: LevelData.Door = e.door
		if d.front:
			d.open = true
