class_name FireData
extends StageHazardData
## 들불 (만주 벌판): 마른 풀밭(patches)은 칸(cell px)으로 나뉜다. 불붙은 칸은 spread_delay초마다 이웃 칸으로 번지고
## (번지기 smoke_time초 전부터 다음 칸에 연기), burn_time초 뒤 타 버린 재가 된다 (regrow_time초 뒤 다시 마른 풀).
## 불 위의 적·영웅은 tick초마다 피해 (중립: 적에게 훨씬 세게). 붙이는 것: ignite 성질 기술(번개·유성)이 떨어진 자리,
## 그리고 박자마다(공통 period·warn_time) 하늘에서 떨어지는 불씨 한 점 (예고 원). 끄는 것: douse 성질(물결)의 자리·길.
## 공통 수치: period = 불씨 간격, warn_time = 불씨 예고, enemy_damage·hero_damage = 불 한 틱 피해.

## 마른 풀밭: (월드 x, 월드 y, 반지름).
@export var patches: PackedVector3Array = PackedVector3Array()
@export var cell: float = 80.0
@export var spread_delay: float = 2.0
@export var smoke_time: float = 1.0
@export var burn_time: float = 7.0
@export var regrow_time: float = 45.0
@export var tick: float = 0.5
@export_group("성질")
@export var ignite: Array[StringName] = [&"thunder", &"meteor"]
@export var douse: Array[StringName] = [&"water"]
## 반경이 없는 알림(0)일 때 붙이기·끄기 반경, 물결 탄이 지나가며 끄는 반경.
@export var ignite_radius: float = 90.0
@export var douse_radius: float = 110.0
@export_group("불씨")
## 불씨가 떨어지며 붙이는 반경. 자리는 화면 안 마른 칸 중 둘레에 적이 가장 많은 칸.
@export var ember_radius: float = 110.0
@export_group("그림·소리")
@export var dry_color: Color = Color(0.78, 0.62, 0.3, 0.85)
@export var ash_color: Color = Color(0.12, 0.1, 0.09, 0.45)
@export var flame_color: Color = Color(1.0, 0.55, 0.15, 0.9)
@export var flame_core: Color = Color(1.0, 0.9, 0.55, 0.95)
@export var smoke_color: Color = Color(0.45, 0.42, 0.4, 0.5)
@export var ember_color: Color = Color(1.0, 0.45, 0.1, 0.9)
@export var ignite_sfx: StringName = &"mat_fire"
@export var douse_sfx: StringName = &"mat_water"
@export var burn_vfx: SkillVfxData
@export var steam_vfx: SkillVfxData


func make() -> Node2D:
	return GrassFire.new(self)
