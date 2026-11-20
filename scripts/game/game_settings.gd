class_name GameSettings
extends RefCounted
## 플레이어 설정 저장 (엔진 기본 ConfigFile, user://settings.cfg).

const PATH := "user://settings.cfg"
## 실제로 읽고 쓰는 파일 (테스트는 다른 파일로 바꿔 실제 설정을 건드리지 않는다).
static var settings_path: String = PATH


## 테스트 전용 설정 파일: 실행(프로세스)마다 다른 파일이라, 다른 실행이 남긴 파일을 읽지 않는다
## (저장 폴더에 쓸 수 없는 검증 환경에서 이전 실행의 설정이 섞이던 문제).
static func test_path() -> String:
	return "user://test_settings_%d.cfg" % OS.get_process_id()
const SECTION := "controls"

## 스킬 버튼 표시·사용. 기본은 끔 (한 손 제스처가 기본 조작).
static var skill_button_enabled: bool = false
## 설정 화면: 효과음·음악 크기 (0~1), 타격 진동, 이야기 보기.
static var sfx_volume: float = 0.8
static var music_volume: float = 0.8
static var haptics_enabled: bool = true
static var story_enabled: bool = true
## 마지막으로 고른 영웅 id (재시작 때 그대로).
static var hero_id: StringName = &""
## 이번 실행에서 영웅을 이미 골랐는지 (앱을 새로 켜면 고르기 화면부터).
static var hero_picked: bool = false
## 이번 실행에서 인트로를 지나갔는지.
static var title_seen: bool = false
## 이야기 인트로를 한 번 봤는지 (저장). 처음 입장할 때만 나온다.
static var intro_seen: bool = false
## 이야기를 이미 본 영웅 id들 (영웅 이야기는 영웅마다 처음 한 번).
static var seen_stories: PackedStringArray = PackedStringArray()
## 마지막으로 고른 무대 id, 이번 실행에서 무대를 골랐는지.
static var stage_id: StringName = &""
static var stage_picked: bool = false
## 영웅마다 지금 설 무대 (hero_id → stage_id 문자열). 없으면 그 영웅의 home_stage. "다음 전장"이 바꾼다.
static var hero_stages: Dictionary = {}
## 이긴 무대 id들 (다음 무대 열기).
static var cleared_stages: PackedStringArray = PackedStringArray()
## 무대 전부 열기: -1 = 빌드 따라 (시험판이면 전부), 0 = 차례대로, 1 = 전부. 테스트가 바꾼다.
static var unlock_all_override: int = -1


static func unlock_all_stages() -> bool:
	return StageUnlock.test_build() if unlock_all_override < 0 else unlock_all_override == 1


## 무대를 이겼다고 기록 (이미 있으면 그대로). 기록이 늘면 true.
static func mark_cleared(id: StringName) -> bool:
	if id == &"" or cleared_stages.has(String(id)):
		return false
	cleared_stages.append(String(id))
	return true


static func load_settings(path: String = "") -> void:
	if path == "":
		path = settings_path
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	skill_button_enabled = bool(cfg.get_value(SECTION, "skill_button_enabled", skill_button_enabled))
	hero_id = StringName(cfg.get_value("game", "hero_id", String(hero_id)))
	stage_id = StringName(cfg.get_value("game", "stage_id", String(stage_id)))
	intro_seen = bool(cfg.get_value("game", "intro_seen", intro_seen))
	seen_stories = PackedStringArray(cfg.get_value("game", "seen_stories", seen_stories))
	cleared_stages = PackedStringArray(cfg.get_value("game", "cleared_stages", cleared_stages))
	hero_stages = cfg.get_value("game", "hero_stages", hero_stages)


static func save_settings(path: String = "") -> Error:
	if path == "":
		path = settings_path
	var cfg := ConfigFile.new()
	cfg.load(path)  # 다른 항목 보존 (없으면 무시)
	cfg.set_value(SECTION, "skill_button_enabled", skill_button_enabled)
	cfg.set_value("game", "hero_id", String(hero_id))
	cfg.set_value("game", "stage_id", String(stage_id))
	cfg.set_value("game", "intro_seen", intro_seen)
	cfg.set_value("game", "seen_stories", seen_stories)
	cfg.set_value("game", "cleared_stages", cleared_stages)
	cfg.set_value("game", "hero_stages", hero_stages)
	return cfg.save(path)
