class_name BossPhases
extends RefCounted
## 보스 단계 (EnemyData.phases, 하데스식 66%·33%): 체력이 단계 문턱 아래로 내려가면 공격 목록 바꾸기·주기 단축,
## 부하 부르기(먹 번짐 예고 뒤), 잠깐 무적, 북소리·낙인. 단계 계산은 순수 함수라 테스트에서 직접 부른다.


## 지금 들어가야 할 단계 번호 (phases 순서, 없으면 current 그대로). current = 이미 들어간 단계 수.
static func due(phases: Array, current: int, hp_frac: float) -> int:
	var i := current
	while i < phases.size() and hp_frac <= (phases[i] as BossPhaseData).hp_frac:
		i += 1
	return i


## 쿨타임을 mult배 한 공격 목록 사본 (공유 리소스를 바꾸지 않게).
static func scaled_patterns(list: Array, mult: float) -> Array:
	var out: Array = []
	for p in list:
		var a := (p as EnemyAttackData).duplicate() as EnemyAttackData
		a.cooldown *= mult
		out.append(a)
	return out


## 맞은 뒤 (Enemy._on_damaged, 살아 있을 때): 문턱을 넘었으면 새 단계로 (한 번에 여러 단계면 마지막 단계 것).
static func on_damaged(e: Enemy) -> void:
	if e.data == null or e.data.phases.is_empty():
		return
	var frac := float(e.health.current) / maxf(e.health.max, 1)
	var target := due(e.data.phases, e.phase_index, frac)
	if target == e.phase_index:
		return
	e.phase_index = target
	enter(e, e.data.phases[target - 1])


static func enter(e: Enemy, ph: BossPhaseData) -> void:
	if e.attack:
		e.attack.cancel()
		if not ph.patterns.is_empty():
			e.attack.set_patterns(scaled_patterns(ph.patterns, ph.cooldown_mult))
	e.phase_invuln = ph.invuln_time
	var stg := BossStaging.of(e)
	var sp := e.get_parent() as EnemySpawner
	if stg:
		stg.on_phase(ph)  # 한 박자 쉬고 강화 → 부하 (BossFeelData)
	elif sp:
		for i in ph.summon.size():
			var off := Vector2.from_angle(TAU * i / maxf(ph.summon.size(), 1)) * (e.body_radius * e.size_mult + 120.0)
			var r := off.length()
			sp.warn_spawn(ph.summon[i], sp.safe_point(e.global_position + off, e.global_position, r, r + 80.0))  # 벽 속 소환 방지 (Codex 3ceebe3)
		sp.breather.emit(false)  # 쌓인 강화를 연다
	var fb := Feedback.instance
	if fb:
		fb.play(&"gugak_kill", 0.0)  # 북·징 (파일이 있을 때만)
		fb.play(&"confirm_big", 0.0)
		fb.add_trauma(fb.feel.poise_trauma)
		if fb.fx:
			fb.fx.add_label(e.global_position + Vector2(0, -e.body_radius * 2.0), ph.seal_label, Ink.SEAL)
			if ph.seal_art:
				fb.fx.add_fall(ph.seal_art, e.global_position + Vector2(0, -260), e.global_position, 0.3, 180.0, 90.0)  # 낙인은 똑바로 선 채 떨어진다
