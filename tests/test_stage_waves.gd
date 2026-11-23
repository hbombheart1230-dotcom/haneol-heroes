extends GdUnitTestSuite
## 네 무대 물결·적 규칙이 한산과 같은 틀 (사용자: "스테이지 작업도 순신과 동일하게 다른 영웅들 것 맞춰줘").
## 물결: 6 · 3+정예 · 9, 상한 3·4·5, 한 마리씩 보충, xp ×3.5. 적은 역할(근접·원거리·중갑·정예)별로 한산 왜군과 같은 값,
## 군대마다의 버릇(돌진·숨기·거리, 공격 종류·사거리, 테두리 색)은 그대로.

const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]
## 무대마다 역할 → 적 (한산이 기준).
const ROLES := {
	"hansan_1592": {"melee": "waegun_soldier", "ranged": "waegun_gunner", "heavy": "waegun_heavy", "elite": "waegun_elite"},
	"manchuria_395": {"melee": "chaser", "ranged": "archer", "heavy": "heavy", "elite": "elite_warrior"},
	"gyeongbokgung_1433": {"melee": "jurchen_soldier", "ranged": "jurchen_archer", "heavy": "jurchen_heavy", "elite": "jurchen_elite"},
	"chochungdo": {"melee": "cc_mouse", "ranged": "cc_grasshopper", "heavy": "cc_beetle", "elite": "cc_mantis"},
}


func _st(id: String) -> StageTheme:
	return load("res://data/stages/%s.tres" % id)


func _enemy(id: String) -> EnemyData:
	return load("res://data/enemies/%s.tres" % id)


## 물결 모양: 수·상한·정예 자리·보충 방식이 한산과 같고, 적은 그 무대 군대의 근접·원거리·중갑.
func test_every_stage_has_hansan_wave_shape() -> void:
	var base := _st("hansan_1592").waves
	for id in STAGES:
		var w := _st(id).waves
		assert_object(w).override_failure_message(id).is_not_null()
		for k in ["max_alive", "next_when_left", "refill_each", "xp_mult", "warn_time", "one_pick_per_break", "pick_stacks"]:
			assert_that(w.get(k)).override_failure_message("%s.%s" % [id, k]).is_equal(base.get(k))
		assert_int(w.waves.size()).is_equal(base.waves.size())
		var roles: Dictionary = ROLES[id]
		var base_roles: Dictionary = ROLES["hansan_1592"]
		for i in w.waves.size():
			var a: WaveData = w.waves[i]
			var b: WaveData = base.waves[i]
			assert_int(a.max_alive).is_equal(b.max_alive)
			assert_int(a.first_count).is_equal(b.first_count)
			assert_bool(a.elite_last).is_equal(b.elite_last)
			var mine := a.enemies.map(func(e: EnemyData) -> String: return _role(roles, e.id))
			var theirs := b.enemies.map(func(e: EnemyData) -> String: return _role(base_roles, e.id))
			assert_array(mine).override_failure_message("%s wave %d: %s" % [id, i, mine]).is_equal(theirs)
		assert_str(String(_st(id).elite.id)).is_equal(roles["elite"])


func _role(roles: Dictionary, enemy_id: StringName) -> String:
	for k in roles:
		if roles[k] == String(enemy_id):
			return k
	return "?" + String(enemy_id)


## 역할별 값은 한산 왜군과 같다 (근접 잡몹 체력만 무대 영웅 평타에 맞춤, 아래): 피해 15/20/25 급, 대기, 체력, 잡몹 경직 0.3초 + 맞으면 대기 다시.
func test_role_values_match_hansan() -> void:
	var keys := {"melee": ["contact_damage", "stagger_time", "hit_resets_attack"],
		"ranged": ["max_hp", "stagger_time", "hit_resets_attack"],
		"heavy": ["max_hp", "contact_damage", "super_armor"], "elite": ["max_hp", "contact_damage", "is_elite"]}
	for id in STAGES.slice(1):
		for role in keys:
			var mine := _enemy(ROLES[id][role])
			var base := _enemy(ROLES["hansan_1592"][role])
			for k in keys[role]:
				if role == "heavy" and k == "super_armor" and id == "chochungdo":
					continue  # 쇠똥벌레는 넘어지는 벌레 (버릇: 슈퍼아머 없음)
				assert_that(mine.get(k)).override_failure_message("%s.%s" % [mine.id, k]).is_equal(base.get(k))
			assert_float(mine.attack.cooldown).override_failure_message(String(mine.id)).is_equal(base.attack.cooldown)
			assert_int(mine.attack.damage).override_failure_message(String(mine.id)).is_equal(base.attack.damage)
			assert_float(mine.attack.windup).is_greater_equal(Enemy.ai_data().min_windup)
			assert_float(mine.rim_color.a).override_failure_message(String(mine.id)).is_greater(0.0)  # 테두리 빛
			assert_float(mine.ghost_body_alpha).is_equal(1.0)  # 불투명 몸


## 잡몹 떼: 근접 잡몹은 그 무대 영웅의 평타 두 대(무거운 3타면 한 대)에 죽고, 한 대로는 안 죽는다.
func test_trash_dies_in_one_or_two_hero_hits() -> void:
	for id in STAGES:
		var hero := load(StageSim.hero_of(_st(id))) as HeroData
		var hit := maxi(hero.attack.melee_damage, hero.attack.ranged_damage)
		var hp := _enemy(ROLES[id]["melee"]).max_hp
		assert_int(hp).override_failure_message("%s: hp %d, hit %d" % [id, hp, hit]).is_between(hit + 1, hit * 2)


## 떼는 근접 위주: 원거리는 한산 예전 수(2 · 1 · 3) 그대로, 물결 상한 6 · 8 · 10.
func test_swarm_is_melee_heavy_and_ranged_stays_few() -> void:
	for id in STAGES:
		var w := _st(id).waves
		var ranged := []
		var caps := []
		for wave: WaveData in w.waves:
			ranged.append(wave.enemies.filter(func(e: EnemyData) -> bool: return String(e.id) == ROLES[id]["ranged"]).size())
			caps.append(wave.max_alive)
		assert_array(ranged).override_failure_message(id).is_equal([2, 1, 3])
		assert_array(caps).override_failure_message(id).is_equal([6, 8, 10])
