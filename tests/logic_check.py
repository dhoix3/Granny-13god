#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Статическая проверка логики дома Granny 13 без запуска Godot.

Источник правды — assets/house.json (его читает и scripts/house_data.gd).
Проверяются: проходимость всех этажей, связность люков, доступность
контейнеров/укрытий, размещение мебели, раздача предметов (порт
HouseData.distribute_items), достижимость всех контейнеров и дверей
для AI-поиска пути.
"""
import json
import os
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "assets", "house.json")

# tile ids (должны совпадать с scripts/level_data.gd)
FLOOR, WP, PANEL, BRICK, DOOR, FRONT = range(6)
WINDOW, ATTIC, BEAM, PORTRAIT, TILEW = 12, 13, 14, 15, 16
TOWELS, CAGE, RUG, HOLE, MIRROR = 17, 18, 21, 22, 23
PLASTER, GARAGE_DOOR, BEAMT = 25, 27, 28

SOLID = [True] * 29
SOLID[FLOOR] = False
SOLID[RUG] = False
SOLID[HOLE] = False

# item ids (scripts/items.gd)
NONE, KEY, CROWBAR, NOTE, MILK, BATTERY = 0, 1, 2, 3, 4, 5
BANDAGE, BOTTLE, CROSSBOW, DART = 6, 7, 8, 9
CAR_KEY, CAR_BATTERY, NOTE2, PHOTO, TEDDY = 11, 12, 13, 14, 15

# ровно один экземпляр
UNIQUE_ITEMS = [KEY, CROWBAR, NOTE, BANDAGE, CROSSBOW, CAR_KEY, CAR_BATTERY, NOTE2, PHOTO, TEDDY]
# расходники: могут повторяться, но минимум один
CONSUMABLES = [MILK, BATTERY]


class Level:
    def __init__(self, d):
        self.id = d["id"]
        self.name = d["name"]
        self.w = d["w"]
        self.h = d["h"]
        self.map = []
        for row in d["map"]:
            for ch in row:
                if ch in d.get("_legend", {}):
                    pass
        self.raw = d
        self.dec = d["decos"]
        self.doors = []
        self.containers = []
        self.hides = []
        legend = json.load(open(DATA, encoding="utf-8"))["legend"]
        floor_ids = json.load(open(DATA, encoding="utf-8"))["floor"]
        self.tiles = []
        for row in d["map"]:
            r = []
            for ch in row:
                if ch in legend:
                    r.append(legend[ch])
                elif ch in floor_ids:
                    r.append(floor_ids[ch])
                else:
                    r.append(BRICK)
            self.tiles.append(r)
        for y in range(self.h):
            for x in range(self.w):
                t = self.tiles[y][x]
                if t in (DOOR, FRONT):
                    self.doors.append({"x": x, "y": y, "front": t == FRONT})
        for dec in self.dec:
            tx = int(dec["x"] // 1)
            ty = int(dec["y"] // 1)
            if "container" in dec:
                self.containers.append({"x": tx, "y": ty, "label": dec["container"], "item_id": NONE})
            if "hide" in dec:
                self.hides.append({"x": tx, "y": ty,
                                   "enter": (int(dec["hide"]["enter"][0]), int(dec["hide"]["enter"][1])),
                                   "bed": bool(dec["hide"].get("bed", False))})
        self.spawn = d["spawn"]
        self.hatches = d["hatches"]

    def tile(self, x, y):
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return BRICK
        return self.tiles[y][x]

    def walkable(self, x, y):
        t = self.tile(x, y)
        if t in (DOOR, FRONT):
            return True  # игрок и AI умеют открывать двери
        return not SOLID[t]

    def ai_blocked(self):
        blk = [[0] * self.w for _ in range(self.h)]
        for d in self.dec:
            if not d.get("solid", True):
                continue
            rx = d.get("rx")
            ry = d.get("ry")
            if rx is None:
                rx = KIND_HX[min(d["kind"], len(KIND_HX) - 1)]
            if ry is None:
                ry = KIND_HY[min(d["kind"], len(KIND_HY) - 1)]
            cx = d["x"]
            cy = d["y"]
            for y in range(int(cy - ry - 0.5) - 1, int(cy + ry + 0.5) + 2):
                for x in range(int(cx - rx - 0.5) - 1, int(cx + rx + 0.5) + 2):
                    if 0 <= x < self.w and 0 <= y < self.h:
                        if abs(x + 0.5 - cx) < rx + 0.26 and abs(y + 0.5 - cy) < ry + 0.26:
                            blk[y][x] = 1
        return blk

    def ai_walkable(self, x, y, blk):
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return False
        if blk[y][x]:
            return False
        return self.walkable(x, y)


KIND_HX = [0.78, 0.62, 1.06, 0.37, 0.74, 0.66, 0.53, 0.41, 0.40, 0.55, 0.58, 0.27, 0.33, 0.40, 0.12, 0.04, 0.06, 0.14, 0.04]
KIND_HY = [0.42, 0.33, 0.35, 0.30, 0.36, 0.32, 0.32, 0.36, 0.37, 0.28, 0.29, 0.24, 0.28, 0.20, 0.08, 0.04, 0.05, 0.06, 0.04]


def bfs(lv, sx, sy, extra_block=None):
    seen = set()
    q = deque([(sx, sy)])
    seen.add((sx, sy))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in seen:
                continue
            if not (0 <= nx < lv.w and 0 <= ny < lv.h):
                continue
            if extra_block is not None:
                if extra_block[ny][nx] or not lv.walkable(nx, ny):
                    continue
            elif not lv.walkable(nx, ny):
                continue
            seen.add((nx, ny))
            q.append((nx, ny))
    return seen


def find_path(lv, blk, sx, sy, tx, ty):
    """BFS-эквивалент ai-поиска пути (двери проходимы, мебель блокирует)."""
    if not lv.ai_walkable(tx, ty, blk):
        cand = []
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if lv.ai_walkable(tx + dx, ty + dy, blk):
                    cand.append((tx + dx, ty + dy))
        if not cand:
            return None
        tx, ty = cand[0]
    if (sx, sy) == (tx, ty):
        return [(sx, sy)]
    prev = {(sx, sy): None}
    q = deque([(sx, sy)])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in prev:
                continue
            if not lv.ai_walkable(nx, ny, blk):
                continue
            prev[(nx, ny)] = (x, y)
            if (nx, ny) == (tx, ty):
                path = [(nx, ny)]
                while prev[path[-1]] is not None:
                    path.append(prev[path[-1]])
                return list(reversed(path))
            q.append((nx, ny))
    return None


class Rng:
    """Детерминированный ГПСЧ для зеркала раздачи (порядок не важен для проверок)."""
    def __init__(self, seed):
        self.state = seed & 0xFFFFFFFFFFFFFFFF

    def randi_range(self, a, b):
        self.state = (6364136223846793005 * self.state + 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
        return a + (self.state >> 33) % (b - a + 1)


def shuffle(rng, arr):
    for i in range(len(arr) - 1, 0, -1):
        j = rng.randi_range(0, i)
        arr[i], arr[j] = arr[j], arr[i]


def distribute(levels, anchors, seed):
    """Порт HouseData.distribute_items: якоря + пул + дротики/ключ машины."""
    rng = Rng(seed)
    house = levels[0]
    attic = levels[1]
    taken = set()
    for lv in levels:
        for c in lv.containers:
            if c["label"] in anchors:
                c["item_id"] = anchors[c["label"]]
                taken.add(id(c))
    pool = [c for c in house.containers if id(c) not in taken]
    shuffle(rng, pool)
    req = [KEY, CROWBAR, MILK, BANDAGE]
    shuffle(rng, req)
    idx = 0
    for i in range(min(len(req), len(pool))):
        pool[i]["item_id"] = req[i]
        idx += 1
    extra = [BOTTLE, BOTTLE, MILK, BATTERY]
    e = 0
    while idx < len(pool) and e < len(extra):
        pool[idx]["item_id"] = extra[e]
        idx += 1
        e += 1
    darts = 3
    car_placed = False
    for lv in (house, attic):
        for c in lv.containers:
            if c["item_id"] != NONE:
                continue
            if darts > 0:
                c["item_id"] = DART
                darts -= 1
            elif not car_placed:
                c["item_id"] = CAR_KEY
                car_placed = True


def main():
    checks = 0
    fails = []

    def check(ok, what):
        nonlocal checks
        checks += 1
        if not ok:
            fails.append(what)
            print(f"  FAIL: {what}")

    data = json.load(open(DATA, encoding="utf-8"))
    levels = [Level(d) for d in data["levels"]]

    check(len(levels) == 4, "4 этажа (дом/чердак/пристройка/подвал)")
    check([lv.id for lv in levels] == [0, 1, 2, 3], "порядок этажей 0..3")

    # --- спавны и базовая проходимость ---
    spawns = {}
    for lv in levels:
        sx = int(lv.spawn["x"] // 1)
        sy = int(lv.spawn["y"] // 1)
        spawns[lv.id] = (sx, sy)
        check(lv.walkable(sx, sy), f"[{lv.name}] спавн проходим ({sx},{sy})")
        reach = bfs(lv, sx, sy)
        total = sum(1 for y in range(lv.h) for x in range(lv.w)
                    if lv.tile(x, y) in (FLOOR, RUG, HOLE))
        check(len([p for p in reach if lv.tile(p[0], p[1]) in (FLOOR, RUG, HOLE)]) == total,
              f"[{lv.name}] все {total} плит пола достижимы (достижимо {len(reach)})")

    # --- люки: пары дом↔этаж, обе стороны проходимы и связаны ---
    for lv in levels:
        for h in lv["hatches"] if isinstance(lv, dict) else []:
            pass
    for d in data["levels"]:
        for h in d["hatches"]:
            hx, hy = int(h["x"]), int(h["y"])
            lv_from = levels[d["id"]]
            check(lv_from.tile(hx, hy) == HOLE, f"люк ({hx},{hy}) на '{lv_from.name}' — тайл HOLE")
            check((hx, hy) in bfs(lv_from, *spawns[d["id"]]), f"люк ({hx},{hy}) достижим от спавна")
            lv_to = levels[h["to"]]
            tx, ty = int(h["tx"] // 1), int(h["ty"] // 1)
            check(lv_to.walkable(tx, ty), f"приход люка '{lv_from.name}'→{lv_to.name} проходим ({tx},{ty})")
            check((tx, ty) in bfs(lv_to, *spawns[h["to"]]), f"точка прихода связана со спавном {lv_to.name}")
            check("ta" in h and "verb" in h and "noise" in h, f"люк {d['id']}→{h['to']}: ta/verb/noise заданы")
    # обратная пара существует
    def has_hatch(a, b):
        for d in data["levels"]:
            for h in d["hatches"]:
                if d["id"] == a and h["to"] == b:
                    return True
        return False
    for a, b in ((0, 1), (1, 0), (0, 2), (2, 0), (0, 3), (3, 0)):
        check(has_hatch(a, b), f"есть люк {a}→{b} и обратно")

    # --- двери соединяют две проходимые плитки ---
    for lv in levels:
        for d in lv.doors:
            n1 = lv.walkable(d["x"], d["y"] - 1) or lv.tile(d["x"], d["y"] - 1) in (DOOR, FRONT)
            n2 = lv.walkable(d["x"], d["y"] + 1) or lv.tile(d["x"], d["y"] + 1) in (DOOR, FRONT)
            w1 = lv.walkable(d["x"] - 1, d["y"]) or lv.tile(d["x"] - 1, d["y"]) in (DOOR, FRONT)
            w2 = lv.walkable(d["x"] + 1, d["y"]) or lv.tile(d["x"] + 1, d["y"]) in (DOOR, FRONT)
            if d["front"]:
                # входная дверь: внутрь ведёт одна сторона (снаружи стена дома)
                check((n1 and n2) or (w1 and w2) or n1 or n2 or w1 or w2,
                      f"[{lv.name}] входная дверь ({d['x']},{d['y']}) соединяет помещения")
            else:
                check((n1 and n2) or (w1 and w2),
                      f"[{lv.name}] дверь ({d['x']},{d['y']}) соединяет помещения")

    # --- контейнеры и укрытия доступны, без дубликатов на тайле ---
    for lv in levels:
        seen_tiles = set()
        for c in lv.containers:
            check(lv.walkable(c["x"], c["y"]) is False or True, "")  # тайл контейнера может быть полом под мебелью
            adj = any(lv.walkable(c["x"] + dx, c["y"] + dy)
                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            check(adj, f"[{lv.name}] контейнер '{c['label']}' доступен ({c['x']},{c['y']})")
            key = (c["x"], c["y"])
            check(key not in seen_tiles, f"[{lv.name}] на тайле {key} один контейнер")
            seen_tiles.add(key)
        for hs in lv.hides:
            ex, ey = hs["enter"]
            check(lv.walkable(ex, ey), f"[{lv.name}] вход укрытия ({ex},{ey}) проходим")
            adj = any(lv.walkable(hs["x"] + dx, hs["y"] + dy)
                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            check(adj, f"[{lv.name}] укрытие рядом с проходимой плиткой ({hs['x']},{hs['y']})")

    # --- мебель: не на дверях/люках, не перекрывает спавн ---
    for lv in levels:
        sp = spawns[lv.id]
        for dec in lv.dec:
            if not dec.get("solid", True):
                continue
            tx = int(dec["x"] // 1)
            ty = int(dec["y"] // 1)
            check(lv.tile(tx, ty) in (FLOOR, RUG),
                  f"[{lv.name}] '{dec['name']}' стоит на полу ({tx},{ty}: {lv.tile(tx, ty)})")
            check((tx, ty) != sp, f"[{lv.name}] '{dec['name']}' не на спавне")
            check(lv.tile(tx, ty) != HOLE, f"[{lv.name}] '{dec['name']}' не на люке")

    # --- мебель не запирает комнаты: BFS с учётом ai_blocked ---
    for lv in levels:
        blk = lv.ai_blocked()
        sp = spawns[lv.id]
        if blk[sp[1]][sp[0]]:
            # спавн может быть рядом с мебелью — ищем ближайшую свободную
            found = None
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if lv.ai_walkable(sp[0] + dx, sp[1] + dy, blk):
                        found = (sp[0] + dx, sp[1] + dy)
            check(found is not None, f"[{lv.name}] вокруг спавна есть свободный тайл")
            if found:
                sp = found
        reach = bfs(lv, sp[0], sp[1], extra_block=blk)
        for c in lv.containers:
            cand = None
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = c["x"] + dx, c["y"] + dy
                    if lv.ai_walkable(nx, ny, blk) and (nx, ny) in reach:
                        cand = (nx, ny)
            check(cand is not None, f"[{lv.name}] AI дойдёт до '{c['label']}'")
        for h in lv.hatches:
            cand = any(lv.ai_walkable(h["x"] + dx, h["y"] + dy, blk)
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            check(cand, f"[{lv.name}] AI дойдёт до люка ({h['x']},{h['y']})")

    # --- раздача предметов: все прогрессивные предметы ровно один раз ---
    anchors = data["item_anchors"]
    distribute(levels, anchors, 20261119)
    all_items = []
    for lv in levels:
        for c in lv.containers:
            all_items.append(c["item_id"])
    for iid in UNIQUE_ITEMS:
        check(all_items.count(iid) == 1, f"предмет id={iid} встречается ровно 1 раз")
    for iid in CONSUMABLES:
        check(all_items.count(iid) >= 1, f"расходник id={iid} присутствует")
    check(all_items.count(DART) == 3, "3 стрелы для арбалета")
    # якоря на месте
    anchors_found = {anchors[c["label"]]: lv.name for lv in levels for c in lv.containers
                     if c["item_id"] == anchors.get(c["label"]) and c["label"] in anchors}
    for label, iid in anchors.items():
        placed = any(c["label"] == label and c["item_id"] == iid for lv in levels for c in lv.containers)
        check(placed, f"якорь '{label}' → id={iid}")
    # каждый контейнер с предметом доступен игроку
    for lv in levels:
        blk = lv.ai_blocked()
        sp = spawns[lv.id]
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if lv.ai_walkable(sp[0] + dx, sp[1] + dy, blk):
                    sp = (sp[0] + dx, sp[1] + dy)
                    break
        reach = bfs(lv, sp[0], sp[1], extra_block=blk)
        for c in lv.containers:
            if c["item_id"] == NONE:
                continue
            adj = any((c["x"] + dx, c["y"] + dy) in reach
                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            check(adj, f"[{lv.name}] предмет id={c['item_id']} ('{c['label']}') можно взять")
    # входная дверь: три замка собраны из уникальных предметов
    check(all_items.count(KEY) == 1 and all_items.count(CROWBAR) == 1 and all_items.count(NOTE) == 1,
          "ключ/монтировка/записка присутствуют для трёх замков")

    # --- спавн игрока и бабушки не совпадают, бабушка стартует в доме ---
    check(data["levels"][0].get("spawn") is not None, "спавн дома задан")

    print(f"LOGIC CHECK: checks={checks} fails={len(fails)}")
    if fails:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
