"""기준 그림 → Meshy 3D 생성 → 자동 뼈대 → 동작 → Godot 스프라이트 굽기 → 영웅 데이터 교체.

사용 (저장소 루트에서):
  python tools/ai3d/meshy_pipeline.py actions [검색어]          # 동작 라이브러리 조회 (무료)
  python tools/ai3d/meshy_pipeline.py plan tools/ai3d/heroes/yi_sun_sin.json   # 할 일·예상 크레딧만 표시
  python tools/ai3d/meshy_pipeline.py run  tools/ai3d/heroes/yi_sun_sin.json --yes

- 진행 상태는 assets/models/meshy/<name>/state.json에 남겨 중간에 끊겨도 이어서 한다
  (이미 성공한 유료 작업은 다시 요청하지 않는다). 처음부터 다시: --restart <단계>(model|rig|anim).
- 키는 MESHY_API_KEY 환경 변수에서만 읽는다.
- 굽기는 GPU가 필요해 창 모드 Godot을 잠깐 띄운다. Godot 경로: --godot 또는 GODOT_BIN.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshy_api as api  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
STAGES = ("model", "rig", "anim")
# 크레딧 대략값 (https://docs.meshy.ai/en/api/pricing, 2026-11 기준). 실제 차감은 Meshy 대시보드가 정본.
COST = {"model": 30, "rig": 5, "anim_each": 3}


def rel(path: str) -> str:
    return os.path.join(ROOT, path)


def load_state(out_dir: str) -> dict:
    path = os.path.join(out_dir, "state.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_state(out_dir: str, state: dict) -> None:
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "state.json"), "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def resolve_actions(cfg: dict) -> list:
    """설정의 동작마다 라이브러리 항목 하나를 고른다 (action_id 지정 > 검색 첫 결과)."""
    picked = []
    everything = api.library() if any("action_id" in a for a in cfg["anims"]) else []
    for anim in cfg["anims"]:
        if "action_id" in anim:
            entry = next((e for e in everything if e.get("action_id") == anim["action_id"]), None)
        else:
            hits = api.library(search=anim["search"])
            entry = hits[0] if hits else None
        if entry is None:
            raise api.MeshyError(f"동작을 찾지 못했습니다: {anim}. 'actions' 명령으로 골라 action_id를 넣으세요.")
        picked.append({"key": anim["key"], "action_id": entry["action_id"], "name": entry["name"]})
    return picked


def stage_model(cfg: dict, state: dict) -> None:
    body = dict(cfg.get("image_to_3d", {}))
    body["image_url"] = api.data_uri(rel(cfg["image"]))
    print("1/3 이미지 → 3D 생성")
    state["model_task"] = api.create("image-to-3d", body)
    task = api.wait("image-to-3d", state["model_task"])
    state["model_glb_url"] = task.get("model_urls", {}).get("glb", "")


def stage_rig(cfg: dict, state: dict) -> None:
    print("2/3 자동 뼈대")
    state["rig_task"] = api.create("rigging", {
        "input_task_id": state["model_task"], "height_meters": cfg.get("height_meters", 1.7)})
    task = api.wait("rigging", state["rig_task"])
    state["rigged_glb_url"] = (task.get("result") or {}).get("rigged_character_glb_url", "")


def stage_anim(cfg: dict, state: dict) -> None:
    print("3/3 동작 입히기")
    state["actions"] = resolve_actions(cfg)
    for a in state["actions"]:
        print(f"  {a['key']:7s} ← #{a['action_id']} {a['name']}")
    state["anim_task"] = api.create("animations", {
        "rig_task_id": state["rig_task"],
        "action_ids": [a["action_id"] for a in state["actions"]],
        "post_process": {"operation_type": "change_fps", "fps": 30}})
    task = api.wait("animations", state["anim_task"])
    state["anim_glb_url"] = (task.get("result") or {}).get("animation_glb_url", "")


def download_all(state: dict, out_dir: str) -> None:
    for key, file in (("model_glb_url", "model.glb"), ("rigged_glb_url", "rigged.glb"),
                      ("anim_glb_url", "animated.glb")):
        dest = os.path.join(out_dir, file)
        if state.get(key) and not os.path.exists(dest):
            api.download(state[key], dest)


def write_bake_job(cfg: dict, state: dict) -> str:
    """tools/bake/jobs/<name>.json — bake_sprites.gd가 읽는 굽기 설정."""
    names = {a["key"]: a["name"] for a in state["actions"]}
    job = {
        "name": cfg["name"],
        "model": f"res://assets/models/meshy/{cfg['name']}/animated.glb",
        "ortho_size": cfg["bake"]["ortho_size"], "frame": cfg["bake"]["frame"],
        "anims": [{"key": a["key"], "src": names[a["key"]], "frames": a["frames"],
                   "fps": a["fps"], "loop": a["loop"]} for a in cfg["anims"]],
    }
    path = rel(f"tools/bake/jobs/{cfg['name']}.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(job, f, ensure_ascii=False, indent=2)
    return path


def find_godot(arg: str) -> str:
    if arg:
        return arg
    if os.environ.get("GODOT_BIN"):
        return os.environ["GODOT_BIN"]
    pattern = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\*Godot*\Godot_v4*_console.exe")
    hits = sorted(glob.glob(pattern))
    if not hits:
        raise SystemExit("Godot을 찾지 못했습니다. --godot 경로를 주세요.")
    return hits[-1]


def bake(godot: str, name: str) -> None:
    print("Godot 가져오기(import) → 스프라이트 굽기")
    subprocess.run([godot, "--headless", "--path", ROOT, "--import"], check=False)
    subprocess.run([godot, "--path", ROOT, "-s", "res://tools/bake/bake_sprites.gd", "--", f"--only={name}"],
                   check=True)
    subprocess.run([godot, "--headless", "--path", ROOT, "--import"], check=False)


def apply_to_hero(cfg: dict) -> None:
    """영웅 데이터의 sprite_sheet 경로를 새로 구운 시트로 바꾼다."""
    path = rel(cfg["hero_data"])
    with open(path, encoding="utf-8") as f:
        text = f.read()
    new_sheet = f"res://assets/sprites/{cfg['name']}/{cfg['name']}.tres"
    m = re.search(r'sprite_sheet = ExtResource\("([^"]+)"\)', text)
    if not m:
        raise SystemExit(f"{path}에 sprite_sheet가 없습니다.")
    pat = r'(\[ext_resource type="Resource" )(?:uid="[^"]*" )?path="[^"]*"( id="%s"\])' % re.escape(m.group(1))
    text, n = re.subn(pat, r'\1path="%s"\2' % new_sheet, text)
    if n != 1:
        raise SystemExit("sprite_sheet ext_resource 줄을 찾지 못했습니다.")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"{cfg['hero_data']} sprite_sheet → {new_sheet}")


def plan(cfg: dict, state: dict) -> int:
    todo = [s for s in STAGES if not state.get(f"{s}_done")]
    credits = sum(COST["anim_each"] * len(cfg["anims"]) if s == "anim" else COST[s] for s in todo)
    print(f"[{cfg['name']}] 남은 단계: {', '.join(todo) or '없음 (굽기만)'} / 예상 약 {credits} 크레딧")
    return credits


def run(cfg: dict, args: argparse.Namespace) -> None:
    out_dir = rel(f"assets/models/meshy/{cfg['name']}")
    state = load_state(out_dir)
    if args.restart:
        for s in STAGES[STAGES.index(args.restart):]:
            state.pop(f"{s}_done", None)
    if plan(cfg, state) > 0 and not args.yes:
        raise SystemExit("유료 작업입니다. 확인했으면 --yes를 붙여 다시 실행하세요.")
    for s, fn in zip(STAGES, (stage_model, stage_rig, stage_anim)):
        if not state.get(f"{s}_done"):
            fn(cfg, state)
            state[f"{s}_done"] = True
            save_state(out_dir, state)
    download_all(state, out_dir)
    save_state(out_dir, state)
    print("굽기 설정:", write_bake_job(cfg, state))
    if not args.no_bake:
        bake(find_godot(args.godot), cfg["name"])
        apply_to_hero(cfg)
    print("완료")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=("actions", "plan", "run"))
    p.add_argument("target", nargs="?", default="", help="설정 JSON (plan/run) 또는 검색어 (actions)")
    p.add_argument("--yes", action="store_true", help="유료 작업 진행 확인")
    p.add_argument("--restart", choices=STAGES, help="이 단계부터 다시 요청")
    p.add_argument("--no-bake", action="store_true", help="다운로드까지만")
    p.add_argument("--godot", default="", help="Godot 콘솔 실행 파일")
    args = p.parse_args()
    try:
        if args.command == "actions":
            for e in api.library(search=args.target):
                print(f"#{e['action_id']:4d} {e['name']:32s} {e.get('category', '')}/{e.get('sub_category', '')}")
            return
        with open(args.target, encoding="utf-8") as f:
            cfg = json.load(f)
        if args.command == "plan":
            plan(cfg, load_state(rel(f"assets/models/meshy/{cfg['name']}")))
        else:
            run(cfg, args)
    except api.MeshyError as e:
        raise SystemExit(f"오류: {e}")


if __name__ == "__main__":
    main()
