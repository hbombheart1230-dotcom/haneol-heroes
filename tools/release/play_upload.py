"""Google Play 업로드 (공식 androidpublisher v3: edits.insert → bundles.upload → tracks.update → edits.commit).

열쇠(서비스 계정 JSON)는 저장소 밖에만 둔다: --key 또는 환경 변수 HANEOL_PLAY_KEY,
없으면 %USERPROFILE%\\.haneol-keys\\play-uploader.json. 열쇠 내용·토큰은 어디에도 찍지 않는다.
JWT 서명은 JDK(JwtSign.java)로 한다 — 새 파이썬 패키지 없이 (키는 표준 입력으로만 넘김).

  읽기만:   python tools/release/play_upload.py --check
  올리기:   python tools/release/play_upload.py --aab build/release/x.aab --notes tools/release/notes/0.4.1-ko.txt
            (기본 트랙 alpha, status draft, 커밋은 --commit 을 줄 때만. 커밋은 changesNotSentForReview=true)
출시(rollout)·검토 전송·프로덕션·스토어 등록정보·테스터는 건드리지 않는다.
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import requests

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
HERE = Path(__file__).resolve().parent


def _b64(d: bytes) -> str:
    return base64.urlsafe_b64encode(d).rstrip(b"=").decode("ascii")


def _java() -> str:
    jh = os.environ.get("JAVA_HOME") or str(Path(os.environ["LOCALAPPDATA"]) / "Programs/Temurin/jdk-17.0.21+9")
    return str(Path(jh) / "bin" / "java.exe")


def key_path(arg: str | None) -> Path:
    p = arg or os.environ.get("HANEOL_PLAY_KEY") or str(Path(os.environ["USERPROFILE"]) / ".haneol-keys/play-uploader.json")
    return Path(p)


def access_token(key_file: Path) -> str:
    info = json.loads(key_file.read_text(encoding="utf-8"))
    now = int(time.time())
    head = _b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    body = _b64(json.dumps({"iss": info["client_email"], "scope": SCOPE, "aud": info["token_uri"],
                            "iat": now, "exp": now + 3000}).encode())
    data = f"{head}.{body}"
    sig = subprocess.run([_java(), str(HERE / "JwtSign.java")], input=data + "\n" + info["private_key"],
                         capture_output=True, text=True, check=True).stdout.strip()
    r = requests.post(info["token_uri"], data={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": f"{data}.{sig}"}, timeout=60)
    if r.status_code != 200:
        sys.exit(f"토큰 실패 {r.status_code}: {_err(r)}")
    return r.json()["access_token"]


def _err(r: requests.Response) -> str:
    try:
        e = r.json().get("error", {})
        return f"{e.get('status', '')} {e.get('message', '')}".strip() if isinstance(e, dict) else str(e)
    except ValueError:
        return r.text[:300]


class Edit:
    def __init__(self, token: str, package: str):
        self.h = {"Authorization": f"Bearer {token}"}
        self.pkg = package
        r = requests.post(f"{API}/{package}/edits", headers=self.h, timeout=60)
        if r.status_code != 200:
            sys.exit(f"edits.insert 실패 {r.status_code}: {_err(r)}")
        self.id = r.json()["id"]

    def url(self, tail: str = "") -> str:
        return f"{API}/{self.pkg}/edits/{self.id}{tail}"

    def get_track(self, track: str) -> dict:
        r = requests.get(self.url(f"/tracks/{track}"), headers=self.h, timeout=60)
        if r.status_code == 404:
            return {}
        if r.status_code != 200:
            sys.exit(f"tracks.get 실패 {r.status_code}: {_err(r)}")
        return r.json()

    def delete(self) -> None:
        requests.delete(self.url(), headers=self.h, timeout=60)

    def upload_bundle(self, aab: Path) -> int:
        with aab.open("rb") as f:
            r = requests.post(f"{UPLOAD}/{self.pkg}/edits/{self.id}/bundles", params={"uploadType": "media"},
                              headers={**self.h, "Content-Type": "application/octet-stream"}, data=f, timeout=1800)
        if r.status_code != 200:
            self.delete()
            sys.exit(f"bundles.upload 실패 {r.status_code}: {_err(r)}")
        return int(r.json()["versionCode"])

    def set_draft(self, track: str, code: int, notes: str, lang: str, status: str = "draft") -> dict:
        body = {"track": track, "releases": [{"versionCodes": [str(code)], "status": status,
                                              "releaseNotes": [{"language": lang, "text": notes}]}]}
        r = requests.put(self.url(f"/tracks/{track}"), headers=self.h, json=body, timeout=60)
        if r.status_code != 200:
            self.delete()
            sys.exit(f"tracks.update 실패 {r.status_code}: {_err(r)}")
        return r.json()

    def commit(self, send_review: bool = False) -> dict:
        params = {} if send_review else {"changesNotSentForReview": "true"}
        r = requests.post(self.url(":commit"), headers=self.h, params=params, timeout=120)
        if r.status_code != 200:
            self.delete()
            sys.exit(f"edits.commit 실패 {r.status_code}: {_err(r)} (편집은 지움, 올라간 것 없음)")
        return r.json()


def summarize(track: dict) -> str:
    rel = track.get("releases", [])
    if not rel:
        return "(출시 없음)"
    return "; ".join(f"{x.get('name', '')} status={x.get('status')} codes={x.get('versionCodes', [])}" for x in rel)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--key")
    ap.add_argument("--package", default="com.haneol.heroes")
    ap.add_argument("--track", default="alpha")
    ap.add_argument("--check", action="store_true", help="읽기만: 편집 열고 트랙 읽고 편집 지움")
    ap.add_argument("--aab")
    ap.add_argument("--notes", help="출시 노트 파일 (UTF-8)")
    ap.add_argument("--lang", default="ko-KR")
    ap.add_argument("--commit", action="store_true", help="주지 않으면 편집을 지우고 끝 (아무것도 안 올라감)")
    ap.add_argument("--release", action="store_true",
                    help="--commit과 함께: 초안이 아니라 완료(completed)로 두고 검토로 보낸다 (자동 검토 전송 앱은 이것만 받는다)")
    a = ap.parse_args()
    kp = key_path(a.key)
    if not kp.is_file():
        sys.exit(f"열쇠 파일이 없습니다: {kp}")
    if a.track in ("production", "internal"):
        sys.exit("이 스크립트는 비공개 테스트 트랙만 다룬다")
    edit = Edit(access_token(kp), a.package)
    try:
        print(f"[play] {a.package} {a.track} 지금: {summarize(edit.get_track(a.track))}")
        if a.check:
            return
        notes = Path(a.notes).read_text(encoding="utf-8").strip()
        if len(notes) > 500:
            sys.exit(f"출시 노트가 500자를 넘습니다 ({len(notes)})")
        code = edit.upload_bundle(Path(a.aab))
        print(f"[play] 올림: versionCode {code}")
        status = "completed" if a.release else "draft"
        print(f"[play] {status}로 둠: {summarize(edit.set_draft(a.track, code, notes, a.lang, status))}")
        if not a.commit:
            print("[play] --commit 없음: 편집을 지움 (아무것도 반영 안 됨)")
            return
        edit.commit(send_review=a.release)
        edit.id = ""
        print("[play] 커밋함 (검토로 보냄: 통과하면 테스터에게 나감)" if a.release else "[play] 커밋함 (검토 전송 안 함, 콘솔에서 직접 검토 전송)")
    finally:
        if edit.id and (a.check or not a.commit):
            edit.delete()


if __name__ == "__main__":
    main()
