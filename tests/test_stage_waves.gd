extends GdUnitTestSuite
## 네 무대 물결·적 규칙이 한산과 같은 틀 (사용자: "스테이지 작업도 순신과 동일하게 다른 영웅들 것 맞춰줘").
## 물결: 6 · 3+정예 · 9, 상한 3·4·5, 한 마리씩 보충, xp ×3.5. 적은 역할(근접·원거리·중갑·정예)별로 한산 왜군과 같은 값,
## 군대마다의 버릇(돌진·숨기·거리, 공격 종류·사거리, 테두리 색)은 그대로.

## 물결마다 흩어져 나오는 원거리 졸 상한 (대형 구성원은 따로).
const RANGED_SCATTER_MAX: Array[int] = [0, 3, 0, 4]
const STAGES := ["hansan_1592", "manchuria_395", "gyeongbokgung_1433", "chochungdo"]
## 무대마다 역할 → 적 (한산이 기준). elite = 3물결 중간 보스 (StageTheme.elite), captain = 4물결에 섞이는 일반 정예.
const ROLES := {
	"hansan_1592": {"melee": "waegun_soldier", "ranged": "waegun_gunner", "heavy": "waegun_heavy", "elite": "waegun_elite", "captain": "waegun_captain"},
	"manchuria_395": {"melee": "chaser", "ranged": "archer", "heavy": "heavy", "elite": "elite_warrior", "captain": "elite_warrior_captain"},
	"gyeongbokgung_1433": {"melee": "jurchen_soldier", "ranged": "jurchen_archer", "heavy": "jurchen_heavy", "elite": "jurchen_elite", "captain": "jurchen_elite_captain"},
	"chochungdo": {"melee": "cc_mouse", "ranged": "cc_grasshopper", "heavy": "cc_beetle", "elite": "cc_mantis", "captain": "cc_mantis_captain"},
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
		for k in ["max_alive", "next_when_left", "refill_each", "warn_time", "one_pick_per_break", "pick_stacks"]:
			assert_that(w.get(k)).override_failure_message("%s.%s" % [id, k]).is_equal(base.get(k))
		assert_int(w.waves.size()).is_equal(base.waves.size())
		# 판 전체 처치 점수 (실제로 주는 값 = 적마다 반올림(xp × xp_mult), ScoreFeed.kill): 한산(282)의 95~120%.
		# 근접을 더해 물결 길이를 맞춘 무대(경복궁 +17%, 초충도 +6%)는 그만큼 더 준다 (잡몹 xp는 정수 1이라 깎을 수 없음).
		# 임시 조정, 0.4.3에서 재정비: 경복궁 4물결 근접 36→34로 흩어진 점수를 띠 안에 맞춤 (#258로 한산 흩어진 점수가 261로 내려감).
		# 0.4.3: 흩어진 + 대형 합으로 다시 비교하고, 모자란 무대(만주 0.906)를 올리는 쪽으로 (경복궁은 36 이상으로 되돌리기).
		# 대형 구성원은 무대마다 수가 다르다 (한산 8 · 만주 5 · 경복궁 6 · 초충도 6): 무대 사이 비교는 흩어진 적·정예로, 대형 몫은 따로 찍는다.
		var score := _stage_score(id)
		var base_score := _stage_score("hansan_1592")
		print("[stage-score] %s %d + 대형 %d (한산 %d + %d)" % [id, score, _stage_score(id, true) - score, base_score, _stage_score("hansan_1592", true) - base_score])
		assert_int(score).override_failure_message("%s score %d (한산 %d)" % [id, score, base_score]).is_between(roundi(base_score * 0.95), roundi(base_score * 1.2))
		var roles: Dictionary = ROLES[id]
		var base_roles: Dictionary = ROLES["hansan_1592"]
		for i in w.waves.size():
			var a: WaveData = w.waves[i]
			var b: WaveData = base.waves[i]
			assert_int(a.max_alive).override_failure_message("%s wave %d cap" % [id, i]).is_equal(b.max_alive)
			assert_int(a.first_count).is_equal(b.first_count)
			assert_bool(a.elite_last).is_equal(b.elite_last)
			assert_int(a.elite_when_left).is_equal(b.elite_when_left)
			var mine := a.enemies.map(func(e: EnemyData) -> String: return _role(roles, e.id))
			var theirs := b.enemies.map(func(e: EnemyData) -> String: return _role(base_roles, e.id))
			# 역할별 수: 원거리·중갑·정예는 한산과 같고, 근접 잡몹은 한산 이상 (영웅이 물결을 빨리 지우는 무대는 근접을 더해
			# 물결 길이를 맞춘다: 경복궁 세종·초충도 사임당, test_stage_sim 길이 비율 0.75)
			for role in ["ranged", "heavy", "captain", "melee"]:
				var n_mine := mine.count(role)
				var n_base := theirs.count(role)
				if role == "ranged":  # 흩어진 원거리는 한산 이하, 원거리 대형은 영웅마다 모양·수가 다르다 (아래 대형 시험)
					assert_int(n_mine).override_failure_message("%s wave %d ranged %d" % [id, i, n_mine]).is_less_equal(maxi(n_base, RANGED_SCATTER_MAX[i]))
				elif role == "melee":
					assert_int(n_mine).override_failure_message("%s wave %d melee %d" % [id, i, n_mine]).is_greater_equal(n_base)
				else:
					assert_int(n_mine).override_failure_message("%s wave %d %s" % [id, i, role]).is_equal(n_base)
			assert_bool(mine.all(func(r: String) -> bool: return not r.begins_with("?"))).override_failure_message("%s wave %d: %s" % [id, i, mine]).is_true()
			for f: FormationData in a.formations:  # 대형은 그 무대 군대의 원거리 졸 (사용자: 원거리 대형으로 확 쓸어버리게)
				assert_str(_role(roles, f.member.id)).override_failure_message("%s wave %d formation" % [id, i]).is_equal("ranged")
		assert_str(String(_st(id).elite.id)).is_equal(roles["elite"])
		assert_object(_st(id).elite.boss_feel).override_failure_message("%s mid-boss" % id).is_not_null()  # 3물결 중간 보스


## 판 전체 처치 점수: 적마다 반올림(xp × xp_mult) (정예 자리는 무리 전부 또는 무대 정예 하나).
func _stage_score(id: String, with_formations: bool = false) -> int:
	var w := _st(id).waves
	var n := 0
	for wave: WaveData in w.waves:
		var list: Array = wave.enemies.duplicate()
		if wave.elite_last:
			list.append_array(wave.elite_group if not wave.elite_group.is_empty() else [_enemy(ROLES[id]["elite"])])
		for e: EnemyData in list:
			n += roundi(e.xp * w.xp_mult)
		for f: FormationData in (wave.formations if with_formations else []):  # 대형 구성원도 처치 점수를 준다 (× FormationData.xp_mult)
			n += roundi(f.count * f.member.xp * w.xp_mult * f.xp_mult)  # 대형은 소수로 쌓인다 (ScoreFeed)
	return n


func _group_xp(wave: WaveData) -> float:
	var t := 0.0
	for e: EnemyData in wave.elite_group:
		t += e.xp
	return t


func _role(roles: Dictionary, enemy_id: StringName) -> String:
	for k in roles:
		if roles[k] == String(enemy_id):
			return k
	return "?" + String(enemy_id)


## 역할별 값은 한산 왜군과 같다 (근접 잡몹 체력만 무대 영웅 평타에 맞춤, 아래): 피해 15/20/25 급, 대기, 체력, 잡몹 경직 0.3초 + 맞으면 대기 다시.
func test_role_values_match_hansan() -> void:
	var keys := {"melee": ["contact_damage", "stagger_time", "hit_resets_attack"],
		"ranged": ["max_hp", "stagger_time", "hit_resets_attack"],
		"heavy": ["max_hp", "contact_damage", "super_armor"], "captain": ["max_hp", "contact_damage", "is_elite"],
		"elite": ["contact_damage", "is_elite"]}  # 체력은 무대마다 다르다 (한산은 무리 셋, 영웅 배율·궁합)  # 처치 점수는 3물결 합으로 (한산은 무리 셋의 합, 위 시험)
	for id in STAGES.slice(1):
		for role in keys:
			var mine := _enemy(ROLES[id][role])
			var base := _enemy(ROLES["hansan_1592"][role])
			for k in keys[role]:
				if role == "heavy" and k == "super_armor" and id == "chochungdo":
					continue  # 쇠똥벌레는 넘어지는 벌레 (버릇: 슈퍼아머 없음)
				assert_that(mine.get(k)).override_failure_message("%s.%s" % [mine.id, k]).is_equal(base.get(k))
			if role == "elite":  # 중간 보스: 공격은 무대마다 다르다 (tests/test_mid_boss.gd가 규칙을 본다)
				continue
			assert_float(mine.attack.cooldown).override_failure_message(String(mine.id)).is_equal(base.attack.cooldown)
			assert_int(mine.attack.damage).override_failure_message(String(mine.id)).is_equal(base.attack.damage)
			assert_float(mine.attack.windup).is_greater_equal(Enemy.ai_data().min_windup)
			assert_float(mine.rim_color.a).override_failure_message(String(mine.id)).is_greater(0.0)  # 테두리 빛
			assert_float(mine.ghost_body_alpha).is_equal(1.0)  # 불투명 몸


## 잡몹 떼: 근접 잡몹은 그 무대 영웅의 평타 두 대(무거운 3타면 한 대)에 죽고, 한 대로는 안 죽는다.
## 잡몹은 한 타에 죽지 않고, 세 타 이내 그리고 첫 타가 닿은 뒤 처치까지 TRASH_KILL_TIME초 이내 (손 평타 간격으로 잰다).
## 예전 규칙 "한두 타"를 바꾼 까닭: 순신 쾌검(#167, 한 타 13 → 10, 0.25초 간격)은 타 수가 늘어도 더 빨리 죽인다 —
## 잡몹 체력은 그대로 (사용자 2026-11-24 "너무 종잇장 같으면 타격감이 없음"), 느린 영웅은 시간 때문에 종전처럼 한두 타.
const TRASH_MAX_HITS := 3
const TRASH_KILL_TIME := 0.6


## 영웅이 잡몹 하나를 죽이는 [타 수, 첫 타 뒤 처치까지 초] (손 평타 박자: 평타 간격 × 타별 간격 배율).
static func trash_kill(hero: HeroData, hp: int) -> Array:
	var a := hero.attack
	var hit := maxi(a.melee_damage, a.ranged_damage)
	var hits := ceili(float(hp) / maxf(hit, 1))
	var interval := a.ranged_interval if hero.kit and hero.kit.ranged_taps else a.melee_interval
	var t := 0.0
	for k in range(2, hits + 1):
		t += interval * ComboSteps.at(a.step_gap_mults, k, hero.kit.tap_min_gap_mult if hero.kit else 1.0)
	return [hits, t]


func test_trash_dies_fast_but_not_in_one_hit() -> void:
	for id in STAGES:
		var hero := load(StageSim.hero_of(_st(id))) as HeroData
		var hp := _enemy(ROLES[id]["melee"]).max_hp
		var r := trash_kill(hero, hp)
		var msg := "%s: hp %d, %d hits, %.2fs" % [id, hp, r[0], r[1]]
		print("[trash-kill] " + msg)
		assert_int(r[0]).override_failure_message(msg).is_between(2, TRASH_MAX_HITS)
		assert_float(r[1]).override_failure_message(msg).is_less_equal(TRASH_KILL_TIME + 0.001)


## 떼는 근접 위주: 흩어진 원거리는 물결마다 적게 (0 · 3 · 0 · 4 이하), 물결 상한 8 · 10 · 8 · 14 (사용자: 5웨이브, 약 4분).
## 원거리를 늘리는 것은 흩어 내지 않고 대형 한 묶음으로 (FormationData, 같은 순간 겨눔·일제 사격).
func test_swarm_is_melee_heavy_and_ranged_stays_few() -> void:
	for id in STAGES:
		var w := _st(id).waves
		var ranged := []
		var caps := []
		for wave: WaveData in w.waves:
			ranged.append(wave.enemies.filter(func(e: EnemyData) -> bool: return String(e.id) == ROLES[id]["ranged"]).size())
			caps.append(wave.max_alive)
		for i in ranged.size():
			assert_int(ranged[i]).override_failure_message("%s wave %d scattered ranged %s" % [id, i, ranged]).is_less_equal(RANGED_SCATTER_MAX[i])
		assert_array(caps).override_failure_message(id).is_equal([8, 10, 8, 14])  # 3물결은 중간 보스 물결 (잡몹 여섯 → 중간 보스)


## 잡몹은 닿기만 해서는 피해가 없다: 모든 피해는 붉은 먹 예고를 거친 공격으로만 (정예·보스 접촉은 따로).
func test_trash_has_no_contact_damage() -> void:
	for id in STAGES:
		for role in ["melee", "ranged", "heavy"]:
			var d := _enemy(ROLES[id][role])
			assert_int(d.contact_damage).override_failure_message(String(d.id)).is_equal(0)
