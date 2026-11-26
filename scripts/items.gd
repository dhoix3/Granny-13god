class_name Items
extends RefCounted

# Item IDs (same values as the original C# game).
const NONE := 0
const KEY := 1
const CROWBAR := 2
const NOTE := 3
const MILK := 4
const BATTERY := 5
const BANDAGE := 6
const BOTTLE := 7
const CROSSBOW := 8
const DART := 9
const CAR_KEY := 11
const CAR_BATTERY := 12
const NOTE2 := 13
const PHOTO := 14
const TEDDY := 15

static var _icon_cache: Dictionary = {}

static func display_name(id: int) -> String:
	match id:
		KEY: return "Ключ от замка"
		CROWBAR: return "Монтировка"
		NOTE: return "Записка с кодом"
		MILK: return "Молоко для Маруси"
		BATTERY: return "Батарейка"
		BANDAGE: return "Бинт"
		BOTTLE: return "Бутылка (G — бросить)"
		CROSSBOW: return "Арбалет (Q — выстрел)"
		DART: return "Стрела с транквилизатором"
		CAR_KEY: return "Ключ от машины"
		CAR_BATTERY: return "Аккумулятор"
		NOTE2: return "Записка с кодом 2"
		PHOTO: return "Семейное фото"
		TEDDY: return "Плюшевый мишка"
	return ""

static func short_name(id: int) -> String:
	match id:
		KEY: return "Ключ"
		CROWBAR: return "Монтировка"
		NOTE: return "Код 137"
		MILK: return "Молоко"
		BATTERY: return "Батарейка"
		BANDAGE: return "Бинт"
		BOTTLE: return "Бутылка"
		CROSSBOW: return "Арбалет"
		DART: return "Стрела"
		CAR_KEY: return "Ключ от машины"
		CAR_BATTERY: return "Аккумулятор"
		NOTE2: return "Код 274"
		PHOTO: return "Фото"
		TEDDY: return "Тедди"
	return ""

static func hint(id: int) -> String:
	match id:
		KEY: return "Тяжёлый ключ. Подойдёт к висячему замку."
		CROWBAR: return "Можно отжать ржавый засов."
		NOTE: return "«Код от кодового замка: 137»"
		MILK: return "Маруся будет спать как убитая."
		BATTERY: return "Ещё немного света в этом аду."
		BANDAGE: return "Перевязать ногу. +Здоровье."
		BOTTLE: return "Разбей её в другом конце дома — она прибежит на звук."
		CROSSBOW: return "Q — выстрел. Стрела с успокоительным усыпит Гренни."
		DART: return "Боеприпас для арбалета. Попадёт — она на четверть минуты отключится."
		CAR_KEY: return "От бабушкиного «Запорожца». Осталось найти аккумулятор (гараж)."
		CAR_BATTERY: return "Жёлтый бугай. Он ещё живой — подать в зажигание должны силы."
		NOTE2: return "«Код от четвёртого замка: 274». Только на Сложном и Кошмаре."
		PHOTO: return "Фотография семьи. Бабушка не любит, когда её напоминают о прошлом. +1 день."
		TEDDY: return "Гренни узнаёт своего мишку. Пока он у тебя — она идёт по пятам. Положи его в колыбель на чердаке."
	return ""

# Atlas icon index (0..15).
static func icon_index(id: int) -> int:
	match id:
		KEY: return 0
		CROWBAR: return 1
		NOTE: return 2
		MILK: return 3
		BATTERY: return 4
		BANDAGE: return 5
		BOTTLE: return 8
		CROSSBOW: return 9
		DART: return 10
		CAR_KEY: return 11
		CAR_BATTERY: return 12
		NOTE2: return 13
		PHOTO: return 14
		TEDDY: return 15
	return 7

static func icon_texture(id: int) -> Texture2D:
	var idx := icon_index(id)
	if _icon_cache.has(idx):
		return _icon_cache[idx]
	var tex: Texture2D = null
	if idx <= 8:
		var atlas := load("res://assets/items.png") as Texture2D
		if atlas:
			var at := AtlasTexture.new()
			at.atlas = atlas
			at.region = Rect2((idx % 4) * 128, (idx / 4) * 128, 128, 128)
			tex = at
	if tex == null:
		tex = _make_icon(idx)
	_icon_cache[idx] = tex
	return tex

# Simple procedural fallback icons for the items missing from items.png.
static func _make_icon(idx: int) -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.48, 0.29, 0.13)
	var metal := Color(0.55, 0.58, 0.63)
	var dark := Color(0.12, 0.11, 0.10)
	var paper := Color(0.90, 0.86, 0.72)
	var red := Color(0.72, 0.12, 0.10)
	match idx:
		9: # crossbow
			_line(img, 10, 52, 48, 18, wood, 5)
			_line(img, 22, 20, 42, 44, wood, 4)
			_line(img, 8, 20, 30, 8, metal, 3)
			_line(img, 30, 8, 54, 22, metal, 3)
			_line(img, 8, 20, 54, 22, Color(0.90, 0.88, 0.78), 2)
			_line(img, 28, 6, 36, 26, Color(0.80, 0.82, 0.86), 2)
		10: # dart
			_line(img, 12, 50, 40, 22, metal, 5)
			_line(img, 40, 22, 54, 8, Color(0.82, 0.86, 0.90), 2)
			_rect(img, 14, 38, 10, 18, Color(0.62, 0.66, 0.70))
			_rect(img, 16, 40, 6, 12, Color(0.85, 0.20, 0.18))
			_line(img, 10, 54, 26, 58, red, 3)
		11: # car key
			_disc(img, 20, 20, 10, Color(0.78, 0.72, 0.45))
			_disc(img, 20, 20, 5, Color(0, 0, 0, 0))
			_line(img, 27, 27, 50, 50, Color(0.78, 0.72, 0.45), 6)
			_line(img, 42, 42, 50, 34, Color(0.78, 0.72, 0.45), 4)
			_line(img, 47, 47, 55, 39, Color(0.78, 0.72, 0.45), 4)
		12: # car battery
			_rect(img, 12, 18, 40, 32, Color(0.82, 0.70, 0.16))
			_rect(img, 16, 12, 8, 8, metal)
			_rect(img, 40, 12, 8, 8, metal)
			_rect(img, 18, 28, 28, 4, dark)
			_rect(img, 18, 36, 20, 4, dark)
		13: # note 274
			_rect(img, 14, 8, 36, 48, paper)
			for i in 5:
				_line(img, 20, 20 + i * 6, 44, 20 + i * 6, Color(0.45, 0.38, 0.30), 1)
			_rect(img, 24, 36, 16, 8, red)
		14: # family photo
			_rect(img, 8, 12, 48, 40, Color(0.55, 0.43, 0.28))
			_rect(img, 12, 16, 40, 32, Color(0.55, 0.66, 0.72))
			_disc(img, 24, 30, 5, Color(0.86, 0.70, 0.58))
			_disc(img, 38, 30, 5, Color(0.86, 0.70, 0.58))
			_rect(img, 19, 34, 10, 10, Color(0.35, 0.40, 0.52))
			_rect(img, 33, 34, 10, 10, Color(0.52, 0.32, 0.34))
		15: # teddy
			_disc(img, 24, 38, 13, Color(0.52, 0.34, 0.18))
			_disc(img, 40, 38, 13, Color(0.52, 0.34, 0.18))
			_disc(img, 32, 32, 12, Color(0.60, 0.40, 0.22))
			_disc(img, 27, 29, 2, dark)
			_disc(img, 37, 29, 2, dark)
			_disc(img, 32, 35, 3, Color(0.28, 0.17, 0.09))
	var tex := ImageTexture.create_from_image(img)
	return tex

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, mini(y + h, img.get_height())):
		for xx in range(x, mini(x + w, img.get_width())):
			if xx >= 0 and yy >= 0:
				img.set_pixel(xx, yy, c)

static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for yy in range(cy - r, cy + r + 1):
		for xx in range(cx - r, cx + r + 1):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				if (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) <= r * r:
					img.set_pixel(xx, yy, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, width: int = 1) -> void:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0
	while true:
		_disc(img, x, y, maxi(0, width / 2), c)
		if x == x1 and y == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
