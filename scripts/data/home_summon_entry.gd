class_name HomeSummonEntry
extends Resource
## 주인 영웅 하나가 원정 온 영웅을 도울 때 쓰는 기술 (HomeSummonData.entries).

@export var hero_id: StringName = &""
## 주인 영웅 기술 묶음(SkillKit)의 어느 칸 (SkillCaster.Slot: 1 탭, 2 내닫기, 3 모으기, 4 반격). 기본 = 모으기 기술.
@export var slot: int = 3
## 이 기술의 피해 배율 (기본 영웅 배율 1인 우두머리 기준). 우두머리 체력이 영웅·난이도로 늘면 같은 비율로 곱한다
## (HomeSummonRules.boss_factor). 한 번에 우두머리 체력의 boss_share 근처가 되게 맞춘다 (tests/test_home_summon_sim.gd).
@export var damage_scale: float = 1.0
@export_group("최종 단계 모습")
## 부를 때 그 기술을 이 강화 모습 단계로 쓴다 (SkillDef.vfx_level → SkillGrowthData: 모습·범위·겹 모두; 사용자 "기술 최종 단계만 붙여서").
## 6 = 많이 깨지 않은 판에서도 열리는 맨 위 단계 (크기 1.3배). -1이면 예전처럼 기본 단계.
@export var final_level: int = 6
## 대표 큰 변형 하나 (그 기술의 속성 이름과 더할 값). 비면 없음. 피해만 바꾸는 변형은 넣지 않는다.
@export var major_property: StringName = &""
@export var major_value: float = 0.0


## 이 기술의 부르기용 사본: 최종 모습 단계 + 대표 큰 변형 + 성장 배율이 든 판정 (피해 배율은 부른 쪽이 따로 곱한다).
func final_def(d: SkillDef) -> SkillDef:
	if d == null or final_level < 0:
		return d
	var c := d.duplicate() as SkillDef
	c.vfx_level = final_level
	if major_property != &"" and major_property in c:
		var v: Variant = c.get(major_property)
		c.set(major_property, roundi(float(v) + major_value) if typeof(v) == TYPE_INT else float(v) + major_value)
	return SkillGrowthData.get_default().scaled_def(c)
