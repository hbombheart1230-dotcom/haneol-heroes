extends GdUnitTestSuite
## 강화 카드 그림: 영웅 강화(일반·큰 변형)는 모두 그림이 있고, 한 영웅 안에서 같은 그림을 두 번 쓰지 않는다.
## (그림이 없으면 카드에 글자 하나만 나온다 — 무엇을 고르는지 모른다는 피드백.)

const HEROES := [
	"res://data/heroes/yi_sun_sin.tres",
	"res://data/heroes/gwanggaeto.tres",
	"res://data/heroes/sejong.tres",
	"res://data/heroes/shin_saimdang.tres",
]


func _all_upgrades(hero: HeroData) -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for pool: UpgradePool in [hero.upgrade_pool, hero.major_pool]:
		if pool:
			out.append_array(pool.upgrades)
	return out


func test_every_upgrade_has_an_icon() -> void:
	for path: String in HEROES:
		var hero: HeroData = load(path)
		var ups := _all_upgrades(hero)
		assert_int(ups.size()).override_failure_message("%s: 강화가 없다" % path).is_greater(0)
		for u in ups:
			assert_object(u.icon).override_failure_message("%s / %s: 그림 없음" % [path, u.id]).is_not_null()


func test_no_two_upgrades_of_a_hero_share_an_icon() -> void:
	for path: String in HEROES:
		var hero: HeroData = load(path)
		var seen := {}
		for u in _all_upgrades(hero):
			if u.icon == null:
				continue
			var file := u.icon.resource_path
			assert_bool(seen.has(file)).override_failure_message(
				"%s: %s 와 %s 가 같은 그림 %s" % [path, seen.get(file, ""), u.id, file]).is_false()
			seen[file] = u.id


func test_upgrade_icons_are_small_squares() -> void:
	for path: String in HEROES:
		for u in _all_upgrades(load(path)):
			if u.icon == null:
				continue
			assert_int(u.icon.get_width()).is_equal(u.icon.get_height())
			assert_int(u.icon.get_width()).is_less_equal(256)
