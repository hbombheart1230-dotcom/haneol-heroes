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
		e._charge_to(e.attack.charge_end() + e.attack.aim_dir * extra)
	elif d.kind == EnemyAttackData.Kind.PULL and r == EnemyAttack.Result.HIT and e.target is Player:
		var p := e.target as Player
		var to_me := e.global_position - p.global_position
		var dist := minf(d.pull_distance, maxf(to_me.length() - e.body_radius - p.body_radius, 0.0))
		p.apply_recoil(to_me.normalized() * dist, d.pull_time)


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
