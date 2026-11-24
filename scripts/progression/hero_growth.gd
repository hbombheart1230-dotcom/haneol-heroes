class_name HeroGrowth
extends RefCounted
## 판을 넘어 남는 영웅 성장 (순수 로직): 점수 n → 체력·피해 배율, 기술 시작 단계, 전장 고르기 한 줄.
## 점수는 따로 저장하지 않고 GameSettings.hero_cleared(처음 이긴 전장 목록, 원정 포함)의 크기에서 계산한다.

var data: HeroGrowthData


func _init(p_data: HeroGrowthData = null) -> void:
	data = p_data if p_data else HeroGrowthData.new()


static func load_default() -> HeroGrowth:
	var d := load(HeroGrowthData.PATH) as HeroGrowthData if ResourceLoader.exists(HeroGrowthData.PATH) else null
	return HeroGrowth.new(d)


## 성장 점수: 이 영웅이 처음 이긴 전장 수.
static func points(cleared: Dictionary, hero_id: StringName) -> int:
	return PackedStringArray(cleared.get(String(hero_id), PackedStringArray())).size()


func _n(n: int) -> int:
	return clampi(n, 0, data.max_points)


func hp_mult(n: int) -> float:
	return 1.0 + data.hp_per * _n(n)


func damage_mult(n: int) -> float:
	return 1.0 + data.atk_per * _n(n)


## 기술 시작 단계 (0 = 기본).
func skill_start(n: int) -> int:
	if data.skill_every <= 0:
		return 0
	return mini(_n(n) / data.skill_every, data.skill_start_max)


func top_stage_open(n: int) -> bool:
	return skill_start(n) >= data.top_stage_from_start


## 전장 고르기 한 줄: "깬 전장 n · 영웅 성장 +x% · 기술 n단계 시작" (없는 부분은 뺀다).
func line(n: int) -> String:
	var s := "깬 전장 %d" % n
	var pct := roundi((hp_mult(n) - 1.0) * 100.0)
	if pct > 0:
		s += " · 영웅 성장 +%d%%" % pct
	if skill_start(n) > 0:
		s += " · 기술 %d단계 시작" % skill_start(n)
	return s
