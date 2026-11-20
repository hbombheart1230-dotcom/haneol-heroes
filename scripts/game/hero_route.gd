class_name HeroRoute
extends RefCounted
## 영웅별 무대 순서: 자기 무대(HeroData.home_stage)에서 시작해, 이기면 무대 목록 순서대로 다음 전장
## (마지막 다음은 처음으로 돌아간다). 진행은 GameSettings.hero_stages에 영웅마다 저장.


## 이 영웅이 지금 설 무대 id. 저장된 것이 목록에 없으면 자기 무대, 그것도 없으면 첫 무대.
static func current(stages: Array[StageTheme], hero: HeroData, saved: Dictionary) -> StringName:
	if stages.is_empty():
		return &""
	var want := StringName(saved.get(String(hero.id), "")) if hero else &""
	if index_of(stages, want) < 0 and hero:
		want = hero.home_stage
	return want if index_of(stages, want) >= 0 else stages[0].id


## 목록에서 다음 무대 id (끝이면 처음).
static func next(stages: Array[StageTheme], id: StringName) -> StringName:
	if stages.is_empty():
		return &""
	var i := index_of(stages, id)
	return stages[(i + 1) % stages.size()].id if i >= 0 else stages[0].id


static func index_of(stages: Array[StageTheme], id: StringName) -> int:
	for i in stages.size():
		if stages[i] and stages[i].id == id:
			return i
	return -1
