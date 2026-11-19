class_name GameSettings
extends RefCounted
## 플레이어 설정 저장 (엔진 기본 ConfigFile, user://settings.cfg).

const PATH := "user://settings.cfg"
## 실제로 읽고 쓰는 파일 (테스트는 다른 파일로 바꿔 실제 설정을 건드리지 않는다).
static var settings_path: String = PATH
const SECTION := "controls"

## 스킬 버튼 표시·사용. 기본은 끔 (한 손 제스처가 기본 조작).
static var skill_button_enabled: bool = false
## 마지막으로 고른 영웅 id (재시작 때 그대로).
static var hero_id: StringName = &""
## 이번 실행에서 영웅을 이미 골랐는지 (앱을 새로 켜면 고르기 화면부터).
static var hero_picked: bool = false


static func load_settings(path: String = "") -> void:
	if path == "":
		path = settings_path
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	skill_button_enabled = bool(cfg.get_value(SECTION, "skill_button_enabled", skill_button_enabled))
	hero_id = StringName(cfg.get_value("game", "hero_id", String(hero_id)))


static func save_settings(path: String = "") -> Error:
	if path == "":
		path = settings_path
	var cfg := ConfigFile.new()
	cfg.load(path)  # 다른 항목 보존 (없으면 무시)
	cfg.set_value(SECTION, "skill_button_enabled", skill_button_enabled)
	cfg.set_value("game", "hero_id", String(hero_id))
	return cfg.save(path)
