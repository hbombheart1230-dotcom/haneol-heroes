class_name GameSettings
extends RefCounted
## 플레이어 설정 저장 (엔진 기본 ConfigFile, user://settings.cfg).

const PATH := "user://settings.cfg"
const SECTION := "controls"

## 스킬 버튼 표시·사용. 기본은 끔 (한 손 제스처가 기본 조작).
static var skill_button_enabled: bool = false


static func load_settings(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	skill_button_enabled = bool(cfg.get_value(SECTION, "skill_button_enabled", skill_button_enabled))


static func save_settings(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(path)  # 다른 항목 보존 (없으면 무시)
	cfg.set_value(SECTION, "skill_button_enabled", skill_button_enabled)
	return cfg.save(path)
