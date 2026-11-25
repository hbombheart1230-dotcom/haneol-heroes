class_name ComboSteps
extends RefCounted
## 연타 흐름 (타별 수치 읽기·전진 거리, 순수 로직). auto_attack.gd가 400줄을 넘지 않게 나눔.
## 배열은 1타부터 차례로, 모자라면 마지막 값, 비었으면 기본값.


static func at(arr: PackedFloat32Array, step: int, fallback: float) -> float:
	if arr.is_empty():
		return fallback
	return arr[clampi(step - 1, 0, arr.size() - 1)]


## 이번 타의 전진 거리(px): 데이터 값을 max로 자르고, 앞 적의 몸 안으로 들어가지 않게 (gap_to_enemy = 몸끼리
## 남은 거리, 적이 없으면 INF), 적 예고가 영웅을 덮고 있으면 0 (한 손 조작에서 원치 않는 이동 방지).
static func step_in(want: float, max_px: float, gap_to_enemy: float, in_danger: bool) -> float:
	if in_danger or want <= 0.0:
		return 0.0
	return clampf(minf(want, max_px), 0.0, maxf(gap_to_enemy, 0.0))


## 이번 타가 바라는 실제 전진(px): step 0 = 마무리(finisher_step_in_px), 대상이 없으면 step_in_no_target_mult배,
## 이동 막대가 반대쪽(step_in_against_input)이면 0. 적 몸·적 예고·위험 칸은 step_in과 StepGuard가 자른다.
static func want_step(d: BasicAttackData, step: int, dir: Vector2, has_target: bool, move_input: Vector2) -> float:
	var px := at(d.step_in_px, step, 0.0) if step > 0 else d.finisher_step_in_px
	if not has_target:
		px *= d.step_in_no_target_mult
	if move_input.length() > 0.3 and move_input.normalized().dot(dir) < d.step_in_against_input:
		return 0.0
	return px


## 적 목록 중 하나라도 공격 예고가 pos를 덮고 있는지.
static func in_windup(enemy_list: Array, pos: Vector2) -> bool:
	for n in enemy_list:
		if not is_instance_valid(n):  # 지워진 몹 (as 변환 전에, "freed object" 오류)
			continue
		var e := n as Enemy
		if e and e.attack and e.attack.state == EnemyAttack.State.WINDUP and e.attack.contains(pos):
			return true
	return false


## dir 쪽 가장 가까운 적까지 몸끼리 남은 거리 (부채꼴 cone_deg 안, 없으면 INF).
static func gap_ahead(enemy_list: Array, from: Vector2, dir: Vector2, my_radius: float, cone_deg: float = 60.0) -> float:
	var best := INF
	for n in enemy_list:
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e == null:
			continue
		var off := e.global_position - from
		var d := off.length()
		if d < 0.001 or dir.dot(off / d) < cos(deg_to_rad(cone_deg * 0.5)):
			continue
		best = minf(best, d - e.body_radius * e.size_mult - my_radius)
	return best


## 마무리 기술을 지금 낼 수 있는지: 휘두르던 칼이 닿았고 after초가 지났다 (F1, 3타가 보이게).
static func finisher_ready(atk: AutoAttack, after: float) -> bool:
	return atk == null or (atk._melee_left < 0.0 and atk._since_strike >= after)


## 휘두르는 중인지 (SwingGuardData): 칼이 닿기 전 · 4타 동작(busy) · 닿은 뒤 tail초.
static func swinging(atk: AutoAttack, tail: float) -> bool:
	return atk != null and (atk._melee_left >= 0.0 or atk.busy_left() > 0.0 or atk._since_strike < tail)


## 대시가 휘두름을 끊는다: 닿기 전 칼·전진을 버린다 (하데스 RushWeapon CanCancelDisables).
static func cancel_swing(atk: AutoAttack) -> void:
	if atk:
		atk._melee_left = -1.0
		atk._stepin_left = -1.0
		atk.lock.release()  # 대시하면 연타 대상도 풀림
		atk.busy_for(0.0)  # 마무리 동작도 대시로 끊긴다


## 평타 밀림: 3타 강타이고 heavy_launch_px가 있으면 크게 날리기 (사임당 3타 원 붓질), 아니면 넉백 (적 배율 반영).
static func push(en: Enemy, from: Vector2, kb: float, heavy: bool, d: BasicAttackData) -> void:
	var dir := (en.global_position - from).normalized()
	if heavy and d.heavy_launch_px > 0.0:
		launch(en, dir, d.heavy_launch_px)
	else:
		en.apply_knockback(dir * kb)


## 크게 날리기: 넉백과 같은 배율 (적 knockback_scale × 갑옷 poise — 보스·갑옷 정예는 0이라 안 날아가고
## 돌진도 멈추지 않는다).
static func launch(en: Enemy, dir: Vector2, px: float) -> void:
	if en == null or not is_instance_valid(en):
		return
	var f := Feedback.feel_data()
	var k := (en.data.knockback_scale if en.data else 1.0) * (en.poise.knockback_mult() if en.poise else 1.0)
	en.launch.start(dir, px * k, f.big_push_hold, f.big_push_time, f.big_push_hold_share)


## 큰 기술의 바깥 밀림: launch_px가 있으면 크게 날리기, 없으면 knockback 넉백 (center에서 바깥으로).
static func push_out(en: Enemy, center: Vector2, launch_px: float, knockback: float) -> void:
	var off := en.global_position - center
	var dir := off.normalized() if off.length_squared() > 0.01 else Vector2.RIGHT
	if launch_px > 0.0:
		launch(en, dir, launch_px)
	elif knockback > 0.0:
		en.apply_knockback(dir * knockback)

