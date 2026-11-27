#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Схема фиксированной планировки дома: docs/screenshots/plan_level*.png.

Читает const PLAN из scripts/house_plan.gd (тот же блок, что logic_check)
и рисует вид сверху: стены, комнаты, двери, люки, мебель, предметы,
капканы, спавны. Запуск: python3 tools/draw_plan.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests"))
from logic_check import load_plan, Level, SOLID, FLOOR, RUG, HOLE, DOOR, FRONT  # noqa: E402

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("нужен Pillow: pip install --break-system-packages pillow")
    sys.exit(1)

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "docs", "screenshots")
S = 26  # пикселей на плитку

ITEM_TAGS = {"KEY": "К", "CROWBAR": "М", "NOTE": "З", "MILK": "мл", "BATTERY": "Б",
             "BANDAGE": "бн", "BOTTLE": "бт", "CROSSBOW": "А", "DART": "С",
             "CAR_KEY": "ТК", "CAR_BATTERY": "АК", "NOTE2": "З2", "PHOTO": "Ф",
             "TEDDY": "Т"}


def level_image(lv, plan):
    w, h = lv.w * S + 180, lv.h * S + 40
    img = Image.new("RGB", (w, h), (14, 14, 18))
    dr = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
        font_s = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
    except Exception:
        font = font_s = ImageFont.load_default()

    # полы и стены
    palette = {"wood": (58, 42, 30), "rug": (74, 34, 38), "hole": (10, 8, 10),
               "wall": (86, 82, 88), "special": (46, 60, 74)}
    for y in range(lv.h):
        for x in range(lv.w):
            t = lv.tile(x, y)
            px, py = x * S, y * S
            if t in (FLOOR, RUG):
                c = palette["rug"] if t == RUG else palette["wood"]
                dr.rectangle([px, py, px + S - 1, py + S - 1], fill=c)
                if t == RUG:
                    dr.rectangle([px + 3, py + 3, px + S - 4, py + S - 4], outline=(96, 44, 48))
            elif t == HOLE:
                dr.rectangle([px, py, px + S - 1, py + S - 1], fill=palette["hole"])
                dr.rectangle([px + 1, py + 1, px + S - 2, py + S - 2], outline=(70, 62, 40))
            elif t in (DOOR, FRONT):
                dr.rectangle([px, py, px + S - 1, py + S - 1], fill=palette["wood"])
                c = (212, 168, 64) if t == FRONT else (150, 104, 60)
                dr.rectangle([px + 2, py + 2, px + S - 3, py + S - 3], fill=c)
            elif SOLID[t]:
                # стены разных типов: окно — синеватое, остальное — серый кирпич
                c = (52, 74, 96) if t == 12 else palette["wall"]
                dr.rectangle([px, py, px + S - 1, py + S - 1], fill=c)
                dr.line([px, py + S - 1, px + S, py + S - 1], fill=(30, 30, 34))
                dr.line([px + S - 1, py, px + S - 1, py + S], fill=(30, 30, 34))

    # мебель (контур), укрытия (кружок), контейнеры
    for d in lv.dec:
        rx = d.get("rx") or 0.5
        ry = d.get("ry") or 0.5
        cx, cy = d["x"] * S, d["y"] * S
        if d.get("solid", True):
            dr.rectangle([cx - rx * S, cy - ry * S, cx + rx * S, cy + ry * S],
                         outline=(120, 120, 140), width=2)
        if "container" in d:
            dr.rectangle([cx - 3, cy - 3, cx + 3, cy + 3], fill=(120, 120, 140))
        if "hide" in d:
            dr.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], outline=(70, 130, 200), width=2)

    # люки
    for hh in lv.hatches:
        px, py = hh["x"] * S, hh["y"] * S
        dr.rectangle([px + 2, py + 2, px + S - 3, py + S - 3], outline=(64, 200, 210), width=3)
        dr.line([px + 6, py + S // 2, px + S - 6, py + S // 2], fill=(64, 200, 210), width=2)

    # предметы: буква в контейнере
    for iname, target in plan["items"].items():
        labels = target if isinstance(target, list) else [target]
        for label in labels:
            for d in lv.dec:
                if d.get("container") == label:
                    cx, cy = int(d["x"]) * S + S // 2, int(d["y"]) * S + S // 2
                    tag = ITEM_TAGS.get(iname, "?")
                    dr.rectangle([cx - 9, cy - 8, cx + 9, cy + 8], fill=(190, 150, 30))
                    dr.text((cx - 6, cy - 7), tag, fill=(20, 16, 8), font=font_s)

    # капканы (дом, уровень 0)
    if lv.id == 0:
        for s in plan["trap_spots"]:
            cx, cy = s[0] * S + S // 2, s[1] * S + S // 2
            dr.line([cx - 7, cy - 7, cx + 7, cy + 7], fill=(220, 60, 50), width=3)
            dr.line([cx - 7, cy + 7, cx + 7, cy - 7], fill=(220, 60, 50), width=3)

    # спавны
    sp = lv.spawn
    cx, cy = int(sp["x"]) * S + S // 2, int(sp["y"]) * S + S // 2
    dr.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(60, 200, 90))
    dr.text((cx - 6, cy - 8), "И", fill=(0, 0, 0), font=font_s)
    if lv.id == 0:
        gs = plan["granny_start"]
        cx, cy = int(gs["x"]) * S + S // 2, int(gs["y"]) * S + S // 2
        dr.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(200, 60, 160))
        dr.text((cx - 6, cy - 8), "Б", fill=(0, 0, 0), font=font_s)

    # имена комнат
    for r in lv.rooms:
        cx, cy = (r["x"] + r["w"] / 2.0) * S, (r["y"] + r["h"] / 2.0) * S
        dr.text((cx - len(r["name"]) * 3.4, cy), r["name"], fill=(235, 225, 205), font=font)

    # легенда
    lx = lv.w * S + 12
    legend = [
        ("стена/окно", (86, 82, 88)), ("дверь", (150, 104, 60)), ("входная", (212, 168, 64)),
        ("люк/лестница", (64, 200, 210)), ("предмет", (190, 150, 30)), ("капкан", (220, 60, 50)),
        ("спавн игрока", (60, 200, 90)), ("старт Гренни", (200, 60, 160)),
    ]
    dr.text((lx, 16), lv.name, fill=(240, 230, 210), font=font)
    yy = 44
    for name, c in legend:
        dr.rectangle([lx, yy, lx + 14, yy + 10], fill=c)
        dr.text((lx + 20, yy - 1), name, fill=(200, 200, 200), font=font_s)
        yy += 20
    return img


def main():
    plan = load_plan()
    os.makedirs(OUT, exist_ok=True)
    imgs = [level_image(Level(d, plan), plan) for d in plan["levels"]]
    for i, im in enumerate(imgs):
        p = os.path.join(OUT, "plan_level%d.png" % i)
        im.save(p)
        print("saved", p, im.size)
    # сводный лист 2x2
    pad = 24
    cw = max(im.width for im in imgs)
    ch = max(im.height for im in imgs)
    sheet = Image.new("RGB", (cw * 2 + pad * 3, ch * 2 + pad * 3), (8, 8, 10))
    pos = [(pad, pad), (cw + pad * 2, pad), (pad, ch + pad * 2), (cw + pad * 2, ch + pad * 2)]
    for im, p in zip(imgs, pos):
        sheet.paste(im, p)
    out = os.path.join(OUT, "plan_overview.png")
    sheet.save(out)
    print("saved", out, sheet.size)


if __name__ == "__main__":
    main()
