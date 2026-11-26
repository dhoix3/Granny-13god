class_name SaveSystem
extends RefCounted

# Сохранения прогресса. Автосейв при смене дня + 3 ручных слота.
# Формат: user://saves/<slot>.json (JSON с блоком meta и блоком state).
# Мир игры детерминирован (фиксированный seed), поэтому сохраняется только
# изменяемое состояние: инвентарь, замки, обысканные контейнеры, двери,
# капканы, позиция/параметры актёров, счётчики.

const SAVE_DIR := "user://saves"
const AUTO := "auto"
const SLOTS: Array[String] = ["slot1", "slot2", "slot3"]
const ALL_SLOTS: Array[String] = [AUTO, "slot1", "slot2", "slot3"]
const VERSION := 1

class SlotMeta:
	var slot := ""
	var exists := false
	var diff_name := ""
	var diff_index := 1
	var day := 1
	var max_days := 5
	var locks := 0
	var play_time := 0.0
	var saved_unix := 0

static func _slot_path(slot: String) -> String:
	return SAVE_DIR + "/" + slot + ".json"

static func slot_label(slot: String) -> String:
	match slot:
		AUTO: return "АВТОСОХРАНЕНИЕ"
		"slot1": return "СЛОТ 1"
		"slot2": return "СЛОТ 2"
		"slot3": return "СЛОТ 3"
	return slot

static func read_meta(slot: String) -> SlotMeta:
	var m := SlotMeta.new()
	m.slot = slot
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return m
	var data = _parse_json(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return m
	var meta = data.get("meta")
	if typeof(meta) != TYPE_DICTIONARY:
		return m
	m.exists = true
	m.diff_name = str(meta.get("diff_name", ""))
	m.diff_index = int(meta.get("diff_index", 1))
	m.day = int(meta.get("day", 1))
	m.max_days = int(meta.get("max_days", 5))
	m.locks = int(meta.get("locks", 0))
	m.play_time = float(meta.get("play_time", 0.0))
	m.saved_unix = int(meta.get("saved_unix", 0))
	return m

static func read_all_metas() -> Array[SlotMeta]:
	var out: Array[SlotMeta] = []
	for s in ALL_SLOTS:
		out.append(read_meta(s))
	return out

static func has_any_save() -> bool:
	for m in read_all_metas():
		if m.exists:
			return true
	return false

static func latest_slot() -> String:
	var best := ""
	var best_time := -1
	for m in read_all_metas():
		if m.exists and m.saved_unix > best_time:
			best_time = m.saved_unix
			best = m.slot
	return best

static func save_run(game: GrannyGame, slot: String) -> bool:
	if game.world == null or game.world.levels.is_empty():
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	dir.make_dir_recursive(SAVE_DIR.trim_prefix("user://"))

	var state := {}
	state["version"] = VERSION
	state["diff_index"] = game.diff_index
	state["day"] = game.day
	state["max_days"] = game.max_days
	state["play_time"] = game.play_time
	state["deaths"] = game.deaths
	state["inv"] = game.inv.duplicate()
	state["locks"] = game.locks.duplicate()
	state["lock4"] = game.lock4
	state["car_key_installed"] = game.car_key_installed
	state["car_battery_installed"] = game.car_battery_installed
	state["photo_taken"] = game.photo_taken
	state["garage_open"] = game.world.garage_open

	var p := game.player
	var plv: LevelData = game.world.levels[p.level]
	var pp: Vector3 = p.global_position - plv.origin
	state["player"] = {
		"level": p.level, "x": pp.x, "y": pp.z, "angle": p.angle, "pitch": p.pitch,
		"health": p.health, "stamina": p.stamina, "battery": p.battery,
		"flashlight_on": p.flashlight_on, "crouch": p.crouch, "hidden": p.hidden,
		"hide_x": (p.hide_spot.x if p.hidden and p.hide_spot != null else -1),
		"hide_y": (p.hide_spot.y if p.hidden and p.hide_spot != null else -1),
	}
	var gr := game.granny
	state["granny"] = {
		"level": gr.level, "x": gr.x, "y": gr.y, "angle": gr.angle,
		"trap_t": gr.trap_t,
	}
	state["cat"] = {"fed": game.cat.fed, "angry": game.cat.angry, "x": game.cat.x, "y": game.cat.y}

	var containers := []
	for lv in game.world.levels:
		for c in lv.containers:
			if c.searched:
				containers.append({"lv": lv.id, "x": c.x, "y": c.y})
	state["searched_containers"] = containers

	var doors := []
	for lv in game.world.levels:
		for d in lv.doors:
			if d.open and not d.front:
				doors.append({"lv": lv.id, "x": d.x, "y": d.y})
	state["open_doors"] = doors

	var traps := []
	for lv in game.world.levels:
		for t in lv.traps:
			if t.armed:
				traps.append({"lv": lv.id, "x": t.x, "y": t.y})
	state["armed_traps"] = traps

	var meta := {
		"diff_name": game.diff.name,
		"diff_index": game.diff_index,
		"day": game.day,
		"max_days": game.max_days,
		"locks": game.count_locks(),
		"play_time": game.play_time,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}
	var data := {"meta": meta, "state": state}

	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

static func load_run(game: GrannyGame, slot: String) -> bool:
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return false
	var data = _parse_json(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("state")) != TYPE_DICTIONARY:
		return false
	var st: Dictionary = data["state"]

	game.diff_index = clampi(int(st.get("diff_index", 1)), 0, game.diffs.size() - 1)
	game.diff = game.diffs[game.diff_index]
	game.max_days = maxi(1, int(st.get("max_days", game.diff.days)))
	game.day = clampi(int(st.get("day", 1)), 1, game.max_days)
	game.play_time = float(st.get("play_time", 0.0))
	game.deaths = int(st.get("deaths", 0))
	game.lock4 = bool(st.get("lock4", false))
	game.car_key_installed = bool(st.get("car_key_installed", false))
	game.car_battery_installed = bool(st.get("car_battery_installed", false))
	game.photo_taken = bool(st.get("photo_taken", false))
	var locks_arr: Array = st.get("locks", [false, false, false])
	while locks_arr.size() < 3:
		locks_arr.append(false)
	for i in 3:
		game.locks[i] = bool(locks_arr[i])

	game.inv.clear()
	for v in st.get("inv", []):
		game.inv.append(int(v))
	game.noises.clear()
	game.subs.clear()
	for t in game.throwns:
		if is_instance_valid(t):
			t.queue_free()
	game.throwns.clear()
	for b in game.bloods:
		if is_instance_valid(b):
			b.queue_free()
	game.bloods.clear()
	game.journal = false
	game.target_kind = 0
	game.target_obj = null
	game.prompt = ""
	game.interact_prog = 0.0
	game.interact_label = ""
	game.pickup_t = 0.0
	game.pickup_item = 0
	game.toast_t = 0.0
	game.detect_fx = 0.0
	game.hit_flash = 0.0
	game.climb_fx = 0.0
	game.shake = 0.0
	game.fade_t = 1.0
	game.attic_alert_t = 0.0
	game.lightning_t = game.time + 30.0 + game.rng.randf() * 30.0

	# Контейнеры: детерминированная генерация уже раздала предметы.
	# Обысканные при сохранении — обнуляем, чтобы предметы не дублировались.
	var searched: Array = st.get("searched_containers", [])
	for lv in game.world.levels:
		for c in lv.containers:
			c.searched = false
	for sc in searched:
		var lv: LevelData = game.world.levels[int(sc.lv)]
		var c = lv.container_at(int(sc.x), int(sc.y))
		if c != null:
			c.searched = true
			c.item_id = Items.NONE

	# Двери
	for lv in game.world.levels:
		for d in lv.doors:
			d.open = false
			d.open_t = 0.0
	for od in st.get("open_doors", []):
		var lv: LevelData = game.world.levels[int(od.lv)]
		var d = lv.door_at(int(od.x), int(od.y))
		if d != null:
			d.open = true
	game.world.set_garage_open(bool(st.get("garage_open", false)))
	game.world.set_front_locks(game.count_locks())
	game.world.update_doors(1.0)

	# Капканы: только вооружённые из сейва
	game.world.clear_traps()
	for tp in st.get("armed_traps", []):
		var lv: LevelData = game.world.levels[int(tp.lv)]
		game.world.add_trap(lv, float(tp.x), float(tp.y))

	# Игрок
	var ps: Dictionary = st.get("player", {})
	var p_level := clampi(int(ps.get("level", 0)), 0, game.world.levels.size() - 1)
	var plv: LevelData = game.world.levels[p_level]
	game.player.reset_state()
	game.player.dead = false
	game.player.place_at(p_level, float(ps.get("x", 5.5)), float(ps.get("y", 10.5)), float(ps.get("angle", 0.0)))
	game.player.pitch = float(ps.get("pitch", 0.0))
	game.player.health = clampf(float(ps.get("health", 1.0)), 0.05, 1.0)
	game.player.stamina = clampf(float(ps.get("stamina", 1.0)), 0.0, 1.0)
	game.player.battery = clampf(float(ps.get("battery", 1.0)), 0.0, 1.0)
	game.player.flashlight_on = bool(ps.get("flashlight_on", true))
	game.player.crouch = bool(ps.get("crouch", false))
	var was_hidden := bool(ps.get("hidden", false))
	game.player.hidden = false
	game.player.hide_spot = null
	if was_hidden:
		var hs = plv.hide_at(int(ps.get("hide_x", -1)), int(ps.get("hide_y", -1)))
		if hs != null:
			game.player.enter_hide(hs)
	game.player.apply_camera()

	# Гренни
	var gs: Dictionary = st.get("granny", {})
	var g_level := clampi(int(gs.get("level", 0)), 0, 1)
	game.granny.spawn(game.world.levels[g_level], float(gs.get("x", 24.5)), float(gs.get("y", 27.5)), float(gs.get("angle", 0.0)))
	game.granny.trap_t = float(gs.get("trap_t", 12.0))
	game.granny.state = GrannyAI.PATROL
	game.granny.line = ""
	game.granny.line_t = 0.0
	game.granny.update_transform()

	# Кошка
	var cs: Dictionary = st.get("cat", {})
	game.cat.x = float(cs.get("x", 9.5))
	game.cat.y = float(cs.get("y", 5.3))
	game.cat.fed = bool(cs.get("fed", false))
	game.cat.angry = bool(cs.get("angry", false))
	game.cat.angry_t = 6.0 if game.cat.angry else 0.0
	game.cat.update_transform()

	game._set_state(GrannyGame.STATE_PLAY)
	return true

static func _parse_json(text: String):
	var parsed = JSON.parse_string(text)
	return parsed
