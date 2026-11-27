#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Статическая проверка логики фиксированного дома Granny 13 без запуска Godot.

Источник правды — const PLAN в scripts/house_plan.gd (вручную
спроектированная фиксированная планировка; её же читает рантайм и
tools/bake_house.gd). Формат блока — JSON между маркерами PLAN_PY.

Проверяются: проходимость всех этажей, связность люков, доступность
контейнеров/укрытий, размещение мебели, ФИКСИРОВАННОЕ размещение
предметов и капканов (никакой случайной раздачи), достижимость всего
для AI-поиска пути.
"""
import ast
import json
import os
import re
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN_GD = os.path.join(ROOT, "scripts", "house_plan.gd")


def load_plan():
    """Читает const PLAN (JSON) из house_plan.gd между маркерами PLAN_PY."""
    src = open(PLAN_GD, encoding="utf-8").read()
    a = src.index("# >>>PLAN_PY")
    b = src.index("# <<<PLAN_PY")
    block = src[a:b]
    block = block[block.index("{"):]
    # GDScript-литерал совпадает с JSON для этого подмножества (строки/числа/
    # true/false/списки/словари); проверяем строгим JSON-парсером.
    try:
        return json.loads(block)
    except json.JSONDecodeError:
        # запасной путь: python-литерал (true/false/null → True/False/None)
        txt = re.sub(r"\btrue\b", "True", block)
        txt = re.sub(r"\bfalse\b", "False", txt)
        txt = re.sub(r"\bnull\b", "None", txt)
        return ast.literal_eval(txt)


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

ITEM_IDS = {"KEY": KEY, "CROWBAR": CROWBAR, "NOTE": NOTE, "MILK": MILK,
            "BATTERY": BATTERY, "BANDAGE": BANDAGE, "BOTTLE": BOTTLE,
            "CROSSBOW": CROSSBOW, "DART": DART, "CAR_KEY": CAR_KEY,
            "CAR_BATTERY": CAR_BATTERY, "NOTE2": NOTE2, "PHOTO": PHOTO,
            "TEDDY": TEDDY}

# ровно один экземпляр в доме
UNIQUE_ITEMS = [KEY, CROWBAR, NOTE, BANDAGE, CROSSBOW, CAR_KEY, CAR_BATTERY,
                NOTE2, PHOTO, TEDDY]
# расходники: минимум один
CONSUMABLES = [MILK, BATTERY]


class Level:
    def __init__(self, d, plan):
        self.id = d["id"]
        self.name = d["name"]
        self.w = d["w"]
        self.h = d["h"]
        self.raw = d
        self.dec = d["decos"]
        self.doors = []
        self.containers = []
        self.hides = []
        legend = plan["legend"]
        floor_ids = plan["floor"]
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
                                   "bed": bool(dec["hide"].get("bed", 0))})
        self.spawn = d["spawn"]
        self.hatches = d["hatches"]
        self.rooms = d.get("room_rects", [])

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
    """Достижимые тайлы от (sx, sy); doors/FRONT считаются проходимыми."""
    blk = extra_block
    start = (sx, sy)
    if blk is not None:
        cand = []
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nx, ny = sx + dx, sy + dy
                if lv.ai_walkable(nx, ny, blk):
                    cand.append((nx, ny))
        if not cand:
            return []
        start = cand[0]
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in seen:
                continue
            if blk is not None:
                if not lv.ai_walkable(nx, ny, blk):
                    continue
            else:
                if not lv.walkable(nx, ny):
                    continue
            seen.add((nx, ny))
            q.append((nx, ny))
    return seen


def main():
    checks = 0
    fails = []

    def check(ok, what):
        nonlocal checks
        checks += 1
        if not ok:
            fails.append(what)
            print(f"  FAIL: {what}")

    plan = load_plan()
    levels = [Level(d, plan) for d in plan["levels"]]

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
    for d in plan["levels"]:
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

    def has_hatch(a, b):
        for d in plan["levels"]:
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
                check((n1 and n2) or (w1 and w2) or n1 or n2 or w1 or w2,
                      f"[{lv.name}] входная дверь ({d['x']},{d['y']}) соединяет помещения")
            else:
                check((n1 and n2) or (w1 and w2),
                      f"[{lv.name}] дверь ({d['x']},{d['y']}) соединяет помещения")

    # --- комнаты: имена уникальны, прямоугольники в границах и жилые ---
    for lv in levels:
        names = [r["name"] for r in lv.rooms]
        check(len(names) == len(set(names)), f"[{lv.name}] имена комнат уникальны")
        for r in lv.rooms:
            x0, y0, rw, rh = r["x"], r["y"], r["w"], r["h"]
            inside = 0 <= x0 and 0 <= y0 and x0 + rw <= lv.w and y0 + rh <= lv.h
            check(inside, f"[{lv.name}] комната '{r['name']}' в границах этажа")
            walk_cnt = sum(1 for y in range(y0, y0 + rh) for x in range(x0, x0 + rw)
                           if lv.walkable(x, y))
            check(walk_cnt >= 4, f"[{lv.name}] комната '{r['name']}' жилая ({walk_cnt} плит)")

    # --- контейнеры и укрытия доступны, без дубликатов на тайле ---
    for lv in levels:
        seen_tiles = set()
        for c in lv.containers:
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

    # --- ФИКСИРОВАННЫЕ предметы: каждый в своём контейнере плана ---
    # (порт HousePlan.reset_items: никакой случайной раздачи)
    for lv in levels:
        for c in lv.containers:
            c["item_id"] = NONE
    labels_index = {}
    for lv in levels:
        for c in lv.containers:
            labels_index.setdefault(c["label"], []).append((lv, c))
    items_total = 0
    for iname, target in plan["items"].items():
        iid = ITEM_IDS[iname]
        labels = target if isinstance(target, list) else [target]
        for label in labels:
            hits = labels_index.get(label, [])
            check(len(hits) == 1, f"метка '{label}' уникальна и существует ({len(hits)})")
            if len(hits) == 1:
                hits[0][1]["item_id"] = iid
                items_total += 1
    check(items_total == 18, f"в доме ровно 18 предметов ({items_total})")
    all_items = [c["item_id"] for lv in levels for c in lv.containers]
    for iid in UNIQUE_ITEMS:
        check(all_items.count(iid) == 1, f"предмет id={iid} встречается ровно 1 раз")
    for iid in CONSUMABLES:
        check(all_items.count(iid) >= 1, f"расходник id={iid} присутствует")
    check(all_items.count(DART) == 3, "3 стрелы для арбалета")
    check(all_items.count(BOTTLE) == 2, "2 бутылки для бросков")
    # каждый контейнер с предметом доступен игроку и AI
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
    # ключ/монтировка/записка — три замка собирутся
    check(all_items.count(KEY) == 1 and all_items.count(CROWBAR) == 1 and all_items.count(NOTE) == 1,
          "ключ/монтировка/записка присутствуют для трёх замков")

    # --- ФИКСИРОВАННЫЕ капканы: точки плана корректны ---
    spots = [tuple(s) for s in plan["trap_spots"]]
    check(len(spots) == len(set(spots)), "точки капканов не дублируются")
    check(len(spots) >= 7, "точек капканов хватает для КОШМАРА (7)")
    gs = plan["granny_start"]
    for s in spots:
        x, y = s
        lv = levels[0]
        check(lv.walkable(x, y) and not lv.tile(x, y) in (DOOR, FRONT),
              f"капкан ({x},{y}) на полу, не в двери ({lv.tile(x, y)})")
        check((x, y) in bfs(lv, *spawns[0]), f"капкан ({x},{y}) достижим от спавна")
        dsp = (abs(x - spawns[0][0]) + abs(y - spawns[0][1]))
        check(dsp > 4, f"капкан ({x},{y}) не у спавна игрока (manhattan {dsp})")
        dgr = abs(x - int(gs["x"] // 1)) + abs(y - int(gs["y"] // 1))
        check(dgr > 4, f"капкан ({x},{y}) не у старта Гренни (manhattan {dgr})")
    for a in range(len(spots)):
        for b in range(a + 1, len(spots)):
            d = abs(spots[a][0] - spots[b][0]) + abs(spots[a][1] - spots[b][1])
            check(d >= 2, f"капканы {spots[a]} и {spots[b]} не слипаются ({d})")

    # --- старт Гренни задан и корректен ---
    check(0 <= int(gs["lv"]) <= 3, "старт Гренни на существующем этаже")
    check(levels[int(gs["lv"])].walkable(int(gs["x"] // 1), int(gs["y"] // 1)),
          "старт Гренни проходим")

    # --- спавн игрока и бабушки не совпадают ---
    check(spawns[0] != (int(gs["x"] // 1), int(gs["y"] // 1)), "спавны игрока и Гренни различаются")

    print(f"LOGIC CHECK: checks={checks} fails={len(fails)}")
    if fails:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
