# 개인정보처리방침 초안 — 한얼: 영웅들

> 초안 (2026-11-24, 버전 0.4.0 기준). 연락처는 사용자 결정 (2026-11-24). 공개 주소에 올리는 것은 사용자가 정한다 (아래 "올릴 곳 후보").

## 한국어

**한얼: 영웅들 개인정보처리방침**

시행일: [시행일]

「한얼: 영웅들」(이하 "게임")은 이용자의 개인정보를 수집하지 않습니다.

1. **수집하는 정보:** 없습니다. 게임에는 회원 가입, 로그인, 광고, 분석 도구, 결제 기능이 없습니다. 인터넷 연결도 쓰지 않습니다.
2. **기기에 저장하는 정보:** 게임 설정(소리 크기, 진동, 이야기 보기 등)과 진행 기록(고른 영웅, 이긴 전장, 전장별 최고 기록)만 이용자의 기기 안 게임 전용 저장 공간에 저장합니다. 이 정보는 기기 밖으로 전송되지 않고, 개발자도 볼 수 없습니다. 앱을 지우면 함께 지워집니다.
3. **제3자 제공:** 없습니다.
4. **권한:** 타격 진동을 위한 진동 권한만 사용합니다.
5. **아동:** 게임은 만 13세 이상을 대상으로 하며, 아동의 정보를 따로 수집하지 않습니다.
6. **변경:** 방침이 바뀌면 이 페이지에 시행일과 함께 알립니다.
7. **문의:** hbombheart1230@gmail.com

## English

**Haneol: Heroes — Privacy Policy**

Effective date: [effective date]

Haneol: Heroes ("the game") does not collect any personal information.

1. **Information collected:** None. The game has no account, sign-in, ads, analytics or payments, and does not use the internet.
2. **Stored on your device:** Only game settings (volume, vibration, story on/off and similar) and progress (chosen hero, cleared battlefields, best records). They are kept in the game's private storage on your device, never sent anywhere, and are not visible to the developer. Uninstalling the game deletes them.
3. **Sharing with third parties:** None.
4. **Permissions:** Vibration only, for hit feedback.
5. **Children:** The game is intended for ages 13 and up and does not knowingly collect information from children.
6. **Changes:** Any change will be posted on this page with a new effective date.
7. **Contact:** hbombheart1230@gmail.com

---

## 근거 (`art/enemy-rebake` 37d9a7f 기준)

- **네트워크:** 게임 코드와 플러그인(`scripts/`, `addons/health_hitbox_hurtbox/`)에 HTTPRequest·HTTPClient·소켓·WebSocket·멀티플레이·광고·분석 SDK가 없다. gdUnit4는 시험 전용이고 내보내기에서 빠진다(`exclude_filter`).
- **권한:**
  - 내보내기 설정 두 개(APK·AAB) 모두 `permissions/vibrate=true`만 켜져 있다.
  - 실제 APK(`haneol-heroes-release.apk`, 11-22)를 `aapt2 dump permissions`로 읽으면 `android.permission.VIBRATE` 하나뿐이고, INTERNET은 없다.
- **저장:**
  - `user://settings.cfg` 하나(`GameSettings`, 엔진 ConfigFile)에 다음 값을 저장한다.
  - 설정: 효과음·음악 크기, 진동, 노랫소리, 이야기, 기술 단추, 적 체력, 연타 글씨, 개발 수치, 조작 안내
  - 진행: 고른 영웅·전장, 본 이야기, 이긴 전장, 난이도 단계, 전장별 기록
- **기기 밖으로 나가는 데이터:** 없다. 판이 끝날 때 성능 한 줄(`[HH perf]`)을 기기 로그(logcat)에 남기지만, 이것도 기기 밖으로 보내지 않는다.

## 올릴 곳 후보 (올리지 않음)

저장소 `hbombheart1230-dotcom/haneol-heroes`는 **공개(PUBLIC)**라 GitHub Pages를 쓸 수 있다.

| 후보 | 장점 | 단점 |
|---|---|---|
| GitHub Pages (이 저장소 `docs/`) | 저장소 파일 그대로, 고치면 바로 반영, 무료 | 저장소 Pages 설정을 켜야 함, 주소에 GitHub 계정 이름이 드러남 |
| GitHub Pages (방침만 담은 새 공개 저장소) | 게임 저장소와 분리, 저장소를 나중에 비공개로 바꿔도 방침 주소가 살아 있음 | 저장소 하나 더 관리 |
| Google Sites | Play Console과 같은 구글 계정, 코드 없이 편집 | 손으로 옮겨 적어야 하고 저장소와 따로 놂 |
| GitHub 파일 보기 주소 (`blob/.../privacy_policy.md`) | 설정 필요 없음 | 저장소가 비공개가 되면 바로 깨짐, 공식 웹페이지로 보기엔 어색함 |
