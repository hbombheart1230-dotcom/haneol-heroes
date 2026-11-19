"""웹에서 받은 .glb 가져오기 (무료 플랜): 파일·동작 이름 맞추기, 굽기 설정 쓰기."""
import json
import os
import re
import shutil

def name_words(text: str) -> list:
    """이름을 단어로 나눈다: 기호·숫자 경계와 낙타 표기 (HitReaction → hit, reaction)."""
    spaced = re.sub(r"([a-z])([A-Z])", r"\1 \2", text)
    return [w for w in re.split(r"[^A-Za-z]+", spaced.lower()) if w]


def name_matches(text: str, cand: str) -> bool:
    """후보가 어떤 단어의 앞부분이면 일치 (run → Running, soldier는 die와 불일치)."""
    return any(w.startswith(cand.lower()) for w in name_words(text))


def import_files(cfg: dict, files: list, root: str) -> str:
    """웹에서 받은 .glb들을 모델 폴더로 복사하고 굽기 설정을 쓴다.
    파일 하나 = 모든 동작이 든 파일. 여러 개 = 동작별 파일 (파일 이름에 match 후보가 들어 있으면 그 동작)."""
    name = cfg["name"]
    out_dir = os.path.join(root, f"assets/models/meshy/{name}")
    os.makedirs(out_dir, exist_ok=True)
    res = []
    for src in files:
        if not src.lower().endswith(".glb"):
            raise SystemExit(f".glb 파일만 받습니다: {src}")
        base = re.sub(r"[^A-Za-z0-9_.-]", "_", os.path.basename(src))
        stem, n = base[:-4], 2
        while f"res://assets/models/meshy/{name}/{base}" in res:  # 이름 정리 후 겹치면 번호를 붙인다
            base = f"{stem}_{n}.glb"
            n += 1
        shutil.copyfile(src, os.path.join(out_dir, base))
        res.append(f"res://assets/models/meshy/{name}/{base}")

    def file_for(match: str) -> str:
        for cand in match.lower().split("|"):
            for r in res:
                if name_matches(os.path.basename(r)[:-4], cand):
                    return r
        return ""

    model = file_for(cfg["anims"][0]["match"]) or res[0]
    anims = []
    for a in cfg["anims"]:
        entry = {"key": a["key"], "src": a["match"], "frames": a["frames"], "fps": a["fps"], "loop": a["loop"]}
        if len(res) > 1:
            src_file = file_for(a["match"])
            if not src_file:
                print(f"  경고: '{a['key']}' 동작 파일을 찾지 못해 건너뜁니다 (파일 이름에 {a['match']} 중 하나 필요)")
                continue
            if src_file != model:
                entry["from"] = src_file
        anims.append(entry)
    job = {"name": name, "model": model, "ortho_size": cfg["bake"]["ortho_size"],
           "frame": cfg["bake"]["frame"], "anims": anims}
    path = os.path.join(root, f"tools/bake/jobs/{name}.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(job, f, ensure_ascii=False, indent=2)
    return path
