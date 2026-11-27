class_name HouseWorld
extends Node3D

# Рантайм-мир фиксированного дома.
#
# Дом НЕ собирается при запуске: геометрия запечена офлайн-инструментом
# tools/bake_house.gd в постоянную сцену scenes/house.scn (стены, полы,
# мебель, двери, замки, ворота, лампы, люки, паутина — все позиции заранее
# заданы планом scripts/house_plan.gd и одинаковы при каждом запуске).
# Здесь только:
#   1) загрузка запечённой сцены;
#   2) назначение материалов из scripts/materials.gd (профили качества);
#   3) проводка состоянных объектов: двери (анимация), замки (видимость),
#      ворота гаража, капканы и пауки (живые сущности, ставятся по плану);
#   4) логическая модель уровней LevelData для AI/коллизий/сохранений.

const WALL_H := 2.60

var levels: Array[LevelData] = []
var roots: Array[Node3D] = []

var door_entries: Array[Dictionary] = []
var lock_meshes: Array[MeshInstance3D] = []
var garage_node: Node3D = null
var garage_shape: CollisionShape3D = null
var garage_open := false
var garage_t := 0.0

var spider_nodes: Array[Node3D] = []
var lamp_lights: Array[OmniLight3D] = []

func build(_pseed := 0) -> void:
	# Логическая модель из фиксированного плана (детерминировано).
	levels = HousePlan.build_levels()
	# Запечённая сцена дома.
	var scene: PackedScene = load("res://scenes/house.scn")
	if scene == null:
		push_error("house_world: scenes/house.scn не найдена — запусти tools/bake_house.gd")
		return
	var inst: Node3D = scene.instantiate()
	inst.name = "House"
	add_child(inst)
	for i in levels.size():
		roots.append(inst.find_child("Level%d_*" % i, true, false))
	_apply_materials(inst)
	_collect_lights(inst)
	_wire_doors()
	_wire_locks(inst)
	_wire_garage(inst)
	for lv in levels:
		if lv.spiders.size() > 0:
			_build_spiders(lv, get_root(lv.id))

func get_root(id: int) -> Node3D:
	if id < 0 or id >= roots.size() or roots[id] == null:
		return roots[0]
	return roots[id]

# --- материалы и свет ---

func _apply_materials(n: Node) -> void:
	# Запечённые меши несут имя материала в метаданных "mat": материалы
	# выдаёт scripts/materials.gd — профили качества работают как раньше.
	if n is GeometryInstance3D:
		if n.has_meta("web"):
			return  # паутина: материал уже запечён в сцену
		if n.has_meta("mat"):
			(n as GeometryInstance3D).material_override = Mats.mat(String(n.get_meta("mat")))
	for c in n.get_children():
		_apply_materials(c)

func _collect_lights(n: Node) -> void:
	if n is OmniLight3D:
		var light := n as OmniLight3D
		light.shadow_enabled = Mats.quality() >= 2
		lamp_lights.append(light)
	for c in n.get_children():
		_collect_lights(c)

# --- двери, замки, ворота ---

func _wire_doors() -> void:
	for lv in levels:
		for d in lv.doors:
			var pivot: Node3D = get_root(lv.id).find_child("Door_%d_%d" % [d.x, d.y], true, false)
			if pivot == null:
				push_error("house_world: дверь (%d,%d) не найдена в запечённой сцене" % [d.x, d.y])
				continue
			var body := pivot.get_child(0)
			door_entries.append({
				"door": d,
				"pivot": pivot,
				"base": 0.0,
				"sign": 1.0,
				"body": body,
				"shape": body.get_child(0),
				"axis": str(pivot.get_meta("axis")),
			})

func _wire_locks(inst: Node3D) -> void:
	for i in 3:
		var lm := inst.find_child("Lock_%d" % i, true, false)
		if lm != null:
			lock_meshes.append(lm)

func _wire_garage(inst: Node3D) -> void:
	garage_node = inst.find_child("GarageDoor", true, false)
	if garage_node != null:
		garage_shape = garage_node.find_child("GarageCollider", true, false)

func set_garage_open(v: bool) -> void:
	garage_open = v

func update_doors(dt: float) -> void:
	for e in door_entries:
		var d: LevelData.Door = e.door
		var target := 1.0 if d.open else 0.0
		var spd := 3.0 if target > d.open_t else 4.5
		d.open_t = move_toward(d.open_t, target, dt * spd)
		var pivot: Node3D = e.pivot
		pivot.rotation.y = float(e.base) + float(e.sign) * d.open_t * PI * 0.5
		var sh: CollisionShape3D = e.shape
		sh.disabled = d.open_t > 0.10
	if garage_node != null:
		var target := 1.0 if garage_open else 0.0
		garage_t = move_toward(garage_t, target, dt * 1.4)
		garage_node.position.y = lerpf(0.0, 2.75, garage_t)
		if garage_shape != null:
			garage_shape.disabled = garage_t > 0.04

func set_front_locks(opened: int) -> void:
	for i in lock_meshes.size():
		lock_meshes[i].visible = i >= opened

# --- капканы (живые объекты, позиции из фиксированного плана) ---

func make_trap_node(lv: LevelData, trap: LevelData.Trap) -> Node3D:
	var root := get_root(lv.id)
	var node := TrapNode.new()
	node.name = "Trap"
	node.position = Vector3(trap.x, 0.02, trap.y)
	root.add_child(node)
	_cyl(node, 0.20, 0.025, Vector3.ZERO, "metal")
	var jaw_l := Node3D.new()
	jaw_l.position = Vector3(0, 0.03, 0)
	node.add_child(jaw_l)
	var jaw_r := Node3D.new()
	jaw_r.position = Vector3(0, 0.03, 0)
	node.add_child(jaw_r)
	for i in 5:
		var a := -0.55 + i * 0.275
		_box(jaw_l, Vector3(0.04, 0.05, 0.20), Vector3(cos(a) * 0.14, 0, sin(a) * 0.14), "trap", a)
		_box(jaw_r, Vector3(0.04, 0.05, 0.20), Vector3(cos(a) * 0.14, 0, -sin(a) * 0.14), "trap", -a)
	node.jaw_l = jaw_l
	node.jaw_r = jaw_r
	node.set_armed(trap.armed)
	trap.node = node
	return node

func add_trap(lv: LevelData, x: float, y: float) -> LevelData.Trap:
	var trap := LevelData.Trap.new()
	trap.x = x
	trap.y = y
	lv.traps.append(trap)
	make_trap_node(lv, trap)
	return trap

func clear_traps() -> void:
	for lv in levels:
		for t in lv.traps:
			if t.node != null:
				t.node.queue_free()
				t.node = null
		lv.traps.clear()

# --- пауки подвала (живые объекты; точки из фиксированного плана) ---

func _build_spiders(lv: LevelData, root: Node3D) -> void:
	for p in lv.spiders:
		var n := Node3D.new()
		n.name = "Spider"
		n.position = Vector3(p.x, 0.06, p.y)
		root.add_child(n)
		var body := SphereMesh.new()
		body.radius = 0.20
		body.height = 0.28
		var bmi := MeshInstance3D.new()
		bmi.mesh = body
		bmi.material_override = Mats.mat("black")
		bmi.position = Vector3(0, 0.18, 0)
		n.add_child(bmi)
		var head := SphereMesh.new()
		head.radius = 0.10
		head.height = 0.14
		var hmi := MeshInstance3D.new()
		hmi.mesh = head
		hmi.material_override = Mats.mat("black")
		hmi.position = Vector3(0.20, 0.17, 0)
		n.add_child(hmi)
		for i in 4:
			for side in [-1.0, 1.0]:
				var a := (i - 1.5) * 0.42
				_box(n, Vector3(0.045, 0.035, 0.36), Vector3(cos(a) * 0.20, 0.08, side * 0.18), "black", a)
		_box(n, Vector3(0.03, 0.03, 0.03), Vector3(0.28, 0.20, 0.04), "eye")
		_box(n, Vector3(0.03, 0.03, 0.03), Vector3(0.28, 0.20, -0.04), "eye")
		n.set_meta("base", n.position)
		spider_nodes.append(n)

# --- примитивы для живых объектов (капканы/пауки) ---

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat_name: String, rot_y: float = 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = Mats.mat(mat_name)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat_name: String, rot_x: float = 0.0, rot_z: float = 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = Mats.mat(mat_name)
	mi.position = pos
	mi.rotation.x = rot_x
	mi.rotation.z = rot_z
	parent.add_child(mi)
	return mi
