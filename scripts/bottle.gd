class_name ThrownBottle
extends Node3D

# Брошенная бутылка. Летит по локальным координатам уровня,
# звенит и уводит Гренни в другую комнату.

var game: Node
var level := 0
var x := 0.0
var y := 0.0
var z := 1.23
var vx := 0.0
var vy := 0.0
var vz := 0.0
var life := 0.0
var broken := false

func setup(g: Node, lv: int, px: float, py: float, pz: float, pvx: float, pvy: float, pvz: float) -> void:
	game = g
	level = lv
	x = px
	y = py
	z = pz
	vx = pvx
	vy = pvy
	vz = pvz
	var root: Node3D = g.world.get_root(lv)
	root.add_child(self)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.06
	cm.height = 0.24
	cm.radial_segments = 10
	body.mesh = cm
	body.material_override = Mats.mat("bottle")
	add_child(body)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.025
	nm.bottom_radius = 0.04
	nm.height = 0.10
	nm.radial_segments = 8
	neck.mesh = nm
	neck.material_override = Mats.mat("bottle")
	neck.position.y = 0.16
	add_child(neck)
	position = Vector3(x, z, y)

func update(dt: float, g: Node) -> void:
	if broken:
		return
	life += dt
	var lv: LevelData = g.world.levels[level]
	for s in 3:
		var sdt := dt / 3.0
		vz -= 11.0 * sdt
		var nx := x + vx * sdt
		var ny := y + vy * sdt
		var nz := z + vz * sdt
		var hit_wall: bool = lv.solid_at(nx, y) or lv.solid_at(x, ny)
		if hit_wall:
			vx *= -0.25
			vy *= -0.25
			if absf(vz) < 1.5:
				g.break_bottle(self)
				return
		else:
			x = nx
			y = ny
		# бутылка захлопывает капкан
		var tt = lv.trap_near(x, y, 0.35)
		if tt != null and tt.armed:
			tt.armed = false
			tt.triggered_t = g.time
			if tt.node != null:
				tt.node.set_armed(false)
			Audio.play("snap", 0.6, 1.2)
			g.break_bottle(self)
			return
		if nz < 0.06:
			z = 0.06
			if absf(vz) > 2.2:
				vz = -vz * 0.42
				vx *= 0.6
				vy *= 0.6
			else:
				g.break_bottle(self)
				return
		else:
			z = nz
	position = Vector3(x, z, y)
	rotation.y += dt * 7.0
	rotation.x += dt * 3.0
	if life > 6.0 or absf(vx) + absf(vy) < 0.05:
		g.break_bottle(self)
