extends RefCounted

# Автотест: запускает игру, проходит ключевые механики и сохраняет скриншоты.
# Запуск: Godot.exe --path . -- --autotest

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

	g.diff_index = 1
	g.start_game()
	await _frames(4)
	await _shot("02_intro")

	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	await _frames(4)
	await _shot("03_play")

	var lv0: LevelData = g.world.levels[0]
	_check(lv0.containers.size() > 0, "house has containers")
	_check(lv0.doors.size() > 0, "house has doors")
	_check(lv0.decos.size() > 0, "house has furniture")
	_check(lv0.lamps.size() > 0, "house has lamps")

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

	# --- закрытая дверь физически не пускает ---
	var door0 = lv0.doors[0]
	door0.open = false
	g.world.update_doors(1.0)
	g.player.place_at(0, door0.x + 0.5, door0.y + 2.2, -PI * 0.5)
	await _frames(2)
	_press(KEY_W, true)
	await _frames(55)
	_press(KEY_W, false)
	var blocked := g.player.global_position - lv0.origin
	_check(blocked.z > 13.5, "closed door blocks the player (z=%.2f)" % blocked.z)
	door0.open = true
	g.world.update_doors(1.0)
	_press(KEY_W, true)
	await _frames(55)
	_press(KEY_W, false)
	var through := g.player.global_position - lv0.origin
	_check(through.z < 13.2, "open door lets the player through (z=%.2f)" % through.z)
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

	# --- обыск контейнера ---
	var cont = null
	for c in lv0.containers:
		if c.item_id != Items.NONE:
			cont = c
			break
	if cont != null:
		g.player.place_at(0, cont.x + 0.5, cont.y + 1.5, -PI * 0.5)
		g.update_target_scan()
		_check(g.target_kind == 2 and g.target_obj == cont, "container targeted")
		g.target_kind = 2
		g.target_obj = cont
		g.e_down = true
		g.interact_prog = 0.0
		g.update_interaction(1.2)
		_check(cont.searched, "container searched")
		_check(g.inv.has(cont.item_id), "item picked up")
		g.e_down = false
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

	# --- бутылка ---
	g.inv.append(Items.BOTTLE)
	g.player.place_at(0, 15.5, 27.0, -PI * 0.5)
	g.throw_bottle()
	_check(not g.inv.has(Items.BOTTLE), "bottle consumed")
	await _frames(20)
	_check(g.throwns.size() >= 0, "bottle update safe")

	# --- арбалет ---
	g.inv.append(Items.CROSSBOW)
	g.inv.append(Items.DART)
	g.fire_crossbow()
	_check(not g.inv.has(Items.DART), "dart consumed")

	# --- чердак и кошка ---
	g.player.place_at(0, 4.5, 6.0, -PI * 0.5)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 1, "switched to attic")
	_check(g.cat != null, "cat present")
	await _shot("05_attic")

	# --- кошка злится на свет и шум ---
	g.cat.fed = false
	g.cat.angry = false
	g.cat.angry_t = 0.0
	g.attic_alert_t = 0.0
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

	g.inv.append(Items.MILK)
	g.remove_item(Items.MILK)
	g.inv.append(Items.MILK)
	g.cat.feed(g)
	_check(g.cat.fed, "cat fed")
	g.remove_item(Items.MILK)
	await _frames(2)
	await _shot("06_cat")

	# --- подвал и пауки ---
	g.player.place_at(0, 4.5, 27.0, -PI * 0.5)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 3, "switched to cellar")
	_check(g.in_spider_web() == false, "web check safe")
	await _shot("07_cellar")

	# --- гараж ---
	g.player.place_at(0, 14.5, 27.0, -PI * 0.5)
	g.switch_level()
	await _frames(3)
	_check(g.player.level == 2, "switched to garage")
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
		g.inv.append(Items.CAR_KEY)
		g.inv.append(Items.CAR_BATTERY)
		g.target_kind = 7
		g.target_obj = car
		g.e_down = true
		g.update_interaction(3.0)
		_check(g.car_key_installed, "car key installed")
		g.update_interaction(3.0)
		_check(g.car_battery_installed, "car battery installed")
		g.e_down = false
		g.e_hit = true
		g.update_interaction(0.1)
		_check(g.state == g.STATE_WIN and g.last_win == g.WIN_CAR, "car escape ending")
		g._set_state(g.STATE_PLAY)
		g.fade_t = 0.0

	# --- возвращаемся в дом, открываем замки ---
	g.player.place_at(0, 15.5, 28.4, PI * 0.5)
	g.inv.append(Items.KEY)
	g.inv.append(Items.CROWBAR)
	g.inv.append(Items.NOTE)
	var front = null
	for d in lv0.doors:
		if d.front:
			front = d
			break
	_check(front != null, "front door exists")
	if front != null:
		g.target_kind = 5
		g.target_obj = front
		g.e_down = true
		for i in 3:
			g.interact_prog = 0.0
			g.update_interaction(1.6)
		g.e_down = false
		_check(g.count_locks() == 3, "three locks opened")
		_check(g.world.lock_meshes.size() >= 3, "lock meshes exist")
	await _frames(2)
	await _shot("09_locks")

	# --- побег через входную дверь после трёх замков ---
	g.e_down = false
	g.e_hit = true
	g.update_interaction(0.1)
	_check(g.state == g.STATE_WIN and g.last_win == g.WIN_DOOR, "front door escape ending")
	g.e_hit = false
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0

	# --- дневник ---
	g.journal = true
	await _frames(2)
	await _shot("10_journal")
	g.journal = false

	# --- поимка ---
	g.player.place_at(0, 15.5, 20.0, -PI * 0.5)
	g.on_caught()
	await _frames(6)
	await _shot("11_caught")
	await g.get_tree().create_timer(3.2).timeout
	_check(g.state == g.STATE_PLAY, "respawn after caught")
	_check(g.day == 2, "day advanced")

	# --- победа ---
	g.win_game(g.WIN_DOOR)
	await _frames(4)
	await _shot("12_win")
	_check(g.state == g.STATE_WIN, "win state")

	# --- проигрыш по дням ---
	g._set_state(g.STATE_PLAY)
	g.day = g.max_days
	g.on_caught()
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
	g._set_state(g.STATE_PLAY)
	g.fade_t = 0.0
	g.inv.append(Items.KEY)
	g.inv.append(Items.CROWBAR)
	g.inv.append(Items.NOTE)
	g.inv.append(Items.NOTE2)
	var front2 = null
	for d in g.world.levels[0].doors:
		if d.front:
			front2 = d
			break
	_check(front2 != null, "hard mode front door exists")
	if front2 != null:
		g.target_kind = 5
		g.target_obj = front2
		g.e_down = true
		for i in 4:
			g.interact_prog = 0.0
			g.update_interaction(1.6)
		g.e_down = false
		_check(g.count_locks() == 3, "hard mode: three locks opened")
		_check(g.lock4, "hard mode: fourth lock opened")

	# --- секретная концовка: Тедди в колыбели ---
	g.car_key_installed = true
	g.car_battery_installed = true
	g.inv.append(Items.TEDDY)
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
