class_name PlayerBody
extends CharacterBody3D

# Игрок от первого лица: две руки с фонариком и предметом, плавные
# анимации (подъём, осмотр, качание, присед), шаги по поверхностям,
# пылинки в свете, тач-ввод. Viewmodel затекстурен и освещён
# (раньше был плоским UNSHADED и умел только фонарик).

const EYE_H := 1.55

var game: Node
var level := 0
var angle := 0.0
var pitch := 0.0
var crouch := false
var hidden := false
var hide_spot = null
var stamina := 1.0
var health := 1.0
var battery := 1.0
var trap_stuck := 0.0
var trap_mash := 0.0
var bob := 0.0
var step_acc := 0.0
var move_speed := 0.0
var dead := false
var flashlight_on := true
var reload_t := 0.0
var gun_t := 0.0
var act_push := 0.0
var act_throw := 0.0
var aim_k := 0.0
var mouse_sensitivity := 1.0

var camera: Camera3D
var flashlight: SpotLight3D
var shape_node: CollisionShape3D

# --- парящий предмет (вместо рук) ---
var held_id := 0
var item_root: Node3D
var _item_nodes: Dictionary = {}
var _appear_k := 1.0
var _inspect_t := -1.0
var _crouch_k := 0.0
var _strafe_k := 0.0
var _item_mat_cache: Dictionary = {}

var _dust: GPUParticles3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 1.70
	shape_node = CollisionShape3D.new()
	shape_node.shape = cap
	shape_node.position = Vector3(0, 0.85, 0)
	add_child(shape_node)
	camera = Camera3D.new()
	camera.position = Vector3(0, EYE_H, 0)
	camera.fov = 75.0
	camera.current = true
	add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.16, -0.08, -0.12)
	flashlight.spot_range = 15.0
	flashlight.spot_angle = 28.0
	flashlight.spot_attenuation = 1.25
	flashlight.light_energy = 1.30
	flashlight.light_color = Color(1.0, 0.94, 0.80)
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)
	_build_item_float()
	_build_dust()

func setup(pgame: Node) -> void:
	game = pgame

# ------------------------------------------------------------------ материалы/примитивы

func _limb(parent: Node3D, radius: float, from: Vector3, to: Vector3, mat: Material) -> MeshInstance3D:
	var d := to - from
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(d.length(), radius * 2.0 + 0.01)
	cm.radial_segments = 12 if Mats.quality() == 0 else 16
	cm.rings = 5 if Mats.quality() == 0 else 8
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = (from + to) * 0.5
	mi.quaternion = Quaternion(Vector3.UP, d.normalized())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _cyl_mesh(r_top: float, r_bot: float, h: float, seg: int = 14) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	return cm

# ------------------------------------------------------------------ парящий предмет

# Предмет не держат руки — он парит перед камерой чуть правее центра,
# слегка покачивается и вращается при осмотре (X).
func _build_item_float() -> void:
	item_root = Node3D.new()
	item_root.name = "ItemFloat"
	item_root.position = Vector3(0.235, -0.155, -0.565)
	camera.add_child(item_root)
	_build_item_models(item_root)
	item_root.visible = false

func _imat(name: String) -> StandardMaterial3D:
	if not _item_mat_cache.has(name):
		_item_mat_cache[name] = Mats.mat(name)
	return _item_mat_cache[name]

func _build_item_models(slot: Node3D) -> void:
	# Каждая модель предмета — компактный узел перед камерой.
	var brass := _imat("brass")
	var metal := _imat("metal")
	var red := _imat("red")
	var paper := _imat("paper")
	var white := _imat("white")
	var black := _imat("black")
	var glass := _imat("bottle")
	var wood := _imat("wood_dark")

	# КЛЮЧ (1)
	var key := Node3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.008
	ring.outer_radius = 0.017
	ring.rings = 12
	ring.ring_segments = 6
	_part(key, ring, Vector3.ZERO, brass)
	_part(key, BoxMesh.new(), Vector3(0.024, -0.004, 0.0), brass, Vector3(0.05, 0.006, 0.014))
	_part(key, BoxMesh.new(), Vector3(0.038, -0.008, 0.0), brass, Vector3(0.012, 0.012, 0.010))
	slot.add_child(key)
	_item_nodes[1] = key

	# МОНТИРОВКА (2)
	var crow := Node3D.new()
	var shaft := _cyl_mesh(0.010, 0.011, 0.26, 10)
	_part(crow, shaft, Vector3.ZERO, red, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))
	_part(crow, BoxMesh.new(), Vector3(-0.135, 0.014, 0.0), red, Vector3(0.045, 0.020, 0.018), Vector3(0.0, 0.0, 0.6))
	_part(crow, BoxMesh.new(), Vector3(0.132, 0.010, 0.0), red, Vector3(0.030, 0.016, 0.016), Vector3(0.0, 0.0, -0.5))
	slot.add_child(crow)
	_item_nodes[2] = crow

	# ЗАПИСКА / ЗАПИСКА-2 / ФОТО (3, 13, 14)
	for trio in [[3, 0.0], [13, 0.05], [14, -0.04]]:
		var np := Node3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.09, 0.12)
		_part(np, plane, Vector3.ZERO, paper, Vector3.ONE, Vector3(-PI * 0.5 + 0.25, 0.0, float(trio[1])))
		_part(np, plane, Vector3(0.004, 0.004, 0.006), paper, Vector3(0.92, 0.92, 1.0), Vector3(-PI * 0.5 + 0.35, 0.08, float(trio[1]) + 0.05))
		slot.add_child(np)
		_item_nodes[int(trio[0])] = np

	# МОЛОКО (4)
	var milk := Node3D.new()
	_part(milk, _cyl_mesh(0.030, 0.034, 0.13, 12), Vector3.ZERO, white)
	_part(milk, _cyl_mesh(0.018, 0.024, 0.03, 10), Vector3(0.0, 0.078, 0.0), white)
	slot.add_child(milk)
	_item_nodes[4] = milk

	# БАТАРЕЙКА (5)
	var bat := Node3D.new()
	_part(bat, _cyl_mesh(0.016, 0.016, 0.085, 12), Vector3.ZERO, black, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))
	_part(bat, _cyl_mesh(0.006, 0.006, 0.01, 8), Vector3(0.046, 0.0, 0.0), brass, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))
	slot.add_child(bat)
	_item_nodes[5] = bat

	# БИНТ (6)
	var band := Node3D.new()
	_part(band, _cyl_mesh(0.034, 0.034, 0.05, 14), Vector3.ZERO, white, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))
	_part(band, _cyl_mesh(0.010, 0.010, 0.02, 8), Vector3(0.0, 0.0, 0.0), paper, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))
	slot.add_child(band)
	_item_nodes[6] = band

	# БУТЫЛКА (7)
	var bot := Node3D.new()
	_part(bot, _cyl_mesh(0.030, 0.033, 0.15, 12), Vector3(0.0, 0.02, 0.0), glass)
	_part(bot, _cyl_mesh(0.012, 0.024, 0.06, 10), Vector3(0.0, 0.12, 0.0), glass)
	slot.add_child(bot)
	_item_nodes[7] = bot

	# АРБАЛЕТ (8)
	var cb := Node3D.new()
	_part(cb, BoxMesh.new(), Vector3(0.0, 0.0, -0.06), wood, Vector3(0.030, 0.042, 0.30))
	_part(cb, BoxMesh.new(), Vector3(0.0, 0.026, -0.19), metal, Vector3(0.30, 0.014, 0.014))
	_part(cb, BoxMesh.new(), Vector3(0.0, 0.010, -0.19), black, Vector3(0.28, 0.003, 0.003))
	_part(cb, BoxMesh.new(), Vector3(0.0, 0.02, -0.055), brass, Vector3(0.02, 0.024, 0.05))
	slot.add_child(cb)
	_item_nodes[8] = cb

	# ДАРТ (9)
	var dart := Node3D.new()
	_part(dart, _cyl_mesh(0.004, 0.004, 0.16, 8), Vector3(0.0, 0.0, -0.04), metal, Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	_part(dart, BoxMesh.new(), Vector3(0.0, 0.0, 0.06), red, Vector3(0.02, 0.004, 0.035))
	slot.add_child(dart)
	_item_nodes[9] = dart

	# КЛЮЧ ОТ МАШИНЫ (11)
	var ckey := Node3D.new()
	_part(ckey, BoxMesh.new(), Vector3(0.0, 0.0, 0.0), black, Vector3(0.016, 0.008, 0.05))
	_part(ckey, BoxMesh.new(), Vector3(0.0, -0.004, -0.036), brass, Vector3(0.014, 0.004, 0.026))
	slot.add_child(ckey)
	_item_nodes[11] = ckey

	# АККУМУЛЯТОР (12)
	var acc := Node3D.new()
	_part(acc, BoxMesh.new(), Vector3(0.0, 0.012, 0.0), black, Vector3(0.13, 0.09, 0.10))
	_part(acc, _cyl_mesh(0.010, 0.010, 0.02, 8), Vector3(-0.04, 0.062, 0.0), brass)
	_part(acc, _cyl_mesh(0.010, 0.010, 0.02, 8), Vector3(0.04, 0.062, 0.0), brass)
	slot.add_child(acc)
	_item_nodes[12] = acc

	# МИШКА (15)
	var ted := Node3D.new()
	var fur := Mats.mat("fabric_red")
	var tb := SphereMesh.new()
	tb.radius = 0.032
	tb.height = 0.07
	_part(ted, tb, Vector3(0.0, 0.03, 0.0), fur, Vector3(0.9, 1.15, 0.8))
	var th := SphereMesh.new()
	th.radius = 0.022
	th.height = 0.05
	_part(ted, th, Vector3(0.0, 0.075, 0.0), fur)
	for sx in [-1.0, 1.0]:
		_part(ted, th, Vector3(sx * 0.018, 0.094, 0.0), fur, Vector3(0.5, 0.5, 0.5))
	var snout := SphereMesh.new()
	snout.radius = 0.010
	snout.height = 0.022
	_part(ted, snout, Vector3(0.0, 0.070, -0.020), black)
	for sx in [-1.0, 1.0]:
		_limb(ted, 0.008, Vector3(sx * 0.026, 0.006, -0.012), Vector3(sx * 0.034, -0.010, -0.028), fur)
	slot.add_child(ted)
	_item_nodes[15] = ted

func set_held(id: int) -> void:
	id = int(id) if _item_nodes.has(int(id)) else 0
	if id == held_id:
		return
	held_id = id
	_appear_k = 0.0  # анимация появления нового предмета
	if _inspect_t >= 0.0:
		_inspect_t = -1.0
	# звуки взятия/дропа играет game.gd (give_item/drop_held)

func start_inspect() -> void:
	if held_id != 0 and _inspect_t < 0.0:
		_inspect_t = 0.0
		Audio.play("ui_move", 0.35, 0.9)

func _build_dust() -> void:
	var q := Mats.quality()
	if q == 0:
		return
	_dust = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.0, 1.1, 2.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.015
	pm.initial_velocity_max = 0.06
	pm.gravity = Vector3(0, 0.006, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	_dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = Mats.tex("dust")
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(1, 1, 1, 0.35)
	quad.material = dm
	_dust.draw_pass_1 = quad
	_dust.amount = 24 if q == 1 else 44
	_dust.lifetime = 7.0
	_dust.local_coords = false
	_dust.position = Vector3(0, 1.0, 0)
	add_child(_dust)

func _process(_dt: float) -> void:
	if item_root == null or game == null:
		return
	var show: bool = game.state == game.STATE_PLAY and not game.journal and not hidden and not dead and held_id != 0
	item_root.visible = show
	if not show:
		return
	var walk := clampf(move_speed / 3.45, 0.0, 1.0)
	var sway := sin(bob) * 0.010 * walk
	var bob_y := absf(cos(bob)) * 0.009 * walk
	var push := act_push
	var throw_k := act_throw
	var aim := aim_k
	# появление предмета: подплывает и проявляется
	_appear_k = minf(1.0, _appear_k + _dt * 3.4)
	var ak := 1.0 - _appear_k
	# осмотр (X): плавно к центру экрана и вращается вокруг оси Y
	var inspect_rot := 0.0
	var inspect_lean := 0.0
	var inspect_zoom := 0.0
	if _inspect_t >= 0.0:
		_inspect_t += _dt
		var k := clampf(_inspect_t / 2.6, 0.0, 1.0)
		inspect_rot = k * TAU * 0.75
		inspect_lean = sin(minf(k * PI, PI)) * 0.55
		inspect_zoom = sin(minf(k * PI, PI)) * 0.16
		if k >= 1.0:
			_inspect_t = -1.0
	# дыхание покоя: очень лёгкое, чтобы предмет не выглядел приклеенным
	var idle := sin(game.time * 1.7) * 0.004
	item_root.rotation.y = inspect_rot + sway * 0.6
	item_root.rotation.x = -0.08 + inspect_lean * 0.4
	item_root.rotation.z = sway * 1.8 + throw_k * 0.5
	item_root.position = Vector3(
		0.235 + sway * 1.6 - inspect_lean * 0.19 + aim * 0.10,
		-0.155 + bob_y + idle - push * 0.03 - ak * 0.14 + inspect_lean * 0.10,
		-0.565 + inspect_zoom - ak * 0.10 - push * 0.03 + aim * 0.16)
	item_root.scale = Vector3.ONE * (0.6 + 0.4 * _appear_k)

func place_at(pid: int, x: float, z: float, a: float) -> void:
	level = pid
	var lv: LevelData = game.world.levels[pid]
	global_position = lv.origin + Vector3(x, 0.02, z)
	angle = a
	pitch = 0.0
	rotation.y = -angle - PI * 0.5
	camera.rotation.x = pitch
	velocity = Vector3.ZERO
	apply_camera()

func _unhandled_input(event: InputEvent) -> void:
	if game == null:
		return
	if not game.can_look():
		return
	if event is InputEventMouseMotion:
		# game типизирован как Node — возвращаемые значения Variant,
		# поэтому тип указываем явно (:= здесь не компилируется)
		var sens: float = mouse_sensitivity * game.look_scale()
		var inv: float = -1.0 if game.invert_look() else 1.0
		angle = wrapf(angle + event.relative.x * 0.0026 * sens, -PI, PI)
		pitch = clampf(pitch - event.relative.y * 0.0022 * sens * inv, -1.35, 1.35)
		if hidden:
			pitch = clampf(pitch, -0.7, 0.7)
	elif event is InputEventScreenDrag:
		# сенсорный осмотр: активная зона устанавливается TouchControls
		if bool(game.get("touch_look_enabled")):
			var tsens: float = mouse_sensitivity * game.look_scale() * 1.6
			var tinv: float = -1.0 if game.invert_look() else 1.0
			angle = wrapf(angle + event.relative.x * 0.0034 * tsens, -PI, PI)
			pitch = clampf(pitch - event.relative.y * 0.0030 * tsens * tinv, -1.35, 1.35)
			if hidden:
				pitch = clampf(pitch, -0.7, 0.7)

func _joy() -> Vector2:
	var v := Vector2.ZERO
	var touch = game.get("touch")
	if touch != null:
		v = touch.joy_vec
	return v

func _physics_process(dt: float) -> void:
	if game == null:
		return
	if game.state != game.STATE_PLAY or game.journal or dead:
		velocity = Vector3.ZERO
		return
	if hidden:
		velocity = Vector3.ZERO
		apply_camera()
		return
	if trap_stuck > 0.0:
		trap_stuck -= dt
		velocity = Vector3.ZERO
		move_and_slide()
		apply_camera()
		if trap_stuck <= 0.0:
			trap_stuck = 0.0
			game.toast_msg("Ты вырвался из капкана!", 2.0, 1)
		return

	var joy := _joy()
	var fwd := 0.0
	var strafe := 0.0
	if joy.length() > 0.15:
		# joy_vec — экранный вектор (вверх = отрицательный y)
		fwd = -joy.y
		strafe = joy.x
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		fwd += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		fwd -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		strafe += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		strafe -= 1.0
	if Input.is_physical_key_pressed(KEY_R):
		angle = wrapf(angle + dt * 1.9, -PI, PI)
	crouch = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C) or bool(game.get("touch_crouch"))
	var want_run := Input.is_physical_key_pressed(KEY_SHIFT) or bool(game.get("touch_run"))
	if joy.length() > 0.92:
		want_run = true  # джойстик до упора = бег
	var moving := absf(fwd) + absf(strafe) > 0.01
	var running := want_run and stamina > 0.05 and moving and not crouch
	var speed := 2.05
	if crouch:
		speed = 1.05
	elif running:
		speed = 3.45
	if moving:
		var dir_len := Vector2(fwd, strafe).length()
		if dir_len > 1.0:
			fwd /= dir_len
			strafe /= dir_len
	if game.in_spider_web():
		speed *= 0.33
	var dir := Vector3.ZERO
	if moving:
		dir = Vector3(cos(angle) * fwd - sin(angle) * strafe, 0.0, sin(angle) * fwd + cos(angle) * strafe).normalized()
	move_speed = speed if moving else 0.0
	_strafe_k = lerpf(_strafe_k, clampf(strafe, -1.0, 1.0), dt * 8.0)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y -= 20.0 * dt
	move_and_slide()

	if moving:
		bob += dt * (11.5 if running else (4.2 if crouch else 7.4))
		step_acc += dt * (3.4 if running else (1.2 if crouch else 2.15))
		if step_acc > 1.0:
			step_acc = 0.0
			_play_step(running, crouch)
	else:
		_strafe_k = lerpf(_strafe_k, 0.0, dt * 8.0)
		if _inspect_t >= 0.0:
			_inspect_t = -1.0  # движение отменяет осмотр

	if running and moving:
		stamina = maxf(0.0, stamina - dt * 0.17)
	else:
		stamina = minf(1.0, stamina + dt * (0.36 if crouch else 0.22))

	if flashlight_on:
		battery = maxf(0.0, battery - dt / maxf(1.0, float(game.diff.battery)))
		if battery <= 0.0:
			flashlight_on = false
			game.toast_msg("Фонарик погас. Найди батарейку!", 3.0, 2)

	if reload_t > 0.0:
		var before := reload_t
		reload_t = maxf(0.0, reload_t - dt)
		if before > 0.55 and reload_t <= 0.55:
			Audio.play("crossbow_reload", 0.55, 1.05)
		if reload_t <= 0.0:
			game.toast_msg("Арбалет заряжен.", 1.4, 0)
	gun_t = maxf(0.0, gun_t - dt * 3.0)
	act_push = maxf(0.0, act_push - dt * 3.4)
	act_throw = maxf(0.0, act_throw - dt * 2.6)
	var aim_hold := (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or bool(game.get("touch_aim"))) and not crouch
	aim_k = move_toward(aim_k, 1.0 if aim_hold else 0.0, dt * 7.0)
	camera.fov = lerpf(75.0, 55.0, aim_k)
	rotation.y = -angle - PI * 0.5
	apply_camera()

var touch = null  # TouchControls; заполняется game'ом (избегаем цикла типов)

func _step_surface() -> String:
	var lv: LevelData = game.world.levels[level]
	var tile: int = lv.get_tile(int(floor(global_position.x - lv.origin.x)), int(floor(global_position.z - lv.origin.z)))
	if tile == LevelData.RUG:
		return "step_rug"
	if tile == LevelData.TILEW:
		return "step_tile"
	if level == 1:
		return "step_wood"
	if level == 2 or level == 3:
		return "step_concrete"
	return "step" if randf() < 0.5 else "step2"

func _play_step(running: bool, sneaking: bool) -> void:
	var vol := 0.5 if running else (0.12 if sneaking else 0.28)
	var pitch_s := 0.9 + randf() * 0.25
	Audio.play(_step_surface(), vol, pitch_s)
	if running:
		game.emit_noise(global_position.x - game.world.levels[level].origin.x, global_position.z - game.world.levels[level].origin.z, 6.2, "шаги")
	elif not sneaking:
		game.emit_noise(global_position.x - game.world.levels[level].origin.x, global_position.z - game.world.levels[level].origin.z, 2.6, "шаги")
	elif randf() < 0.35:
		game.emit_noise(global_position.x - game.world.levels[level].origin.x, global_position.z - game.world.levels[level].origin.z, 0.9, "скрип")

func apply_camera() -> void:
	if camera == null:
		return
	# плавное приседание
	var want_crouch_k := 1.0 if (crouch or hidden) else 0.0
	if hidden and hide_spot != null and hide_spot.is_bed:
		want_crouch_k = 1.6  # ниже, чем обычное приседание
	_crouch_k = lerpf(_crouch_k, want_crouch_k, 0.12)
	if hidden:
		camera.position.y = 0.28 if hide_spot != null and hide_spot.is_bed else 1.18
		camera.position.x = 0.0
		camera.rotation.x = pitch * 0.4
		camera.rotation.z = 0.0
		flashlight.visible = false
		return
	var speed_k := clampf(move_speed / 2.0, 0.0, 1.0)
	var crouch_drop: float = 0.30 * clampf(_crouch_k, 0.0, 1.2)
	camera.position.y = EYE_H + sin(bob * 2.0) * 0.012 * speed_k - crouch_drop
	camera.position.x = 0.0
	camera.rotation.x = pitch + sin(bob) * 0.022 * clampf(move_speed / 3.0, 0.0, 1.0) - act_push * 0.05 - act_throw * 0.03
	# лёгкий крен при стрейфе и покачивание взгляда
	camera.rotation.z = -_strafe_k * 0.022 + sin(bob) * 0.006 * speed_k
	flashlight.visible = flashlight_on and battery > 0.0
	var flick := 1.0
	if battery < 0.18:
		flick = 0.88 + 0.12 * absf(sin(float(game.time) * 23.0))
	flashlight.light_energy = 1.30 * (0.75 + 0.25 * clampf(battery, 0.0, 1.0)) * flick

func enter_hide(h) -> void:
	hidden = true
	hide_spot = h
	crouch = true
	velocity = Vector3.ZERO
	var lv: LevelData = game.world.levels[level]
	global_position = lv.origin + Vector3(h.enter_x + 0.5, 0.02, h.enter_y + 0.5)
	angle = atan2((h.y + 0.5) - (h.enter_y + 0.5), (h.x + 0.5) - (h.enter_x + 0.5))
	pitch = 0.0
	rotation.y = -angle - PI * 0.5
	apply_camera()

func exit_hide() -> void:
	hidden = false
	hide_spot = null
	crouch = false
	apply_camera()

func hurt(amount: float) -> void:
	health = maxf(0.05, health - amount)

func heal(amount: float) -> void:
	health = minf(1.0, health + amount)

func add_battery(amount: float) -> void:
	battery = minf(1.0, battery + amount)

func reset_state() -> void:
	dead = false
	hidden = false
	hide_spot = null
	trap_stuck = 0.0
	trap_mash = 0.0
	crouch = false
	health = 1.0
	stamina = 1.0
	battery = 1.0
	flashlight_on = true
	reload_t = 0.0
	gun_t = 0.0
	act_push = 0.0
	act_throw = 0.0
	aim_k = 0.0
	bob = 0.0
	step_acc = 0.0
	move_speed = 0.0
	_crouch_k = 0.0
	_inspect_t = -1.0
	_appear_k = 1.0
