class_name EnemyActions
extends RefCounted
## 적 공격 결과 처리 (enemy.gd가 400줄을 넘지 않게 나눔): 화살 발사, 돌진(빗나가면 더 미끄러짐), 혀로 끌어당기기.


static func on_attack_result(e: Enemy, r: EnemyAttack.Result) -> void:
	var d := e.attack.data
	play_sfx(d, false)  # 휘두름·내려침·발사 소리 (E1)
	if r == EnemyAttack.Result.FIRED:
		fire_arrow(e)
	elif d.kind == EnemyAttackData.Kind.CHARGE:
		var extra := d.miss_overshoot if r != EnemyAttack.Result.HIT else 0.0
		var end := e.attack.charge_end() + e.attack.aim_dir * extra
		e._charge_to(charge_stop(e, end) if e.data and e.data.boss_feel else end)
	if d.spawn_on_strike:
		plant(e, d)
	if d.kind == EnemyAttackData.Kind.PULL and r == EnemyAttack.Result.HIT and e.target is Player:
		var p := e.target as Player
		var to_me := e.global_position - p.global_position
		var dist := minf(d.pull_distance, maxf(to_me.length() - e.body_radius - p.body_radius, 0.0))
		p.apply_recoil(to_me.normalized() * dist, d.pull_time)


## 예고 자리(target_point)에 적을 세운다 (깃발 꽂기). 같은 적이 spawn_cap 이상 살아 있으면 세우지 않는다.
static func plant(e: Enemy, d: EnemyAttackData) -> void:
	var sp := e.get_parent() as EnemySpawner
	if sp == null:
		return
	var n := 0
	for c in sp.get_children():
		if c is Enemy and (c as Enemy).data == d.spawn_on_strike and not (c as Enemy).health.is_dead():
			n += 1
	if n < d.spawn_cap:
		sp.spawn_at(d.spawn_on_strike, sp.safe_point(e.attack.target_point, e.global_position, 60.0, 200.0))


## 돌진 끝을 벽·장애물·전장 끝 앞에서 멈춘다 (보스: 돌진이 벽을 뚫고 지나가지 않게). 길을 CHARGE_STEP px씩 짚는다.
const CHARGE_STEP := 20.0


static func charge_stop(e: Enemy, end: Vector2) -> Vector2:
	var sp := e.get_parent() as EnemySpawner
	if sp == null:
		return end
	var from := e.global_position
	var n := maxi(ceili(from.distance_to(end) / CHARGE_STEP), 1)
	var last := from
	var room := e.body_radius * e.size_mult
	var r := sp.arena_rect.grow(-room) if sp.arena_rect.has_area() else Rect2()
	for i in range(1, n + 1):
		var p := from.lerp(end, float(i) / n)
		if (r.has_area() and not r.has_point(p)) or (sp.blocked_check.is_valid() and bool(sp.blocked_check.call(p, room * 0.6))):
			return last
		last = p
	return end


## 화살·조총 탄은 무기 끝(맞닿는 프레임의 활·총구)에서 나가고, 조총은 거기서 불꽃이 터진다 (T2).
static func fire_arrow(e: Enemy) -> void:
	var d := e.attack.data
	var tip := EnemySprite.weapon_tip(e, String(d.anim), e.attack.aim_dir)
	var a := EnemyArrow.new()
	a.direction = e.attack.aim_dir
	a.setup(e.target as Player, tip, d)
	e.get_parent().add_child(a)
	if d.fire_vfx:
		Feedback.vfx_burst(d.fire_vfx, tip, e.attack.aim_dir)


## 공격 소리: 데이터에 적힌 것, 없으면 종류별 기본값 (EnemyAIData.attack_sfx).
static func sfx_for(d: EnemyAttackData, windup: bool) -> StringName:
	var own := d.windup_sfx if windup else d.strike_sfx
	if own != &"":
		return own
	var pair: Array = Enemy.ai_data().attack_sfx.get(int(d.kind), [])
	return pair[0 if windup else 1] if pair.size() == 2 else &""


static func play_sfx(d: EnemyAttackData, windup: bool) -> void:
	var k := sfx_for(d, windup)
	if k != &"" and Feedback.instance:
		Feedback.instance.play(k, 0.06)
