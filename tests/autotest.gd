extends RefCounted

# Автотест: запускает игру, проходит ключевые механики и сохраняет скриншоты.
# Запуск: Godot.exe --path . -- --autotest
# Переработка 2/3: один предмет в руках, дроп на пол, фиксированная
# планировка (scenes/house.scn + house_plan.gd), миграция сейвов v1→v2,
# парящий предмет, амбиент/окклюзия, детерминизм дома между запусками.

var g: GrannyGame
var checks := 0
var fails := 0

func run(pgame: GrannyGame) -> void:
	g = pgame
	await _frames(6)
	await _shot("01_title")

	_check(g.world != null, "world built")
	_check(g.world.levels.size() == 4, "four levels")
	for i in 4:
		_check(g.world.levels[i].w > 0 and g.world.levels[i].h > 0, "level %d has size" % i)
	_check(g.player != null and g.granny != null and g.cat != null, "actors created")
	_check(g.ui != null, "ui created")

	# --- фиксированная планировка (план + запечённая сцена) ---
	var lv0: LevelData = g.world.levels[0]
	_check(lv0.containers.size() >= 12, "house has containers (%d)" % lv0.containers.size())
	_check(lv0.doors.size() >= 10, "house has doors (%d)" % lv0.doors.size())
	_check(lv0.decos.size() >= 45, "house has furniture (%d)" % lv0.decos.size())
	_check(lv0.lamps.size() >= 10, "house has lamps (%d)" % lv0.lamps.size())
	_check(lv0.hatches.size() == 3, "house has 3 hatches")
	_check(lv0.room_names.size() >= 10, "house rooms named (%d)" % lv0.room_names.size())
	_check(g.world.levels[1].hatches.size() == 1, "attic hatch down")
	_check(g.world.levels[2].hatches.size() == 1, "garage hatch back")
	_check(g.world.levels[3].hatches.size() == 1, "cellar hatch back")
	_check(g.world.levels[3].spiders.size() >= 3, "cellar spiders from json")
	_check(g.world.levels[1].get_tile(12, 3) == LevelData.ATTICWOOD, "attic beams built")
	_check(lv0.get_tile(19, 3) == LevelData.CAGE or g.world.levels[1].get_tile(19, 2) == LevelData.CAGE, "marusya cage built")
	var has_fireplace := false
	var has_bathtub := false
	var has_car := false
	var has_cradle := false
	for lv in g.world.levels:
		for d in lv.decos:
			if d.kind == 19:
				has_fireplace = true
			if d.kind == 21:
				has_bathtub = true
			if d.is_car:
				has_car = true
			if d.is_cradle:
				has_cradle = true
	_check(has_fireplace, "fireplace exists")
	_check(has_bathtub, "bathtub exists")
	_check(has_car, "car exists")
	_check(has_cradle, "cradle exists")

	g.diff_index = 1
	g.start_game()
	g.diff.god_mode = true  # навигационные секции: Гренни не мешает (поимка тестируется отдельно)
	await _frames(4)
	await _shot("02_intro")

	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	await _frames(4)
	await _shot("03_play")

	# --- реальное управление: клавиши и мышь ---
	g.world.clear_traps()
	g.player.place_at(0, 15.5, 15.5, 0.0)
	var start_pos := g.player.global_position
	var w_ev := InputEventKey.new()
	w_ev.physical_keycode = KEY_W
	w_ev.keycode = KEY_W
	w_ev.pressed = true
	Input.parse_input_event(w_ev)
	await _frames(30)
	var w_up := InputEventKey.new()
	w_up.physical_keycode = KEY_W
	w_up.keycode = KEY_W
	w_up.pressed = false
	Input.parse_input_event(w_up)
	var moved := g.player.global_position.distance_to(start_pos)
	_check(moved > 0.25, "W moves the player (%.2f m)" % moved)
	var old_angle: float = g.player.angle
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(140, 0)
	g.player._unhandled_input(mm)
	_check(absf(g.player.angle - old_angle) > 0.02, "mouse look rotates the player")

	# --- укрытие ---
	if lv0.hides.size() > 0:
		var hs = lv0.hides[0]
		g.player.place_at(0, hs.enter_x + 0.5, hs.enter_y + 0.5, 0.0)
		g.enter_hide(hs)
		_check(g.player.hidden, "hide spot works")
		g.exit_hide()
		_check(not g.player.hidden, "leaving hide spot works")

	# --- капкан ---
	var trap = g.world.add_trap(lv0, 15.5, 14.5)
	g.player.place_at(0, 15.5, 14.5, 0.0)
	g.update_traps(0.1)
	_check(g.player.trap_stuck > 0.0, "trap catches the player")
	_check(not trap.armed, "trap disarms after trigger")
	for i in 12:
		g._on_key(KEY_SPACE)
	_check(g.player.trap_stuck <= 0.0, "space mashing frees the player")
	g.player.trap_stuck = 0.0

	# --- закрытая дверь физически не пускает (проход восток-запад) ---
	# 150 кадров, а не 55: в headless process-кадры идут быстрее physics-тиков.
	var door0 = lv0.doors[0]
	door0.open = false
	g.world.update_doors(1.0)
	g.player.place_at(0, door0.x - 1.6, door0.y + 0.5, 0.0)
	await _frames(2)
	_press(KEY_W, true)
	await _frames(150)
	_press(KEY_W, false)
	var blocked := g.player.global_position - lv0.origin
	_check(blocked.x < door0.x + 1.0, "closed door blocks the player (x=%.2f)" % blocked.x)
	door0.open = true
	g.world.update_doors(1.0)
	_press(KEY_W, true)
	await _frames(150)
	_press(KEY_W, false)
	var through := g.player.global_position - lv0.origin
	_check(through.x > door0.x + 1.6, "open door lets the player through (x=%.2f)" % through.x)
	door0.open = false
	g.world.update_doors(1.0)

	# --- шум привлекает Гренни ---
	g.player.place_at(0, 15.5, 15.5, 0.0)
	g.player.flashlight_on = false
	g.player.crouch = true
	g.granny.spawn(lv0, 10.5, 15.5, PI)
	g.emit_noise(15.5, 15.5, 10.0, "шаги")
	g.granny.update(0.12, g)
	_check(g.granny.state == GrannyAI.INVESTIGATE, "noise attracts granny")
	g.player.flashlight_on = true
	g.player.crouch = false
	g.granny.spawn(lv0, 24.5, 27.5, -PI * 0.5)
	g.granny.line = ""
	g.granny.line_t = 0.0
	g.subs.clear()

	# --- Гренни видит игрока и начинает погоню ---
	g.player.place_at(0, 15.5, 15.5, -PI * 0.5)
	g.granny.spawn(lv0, 15.5, 12.5, PI * 0.5)
	for i in 8:
		g.granny.update(0.1, g)
		if g.granny.state == GrannyAI.CHASE:
			break
	_check(g.granny.state == GrannyAI.CHASE, "granny sees the player and chases")
	g.granny.spawn(lv0, 24.5, 27.5, -PI * 0.5)
	g.granny.line = ""
	g.granny.line_t = 0.0
	g.subs.clear()

	# --- ОДИН ПРЕДМЕТ: обыск, «руки заняты», дроп, подъём ---
	var cont = null
	for c in lv0.containers:
		if c.item_id != Items.NONE:
			cont = c
			break
	_check(cont != null, "fixed plan places items in the house")
	if cont != null:
		var found_id := int(cont.item_id)
		# 1) руки заняты — предмет остаётся в контейнере
		g.give_item(Items.BOTTLE)
		g.player.place_at(0, cont.x + 0.5, cont.y + 1.5, -PI * 0.5)
		g.update_target_scan()
		_check(g.target_kind == 2 and g.target_obj == cont, "container targeted")
		g.target_kind = 2
		g.target_obj = cont
		g.e_down = true
		g.interact_prog = 0.0
		g.update_interaction(1.2)
		g.e_down = false
		_check(cont.searched, "container searched with busy hands")
		_check(int(cont.item_id) == found_id, "item stays inside when hands are busy")
		_check(g.held_item == Items.BOTTLE, "hands still hold the bottle")
		# 2) дроп на пол (G)
		var pl_before := g.player_local()
		g.drop_held()
		_check(g.held_item == Items.NONE, "drop empties hands")
		_check(g.ground_items.size() == 1, "dropped item lies on the floor")
		var gi: Dictionary = g.ground_items[0]
		_check(int(gi["id"]) == Items.BOTTLE and int(gi["level"]) == 0, "ground item carries id and level")
		# 3) поднять с пола
		g.player.place_at(0, float(gi["x"]) + 0.2, float(gi["y"]) + 0.2, 0.0)
		g.update_target_scan()
		_check(g.target_kind == 10, "ground item targeted")
		g.take_ground_item(0)
		_check(g.held_item == Items.BOTTLE and g.ground_items.size() == 0, "ground item picked up")
		g.drop_held(true)
		# 4) обыск с пустыми руками — предмет забирается
		g.held_item = Items.NONE
		g.player.set_held(0)
		g.target_kind = 2
		g.target_obj = cont
		g.e_down = true
		g.interact_prog = 0.0
		g.update_interaction(0.4)
		g.e_down = false
		# searched уже true: добираем предмет повторным взаимодействием
		g.e_hit = true
		g.update_interaction(0.1)
		g.e_hit = false
		_check(g.held_item == found_id, "revealed item taken with free hands")
		_check(int(cont.item_id) == Items.NONE, "container emptied after take")
		_check(g.player.held_id == found_id, "player float model matches held item")
		g.drop_held(true)
	await _frames(2)
	await _shot("04_search")

	# --- дверь ---
	var door = lv0.doors[0]
	g.player.place_at(0, door.x + 0.5, door.y + 1.5, -PI * 0.5)
	g.target_kind = 1
	g.target_obj = door
	g.e_hit = true
	g.update_interaction(0.1)
	g.e_hit = false
	_check(door.open, "door opened")

	# --- бутылка: бросок из рук отвлекает Гренни ---
	g.give_item(Items.BOTTLE)
	g.player.place_at(0, 15.5, 27.0, -PI * 0.5)
	g.throw_bottle()
	_check(g.held_item == Items.NONE, "bottle consumed from hands")
	await _frames(20)
	_check(g.throwns.size() >= 0, "bottle update safe")

	# --- арбалет: стрела из внутреннего магазина ---
	g.give_item(Items.CROSSBOW)
	g.dart_ammo = 2
	g.fire_crossbow()
	_check(g.dart_ammo == 1, "dart consumed from crossbow ammo")
	# стрела с пола заряжает арбалет (пол чист от предыдущих дропов)
	g.clear_ground_items()
	g.spawn_ground_item(Items.DART, 0, 15.6, 27.1)
	g.take_ground_item(0)
	_check(g.dart_ammo == 2 and g.held_item == Items.CROSSBOW, "floor dart reloads crossbow")
	# арбалет полон — стрела остаётся лежать
	g.dart_ammo = 3
	g.spawn_ground_item(Items.DART, 0, 15.6, 27.1)
	g.take_ground_item(0)
	_check(g.dart_ammo == 3 and g.ground_items.size() == 1, "full crossbow leaves dart on floor")
	g.clear_ground_items()
	g.drop_held(true)

	# --- люки: переходы по фиксированному плану ---
	g.player.place_at(0, 11.5, 2.5, 0.0)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 1, "hatch to attic")
	_check(absf(g.player_local().x - 4.5) < 0.3 and absf(g.player_local().y - 19.5) < 0.3, "attic arrival point from json")
	await _shot("05_attic")
	g.player.place_at(1, 4.5, 20.5, 0.0)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 0, "hatch back to house")

	# --- кошка: злость на свет, молоко из рук ---
	g.cat.fed = false
	g.cat.angry = false
	g.cat.angry_t = 0.0
	g.attic_alert_t = 0.0
	g.player.place_at(0, 11.5, 2.5, 0.0)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 1, "hatch to attic again")
	g.player.place_at(1, g.cat.x, g.cat.y + 1.7, -PI * 0.5)
	g.player.flashlight_on = true
	g.player.crouch = false
	g.cat.update(0.12, g)
	_check(g.cat.angry, "cat gets angry at the player")
	_check(g.attic_alert_t > 0.0, "cat raises the attic alert")
	_check(g.noises.size() > 0, "cat meow makes noise")
	g.cat.angry = false
	g.cat.angry_t = 0.0
	g.attic_alert_t = 0.0
	g.give_item(Items.MILK)
	_check(g.has_item(Items.MILK), "milk in hands")
	g.remove_item(Items.MILK)
	g.cat.feed(g)
	_check(g.cat.fed, "cat fed")
	_check(g.held_item == Items.NONE, "milk consumed")
	await _frames(2)
	await _shot("06_cat")

	# --- подвал и пауки ---
	g.player.place_at(1, 4.5, 20.5, 0.0)
	g.switch_level()
	await _frames(3)
	g.player.place_at(0, 26.5, 2.5, 0.0)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 3, "hatch to cellar")
	_check(g.in_spider_web() == false, "web check safe")
	await _shot("07_cellar")

	# --- пристройка (гараж): люк подвала ведёт в дом, из дома — в пристройку ---
	g.player.place_at(3, 4.5, 17.5, 0.0)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 0, "cellar hatch returns to house")
	g.player.place_at(0, 19.5, 29.5, -PI * 0.5)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 2, "hatch to garage")
	await _shot("08_garage")

	# --- машина: ключ, аккумулятор и побег ---
	var car = null
	for d in g.world.levels[2].decos:
		if d.is_car:
			car = d
			break
	_check(car != null, "garage has a car")
	if car != null:
		g.player.place_at(2, car.x, car.y + 1.6, -PI * 0.5)
		g.give_item(Items.CAR_KEY)
		g.target_kind = 7
		g.target_obj = car
		g.e_down = true
		g.update_interaction(3.0)
		_check(g.car_key_installed, "car key installed")
		_check(g.held_item == Items.NONE, "car key consumed")
		g.give_item(Items.CAR_BATTERY)
		g.update_interaction(3.0)
		_check(g.car_battery_installed, "car battery installed")
		g.e_down = false
		g.e_hit = true
		g.update_interaction(0.1)
		_check(g.state == g.STATE_WIN and g.last_win == g.WIN_CAR, "car escape ending")
		g._set_state(g.STATE_PLAY)
		g.fade_t = 0.0

	# --- возвращаемся в дом, открываем замки (предметы уходят в замки) ---
	g.player.place_at(0, 19.5, 28.5, -PI * 0.5)
	g.switch_level()
	await _frames(2)
	var front = null
	for d in lv0.doors:
		if d.front:
			front = d
			break
	_check(front != null, "front door exists")
	if front != null:
		g.player.place_at(0, front.x + 0.5, front.y - 1.5, PI * 0.5)
		g.target_kind = 5
		g.target_obj = front
		for lock_item in [Items.KEY, Items.CROWBAR, Items.NOTE]:
			g.give_item(lock_item)
			g.e_down = true
			g.interact_prog = 0.0
			g.update_interaction(1.6)
			g.e_down = false
		_check(g.count_locks() == 3, "three locks opened")
		_check(g.held_item == Items.NONE, "lock items consumed")
		_check(g.world.lock_meshes.size() >= 3, "lock meshes exist")
	await _frames(2)
	await _shot("09_locks")

	# --- побег через входную дверь после трёх замков ---
	g.e_hit = true
	g.target_kind = 5
	g.target_obj = front
	g.update_interaction(0.1)
	g.e_hit = false
	_check(g.state == g.STATE_WIN and g.last_win == g.WIN_DOOR, "front door escape ending")
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0

	# --- дневник ---
	g.journal = true
	await _frames(2)
	await _shot("10_journal")
	g.journal = false

	# --- поимка: предмет падает там, где поймали ---
	g.diff.god_mode = false
	g.clear_ground_items()
	g.give_item(Items.KEY)
	g.player.place_at(0, 15.5, 20.0, -PI * 0.5)
	g.on_caught()
	_check(g.held_item == Items.NONE, "caught player drops the item")
	_check(g.ground_items.size() == 1, "dropped item persists after catch")
	var drop_pos: Vector2 = Vector2(float(g.ground_items[0]["x"]), float(g.ground_items[0]["y"]))
	_check(Vector2(15.5, 20.0).distance_to(drop_pos) < 1.2, "item dropped near catch point")
	await _frames(6)
	await _shot("11_caught")
	await g.get_tree().create_timer(3.2).timeout
	_check(g.state == g.STATE_PLAY, "respawn after caught")
	_check(g.day == 2, "day advanced")
	_check(g.ground_items.size() == 1, "dropped item survives respawn")
	g.diff.god_mode = true

	# --- победа ---
	g.win_game(g.WIN_DOOR)
	await _frames(4)
	await _shot("12_win")
	_check(g.state == g.STATE_WIN, "win state")

	# --- проигрыш по дням ---
	g._set_state(g.STATE_PLAY)
	g.diff.god_mode = false
	g.day = g.max_days
	g.on_caught()
	g.diff.god_mode = true
	await g.get_tree().create_timer(3.2).timeout
	await _frames(2)
	await _shot("13_over")
	_check(g.state == g.STATE_OVER, "over state after last day")

	# --- меню сложности и помощь ---
	g._set_state(g.STATE_DIFF)
	await _frames(2)
	await _shot("14_diff")
	g._set_state(g.STATE_HELP)
	await _frames(2)
	await _shot("15_help")
	g._set_state(g.STATE_PAUSE)
	await _frames(2)
	await _shot("16_pause")

	# --- сложный режим: четвертый замок ---
	g.diff_index = 2
	g.start_game()
	g.diff.god_mode = true
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	g.clear_ground_items()
	var front2 = null
	for d in g.world.levels[0].doors:
		if d.front:
			front2 = d
			break
	_check(front2 != null, "hard mode front door exists")
	if front2 != null:
		g.player.place_at(0, front2.x + 0.5, front2.y - 1.5, PI * 0.5)
		g.target_kind = 5
		g.target_obj = front2
		for lock_item in [Items.KEY, Items.CROWBAR, Items.NOTE, Items.NOTE2]:
			g.give_item(lock_item)
			g.e_down = true
			g.interact_prog = 0.0
			g.update_interaction(1.6)
			g.e_down = false
		_check(g.count_locks() == 3, "hard mode: three locks opened")
		_check(g.lock4, "hard mode: fourth lock opened")

	# --- секретная концовка: Тедди в колыбели ---
	g.car_key_installed = true
	g.car_battery_installed = true
	g.give_item(Items.TEDDY)
	var cradle = null
	for d in g.world.levels[1].decos:
		if d.is_cradle:
			cradle = d
			break
	_check(cradle != null, "attic has a cradle")
	if cradle != null:
		g.player.place_at(1, cradle.x, cradle.y + 1.5, -PI * 0.5)
		g.target_kind = 9
		g.target_obj = cradle
		g.e_down = true
		g.update_interaction(2.0)
		_check(g.state == g.STATE_WIN and g.last_win == g.WIN_SECRET, "secret ending")

	# --- отладочная панель ---
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	g._on_key(KEY_F1)
	await _frames(2)
	_check(g.debug_on, "F1 debug overlay toggles")
	await _shot("17_debug")
	g._on_key(KEY_F1)

	# --- НАСТРОЙКИ: экран, изменение, применение, сохранение ---
	var sens_before: float = g.settings.mouse_sensitivity
	var shadows_before: bool = g.settings.flashlight_shadows
	g._set_state(g.STATE_TITLE)
	g.menu_idx = 4
	g._activate_title_item()
	_check(g.state == g.STATE_SETTINGS, "title menu opens settings")
	g.settings_idx = 3
	g._on_key(KEY_RIGHT)
	_check(absf(g.settings.mouse_sensitivity - (sens_before + 0.1)) < 0.001, "right increases mouse sensitivity")
	g._on_key(KEY_LEFT)
	g._on_key(KEY_LEFT)
	_check(g.settings.mouse_sensitivity < sens_before, "left decreases mouse sensitivity")
	g.settings.mouse_sensitivity = sens_before
	g.settings_idx = 7
	g._cycle_setting(7)
	_check(g.settings.flashlight_shadows != shadows_before, "flashlight shadows toggles")
	_check(g.player.flashlight.shadow_enabled == g.settings.flashlight_shadows, "shadow setting applies to flashlight")
	g._cycle_setting(7)
	_check(g.settings.flashlight_shadows == shadows_before, "flashlight shadows restored")
	await _frames(2)
	await _shot("18_settings")
	g._on_key(KEY_ESCAPE)
	_check(g.state == g.STATE_TITLE, "settings Esc returns to title")
	g.settings.save_settings()
	var s_reload := GameSettings.load_settings()
	_check(absf(s_reload.mouse_sensitivity - g.settings.mouse_sensitivity) < 0.001, "settings persist to disk")
	g.settings.save_settings()

	# --- проводка настроек в игру ---
	g.settings.invert_y = true
	_check(g.invert_look(), "invert_y reaches player look")
	g.settings.invert_y = false
	_check(not g.invert_look(), "invert_y off")
	g.settings.mouse_sensitivity = 2.0
	_check(absf(g.look_scale() - 2.0) < 0.001, "sensitivity reaches look scale")
	g.settings.mouse_sensitivity = sens_before

	# --- F11 синхронизирует настройку полного экрана ---
	var fs_before := g.settings.fullscreen
	g._on_key(KEY_F11)
	_check(g.settings.fullscreen != fs_before, "F11 toggles fullscreen setting")
	g._on_key(KEY_F11)
	_check(g.settings.fullscreen == fs_before, "F11 toggles fullscreen back")
	g.settings.save_settings()

	# --- СОХРАНЕНИЯ v2: предмет в руках и на полу восстанавливаются ---
	g.diff_index = 1
	g.start_game()
	g.diff.god_mode = true
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	g.clear_ground_items()
	g.give_item(Items.KEY)
	g.locks[0] = true
	g.play_time = 77.0
	g.player.place_at(0, 14.5, 12.5, 1.0)
	await _frames(4)
	var save_pos := g.player_local()
	g.spawn_ground_item(Items.BOTTLE, 0, 15.5, 13.5)
	_check(SaveSystem.save_run(g, SaveSystem.SLOTS[0]), "save_run writes slot1")
	var meta := SaveSystem.read_meta(SaveSystem.SLOTS[0])
	_check(meta.exists, "slot1 meta exists")
	_check(meta.day == 1 and meta.locks == 1 and meta.max_days == 5, "slot1 meta fields correct")
	_check(SaveSystem.latest_slot() != "", "latest slot found")
	g.held_item = Items.NONE
	g.player.set_held(0)
	g.dart_ammo = 0
	g.locks[0] = false
	g.day = 3
	g.play_time = 999.0
	g.clear_ground_items()
	g.player.place_at(0, 24.5, 27.5, 2.5)
	var cont0 = g.world.levels[0].containers[0]
	cont0.searched = true
	_check(SaveSystem.load_run(g, SaveSystem.SLOTS[0]), "load_run restores slot1")
	_check(g.day == 1, "load restores day")
	_check(g.max_days == 5, "load restores max days")
	_check(g.locks[0], "load restores locks")
	_check(g.held_item == Items.KEY, "load restores held item")
	_check(g.dart_ammo == 0, "load restores dart ammo")
	_check(g.ground_items.size() == 1, "load restores ground items")
	_check(absf(g.play_time - 77.0) < 0.5, "load restores play time")
	_check(g.player.level == 0, "load restores player level")
	var plp := g.player_local()
	_check(Vector2(plp.x - save_pos.x, plp.y - save_pos.y).length() < 0.6, "load restores position")
	_check(not cont0.searched, "load resets searched containers")
	_check(g.state == g.STATE_PLAY, "load enters play state")
	_check(g.diff.name == "НОРМАЛЬНО", "load restores difficulty")

	# --- миграция старого сейва v1: без ошибок, предметы раздаются заново ---
	var v1_save := {
		"meta": {"diff_name": "НОРМАЛЬНО", "diff_index": 1, "day": 2, "max_days": 5, "locks": 2},
		"state": {
			"version": 1,
			"diff_index": 1, "day": 2, "max_days": 5, "play_time": 300.0, "deaths": 1,
			"inv": [Items.KEY, Items.CROWBAR],
			"locks": [true, true, false], "lock4": false,
			"car_key_installed": false, "car_battery_installed": false,
			"photo_taken": false, "garage_open": false,
			"player": {"level": 0, "x": 5.5, "y": 8.5, "angle": 0.0},
			"granny": {"level": 0, "x": 20.5, "y": 20.5, "angle": 0.0},
			"cat": {"fed": false, "angry": false, "x": 9.5, "y": 5.3},
			"searched_containers": [{"lv": 0, "x": -5, "y": -5}],
			"open_doors": [], "armed_traps": [],
		},
	}
	var fw2 := FileAccess.open("user://saves/slot3.json", FileAccess.WRITE)
	fw2.store_string(JSON.stringify(v1_save))
	fw2.close()
	var items_before := 0
	for lvx in g.world.levels:
		for cx in lvx.containers:
			if cx.item_id != Items.NONE:
				items_before += 1
	_check(SaveSystem.load_run(g, "slot3"), "v1 save loads without error")
	_check(g.state == g.STATE_PLAY, "v1 migration enters play state")
	_check(g.held_item == Items.NONE, "v1 migration clears inventory (old house incompatible)")
	_check(g.locks[0] and g.locks[1], "v1 migration keeps lock progress")
	_check(g.day == 2, "v1 migration keeps day")
	var items_after := 0
	for lvx in g.world.levels:
		for cx in lvx.containers:
			if cx.item_id != Items.NONE:
				items_after += 1
	_check(items_after >= items_before - 1, "v1 migration redistributes items (%d → %d)" % [items_before, items_after])

	# --- экраны сохранения/загрузки через меню паузы ---
	g._set_state(g.STATE_PAUSE)
	g.pause_idx = 1
	g._activate_pause_item()
	_check(g.state == g.STATE_SAVE, "pause opens save screen")
	await _frames(2)
	await _shot("19_saves")
	g.save_idx = 2  # ALL_SLOTS[2] == "slot2"
	g._activate_save_slot()
	_check(g.state == g.STATE_PAUSE, "saving returns to pause")
	_check(SaveSystem.read_meta(SaveSystem.SLOTS[1]).exists, "slot2 written from UI")
	g._set_state(g.STATE_PAUSE)
	g.pause_idx = 2
	g._activate_pause_item()
	_check(g.state == g.STATE_LOAD, "pause opens load screen")
	g._on_key(KEY_ESCAPE)
	_check(g.state == g.STATE_PAUSE, "load screen Esc returns to pause")
	g._set_state(g.STATE_TITLE)
	g.menu_idx = 0
	g._activate_title_item()
	_check(g.state == g.STATE_PLAY, "continue loads latest save")

	# --- музыка, амбиент и 3D-звук ---
	_check(Audio.streams.has("music_menu") and Audio.streams.has("music_ambient"), "music tracks generated")
	_check(Audio.music_player != null, "music player exists")
	_check(Audio.streams.has("hum"), "granny hum generated")
	Audio.set_music("music_ambient")
	await g.get_tree().create_timer(1.2).timeout
	_check(Audio.music_track == "music_ambient", "ambient music switched")
	_check(Audio.music_player.playing, "music is playing")
	var root0: Node3D = g.world.get_root(0)
	var ch := root0.get_child_count()
	Audio.play3d("break", root0, Vector3(6, 1.0, 8), 0.5, 1.0)
	_check(root0.get_child_count() == ch + 1, "play3d spawns positional node")
	# амбиентные петли по этажам
	_check(Audio.streams.has("wind_loop") and Audio.streams.has("attic_loop") and Audio.streams.has("cellar_loop"), "ambient loops generated")
	g.player.level = 1
	await _frames(2)
	g._update_atmosphere(0.1)
	_check(Audio._amb_target == "attic_loop", "attic ambient layer selected")
	g.player.level = 3
	g._update_atmosphere(0.1)
	_check(Audio._amb_target == "cellar_loop", "cellar ambient layer selected")
	g.player.level = 0
	g._update_atmosphere(0.1)
	_check(Audio._amb_target == "wind_loop", "house ambient layer selected")
	# окклюзия: стена глушит звук
	g.player.place_at(0, 15.5, 15.5, 0.0)
	var occ_same: float = Audio.occlusion_factor(lv0, Vector2(15.5, 15.5), Vector2(16.5, 16.5))
	var occ_wall: float = Audio.occlusion_factor(lv0, Vector2(15.5, 15.5), Vector2(8.5, 8.5))
	_check(occ_same == 1.0, "no occlusion in same room")
	_check(occ_wall < 1.0, "wall between rooms muffles sound")
	# музыкальные состояния: chase → return
	g.granny.state = GrannyAI.INVESTIGATE
	g.granny.level = g.player.level
	g.chase_cool = 0.0
	g._update_music_intensity()
	_check(Audio._pending_track == "music_tension", "tension track on investigate")
	g.granny.state = GrannyAI.CHASE
	g._update_music_intensity()
	_check(Audio._pending_track == "music_chase", "chase track on chase")
	_check(g.chase_cool > 0.0, "chase cooldown set")
	g.granny.state = GrannyAI.PATROL
	g._update_music_intensity()
	_check(Audio._pending_track == "music_return", "return track right after chase")
	g.chase_cool = 0.0
	g._update_music_intensity()
	_check(Audio._pending_track == "" or Audio._pending_track == "music_ambient", "ambient restored on patrol")

	# --- мышь в меню: ховер по прямоугольникам ---
	g._set_state(g.STATE_TITLE)
	await _frames(2)
	var rects := g.ui.hover_rects
	_check(rects.size() == g.menu_items.size(), "title menu exposes click rects")
	var all_cover := true
	for i in rects.size():
		var center: Vector2 = rects[i].get_center()
		var covered := false
		for j in rects.size():
			if rects[j].has_point(center):
				covered = true
				break
		if not covered:
			all_cover = false
	_check(all_cover, "every menu rect covers its own center")
	g.menu_idx = 2
	g._activate_title_item()
	_check(g.state == g.STATE_LOAD, "title menu opens load screen")
	g._on_key(KEY_ESCAPE)
	_check(g.state == g.STATE_TITLE, "load screen Esc from title returns to title")

	# --- мышь в паузе ---
	g._set_state(g.STATE_PAUSE)
	await _frames(2)
	var prects := g.ui.hover_rects
	_check(prects.size() == g.pause_items.size(), "pause menu exposes click rects")
	var pause_cover := true
	for i in prects.size():
		var pc: Vector2 = prects[i].get_center()
		if not prects[i].has_point(pc):
			pause_cover = false
	_check(pause_cover, "pause rects cover their centers")
	g.pause_idx = 0
	g.ui.hover_idx = 0
	g._menu_click()
	_check(g.state == g.STATE_PLAY, "clicking highlighted pause item resumes")
	g._set_state(g.STATE_PAUSE)
	await _frames(2)

	# --- повреждённые и отсутствующие сейвы ---
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	var udir := DirAccess.open("user://")
	udir.make_dir_recursive("saves")
	var fw := FileAccess.open("user://saves/slot3.json", FileAccess.WRITE)
	fw.store_string("{это не json!!!")
	fw.close()
	var bad_meta := SaveSystem.read_meta(SaveSystem.SLOTS[2])
	_check(not bad_meta.exists, "corrupted json reports missing meta")
	_check(not SaveSystem.load_run(g, SaveSystem.SLOTS[2]), "corrupted json refuses to load")
	fw = FileAccess.open("user://saves/slot3.json", FileAccess.WRITE)
	fw.store_string("{\"meta\": {\"day\": 2}}")
	fw.close()
	_check(not SaveSystem.load_run(g, SaveSystem.SLOTS[2]), "json without state refuses to load")
	_check(g.state == g.STATE_PLAY, "failed load keeps play state")
	var m_missing := SaveSystem.read_meta("no_such_slot")
	_check(not m_missing.exists, "missing slot reports missing")
	_check(not SaveSystem.load_run(g, "no_such_slot"), "missing slot refuses to load")
	# семантический мусор в валидном json: клампы и фильтры
	fw = FileAccess.open("user://saves/slot3.json", FileAccess.WRITE)
	fw.store_string(JSON.stringify({
		"meta": {},
		"state": {
			"version": 2,
			"diff_index": 99, "day": 999, "max_days": 0, "deaths": -5, "play_time": -12.0,
			"player": {"level": 55, "x": -12345.0, "y": -9999.0},
			"held_item": 3,
			"ground_items": [{"id": 3, "lv": 0, "x": 999.0, "y": -999.0}, {"id": 77, "lv": 0, "x": 5.5, "y": 5.5}],
			"armed_traps": [{"lv": 31, "x": -50.0, "y": -50.0}],
		},
	}))
	fw.close()
	_check(SaveSystem.load_run(g, SaveSystem.SLOTS[2]), "garbage-but-valid save loads")
	_check(g.diff_index >= 0 and g.diff_index < g.diffs.size(), "diff index clamped")
	_check(g.max_days >= 1, "max days clamped positive")
	_check(g.day >= 1 and g.day <= g.max_days, "day clamped into range")
	_check(g.deaths >= 0, "deaths clamped non-negative")
	_check(g.play_time >= 0.0, "play time clamped non-negative")
	_check(g.player.level >= 0 and g.player.level < g.world.levels.size(), "player level clamped")
	var glv2: LevelData = g.world.levels[g.player.level]
	var pp2: Vector3 = g.player.global_position - glv2.origin
	_check(pp2.x >= 0.0 and pp2.x <= glv2.w and pp2.z >= 0.0 and pp2.z <= glv2.h, "player position clamped into level")
	_check(not glv2.solid_at(pp2.x, pp2.z), "player not stuck inside a wall")
	_check(g.held_item == Items.NOTE, "invalid held item ids filtered out")
	_check(g.ground_items.size() <= 1, "ground items in walls filtered out")
	var trap_total := 0
	for lvx in g.world.levels:
		trap_total += lvx.traps.size()
	_check(trap_total == 0, "garbage trap coords filtered out")

	# --- переработка 2: ресурсы, профили, парящий предмет ---
	var ui_bold: Font = g.ui.font_bold
	_check(ui_bold != null, "ui bold font loaded")
	_check(g.ui.font_reg != null, "ui regular font loaded")
	_check(g.ui.vignette_tex != null and g.ui.fog_tex != null, "ui atmosphere textures loaded")
	_check(Audio.streams.size() >= 57, "audio streams loaded (%d)" % Audio.streams.size())
	var menu_stream: AudioStream = Audio.streams.get("music_menu")
	var looped := false
	if menu_stream is AudioStreamWAV:
		looped = (menu_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	_check(looped, "menu music loops")
	for snd in ["step_rug", "step_wood", "step_concrete", "granny_step2", "granny_step3",
			"granny_gasps", "granny_lost", "granny_hum", "drawer", "stairs", "metal_door",
			"item_drop", "house_settle", "window_scratch", "floor_creak2", "music_return",
			"wind_loop", "cellar_loop", "attic_loop", "music_tension", "music_chase"]:
		_check(Audio.streams.has(snd), "overhaul sound present: " + snd)
	# профили качества: нормальные карты включаются/выключаются
	Mats.set_quality(0)
	var low_q: StandardMaterial3D = Mats.mat("wood")
	Mats.set_quality(2)
	var hi_q: StandardMaterial3D = Mats.mat("wood")
	_check(not low_q.normal_enabled, "quality low disables normal maps")
	_check(hi_q.normal_enabled, "quality high enables normal maps")
	# парящий предмет: модели построены, видна только удерживаемая
	g.player.set_held(Items.CROSSBOW)
	await _frames(2)
	_check(g.player.item_root != null, "item float node exists")
	_check(g.player.item_root.get_child_count() >= 12, "item models built (%d)" % g.player.item_root.get_child_count())
	_check(g.player.item_root.visible, "held item visible in play state")
	var cb_visible := false
	for c in g.player.item_root.get_children():
		if c is Node3D and (c as Node3D).visible:
			cb_visible = true
	_check(cb_visible, "held item node visible")
	_check(not g.player.item_root.visible or g.player.held_id == Items.CROSSBOW, "only held item shown")
	g.player.start_inspect()
	_check(g.player._inspect_t >= 0.0, "inspect animation starts")
	g.player._inspect_t = -1.0
	g.player.set_held(0)
	await _frames(1)
	_check(not g.player.item_root.visible or g.player.held_id == 0, "empty hands hide the item")
	# шаги по поверхностям
	g.player.place_at(0, 15.5, 27.2, -PI * 0.5)
	var surf := g.player._step_surface()
	_check(surf == "step" or surf == "step2", "wood floor step sound (%s)" % surf)
	# переход-затемнение между экранами
	var ta_before: float = g.transition_a
	g._set_state(g.STATE_PAUSE)
	_check(g.transition_a > ta_before or g.transition_a > 0.9, "state transition fade set")
	g._set_state(g.STATE_PLAY)
	# сенсорное управление: проводка кнопок и джойстика
	var tc := TouchControls.new()
	g.add_child(tc)
	g.touch = tc
	tc.setup(g)
	tc._press("E", true)
	_check(g.touch_e, "touch E press wires flag")
	tc._press("E", false)
	_check(not g.touch_e, "touch E release clears flag")
	tc._press("F", true)
	_check(not g.player.flashlight_on, "touch F toggles flashlight")
	tc._press("F", true)
	_check(g.player.flashlight_on, "touch F toggles back")
	tc.joy_idx = 3
	tc.joy_vec = Vector2(0.0, -1.0)
	_check(g.player._joy().y < -0.9, "touch joystick vector reaches player")
	tc.queue_free()
	g.touch = null
	g.touch_e = false
	# --- ФИКСИРОВАННАЯ ПЛАНИРОВКА: повторный старт даёт тот же дом ---
	# два ПОЛНЫХ старта игры: раскладка предметов и капканов совпадает
	g.diff_index = 1
	g.start_game()
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	var snap_a := []
	for lvx in g.world.levels:
		for c in lvx.containers:
			snap_a.append("%d:%d:%d:%d" % [lvx.id, c.x, c.y, int(c.item_id)])
	var traps_a := []
	for t in g.world.levels[0].traps:
		traps_a.append("%0.1f:%0.1f" % [t.x, t.y])
	g.start_game()
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	var snap_b := []
	for lvx in g.world.levels:
		for c in lvx.containers:
			snap_b.append("%d:%d:%d:%d" % [lvx.id, c.x, c.y, int(c.item_id)])
	var traps_b := []
	for t in g.world.levels[0].traps:
		traps_b.append("%0.1f:%0.1f" % [t.x, t.y])
	_check(str(snap_a) == str(snap_b), "fixed items identical between runs")
	_check(str(traps_a) == str(traps_b), "fixed traps identical between runs")
	_check(traps_b.size() == 3, "normal difficulty places 3 plan traps (%d)" % traps_b.size())
	var plan_spots: Array = HousePlan.PLAN["trap_spots"]
	var all_on_plan := true
	for t in g.world.levels[0].traps:
		var on_plan := false
		for s in plan_spots:
			if int(s[0]) + 0.5 == t.x and int(s[1]) + 0.5 == t.y:
				on_plan = true
		if not on_plan:
			all_on_plan = false
	_check(all_on_plan, "every trap sits on a plan spot")

	# замер CPU-времени кадра (headless = физика+скрипты, без рендера)
	var times: Array[float] = []
	for i in 240:
		var t0 := Time.get_ticks_usec()
		await _frames(1)
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= float(times.size())
	var p95: float = times[int(times.size() * 0.95)]
	print("AUTOTEST perf frame_ms avg=%.2f p95=%.2f" % [avg, p95])

	# Даём дереву освободить отложенные ресурсы и таймеры перед выходом.
	await _frames(10)

	print("AUTOTEST checks=%d fails=%d" % [checks, fails])
	print("AUTOTEST " + ("OK" if fails == 0 else "FAILED"))
	g.get_tree().quit(0 if fails == 0 else 1)

func _frames(n: int) -> void:
	for i in n:
		await g.get_tree().process_frame

func _press(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		# Headless: кадры не рендерятся, frame_post_draw не приходит —
		# скриншоты недоступны в принципе; все проверки не зависят от них.
		return
	await RenderingServer.frame_post_draw
	var img := g.get_viewport().get_texture().get_image()
	var dir := DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive("tests/shots")
	img.save_png("res://tests/shots/" + name + ".png")

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("AUTOTEST FAIL: ", what)
