class_name WorldBuilder
extends Node3D

const WALL_H := 2.60

var levels: Array[LevelData] = []
var roots: Array[Node3D] = []
var gen: WorldGen
var seed := 1

var door_entries: Array[Dictionary] = []
var front_entry: Dictionary = {}
var lock_meshes: Array[MeshInstance3D] = []
var garage_node: Node3D = null
var garage_shape: CollisionShape3D = null
var garage_open := false
var garage_t := 0.0

var spider_nodes: Array[Node3D] = []
var web_nodes: Array[Node3D] = []
var _sts: Dictionary = {}
var _web_tex: ImageTexture = null
var _box_shape: BoxShape3D = null

func build(pseed: int) -> void:
	seed = pseed
	gen = WorldGen.new()
	levels = gen.build(pseed)
	_box_shape = BoxShape3D.new()
	_box_shape.size = Vector3(1.0, WALL_H, 1.0)
	for i in levels.size():
		var lv := levels[i]
		var root := Node3D.new()
		root.name = "Level%d_%s" % [i, lv.name]
		root.position = lv.origin
		add_child(root)
		roots.append(root)
		_build_shell(lv, root)
		_build_decos(lv, root)
		_build_lamps(lv, root)
		_build_traps(lv, root)
		_build_webs(lv, root)
		if i == 3:
			_build_spiders(lv, root)
	if front_entry.size() > 0:
		set_front_locks(0)

func get_root(id: int) -> Node3D:
	if id < 0 or id >= roots.size():
		return roots[0]
	return roots[id]

func _st(mat_name: String) -> SurfaceTool:
	if not _sts.has(mat_name):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sts[mat_name] = st
	return _sts[mat_name]

func _flush_surfaces(root: Node3D) -> void:
	for key in _sts.keys():
		var st: SurfaceTool = _sts[key]
		var mesh := st.commit()
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Shell_" + str(key)
		mi.mesh = mesh
		mi.material_override = Mats.mat(str(key))
		root.add_child(mi)
	_sts.clear()

func _world_uv(p: Vector3, n: Vector3, s: float) -> Vector2:
	if absf(n.x) > 0.5:
		return Vector2(p.z, p.y) * s
	if absf(n.z) > 0.5:
		return Vector2(p.x, p.y) * s
	return Vector2(p.x, p.z) * s

func _uv_scale(mat_name: String) -> float:
	match mat_name:
		"wallpaper": return 1.00
		"panel": return 0.55
		"plaster": return 0.55
		"brick": return 0.55
		"tile": return 0.60
		"attic": return 0.55
		"ceiling": return 0.55
		"wood": return 0.50
		"concrete": return 0.50
	return 0.0

func _quad(st: SurfaceTool, p0: Vector3, u: Vector3, v: Vector3, n: Vector3, uv_scale := 0.0) -> void:
	var p1 := p0 + v
	var p2 := p0 + u + v
	var p3 := p0 + u
	var uv0 := Vector2(0.0, 0.0)
	var uv1 := Vector2(0.0, 1.0)
	var uv2 := Vector2(1.0, 1.0)
	var uv3 := Vector2(1.0, 0.0)
	if uv_scale > 0.0:
		uv0 = _world_uv(p0, n, uv_scale)
		uv1 = _world_uv(p1, n, uv_scale)
		uv2 = _world_uv(p2, n, uv_scale)
		uv3 = _world_uv(p3, n, uv_scale)
	st.set_normal(n)
	st.set_uv(uv0)
	st.add_vertex(p0)
	st.set_normal(n)
	st.set_uv(uv1)
	st.add_vertex(p1)
	st.set_normal(n)
	st.set_uv(uv2)
	st.add_vertex(p2)
	st.set_normal(n)
	st.set_uv(uv0)
	st.add_vertex(p0)
	st.set_normal(n)
	st.set_uv(uv2)
	st.add_vertex(p2)
	st.set_normal(n)
	st.set_uv(uv3)
	st.add_vertex(p3)

func _tile_mat(t: int) -> String:
	match t:
		LevelData.WP: return "wallpaper"
		LevelData.PANEL: return "panel"
		LevelData.BRICK: return "brick"
		LevelData.WINDOW: return "window"
		LevelData.ATTIC: return "attic"
		LevelData.ATTICWOOD: return "beam"
		LevelData.TILEW: return "tile"
		LevelData.TOWELS: return "towel"
		LevelData.MIRROR: return "mirror"
		LevelData.CAGE: return "cage"
		LevelData.GARAGE_DOOR: return "garage_door"
		LevelData.PORTRAIT: return "plaster"
		LevelData.PLASTER: return "plaster"
	return "plaster"

func _is_opening(t: int) -> bool:
	return t == LevelData.DOOR or t == LevelData.FRONT or t == LevelData.GARAGE_DOOR

func _build_shell(lv: LevelData, root: Node3D) -> void:
	var wall_body := StaticBody3D.new()
	wall_body.name = "WallCollision"
	root.add_child(wall_body)
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorCollision"
	root.add_child(floor_body)
	var fshape := BoxShape3D.new()
	fshape.size = Vector3(lv.w, 0.20, lv.h)
	var fcs := CollisionShape3D.new()
	fcs.shape = fshape
	fcs.position = Vector3(lv.w * 0.5, -0.10, lv.h * 0.5)
	floor_body.add_child(fcs)

	for y in lv.h:
		for x in lv.w:
			var t := lv.get_tile(x, y)
			var opening := _is_opening(t)
			if not LevelData.SOLID[t] or opening:
				# floor
				if t == LevelData.HOLE:
					var hs := _st("hole")
					_quad(hs, Vector3(x, 0.012, y), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3.UP)
				else:
					var fmat := _floor_name(t, lv.id)
					var fs := _st(fmat)
					_quad(fs, Vector3(x, 0.0, y), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3.UP, _uv_scale(fmat))
				# ceiling
				var cs := _st("ceiling")
				_quad(cs, Vector3(x, WALL_H, y), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3.DOWN, _uv_scale("ceiling"))
			if LevelData.SOLID[t] and not opening:
				var mat := _tile_mat(t)
				var st := _st(mat)
				# north
				var us := _uv_scale(mat)
				if not LevelData.SOLID[lv.get_tile(x, y - 1)] or _is_opening(lv.get_tile(x, y - 1)):
					_quad(st, Vector3(x + 1, 0, y), Vector3(-1, 0, 0), Vector3(0, WALL_H, 0), Vector3(0, 0, -1), us)
				# south
				if not LevelData.SOLID[lv.get_tile(x, y + 1)] or _is_opening(lv.get_tile(x, y + 1)):
					_quad(st, Vector3(x, 0, y + 1), Vector3(1, 0, 0), Vector3(0, WALL_H, 0), Vector3(0, 0, 1), us)
				# west
				if not LevelData.SOLID[lv.get_tile(x - 1, y)] or _is_opening(lv.get_tile(x - 1, y)):
					_quad(st, Vector3(x, 0, y), Vector3(0, 0, 1), Vector3(0, WALL_H, 0), Vector3(-1, 0, 0), us)
				# east
				if not LevelData.SOLID[lv.get_tile(x + 1, y)] or _is_opening(lv.get_tile(x + 1, y)):
					_quad(st, Vector3(x + 1, 0, y + 1), Vector3(0, 0, -1), Vector3(0, WALL_H, 0), Vector3(1, 0, 0), us)
				# collision
				var cs2 := CollisionShape3D.new()
				cs2.shape = _box_shape
				cs2.position = Vector3(x + 0.5, WALL_H * 0.5, y + 0.5)
				wall_body.add_child(cs2)
			if t == LevelData.DOOR:
				_build_door(lv, root, x, y, false, wall_body)
			elif t == LevelData.FRONT:
				_build_door(lv, root, x, y, true, wall_body)
			elif t == LevelData.GARAGE_DOOR:
				_build_garage(lv, root, x, y, wall_body)
	_flush_surfaces(root)

func _floor_name(t: int, level_id: int) -> String:
	if t == LevelData.RUG:
		return "rug"
	if t == LevelData.HOLE:
		return "hole"
	if level_id == 0:
		if t == LevelData.TILEW:
			return "tile"
		return "wood"
	if level_id == 1:
		return "attic"
	if level_id == 2 or level_id == 3:
		return "concrete"
	return "wood"

func _door_axis(lv: LevelData, x: int, y: int) -> String:
	var sx := LevelData.SOLID[lv.get_tile(x - 1, y)] and LevelData.SOLID[lv.get_tile(x + 1, y)]
	var sz := LevelData.SOLID[lv.get_tile(x, y - 1)] and LevelData.SOLID[lv.get_tile(x, y + 1)]
	if sz and not sx:
		return "z"
	return "x"

func _build_door(lv: LevelData, root: Node3D, x: int, y: int, front: bool, wall_body: StaticBody3D) -> void:
	var door := lv.door_at(x, y)
	if door == null:
		door = LevelData.Door.new()
		door.x = x
		door.y = y
		door.front = front
		lv.doors.append(door)
	var axis := _door_axis(lv, x, y)
	var pivot := Node3D.new()
	pivot.name = "Door_%d_%d" % [x, y]
	root.add_child(pivot)
	var body := StaticBody3D.new()
	pivot.add_child(body)
	var shape := BoxShape3D.new()
	var leaf: MeshInstance3D
	var mat_name := "front_door" if front else "door"
	if axis == "x":
		pivot.position = Vector3(x + 0.04, 0, y + 0.5)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.92, 2.06, 0.07)
		leaf = MeshInstance3D.new()
		leaf.mesh = bm
		leaf.material_override = Mats.mat(mat_name)
		leaf.position = Vector3(0.46, 1.03, 0)
		pivot.add_child(leaf)
		shape.size = Vector3(0.92, 2.06, 0.07)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(0.46, 1.03, 0)
		body.add_child(cs)
		# Panels and a brass knob on the leaf.
		for side in [-1.0, 1.0]:
			for py in [-0.32, 0.34]:
				_box(leaf, Vector3(0.58, 0.50, 0.02), Vector3(0, py, side * 0.045), "wood_light")
			_box(leaf, Vector3(0.055, 0.055, 0.055), Vector3(0.33, 0.0, side * 0.055), "brass")
		# frame (stays in place while the leaf swings)
		_box(root, Vector3(0.09, 2.10, 0.16), Vector3(x + 0.02, 1.05, y + 0.5), "wood_dark")
		_box(root, Vector3(0.09, 2.10, 0.16), Vector3(x + 0.98, 1.05, y + 0.5), "wood_dark")
		_box(root, Vector3(1.05, 0.09, 0.16), Vector3(x + 0.5, 2.10, y + 0.5), "wood_dark")
	else:
		pivot.position = Vector3(x + 0.5, 0, y + 0.04)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 2.06, 0.92)
		leaf = MeshInstance3D.new()
		leaf.mesh = bm
		leaf.material_override = Mats.mat(mat_name)
		leaf.position = Vector3(0, 1.03, 0.46)
		pivot.add_child(leaf)
		shape.size = Vector3(0.07, 2.06, 0.92)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(0, 1.03, 0.46)
		body.add_child(cs)
		for side in [-1.0, 1.0]:
			for py in [-0.32, 0.34]:
				_box(leaf, Vector3(0.02, 0.50, 0.58), Vector3(side * 0.045, py, 0), "wood_light")
			_box(leaf, Vector3(0.055, 0.055, 0.055), Vector3(side * 0.055, 0.0, 0.33), "brass")
		_box(root, Vector3(0.14, 2.08, 0.06), Vector3(x + 0.5, 1.04, y + 0.02), "wood_dark")
		_box(root, Vector3(0.14, 2.08, 0.06), Vector3(x + 0.5, 1.04, y + 0.98), "wood_dark")
		_box(root, Vector3(0.14, 0.08, 1.0), Vector3(x + 0.5, 2.08, y + 0.5), "wood_dark")
	# lintel above the opening
	var lintel := StaticBody3D.new()
	root.add_child(lintel)
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(1.0, WALL_H - 2.08, 1.0)
	var lcs := CollisionShape3D.new()
	lcs.shape = lshape
	lcs.position = Vector3(x + 0.5, 2.08 + (WALL_H - 2.08) * 0.5, y + 0.5)
	lintel.add_child(lcs)
	_box(root, Vector3(1.0, WALL_H - 2.08, 1.0), Vector3(x + 0.5, 2.08 + (WALL_H - 2.08) * 0.5, y + 0.5), "plaster")
	var entry := {
		"door": door,
		"pivot": pivot,
		"base": 0.0,
		"sign": 1.0 if axis == "x" else 1.0,
		"body": body,
		"shape": body.get_child(0),
		"axis": axis,
	}
	door_entries.append(entry)
	if front:
		front_entry = entry
		# three padlocks on the inside face
		for i in 3:
			var lm := _box(leaf, Vector3(0.10, 0.13, 0.08), Vector3(0.78, 1.45 - i * 0.24, -0.06), "lock")
			lock_meshes.append(lm)

func _build_garage(lv: LevelData, root: Node3D, x: int, y: int, _wall_body: StaticBody3D) -> void:
	if garage_node != null:
		return
	garage_node = Node3D.new()
	garage_node.name = "GarageDoor"
	garage_node.position = Vector3(8.0, 0, 14.5)
	root.add_child(garage_node)
	var bm := BoxMesh.new()
	bm.size = Vector3(6.0, WALL_H, 0.14)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = Mats.mat("garage_door")
	mi.position = Vector3(0, WALL_H * 0.5, 0)
	garage_node.add_child(mi)
	for i in 6:
		_box(garage_node, Vector3(5.9, 0.05, 0.17), Vector3(0, 0.25 + i * 0.42, 0), "metal")
	var body := StaticBody3D.new()
	garage_node.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, WALL_H, 0.14)
	garage_shape = CollisionShape3D.new()
	garage_shape.shape = shape
	garage_shape.position = Vector3(0, WALL_H * 0.5, 0)
	body.add_child(garage_shape)

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

# ------------------------------------------------------------------ furniture

func _front_dir(rot: int) -> Vector3:
	match rot % 4:
		0: return Vector3(0, 0, -1)
		1: return Vector3(-1, 0, 0)
		2: return Vector3(0, 0, 1)
	return Vector3(1, 0, 0)

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

func _front_panel(parent: Node3D, d: LevelData.Deco, width: float, height: float, y: float, dist: float, mat_name: String) -> MeshInstance3D:
	var f := _front_dir(d.rot)
	if absf(f.z) > 0.5:
		return _box(parent, Vector3(width, height, 0.045), Vector3(0, y, f.z * dist), mat_name)
	return _box(parent, Vector3(0.045, height, width), Vector3(f.x * dist, y, 0), mat_name)

func _deco_height(d: LevelData.Deco) -> float:
	if d.is_car:
		return 1.35
	if d.is_cradle:
		return 0.65
	match d.kind:
		0: return 0.78
		1: return 0.80
		2: return 0.98
		3: return 0.66
		4: return 0.88
		5: return 2.05
		6: return 0.95
		7: return 1.80
		8: return 0.94
		9: return 1.85
		10: return 1.18
		11: return 0.96
		12: return 0.62
		13: return 0.80
		14: return 0.34
		15: return 1.86
		16: return 0.16
		17: return 1.75
		18: return 1.75
	return 0.8

func _build_decos(lv: LevelData, root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "DecoCollision"
	root.add_child(body)
	for d in lv.decos:
		var n := Node3D.new()
		n.name = "Deco_%s" % d.name
		n.position = Vector3(d.x, 0, d.y)
		root.add_child(n)
		d.node = n
		if d.is_car:
			_build_car(n, d)
		elif d.is_cradle:
			_build_cradle(n, d)
		else:
			_build_furn(n, d)
		if d.solid:
			var h := _deco_height(d)
			var cy := h * 0.5
			if d.kind == 13:
				cy = 1.65
			elif d.kind == 14:
				cy = 0.78
			elif d.kind == 16:
				cy = 0.08
			var shape := BoxShape3D.new()
			shape.size = Vector3(d.rx * 2.0, h, d.ry * 2.0)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(d.x, cy, d.y)
			body.add_child(cs)

func _build_furn(n: Node3D, d: LevelData.Deco) -> void:
	var w := d.rx * 2.0
	var dep := d.ry * 2.0
	var f := _front_dir(d.rot)
	match d.kind:
		0: # bed
			_box(n, Vector3(w, 0.30, dep), Vector3(0, 0.20, 0), "wood_dark")
			_box(n, Vector3(w - 0.06, 0.20, dep - 0.06), Vector3(0, 0.44, 0), "mattress")
			var long_x := w >= dep
			if long_x:
				_box(n, Vector3(0.10, 0.85, dep), Vector3(-w * 0.5 + 0.05, 0.45, 0), "wood_dark")
				_box(n, Vector3(w * 0.34, 0.11, dep * 0.55), Vector3(-w * 0.30, 0.58, 0), "paper")
				_box(n, Vector3(w * 0.56, 0.09, dep - 0.10), Vector3(w * 0.14, 0.56, 0), "fabric_red")
			else:
				_box(n, Vector3(w, 0.85, 0.10), Vector3(0, 0.45, -dep * 0.5 + 0.05), "wood_dark")
				_box(n, Vector3(w * 0.55, 0.11, dep * 0.34), Vector3(0, 0.58, -dep * 0.30), "paper")
				_box(n, Vector3(w - 0.10, 0.09, dep * 0.56), Vector3(0, 0.56, dep * 0.14), "fabric_red")
		1: # table
			_box(n, Vector3(w, 0.09, dep), Vector3(0, 0.77, 0), "wood_light")
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_box(n, Vector3(0.08, 0.73, 0.08), Vector3(sx * (w * 0.5 - 0.10), 0.365, sz * (dep * 0.5 - 0.10)), "wood_dark")
			_box(n, Vector3(w * 0.45, 0.12, dep * 0.55), Vector3(0, 0.66, 0), "wood_dark")
		2: # sofa
			_box(n, Vector3(w, 0.36, dep), Vector3(0, 0.22, 0), "fabric_green")
			_box(n, Vector3(w, 0.55, 0.16), Vector3(0, 0.55, -f.z * (dep * 0.5 - 0.08) - f.x * 0.0), "fabric_green")
			_box(n, Vector3(0.16, 0.52, dep), Vector3(-f.x * 0.0 - w * 0.5 + 0.08, 0.48, 0), "fabric_green")
			_box(n, Vector3(0.16, 0.52, dep), Vector3(w * 0.5 - 0.08, 0.48, 0), "fabric_green")
			for i in 3:
				_box(n, Vector3(w * 0.28, 0.12, dep * 0.62), Vector3((i - 1) * w * 0.29, 0.48, f.z * dep * 0.10), "fabric_blue" if i == 1 else "fabric_green")
		3: # crate / chest
			_box(n, Vector3(w, 0.52, dep), Vector3(0, 0.28, 0), "wood_dark")
			_box(n, Vector3(w + 0.03, 0.08, dep + 0.03), Vector3(0, 0.58, 0), "wood_light")
			for i in 3:
				_box(n, Vector3(w + 0.02, 0.035, 0.04), Vector3(0, 0.15 + i * 0.14, -f.z * (dep * 0.5 + 0.01)), "wood_light")
			_box(n, Vector3(0.12, 0.10, 0.05), Vector3(0, 0.50, -f.z * (dep * 0.5 + 0.02)), "lock")
		4: # desk / workbench
			_box(n, Vector3(w, 0.10, dep), Vector3(0, 0.82, 0), "wood_light")
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_box(n, Vector3(0.09, 0.77, 0.09), Vector3(sx * (w * 0.5 - 0.09), 0.385, sz * (dep * 0.5 - 0.09)), "wood_dark")
			_box(n, Vector3(w * 0.38, 0.20, dep * 0.62), Vector3(w * 0.25, 0.68, 0), "wood_dark")
			_box(n, Vector3(0.30, 0.10, 0.20), Vector3(-w * 0.22, 0.91, 0), "metal")
		5: # wardrobe
			_box(n, Vector3(w, 1.98, dep), Vector3(0, 0.99, 0), "wood_dark")
			_box(n, Vector3(w + 0.04, 0.08, dep + 0.04), Vector3(0, 2.00, 0), "wood_light")
			for i in 2:
				_front_panel(n, d, w * 0.44, 1.72, 1.00, dep * 0.5 + 0.025, "wood_light")
				var side := -1.0 if i == 0 else 1.0
				var hx := side * w * 0.08
				if absf(f.z) > 0.5:
					_box(n, Vector3(0.035, 0.22, 0.035), Vector3(hx, 1.00, f.z * (dep * 0.5 + 0.06)), "brass")
				else:
					_box(n, Vector3(0.035, 0.22, 0.035), Vector3(f.x * (dep * 0.5 + 0.06), 1.00, hx), "brass")
		6: # dresser / chest of drawers
			_box(n, Vector3(w, 0.86, dep), Vector3(0, 0.45, 0), "wood_dark")
			_box(n, Vector3(w + 0.04, 0.06, dep + 0.04), Vector3(0, 0.90, 0), "wood_light")
			for i in 3:
				_front_panel(n, d, w * 0.84, 0.20, 0.22 + i * 0.23, dep * 0.5 + 0.02, "wood_light")
				if absf(f.z) > 0.5:
					_box(n, Vector3(0.12, 0.035, 0.035), Vector3(0, 0.22 + i * 0.23, f.z * (dep * 0.5 + 0.05)), "brass")
				else:
					_box(n, Vector3(0.035, 0.035, 0.12), Vector3(f.x * (dep * 0.5 + 0.05), 0.22 + i * 0.23, 0), "brass")
		7: # fridge
			_box(n, Vector3(w, 1.72, dep), Vector3(0, 0.88, 0), "white")
			_front_panel(n, d, w * 0.90, 0.62, 1.40, dep * 0.5 + 0.02, "white")
			_front_panel(n, d, w * 0.90, 0.98, 0.55, dep * 0.5 + 0.02, "white")
			if absf(f.z) > 0.5:
				_box(n, Vector3(0.04, 0.42, 0.04), Vector3(w * 0.38, 1.20, f.z * (dep * 0.5 + 0.05)), "metal")
			else:
				_box(n, Vector3(0.04, 0.42, 0.04), Vector3(f.x * (dep * 0.5 + 0.05), 1.20, w * 0.38), "metal")
		8: # stove
			_box(n, Vector3(w, 0.88, dep), Vector3(0, 0.46, 0), "white")
			_box(n, Vector3(w, 0.05, dep), Vector3(0, 0.91, 0), "black")
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_cyl(n, 0.085, 0.02, Vector3(sx * w * 0.24, 0.935, sz * dep * 0.24), "metal")
			_front_panel(n, d, w * 0.78, 0.42, 0.42, dep * 0.5 + 0.02, "black")
			_front_panel(n, d, w * 0.70, 0.05, 0.72, dep * 0.5 + 0.03, "metal")
		9: # shelf / bookcase
			_box(n, Vector3(w, 1.80, 0.06), Vector3(0, 0.92, -f.z * (dep * 0.5 - 0.03) - f.x * 0.0), "wood_dark")
			_box(n, Vector3(0.06, 1.80, dep), Vector3(-w * 0.5 + 0.03, 0.92, 0), "wood_dark")
			_box(n, Vector3(0.06, 1.80, dep), Vector3(w * 0.5 - 0.03, 0.92, 0), "wood_dark")
			for i in 5:
				_box(n, Vector3(w - 0.08, 0.05, dep - 0.04), Vector3(0, 0.22 + i * 0.36, 0), "wood_light")
				if i < 4:
					for b in 5:
						var bw := 0.055
						var bh := 0.22 + fmod(float(b * 7 + i * 3), 0.08)
						var colors := ["fabric_red", "fabric_green", "fabric_blue", "paper", "red"]
						_box(n, Vector3(bw, bh, dep * 0.62), Vector3(-w * 0.36 + b * w * 0.16, 0.27 + i * 0.36 + bh * 0.5, 0), colors[(b + i) % colors.size()])
		10: # TV
			_box(n, Vector3(w, 0.42, dep), Vector3(0, 0.24, 0), "wood_dark")
			_box(n, Vector3(w * 0.82, 0.58, dep * 0.55), Vector3(0, 0.78, 0), "black")
			_front_panel(n, d, w * 0.70, 0.44, 0.80, dep * 0.28 + 0.02, "screen")
			_box(n, Vector3(0.04, 0.26, 0.04), Vector3(w * 0.32, 0.40, 0), "metal")
		11: # chair
			_box(n, Vector3(w, 0.07, dep), Vector3(0, 0.46, 0), "wood_light")
			_box(n, Vector3(w, 0.58, 0.06), Vector3(0, 0.75, -f.z * (dep * 0.5 - 0.04)), "wood_dark")
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_box(n, Vector3(0.055, 0.45, 0.055), Vector3(sx * (w * 0.5 - 0.06), 0.225, sz * (dep * 0.5 - 0.06)), "wood_dark")
		12: # nightstand
			_box(n, Vector3(w, 0.55, dep), Vector3(0, 0.28, 0), "wood_dark")
			_front_panel(n, d, w * 0.78, 0.18, 0.32, dep * 0.5 + 0.02, "wood_light")
			_box(n, Vector3(0.10, 0.035, 0.035), Vector3(0, 0.32, f.z * (dep * 0.5 + 0.05)), "brass")
			_box(n, Vector3(0.16, 0.10, 0.16), Vector3(0, 0.62, 0), "lamp")
		13: # hanging cabinet
			_box(n, Vector3(w, 0.72, dep), Vector3(0, 1.55, 0), "wood_dark")
			_front_panel(n, d, w * 0.44, 0.60, 1.55, dep * 0.5 + 0.025, "wood_light")
			_front_panel(n, d, w * 0.44, 0.60, 1.55, dep * 0.5 + 0.028, "wood_light")
			_box(n, Vector3(0.04, 0.20, 0.04), Vector3(-w * 0.08, 1.55, f.z * (dep * 0.5 + 0.06)), "brass")
			_box(n, Vector3(0.04, 0.20, 0.04), Vector3(w * 0.08, 1.55, f.z * (dep * 0.5 + 0.06)), "brass")
		14: # pot
			_cyl(n, minf(w, dep) * 0.48, 0.26, Vector3(0, 0.80, 0), "metal")
			_box(n, Vector3(0.03, 0.03, 0.16), Vector3(-w * 0.48, 0.86, 0), "metal")
			_box(n, Vector3(0.03, 0.03, 0.16), Vector3(w * 0.48, 0.86, 0), "metal")
		15: # coat rack
			_cyl(n, 0.22, 0.05, Vector3(0, 0.025, 0), "wood_dark")
			_cyl(n, 0.045, 1.75, Vector3(0, 0.88, 0), "wood_dark")
			for i in 4:
				var a := i * PI * 0.5
				_box(n, Vector3(0.03, 0.03, 0.34), Vector3(cos(a) * 0.16, 1.68, sin(a) * 0.16), "brass", a)
		16: # shoes
			for i in 4:
				_box(n, Vector3(0.20, 0.10, 0.34), Vector3(-w * 0.4 + (i % 2) * w * 0.55, 0.06, -dep * 0.15 + (i / 2) * dep * 0.45), "black")
		17, 18: # floor lamp
			_cyl(n, 0.24, 0.05, Vector3(0, 0.03, 0), "metal")
			_cyl(n, 0.035, 1.55, Vector3(0, 0.78, 0), "metal")
			_cyl(n, 0.28, 0.32, Vector3(0, 1.62, 0), "lamp")
			var light := OmniLight3D.new()
			light.position = Vector3(0, 1.55, 0)
			light.light_color = Color(1.0, 0.72, 0.38)
			light.light_energy = 0.9
			light.omni_range = 4.5
			light.shadow_enabled = false
			n.add_child(light)

func _build_car(n: Node3D, _d: LevelData.Deco) -> void:
	# Body and chassis.
	_box(n, Vector3(4.1, 0.52, 1.68), Vector3(0, 0.58, 0), "car")
	_box(n, Vector3(4.16, 0.14, 1.74), Vector3(0, 0.40, 0), "black")
	# Cabin: red pillars and roof, with dark glass let into the sides.
	_box(n, Vector3(2.25, 0.58, 1.52), Vector3(-0.15, 1.02, 0), "car")
	_box(n, Vector3(2.05, 0.08, 1.40), Vector3(-0.15, 1.34, 0), "car")
	_box(n, Vector3(1.95, 0.36, 0.035), Vector3(-0.15, 1.14, 0.765), "car_glass")
	_box(n, Vector3(1.95, 0.36, 0.035), Vector3(-0.15, 1.14, -0.765), "car_glass")
	_box(n, Vector3(0.035, 0.36, 1.30), Vector3(0.93, 1.14, 0), "car_glass")
	_box(n, Vector3(0.035, 0.36, 1.30), Vector3(-1.23, 1.14, 0), "car_glass")
	# Hood, bumpers, lights and wheels.
	_box(n, Vector3(0.55, 0.08, 1.55), Vector3(1.72, 0.88, 0), "car")
	_box(n, Vector3(0.16, 0.20, 1.72), Vector3(2.05, 0.52, 0), "metal")
	_box(n, Vector3(0.16, 0.20, 1.72), Vector3(-2.05, 0.52, 0), "metal")
	for i in 2:
		_cyl(n, 0.09, 0.05, Vector3(1.96, 0.72, -0.52 + i * 1.04), "lamp", 0, PI * 0.5)
	for sx in [-1.35, 1.35]:
		for sz in [-0.86, 0.86]:
			_cyl(n, 0.31, 0.20, Vector3(sx, 0.34, sz), "black", PI * 0.5, 0)
			_cyl(n, 0.15, 0.22, Vector3(sx, 0.34, sz), "metal", PI * 0.5, 0)
	_box(n, Vector3(0.05, 0.16, 0.10), Vector3(-2.0, 0.62, 0.62), "red")
	_box(n, Vector3(0.05, 0.16, 0.10), Vector3(-2.0, 0.62, -0.62), "red")

func _build_cradle(n: Node3D, d: LevelData.Deco) -> void:
	var w := d.rx * 2.0
	var dep := d.ry * 2.0
	_box(n, Vector3(w, 0.32, dep), Vector3(0, 0.45, 0), "wood_light")
	_box(n, Vector3(w * 0.92, 0.10, dep * 0.86), Vector3(0, 0.66, 0), "mattress")
	for sx in [-1.0, 1.0]:
		_cyl(n, 0.05, w, Vector3(0, 0.14, sx * dep * 0.32), "wood_dark", 0, PI * 0.5)
	_box(n, Vector3(0.08, 0.55, dep), Vector3(-w * 0.46, 0.70, 0), "wood_light")
	_box(n, Vector3(0.08, 0.55, dep), Vector3(w * 0.46, 0.70, 0), "wood_light")
	_box(n, Vector3(0.08, 0.45, dep), Vector3(0, 0.80, -dep * 0.46), "wood_light")

# ------------------------------------------------------------------ lamps, traps, webs, spiders

func _build_lamps(lv: LevelData, root: Node3D) -> void:
	for p in lv.lamps:
		var pos := Vector3(p.x, p.y, p.z)
		var bulb := _cyl(root, 0.055, 0.10, pos, "lamp")
		bulb.rotation = Vector3.ZERO
		_cyl(root, 0.012, maxf(0.05, WALL_H - p.y), Vector3(p.x, (WALL_H + p.y) * 0.5, p.z), "black")
		var shade := _cyl(root, 0.18, 0.10, Vector3(p.x, p.y + 0.09, p.z), "metal")
		shade.rotation = Vector3.ZERO
		var light := OmniLight3D.new()
		light.position = Vector3(p.x, p.y - 0.08, p.z)
		light.light_color = Color(1.0, 0.74, 0.42)
		light.light_energy = 2.0
		light.omni_range = 8.0
		light.omni_attenuation = 1.15
		light.shadow_enabled = false
		root.add_child(light)

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

func _build_traps(lv: LevelData, _root: Node3D) -> void:
	for t in lv.traps:
		make_trap_node(lv, t)

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

func _web_texture() -> ImageTexture:
	if _web_tex != null:
		return _web_tex
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(s * 0.5, s * 0.5)
	for i in 16:
		var a := float(i) / 16.0 * TAU
		for r in range(8, 126):
			var x := int(c.x + cos(a) * r)
			var y := int(c.y + sin(a) * r)
			for oy in 2:
				for ox in 2:
					if x + ox >= 0 and y + oy >= 0 and x + ox < s and y + oy < s:
						img.set_pixel(x + ox, y + oy, Color(0.82, 0.84, 0.82, 0.34))
	for ring in [28, 52, 76, 100, 122]:
		for i in 360:
			var a := float(i) / 360.0 * TAU
			var x := int(c.x + cos(a) * ring)
			var y := int(c.y + sin(a) * ring)
			for oy in 2:
				for ox in 2:
					if x + ox >= 0 and y + oy >= 0 and x + ox < s and y + oy < s:
						img.set_pixel(x + ox, y + oy, Color(0.76, 0.78, 0.76, 0.26))
	_web_tex = ImageTexture.create_from_image(img)
	return _web_tex

func _build_webs(lv: LevelData, root: Node3D) -> void:
	for w in lv.webs:
		var quad := QuadMesh.new()
		quad.size = Vector2(w.size.x, w.size.y)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		var m := StandardMaterial3D.new()
		m.albedo_texture = _web_texture()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(1, 1, 1, 0.58)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mi.material_override = m
		mi.position = Vector3(w.position.x + w.size.x * 0.5, 0.03, w.position.y + w.size.y * 0.5)
		mi.rotation.x = -PI * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		web_nodes.append(mi)

func _build_spiders(lv: LevelData, root: Node3D) -> void:
	var pts := [Vector2(7.0, 6.0), Vector2(13.0, 10.75), Vector2(9.0, 14.25)]
	for p in pts:
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
