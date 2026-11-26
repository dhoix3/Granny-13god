class_name CatAI
extends Node3D

# Маруся — кошка с чердака. Port of Cat.cs.

var game: Node
var sprite: Sprite3D
var shadow: MeshInstance3D
var x := 9.5
var y := 5.3
var level := 1
var fed := false
var angry := false
var meow_t := 0.0
var idle_t := 18.0
var angry_t := 0.0
var tail := 0.0
var purr_t := 0.0

func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.texture = load("res://assets/marusya.png")
	sprite.pixel_size = 0.56 / 245.0
	sprite.position = Vector3(0, 0.28, 0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded = true
	add_child(sprite)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	shadow = MeshInstance3D.new()
	shadow.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.36)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = m
	shadow.rotation.x = -PI * 0.5
	shadow.position = Vector3(0, 0.015, 0)
	add_child(shadow)

func setup(pgame: Node) -> void:
	game = pgame

func reset() -> void:
	x = 9.5
	y = 5.3
	fed = false
	angry = false
	meow_t = 0.0
	idle_t = 18.0 + randf() * 14.0
	angry_t = 0.0
	purr_t = 0.0
	update_transform()

func feed(g: Node) -> void:
	fed = true
	angry = false
	angry_t = 0.0
	Audio.play("purr", 0.5, 1.0)
	g.emit_noise(x, y, 2.0, "мурчание")
	g.push_subtitle("Маруся: муррр...", 2.4, false)
	update_transform()

func purr_now(_g: Node) -> void:
	Audio.play("purr", 0.45, 1.0)

func alert(g: Node, what: String) -> void:
	if angry_t > 0.0:
		return
	angry = true
	angry_t = 9.0
	meow_t = 0.9
	Audio.play("hiss" if what == "шипение" else "meow", 0.8, 1.0)
	g.emit_noise(x, y, 15.0, "мяу")
	g.attic_alert_t = maxf(g.attic_alert_t, 8.0)
	g.push_subtitle("Маруся: МЯУ!!!", 2.0, false)
	update_transform()

func update(dt: float, g: Node) -> void:
	tail += dt * 1.6
	if angry_t > 0.0:
		angry_t -= dt
		if angry_t <= 0.0:
			angry = false
	if fed:
		purr_t -= dt
		if purr_t <= 0.0 and g.player.level == 1 and _dist_to_player(g) < 7.5:
			Audio.play("purr", 0.14, 1.0)
			purr_t = 1.05
		update_transform()
		return
	if g.player.level != 1:
		update_transform()
		return
	var d := _dist_to_player(g)
	var cat_range: float = float(g.diff.cat_range)
	var moving_fast: bool = g.player.move_speed > 1.6 and not g.player.crouch
	var light_on: bool = g.player.flashlight_on and d < 3.4
	var near := d < cat_range
	if not g.player.hidden and ((near and moving_fast) or (d < 1.5) or (light_on and d < 2.6)):
		alert(g, "мяу")
	# сундук рядом с кошкой
	var chest = g.world.levels[1].container_at(9, 4)
	if chest != null and chest.searched and d < 4.0:
		alert(g, "мяу")
	idle_t -= dt
	if idle_t <= 0.0:
		idle_t = 22.0 + randf() * 20.0
		if d < 9.0:
			Audio.play("meow", 0.35, 0.85 + randf() * 0.3)
			g.emit_noise(x, y, 5.5, "мяу")
	update_transform()

func _dist_to_player(g: Node) -> float:
	var lv: LevelData = g.world.levels[g.player.level]
	var p: Vector3 = g.player.global_position - lv.origin
	return Vector2(x - p.x, y - p.z).length()

func update_transform() -> void:
	if game == null:
		return
	var lv: LevelData = game.world.levels[1]
	global_position = lv.origin + Vector3(x, 0.02, y)
	if sprite != null:
		sprite.texture = load("res://assets/marusya_angry.png") if angry else load("res://assets/marusya.png")
		var pulse := 1.0
		if angry:
			pulse = 1.0 + 0.04 * sin(game.time * 18.0)
		sprite.scale = Vector3(pulse, pulse, pulse)
		var bob := sin(tail * 1.7) * 0.01
		sprite.position.y = 0.28 + bob
