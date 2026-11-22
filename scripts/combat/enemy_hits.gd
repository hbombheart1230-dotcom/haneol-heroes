class_name EnemyHits
extends RefCounted
## 적이 맞았을 때의 던파식 처리 (enemy.gd가 400줄을 넘지 않게 나눔, docs/research/dnf_benchmark.md):
## 반격·뒤치기 판정, 슈퍼아머 없는 잡몹의 예고 끊김 (B1), 3타째 강타의 멈춤·넘어짐 (B4·B8).


static func impact() -> ImpactFeelData:
	return Feedback.feel_data().impact_data()


## 적이 보는 방향: 공격 중이면 겨눈 쪽, 걷는 중이면 걷는 쪽, 아니면 영웅 쪽.
static func body_facing(e: Enemy) -> Vector2:
	if e.attack and e.attack.is_busy():
		return e.attack.aim_dir
	if e.velocity.length_squared() > 100.0:
		return e.velocity.normalized()
	return e._dir_to_target()


## 지금 맞으면 반격·뒤치기인지 (HitBonus 깃발). 적 → 영웅 방향으로 판정한다 (때리는 쪽은 늘 영웅).
static func bonus_flags(e: Enemy) -> int:
	var windup := e.attack != null and e.attack.state == EnemyAttack.State.WINDUP
	return HitBonus.flags(windup, body_facing(e), e._dir_to_target(), impact().back_arc_deg)


## 슈퍼아머 (중장병) 또는 잡몹이 아님: 끊기지도 넘어지지도 않는다.
static func is_armored(e: Enemy) -> bool:
	return e.reaction == null or e.reaction.tier != HitReaction.Tier.TRASH or (e.data != null and e.data.super_armor)


## 피해를 받고 살아 있을 때 (Enemy._on_damaged). heavy = 영웅 3타째 강타.
static func on_hit(e: Enemy, heavy: bool) -> void:
	var d := impact()
	if not is_armored(e) and e.attack and e.attack.can_interrupt():
		e.attack.interrupt(d.interrupt_cooldown, d.interrupt_rearm)
		e.reaction.stagger_left = maxf(e.reaction.stagger_left, d.interrupt_stagger)
		e._stop_charge()
	if heavy:
		e.freeze(d.heavy_freeze)
		knock_down(e)


## 넘어뜨리기 (잡몹, 슈퍼아머 아님): 예고를 버리고 돌진을 멈춘다. 넘어졌으면 true.
static func knock_down(e: Enemy) -> bool:
	if is_armored(e) or not e.reaction.knock_down(impact()):
		return false
	if e.attack:
		e.attack.cancel()
	e._stop_charge()
	return true


## 갑옷 깨짐(정예) · 휘청(보스): 기절 저항(stun_scale)과 무관하게 정해진 시간 멈추고 맞는 동작.
static func on_poise(e: Enemy, ev: EnemyPoise.Event) -> void:
	if ev == EnemyPoise.Event.NONE:
		return
	var broke := ev == EnemyPoise.Event.ARMOR_BREAK
	e._stun_left = maxf(e._stun_left, Enemy.AI.armor_break_stun if broke else Enemy.AI.boss_stagger_time)
	if e.attack:
		e.attack.cancel()
	e._stop_charge()
	if e.reaction and e.sprite:
		e.reaction.anim_left = e.reaction.data.hit_anim_time
		EnemySprite.start_hit(e)
	Feedback.poise_broken(e.global_position, broke)


## 피해 숫자 모양: 2 = 강타, 1 = 큰 피해, 0 = 보통.
static func number_style(applied: int, heavy: bool) -> int:
	if heavy:
		return 2
	return 1 if applied >= Feedback.feel_data().big_hit_damage else 0
