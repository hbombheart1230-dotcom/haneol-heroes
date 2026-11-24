class_name HomeSummonEntry
extends Resource
## 주인 영웅 하나가 원정 온 영웅을 도울 때 쓰는 기술 (HomeSummonData.entries).

@export var hero_id: StringName = &""
## 주인 영웅 기술 묶음(SkillKit)의 어느 칸 (SkillCaster.Slot: 1 탭, 2 내닫기, 3 모으기, 4 반격). 기본 = 모으기 기술.
@export var slot: int = 3
## 이 기술의 피해 배율 (기본 영웅 배율 1인 우두머리 기준). 우두머리 체력이 영웅·난이도로 늘면 같은 비율로 곱한다
## (HomeSummonRules.boss_factor). 한 번에 우두머리 체력의 boss_share 근처가 되게 맞춘다 (tests/test_home_summon_sim.gd).
@export var damage_scale: float = 1.0
