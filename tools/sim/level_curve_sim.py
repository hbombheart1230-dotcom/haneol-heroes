"""판 안 레벨·카드 시간표 시뮬 (결정적): 5물결·약 4분 판에서 영웅별·실력별로 레벨과 카드가 언제 오는지.

  python tools/sim/level_curve_sim.py            # 표 출력 (마크다운)
  python tools/sim/level_curve_sim.py --check    # 목표를 어기면 종료 코드 1

곡선·점수·카드 규칙은 게임 데이터를 그대로 읽는다 (data/runs/level_rules.tres, score_table.tres).
물결 구성(PLAN)은 확정된 판 구조(① 잡몹 떼 ② 떼+새 종류 ③ 중간 보스 ④ 떼+정예 ⑤ 보스)를 한산 적 구성으로 채운 가정이다.
적 움직임 세션이 물결 데이터를 바꾸면 PLAN만 맞춰 다시 돌린다.
영웅 빠르기(PACE)는 tests/test_stage_sim.gd 봇 기록 (같은 50마리를 깨는 시간 비: 순신 43s·광개토 40s·세종 30s·사임당 33s).
실력(SKILL): 물결을 깨는 시간 배율과 분당 행동 횟수 (점수는 ScoreTable 간격·물결당 상한을 그대로 적용).
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# 물결: (적 xp 목록, 보통 실력·순신 기준 싸우는 시간 초). 처치 점수 = xp × 무대 xp_mult(2) × kill_mult.
SOLDIER, GUNNER, HEAVY, ELITE, MID_BOSS = 1, 2, 4, 12, 20
PLAN = [
    ([SOLDIER] * 14 + [GUNNER] * 2, 40.0),
    ([SOLDIER] * 16 + [GUNNER] * 3 + [HEAVY] * 2, 47.0),
    ([MID_BOSS] + [SOLDIER] * 8, 42.0),
    ([SOLDIER] * 18 + [GUNNER] * 3 + [HEAVY] * 2 + [ELITE], 47.0),
]
BREATH = 8.0  # 숨 고르기 (카드 고르는 시간 포함)
BOSS_FIGHT = 35.0
STAGE_XP_MULT = 2.0
PACE = {"순신": 1.0, "광개토": 0.93, "세종": 0.85, "사임당": 0.9}
# 실력: 시간 배율, 분당 (연타 마무리, 회피, 반격 명중, 충전 만충 명중)
SKILL = {
    "잘함": (0.85, (12, 8, 5, 3)),
    "보통": (1.0, (6, 4, 2, 1.5)),
    "서툼": (1.3, (2, 1.5, 0.3, 0.3)),
}
KINDS = ("combo", "evade", "counter", "charge")


def read_tres(rel):
    vals = {}
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^(\w+) = (.+)$", line.strip())
            if m:
                vals[m.group(1)] = m.group(2)
    return vals


def load_rules():
    r = read_tres("data/runs/level_rules.tres")
    s = read_tres("data/runs/score_table.tres")
    needs = [int(x) for x in re.findall(r"\d+", r["needs"].split("(", 1)[1])]
    return {
        "needs": needs, "tail": int(r["tail_growth"]), "vfx_every": int(r["vfx_every"]),
        "picks": int(r["picks_per_break"]), "per_break": int(r["cards_per_break"]),
        "last_picks": int(r["last_break_picks"]), "min": int(r["min_cards_per_break"]),
        "kill_mult": float(s["kill_mult"]), "cap": int(s["per_wave_cap"]),
        "value": {"combo": int(s["combo_finish"]), "evade": int(s["evade"]), "counter": int(s["counter_hit"]),
                  "charge": int(s["full_charge"])},
        "gap": {"combo": float(s["combo_gap"]), "evade": float(s["evade_gap"]), "counter": float(s["counter_gap"]),
                "charge": float(s["charge_gap"])},
    }


def need(R, level):
    i = level - 1
    if i < len(R["needs"]):
        return R["needs"][i]
    return R["needs"][-1] + R["tail"] * (i - len(R["needs"]) + 1)


def plan(R, banked, last):
    cards = max(banked, R["min"])
    picks = R["last_picks"] if last else R["picks"]
    if not last:
        cards = min(cards, R["per_break"])
    picks = max(1, min(picks, cards))
    out = [cards // picks] * picks
    for i in range(cards % picks):
        out[picks - 1 - i] += 1
    return out


def run(R, hero, skill):
    tmul, rates = SKILL[skill]
    tmul *= PACE[hero]
    events = []  # (t, kind, value)
    t = 0.0
    breaks = []
    for wi, (enemies, dur) in enumerate(PLAN):
        d = dur * tmul
        for k, xp in enumerate(enemies):  # 첫 처치 3초 뒤, 고르게
            events.append((t + 3.0 + (d - 3.0) * k / max(len(enemies) - 1, 1), "kill", xp * STAGE_XP_MULT * R["kill_mult"]))
        for kind, per_min in zip(KINDS, rates):
            if per_min <= 0:
                continue
            step = 60.0 / per_min
            x = t + step * 0.5
            while x < t + d:
                events.append((x, kind, 0))
                x += step
        t += d
        breaks.append((t, wi))
        t += BREATH
    events.sort()
    level, xp, bank, total_cards, stacks = 1, 0, 0, 0, 0
    first_level = None
    last_t = {}
    count = {}
    rows = []
    bi = 0
    for (et, kind, v) in events + [(1e9, "end", 0)]:
        while bi < len(breaks) and breaks[bi][0] <= et:
            bt, wi = breaks[bi]
            last = wi == len(PLAN) - 1
            p = plan(R, bank, last)
            used = sum(p)
            free = max(0, used - bank)
            bank = max(0, bank - used)
            stacks += used
            total_cards += free
            rows.append({"t": bt, "level": level, "picks": len(p), "stacks": used, "carry": bank,
                         "vfx": (level - 1) // R["vfx_every"] if R["vfx_every"] else 0})
            count = {}
            bi += 1
        if kind == "end":
            break
        if kind != "kill":
            if kind in last_t and et - last_t[kind] < R["gap"][kind]:
                continue
            if R["cap"] and count.get(kind, 0) >= R["cap"]:
                continue
            last_t[kind] = et
            count[kind] = count.get(kind, 0) + 1
            v = R["value"][kind]
        xp += round(v)
        while xp >= need(R, level):
            xp -= need(R, level)
            level += 1
            bank += 1
            total_cards += 1
            if first_level is None:
                first_level = et
    return {"first": first_level, "rows": rows, "level": level, "stacks": stacks}


def main():
    R = load_rules()
    print("| 영웅 | 실력 | 첫 레벨업 | 숨①(레벨·고름·단계) | 숨② | 숨③ | 숨④ 보스 직전 | 보스전 레벨 | 모습 단계 | 강화 단계 합 |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    bad = []
    for hero in PACE:
        for skill in SKILL:
            r = run(R, hero, skill)
            cells = []
            for row in r["rows"]:
                cells.append("%ds L%d %d번·%d단계%s" % (row["t"], row["level"], row["picks"], row["stacks"],
                                                    " (남김 %d)" % row["carry"] if row["carry"] else ""))
            vfx = (r["level"] - 1) // R["vfx_every"]
            print("| %s | %s | %.0f초 | %s | %d | +%d | %d |" % (hero, skill, r["first"] or -1, " | ".join(cells),
                                                             r["level"], vfx, r["stacks"]))
            if skill == "보통" and not (8.0 <= (r["first"] or 99) <= 16.0):
                bad.append(f"{hero} 보통 첫 레벨업 {r['first']}")
            if r["rows"][0]["stacks"] < 1:
                bad.append(f"{hero} {skill} 첫 숨 고르기 카드 없음")
    old = 3 * 2  # 옛 물결 방식: 숨 고르기 3번 × 2단계 (+ 정예 큰 변형 1, 둘 다 같음)
    print(f"\n옛 방식 강화 단계 합: {old} (3물결) — 5물결이면 4번 × 2 = 8")
    if bad:
        print("목표 어김:", *bad, sep="\n  ")
    if "--check" in sys.argv and bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
