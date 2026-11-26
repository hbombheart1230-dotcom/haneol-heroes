class_name HeroLines
extends Resource
## 영웅 한 줄 대사 (사용자 확정 2026-11-24, docs/research/hero_lines_draft.md). 영웅마다 data/heroes/lines/<영웅 id>.tres 하나.
## lines[경우] = 한 줄. 영웅·경우가 늘면 데이터(와 Case 끝)에만 더한다.

enum Case { ENTER_OWN, ENTER_AWAY, BOSS, VICTORY, DEFEAT, SUMMON }

const DIR := "res://data/heroes/lines/"

## Case 순서대로 한 줄씩 (자기 전장 · 원정 · 우두머리 앞 · 이김 · 쓰러짐 · 소환되어 도울 때).
@export var lines: PackedStringArray = PackedStringArray()


func line(c: Case) -> String:
	return lines[c] if c < lines.size() else ""


static func for_hero(id: StringName) -> HeroLines:
	var path := DIR + String(id) + ".tres"
	return load(path) as HeroLines if ResourceLoader.exists(path) else null


## 이 전장이 그 영웅의 전장 목록에 있으면 자기 전장, 아니면 원정.
static func enter_case(hero: HeroData, stage_id: StringName) -> Case:
	if hero and hero.campaign:
		for sl in hero.campaign.slots:
			if sl and sl.id == stage_id:
				return Case.ENTER_OWN
	return Case.ENTER_AWAY
