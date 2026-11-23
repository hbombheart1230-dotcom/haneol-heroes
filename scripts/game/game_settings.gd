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
## 왼쪽 아래 개발용 수치 (초당 장면 수·적 수·대시 판정 글자). 처음엔 끔 (설정 "개발 수치"로 켬).
## 예전 저장 키(show_stats, 처음 값 켬)는 읽지 않는다 → 이미 깐 폰에서도 꺼진 채로 시작.
static var show_stats: bool = false
## 적 머리 위 체력 막대.
static var enemy_hp_bars: bool = true
## 연타 글씨 ("1타"~"4타", ComboCounter).
static var combo_text: bool = true
## 조작 안내 (설정 "조작 안내", 저장, 처음엔 켬): 켜 두면 앱을 켤 때마다 첫 판에 한 번 나온다.
static var tutorial_enabled: bool = true
## 이번 실행에서 조작 안내를 마쳤는지 (저장 안 함).
static var tutorial_done: bool = false
## 마지막으로 고른 영웅 id (재시작 때 그대로).
static var hero_id: StringName = &""
## 이번 실행에서 영웅을 이미 골랐는지 (앱을 새로 켜면 고르기 화면부터).
static var hero_picked: bool = false
## 이번 실행에서 인트로를 지나갔는지.
static var title_seen: bool = false
## 이번 실행에서 오프닝 영상을 봤는지 (앱을 켤 때마다 한 번).
static var opening_seen: bool = false
## 이야기 인트로를 한 번 봤는지 (저장). 처음 입장할 때만 나온다.
static var intro_seen: bool = false
## 이야기를 이미 본 영웅 id들 (영웅 이야기는 영웅마다 처음 한 번).
static var seen_stories: PackedStringArray = PackedStringArray()
## true면 한 번 본 이야기는 다시 안 보여 준다. 지금은 매번 보여 준다 (사용자 결정, 나중에 켤 수 있게 남김).
static var story_once: bool = false


## 설정 "나가기": 앱을 막 켠 것처럼 첫 화면부터 (오프닝 영상은 다시 틀지 않는다, 저장 값은 그대로).
static func back_to_title() -> void:
	title_seen = false
	hero_picked = false
	stage_picked = false


## 이 이야기를 보여 줄지: 매번 보여 주거나(story_once 꺼짐), 아직 안 봤으면.
static func should_show_story(seen: bool) -> bool:
	return not (story_once and seen)
## 강제로 정한 무대 (테스트·디버그용, stage_picked가 true일 때만). 평소에는 영웅의 무대 순서(hero_stages).
static var stage_id: StringName = &""
static var stage_picked: bool = false
## 영웅마다 지금 설 무대 (hero_id → stage_id). 이번 실행 동안만 (저장 안 함): 앱을 켜거나 영웅을 고르면 자기 무대부터, "다음 전장"으로만 이어간다.
static var hero_stages: Dictionary = {}
## 영웅마다 이긴 전장 수 (hero_id → 수). 난이도 단계 (DifficultyCurve).
static var hero_clears: Dictionary = {}
## 이긴 무대 id들 (옛 저장·기록용. 전장 열기는 영웅별 hero_cleared).
static var cleared_stages: PackedStringArray = PackedStringArray()
## 다음 판 전 흐름에서 전장 목록(StageSelect)을 연다 (입장·영웅 고르기·결과 "전장 목록"·판 중 "전장 나가기" 뒤). 저장 안 함.
static var want_stage_list: bool = false
## 전장 기록 ("hero_id/stage_id" → {"level": 가장 높이 오른 경지, "time": 가장 빨리 이긴 초 (0 = 아직 못 이김)}).
static var stage_records: Dictionary = {}
## 영웅마다 이긴 무대 (hero_id → PackedStringArray). 전장 목록의 이김·열림 (CampaignProgress).
## 옛 저장에 없으면 cleared_stages에서 옮긴다 (CampaignProgress.migrate, Main이 영웅 목록을 알 때).
static var hero_cleared: Dictionary = {}


## 판 중 "전장 나가기"·결과 "전장 목록": 판을 버리고 그 영웅의 전장 목록으로 (첫 화면·영웅 고르기는 건너뜀).
static func back_to_stage_list() -> void:
	stage_picked = false
	want_stage_list = true


## 판이 끝난 기록을 남긴다: 가장 높은 경지, 이겼으면 가장 빠른 시간.
static func record_run(hero: StringName, stage: StringName, level: int, won: bool, seconds: float) -> void:
	var key := "%s/%s" % [hero, stage]
	var r: Dictionary = stage_records.get(key, {"level": 0, "time": 0.0})
	r["level"] = maxi(int(r.get("level", 0)), level)
	var best := float(r.get("time", 0.0))
	if won and (best <= 0.0 or seconds < best):
		r["time"] = seconds
	stage_records[key] = r


static func record_of(hero: StringName, stage: StringName) -> Dictionary:
	return stage_records.get("%s/%s" % [hero, stage], {})


## 이 영웅이 이 무대를 이겼다고 기록 (cleared_stages에도). 영웅 기록이 늘면 true.
static func mark_hero_cleared(hero: StringName, id: StringName) -> bool:
	mark_cleared(id)
	var key := String(hero)
	var mine := PackedStringArray(hero_cleared.get(key, PackedStringArray()))
	if id == &"" or mine.has(String(id)):
		return false
	mine.append(String(id))
	hero_cleared[key] = mine
	return true


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
	sfx_volume = clampf(float(cfg.get_value("sound", "sfx_volume", sfx_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("sound", "music_volume", music_volume)), 0.0, 1.0)
	haptics_enabled = bool(cfg.get_value("sound", "haptics", haptics_enabled))
	story_enabled = bool(cfg.get_value("game", "story_enabled", story_enabled))
	show_stats = bool(cfg.get_value("display", "dev_stats", false))
	enemy_hp_bars = bool(cfg.get_value("display", "enemy_hp_bars", enemy_hp_bars))
	combo_text = bool(cfg.get_value("display", "combo_text", combo_text))
	tutorial_enabled = bool(cfg.get_value("game", "tutorial_enabled", true))  # 값이 없으면 (처음·예전 저장) 켬
	apply_audio()
	hero_id = StringName(cfg.get_value("game", "hero_id", String(hero_id)))
	stage_id = StringName(cfg.get_value("game", "stage_id", String(stage_id)))
	intro_seen = bool(cfg.get_value("game", "intro_seen", intro_seen))
	seen_stories = PackedStringArray(cfg.get_value("game", "seen_stories", seen_stories))
	cleared_stages = PackedStringArray(cfg.get_value("game", "cleared_stages", cleared_stages))
	hero_clears = cfg.get_value("game", "hero_clears", hero_clears)
	hero_cleared = cfg.get_value("game", "hero_cleared", hero_cleared)
	stage_records = cfg.get_value("game", "stage_records", stage_records)


static func save_settings(path: String = "") -> Error:
	if path == "":
		path = settings_path
	var cfg := ConfigFile.new()
	cfg.load(path)  # 다른 항목 보존 (없으면 무시)
	cfg.set_value(SECTION, "skill_button_enabled", skill_button_enabled)
	cfg.set_value("sound", "sfx_volume", sfx_volume)
	cfg.set_value("sound", "music_volume", music_volume)
	cfg.set_value("sound", "haptics", haptics_enabled)
	cfg.set_value("game", "story_enabled", story_enabled)
	cfg.set_value("display", "dev_stats", show_stats)
	cfg.set_value("display", "enemy_hp_bars", enemy_hp_bars)
	cfg.set_value("display", "combo_text", combo_text)
	cfg.set_value("game", "tutorial_enabled", tutorial_enabled)
	cfg.set_value("game", "hero_id", String(hero_id))
	cfg.set_value("game", "stage_id", String(stage_id))
	cfg.set_value("game", "intro_seen", intro_seen)
	cfg.set_value("game", "seen_stories", seen_stories)
	cfg.set_value("game", "cleared_stages", cleared_stages)
	cfg.set_value("game", "hero_clears", hero_clears)
	cfg.set_value("game", "hero_cleared", hero_cleared)
	cfg.set_value("game", "stage_records", stage_records)
	return cfg.save(path)


## 효과음·음악 크기를 오디오 버스(default_bus_layout.tres: Music, SFX)에 반영. 0이면 끈다.
static func apply_audio() -> void:
	for pair in [[&"Music", music_volume], [&"SFX", sfx_volume]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i < 0:
			continue
		var v: float = pair[1]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
