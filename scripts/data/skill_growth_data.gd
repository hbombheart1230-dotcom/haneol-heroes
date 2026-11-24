class_name SkillGrowthData
extends Resource
## 강화할수록 기술 모습이 단계적으로 커지고 화려해진다 (사용자: "초반엔 작게 나중엔 크고 화려하게").
## 입력은 SkillDef.vfx_level 하나 (카드 한 장·레벨업 두 번마다 +1 등, 진행 방식이 바뀌어도 이 숫자만 오르면 된다).
## vfx_level → 단계 (stage_from): 0 기본 · 1~2 · 3~5 · 6 이상 (판 흐름: 숨① 뒤 1단계, 숨② 뒤 2단계, 숨④ 뒤 최대 — docs/research/skill_growth.md). 단계마다 크기·입자·빛·겹·화면 상한.
## 판정은 SkillDef.growth가 켜진 기술, 그림 단계는 SkillVfxData.growth가 켜진 효과에 (켜지 않은 효과는 예전 level_size 방식).
## 판정도 같은 비율로 (사용자 결정: 보이는 대로 맞게, 성장이 손에도) — 발동 때 hit_props 수치를 size배 한 기술 사본 (scaled_def).

const PATH := "res://data/feel/skill_growth.tres"

## 이 vfx_level부터 그 단계 (오름차순, 첫 값 0).
@export var stage_from: PackedInt32Array = PackedInt32Array([0, 1, 3, 6, 9])
## 판정·그림 크기 배율 (기본 0.75는 tests/test_growth_sim.gd 근거). 기본은 지금보다 작게 시작한다.
@export var size: PackedFloat32Array = PackedFloat32Array([0.75, 0.88, 1.0, 1.3, 1.45])
## 입자 수 배율, 빛 세기 배율, 밝기 배율.
@export var count: PackedFloat32Array = PackedFloat32Array([0.6, 1.0, 1.5, 2.2, 2.6])
@export var glow: PackedFloat32Array = PackedFloat32Array([0.6, 1.0, 1.4, 1.9, 2.2])
@export var bright: PackedFloat32Array = PackedFloat32Array([0.9, 1.0, 1.15, 1.3, 1.35])
## 그림 겹 추가 (돌며 겹치는 그림 한 장씩 더).
@export var layers: PackedInt32Array = PackedInt32Array([0, 0, 1, 2, 2])
## 이 단계부터 금빛 고리.
@export var ring_stage: int = 2
## 맨 위 이 수만큼의 단계는 많이 깬 영웅의 판에서만 열린다 (top_open, HeroGrowth가 판 시작에 정한다).
## 성장 0인 판은 우두머리 때 이미 vfx_level 7~14라, 닫아 두지 않으면 성장 0 기준 균형이 바뀐다.
@export var gated_stages: int = 1
## 화면 너비 대비 상한 (SkillStageFeel.screen_cap 대신). 마지막 단계는 지금(0.58)보다 크게.
@export var screen_cap: PackedFloat32Array = PackedFloat32Array([0.36, 0.46, 0.58, 0.75, 0.75])

## 판정 크기 속성 이름 (있는 것만, 숫자면 size배). 기술 vfx_impact.growth가 켜진 기술에만.
@export var hit_props: PackedStringArray = PackedStringArray(["radius", "outer_radius", "end_burst_radius",
	"star_burst_radius", "min_radius", "max_radius", "width", "length", "line_width", "splash_radius", "fall_size",
	"critter_size", "min_scale", "max_scale"])

@export_group("발동 연출")
## 발동 순간 화면 흔들림 (단계별, 0이면 없음).
@export var cast_shake: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.08, 0.16, 0.16])
## 발동 순간 더 겹쳐 울리는 소리 (단계별, 빈 이름 = 없음).
@export var cast_sfx: Array[StringName] = [&"", &"", &"gugak_buk", &"gugak_big", &"gugak_big"]
## 이 단계부터 컷인 (먹 띠 + 영웅 그림 + 기술 이름). 기술이 cutin이면 늘.
@export var cutin_stage: int = 3

static var _cached: SkillGrowthData
## 이번 판에 맨 위 단계(gated_stages)가 열렸나. 판마다 GrowthApply가 정하고, 시뮬은 reset_globals가 닫는다.
static var top_open: bool = false


static func get_default() -> SkillGrowthData:
	if _cached == null:
		_cached = load(PATH) as SkillGrowthData if ResourceLoader.exists(PATH) else null
		if _cached == null:
			_cached = SkillGrowthData.new()
	return _cached


## vfx_level → 단계 번호 (0 ~ stage_from.size() - 1).
func stage_of(level: int) -> int:
	var s := 0
	var last := stage_from.size() - 1 - (0 if top_open else maxi(gated_stages, 0))
	for i in mini(stage_from.size(), last + 1):
		if level >= stage_from[i]:
			s = i
	return s


func size_at(level: int) -> float:
	return _f(size, level, 1.0)


func count_at(level: int) -> float:
	return _f(count, level, 1.0)


func glow_at(level: int) -> float:
	return _f(glow, level, 1.0)


func bright_at(level: int) -> float:
	return _f(bright, level, 1.0)


func cap_at(level: int) -> float:
	return _f(screen_cap, level, 0.58)


func layers_at(level: int) -> int:
	var s := stage_of(level)
	return layers[s] if s < layers.size() else 0


func ring_at(level: int) -> bool:
	return stage_of(level) >= ring_stage


func _f(arr: PackedFloat32Array, level: int, fallback: float) -> float:
	var s := stage_of(level)
	return arr[s] if s < arr.size() else (arr[arr.size() - 1] if not arr.is_empty() else fallback)


## 이 기술이 성장 단계를 쓰는지 (SkillDef.growth).
static func applies(d: SkillDef) -> bool:
	return d != null and d.growth


## 발동 순간: 단계별 흔들림·소리 층. 반환: 이 단계에서 컷인을 띄울지.
func on_cast(d: SkillDef) -> bool:
	if not applies(d):
		return false
	var s := stage_of(d.vfx_level)
	if s < cast_shake.size() and cast_shake[s] > 0.0:
		Feedback.shake(cast_shake[s])
	if s < cast_sfx.size() and cast_sfx[s] != &"" and Feedback.instance:
		Feedback.instance.play(cast_sfx[s], 0.0)
	return s >= cutin_stage


## 발동할 기술: 성장 단계면 판정 크기 속성을 단계 배율로 키운(줄인) 사본, 아니면 그대로.
func scaled_def(d: SkillDef) -> SkillDef:
	if not applies(d):
		return d
	var k := size_at(d.vfx_level)
	if is_equal_approx(k, 1.0):
		return d
	var c := d.duplicate() as SkillDef
	for n in hit_props:
		if not (n in c):
			continue
		var v: Variant = c.get(n)
		if typeof(v) == TYPE_FLOAT and float(v) > 0.0:
			c.set(n, float(v) * k)
	return c
