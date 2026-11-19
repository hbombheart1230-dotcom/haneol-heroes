"""Meshy REST API 최소 클라이언트 (파이썬 표준 라이브러리만 사용).

키는 환경 변수 MESHY_API_KEY 또는 저장소 루트 .env(깃 제외)에서 읽는다. 로그·명령줄·상태 파일에 남기지 않는다.
문서: https://docs.meshy.ai/en/api  (image-to-3d, rigging, animations)
"""
import base64
import json
import mimetypes
import os
import time
import urllib.error
import urllib.request

BASE = "https://api.meshy.ai/openapi/v1"
TERMINAL = ("SUCCEEDED", "FAILED", "CANCELED")


class MeshyError(RuntimeError):
    pass


## 저장소 루트의 .env (깃에 올리지 않는다, .gitignore). 환경 변수가 있으면 그쪽이 우선.
ENV_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".env")


def read_env_file(path: str = ENV_FILE) -> dict:
    """KEY=VALUE 줄만 읽는다 (# 주석, 빈 줄, 따옴표 허용). 파일이 없으면 빈 사전."""
    out = {}
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def api_key(env_path: str = ENV_FILE) -> str:
    key = os.environ.get("MESHY_API_KEY", "").strip() or read_env_file(env_path).get("MESHY_API_KEY", "")
    if not key:
        raise MeshyError(
            "MESHY_API_KEY가 없습니다. 저장소 루트의 .env 파일에 MESHY_API_KEY=발급받은_키 를 적으세요 "
            "(.env는 깃에 올라가지 않습니다).")
    return key


def _request(method: str, path: str, body: dict | None = None) -> object:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + api_key())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=120) as res:
            return json.loads(res.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:500]
        raise MeshyError(f"{method} {path} -> HTTP {e.code}: {detail}") from None


def data_uri(path: str) -> str:
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode()


def create(kind: str, body: dict) -> str:
    """kind = image-to-3d | rigging | animations. 새 작업 id를 돌려준다."""
    res = _request("POST", "/" + kind, body)
    task_id = res.get("result") if isinstance(res, dict) else None
    if not task_id:
        raise MeshyError(f"{kind} 작업 생성 응답에 id가 없습니다: {res}")
    return task_id


def get(kind: str, task_id: str) -> dict:
    return _request("GET", f"/{kind}/{task_id}")


def wait(kind: str, task_id: str, poll: float = 10.0, timeout: float = 3600.0) -> dict:
    """작업이 끝날 때까지 기다린다. 실패하면 MeshyError."""
    start = time.time()
    last = -1
    while True:
        task = get(kind, task_id)
        status = task.get("status")
        progress = task.get("progress", 0)
        if progress != last:
            print(f"  [{kind}] {status} {progress}%", flush=True)
            last = progress
        if status in TERMINAL:
            if status != "SUCCEEDED":
                raise MeshyError(f"{kind} {task_id} {status}: {task.get('task_error')}")
            return task
        if time.time() - start > timeout:
            raise MeshyError(f"{kind} {task_id} 시간 초과")
        time.sleep(poll)


def library(search: str = "", category: str = "") -> list:
    """동작 라이브러리 (무료 조회). 응답은 배열 그대로."""
    query = []
    if search:
        query.append("search=" + urllib.request.quote(search))
    if category:
        query.append("category=" + urllib.request.quote(category))
    path = "/animations/library" + ("?" + "&".join(query) if query else "")
    res = _request("GET", path)
    return res if isinstance(res, list) else res.get("result", [])


def download(url: str, dest: str) -> None:
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as res, open(dest, "wb") as f:
        f.write(res.read())
    print(f"  저장 {dest} ({os.path.getsize(dest) // 1024} KiB)", flush=True)
