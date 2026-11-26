#!/usr/bin/env python3
"""gdUnit 전체 시험을 여러 Godot 프로세스로 나눠 동시에 돌리고 결과를 한 요약으로 합친다.

  python tools/test/parallel_gdunit.py --shards 4 --godot <Godot 콘솔 exe> [--only 이름조각 ...] [--out 폴더]

- 조각 나누기: tests/test_*.gd 묶음(스위트)을 tools/test/suite_times.json의 지난 시간으로 무거운 것부터 가장 한가한 조각에 넣는다 (LPT).
  시간표에 없는 새 스위트는 중간값으로 친다. 한 스위트는 쪼개지 않는다 (가장 긴 시험이 걸리는 시간의 바닥).
- 프로세스마다 사용자 폴더를 따로 쓴다: APPDATA·LOCALAPPDATA를 <out>/shard_N/ 아래로 돌려 user:// 설정·저장 파일이 겹치지 않는다.
  보고서도 조각마다 따로 (-rd). 첫 한 번 --import로 클래스 목록을 맞춘다 (조각들이 같은 .godot 캐시를 동시에 쓰지 않게).
- 규칙: --remote-debug tcp://127.0.0.1:0, 통합 세션과 겹치지 않게 build/gdunit.lock을 지킨다 (잠겨 있으면 멈춘다. --ignore-lock 없음).
  이 도구가 도는 동안 같은 잠금을 쥔다.
- 요약: 조각별 걸린 시간, 전체 시험·실패 수, 스위트별 시간 상위, 실패 목록. --update-times를 주면 시간표를 이번 값으로 고친다.
"""
import argparse, collections, glob, json, os, re, subprocess, sys, time
sys.stdout.reconfigure(encoding="utf-8")
from concurrent.futures import ThreadPoolExecutor

ANSI = re.compile(r"\x1b\[[0-9;]*m")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
LOCK = os.path.join(os.environ.get("HH_MAIN_REPO", r"C:\Haneol-Heroes"), "build", "gdunit.lock")


def secs(s):
    t = 0.0
    for pat, mul in ((r"(\d+)min", 60), (r"(\d+)s\b", 1), (r"(\d+)ms", 0.001)):
        m = re.search(pat, s or "")
        if m:
            t += mul * int(m.group(1))
    return t


def check_lock():
    if os.path.exists(LOCK):
        txt = open(LOCK, encoding="utf-8", errors="replace").read().strip()
        m = re.search(r"until=(\d+)", txt)
        if m and int(m.group(1)) < time.time():
            return  # 기한 지난 잠금
        sys.exit("gdunit.lock이 잠겨 있다: %s\n끝날 때까지 기다린다 (풀리면 다시)." % txt)


def take_lock(shards):
    until = int(time.time()) + 3600
    with open(LOCK, "w", encoding="utf-8") as f:
        f.write("parallel_gdunit (%d조각) %s until=%d\n" % (shards, time.strftime("%Y-%m-%dT%H:%M:%S%z"), until))


def split(suites, times, n):
    known = sorted(times.values())
    mid = known[len(known) // 2] if known else 1.0
    bins = [[0.0, []] for _ in range(n)]
    for s in sorted(suites, key=lambda s: -times.get(s, mid)):
        b = min(bins, key=lambda b: b[0])
        b[0] += times.get(s, mid)
        b[1].append(s)
    return bins


def run_shard(i, names, a):
    d = os.path.join(a.out, "shard_%d" % i)
    for sub in ("roaming", "local", "reports"):
        os.makedirs(os.path.join(d, sub), exist_ok=True)
    env = dict(os.environ, APPDATA=os.path.join(d, "roaming"), LOCALAPPDATA=os.path.join(d, "local"))
    cmd = [a.godot, "--headless", "--path", ROOT, "-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"]
    for n in names:
        cmd += ["-a", "res://tests/%s.gd" % n]
    cmd += ["-c", "--ignoreHeadlessMode", "-rd", os.path.join(d, "reports"), "--remote-debug", "tcp://127.0.0.1:0"]
    log = os.path.join(d, "log.txt")
    t0 = time.time()
    with open(log, "w", encoding="utf-8", errors="replace") as f:
        p = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, env=env, cwd=ROOT)
    return i, time.time() - t0, p.returncode, log


def parse(log):
    txt = ANSI.sub("", open(log, encoding="utf-8", errors="replace").read())
    suite = collections.defaultdict(float)
    failed = []
    n = 0
    for m in re.finditer(r"res://tests/(\S+?)\.gd > (\S+) (PASSED|FAILED|ERROR|SKIPPED)\s+((?:\d+min )?(?:\d+s )?\d+ms)?", txt):
        n += 1
        suite[m.group(1)] += secs(m.group(4))
        if m.group(3) in ("FAILED", "ERROR"):
            failed.append("%s::%s" % (m.group(1), m.group(2)))
    return n, suite, failed


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shards", type=int, default=4)
    ap.add_argument("--godot", required=True)
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "parallel_gdunit"))
    ap.add_argument("--only", nargs="*", default=[], help="이름에 이 조각이 든 스위트만")
    ap.add_argument("--no-import", action="store_true")
    ap.add_argument("--update-times", action="store_true")
    ap.add_argument("--dry-run", action="store_true", help="나누기만 보여 주고 돌리지 않는다 (잠금도 안 본다)")
    a = ap.parse_args()
    if not a.dry_run:
        check_lock()
    suites = sorted(os.path.basename(p)[:-3] for p in glob.glob(os.path.join(ROOT, "tests", "test_*.gd")))
    if a.only:
        suites = [s for s in suites if any(o in s for o in a.only)]
    tpath = os.path.join(HERE, "suite_times.json")
    times = json.load(open(tpath, encoding="utf-8")) if os.path.exists(tpath) else {}
    bins = split(suites, times, a.shards)
    if a.dry_run:
        for i, b in enumerate(bins):
            print("조각 %d: 예상 %.0fs, 스위트 %d개 (%s ...)" % (i, b[0], len(b[1]), ", ".join(b[1][:3])))
        print("예상 바닥(가장 긴 조각) %.0fs" % max(b[0] for b in bins))
        return
    os.makedirs(a.out, exist_ok=True)
    take_lock(a.shards)
    t0 = time.time()
    try:
        if not a.no_import:
            subprocess.run([a.godot, "--headless", "--path", ROOT, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=ROOT)
        t_imp = time.time() - t0
        with ThreadPoolExecutor(a.shards) as ex:
            futs = [ex.submit(run_shard, i, b[1], a) for i, b in enumerate(bins) if b[1]]
            res = [f.result() for f in futs]
    finally:
        try:
            os.remove(LOCK)
        except OSError:
            pass
    wall = time.time() - t0
    total, suite_t, failed = 0, collections.defaultdict(float), []
    print("조각 %d개, 스위트 %d개, 가져오기 %.0fs, 전체 %.1f분" % (a.shards, len(suites), t_imp, wall / 60))
    for i, dur, rc, log in sorted(res):
        n, st, fl = parse(log)
        total += n
        failed += fl
        for k, v in st.items():
            suite_t[k] += v
        print("  조각 %d: 스위트 %d (예상 %.0fs) 시험 %d 걸린 %.0fs 종료코드 %d  %s" % (i, len(bins[i][1]), bins[i][0], n, dur, rc, log))
    print("시험 %d개 (실패 %d), 시험 시간 합 %.0fs" % (total, len(failed), sum(suite_t.values())))
    for f in failed:
        print("  실패:", f)
    for k, v in sorted(suite_t.items(), key=lambda x: -x[1])[:10]:
        print("  %6.1fs %s" % (v, k))
    if a.update_times and not failed:
        json.dump({k: round(v, 1) for k, v in sorted(suite_t.items())}, open(tpath, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("시간표 갱신:", tpath)
    sys.exit(1 if failed or any(r[2] for r in res) else 0)


if __name__ == "__main__":
    main()
