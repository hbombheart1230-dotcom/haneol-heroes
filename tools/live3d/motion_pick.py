"""동작 구간 고르기: motion_scan.gd 시트(8방향 × 칸)에서 칸마다 몸 기울기·중심·키·칼끝 각을 재고
슬롯(1·2·3타, 마무리, 반격, 뒤로 빠지기)마다 가장 큰 움직임의 구간을 추천한다.

정의 (measure_motion.py·무대 세션 motion_compare와 같음, 8방향 중앙값):
  몸 기울기 폭 = 실루엣 주축 각도 최대 - 최소 (°), 무게 이동 = 실루엣 중심 가로 이동 ÷ 몸 키
  칼끝 호 = 가슴에서 가장 먼 실루엣 점(대개 칼끝)의 각도가 쓸고 간 폭 (°, 이어 붙여 360 넘김 허용)
  맞닿음 = 구간 안에서 칼끝 각속도가 가장 빠른 칸 (빠르게 베는 순간)

python tools/live3d/motion_pick.py <scan 폴더> [출력 json]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

# 슬롯 → (최소 길이, 최대 길이, 후보 동작 접두 / 이름)
SLOTS = {
    "1타": (0.45, 0.75, "web_weapon web_sword triple righthand"),
    "2타": (0.45, 0.80, "web_weapon web_sword triple righthand"),
    "3타": (0.55, 0.95, "web_weapon web_sword web_jump web_axe triple"),
    "마무리": (0.85, 1.40, "web_jump web_axe web_sword web_charged web_weapon double charged"),
    "반격": (0.60, 1.20, "web_dodge web_axe web_weapon double"),
    "뒤로 빠지기": (0.40, 1.00, "web_swordparry web_dodge"),
}
# 지금 쓰는 구간 (feat/yi-reach ebec94d, 굽기 작업)
CURRENT = {
    "1타": ("triplecomboattack", 0.34, 0.90),
    "2타": ("triplecomboattack", 0.90, 1.68),
    "3타": ("triplecomboattack", 1.68, 2.45),
    "마무리": ("doublebladespin", 0.45, 1.50),
    "반격": ("doublebladespin", 1.12, 1.85),
}


def frame_stats(cell, chest):
    a = cell[:, :, 3] > 40
    ys, xs = np.nonzero(a)
    if len(xs) < 30:
        return None
    cx, cy = xs.mean(), ys.mean()
    cov = np.cov(np.stack([xs - cx, ys - cy]))
    w, v = np.linalg.eigh(cov)
    ax = v[:, np.argmax(w)]
    ang = np.degrees(np.arctan2(ax[0], ax[1]))
    if ang > 90:
        ang -= 180
    if ang < -90:
        ang += 180
    d2 = (xs - chest[0]) ** 2 + (ys - chest[1]) ** 2
    k = int(np.argmax(d2))
    tip = np.degrees(np.arctan2(ys[k] - chest[1], xs[k] - chest[0]))
    return ang, cx, ys.max() - ys.min(), tip


def load(folder, name):
    meta = json.load(open(os.path.join(folder, name + ".json"), encoding="utf-8"))
    im = np.asarray(Image.open(os.path.join(folder, name + ".png")).convert("RGBA"))
    c = meta["cell"]
    stats = []  # [dir][frame]
    for d in range(8):
        row = []
        for f in range(meta["frames"]):
            row.append(frame_stats(im[d * c:(d + 1) * c, f * c:(f + 1) * c], meta["chest"][d][f]))
        stats.append(row)
    return meta, stats


def window(meta, stats, f0, f1):
    """구간 [f0, f1] 칸의 8방향 중앙값: 기울기 폭, 무게 이동, 칼끝 호, 맞닿는 칸."""
    tilts, shifts, arcs, hits = [], [], [], []
    for d in range(8):
        st = [s for s in stats[d][f0:f1 + 1] if s]
        if len(st) < 3:
            continue
        angs = [s[0] for s in st]
        xs = [s[1] for s in st]
        h = np.median([s[2] for s in st])
        tip = np.unwrap(np.radians([s[3] for s in st]))
        tilts.append(max(angs) - min(angs))
        shifts.append((max(xs) - min(xs)) / max(h, 1.0))
        arcs.append(np.degrees(tip.max() - tip.min()))
        hits.append(int(np.argmax(np.abs(np.diff(tip)))) + 1)
    if not tilts:
        return None
    return {"tilt": float(np.median(tilts)), "shift": float(np.median(shifts)), "arc": float(np.median(arcs)),
            "hit": f0 + int(np.median(hits))}


def score(w):
    return w["tilt"] + 40.0 * w["shift"] + 0.25 * w["arc"]


def main():
    folder = sys.argv[1]
    names = sorted(n[:-5] for n in os.listdir(folder) if n.endswith(".json"))
    data = {n: load(folder, n) for n in names}
    out = {"slots": {}, "current": {}, "chains": []}
    for slot, (lo, hi, pref) in SLOTS.items():
        cands = []
        for n in names:
            if not any(n.startswith(p) for p in pref.split()):
                continue
            meta, stats = data[n]
            fps = meta["fps"]
            for f0 in range(meta["frames"]):
                for ln in np.arange(lo, hi + 1e-6, 0.1):
                    f1 = f0 + int(round(ln * fps))
                    if f1 >= meta["frames"]:
                        break
                    w = window(meta, stats, f0, f1)
                    if w:
                        cands.append({"clip": n, "start": round(f0 / fps, 2), "end": round(f1 / fps, 2),
                                      "strike": round(w["hit"] / fps, 2), **w, "score": score(w)})
        cands.sort(key=lambda c: -c["score"])
        picked = []
        for c in cands:  # 같은 동작에서 겹치는 구간은 하나만, 동작 하나에서 둘까지 (여러 동작을 보이게)
            if any(p["clip"] == c["clip"] and not (c["end"] <= p["start"] or c["start"] >= p["end"]) for p in picked):
                continue
            if sum(p["clip"] == c["clip"] for p in picked) >= 2:
                continue
            picked.append(c)
            if len(picked) == 4:
                break
        out["slots"][slot] = picked
    for slot, (n, s, e) in CURRENT.items():
        meta, stats = data[n]
        fps = meta["fps"]
        w = window(meta, stats, int(round(s * fps)), min(int(round(e * fps)), meta["frames"] - 1))
        out["current"][slot] = {"clip": n, "start": s, "end": e, **w, "score": score(w)}
    # 1·2·3타를 한 연타 동작에서 이어 자르기 (끝 = 다음 시작)
    for n in names:
        if not n.startswith("web_weapon") and not n.startswith("web_sword"):
            continue
        meta, stats = data[n]
        fps = meta["fps"]
        best = None
        L = [int(round(x * fps)) for x in np.arange(0.45, 0.85, 0.1)]
        for a0 in range(meta["frames"]):
            for l1 in L:
                for l2 in L:
                    for l3 in L:
                        a1, a2, a3 = a0 + l1, a0 + l1 + l2, a0 + l1 + l2 + l3
                        if a3 >= meta["frames"]:
                            continue
                        ws = [window(meta, stats, a0, a1), window(meta, stats, a1, a2), window(meta, stats, a2, a3)]
                        if not all(ws):
                            continue
                        tot = sum(score(w) for w in ws) + 0.3 * score(ws[2])  # 3타는 더 크게
                        if best is None or tot > best["total"]:
                            best = {"clip": n, "total": tot, "cuts": [round(x / fps, 2) for x in (a0, a1, a2, a3)],
                                    "hits": [ws[i] | {"strike": round(ws[i]["hit"] / fps, 2)} for i in range(3)]}
        if best:
            out["chains"].append(best)
    out["chains"].sort(key=lambda c: -c["total"])
    path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(folder, "picks.json")
    json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for slot, c in out["current"].items():
        print(f"현재 {slot}: {c['clip']} {c['start']}-{c['end']} 기울기 {c['tilt']:.0f} 이동 {c['shift']:.2f} 호 {c['arc']:.0f}")
    for slot, ps in out["slots"].items():
        for p in ps:
            print(f"{slot}: {p['clip']} {p['start']}-{p['end']} 맞닿음 {p['strike']} 기울기 {p['tilt']:.0f} "
                  f"이동 {p['shift']:.2f} 호 {p['arc']:.0f}")
    for c in out["chains"]:
        print("연타:", c["clip"], c["cuts"], [f"{h['tilt']:.0f}°/{h['arc']:.0f}" for h in c["hits"]])


if __name__ == "__main__":
    main()
