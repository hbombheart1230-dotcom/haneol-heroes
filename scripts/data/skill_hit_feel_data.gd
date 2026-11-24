class_name SkillHitFeelData
extends Resource
## 기술의 연속 타격 (사용자: "스킬들에 타격 효과가, 연속 타격 효과가 없어"): 계속 닿는 장판·도는 글자·벌레·여러 번 치는 기술과
## 기술 탄(해일검기·사방 검기)이 맞을 때마다 내는 가벼운 타격, 그리고 마지막 타의 큰 멈춤 한 번.
## 한 번에 끊어 치는 기술 명중은 HitImpactData.skill_step(3타급) 그대로. 멈춤은 GameTime 겹침 규칙, 흔들림은 ImpactFx.capped_trauma.

const PATH := "res://data/feel/skill_hits.tres"

@export_group("한 번 닿을 때마다 (멈춤 없음)")
## 접점 섬광 크기 (HitImpactData 타 번호 1~3), 작은 퍽 소리 음높이와 다시 울리기까지 간격(초, 여러 적·여러 틱이 한꺼번에 울리지 않게).
@export var tick_step: int = 1
@export var tick_thud: bool = true
@export var tick_pitch: float = 0.92
@export var tick_gap: float = 0.09
## 화면 밀림 (px, 맞은 방향). 흔들림은 주지 않는다 (틱이 쌓여 화면이 계속 흔들리지 않게).
@export var tick_kick: float = 2.0

@export_group("마지막 타")
## 마지막 타의 멈춤 = CombatFeelData.skill_stop_cap × finale_stop (느린 정도 finale_scale), 다시 멈추기까지 최소 간격(초).
@export var finale_stop: float = 1.0
@export var finale_scale: float = 0.05
@export var finale_gap: float = 0.3

@export_group("긁기 (해일검기 물결, WaveRake)")
## 타마다 짧은 소리 (음높이가 타마다 rake_pitch_step씩 올라 rake_pitch_max까지), 다시 울리기까지 간격(초): 여러 적이 한꺼번에 뭉개지지 않게.
@export var rake_sfx: StringName = &"mat_water"
@export var rake_pitch: float = 0.95
@export var rake_pitch_step: float = 0.05
@export var rake_pitch_max: float = 1.35
@export var rake_gap: float = 0.045
## 적마다 마지막 타의 큰 소리.
@export var rake_last_sfx: StringName = &"w_heavy"

static var _cached: SkillHitFeelData


static func get_default() -> SkillHitFeelData:
	if _cached == null:
		_cached = load(PATH) as SkillHitFeelData if ResourceLoader.exists(PATH) else null
		if _cached == null:
			_cached = SkillHitFeelData.new()
	return _cached


func finale_seconds(feel: CombatFeelData) -> float:
	return feel.skill_stop_cap * clampf(finale_stop, 0.0, 2.0) if feel else 0.0
