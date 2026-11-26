class_name WorldGen
extends RefCounted

# Port of WorldBuilder from the original C# source.
const KIND_HX := [0.78, 0.62, 1.06, 0.37, 0.74, 0.66, 0.53, 0.41, 0.40, 0.55, 0.58, 0.27, 0.33, 0.40, 0.12, 0.04, 0.06, 0.14, 0.04]
const KIND_HY := [0.42, 0.33, 0.35, 0.30, 0.36, 0.32, 0.32, 0.36, 0.37, 0.28, 0.29, 0.24, 0.28, 0.20, 0.08, 0.04, 0.05, 0.06, 0.04]

var house: LevelData
var attic: LevelData
var garage: LevelData
var cellar: LevelData
var seed := 1
var rng := RandomNumberGenerator.new()

func build(pseed: int) -> Array[LevelData]:
	seed = pseed
	rng.seed = pseed
	house = build_house()
	attic = build_attic()
	garage = build_garage()
	cellar = build_cellar()
	build_lamps()
	for lv in [house, attic, garage, cellar]:
		lv.origin = Vector3(lv.id * 200.0, 0.0, 0.0)
		lv.rebuild_ai_blocked()
	distribute_items()
	var out: Array[LevelData] = [house, attic, garage, cellar]
	return out

func _wallpaper_pass(lv: LevelData) -> void:
	for y in range(1, lv.h - 1):
		for x in range(1, lv.w - 1):
			if lv.get_tile(x, y) != LevelData.BRICK:
				continue
			var near := (
				lv.get_tile(x - 1, y) == LevelData.FLOOR or lv.get_tile(x + 1, y) == LevelData.FLOOR
				or lv.get_tile(x, y - 1) == LevelData.FLOOR or lv.get_tile(x, y + 1) == LevelData.FLOOR
				or lv.get_tile(x - 1, y) == LevelData.RUG or lv.get_tile(x + 1, y) == LevelData.RUG
				or lv.get_tile(x, y - 1) == LevelData.RUG or lv.get_tile(x, y + 1) == LevelData.RUG
			)
			if near:
				lv.set_tile(x, y, LevelData.PLASTER)

func auto_rot(lv: LevelData, tx: int, ty: int) -> int:
	for d in range(1, 4):
		if LevelData.SOLID[lv.get_tile(tx, ty - d)]:
			return 2
		if LevelData.SOLID[lv.get_tile(tx, ty + d)]:
			return 0
		if LevelData.SOLID[lv.get_tile(tx - d, ty)]:
			return 1
		if LevelData.SOLID[lv.get_tile(tx + d, ty)]:
			return 3
	return 0

func add_furn(lv: LevelData, tx: int, ty: int, kind: int, fname: String, container_label: String = "", hide_label: String = "", hide_ex: int = 0, hide_ey: int = 0) -> LevelData.Deco:
	var d := LevelData.Deco.new()
	d.x = tx + 0.5
	d.y = ty + 0.5
	d.kind = kind
	d.name = fname
	d.rot = auto_rot(lv, tx, ty)
	d.rx = KIND_HX[kind]
	d.ry = KIND_HY[kind]
	if d.rot % 2 == 1:
		var t := d.rx
		d.rx = d.ry
		d.ry = t
	if container_label != "":
		var c := LevelData.ContainerData.new()
		c.x = tx
		c.y = ty
		c.label = container_label
		lv.containers.append(c)
		d.container = c
	if hide_label != "":
		var hs := LevelData.HideSpot.new()
		hs.x = tx
		hs.y = ty
		hs.enter_x = hide_ex
		hs.enter_y = hide_ey
		hs.label = hide_label
		lv.hides.append(hs)
		d.hide = hs
	d.is_cradle = fname == "Колыбель"
	lv.decos.append(d)
	return d

func build_house() -> LevelData:
	var lv := LevelData.new(32, 32, 0, "Дом Гренни")
	lv.room_names.assign(["Спальня", "Кухня", "Коридор", "Гостиная", "Кладовая", "Кабинет", "Ванная", "Прихожая"])
	lv.fill_rect(2, 2, 11, 12, LevelData.FLOOR)
	lv.fill_rect(20, 2, 29, 12, LevelData.FLOOR)
	lv.fill_rect(14, 2, 16, 13, LevelData.FLOOR)
	lv.fill_rect(2, 14, 29, 16, LevelData.FLOOR)
	lv.fill_rect(2, 18, 11, 24, LevelData.FLOOR)
	lv.fill_rect(20, 18, 29, 24, LevelData.FLOOR)
	lv.fill_rect(2, 26, 11, 29, LevelData.FLOOR)
	lv.fill_rect(20, 26, 29, 29, LevelData.FLOOR)
	lv.fill_rect(13, 17, 18, 29, LevelData.FLOOR)

	_wallpaper_pass(lv)
	for y in range(1, 14):
		for x in range(1, 13):
			if lv.get_tile(x, y) == LevelData.PLASTER:
				lv.set_tile(x, y, LevelData.WP)
	for y in range(1, lv.h - 1):
		for x in range(1, lv.w - 1):
			var tb := lv.get_tile(x, y)
			if tb != LevelData.WP and tb != LevelData.BRICK and tb != LevelData.PLASTER:
				continue
			if y >= 25 and x >= 19:
				lv.set_tile(x, y, LevelData.TILEW)
			elif y >= 17 and x >= 19:
				lv.set_tile(x, y, LevelData.PANEL)
			elif y >= 17 and x <= 12:
				lv.set_tile(x, y, LevelData.PANEL)

	var windows := [5, 8, 22, 26]
	for wx in windows:
		lv.set_tile(wx, 1, LevelData.WINDOW)
		lv.set_tile(wx, 30, LevelData.WINDOW)
	lv.set_tile(1, 8, LevelData.WINDOW)
	lv.set_tile(1, 20, LevelData.WINDOW)
	lv.set_tile(30, 6, LevelData.WINDOW)
	lv.set_tile(30, 21, LevelData.WINDOW)

	lv.add_door(6, 13)
	lv.add_door(24, 13)
	lv.add_door(7, 17)
	lv.add_door(24, 17)
	lv.add_door(7, 25)
	lv.add_door(24, 25)
	lv.set_tile(15, 30, LevelData.FRONT)
	lv.set_tile(16, 30, LevelData.WP)
	var front := LevelData.Door.new()
	front.x = 15
	front.y = 30
	front.front = true
	lv.doors.append(front)

	lv.set_tile(15, 3, LevelData.HOLE)
	lv.set_tile(14, 28, LevelData.HOLE)
	lv.set_tile(5, 29, LevelData.HOLE)

	var bed := add_furn(lv, 2, 4, 0, "Кровать")
	lv.fill_rect(4, 6, 8, 8, LevelData.RUG)
	add_furn(lv, 3, 3, 12, "Ночной столик", "Ночной столик")
	add_furn(lv, 10, 3, 5, "Шкаф", "", "Шкаф в спальне", 10, 4)
	add_furn(lv, 10, 9, 6, "Комод", "Комод в спальне")

	add_furn(lv, 20, 2, 7, "Холодильник", "Холодильник")
	add_furn(lv, 21, 2, 8, "Плита")
	add_furn(lv, 24, 2, 6, "Кухонный шкаф", "Кухонный шкаф")
	add_furn(lv, 25, 2, 9, "Полка")
	add_furn(lv, 28, 2, 6, "Кухонный шкаф", "Шкаф у плиты")
	add_furn(lv, 28, 11, 6, "Комод", "Кухонный шкаф")
	add_furn(lv, 23, 2, 13, "Подвесной шкаф")
	add_furn(lv, 26, 2, 13, "Подвесной шкаф")
	add_furn(lv, 24, 7, 1, "Стол")
	add_furn(lv, 23, 6, 14, "Кастрюля")
	add_furn(lv, 25, 6, 14, "Кастрюля")
	add_furn(lv, 23, 7, 11, "Стул")
	add_furn(lv, 25, 8, 11, "Стул")

	add_furn(lv, 2, 18, 9, "Стеллаж")
	add_furn(lv, 2, 23, 6, "Комод", "Комод в гостиной")
	add_furn(lv, 5, 23, 2, "Диван")
	lv.fill_rect(5, 20, 8, 22, LevelData.RUG)
	add_furn(lv, 6, 20, 1, "Столик")
	add_furn(lv, 10, 20, 18, "Торшер")
	add_furn(lv, 9, 23, 10, "Телевизор", "Тумба под телевизор")
	add_furn(lv, 10, 18, 3, "Ящик")

	add_furn(lv, 28, 18, 3, "Ящик")
	add_furn(lv, 28, 19, 3, "Ящик")
	add_furn(lv, 20, 18, 9, "Стеллаж")
	add_furn(lv, 28, 23, 6, "Комод", "Ящик в кладовой")
	add_furn(lv, 22, 21, 3, "Большой ящик")

	add_furn(lv, 2, 26, 9, "Книжный шкаф")
	add_furn(lv, 4, 26, 9, "Книжный шкаф")
	add_furn(lv, 8, 28, 4, "Стол")
	add_furn(lv, 8, 27, 11, "Стул")
	add_furn(lv, 10, 29, 6, "Тумба", "Ящик стола")
	add_furn(lv, 7, 29, 3, "Старый ящик", "Старый ящик")

	add_furn(lv, 28, 26, 6, "Шкафчик", "Шкафчик в ванной")
	lv.set_tile(21, 29, LevelData.TOWELS)
	lv.set_tile(24, 29, LevelData.MIRROR)

	add_furn(lv, 18, 20, 5, "Шкаф", "", "Шкаф в прихожей", 17, 20)
	add_furn(lv, 13, 20, 15, "Вешалка")
	add_furn(lv, 13, 21, 16, "Обувь")
	add_furn(lv, 13, 22, 1, "Столик")
	add_furn(lv, 17, 28, 3, "Ящик")
	lv.set_tile(12, 26, LevelData.PORTRAIT)
	lv.set_tile(12, 22, LevelData.PORTRAIT)
	lv.set_tile(19, 27, LevelData.PORTRAIT)

	var bed_hide := LevelData.HideSpot.new()
	bed_hide.x = 2
	bed_hide.y = 4
	bed_hide.enter_x = 2
	bed_hide.enter_y = 5
	bed_hide.is_bed = true
	bed_hide.label = "Под кроватью"
	lv.hides.append(bed_hide)
	bed.hide = bed_hide

	lv.spawn_x = 15.5
	lv.spawn_y = 27.5
	lv.spawn_a = -PI / 2.0
	return lv

func build_attic() -> LevelData:
	var lv := LevelData.new(24, 24, 1, "Чердак")
	lv.room_names.assign(["Чердак"])
	lv.fill_rect(2, 2, 21, 21, LevelData.FLOOR)
	lv.set_tile(10, 11, LevelData.ATTICWOOD)
	lv.set_tile(15, 11, LevelData.ATTICWOOD)
	lv.set_tile(10, 16, LevelData.ATTICWOOD)
	lv.set_tile(15, 16, LevelData.ATTICWOOD)
	lv.fill_rect(2, 2, 3, 21, LevelData.ATTICWOOD)
	for y in range(1, lv.h - 1):
		for x in range(1, lv.w - 1):
			if lv.get_tile(x, y) == LevelData.BRICK:
				lv.set_tile(x, y, LevelData.ATTIC)
	lv.set_tile(11, 1, LevelData.WINDOW)
	lv.set_tile(4, 20, LevelData.HOLE)
	lv.set_tile(20, 7, LevelData.CAGE)
	lv.set_tile(20, 8, LevelData.CAGE)
	lv.set_tile(19, 14, LevelData.PORTRAIT)
	lv.fill_rect(11, 8, 14, 9, LevelData.RUG)
	add_furn(lv, 9, 4, 3, "Старый сундук", "Старый сундук")
	add_furn(lv, 4, 3, 9, "Полка с хламом", "Полка с хламом")
	add_furn(lv, 16, 16, 3, "Ящик", "Ящик на чердаке")
	add_furn(lv, 17, 3, 3, "Ящик")
	add_furn(lv, 18, 3, 3, "Ящик")
	add_furn(lv, 7, 19, 3, "Ящик")
	add_furn(lv, 14, 19, 3, "Ящик")
	add_furn(lv, 13, 6, 3, "Ящик")
	add_furn(lv, 6, 8, 5, "Старый шкаф", "", "Старый шкаф", 6, 9)
	add_furn(lv, 18, 12, 9, "Полка")
	add_furn(lv, 20, 4, 3, "Колыбель")
	lv.spawn_x = 4.5
	lv.spawn_y = 19.0
	lv.spawn_a = -PI / 2.0
	return lv

func build_garage() -> LevelData:
	var lv := LevelData.new(16, 16, 2, "Гараж")
	lv.room_names.assign(["Гараж"])
	lv.fill_rect(2, 2, 13, 13, LevelData.FLOOR)
	lv.set_tile(6, 1, LevelData.WINDOW)
	lv.set_tile(9, 1, LevelData.WINDOW)
	lv.set_tile(4, 13, LevelData.HOLE)
	var car := LevelData.Deco.new()
	car.x = 10.5
	car.y = 4.5
	car.kind = 13
	car.rx = 2.10
	car.ry = 0.90
	car.rot = 1
	car.name = "Машина"
	car.is_car = true
	lv.decos.append(car)
	for x in range(5, 11):
		lv.set_tile(x, 14, LevelData.GARAGE_DOOR)
	add_furn(lv, 3, 9, 4, "Верстак")
	add_furn(lv, 3, 12, 9, "Стеллаж с инструментами", "Стеллаж с инструментами")
	add_furn(lv, 12, 10, 3, "Ящик у верстака", "Ящик у верстака")
	add_furn(lv, 12, 11, 3, "Канистра", "Канистра с тряпками")
	var shelf := lv.container_at(3, 12)
	if shelf != null:
		shelf.item_id = Items.CAR_BATTERY
	var gbox := lv.container_at(12, 10)
	if gbox != null:
		gbox.item_id = Items.NOTE2
	lv.spawn_x = 4.5
	lv.spawn_y = 12.0
	lv.spawn_a = -PI / 2.0
	return lv

func build_cellar() -> LevelData:
	var lv := LevelData.new(20, 20, 3, "Паучий подвал")
	lv.room_names.assign(["Паучий подвал"])
	lv.fill_rect(2, 2, 17, 17, LevelData.FLOOR)
	lv.set_tile(7, 6, LevelData.ATTICWOOD)
	lv.set_tile(13, 6, LevelData.ATTICWOOD)
	lv.set_tile(7, 13, LevelData.ATTICWOOD)
	lv.set_tile(13, 13, LevelData.ATTICWOOD)
	lv.set_tile(10, 1, LevelData.WINDOW)
	lv.set_tile(4, 17, LevelData.HOLE)
	lv.webs.append(Rect2(5.0, 4.0, 4.0, 4.0))
	lv.webs.append(Rect2(11.0, 9.0, 4.0, 3.5))
	lv.webs.append(Rect2(7.0, 12.5, 4.0, 3.5))
	add_furn(lv, 15, 15, 3, "Ящик", "Ящик в подвале")
	add_furn(lv, 15, 16, 3, "Ящик", "Ящик в подвале 2")
	var pbox := lv.container_at(15, 15)
	if pbox != null:
		pbox.item_id = Items.PHOTO
	var tbox := lv.container_at(15, 16)
	if tbox != null:
		tbox.item_id = Items.TEDDY
	add_furn(lv, 16, 9, 9, "Стеллаж", "Полка с хламом")
	lv.spawn_x = 4.5
	lv.spawn_y = 16.0
	lv.spawn_a = -PI / 2.0
	return lv

func build_lamps() -> void:
	house.lamps.append(Vector3(6.5, 2.25, 7.0))
	house.lamps.append(Vector3(24.5, 2.25, 7.0))
	house.lamps.append(Vector3(15.5, 2.25, 9.5))
	house.lamps.append(Vector3(15.5, 2.25, 22.0))
	house.lamps.append(Vector3(6.5, 2.25, 21.5))
	house.lamps.append(Vector3(24.5, 2.25, 21.5))
	house.lamps.append(Vector3(6.5, 2.25, 27.5))
	house.lamps.append(Vector3(24.5, 2.25, 27.5))
	house.lamps.append(Vector3(15.5, 2.25, 15.5))
	attic.lamps.append(Vector3(15.5, 2.25, 5.0))
	attic.lamps.append(Vector3(11.5, 2.25, 11.5))
	attic.lamps.append(Vector3(17.5, 2.25, 15.0))
	attic.lamps.append(Vector3(5.5, 2.25, 17.5))
	garage.lamps.append(Vector3(8.5, 2.25, 8.5))
	garage.lamps.append(Vector3(12.5, 2.25, 12.0))
	cellar.lamps.append(Vector3(10.5, 2.25, 9.5))
	cellar.lamps.append(Vector3(5.5, 2.25, 15.5))

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

func distribute_items() -> void:
	var pool: Array[LevelData.ContainerData] = []
	var bow: LevelData.ContainerData = null
	for c in house.containers:
		if bow == null and c.label == "Старый ящик":
			bow = c
		else:
			pool.append(c)
	if bow == null:
		bow = house.containers[0]
	_shuffle(pool)

	var chest := attic.containers[0]
	chest.item_id = Items.NOTE

	var req := [Items.KEY, Items.CROWBAR, Items.MILK, Items.BATTERY, Items.BANDAGE]
	_shuffle(req)
	for i in mini(req.size(), pool.size()):
		pool[i].item_id = req[i]

	var extra := [Items.BOTTLE, Items.BOTTLE, Items.BATTERY, Items.MILK]
	var idx := req.size()
	var e := 0
	while idx < pool.size() and e < extra.size():
		pool[idx].item_id = extra[e]
		idx += 1
		e += 1

	bow.item_id = Items.CROSSBOW

	var darts_left := 3
	for c in pool:
		if darts_left <= 0:
			break
		if c.item_id == Items.NONE:
			c.item_id = Items.DART
			darts_left -= 1
	for c in attic.containers:
		if darts_left <= 0:
			break
		if c.item_id == Items.NONE:
			c.item_id = Items.DART
			darts_left -= 1

	var car_key_placed := false
	for c in pool:
		if c.item_id == Items.NONE:
			c.item_id = Items.CAR_KEY
			car_key_placed = true
			break
	if not car_key_placed:
		for c in attic.containers:
			if c.item_id == Items.NONE:
				c.item_id = Items.CAR_KEY
				car_key_placed = true
				break

	if attic.containers.size() > 1 and attic.containers[1].item_id == Items.NONE:
		attic.containers[1].item_id = Items.BOTTLE
	if attic.containers.size() > 2 and attic.containers[2].item_id == Items.NONE:
		attic.containers[2].item_id = Items.BANDAGE
