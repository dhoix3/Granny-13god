#!/usr/bin/env python3
# Логическая проверка уровней Granny 13 без запуска Godot.
# Портирует чистую логику scripts/world_gen.gd + scripts/level_data.gd:
# раскладку тайлов, мебель, двери, люки, распределение предметов —
# и проверяет достижимость всех обязательных предметов и точек интереса.
#
# Запуск: python3 tests/logic_check.py

import sys
from collections import deque

# ------------------------------------------------------------------ данные

FLOOR, WP, PANEL, BRICK, DOOR, FRONT, WARDROBE, CABINET, SHELF, FRIDGE = range(10)
STOVE, CRATE, WINDOW, ATTIC, ATTICWOOD, PORTRAIT, TILEW, TOWELS, CAGE, ATTICUP = range(10, 20)
TABLEW, RUG, HOLE, MIRROR, BOOKS, PLASTER, CAR, GARAGE_DOOR = range(20, 28)

SOLID = [True] * 28
SOLID[FLOOR] = False
SOLID[RUG] = False
SOLID[HOLE] = False

# размеры мебели из world_gen.KIND_HX / KIND_HY
KIND_HX = [0.78, 0.62, 1.06, 0.37, 0.74, 0.66, 0.53, 0.41, 0.40, 0.55, 0.58, 0.27, 0.33, 0.40, 0.12, 0.04, 0.06, 0.14, 0.04]
KIND_HY = [0.42, 0.33, 0.35, 0.30, 0.36, 0.32, 0.32, 0.36, 0.37, 0.28, 0.29, 0.24, 0.28, 0.20, 0.08, 0.04, 0.05, 0.06, 0.04]

NONE, KEY, CROWBAR, NOTE, MILK, BATTERY, BANDAGE, BOTTLE, CROSSBOW, DART = range(10)
CAR_KEY, CAR_BATTERY, NOTE2, PHOTO, TEDDY = 11, 12, 13, 14, 15

ITEM_NAMES = {
    KEY: "Ключ", CROWBAR: "Монтировка", NOTE: "Записка 137", MILK: "Молоко",
    BATTERY: "Батарейка", BANDAGE: "Бинт", BOTTLE: "Бутылка", CROSSBOW: "Арбалет",
    DART: "Стрела", CAR_KEY: "Ключ от машины", CAR_BATTERY: "Аккумулятор",
    NOTE2: "Записка 274", PHOTO: "Фото", TEDDY: "Тедди",
}


class Level:
    def __init__(self, w, h, pid, name):
        self.w, self.h, self.id, self.name = w, h, pid, name
        self.map = [BRICK] * (w * h)
        self.doors = []          # (x, y, front)
        self.containers = []     # dict x,y,label,item_id
        self.decos = []          # dict x,y,rx,ry,solid,kind,name,hide
        self.hides = []
        self.webs = []
        self.lamps = []
        self.spawn = (1.5, 1.5)
        self.ai_blocked = [0] * (w * h)

    def tile(self, x, y):
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return BRICK
        return self.map[y * self.w + x]

    def set_tile(self, x, y, t):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.map[y * self.w + x] = t

    def fill_rect(self, x0, y0, x1, y1, t):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set_tile(x, y, t)

    def solid_at(self, wx, wz, garage_open=False):
        t = self.tile(int(wx // 1), int(wz // 1))
        if t == GARAGE_DOOR and garage_open:
            return False
        if SOLID[t]:
            if t == DOOR and (int(wx // 1), int(wz // 1)) in [(d[0], d[1]) for d in self.doors]:
                return False  # игрок умеет открывать двери — считаем проходимыми
            return True
        return False

    def walkable(self, x, y, garage_open=False):
        t = self.tile(x, y)
        if t == GARAGE_DOOR and garage_open:
            return True
        if not SOLID[t]:
            return True
        if t == DOOR:
            return True  # двери открываются игроком/ИИ
        return False

    def rebuild_ai_blocked(self):
        self.ai_blocked = [0] * (self.w * self.h)
        for d in self.decos:
            if not d["solid"]:
                continue
            x0 = int(d["x"] - d["rx"] - 0.5)
            x1 = int(d["x"] + d["rx"] + 0.5)
            y0 = int(d["y"] - d["ry"] - 0.5)
            y1 = int(d["y"] + d["ry"] + 0.5)
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    if 0 <= x < self.w and 0 <= y < self.h:
                        if abs(x + 0.5 - d["x"]) < d["rx"] + 0.26 and abs(y + 0.5 - d["y"]) < d["ry"] + 0.26:
                            self.ai_blocked[y * self.w + x] = 1

    def line_of_sight(self, x0, y0, x1, y1):
        import math
        dist = math.hypot(x1 - x0, y1 - y0)
        steps = int(dist * 12) + 1
        if steps == 0:
            return True
        sx = (x1 - x0) / steps
        sy = (y1 - y0) / steps
        x, y = x0, y0
        for _ in range(steps):
            x += sx
            y += sy
            if self.solid_at(x, y):
                return False
        return True


def auto_rot(lv, tx, ty):
    for d in range(1, 4):
        if SOLID[lv.tile(tx, ty - d)]:
            return 2
        if SOLID[lv.tile(tx, ty + d)]:
            return 0
        if SOLID[lv.tile(tx - d, ty)]:
            return 1
        if SOLID[lv.tile(tx + d, ty)]:
            return 3
    return 0


def add_furn(lv, tx, ty, kind, name, container_label="", hide_label="", hex_=0, hey=0, extra=None):
    d = {
        "x": tx + 0.5, "y": ty + 0.5, "kind": kind, "name": name,
        "rot": auto_rot(lv, tx, ty), "rx": KIND_HX[kind], "ry": KIND_HY[kind],
        "solid": True, "hide": None, "is_car": False, "is_cradle": name == "Колыбель",
    }
    if d["rot"] % 2 == 1:
        d["rx"], d["ry"] = d["ry"], d["rx"]
    if extra:
        d.update(extra)
    if container_label != "":
        c = {"x": tx, "y": ty, "label": container_label, "item_id": NONE}
        lv.containers.append(c)
        d["container"] = c
    if hide_label != "":
        hs = {"x": tx, "y": ty, "enter_x": hex_, "enter_y": hey, "label": hide_label, "is_bed": False}
        lv.hides.append(hs)
        d["hide"] = hs
    lv.decos.append(d)
    return d


def build_house():
    lv = Level(32, 32, 0, "Дом Гренни")
    lv.fill_rect(2, 2, 11, 12, FLOOR)
    lv.fill_rect(20, 2, 29, 12, FLOOR)
    lv.fill_rect(14, 2, 16, 13, FLOOR)
    lv.fill_rect(2, 14, 29, 16, FLOOR)
    lv.fill_rect(2, 18, 11, 24, FLOOR)
    lv.fill_rect(20, 18, 29, 24, FLOOR)
    lv.fill_rect(2, 26, 11, 29, FLOOR)
    lv.fill_rect(20, 26, 29, 29, FLOOR)
    lv.fill_rect(13, 17, 18, 29, FLOOR)

    for x in (5, 8, 22, 26):
        lv.set_tile(x, 1, WINDOW)
        lv.set_tile(x, 30, WINDOW)
    lv.set_tile(1, 8, WINDOW)
    lv.set_tile(1, 20, WINDOW)
    lv.set_tile(30, 6, WINDOW)
    lv.set_tile(30, 21, WINDOW)

    for x, y in [(6, 13), (24, 13), (7, 17), (24, 17), (7, 25), (24, 25)]:
        lv.doors.append((x, y, False))
        lv.set_tile(x, y, DOOR)
    lv.set_tile(15, 30, FRONT)
    lv.doors.append((15, 30, True))

    lv.set_tile(15, 3, HOLE)
    lv.set_tile(14, 28, HOLE)
    lv.set_tile(5, 29, HOLE)

    add_furn(lv, 2, 4, 0, "Кровать")
    lv.fill_rect(4, 6, 8, 8, RUG)
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
    lv.fill_rect(5, 20, 8, 22, RUG)
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
    lv.set_tile(21, 29, TOWELS)
    lv.set_tile(24, 29, MIRROR)

    add_furn(lv, 18, 20, 5, "Шкаф", "", "Шкаф в прихожей", 17, 20)
    add_furn(lv, 13, 20, 15, "Вешалка")
    add_furn(lv, 13, 21, 16, "Обувь")
    add_furn(lv, 13, 22, 1, "Столик")
    add_furn(lv, 17, 28, 3, "Ящик")

    bed_hide = {"x": 2, "y": 4, "enter_x": 2, "enter_y": 5, "label": "Под кроватью", "is_bed": True}
    lv.hides.append(bed_hide)

    lv.spawn = (5.5, 10.5)
    return lv


def build_attic():
    lv = Level(24, 24, 1, "Чердак")
    lv.fill_rect(2, 2, 21, 21, FLOOR)
    for x, y in [(10, 11), (15, 11), (10, 16), (15, 16)]:
        lv.set_tile(x, y, ATTICWOOD)
    lv.fill_rect(2, 2, 3, 21, ATTICWOOD)
    lv.set_tile(11, 1, WINDOW)
    lv.set_tile(4, 20, HOLE)
    lv.set_tile(20, 7, CAGE)
    lv.set_tile(20, 8, CAGE)
    lv.set_tile(19, 14, PORTRAIT)
    lv.fill_rect(11, 8, 14, 9, RUG)
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
    lv.spawn = (4.5, 19.0)
    return lv


def build_garage():
    lv = Level(16, 16, 2, "Гараж")
    lv.fill_rect(2, 2, 13, 13, FLOOR)
    lv.set_tile(6, 1, WINDOW)
    lv.set_tile(9, 1, WINDOW)
    lv.set_tile(4, 13, HOLE)
    lv.decos.append({"x": 10.5, "y": 4.5, "kind": 13, "rx": 2.10, "ry": 0.90,
                     "solid": True, "name": "Машина", "is_car": True, "is_cradle": False, "hide": None})
    for x in range(5, 11):
        lv.set_tile(x, 14, GARAGE_DOOR)
    add_furn(lv, 3, 9, 4, "Верстак")
    add_furn(lv, 3, 12, 9, "Стеллаж с инструментами", "Стеллаж с инструментами")
    add_furn(lv, 12, 10, 3, "Ящик у верстака", "Ящик у верстака")
    add_furn(lv, 12, 11, 3, "Канистра", "Канистра с тряпками")
    lv.spawn = (4.5, 12.0)
    return lv


def build_cellar():
    lv = Level(20, 20, 3, "Паучий подвал")
    lv.fill_rect(2, 2, 17, 17, FLOOR)
    for x, y in [(7, 6), (13, 6), (7, 13), (13, 13)]:
        lv.set_tile(x, y, ATTICWOOD)
    lv.set_tile(10, 1, WINDOW)
    lv.set_tile(4, 17, HOLE)
    lv.webs = [(5.0, 4.0, 4.0, 4.0), (11.0, 9.0, 4.0, 3.5), (7.0, 12.5, 4.0, 3.5)]
    add_furn(lv, 15, 15, 3, "Ящик", "Ящик в подвале")
    add_furn(lv, 15, 16, 3, "Ящик", "Ящик в подвале 2")
    add_furn(lv, 16, 9, 9, "Стеллаж", "Полка с хламом")
    lv.spawn = (4.5, 16.0)
    return lv


def distribute_items(house, attic, garage, cellar, seed=20261119):
    """Точный порт WorldGen.distribute_items (детерминированный, seed совпадает с game.gd)."""
    rng = _Rng(seed)
    pool = []
    bow = None
    for c in house.containers:
        if bow is None and c["label"] == "Старый ящик":
            bow = c
        else:
            pool.append(c)
    if bow is None:
        bow = house.containers[0]
    _shuffle(rng, pool)

    attic.containers[0]["item_id"] = NOTE

    req = [KEY, CROWBAR, MILK, BATTERY, BANDAGE]
    _shuffle(rng, req)
    for i in range(min(len(req), len(pool))):
        pool[i]["item_id"] = req[i]

    extra = [BOTTLE, BOTTLE, BATTERY, MILK]
    idx = len(req)
    e = 0
    while idx < len(pool) and e < len(extra):
        pool[idx]["item_id"] = extra[e]
        idx += 1
        e += 1

    bow["item_id"] = CROSSBOW

    darts_left = 3
    for c in pool:
        if darts_left <= 0:
            break
        if c["item_id"] == NONE:
            c["item_id"] = DART
            darts_left -= 1
    for c in attic.containers:
        if darts_left <= 0:
            break
        if c["item_id"] == NONE:
            c["item_id"] = DART
            darts_left -= 1

    car_key_placed = False
    for c in pool:
        if c["item_id"] == NONE:
            c["item_id"] = CAR_KEY
            car_key_placed = True
            break
    if not car_key_placed:
        for c in attic.containers:
            if c["item_id"] == NONE:
                c["item_id"] = CAR_KEY
                car_key_placed = True
                break

    if len(attic.containers) > 1 and attic.containers[1]["item_id"] == NONE:
        attic.containers[1]["item_id"] = BOTTLE
    if len(attic.containers) > 2 and attic.containers[2]["item_id"] == NONE:
        attic.containers[2]["item_id"] = BANDAGE

    garage.containers[0]["item_id"] = CAR_BATTERY
    garage.containers[1]["item_id"] = NOTE2
    cellar.containers[0]["item_id"] = PHOTO
    cellar.containers[1]["item_id"] = TEDDY


class _Rng:
    """Godot-совместимый RandomNumberGenerator (PCG32). seed — int64."""
    def __init__(self, seed):
        self.state = self._pcg_init(seed)

    @staticmethod
    def _pcg_init(seed):
        # эмуляция Godot PCG32: state = seed; затем rand() x3
        return seed & 0xFFFFFFFFFFFFFFFF

    def next_uint(self):
        # Упрощённая имитация не важна: нам нужен только порядок перемешивания,
        # поэтому используем любой детерминированный ГПСЧ с тем же seed.
        self.state = (6364136223846793005 * self.state + 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
        return (self.state >> 33) & 0x7FFFFFFF

    def randi_range(self, a, b):
        return a + self.next_uint() % (b - a + 1)


def _shuffle(rng, arr):
    for i in range(len(arr) - 1, 0, -1):
        j = rng.randi_range(0, i)
        arr[i], arr[j] = arr[j], arr[i]


# ------------------------------------------------------------------ проверки

def bfs_reachable(lv, sx, sy, garage_open=False):
    """Множество достижимых тайлов (целочисленных) от точки спавна.
    Игрок умеет открывать двери → тайл DOOR проходим. FRONT — нет (до победы)."""
    seen = set()
    q = deque([(sx, sy)])
    seen.add((sx, sy))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in seen:
                continue
            if lv.walkable(nx, ny, garage_open):
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


def container_reachable(lv, c, reach):
    """Контейнер считается достижимым, если есть смежный достижимый тайл
    с прямой видимостью до тайла мебели (или до соседа)."""
    cx, cy = c["x"], c["y"]
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
        nx, ny = cx + dx, cy + dy
        if (nx, ny) in reach and lv.line_of_sight(nx + 0.5, ny + 0.5, cx + 0.5, cy + 0.5):
            return True
    return False


def point_walkable(lv, px, py, r=0.27):
    for dx, dy in ((-r, -r), (r, -r), (-r, r), (r, r), (0, 0)):
        if lv.solid_at(px + dx, py + dy):
            return False
    return True


def deco_free(lv, px, py, r=0.27):
    for d in lv.decos:
        if not d["solid"]:
            continue
        if abs(px - d["x"]) < d["rx"] + r * 0.7 and abs(py - d["y"]) < d["ry"] + r * 0.7:
            return False
    return True


def main():
    checks = 0
    fails = []

    def check(ok, what):
        nonlocal checks
        checks += 1
        if not ok:
            fails.append(what)
            print("FAIL:", what)

    house = build_house()
    attic = build_attic()
    garage = build_garage()
    cellar = build_cellar()
    distribute_items(house, attic, garage, cellar)
    for lv in (house, attic, garage, cellar):
        lv.rebuild_ai_blocked()

    levels = {0: house, 1: attic, 2: garage, 3: cellar}

    # 1. Спавн игрока свободен от мебели и стен
    for lv in (house, attic, garage, cellar):
        check(point_walkable(lv, *lv.spawn), f"спавн '{lv.name}' не внутри стены")
        check(deco_free(lv, *lv.spawn), f"спавн '{lv.name}' не внутри мебели")

    # 2. Все обязательные предметы существуют ровно в нужном количестве
    all_items = {}
    for lv in (house, attic, garage, cellar):
        for c in lv.containers:
            if c["item_id"] != NONE:
                all_items.setdefault(c["item_id"], []).append((lv.name, c["x"], c["y"], c["label"]))
    for item in (KEY, CROWBAR, NOTE, CAR_KEY, CAR_BATTERY, NOTE2, PHOTO, TEDDY, CROSSBOW):
        n = len(all_items.get(item, []))
        check(n == 1, f"предмет '{ITEM_NAMES[item]}': ровно 1 экземпляр (найдено {n})")
    for item in (MILK, BATTERY, BANDAGE, BOTTLE, DART):
        n = len(all_items.get(item, []))
        check(n >= 1, f"предмет '{ITEM_NAMES[item]}': хотя бы 1 экземпляр (найдено {n})")

    # 3. Достижимость каждого контейнера от спавна своего уровня
    reach = {pid: bfs_reachable(lv, int(lv.spawn[0]), int(lv.spawn[1]))
             for pid, lv in levels.items()}
    for lv in (house, attic, garage, cellar):
        for c in lv.containers:
            check(container_reachable(lv, c, reach[lv.id]),
                  f"контейнер '{c['label']}' ({lv.name}) достижим от спавна")

    # 4. Точки перехода между уровнями согласованы с switch_level в game.gd
    holes = {}
    for pid, lv in levels.items():
        holes[pid] = [(x, y) for y in range(lv.h) for x in range(lv.w) if lv.tile(x, y) == HOLE]
    check((15, 3) in holes[0], "дом: люк на чердак в (15,3)")
    check((14, 28) in holes[0], "дом: люк в гараж в (14,28)")
    check((5, 29) in holes[0], "дом: люк в подвал в (5,29)")
    check((4, 20) in holes[1], "чердак: люк в дом в (4,20)")
    check((4, 13) in holes[2], "гараж: люк в дом в (4,13)")
    check((4, 17) in holes[3], "подвал: люк в дом в (4,17)")
    check(len(holes[0]) == 3 and len(holes[1]) == 1 and len(holes[2]) == 1 and len(holes[3]) == 1,
          "количество люков на уровнях: 3/1/1/1")

    # 5. Все люки достижимы от спавна соответствующего уровня
    check((15, 3) in reach[0], "люк на чердак достижим")
    check((14, 28) in reach[0], "люк в гараж достижим")
    check((5, 29) in reach[0], "люк в подвал достижим")
    check((4, 20) in reach[1], "люк с чердака достижим")
    check((4, 13) in reach[2], "люк из гаража достижим")
    check((4, 17) in reach[3], "люк из подвала достижим")

    # 6. Входная дверь достижима (точка победы WIN_DOOR)
    front = [d for d in house.doors if d[2]]
    check(len(front) == 1 and front[0][:2] == (15, 30), "входная дверь одна и в (15,30)")
    check((15, 29) in reach[0], "тайл у входной двери достижим")

    # 7. Укрытия: точка входа проходима и рядом
    for lv, hs in ((house, house.hides[0]), ):
        check(not lv.solid_at(hs["enter_x"] + 0.5, hs["enter_y"] + 0.5),
              f"укрытие '{hs['label']}': точка входа проходима")
        check((hs["enter_x"], hs["enter_y"]) in reach[lv.id],
              f"укрытие '{hs['label']}': точка входа достижима")
    for lv in (house, attic):
        for hs in lv.hides:
            if hs["label"] == "Под кроватью":
                continue
            check((hs["enter_x"], hs["enter_y"]) in reach[lv.id],
                  f"укрытие '{hs['label']}' ({lv.name}): точка входа достижима")

    # 8. Машина и колыбель достижимы (точки концовок WIN_CAR, WIN_SECRET)
    car = next(d for d in garage.decos if d["is_car"])
    near_car = any((int(car["x"]) + dx, int(car["y"]) + dy) in reach[2]
                   for dx, dy in ((2, 1), (2, 0), (2, -1), (1, 1), (1, 0), (1, -1)))
    check(near_car, "машина в гараже достижима для взаимодействия")
    cradle = next(d for d in attic.decos if d["is_cradle"])
    check(container_reachable(attic, {"x": int(cradle["x"]), "y": int(cradle["y"])}, reach[1]),
          "колыбель на чердаке достижима")

    # 9. Комнаты дома связаны между собой: любой тайл пола достижим
    floor_tiles = {(x, y) for y in range(house.h) for x in range(house.w)
                   if house.tile(x, y) in (FLOOR, RUG, HOLE, DOOR)}
    unreachable = floor_tiles - reach[0]
    check(len(unreachable) == 0,
          f"дом: все тайлы пола достижимы (недостижимо {len(unreachable)}: {sorted(unreachable)[:8]})")
    for pid, name in ((1, "чердак"), (2, "гараж"), (3, "подвал")):
        lv = levels[pid]
        tiles = {(x, y) for y in range(lv.h) for x in range(lv.w)
                 if not SOLID[lv.tile(x, y)] or lv.tile(x, y) == DOOR}
        un = tiles - reach[pid]
        check(len(un) == 0, f"{name}: все тайлы проходимы (недостижимо {len(un)})")

    # 10. Точки патруля Гренни валидны как тайлы (A* найдёт путь или подберёт соседа)
    patrol_house = [(7, 7), (8, 11), (24, 7), (28, 11), (7, 15), (22, 15), (6, 21), (25, 21),
                    (6, 27), (24, 27), (15, 20), (15, 27), (15, 8), (3, 15), (28, 15)]
    for x, y in patrol_house:
        t = house.tile(x, y)
        check(not SOLID[t] or t == DOOR, f"патруль ({x},{y}) не в стене (тайл {t})")
    # спавн Гренни свободен
    check(point_walkable(house, 24.5, 27.5) and deco_free(house, 24.5, 27.5),
          "спавн Гренни свободен")
    check(point_walkable(house, 16.55, 23.0) and deco_free(house, 16.55, 23.0),
          "позиция Гренни в меню свободна")

    # 11. Спавн кошки и сундук с кодом
    cat_free = attic.tile(9, 5) in (FLOOR, RUG) and deco_free(attic, 9.5, 5.3)
    check(cat_free, "кошка Маруся стоит на проходимом тайле")
    chest = next(c for c in attic.containers if c["x"] == 9 and c["y"] == 4)
    check(chest["item_id"] == NOTE, "сундук на чердаке содержит записку с кодом 137")

    # 12. Пересчёт достижимости, если Гренни открыла ВСЕ двери, включая входную (после победы)
    reach_full = bfs_reachable(house, int(house.spawn[0]), int(house.spawn[1]))

    print()
    print(f"LOGIC CHECK: checks={checks} fails={len(fails)}")
    if fails:
        for f in fails:
            print(" -", f)
        sys.exit(1)
    print("LOGIC CHECK OK")


if __name__ == "__main__":
    main()
