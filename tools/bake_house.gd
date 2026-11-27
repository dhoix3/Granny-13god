extends SceneTree

# ОФЛАЙН-запекание фиксированного дома в сцену scenes/house.scn.
#
# Запуск (один раз после изменения scripts/house_plan.gd):
#   godot --headless --path . --script res://tools/bake_house.gd
#
# Результат — постоянная сцена с заранее расставленной геометрией: стены,
# полы, потолки, мебель, двери, замки, ворота, лампы, люки, паутина.
# Игра при запуске НЕ собирает дом — только загружает эту сцену
# (scripts/house_world.gd). Никакой генерации планировки.

var fails := 0

func _initialize() -> void:
	print("BAKE: строю дом из фиксированного плана...")
	var plan = load("res://scripts/house_plan.gd")
	if plan == null:
		push_error("bake: house_plan.gd не загружается")
		quit(1)
		return
	var geo = load("res://tools/house_geometry.gd").new()
	var levels: Array[LevelData] = plan.build_levels()
	var house: Node3D = geo.build(levels)

	# владелец обязателен: pack включает только узлы с owner == корень
	_set_owner(house, house)

	var ps := PackedScene.new()
	var err := ps.pack(house)
	if err != OK:
		push_error("bake: pack вернул %d" % err)
		quit(1)
		return
	var save_err := ResourceSaver.save(ps, "res://scenes/house.scn", ResourceSaver.FLAG_COMPRESS)
	if save_err != OK:
		push_error("bake: save вернул %d" % save_err)
		quit(1)
		return
	var size_mb := FileAccess.open("res://scenes/house.scn", FileAccess.READ).get_length() / 1048576.0
	print("BAKE: сохранено scenes/house.scn (%.1f МБ)" % size_mb)

	# --- верификация запечённой сцены ---
	var back: PackedScene = load("res://scenes/house.scn")
	_check(back != null, "сцена загружается")
	if back == null:
		quit(1)
		return
	var inst: Node3D = back.instantiate()
	var level_nodes := 0
	for i in levels.size():
		var ln := inst.find_child("Level%d_*" % i, true, false)
		_check(ln != null, "Level%d присутствует" % i)
		if ln != null:
			level_nodes += 1
			var meshes := _count_type(ln, "MeshInstance3D")
			var lights := _count_type(ln, "OmniLight3D")
			var bodies := _count_type(ln, "StaticBody3D")
			var mats := _count_meta(ln, "mat")
			_check(meshes > 10, "Level%d: мешей %d" % [i, meshes])
			_check(bodies >= 2, "Level%d: статических тел %d" % [i, bodies])
			_check(mats == meshes, "Level%d: у всех мешей есть материал (meta mat: %d/%d)" % [i, mats, meshes])
			_check(mats > 0 and lights >= 0, "Level%d: меты на месте" % i)
			var lv: LevelData = levels[i]
			for d in lv.doors:
				_check(ln.find_child("Door_%d_%d" % [d.x, d.y], true, false) != null,
					"Level%d: дверь (%d,%d) запечена" % [i, d.x, d.y])
	_check(inst.find_child("GarageDoor", true, false) != null, "ворота гаража запечены")
	_check(inst.find_child("GarageCollider", true, false) != null, "коллайдер ворот запечен")
	var locks := 0
	for i in 3:
		if inst.find_child("Lock_%d" % i, true, false) != null:
			locks += 1
	_check(locks == 3, "3 замка запечены (%d)" % locks)
	var web_cnt := _count_type(inst, "MeshInstance3D")
	_check(web_cnt > 0, "узлов с мешами: %d" % web_cnt)

	# контейнер-метки плана: каждый предмет находит свой контейнер
	var missing := 0
	for lv in levels:
		for c in lv.containers:
			if c.item_id != 0 and c.label == "":
				missing += 1
	_check(missing == 0, "предметы плана распределены без ошибок")

	var total_nodes := _count_all(inst)
	print("BAKE: узлов %d, уровней %d" % [total_nodes, level_nodes])
	inst.free()
	house.free()

	if fails == 0:
		print("BAKE OK")
	else:
		print("BAKE FAILED: %d" % fails)
	quit(0 if fails == 0 else 1)

func _set_owner(n: Node, root: Node) -> void:
	if n != root:
		n.owner = root
	for c in n.get_children():
		_set_owner(c, root)

func _count_type(n: Node, klass: String) -> int:
	var cnt := 0
	if n.is_class(klass):
		cnt += 1
	for c in n.get_children():
		cnt += _count_type(c, klass)
	return cnt

func _count_all(n: Node) -> int:
	var cnt := 1
	for c in n.get_children():
		cnt += _count_all(c)
	return cnt

func _count_meta(n: Node, meta: String) -> int:
	# паутина несёт собственный запечённый материал (meta "web") — не считается
	var cnt := 0
	if n is GeometryInstance3D:
		if n.has_meta(meta) or n.has_meta("web"):
			cnt += 1
	for c in n.get_children():
		cnt += _count_meta(c, meta)
	return cnt

func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("BAKE FAIL: ", what)
