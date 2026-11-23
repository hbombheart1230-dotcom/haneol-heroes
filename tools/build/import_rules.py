"""폴더별 그림 가져오기 압축 규칙을 .png.import 에 적용한다 (APK 용량, docs/research/apk_size.md).

  python tools/build/import_rules.py          적용 (바뀐 파일 수 출력)
  python tools/build/import_rules.py --check  바꿀 것이 있으면 목록을 찍고 1로 끝남

규칙: tools/build/import_rules.json (tests/test_import_rules.gd 도 같은 파일을 읽는다).
새 그림은 Godot 이 기본값(무손실)으로 .import 를 만들므로, 그림을 넣고 한 번 가져온 뒤 이것을 돌린다.
적용 뒤 Godot 이 다시 가져온다 (godot --headless --path . --import).
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RULES = os.path.join(os.path.dirname(__file__), "import_rules.json")


def load_rules() -> list:
    with open(RULES, encoding="utf-8-sig") as f:
        return json.load(f)["rules"]


def wanted(rule: dict) -> dict:
    return {"compress/mode": str(rule["mode"]), "compress/lossy_quality": str(rule["lossy_quality"])}


def apply_text(text: str, want: dict) -> str:
    for key, val in want.items():
        pat = re.compile(rf"^{re.escape(key)}=.*$", re.M)
        text = pat.sub(f"{key}={val}", text) if pat.search(text) else text.replace("[params]\n", f"[params]\n\n{key}={val}", 1)
    return text


def plan(root: str = ROOT) -> list:
    """(파일, 새 내용) 목록 — 바뀌는 것만."""
    out = []
    for rule in load_rules():
        for p in sorted(glob.glob(os.path.join(root, rule["dir"], "**", "*.png.import"), recursive=True)):
            with open(p, encoding="utf-8") as f:
                old = f.read()
            if 'importer="texture"' not in old:
                continue
            new = apply_text(old, wanted(rule))
            if new != old:
                out.append((p, new))
    return out


def main(argv: list) -> int:
    changes = plan()
    if "--check" in argv:
        for p, _ in changes:
            print(os.path.relpath(p, ROOT))
        return 1 if changes else 0
    for p, new in changes:
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(new)
    print(f"{len(changes)} 파일 바꿈")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
