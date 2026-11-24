extends GdUnitTestSuite
## 색 규칙 A (사용자 2026-11-24): 붉은 인주(Ink.SEAL 계열)는 적의 위험 전용. 영웅 쪽 데이터(기술 단추·효과 색, 검기,
## 기술 그림 색, 반격 글자·큰 피해 숫자·마무리 연타 글자)에 순적색(r≥0.6, g≤0.35, b≤0.3)이 다시 들어오면 잡는다.
## 적 예고 테두리는 기술 효과 위 층 (B, TelegraphRim).

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


static func is_seal_red(c: Color) -> bool:
	return c.r >= 0.6 and c.g <= 0.35 and c.b <= 0.3


func _colors_in(res: Resource, out: Array, path: String, seen: Dictionary) -> void:
	if res == null or seen.has(res.get_instance_id()):
		return
	seen[res.get_instance_id()] = true
	for p in res.get_property_list():
		if not (p.usage & PROPERTY_USAGE_STORAGE):
			continue
		var v: Variant = res.get(p.name)
		if v is Color:
			out.append([path + "." + p.name, v])
		elif v is Resource and not (v is Texture2D) and not (v is Script):
			_colors_in(v, out, path + "." + p.name, seen)
		elif v is Array:
			for i in (v as Array).size():
				if (v as Array)[i] is Resource:
					_colors_in((v as Array)[i], out, "%s.%s[%d]" % [path, p.name, i], seen)


func test_hero_side_has_no_seal_red() -> void:
	var bad: Array = []
	for id in HEROES:
		var cols: Array = []
		var h: HeroData = load("res://data/heroes/%s.tres" % id)
		for part in [h.attack, h.kit]:
			_colors_in(part, cols, id, {})
		for c in cols:
			if is_seal_red(c[1]):
				bad.append(c[0])
	var feel := Feedback.feel_data()
	var im := feel.impact_data()
	for c in [["counter_color", im.counter_color], ["number_color_big", im.number_color_big],
			["combo finish_color", ComboTextData.new().finish_color]]:
		if is_seal_red(c[1]):
			bad.append(c[0])
	assert_array(bad).is_empty()


## 적 예고 색은 그대로 인주 빨강 (규칙의 반대쪽).
func test_enemy_warning_stays_seal_red() -> void:
	assert_bool(is_seal_red(Ink.SEAL)).is_true()


## B: 적마다 예고 테두리 층이 있고, 기술 효과 층(검기 4·효과 5·타격 섬광·탄 21)보다 위에 그린다. 채움은 적 노드(바닥).
func test_telegraph_rim_draws_above_skill_effects() -> void:
	var e: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	e.data = preload("res://data/enemies/waegun_soldier.tres")
	add_child(auto_free(e))
	var rim := e.get_node_or_null(^"TelegraphRim") as TelegraphRim
	assert_object(rim).is_not_null()
	assert_bool(rim.z_as_relative).is_false()
	assert_int(rim.z_index).is_greater(21)
	assert_int(rim.z_index).is_greater(HitImpact.data().draw_z)


## 포격 줄(LaneStrike)도 같은 규칙: 위아래 경계 붓 획·화면 밖 화살표는 LaneRim 층(적 예고 테두리와 같은 절대 z), 번짐은 바닥.
func test_lane_strike_rim_draws_above_skill_effects() -> void:
	var lane: Node2D = auto_free((load("res://data/stages/hazards/hansan_cannon.tres") as LaneStrikeData).make())
	var rim := lane.get_node_or_null(^"LaneRim") as Node2D
	assert_object(rim).is_not_null()
	assert_bool(rim.z_as_relative).is_false()
	assert_int(rim.z_index).is_equal(Enemy.ai_data().telegraph_rim_z)
