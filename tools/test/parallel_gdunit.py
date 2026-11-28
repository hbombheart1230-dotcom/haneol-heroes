#!/usr/bin/env python3
"""gdUnit 시험을 층(tier)으로 고르고, 여러 Godot 프로세스로 나눠 동시에 돌려 한 요약으로 합친다.

  python tools/test/parallel_gdunit.py --tier full --shards 4 --godot <Godot 콘솔 exe>
  python tools/test/parallel_gdunit.py --tier fast --shards 2 --godot <exe>        # 그림·글·UI·안내 고칠 때
  python tools/test/parallel_gdunit.py --tier related --shards 3 --godot <exe>     # 바뀐 파일 기준 + fast
  python tools/test/parallel_gdunit.py --tier sim --shards 4 --godot <exe>         # 전투 수치·적 행동 (느린 시뮬 포함)

- 층: tools/test/tiers.json (fast·sim 목록), related = git diff(--base 이후 + 아직 커밋 안 한 것)에 나온 파일 이름·class_name을
  쓰는 스위트 + fast. full = 전부 (베타·출시 후보).
- 조각 나누기: 스위트를 tools/test/suite_times.json의 지난 시간으로 무거운 것부터 가장 한가한 조각에 넣는다 (LPT).
  시간표에 없는 새 스위트는 중간값. 한 스위트는 쪼개지 않는다 (가장 긴 스위트가 걸리는 시간이 바닥).
- 프로세스마다 사용자 폴더를 따로 쓴다: APPDATA·LOCALAPPDATA를 <out>/shard_N/ 아래로 돌려 user:// 설정·저장 파일이 겹치지 않는다.
  보고서도 조각마다 따로 (-rd). 첫 한 번 --import로 클래스 목록을 맞춘다 (조각들이 같은 .godot 캐시를 동시에 쓰지 않게).
- 규칙: --remote-debug tcp://127.0.0.1:0. 잠금 build/gdunit.lock 하나를 전체가 쥔다 (gdunit_lock.py: 한 번에 하나 O_EXCL,
  자기 pid 잠금만 지움, 부모 셸이 죽으면 스스로 끝, 끝나면 모든 조각의 Godot 나무 taskkill /T, build/gdunit.stop 파일이 생기면 멈춤).
  잠겨 있으면 멈춘다 (--wait-minutes N이면 기다린다). --ignore-lock 없음.
- 요약: 조각별 걸린 시간, 전체 시험·실패 수, 스위트별 시간 상위, 실패 목록, 결정적 시뮬 줄([boss-sim] 등) 수.
  --update-times를 주면 시간표를 이번 값으로 고친다 (실패가 없고 전체일 때).
"""
import argparse, collections, json, os, re, signal, subprocess, sys, time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gdunit_lock, tiers  # noqa: E402

ANSI = re.compile(r"\x1b\[[0-9;]*m")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SIM_LINE = re.compile(r"\[(?:boss-sim|stage-sim|growth-sim|hazard-sim|cover-sim|fire-sim|grass-sim)[^\]]*\].*")


def secs(s):
    t = 0.0
    for pat, mul in ((r"(\d+)min", 60), (r"(\d+)s\b", 1), (r"(\d+)ms", 0.001)):
        m = re.search(pat, s or "")
        if m:
            t += mul * int(m.group(1))
    return t


def split(suites, times, n, separate=()):
    """무거운 것부터 가장 한가한 조각에. separate의 쌍은 같은 조각에 두지 않는다 (알려진 순서 의존)."""
    known = sorted(times.values())
    mid = known[len(known) // 2] if known else 1.0
    partners = collections.defaultdict(set)
    for group in separate:
        for g in group:
            partners[g].update(x for x in group if x != g)
    bins = [[0.0, []] for _ in range(n)]
    for s in sorted(suites, key=lambda s: -times.get(s, mid)):
        ok = [b for b in bins if not (partners[s] & set(b[1]))] or bins  # 조각이 하나뿐이면 어쩔 수 없다
        b = min(ok, key=lambda b: b[0])
        b[0] += times.get(s, mid)
        b[1].append(s)
    return bins


def shard_cmd(godot, names, d):
    cmd = [godot, "--headless", "--path", ROOT, "-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"]
    for n in names:
        cmd += ["-a", "res://tests/%s.gd" % n]
    return cmd + ["-c", "--ignoreHeadlessMode", "-rd", os.path.join(d, "reports"), "--remote-debug", "tcp://127.0.0.1:0"]


def start_shard(i, names, a):
    d = os.path.join(a.out, "shard_%d" % i)
    for sub in ("roaming", "local", "reports"):
        os.makedirs(os.path.join(d, sub), exist_ok=True)
    env = dict(os.environ, APPDATA=os.path.join(d, "roaming"), LOCALAPPDATA=os.path.join(d, "local"))
    log = os.path.join(d, "log.txt")
    f = open(log, "w", encoding="utf-8", errors="replace")
    p = subprocess.Popen(shard_cmd(a.godot, names, d), stdout=f, stderr=subprocess.STDOUT, env=env, cwd=ROOT)
    return {"i": i, "p": p, "f": f, "log": log, "t0": time.time(), "dur": None}


def parse(log):
    txt = ANSI.sub("", open(log, encoding="utf-8", errors="replace").read())
    suite = collections.defaultdict(float)
    failed, lines = [], []
    n = 0
    for m in re.finditer(r"res://tests/(\S+?)\.gd > (\S+) (PASSED|FAILED|ERROR|SKIPPED)\s+((?:\d+min )?(?:\d+s )?\d+ms)?", txt):
        n += 1
        suite[m.group(1)] += secs(m.group(4))
        if m.group(3) in ("FAILED", "ERROR"):
            failed.append("%s::%s" % (m.group(1), m.group(2)))
    for m in SIM_LINE.finditer(txt):
        lines.append(m.group(0).strip())
    return n, suite, failed, lines


def run_all(a, bins, lock):
    """조각을 띄우고 끝나길 기다린다. 멈춤 요청(STOP 파일·부모 종료)이면 모두 정리하고 None."""
    shards = [start_shard(i, b[1], a) for i, b in enumerate(bins) if b[1]]
    try:
        while any(s["dur"] is None for s in shards):
            time.sleep(2)
            for s in shards:
                if s["dur"] is None and s["p"].poll() is not None:
                    s["dur"] = time.time() - s["t0"]
            if lock.should_stop():
                print("멈춤 요청 — 조각을 모두 끝낸다")
                return None
        return shards
    finally:
        for s in shards:
            if s["p"].poll() is None:
                gdunit_lock.kill_tree(s["p"].pid)
            s["f"].close()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tier", choices=tiers.TIERS, default="full")
    ap.add_argument("--base", default="origin/int/next-m", help="related·sim에서 바뀐 파일을 셀 기준 (git diff base...HEAD)")
    ap.add_argument("--shards", type=int, default=4)
    ap.add_argument("--godot", help="Godot 콘솔 exe (--dry-run이면 없어도 된다)")
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "parallel_gdunit"))
    ap.add_argument("--only", nargs="*", default=[], help="이름에 이 조각이 든 스위트만")
    ap.add_argument("--no-import", action="store_true")
    ap.add_argument("--update-times", action="store_true")
    ap.add_argument("--wait-minutes", type=float, default=0.0, help="잠겨 있으면 이만큼 기다린다")
    ap.add_argument("--lock-file", default=None, help="시험용으로 다른 잠금 파일")
    ap.add_argument("--dry-run", action="store_true", help="고른 스위트와 나누기만 보여 주고 돌리지 않는다 (잠금도 안 본다)")
    a = ap.parse_args()
    if not a.dry_run and not a.godot:
        ap.error("--godot가 필요하다")
    suites = tiers.select(a.tier, ROOT, a.base)
    if a.only:
        suites = [s for s in suites if any(o in s for o in a.only)]
    tpath = os.path.join(HERE, "suite_times.json")
    times = json.load(open(tpath, encoding="utf-8")) if os.path.exists(tpath) else {}
    bins = split(suites, times, a.shards, tiers.load().get("separate", []))
    print("층 %s: 스위트 %d개, 예상 %.0fs (한 줄로 돌리면)" % (a.tier, len(suites), sum(times.get(s, 1.0) for s in suites)))
    if a.dry_run:
        for i, b in enumerate(bins):
            print("조각 %d: 예상 %.0fs, 스위트 %d개 (%s ...)" % (i, b[0], len(b[1]), ", ".join(b[1][:3])))
        print("예상 바닥(가장 긴 조각) %.0fs" % max(b[0] for b in bins))
        return
    os.makedirs(a.out, exist_ok=True)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    if hasattr(signal, "SIGBREAK"):
        signal.signal(signal.SIGBREAK, lambda *_: sys.exit(143))
    lock = gdunit_lock.Lock("parallel_gdunit", "(%s %d조각)" % (a.tier, a.shards), path=a.lock_file,
                            wait_secs=a.wait_minutes * 60)
    t0 = time.time()
    with lock:
        if not a.no_import:
            subprocess.run([a.godot, "--headless", "--path", ROOT, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=ROOT)
        t_imp = time.time() - t0
        res = run_all(a, bins, lock)
    if res is None:
        sys.exit(2)
    wall = time.time() - t0
    total, suite_t, failed, sim_lines = 0, collections.defaultdict(float), [], []
    print("조각 %d개, 스위트 %d개, 가져오기 %.0fs, 전체 %.1f분" % (a.shards, len(suites), t_imp, wall / 60))
    for s in sorted(res, key=lambda s: s["i"]):
        n, st, fl, ln = parse(s["log"])
        total += n
        failed += fl
        sim_lines += ln
        for k, v in st.items():
            suite_t[k] += v
        print("  조각 %d: 스위트 %d (예상 %.0fs) 시험 %d 걸린 %.0fs 종료코드 %d  %s" % (
            s["i"], len(bins[s["i"]][1]), bins[s["i"]][0], n, s["dur"], s["p"].returncode, s["log"]))
    print("시험 %d개 (실패 %d), 시험 시간 합 %.0fs, 결정적 시뮬 줄 %d" % (total, len(failed), sum(suite_t.values()), len(sim_lines)))
    for f in sorted(failed):
        print("  실패:", f)
    for k, v in sorted(suite_t.items(), key=lambda x: -x[1])[:10]:
        print("  %6.1fs %s" % (v, k))
    with open(os.path.join(a.out, "sim_lines.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(sorted(sim_lines)) + "\n")
    if a.update_times and a.tier == "full" and not failed:
        json.dump({k: round(v, 1) for k, v in sorted(suite_t.items())}, open(tpath, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("시간표 갱신:", tpath)
    sys.exit(1 if failed or any(s["p"].returncode for s in res) else 0)


if __name__ == "__main__":
    main()
