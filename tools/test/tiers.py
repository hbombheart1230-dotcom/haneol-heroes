"""시험 층: 어떤 스위트를 돌릴지 고른다 (tools/test/tiers.json + 바뀐 파일).

 fast    그림·글·UI·조작 안내를 고칠 때 (몇 분 안)
 related 바뀐 파일 기준 + fast (git diff로 바뀐 파일 이름·class_name이 나오는 스위트)
 sim     전투 수치·적 행동을 고칠 때: 느린 시뮬 묶음 + related
 full    전부 (베타·출시 후보)
"""
import glob, json, os, re, subprocess


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()

HERE = os.path.dirname(os.path.abspath(__file__))
TIERS = ("fast", "related", "sim", "full")


def all_suites(root):
    return sorted(os.path.basename(p)[:-3] for p in glob.glob(os.path.join(root, "tests", "test_*.gd")))


def load(path=None):
    return json.loads(_read(path or os.path.join(HERE, "tiers.json")))


def changed_files(root, base):
    """base 이후 커밋 + 아직 커밋 안 한 파일 (이름만)."""
    out = set()
    for cmd in (["git", "diff", "--name-only", "%s...HEAD" % base], ["git", "diff", "--name-only", "HEAD"],
                ["git", "ls-files", "--others", "--exclude-standard"]):
        r = subprocess.run(cmd, cwd=root, capture_output=True, text=True, encoding="utf-8")
        out.update(l.strip() for l in r.stdout.splitlines() if l.strip())
    return sorted(out)


def stems(root, files):
    """바뀐 파일마다 찾을 낱말: 파일 이름(확장자 뺌), .gd의 class_name."""
    words = set()
    for f in files:
        if f.startswith("tools/") or f.endswith((".md", ".uid", ".import", ".png", ".jpg", ".json")):
            continue
        base = os.path.splitext(os.path.basename(f))[0]
        if len(base) >= 4:
            words.add(base)
        if f.endswith(".gd"):
            try:
                m = re.search(r"^class_name\s+(\w+)", _read(os.path.join(root, f)), re.M)
            except OSError:
                m = None
            if m:
                words.add(m.group(1))
    return words


def related(root, files, suites):
    words = stems(root, files)
    hit = set()
    for s in suites:
        if "tests/%s.gd" % s in files:
            hit.add(s)  # 시험 자체를 고쳤다
            continue
        src = _read(os.path.join(root, "tests", s + ".gd"))
        if any(re.search(r"\b%s\b" % re.escape(w), src) for w in words):
            hit.add(s)
    return sorted(hit)


def select(tier, root, base="origin/int/next-m", tiers=None):
    suites = all_suites(root)
    t = tiers or load()
    if tier == "full":
        return suites
    if tier == "fast":
        return [s for s in suites if s in t["fast"]]
    rel = related(root, changed_files(root, base), suites)
    picked = set(t["fast"]) | set(rel)
    if tier == "sim":
        picked |= set(t["sim"])
    return [s for s in suites if s in picked]
