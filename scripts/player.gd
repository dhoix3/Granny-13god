class_name PlayerBody
extends CharacterBody3D

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
var viewmodel: Node3D
var vm_lens_mat: StandardMaterial3D

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
	_build_viewmodel()

func setup(pgame: Node) -> void:
	game = pgame

func _vm_mat(col: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _vm_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _vm_ball(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = height
	sm.radial_segments = 14
	sm.rings = 7
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _vm_cyl(parent: Node3D, r_top: float, r_bottom: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = -PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _vm_limb(parent: Node3D, radius: float, from: Vector3, to: Vector3, mat: Material) -> MeshInstance3D:
	var d := to - from
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(d.length(), radius * 2.0 + 0.01)
	cm.radial_segments = 14
	cm.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = (from + to) * 0.5
	mi.quaternion = Quaternion(Vector3.UP, d.normalized())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_viewmodel() -> void:
	# Рука с фонариком в кадре — как в оригинале.
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	viewmodel.position = Vector3(0.44, -0.34, -0.68)
	viewmodel.rotation = Vector3(0.03, 0.08, -0.10)
	camera.add_child(viewmodel)

	var hand_mat := _vm_mat(Color(0.27, 0.19, 0.15))
	var hand_hi := _vm_mat(Color(0.32, 0.23, 0.18))
	var sleeve_mat := _vm_mat(Color(0.14, 0.13, 0.14))
	var metal_mat := _vm_mat(Color(0.19, 0.20, 0.21))
	var metal_hi := _vm_mat(Color(0.35, 0.36, 0.38))
	var grip_mat := _vm_mat(Color(0.10, 0.10, 0.11))
	vm_lens_mat = StandardMaterial3D.new()
	vm_lens_mat.albedo_color = Color(0.38, 0.24, 0.10)
	vm_lens_mat.emission_enabled = true
	vm_lens_mat.emission = Color(1.0, 0.66, 0.26)
	vm_lens_mat.emission_energy_multiplier = 0.7
	vm_lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Фонарик повёрнут влево-вперёд, поэтому виден его корпус, а не яркий торец.
	var torch := Node3D.new()
	torch.name = "Torch"
	torch.rotation = Vector3(0.17, 0.31, 0.03)
	viewmodel.add_child(torch)

	# Корпус, хвостовик и насечки.
	_vm_cyl(torch, 0.020, 0.023, 0.16, Vector3(0.0, 0.0, -0.055), metal_mat)
	_vm_cyl(torch, 0.024, 0.024, 0.012, Vector3(0.0, 0.0, 0.030), grip_mat)
	for i in 3:
		_vm_cyl(torch, 0.0245, 0.0245, 0.008, Vector3(0.0, 0.0, 0.006 - float(i) * 0.026), grip_mat)
	# Светлая грань сверху — читаемый блик на плоском вьюмоделе.
	_vm_box(torch, Vector3(0.007, 0.003, 0.125), Vector3(0.0, 0.019, -0.055), metal_hi)
	# Кнопка.
	_vm_box(torch, Vector3(0.012, 0.009, 0.032), Vector3(0.0, 0.014, 0.024), metal_hi)

	# Расширяющаяся головка с ободком и тёмной линзой.
	_vm_cyl(torch, 0.036, 0.023, 0.085, Vector3(0.0, 0.0, -0.178), metal_mat)
	_vm_cyl(torch, 0.039, 0.039, 0.012, Vector3(0.0, 0.0, -0.226), metal_hi)
	_vm_cyl(torch, 0.033, 0.033, 0.006, Vector3(0.0, 0.0, -0.234), vm_lens_mat)

	# Кисть обхватывает корпус справа: ладонь, четыре пальца и большой палец.
	_vm_ball(torch, 0.029, 0.066, Vector3(0.043, -0.030, -0.004), hand_mat, Vector3(0.90, 1.05, 0.95), Vector3(0.0, 0.0, 0.12))
	for i in 4:
		var fz := 0.038 - float(i) * 0.024
		_vm_limb(torch, 0.0110, Vector3(0.050, -0.020, fz), Vector3(-0.020, -0.006, fz - 0.008), hand_hi)
	_vm_limb(torch, 0.0100, Vector3(0.030, -0.040, 0.045), Vector3(0.024, -0.030, -0.015), hand_hi)
	_vm_limb(torch, 0.023, Vector3(0.038, -0.048, 0.040), Vector3(0.045, -0.062, 0.070), hand_mat)
	# Манжета и предплечье уходят за правый нижний край экрана.
	_vm_limb(torch, 0.033, Vector3(0.042, -0.055, 0.055), Vector3(0.055, -0.085, 0.105), sleeve_mat)
	var wrist := torch.transform * Vector3(0.055, -0.085, 0.105)
	_vm_limb(viewmodel, 0.042, wrist, Vector3(0.21, -0.42, 0.32), sleeve_mat)

func _process(_dt: float) -> void:
	if viewmodel == null or game == null:
		return
	viewmodel.visible = game.state == game.STATE_PLAY and not game.journal and not hidden and not dead
	if not viewmodel.visible:
		return
	var walk := clampf(move_speed / 3.45, 0.0, 1.0)
	var sway := sin(bob) * 0.014 * walk
	var bob_y := absf(cos(bob)) * 0.012 * walk
	var dip := -0.05 if crouch else 0.0
	var push := act_push
	var throw_k := act_throw
	viewmodel.position = Vector3(0.44 + sway, -0.34 + bob_y + dip - push * 0.055, -0.68 + push * 0.035)
	viewmodel.rotation = Vector3(0.03 + push * 0.22, 0.08, -0.10 - sway * 1.4 + throw_k * 0.55)
	vm_lens_mat.emission_enabled = flashlight_on

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

	var fwd := 0.0
	var strafe := 0.0
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
	crouch = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)
	var want_run := Input.is_physical_key_pressed(KEY_SHIFT) and not crouch
	var moving := absf(fwd) + absf(strafe) > 0.01
	var running := want_run and stamina > 0.05 and moving
	var speed := 2.05
	if crouch:
		speed = 1.05
	elif running:
		speed = 3.45
	if game.in_spider_web():
		speed *= 0.33
	var dir := Vector3.ZERO
	if moving:
		dir = Vector3(cos(angle) * fwd - sin(angle) * strafe, 0.0, sin(angle) * fwd + cos(angle) * strafe).normalized()
	move_speed = speed if moving else 0.0
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y -= 20.0 * dt
	move_and_slide()

	if moving:
		bob += dt * (11.5 if running else (4.2 if crouch else 7.4))
		step_acc += dt * (3.4 if running else (1.2 if crouch else 2.15))
		if step_acc > 1.0:
			step_acc = 0.0
			var vol := 0.5 if running else (0.12 if crouch else 0.28)
			var tile: int = game.world.levels[level].get_tile(int(floor(global_position.x - game.world.levels[level].origin.x)), int(floor(global_position.z - game.world.levels[level].origin.z)))
			var snd := "step_tile" if tile == LevelData.TILEW else ("step" if randf() < 0.5 else "step2")
			Audio.play(snd, vol, 0.85 + randf() * 0.3)
			if running:
				game.emit_noise(global_position.x - game.world.levels[level].origin.x, global_position.z - game.world.levels[level].origin.z, 6.2, "шаги")
			elif not crouch:
				game.emit_noise(global_position.x - game.world.levels[level].origin.x, global_position.z - game.world.levels[level].origin.z, 2.6, "шаги")
			elif randf() < 0.35:
				game.emit_noise(global_position.x - game.world.levels[level].origin.x, global_position.z - game.world.levels[level].origin.z, 0.9, "скрип")

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
	aim_k = move_toward(aim_k, 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not crouch else 0.0, dt * 7.0)
	camera.fov = lerpf(75.0, 55.0, aim_k)
	rotation.y = -angle - PI * 0.5
	apply_camera()

func apply_camera() -> void:
	if camera == null:
		return
	var lv: LevelData = game.world.levels[level]
	var local_x := global_position.x - lv.origin.x
	var local_z := global_position.z - lv.origin.z
	var tile := lv.get_tile(int(floor(local_x)), int(floor(local_z)))
	var tile_bob := 0.0
	if hidden:
		camera.position.y = 0.28 if hide_spot != null and hide_spot.is_bed else 1.18
		camera.position.x = 0.0
		camera.rotation.x = pitch * 0.4
		flashlight.visible = false
		return
	var speed_k := clampf(move_speed / 2.0, 0.0, 1.0)
	camera.position.y = EYE_H + sin(bob * 2.0) * 0.012 * speed_k - (0.30 if crouch else 0.0)
	camera.position.x = 0.0
	camera.rotation.x = pitch + sin(bob) * 0.022 * clampf(move_speed / 3.0, 0.0, 1.0)
	if tile == LevelData.TILEW:
		tile_bob = 0.0
	flashlight.visible = flashlight_on and battery > 0.0
	flashlight.light_energy = 1.30 * (0.75 + 0.25 * clampf(battery, 0.0, 1.0))

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
