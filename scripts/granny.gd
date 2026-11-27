class_name GrannyAI
extends Node3D

const PATROL := 0
const INVESTIGATE := 1
const CHASE := 2
const SEARCH := 3
const CLIMB := 4
const STAGGER := 5

var game: Node
var sprite: Sprite3D
var shadow: MeshInstance3D
var lv: LevelData

var x := 24.5
var y := 27.5
var angle := -PI * 0.5
var level := 0
var state := PATROL
var notice := 0.0
var repath_t := 0.0
var decision_t := 0.0
var search_t := 0.0
var stagger_t := 0.0
var stagger_vis := 0.0
var climb_t := 0.0
var target_x := 0.0
var target_y := 0.0
var hatch_x := 0.0
var hatch_y := 0.0
var attic_wish := 0
var saw_player := false
var lost_t := 0.0
var speed_mul := 1.0
var aggro := false
var trap_t := 8.0
var path: Array[int] = []
var path_idx := 0
var line := ""
var line_t := 0.0
var scream_t := 0.0
var anim_t := 0.0
var bob := 0.0
var step_acc := 0.0
var level_switch_t := 4.0
var stuck_t := 0.0
var watch_t := 0.0
var watch_x := 0.0
var watch_y := 0.0
var replans := 0
var unstick_count := 0
var consecutive_path_fails := 0
var idle_look := 0.0
var wander_t := 0.0
var wander_dir := 0.0
var hum_t := 6.0

func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.texture = load("res://assets/granny.png")
	sprite.pixel_size = 1.82 / 1440.0
	sprite.position = Vector3(0, 0.91, 0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded = true
	add_child(sprite)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.95, 0.95)
	shadow = MeshInstance3D.new()
	shadow.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.38)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = m
	shadow.rotation.x = -PI * 0.5
	shadow.position = Vector3(0, 0.015, 0)
	add_child(shadow)

func setup(pgame: Node) -> void:
	game = pgame

func spawn(plv: LevelData, px: float, py: float, pang: float) -> void:
	lv = plv
	level = plv.id
	x = px
	y = py
	angle = pang
	state = PATROL
	path.clear()
	path_idx = 0
	notice = 0.0
	aggro = false
	scream_t = 0.0
	attic_wish = 0
	trap_t = 8.0
	stagger_t = 0.0
	stagger_vis = 0.0
	lost_t = 0.0
	stuck_t = 0.0
	decision_t = 0.0
	hum_t = 4.0 + randf() * 4.0
	if not can_stand(null, x, y):
		var placed := false
		for r in range(1, 3):
			if placed:
				break
			for dy in range(-r, r + 1):
				if placed:
					break
				for dx in range(-r, r + 1):
					if can_stand(null, x + dx, y + dy):
						x += dx
						y += dy
						placed = true
						break
	update_transform()

func player_local(g: Node) -> Vector2:
	var plv: LevelData = g.world.levels[g.player.level]
	var p: Vector3 = g.player.global_position - plv.origin
	return Vector2(p.x, p.z)

func can_stand(g, px: float, py: float) -> bool:
	var l: LevelData = (g.world.levels[level] if g != null else lv)
	if l == null:
		return false
	var r := 0.27
	if l.solid_at(px - r, py - r) or l.solid_at(px + r, py - r) or l.solid_at(px - r, py + r) or l.solid_at(px + r, py + r):
		return false
	if l.solid_at(px, py):
		return false
	for d in l.decos:
		if not d.solid:
			continue
		if absf(px - d.x) < d.rx + r * 0.7 and absf(py - d.y) < d.ry + r * 0.7:
			return false
	return true

func update_transform() -> void:
	if game == null:
		return
	var l: LevelData = game.world.levels[level]
	global_position = l.origin + Vector3(x, 0.02, y)
	rotation.y = -angle - PI * 0.5
	var tint := Color(1, 1, 1)
	if scream_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(game.time * 26.0)
		tint = Color(1.0, 0.55 - 0.15 * pulse, 0.52 - 0.12 * pulse)
	elif state == CHASE:
		tint = Color(1.0, 0.80, 0.78)
	sprite.modulate = tint
	sprite.position.y = 0.91 - stagger_vis * 0.34
	sprite.scale = Vector3(1.0, 1.0 - stagger_vis * 0.28, 1.0)

func say(g: Node, text: String, dur: float) -> void:
	line = text
	line_t = dur
	g.push_subtitle(text, dur, true)

func hit_by_dart(g: Node) -> void:
	if state == CLIMB:
		return
	state = STAGGER
	stagger_t = clampf(float(g.diff.stagger), 8.0, 30.0)
	notice = 0.0
	aggro = false
	saw_player = false
	lost_t = 0.0
	path.clear()
	path_idx = 0
	stuck_t = 0.0
	trap_t = maxf(trap_t, 6.0)
	var lines := ["Уф... кто это...", "Вот наглость!.. ой...", "Что за укол?.."]
	say(g, lines[randi() % lines.size()], 2.4)

func attract(px: float, py: float) -> void:
	if state == CLIMB:
		return
	state = INVESTIGATE
	target_x = px
	target_y = py
	path.clear()
	decision_t = 0.0

func update(dt: float, g: Node) -> void:
	lv = g.world.levels[level]
	var same_level: bool = g.player.level == level
	var pl := player_local(g)
	var dist := 999.0
	if same_level:
		dist = Vector2(x - pl.x, y - pl.y).length()
	var prev_x := x
	var prev_y := y
	anim_t += dt
	if scream_t > 0.0:
		scream_t -= dt
	if line_t > 0.0:
		line_t -= dt

	if state == STAGGER:
		stagger_t -= dt
		stagger_vis = move_toward(stagger_vis, 1.0, dt / 0.4)
		if stagger_t <= 0.0:
			state = PATROL
			path.clear()
			path_idx = 0
			decision_t = 0.3
			scream_t = 1.0
			if same_level and dist < 2.5:
				say(g, "Очухалась. Где ты, вредина?", 2.0)
			else:
				say(g, "Что это было?..", 1.6)
		else:
			g.noise_seen = g.time
			update_transform()
			return

	var can_see := false
	if same_level and not g.player.hidden and not g.player.dead:
		var sight: float = float(g.diff.sight)
		if g.player.flashlight_on:
			sight *= 1.3
		if g.player.crouch:
			sight *= 0.8
		if dist < sight and lv.line_of_sight(x, y, pl.x, pl.y):
			var ang := atan2(pl.y - y, pl.x - x)
			var diff := absf(angle_diff(ang, angle))
			if diff < 1.35 or dist < 2.4:
				can_see = true
	saw_player = can_see
	if can_see:
		notice = minf(1.0, notice + dt * (2.6 / (1.0 + dist * 0.2)))
		if notice >= 1.0 and state != CHASE:
			state = CHASE
			scream_t = 1.4
			aggro = true
			var lines := ["А ВОТ И ТЫ, СОЛНЫШКО!", "СТОЙ, ВНУЧОК!", "Я ТЕБЯ ВИЖУ, ЗАИНЬКА!", "КУДА СОБРАЛСЯ БЕЗ УЖИНА?!"]
			say(g, lines[randi() % lines.size()], 2.2)
			Audio.play3d("scream", g.world.get_root(level), Vector3(x, 1.4, y), 0.9, 1.0, 9.0)
			g.add_shake(0.7)
	else:
		notice = maxf(0.0, notice - dt * 0.55)

	for n in g.noises:
		if n.time < g.noise_seen:
			continue
		if int(n.level) >= 2 and level < 2:
			continue
		var d := Vector2(x - float(n.x), y - float(n.y)).length()
		var rng: float = float(n.radius) * float(g.diff.hear_mul)
		if same_level or float(n.radius) >= 6.0:
			if d < rng and state != CHASE and state != CLIMB:
				state = INVESTIGATE
				target_x = float(n.x)
				target_y = float(n.y)
				path.clear()
				decision_t = 0.0
				if randf() < 0.35:
					say(g, "Что там у тебя?" if str(n.what) == "крик" else "Кто здесь ходит?", 1.6)

	match state:
		PATROL:
			if path.is_empty() or path_idx >= path.size():
				decision_t -= dt
				idle_look += dt
				angle += sin(idle_look * 1.1) * dt * 0.9
				if decision_t <= 0.0:
					if pick_patrol_target(g):
						idle_look = 0.0
						decision_t = 0.2 + randf() * 0.9
			follow_path(dt, g, float(g.diff.walk))
			try_place_trap(dt, g)
		INVESTIGATE:
			var d := Vector2(x - target_x, y - target_y).length()
			if path.is_empty() or path_idx >= path.size():
				if d < 1.2:
					state = SEARCH
					search_t = 4.0 + randf() * 3.0
					choose_hatch()
					path.clear()
				else:
					set_path(g, int(floor(target_x)), int(floor(target_y)))
					if path.is_empty():
						idle_wander(g, dt)
						if Vector2(x - target_x, y - target_y).length() < 2.5:
							state = SEARCH
							search_t = 4.0
			follow_path(dt, g, float(g.diff.walk) * 1.2)
			if Vector2(x - target_x, y - target_y).length() < 0.9 and state == INVESTIGATE:
				state = SEARCH
				search_t = 4.5
		SEARCH:
			search_t -= dt
			angle += sin(anim_t * 1.6) * dt * 1.4
			if search_t <= 0.0:
				state = PATROL
				path.clear()
				decision_t = 0.4
			if g.player.hidden and g.player.hide_spot != null:
				var hs = g.player.hide_spot
				if Vector2(x - (hs.x + 0.5), y - (hs.y + 0.5)).length() < 2.0:
					if randf() < float(g.diff.hide_check) * dt:
						g.on_caught_in_hide()
		CHASE:
			if same_level:
				repath_t -= dt
				if repath_t <= 0.0:
					set_path(g, int(floor(pl.x)), int(floor(pl.y)))
					repath_t = 0.45
				if not path.is_empty() and path_idx < path.size():
					follow_path(dt, g, float(g.diff.run))
				else:
					step_towards(g, pl.x, pl.y, float(g.diff.run) * dt, true)
					angle += clampf(angle_diff(atan2(pl.y - y, pl.x - x), angle), -5.0 * dt, 5.0 * dt)
				if dist < 0.66:
					g.on_caught()
					update_transform()
					return
				if not can_see and not g.player.hidden:
					lost_t += dt
					if lost_t > 3.5:
						state = SEARCH
						search_t = 5.0
						target_x = pl.x
						target_y = pl.y
						path.clear()
						lost_t = 0.0
						if randf() < 0.5:
							say(g, "Ну и где ты спрятался?", 1.8)
				else:
					lost_t = 0.0
			else:
				state = INVESTIGATE
				target_x = pl.x
				target_y = pl.y
				attic_wish = 1 if g.player.level > level else 2
				path.clear()
		CLIMB:
			climb_t -= dt
			if climb_t <= 0.0:
				var nl := clampi(attic_wish, 0, 1)
				level = nl
				if nl == 0:
					x = 15.5
					y = 4.2
				else:
					x = 5.4
					y = 19.4
				path.clear()
				state = PATROL
				decision_t = 0.5
				Audio.play3d("climb", g.world.get_root(nl), Vector3(x, 1.0, y), 0.5, 0.85)

	update_attic_wish(dt, g)

	var moved := Vector2(x - prev_x, y - prev_y).length()
	if moved < 0.5:
		step_acc += moved
	if step_acc >= 0.78:
		step_acc = 0.0
		if same_level and not g.player.hidden and not g.player.dead:
			Audio.play3d("granny_step", g.world.get_root(level), Vector3(x, 0.6, y), 0.5 + randf() * 0.2, 0.85 + randf() * 0.2, 6.0)
	# Гул при спокойном состоянии — мягкий ориентир, где бабушка.
	if state == PATROL or state == SEARCH or state == INVESTIGATE:
		hum_t -= dt
		if hum_t <= 0.0:
			hum_t = 5.5 + randf() * 6.0
			Audio.play3d("hum", g.world.get_root(level), Vector3(x, 1.4, y), 0.30 + randf() * 0.12, 0.92 + randf() * 0.14, 5.0)
	else:
		hum_t = minf(hum_t, 3.0)

	g.noise_seen = g.time
	bob += dt * (9.0 if state == CHASE else 4.4) * (0.4 + 0.6 * (1.0 if not path.is_empty() and path_idx < path.size() else 0.15))
	if state != STAGGER:
		stagger_vis = move_toward(stagger_vis, 0.0, dt / 0.5)
	watchdog(dt, g)
	update_transform()

func angle_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)

func idle_wander(g: Node, dt: float) -> void:
	wander_t -= dt
	if wander_t <= 0.0:
		wander_t = 0.7 + randf() * 0.8
		wander_dir = randf() * TAU
	var nx := x + cos(wander_dir) * float(g.diff.walk) * dt
	var ny := y + sin(wander_dir) * float(g.diff.walk) * dt
	if can_stand(g, nx, ny):
		x = nx
		y = ny
	else:
		wander_t = 0.0
	angle += clampf(angle_diff(wander_dir, angle), -2.5 * dt, 2.5 * dt)

func set_path(g: Node, tx: int, ty: int) -> bool:
	path = lv.find_path(int(floor(x)), int(floor(y)), tx, ty, true)
	path_idx = 0
	return not path.is_empty()

func choose_hatch() -> void:
	if level == 0:
		hatch_x = 15.5
		hatch_y = 3.5
	else:
		hatch_x = 4.5
		hatch_y = 20.5

func update_attic_wish(dt: float, g: Node) -> void:
	if state == CLIMB:
		return
	if g.player.level >= 2:
		level_switch_t = 4.0
		attic_wish = 0
		return
	if g.player.level != level:
		level_switch_t -= dt * (2.2 if g.attic_alert_t > 0.0 else 1.0)
		attic_wish = g.player.level
		if level_switch_t <= 0.0:
			state = CLIMB
			climb_t = 1.4
			path.clear()
			hatch_x = 15.5 if level == 0 else 4.5
			hatch_y = 3.5 if level == 0 else 20.5
			Audio.play3d("climb", g.world.get_root(level), Vector3(hatch_x, 1.0, hatch_y), 0.55, 0.9)
	else:
		level_switch_t = 4.0
		attic_wish = 0

func pick_patrol_target(g: Node) -> bool:
	var pts_house := [
		Vector2(7.5, 7.5), Vector2(8.5, 11.5), Vector2(24.5, 7.5), Vector2(28.5, 11.5),
		Vector2(7.5, 15.5), Vector2(22.5, 15.5), Vector2(6.5, 21.5), Vector2(25.5, 21.5),
		Vector2(6.5, 27.5), Vector2(24.5, 27.5), Vector2(15.5, 20.5), Vector2(15.5, 27.0),
		Vector2(15.5, 8.0), Vector2(3.5, 15.5), Vector2(28.5, 15.5)
	]
	var pts_other := [
		Vector2(6.5, 6.5), Vector2(16.5, 6.5), Vector2(6.5, 16.5), Vector2(16.5, 16.5),
		Vector2(11.5, 11.5), Vector2(19.5, 19.5), Vector2(8.5, 19.5), Vector2(18.5, 11.5)
	]
	var pts: Array = pts_house if level == 0 else pts_other
	for attempt in 8:
		var p: Vector2 = pts[randi() % pts.size()]
		if not lv.ai_walkable(int(p.x), int(p.y)):
			continue
		if set_path(g, int(p.x), int(p.y)):
			consecutive_path_fails = 0
			return true
	consecutive_path_fails += 1
	if consecutive_path_fails < 2:
		decision_t = 2.0 + randf() * 2.0
		return false
	for rr in range(1, 7):
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if maxi(absi(dx), absi(dy)) != rr:
					continue
				var tx := int(floor(x)) + dx
				var ty := int(floor(y)) + dy
				if not lv.ai_walkable(tx, ty):
					continue
				if set_path(g, tx, ty):
					consecutive_path_fails = 0
					return true
	consecutive_path_fails = 0
	decision_t = 2.0 + randf() * 2.0
	return false

func try_place_trap(dt: float, g: Node) -> void:
	trap_t -= dt
	if trap_t > 0.0:
		return
	trap_t = 16.0 + randf() * 14.0
	for attempt in 12:
		var ang := randf() * TAU
		var rad := 2.0 + randf() * 2.5
		var tx := int(floor(x + cos(ang) * rad))
		var ty := int(floor(y + sin(ang) * rad))
		if tx < 1 or ty < 1 or tx >= lv.w - 1 or ty >= lv.h - 1:
			continue
		var t := lv.get_tile(tx, ty)
		if t != LevelData.FLOOR and t != LevelData.RUG:
			continue
		if lv.door_at(tx, ty) != null:
			continue
		if lv.trap_near(tx + 0.5, ty + 0.5, 2.2) != null:
			continue
		var pl := player_local(g)
		if Vector2(x - pl.x, y - pl.y).length() < 2.5:
			continue
		g.world.add_trap(lv, tx + 0.5, ty + 0.5)
		var cap: int = int(g.diff.traps) + 4
		if lv.traps.size() > cap:
			var old = lv.traps.pop_front()
			if old.node != null:
				old.node.queue_free()
				old.node = null
		return

func follow_path(dt: float, g: Node, speed: float) -> void:
	if path.is_empty() or path_idx >= path.size():
		return
	var node := path[path_idx]
	var nx := node % lv.w
	var ny := int(node / lv.w)
	var tx := nx + 0.5
	var ty := ny + 0.5
	var tile := lv.get_tile(nx, ny)
	if tile == LevelData.DOOR:
		var d := lv.door_at(nx, ny)
		if d != null and not d.open:
			if Vector2(x - tx, y - ty).length() < 1.5:
				open_door(g, d, tx, ty)
				return
	var dx := tx - x
	var dy := ty - y
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 0.5 and path_idx == path.size() - 1:
		path_idx += 1
		return
	if dist < 0.12:
		path_idx += 1
		return
	var moved := step_towards(g, tx, ty, speed * dt, true)
	var target_ang := atan2(dy, dx)
	angle += clampf(angle_diff(target_ang, angle), -3.4 * dt, 3.4 * dt)
	if moved:
		stuck_t = 0.0
	else:
		stuck_t += dt
		if stuck_t > 0.55:
			var dd := door_in_front(g, 0.9)
			if dd != null and not dd.open:
				open_door(g, dd, dd.x + 0.5, dd.y + 0.5)
			else:
				path.clear()
				path_idx = 0
				decision_t = 0.0
			stuck_t = 0.0
			replans += 1

func open_door(g: Node, d: LevelData.Door, tx: float, ty: float) -> void:
	d.open = true
	d.open_t = 0.001
	Audio.play3d("creak", g.world.get_root(level), Vector3(tx, 1.0, ty), 0.6, 0.9 + randf() * 0.25)
	g.emit_noise(tx, ty, 6.0, "дверь")

func door_in_front(g: Node, reach: float) -> LevelData.Door:
	var fx := x + cos(angle) * reach
	var fy := y + sin(angle) * reach
	return lv.door_at(int(floor(fx)), int(floor(fy)))

func step_towards(g: Node, tx: float, ty: float, step: float, open_doors: bool) -> bool:
	var dx := tx - x
	var dy := ty - y
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 0.0001:
		return false
	var base_ang := atan2(dy, dx)
	var offs := [0.0, 0.38, -0.38, 0.8, -0.8, 1.2, -1.2, 1.57, -1.57]
	var best_score := -1.0e9
	var bx := x
	var by := y
	for off in offs:
		var a := base_ang + float(off)
		var nx := x + cos(a) * step
		var ny := y + sin(a) * step
		if not can_stand(g, nx, ny):
			continue
		var score := -Vector2(nx - tx, ny - ty).length()
		if score > best_score:
			best_score = score
			bx = nx
			by = ny
	if best_score < -1.0e8:
		if open_doors:
			var d := door_in_front(g, 0.85)
			if d != null and not d.open:
				open_door(g, d, d.x + 0.5, d.y + 0.5)
		return false
	var moved := Vector2(bx - x, by - y).length()
	x = bx
	y = by
	return moved > step * 0.25

func watchdog(dt: float, g: Node) -> void:
	var wants_to_walk := not path.is_empty() and path_idx < path.size() and state != CLIMB
	if not wants_to_walk:
		watch_t = 0.0
		watch_x = x
		watch_y = y
		return
	watch_t += dt
	if watch_t < 1.1:
		return
	var moved := Vector2(x - watch_x, y - watch_y).length()
	watch_t = 0.0
	watch_x = x
	watch_y = y
	if moved > 0.08:
		return
	unstick_count += 1
	for k in 24:
		var a := float(k) * TAU / 24.0
		var nx := x + cos(a) * 0.15
		var ny := y + sin(a) * 0.15
		if can_stand(g, nx, ny):
			x = nx
			y = ny
			break
	path.clear()
	decision_t = 0.0
	stuck_t = 0.0
	teleport_to_walkable(g)

func teleport_to_walkable(g: Node) -> void:
	var cx := int(floor(x))
	var cy := int(floor(y))
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var tx := cx + dx
				var ty := cy + dy
				if tx < 0 or ty < 0 or tx >= lv.w or ty >= lv.h:
					continue
				if not lv.ai_walkable(tx, ty):
					continue
				if can_stand(g, tx + 0.5, ty + 0.5):
					x = tx + 0.5
					y = ty + 0.5
					return
