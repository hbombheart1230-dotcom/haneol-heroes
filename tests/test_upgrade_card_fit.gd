extends GdUnitTestSuite
## 강화 패 글 자리: 모든 영웅의 모든 패(처음·높은 단계·큰 변형)를 S20(720×1600)과 16:9(720×1280) 화면에 셋씩 띄워
## 글자 상자끼리 겹치지 않고, 패 안(아이콘·띠 아래)에 들어가고, 글씨 크기가 그대로인지 본다.
## 값이 셋인 패와 아주 큰 숫자("지금 → 뒤"가 패 폭보다 넓음)는 시험용 패로 따로.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]
const SCREENS := [Vector2(720, 1600), Vector2(720, 1280)]


func _build(hero: String) -> RunBuild:
	var b := RunBuild.new()
	b.hero = (load("res://data/heroes/%s.tres" % hero) as HeroData).duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	return b


func _cards(b: RunBuild, vp: Vector2) -> UpgradeCards:
	var c: UpgradeCards = auto_free(UpgradeCards.new())
	c.size = vp
	c.build = b
	return c


## 열린 패 셋의 글 자리를 모두 확인한다. 문제를 글로 모아 돌려준다 (빈 목록 = 통과).
func _problems(c: UpgradeCards, tag: String) -> PackedStringArray:
	var bad := PackedStringArray()
	for i in c.choices.size():
		var u := c.choices[i]
		var r := c.card_rect(i)
		var top := maxf(UpgradeCardLayout.icon_rect(c, r).end.y, r.position.y + 6.0 + c.band_height)
		var rows := UpgradeCardLayout.rows(c, u, r)
		for a in rows.size():
			var ra: Rect2 = rows[a]["box"]
			var name := "%s %s '%s'" % [tag, u.id, rows[a]["text"]]
			if ra.position.x < r.position.x + 2.0 or ra.end.x > r.end.x - 2.0:
				bad.append(name + " 옆으로 넘침")
			if ra.position.y < top or ra.end.y > r.end.y - 2.0:
				bad.append(name + " 위아래로 넘침")
			for b in range(a + 1, rows.size()):
				if ra.intersects(rows[b]["box"]):
					bad.append("%s 겹침 '%s'" % [name, rows[b]["text"]])
	return bad


func _check_pages(b: RunBuild, ups: Array, major: bool, stacks: Dictionary, tag: String) -> PackedStringArray:
	var bad := PackedStringArray()
	for vp in SCREENS:
		var i := 0
		while i < ups.size():
			var c := _cards(b, vp)
			var pick: Array[UpgradeDef] = []
			for j in 3:
				pick.append(ups[(i + j) % ups.size()])
			c.open(pick, major, stacks)
			bad.append_array(_problems(c, "%s %s" % [tag, vp]))
			i += 3
	return bad


func test_every_card_fits_without_overlap() -> void:
	var bad := PackedStringArray()
	for h in HEROES:
		var b := _build(h)
		var ups: Array = b.hero.upgrade_pool.upgrades
		bad.append_array(_check_pages(b, ups, false, {}, h + " 처음"))
		bad.append_array(_check_pages(b, b.hero.major_pool.upgrades, true, {}, h + " 큰 변형"))
		var stacks := {}
		for u in ups:  # 최고 단계 바로 앞까지 (숫자가 가장 클 때)
			for s in maxi(u.max_stacks - 1, 0):
				b.apply(u)
			stacks[u.id] = maxi(u.max_stacks - 1, 0)
		bad.append_array(_check_pages(b, ups, false, stacks, h + " 높은 단계"))
	assert_array(Array(bad)).is_empty()


func _mod(target: StringName, prop: StringName, v: float) -> StatMod:
	var m := StatMod.new()
	m.target = target
	m.property = prop
	m.op = StatMod.Op.MUL
	m.value = v
	return m


func test_three_values_and_wide_numbers_keep_font_size() -> void:
	var b := _build("yi_sun_sin")
	b.hero.kit.tap.damage = 123456  # "123456 → 172838"은 패 폭보다 넓다
	var u := UpgradeDef.new()
	u.id = &"test_three"
	u.title = "해룡참 · 아주 긴 이름의 시험 강화"
	u.max_stacks = 3
	u.mods = [_mod(&"tap", &"damage", 1.4), _mod(&"tap", &"radius", 1.25), _mod(&"tap", &"cooldown", 0.8)]
	assert_int(UpgradeReadout.lines(u, b, 1).size()).is_equal(3)
	for vp in SCREENS:
		var c := _cards(b, vp)
		var pick: Array[UpgradeDef] = [u, u, u]
		c.open(pick, false, {})
		assert_array(Array(_problems(c, "세 값 %s" % vp))).is_empty()
		var rows := UpgradeCardLayout.rows(c, u, c.card_rect(0))
		var values := rows.filter(func(it: Dictionary) -> bool: return it["role"] == UpgradeCardLayout.Role.VALUE)
		assert_int(values.size()).is_equal(4)  # 큰 숫자 한 값은 두 줄로 나뉨
		for it in values:
			assert_int(it["px"]).is_equal(c.value_px)  # 글씨는 줄이지 않는다
		assert_float(c.card_rect(0).size.y).is_greater(c.card_size.y)  # 대신 패가 길어진다


func test_same_line_twice_is_shown_once() -> void:
	var b := _build("yi_sun_sin")
	for u in b.hero.upgrade_pool.upgrades:
		if u.id == &"blade":  # 근접·원거리 피해가 같이 오른다
			assert_int(UpgradeReadout.lines(u, b, 1).size()).is_equal(1)
			return
	fail("blade 패가 없다")
