class_name HouseData
extends RefCounted

# Загрузка авторской планировки дома из assets/house.json.
# JSON — единственный источник правды о геометрии дома; его же читает
# tests/logic_check.py (статическая проверка проходимости и логики).
# Здесь только конвертация в LevelData + распределение предметов по seed.

const KIND_HX := [0.78, 0.62, 1.06, 0.37, 0.74, 0.66, 0.53, 0.41, 0.40, 0.55, 0.58, 0.27, 0.33, 0.40, 0.12, 0.04, 0.06, 0.14, 0.04]
const KIND_HY := [0.42, 0.33, 0.35, 0.30, 0.36, 0.32, 0.32, 0.36, 0.37, 0.28, 0.29, 0.24, 0.28, 0.20, 0.08, 0.04, 0.05, 0.06, 0.04]

# Прогрессионные предметы лежат в фиксированных контейнерах (item_anchors в JSON),
# остальной пул — случайно по seed. Сохраняет прежнюю семантику распределения.
const ANCHOR_FALLBACK := {}

static var _cache: Dictionary = {}

static func _data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open("res://assets/house.json", FileAccess.READ)
	if f == null:
		push_error("house.json not found")
		return {}
	_cache = JSON.parse_string(f.get_as_text())
	return _cache

static func build_levels(pseed: int) -> Array[LevelData]:
	var data: Dictionary = _data()
	var out: Array[LevelData] = []
	for ld in data["levels"]:
		out.append(_build_level(ld, pseed))
	distribute_items(out, data["item_anchors"], pseed)
	return out

static func _build_level(ld: Dictionary, _pseed: int) -> LevelData:
	var lv := LevelData.new(int(ld["w"]), int(ld["h"]), int(ld["id"]), String(ld["name"]))
	var legend: Dictionary = _data()["legend"]
	var floor_ids: Dictionary = _data()["floor"]
	var rows: Array = ld["map"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var t := LevelData.BRICK
			if legend.has(ch):
				t = int(legend[ch])
			elif floor_ids.has(ch):
				t = int(floor_ids[ch])
			lv.map[y * lv.w + x] = t
	# двери
	for y in lv.h:
		for x in lv.w:
			var t := lv.get_tile(x, y)
			if t == LevelData.DOOR or t == LevelData.FRONT:
				var d := LevelData.Door.new()
				d.x = x
				d.y = y
				d.front = t == LevelData.FRONT
				lv.doors.append(d)
	# люки/лестницы
	for h in ld.get("hatches", []):
		lv.hatches.append(h)
	# декор и контейнеры
	for dd in ld.get("decos", []):
		var dec := LevelData.Deco.new()
		dec.kind = int(dd["kind"])
		dec.x = float(dd["x"])
		dec.y = float(dd["y"])
		dec.name = String(dd.get("name", ""))
		dec.rot = int(dd.get("rot", 0))
		dec.rx = float(dd.get("rx", HouseData.KIND_HX[mini(dec.kind, HouseData.KIND_HX.size() - 1)]))
		dec.ry = float(dd.get("ry", HouseData.KIND_HY[mini(dec.kind, HouseData.KIND_HY.size() - 1)]))
		dec.solid = bool(dd.get("solid", true))
		var tx := int(floor(dec.x))
		var ty := int(floor(dec.y))
		dec.tile_x = tx
		dec.tile_y = ty
		if dd.has("container"):
			var c := LevelData.ContainerData.new()
			c.x = tx
			c.y = ty
			c.label = String(dd["container"])
			dec.container = c
			lv.containers.append(c)
		if dd.has("hide"):
			var hs := LevelData.HideSpot.new()
			hs.x = tx
			hs.y = ty
			hs.enter_x = int(dd["hide"]["enter"][0])
			hs.enter_y = int(dd["hide"]["enter"][1])
			hs.is_bed = bool(dd["hide"].get("bed", false))
			hs.label = String(dd["hide"].get("label", "Укрытие"))
			dec.hide = hs
			lv.hides.append(hs)
		if int(dd["kind"]) == 23:
			dec.is_car = true
		if int(dd["kind"]) == 20:
			dec.is_cradle = true
		lv.decos.append(dec)
	# лампы
	for lp in ld.get("lamps", []):
		lv.lamps.append(Vector3(float(lp[0]), 2.25, float(lp[1])))
	# паутина
	for wb in ld.get("webs", []):
		lv.webs.append(Rect2(float(wb[0]), float(wb[1]), float(wb[2]), float(wb[3])))
	# пауки (только подвал их имеет)
	for sp in ld.get("spiders", []):
		lv.spiders.append(Vector2(float(sp[0]), float(sp[1])))
	# комнатные имена для аудио/подсказок
	for rn in ld.get("rooms", []):
		lv.room_names.append(String(rn))
	lv.lamp_rooms.clear()
	for ri in ld.get("lamp_rooms", []):
		lv.lamp_rooms.append(int(ri))
	# spawn
	lv.spawn_x = float(ld["spawn"]["x"])
	lv.spawn_y = float(ld["spawn"]["y"])
	lv.spawn_a = float(ld["spawn"]["a"])
	lv.origin = Vector3(lv.id * 200.0, 0.0, 0.0)
	lv.rebuild_ai_blocked()
	return lv

static func distribute_items(levels: Array[LevelData], anchors: Dictionary, pseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pseed
	var house := levels[0]
	var attic := levels[1]
	# фиксированные якоря по метке контейнера
	var taken: Dictionary = {}
	for lv in levels:
		for c in lv.containers:
			if anchors.has(c.label):
				c.item_id = int(anchors[c.label])
				taken[c] = true
	# старый ящик = арбалет (якорь), страховка: если метки нет — первый контейнер дома
	if not taken.values().has(true):
		house.containers[0].item_id = Items.CROSSBOW
		taken[house.containers[0]] = true
	# пул случайных контейнеров дома (не якоря)
	var pool: Array[LevelData.ContainerData] = []
	for c in house.containers:
		if not taken.has(c):
			pool.append(c)
	_shuffle(pool, rng)
	var req := [Items.KEY, Items.CROWBAR, Items.MILK, Items.BANDAGE]
	_shuffle(req, rng)
	var idx := 0
	for i in mini(req.size(), pool.size()):
		pool[i].item_id = req[i]
		idx += 1
	var extra := [Items.BOTTLE, Items.BOTTLE, Items.MILK, Items.BATTERY]
	var e := 0
	while idx < pool.size() and e < extra.size():
		pool[idx].item_id = extra[e]
		idx += 1
		e += 1
	# дротики и ключ от машины — в свободные контейнеры дома, затем чердака
	var darts_left := 3
	var car_key_placed := false
	for lv in [house, attic]:
		for c in lv.containers:
			if c.item_id != Items.NONE:
				continue
			if darts_left > 0:
				c.item_id = Items.DART
				darts_left -= 1
			elif not car_key_placed:
				c.item_id = Items.CAR_KEY
				car_key_placed = true

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
