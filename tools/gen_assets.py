#!/usr/bin/env python3
"""Генератор ассетов Granny 13: текстуры (albedo+normal), звук (WAV 32 кГц), шрифты.

Всё детерминировано (фиксированные seed'ы). Результат: assets/tex/, assets/snd/,
assets/fonts/. Скрипт коммитится в репозиторий — ресурсы воспроизводимы.
Запуск: python3 tools/gen_assets.py
"""
import math
import os
import struct
import wave
import zlib

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "tex")
SND = os.path.join(ROOT, "assets", "snd")
FNT = os.path.join(ROOT, "assets", "fonts")
os.makedirs(TEX, exist_ok=True)
os.makedirs(SND, exist_ok=True)
os.makedirs(FNT, exist_ok=True)

S = 256  # размер поверхностных текстур


# ------------------------------------------------------------------ noise
def vnoise(size: int, freq: int, seed: int) -> np.ndarray:
    """Периодический value noise 0..1 (частота делит size — шов исключён)."""
    rng = np.random.default_rng(seed)
    g = rng.random((freq, freq)).astype(np.float32)
    step = size / freq
    xs = (np.arange(size) / step)
    i0 = np.floor(xs).astype(int) % freq
    i1 = (i0 + 1) % freq
    fx = xs - np.floor(xs)
    sx = fx * fx * (3 - 2 * fx)
    rows = []
    for y in range(size):
        ys = y / step
        j0 = int(ys) % freq
        j1 = (j0 + 1) % freq
        fy = ys - math.floor(ys)
        sy = fy * fy * (3 - 2 * fy)
        a = g[j0, i0] * (1 - sx) + g[j0, i1] * sx
        b = g[j1, i0] * (1 - sx) + g[j1, i1] * sx
        rows.append(a * (1 - sy) + b * sy)
    return np.array(rows, dtype=np.float32)


def fbm(size: int, seed: int, base: int = 8, octaves: int = 4, gain: float = 0.5) -> np.ndarray:
    out = np.zeros((size, size), np.float32)
    amp, tot, f = 1.0, 0.0, base
    for o in range(octaves):
        out += amp * vnoise(size, f, seed + o * 977)
        tot += amp
        amp *= gain
        f *= 2
    return out / tot


def normal_from_height(h: np.ndarray, strength: float = 2.0) -> np.ndarray:
    """RGB-нормаль из height-поля (seamless: sobel с заворотом)."""
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1))
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0))
    n = np.dstack([-gx * strength * S, -gy * strength * S, np.ones_like(h)])
    ln = np.sqrt((n * n).sum(-1, keepdims=True))
    n = n / ln
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name: str, rgb: np.ndarray, normal: np.ndarray | None = None) -> None:
    Image.fromarray(rgb.astype(np.uint8), "RGB").save(os.path.join(TEX, name + ".png"))
    if normal is not None:
        Image.fromarray(normal, "RGB").save(os.path.join(TEX, name + "_n.png"))


def to_rgb(* chans) -> np.ndarray:
    return np.dstack([np.clip(c, 0, 1) * 255 for c in chans]).astype(np.uint8)


def grain(seed: int, amp: float = 0.02) -> np.ndarray:
    rng = np.random.default_rng(seed)
    g = rng.standard_normal((S, S)).astype(np.float32)
    g = 0.6 * g + 0.4 * np.roll(g, 1, 0)  # чуть мягче
    return g * amp


# ------------------------------------------------------------------ текстуры
def gen_textures() -> None:
    # --- дощатый пол (wood_floor) ---
    rng = np.random.default_rng(101)
    y = np.arange(S)[:, None].astype(np.float32)
    x = np.arange(S)[None, :].astype(np.float32)
    rows = 8
    rh = S // rows
    plank = (y // rh).astype(int) % rows
    tone = np.array([0.0, 0.10, -0.07, 0.05, -0.04, 0.12, 0.02, -0.09], np.float32)[plank]
    grain_w = fbm(S, 105, 4, 4) * 0.10 + vnoise(S, 64, 106) * 0.05
    stretch = (x * 0.0 + grain_w)  # зерно вдоль досок: тянем по x
    grain_w = (fbm(S, 107, 8, 4, 0.55) * 0.08)
    gmap = np.zeros((S, S), np.float32)
    for r in range(rows):
        gmap[r * rh:(r + 1) * rh] = grain_w[r * rh:(r + 1) * rh] * (1.0 + 0.5 * ((r * 7) % 3) / 2)
    base = 0.30 + tone + gmap
    ly = y % rh
    joint = ((x + plank * (S // rows)) % 64)
    seam = (ly < 1.5) | (ly > rh - 1.5) | (joint < 1.5)
    knots = (fbm(S, 109, 4, 2) > 0.78)
    r = base * np.where(seam, 0.55, 1.0) * np.where(knots, 0.8, 1.0)
    n = grain(111, 0.012)
    gcol = to_rgb(r + n, r * 0.62 + n * 0.8, r * 0.40 + n * 0.5)
    h = np.where(seam, 0.35, 0.8) + gmap * 0.5 + n * 2
    save("wood_floor", gcol, normal_from_height(h.astype(np.float32), 2.6))

    # --- тёмное дерево (wood_dark) — мебель/балки ---
    wd = 0.19 + fbm(S, 120, 8, 4) * 0.06 + grain(121, 0.012)
    wdl = (y % 32 < 1.5)
    wd = wd * np.where(wdl, 0.82, 1.0)
    save("wood_dark", to_rgb(wd, wd * 0.60, wd * 0.38))

    # --- светлое дерево ---
    wl = 0.50 + fbm(S, 130, 8, 4) * 0.10 + grain(131, 0.014)
    save("wood_light", to_rgb(wl, wl * 0.66, wl * 0.36))

    # --- стеновые панели (panel) — тёмное дерево с пазами ---
    px_ = x % 32
    pan = 0.20 + fbm(S, 140, 8, 4) * 0.05 + grain(141, 0.010)
    groove = px_ < 2.0
    bevel = (px_ >= 14) & (px_ <= 17)
    pan = pan * np.where(groove, 0.60, 1.0) * np.where(bevel, 0.85, 1.0)
    hp = np.where(groove, 0.2, np.where(bevel, 0.9, 0.7)).astype(np.float32)
    save("panel", to_rgb(pan, pan * 0.62, pan * 0.40), normal_from_height(hp, 2.2))

    # --- штукатурка (plaster) с пятнами и трещинами ---
    st = fbm(S, 150, 4, 4)
    pl = 0.30 + (st - 0.5) * 0.10 + grain(151, 0.03)
    crack = (fbm(S, 152, 8, 5) > 0.74) & (np.roll(fbm(S, 152, 8, 5), 2, 0) <= 0.74)
    pl = pl * np.where(crack, 0.72, 1.0)
    stains = fbm(S, 153, 4, 3) > 0.66
    pl = pl * np.where(stains, 0.90, 1.0)
    save("plaster", to_rgb(pl, pl * 0.94, pl * 0.82), normal_from_height((st * 0.4 + 0.4).astype(np.float32), 1.2))

    # --- кирпич ---
    row = (y // 21).astype(int)
    off = (row % 2) * 16
    bx = (x + off) % 32
    by = y % 21
    brk = 0.30 + (vnoise(S, 16, 160) * 0.5 + vnoise(S, 32, 161) * 0.5 - 0.5) * 0.12 + grain(162, 0.018)
    mortar = (by < 2) | (bx < 2)
    brkc = np.where(mortar[..., None] if mortar.ndim < 2 else mortar, 0.0, 0.0)
    brk = np.where(mortar, 0.19, brk)
    hb = np.where(mortar, 0.25, 0.85).astype(np.float32) + grain(163, 0.5)
    save("brick", to_rgb(brk, brk * 0.88, brk * 0.80), normal_from_height(hb, 2.4))

    # --- кафель (tile) ---
    tx = x % 32
    ty = y % 32
    ck = (((x // 32) + (y // 32)) % 2).astype(np.float32)
    tl = 0.42 + ck * 0.06 + vnoise(S, 16, 170)[None if False else slice(None)] * 0.03
    tl = 0.42 + ck * 0.06 + fbm(S, 171, 8, 3) * 0.05
    mortar = (tx < 1.6) | (ty < 1.6)
    tl = np.where(mortar, 0.22, tl)
    ht = np.where(mortar, 0.3, 0.9).astype(np.float32)
    save("tile", to_rgb(tl, tl * 1.04, tl * 0.94), normal_from_height(ht, 1.8))

    # --- чердак (attic) — старые доски ---
    at = 0.22 + fbm(S, 180, 8, 4) * 0.07 + grain(181, 0.014)
    gap = (y % 24 < 1.6)
    at = at * np.where(gap, 0.62, 1.0)
    dust = fbm(S, 182, 4, 3) > 0.68
    at = np.where(dust, at * 1.06, at)
    save("attic", to_rgb(at, at * 0.62, at * 0.40))

    # --- бетон ---
    co = 0.27 + fbm(S, 190, 8, 4) * 0.09 + grain(191, 0.028)
    stains = fbm(S, 192, 4, 3) > 0.70
    co = np.where(stains, co * 0.88, co)
    pits = vnoise(S, 64, 193) > 0.86
    co = np.where(pits, co * 0.75, co)
    save("concrete", to_rgb(co, co * 0.99, co * 0.95), normal_from_height((fbm(S, 193, 16, 3) * 0.5 + 0.3).astype(np.float32), 1.6))

    # --- ковёр (rug) — клетка с каймой (используется 0..1 на тайл) ---
    border = (x < 20) | (x > S - 21) | (y < 20) | (y > S - 21)
    cell = (((x // 24) + (y // 24)) % 2).astype(np.float32)
    ru = np.where(border, 0.30, 0.36 + cell * 0.05)
    weave = ((x + y) % 4 < 2).astype(np.float32) * 0.028 - 0.014
    ru = ru + weave + grain(200, 0.012)
    gold = border & (((x + y) % 20) < 2)
    rr = np.where(gold, 0.55, ru)
    save("rug", to_rgb(rr, rr * 0.45, rr * 0.40))

    # --- дверь (door) — 0..1 на грань ---
    dn = np.full((S, S), 0.30, np.float32) + fbm(S, 210, 8, 4) * 0.05 + grain(211, 0.010)
    for (px0, py0, pw, ph) in [(36, 22, 184, 90), (36, 132, 184, 92)]:
        inside = (x >= px0) & (x < px0 + pw) & (y >= py0) & (y < py0 + ph)
        edge = ((x == px0) | (x == px0 + pw - 1) | (y == py0) | (y == py0 + ph - 1))
        dn = np.where(inside & ~edge, dn * 0.86, dn)
        dn = np.where(edge, dn * 0.60, dn)
    hd = np.full((S, S), 0.7, np.float32)
    for (px0, py0, pw, ph) in [(36, 22, 184, 90), (36, 132, 184, 92)]:
        inside = (x >= px0) & (x < px0 + pw) & (y >= py0) & (y < py0 + ph)
        edge = ((x == px0) | (x == px0 + pw - 1) | (y == py0) | (y == py0 + ph - 1))
        hd = np.where(inside & ~edge, 0.55, hd)
        hd = np.where(edge, 0.25, hd)
    save("door", to_rgb(dn, dn * 0.62, dn * 0.40), normal_from_height(hd, 2.0))

    # --- металл (metal) ---
    mt = 0.38 + vnoise(S, 32, 220)[::1] * 0.03
    mt = 0.38 + fbm(S, 221, 16, 3) * 0.06
    scratch = (fbm(S, 222, 8, 4) > 0.80)
    mt = np.where(scratch, mt * 1.18, mt)
    save("metal", to_rgb(mt, mt * 1.01, mt * 1.06), normal_from_height((fbm(S, 223, 16, 3) * 0.6 + 0.3).astype(np.float32), 1.4))

    # --- ткани ---
    for nm, col, seed in [("fabric_red", (0.30, 0.06, 0.055), 230), ("fabric_green", (0.11, 0.20, 0.13), 231), ("fabric_blue", (0.11, 0.13, 0.23), 232)]:
        wv = (((np.arange(S)[None, :] + np.arange(S)[:, None]) % 4) < 2).astype(np.float32)
        f = col[0] + wv * 0.028 - 0.014 + grain(seed, 0.010)
        fg = col[1] + wv * 0.020 - 0.010 + grain(seed + 1, 0.008)
        fb_ = col[2] + wv * 0.020 - 0.010 + grain(seed + 2, 0.008)
        save(nm, to_rgb(f, fg, fb_))

    # --- окно (window) — ночь, луна, рама (0..1 на грань) ---
    ny = y / S
    sky = 0.020 + ny * 0.035
    stars = (vnoise(S, 64, 240) > 0.965)
    sky = np.where(stars, 0.75, sky)
    moon = ((x - 190) ** 2 + (y - 74) ** 2) < 26 ** 2
    glow = ((x - 190) ** 2 + (y - 74) ** 2) < 52 ** 2
    sky = np.where(glow & ~moon, sky * 1.9, sky)
    sky = np.where(moon, 0.86, sky)
    frame = (x < 9) | (x > S - 10) | (y < 9) | (y > S - 10) | (np.abs(x - 128) < 5) | (np.abs(y - 128) < 5)
    sky = np.where(frame, 0.14, sky)
    fr_r = np.where(frame, 0.14 * 0.75, sky)
    save("window", to_rgb(fr_r * 0.92, np.where(frame, 0.14 * 0.60, sky * 0.98), np.where(frame, 0.14 * 0.45, np.clip(sky * 1.35, 0, 1))))

    # --- решётка (cage) ---
    cg = np.full((S, S), 0.03, np.float32)
    bars = (x % 16 < 4) | (y % 48 < 4)
    cg = np.where(bars, 0.20, cg) + grain(250, 0.008)
    save("cage", to_rgb(cg, cg * 0.95, cg * 0.85))

    # --- ворота гаража (garage) — гофрированные секции ---
    ga = 0.24 + vnoise(S, 16, 260) * 0.02 + grain(261, 0.010)
    rib = (y % 24 <= 2)
    vert = (x % 64 <= 1)
    ga = np.where(rib, 0.13, ga) * np.where(vert, 0.82, 1.0)
    hg = np.where(rib, 0.3, 0.75).astype(np.float32)
    save("garage", to_rgb(ga, ga * 1.02, ga * 1.06), normal_from_height(hg, 2.2))

    # --- полотенце ---
    twv = 0.45 + fbm(S, 270, 16, 2) * 0.05
    stripes = (x % 32 < 4) | (y % 32 < 4)
    spot = (x > 80) & (x < 180) & (y > 60)
    twv = np.where(stripes, 0.27, twv)
    twv = np.where(spot, 0.42, twv)
    save("towel", to_rgb(twv, twv * 1.02, twv * 0.94))

    # --- обои: улучшаем исходный asset (шов + грязь), 256×256 ---
    src = Image.open(os.path.join(ROOT, "assets", "wallpaper.png")).convert("RGB")
    w0, h0 = src.size
    arr = np.asarray(src, np.float32) / 255.0
    # поиск шва по минимуму яркости колонки/строки (как в materials.gd)
    lum = arr.mean(-1)
    sx = int(lum.sum(0).argmin())
    sy = int(lum.sum(1).argmin())
    arr = np.roll(np.roll(arr, -sx, 1), -sy, 0)
    # зеркальная укладка 2x2 для непрерывности, затем даунскейл до S
    m = np.concatenate([np.concatenate([arr, arr[::-1]], 0), np.concatenate([arr[:, ::-1], arr[::-1, ::-1]], 0)], 1)
    img = Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8)).resize((S, S), Image.LANCZOS)
    a2 = np.asarray(img, np.float32) / 255.0
    grime = fbm(S, 280, 4, 4)
    a2 = a2 * (0.82 + 0.18 * grime)[..., None]
    a2 += grain(281, 0.012)[..., None]
    save("wallpaper", np.clip(a2, 0, 1) * 255)

    # --- кожа (skin) для рук — поры, костяшки, 0..1 на кисть ---
    sk = 0.78, 0.58, 0.47
    pores = vnoise(S, 64, 300) * 0.5 + vnoise(S, 32, 301) * 0.5
    sr = 0.78 + (pores - 0.5) * 0.10 + grain(302, 0.012)
    sg = 0.58 + (pores - 0.5) * 0.09
    sb = 0.47 + (pores - 0.5) * 0.07
    knuck = ((x % 64 - 32) ** 2 / 400 + (y % 64 - 32) ** 2 / 400) < 1.0
    sr = np.where(knuck, sr * 1.04, sr)
    hsk = (pores * 0.3 + 0.5).astype(np.float32)
    save("skin", to_rgb(sr, sg, sb), normal_from_height(hsk, 1.0))

    # --- бумага (paper) ---
    pa = 0.86 + fbm(S, 310, 8, 3) * 0.06 + grain(311, 0.014)
    lines_ = (y % 24 < 1)
    pa = np.where(lines_, pa * 0.92, pa)
    save("paper", to_rgb(pa, pa * 0.94, pa * 0.76))

    # --- шум-зерно для UI (film grain, RGBA) ---
    rng = np.random.default_rng(400)
    g = rng.random((128, 128))
    a = (g > 0.5).astype(np.float32) * g * 0.5
    im = np.dstack([np.full((128, 128), 255.0), np.full((128, 128), 255.0), np.full((128, 128), 255.0), a * 255]).astype(np.uint8)
    Image.fromarray(im, "RGBA").save(os.path.join(TEX, "grain.png"))

    # --- дымка для меню (мягкое пятно, RGBA) ---
    yy, xx = np.mgrid[0:256, 0:256]
    d = np.sqrt((xx - 128) ** 2 + (yy - 128) ** 2) / 128.0
    a = np.clip(1.0 - d, 0, 1) ** 2.2
    im = np.dstack([np.full((256, 256), 200.0), np.full((256, 256), 210.0), np.full((256, 256), 225.0), a * 90]).astype(np.uint8)
    Image.fromarray(im, "RGBA").save(os.path.join(TEX, "fogblob.png"))

    # --- пылинка (мягкая точка, RGBA) ---
    d2 = np.sqrt((xx - 128) ** 2 + (yy - 128) ** 2) / 128.0
    a2 = np.clip(1.0 - d2, 0, 1) ** 3.0
    im = np.dstack([np.full((256, 256), 255.0), np.full((256, 256), 250.0), np.full((256, 256), 235.0), a2 * 200]).astype(np.uint8)
    Image.fromarray(im, "RGBA").resize((64, 64), Image.LANCZOS).save(os.path.join(TEX, "dust.png"))

    # --- виньетка (тёмные края, RGBA) ---
    dv = np.sqrt(((xx - 128) / 128.0) ** 2 + ((yy - 128) / 96.0) ** 2) / 1.414
    av = np.clip((dv - 0.55) / 0.65, 0, 1) ** 1.6 * 235
    im = np.dstack([np.zeros((256, 256)), np.zeros((256, 256)), np.zeros((256, 256)), av]).astype(np.uint8)
    Image.fromarray(im, "RGBA").save(os.path.join(TEX, "vignette.png"))
    print("textures OK")


# ------------------------------------------------------------------ audio
RATE = 32000


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * RATE)) / RATE


def env_ar(n: int, attack: float, curve: float, rate: int = RATE) -> np.ndarray:
    """min(1, t*attack) * (1-t)^curve — как в audio.gd, векторно."""
    t = np.arange(n) / rate
    k = t / max(n / rate, 1e-4)
    return np.minimum(1.0, k * attack) * np.power(np.maximum(0.0, 1.0 - k), curve)


def tone(dur: float, f0: float, f1: float, amp: float, curve: float = 1.0, kind: str = "sine", vib: float = 0.0, vib_rate: float = 5.0, seed: int = 1) -> np.ndarray:
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / max(dur, 1e-4))
    if vib > 0:
        f = f * (1.0 + np.sin(t * 2 * math.pi * vib_rate) * vib)
    ph = np.cumsum(2 * math.pi * f / RATE)
    if kind == "sine":
        v = np.sin(ph)
    elif kind == "square":
        v = np.sign(np.sin(ph))
    elif kind == "saw":
        v = 2 * (ph / (2 * math.pi) % 1.0) - 1
    else:
        rng = np.random.default_rng(seed)
        v = rng.standard_normal(len(t))
    return v * amp * env_ar(len(t), 24.0, curve)


def noise(dur: float, amp: float, curve: float = 2.0, smooth: float = 0.0, seed: int = 2) -> np.ndarray:
    rng = np.random.default_rng(seed)
    v = rng.standard_normal(int(dur * RATE)).astype(np.float32)
    if smooth > 0:
        a = 1.0 - smooth
        # one-pole lowpass
        out = np.empty_like(v)
        acc = 0.0
        for i in range(len(v)):
            acc += a * (v[i] - acc)
            out[i] = acc
        v = out
    return v * amp * env_ar(len(v), 18.0, curve)


def mix(*parts) -> np.ndarray:
    """Сумма сегментов разной длины с нулевым паддингом."""
    n = max(len(p) for p in parts)
    out = np.zeros(n, np.float32)
    for p in parts:
        out[:len(p)] += p
    return out



def at(total: int, seg: np.ndarray, delay: float) -> np.ndarray:
    """Сегмент seg, вставленный с задержкой delay (сек) в буфер длины total."""
    out = np.zeros(total, np.float32)
    s = int(delay * RATE)
    if s < total:
        out[s:s + len(seg)] += seg[:total - s]
    return out


def lowpass(x: np.ndarray, alpha: float) -> np.ndarray:
    """Скользящее среднее: окно ~ 1/alpha (векторно)."""
    w = max(1, int(round(1.0 / max(alpha, 1e-3))))
    k = np.ones(w, np.float32) / w
    y = np.convolve(x, k, mode="full")[: len(x)]
    return (x[:1] * 0 + y).astype(np.float32)


def reverb(x: np.ndarray, room: float = 0.5, wet: float = 0.3) -> np.ndarray:
    """Многотаповое эхо с затуханием (векторно)."""
    taps = [0.0297, 0.0371, 0.0411, 0.0613, 0.0891]
    gains = [0.42, 0.34, 0.28, 0.20, 0.14]
    out = x.copy()
    n = len(x)
    for tap, g in zip(taps, gains):
        d = int(tap * RATE)
        if d < n:
            echo = np.zeros(n)
            echo[d:] = x[: n - d] * g
            out += echo
    # вторичное отражение (эхо от эха)
    for tap, g in [(0.0213, 0.18), (0.0537, 0.12)]:
        d = int(tap * RATE)
        if d < n:
            echo = np.zeros(n)
            echo[d:] = out[: n - d] * g
            out += echo
    return np.clip(x * (1 - wet) + out * wet * room * 1.4, -1, 1)


def softclip(x: np.ndarray) -> np.ndarray:
    return np.tanh(x * 1.2) / 1.2


def write_wav(name: str, x: np.ndarray, loop: bool = False) -> None:
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    path = os.path.join(SND, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    # маркер петли в имени не нужен — loop ставится в audio.gd на загруженном стриме
    print(f"  {name}.wav {len(x)/RATE:.2f}s")


def loopify(x: np.ndarray, fade: float = 0.5) -> np.ndarray:
    m = int(fade * RATE)
    n = len(x)
    k = np.linspace(0, 1, m)
    head = x[:m] * k + x[n - m:] * (1 - k)
    return np.concatenate([head, x[m:n - m]])


def gen_audio() -> None:
    print("audio...")
    # ---- шаги по поверхностям ----
    def step(shift=0.0, seed=11):
        return softclip(mix(
            noise(0.13, 0.20, 4.0, 0.55, seed),
            tone(0.14, 95 + shift * 8, 48 + shift * 4, 0.28, 2.5),
            tone(0.05, 1800 + shift * 210, 900, 0.05, 3.0, "noise", seed=seed + 1),
        ))
    write_wav("step", step(0.0, 11))
    write_wav("step2", step(1.7, 21))
    write_wav("step_tile", softclip(mix(
        tone(0.09, 1900, 900, 0.10, 3.0, "noise", seed=31),
        tone(0.11, 210, 95, 0.30, 2.8),
        noise(0.06, 0.16, 3.0, 0.4, 33),
    )))
    # скрипучая деревянная доска
    write_wav("step_wood", softclip(mix(
        tone(0.34, 420, 170, 0.11, 1.4, "saw", vib=0.05, vib_rate=11, seed=41),
        tone(0.22, 560, 240, 0.05, 1.6, vib=0.08, vib_rate=7),
        noise(0.20, 0.05, 2.4, 0.75, 42),
        tone(0.10, 130, 70, 0.22, 2.6),
    )))
    # бетонный шлепок
    write_wav("step_concrete", softclip(mix(
        tone(0.10, 260, 110, 0.30, 2.6),
        noise(0.07, 0.22, 3.5, 0.35, 51),
        tone(0.06, 2100, 1100, 0.05, 3.0, "noise", seed=52),
    )))
    # ковёр — глухо
    write_wav("step_rug", softclip(mix(
        lowpass(noise(0.12, 0.20, 3.6, 0.82, 61), 0.28),
        tone(0.10, 88, 55, 0.16, 2.8),
    )))
    # тяжёлый шаг Гренни: глухой удар + скрип доски
    write_wav("granny_step", softclip(mix(
        tone(0.20, 85, 38, 0.42, 2.2),
        lowpass(noise(0.16, 0.30, 3.2, 0.72, 71), 0.25),
        tone(0.30, 380, 160, 0.08, 1.6, "saw", vib=0.05, vib_rate=9, seed=72),
    )))
    # ---- базовые ----
    write_wav("creak", reverb(softclip(mix(
        tone(0.55, 380, 150, 0.15, 1.2, "saw", vib=0.05, vib_rate=9, seed=81),
        tone(0.42, 520, 210, 0.07, 1.4, vib=0.08, vib_rate=7, seed=82),
        noise(0.5, 0.035, 2.0, 0.8, 83),
    )), 0.35, 0.18))
    write_wav("door_slam", softclip(mix(
        tone(0.35, 120, 40, 0.45, 3.0),
        noise(0.22, 0.35, 3.0, 0.7, 91),
        tone(0.18, 320, 90, 0.12, 3.0, "square"),
    )))
    write_wav("lock", softclip(mix(
        noise(0.04, 0.25, 2.0, 0, 101),
        tone(0.08, 900, 500, 0.16, 2.5),
        at(int(0.25 * RATE), tone(0.09, 700, 380, 0.13, 2.5), 0.13),
        at(int(0.25 * RATE), noise(0.05, 0.20, 2.0, 0, 102), 0.13),
    )))
    parts = [np.zeros(int(0.55 * RATE))]
    for i in range(3):
        s = int(i * 0.11 * RATE)
        parts.append(at(int(0.55 * RATE), noise(0.05, 0.18, 2.0, 0, 111 + i), float(s) / RATE))
        parts.append(at(int(0.55 * RATE), tone(0.10, 620 + i * 180, 420 + i * 90, 0.14, 2.5), float(s) / RATE))
    parts.append(at(int(0.55 * RATE), tone(0.18, 520, 260, 0.12, 2.0, "square"), 0.34))
    write_wav("unlock", softclip(mix(*parts)))
    write_wav("pickup", softclip(mix(
        tone(0.16, 640, 880, 0.22, 1.5),
        at(int(0.42 * RATE), tone(0.25, 960, 1240, 0.18, 1.8), 0.10),
        tone(0.30, 320, 480, 0.08, 2.0),
    )))
    parts = [np.zeros(int(0.45 * RATE))]
    for i in range(4):
        s = int(i * 0.10 * RATE)
        parts.append(at(int(0.45 * RATE), noise(0.08, 0.15, 3.0, 0.4, 121 + i), float(s) / RATE))
        parts.append(at(int(0.45 * RATE), tone(0.06, 260 + i * 40, 160, 0.07, 2.0), float(s) / RATE))
    write_wav("search", mix(*parts))
    parts = [noise(0.5, 0.38, 3.0, 0.15, 131), tone(0.10, 2400, 900, 0.16, 3.0, "noise", seed=132)]
    n65 = int(0.65 * RATE)
    for i in range(5):
        parts.append(at(n65, tone(0.07, 1200 + i * 240, 700, 0.07, 3.0), (0.04 + i * 0.06)))
    write_wav("break", softclip(mix(*parts)))
    write_wav("snap", softclip(mix(
        noise(0.04, 0.35, 2.0, 0, 141),
        tone(0.16, 1400, 420, 0.28, 2.4, "square"),
        tone(0.30, 260, 90, 0.20, 2.0),
    )))
    write_wav("scream", reverb(softclip(mix(
        tone(0.85, 780, 260, 0.28, 1.2, "saw", vib=0.10, vib_rate=8, seed=151),
        tone(0.75, 390, 130, 0.16, 1.4, "square", vib=0.06, vib_rate=6, seed=152),
        noise(0.7, 0.16, 1.6, 0.35, 153),
    )), 0.5, 0.3))
    write_wav("heart", softclip(mix(
        tone(0.22, 72, 42, 0.45, 2.5),
        at(int(0.65 * RATE), tone(0.22, 66, 38, 0.32, 2.5), 0.25),
    )))
    write_wav("meow", softclip(mix(
        tone(0.48, 720, 480, 0.22, 1.2, "saw", vib=0.12, vib_rate=9),
        at(int(0.55 * RATE), tone(0.36, 960, 620, 0.10, 1.4, vib=0.10, vib_rate=8), 0.08),
        noise(0.25, 0.03, 2.0, 0.8, 161),
    )))
    write_wav("hiss", softclip(mix(
        noise(0.35, 0.32, 2.0, 0.05, 171),
        tone(0.35, 1500, 900, 0.10, 2.0, "noise", seed=172),
    )))
    # мурлыканье: AM-модуляция 24 Гц по 52 Гц тону
    t = t_axis(1.05)
    purr_env = np.minimum(1.0, t * 8) * np.minimum(1.0, (1.05 - t) * 8)
    purr = np.sin(t * 2 * math.pi * 52) * 0.16 * (0.55 + 0.45 * np.sin(t * 2 * math.pi * 24)) * purr_env
    purr = mix(purr, noise(1.05, 0.015, 2.0, 0, 181) * purr_env)
    write_wav("purr", purr)
    write_wav("thunder", reverb(softclip(mix(
        lowpass(noise(1.4, 0.45, 1.4, 0.90, 191), 0.12),
        tone(1.2, 55, 28, 0.35, 1.6),
        at(int(1.6 * RATE), lowpass(noise(1.45, 0.25, 2.5, 0.75, 193), 0.2), 0.15),
    )), 0.6, 0.4))
    write_wav("whisper", softclip(mix(
        lowpass(noise(0.75, 0.14, 1.5, 0.94, 201), 0.5),
        at(int(0.85 * RATE), tone(0.75, 220, 140, 0.035, 2.0, "noise", seed=202), 0.10),
    )))
    write_wav("climb", softclip(mix(
        noise(0.10, 0.15, 2.0, 0.5, 211),
        tone(0.16, 150, 90, 0.18, 2.0),
        at(int(0.75 * RATE), noise(0.75, 0.14, 2.0, 0.5, 212), 0.20),
        at(int(0.75 * RATE), tone(0.75, 170, 100, 0.16, 2.0), 0.20),
        at(int(0.75 * RATE), tone(0.75, 330, 180, 0.07, 2.0, "saw", vib=0.04, vib_rate=8), 0.40),
    )))
    write_wav("crossbow_shot", softclip(mix(
        noise(0.05, 0.30, 2.0, 0, 221),
        tone(0.22, 1600, 300, 0.24, 2.2, "square"),
        noise(0.30, 0.15, 2.5, 0.4, 222),
        tone(0.28, 700, 180, 0.10, 2.0, "saw"),
    )))
    write_wav("crossbow_reload", softclip(mix(
        noise(0.04, 0.22, 2.0, 0, 231),
        tone(0.08, 820, 420, 0.12, 2.5),
        at(int(0.32 * RATE), noise(0.32, 0.20, 2.0, 0, 232), 0.16),
        at(int(0.32 * RATE), tone(0.32, 640, 320, 0.11, 2.5), 0.16),
    )))
    write_wav("dart_hit", softclip(mix(
        tone(0.25, 160, 70, 0.28, 2.0),
        noise(0.18, 0.20, 2.5, 0.3, 241),
        at(int(0.45 * RATE), tone(0.45, 600, 300, 0.07, 2.0, "noise", seed=242), 0.10),
    )))
    parts = []
    n12 = int(1.2 * RATE)
    for i, f in enumerate([392.0, 523.25, 659.25, 783.99]):
        parts.append(at(n12, tone(0.5, f, f, 0.16, 1.2), (i * 0.16)))
    parts.append(at(n12, tone(0.5, 1046.5, 1046.5, 0.10, 1.5), (0.64)))
    write_wav("win", softclip(mix(*parts)))
    parts = []
    n13 = int(1.3 * RATE)
    for i, f in enumerate([392.0, 329.63, 261.63, 196.0]):
        parts.append(at(n13, tone(0.6, f, f * 0.98, 0.16, 1.2, "saw"), (i * 0.22)))
    write_wav("lose", softclip(mix(*parts)))
    t = t_axis(1.5)
    car = np.sin(t * 2 * math.pi * (42 + np.sin(t * 3) * 5 + t * 18)) * 0.22 + np.sin(t * 2 * math.pi * (84 + np.sin(t * 3) * 10 + t * 36)) * 0.10
    write_wav("car_start", softclip(mix(car * env_ar(len(t), 3.0, 2.0), noise(0.25, 0.12, 2.0, 0.3, 251))))
    write_wav("spider_hiss", softclip(mix(
        noise(0.4, 0.22, 2.0, 0.15, 261),
        tone(0.4, 1800, 2600, 0.06, 2.0, "noise", vib=0.2, vib_rate=12, seed=262),
        tone(0.55, 300, 200, 0.06, 2.0, "saw"),
    )))
    write_wav("ui_move", softclip(mix(noise(0.03, 0.10, 2.0, 0, 271), tone(0.08, 520, 420, 0.09, 2.5))))
    write_wav("ui_select", softclip(mix(
        noise(0.03, 0.10, 2.0, 0, 281),
        tone(0.08, 760, 620, 0.09, 2.5),
        at(int(0.24 * RATE), tone(0.12, 980, 680, 0.08, 2.2), 0.07),
    )))
    # гул Гренни (мелодичный)
    parts = [np.zeros(int(2.6 * RATE))]
    for (s0, d0, f0) in [(0.0, 0.5, 220.0), (0.5, 0.4, 233.0), (0.9, 0.7, 196.0), (1.6, 0.45, 174.6), (2.05, 0.5, 220.0)]:
        seg = tone(d0, f0, f0 * 0.98, 0.16, 1.6, vib=0.03, vib_rate=5.5, seed=int(f0))
        seg = mix(seg, tone(d0, f0 * 0.5, f0 * 0.49, 0.05, 1.8))
        parts.append(at(int(2.6 * RATE), seg, float(s0)))
    parts.append(at(int(2.6 * RATE), noise(2.4, 0.012, 1.5, 0.92, 291), 0.0))
    write_wav("hum", reverb(softclip(mix(*parts)), 0.4, 0.22))

    # ---- музыка: меню (24 c, A-minor арпеджио + дрон + эхо) ----
    parts = [tone(24.0, 55.0, 55.0, 0.10, 0.15), tone(24.0, 110.0, 109.5, 0.05, 0.15), tone(24.0, 164.8, 164.5, 0.02, 0.2)]
    parts.append(lowpass(noise(24.0, 0.012, 0.2, 0.985, 301), 0.3))
    seq = [440.0, 523.25, 392.0, 329.63, 440.0, 659.25, 523.25, 392.0, 329.63, 293.66, 329.63, 440.0]
    t0 = 1.0
    for i, f in enumerate(seq):
        seg = mix(
            tone(2.6, f, f, 0.045, 2.6, vib=0.01, vib_rate=4.5, seed=400 + i),
            tone(2.2, f * 2.0, f * 2.0, 0.016, 3.4),
        )
        parts.append(at(int(24.0 * RATE), seg, float(t0)))
        t0 += 1.8 + (0.35 if i % 3 == 0 else 0.1)
    b = reverb(mix(*parts), 0.65, 0.35)
    b = loopify(b)
    write_wav("music_menu", softclip(b))

    # ---- эмбиент дома (32 c): дождь + ветер + дрон + далёкий гром ----
    rain = lowpass(noise(32.0, 0.5, 0.0, 0.0, seed=310), 0.32)
    rain *= 0.10 + 0.03 * np.sin(t_axis(32.0) * 0.7)
    wind = lowpass(noise(32.0, 0.6, 0.0, 0.0, seed=311), 0.10)
    lfo = 0.5 + 0.5 * np.sin(t_axis(32.0) * 0.9 + 1.3) * np.sin(t_axis(32.0) * 0.23)
    th = lowpass(noise(2.2, 0.30, 2.2, 0.93, 312), 0.12)
    parts = [
        tone(32.0, 46.0, 46.0, 0.16, 0.1), tone(32.0, 92.0, 91.5, 0.05, 0.12),
        rain, wind * (0.14 * lfo),
        at(int(32.0 * RATE), th, 9.5),
    ]
    b = loopify(mix(*parts))
    write_wav("music_ambient", softclip(b))

    # ---- напряжение (20 c): суб-пульс + диссонанс + тиканье ----
    parts = [np.zeros(int(20.0 * RATE))]
    for k in range(int(20 / 1.4)):
        s = int(k * 1.4 * RATE)
        parts.append(at(int(20.0 * RATE), tone(0.26, 62, 40, 0.30, 2.4), float(s) / RATE))
        s2 = s + int(0.5 * RATE)
        parts.append(at(int(20.0 * RATE), tone(0.20, 56, 38, 0.20, 2.4), float(s2) / RATE))
    for k in range(20):
        s = int(k * 1.0 * RATE)
        parts.append(at(int(20.0 * RATE), noise(0.02, 0.10, 2.0, 0, seed=320 + k), float(s) / RATE))
    for (st, dur, f) in [(2.0, 3.0, 220.0), (6.5, 2.5, 311.1), (11.0, 3.0, 233.1), (15.5, 3.0, 220.0)]:
        sw = mix(
            tone(dur, f, f * 1.01, 0.055, 0.8, "saw", vib=0.01, vib_rate=3, seed=int(f)),
            tone(dur, f * 0.5, f * 0.5, 0.05, 0.8),
        )
        parts.append(at(int(20.0 * RATE), sw, float(st)))
    parts.append(lowpass(noise(20.0, 0.35, 0.0, 0.0, seed=330), 0.06) * 0.10)
    b = loopify(mix(*parts))
    write_wav("music_tension", softclip(b))

    # ---- погоня (14 c): 150 BPM, кик + дробь + стаккато-бас ----
    parts = [np.zeros(int(14.0 * RATE))]
    beat = 60.0 / 150.0  # 0.4 c
    n14 = int(14.0 * RATE)
    for k in range(int(14 / beat)):
        s = int(k * beat * RATE)
        if k % 2 == 0:
            parts.append(at(n14, tone(0.16, 150, 48, 0.42, 2.2), float(s) / RATE))
        else:
            parts.append(at(n14, noise(0.09, 0.22, 2.6, 0.1, seed=340 + k), float(s) / RATE))
        for e in range(2):
            s2 = s + int(e * beat * 0.5 * RATE)
            parts.append(at(n14, noise(0.03, 0.07, 2.0, 0, seed=360 + k * 2 + e), float(s2) / RATE))
    bass_notes = [220.0, 220.0, 261.63, 311.13]
    for bar in range(int(14 / (beat * 4))):
        for q in range(4):
            f = bass_notes[(bar * 4 + q) % 4]
            s = int((bar * 4 + q) * beat * RATE)
            nt = at(n14, tone(beat * 0.9, f, f, 0.14, 0.9, "saw"), float(s) / RATE)
            parts.append(nt)
    rz = noise(1.2, 0.10, 0.6, 0.0, seed=380) * np.linspace(0.2, 1.0, int(1.2 * RATE))
    parts.append(at(n14, rz, (12.8)))
    b = loopify(mix(*parts), 0.25)
    write_wav("music_chase", softclip(b))
    print("audio OK")


# ------------------------------------------------------------------ fonts
def gen_fonts() -> None:
    import matplotlib
    src = os.path.join(os.path.dirname(matplotlib.__file__), "mpl-data", "fonts", "ttf")
    for f in ("DejaVuSans.ttf", "DejaVuSans-Bold.ttf"):
        with open(os.path.join(src, f), "rb") as fh:
            data = fh.read()
        with open(os.path.join(FNT, f), "wb") as fh:
            fh.write(data)
        print(f"  fonts/{f} {len(data)//1024}KB")
    print("fonts OK")


if __name__ == "__main__":
    gen_textures()
    gen_audio()
    gen_fonts()
    print("ALL ASSETS GENERATED")
