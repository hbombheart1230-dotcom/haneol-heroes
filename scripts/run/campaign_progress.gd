class_name CampaignProgress
extends RefCounted
## 전장 목록의 상태 (순수 로직): 칸마다 이김 / 열림 / 잠김 / 곧 열림, 원정(다른 영웅 전장) 열림.
## 이긴 기록은 영웅마다 (GameSettings.hero_cleared: hero_id → 이긴 무대 id 목록). 저장·불러오기는 GameSettings.

enum State { CLEARED, OPEN, LOCKED, COMING }

## 무대 id → StageTheme (만든 무대만).
var stages: Dictionary = {}
## hero_id(String) → PackedStringArray (그 영웅이 이긴 무대 id).
var cleared: Dictionary = {}


func _init(p_stages: Array[StageTheme] = [], p_cleared: Dictionary = {}) -> void:
	for st in p_stages:
		if st:
			stages[st.id] = st
	cleared = p_cleared


func stage_of(id: StringName) -> StageTheme:
	return stages.get(id)


func has_cleared(hero: HeroData, id: StringName) -> bool:
	return hero != null and PackedStringArray(cleared.get(String(hero.id), PackedStringArray())).has(String(id))


## 칸 i의 상태. 무대가 아직 없으면 곧 열림, 이겼으면 이김, 첫 칸이거나 앞 칸을 이겼으면 열림, 아니면 잠김.
func state(hero: HeroData, i: int) -> State:
	var slots := hero.campaign.slots if hero and hero.campaign else []
	if i < 0 or i >= slots.size():
		return State.LOCKED
	var id: StringName = slots[i].id
	if stage_of(id) == null:
		return State.COMING
	if has_cleared(hero, id):
		return State.CLEARED
	if i == 0 or has_cleared(hero, slots[i - 1].id):
		return State.OPEN
	return State.LOCKED


## 원정: 다른 영웅(owner)의 전장 칸 i를 지금 영웅(player)으로 볼 때. 만든 전장은 모두 갈 수 있다 (이김은 player 기록).
func expedition_state(player: HeroData, owner: HeroData, i: int) -> State:
	var slots := owner.campaign.slots if owner and owner.campaign else []
	if i < 0 or i >= slots.size():
		return State.LOCKED
	var id: StringName = slots[i].id
	if stage_of(id) == null:
		return State.COMING
	return State.CLEARED if has_cleared(player, id) else State.OPEN


## 원정이 열렸는지: 원정에 필요한 자기 전장(HeroCampaign.expedition_needs, 만든 것만)을 모두 이겼으면.
func expedition_open(hero: HeroData) -> bool:
	return not expedition_needed(hero).is_empty() and expedition_missing(hero).is_empty()


## 원정에 필요한 자기 전장 칸 id (앞에서부터 expedition_needs개, 0이면 모두. 곧 열림 칸은 뺀다).
func expedition_needed(hero: HeroData) -> Array[StringName]:
	var out: Array[StringName] = []
	if hero == null or hero.campaign == null:
		return out
	var c := hero.campaign
	var n := c.slots.size() if c.expedition_needs <= 0 else mini(c.expedition_needs, c.slots.size())
	for i in n:
		if stage_of(c.slots[i].id) != null:
			out.append(c.slots[i].id)
	return out


## 원정에 필요한데 아직 못 이긴 자기 전장 id.
func expedition_missing(hero: HeroData) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in expedition_needed(hero):
		if not has_cleared(hero, id):
			out.append(id)
	return out


## 잠긴 원정의 까닭 한 줄: "순신의 전장(한산)을 먼저 깨야 합니다". 열렸으면 "".
func expedition_reason(hero: HeroData) -> String:
	if hero == null or expedition_open(hero):
		return ""
	var names := PackedStringArray()
	for id in expedition_missing(hero):
		names.append(_title(hero, id))
	if names.is_empty():
		return "%s의 전장이 아직 없습니다" % hero.display_name
	return "%s의 전장(%s)을 먼저 깨야 합니다" % [hero.display_name, "·".join(names)]


func _title(hero: HeroData, id: StringName) -> String:
	for sl in hero.campaign.slots:
		if sl.id == id and sl.title != "":
			return sl.title
	var st := stage_of(id)
	return st.title if st and st.title != "" else String(id)


## 이 영웅이 지금 이어 갈 전장 (열린 첫 칸, 다 이겼으면 마지막으로 이긴 칸). 없으면 &"".
func current(hero: HeroData) -> StringName:
	if hero == null or hero.campaign == null:
		return &""
	var last := &""
	for i in hero.campaign.slots.size():
		var s := state(hero, i)
		if s == State.OPEN:
			return hero.campaign.slots[i].id
		if s == State.CLEARED:
			last = hero.campaign.slots[i].id
	return last


## 이 칸 다음 칸 id (없으면 &"").
static func next_of(hero: HeroData, id: StringName) -> StringName:
	if hero == null or hero.campaign == null:
		return &""
	var ids := hero.campaign.ids()
	var i := ids.find(id)
	return ids[i + 1] if i >= 0 and i + 1 < ids.size() else &""


## 옛 저장 (무대 id만 있는 cleared_stages) → 영웅별 기록: 그 무대를 전장 목록에 가진 영웅의 기록으로 옮긴다.
static func migrate(heroes: Array[HeroData], old_cleared: PackedStringArray, into: Dictionary) -> Dictionary:
	for h in heroes:
		if h == null or h.campaign == null:
			continue
		var key := String(h.id)
		var mine := PackedStringArray(into.get(key, PackedStringArray()))
		for id in old_cleared:
			if h.campaign.has(StringName(id)) and not mine.has(id):
				mine.append(id)
		if not mine.is_empty():
			into[key] = mine
	return into
