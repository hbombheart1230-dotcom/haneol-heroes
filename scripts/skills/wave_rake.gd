class_name WaveRake
extends Node2D
## 해일검기 긁기 (사용자: "다다다다다 파파파파팍이 없어, 너무 덩어리로 나가고"): 물결 앞머리가 처음 닿은 적을 잡아
## interval초마다 hits번 잘게 친다 (충전에 따라 타수 ↑). 총 피해·총 넉백은 그대로 나눠 마지막 타가 크게.
## 타마다 작은 접점 섬광·먹 튐·물보라·오르는 음높이의 짧은 소리, 숫자는 한 숫자로 쌓인다 (FxLayer.stack_key).
## 멈춤은 관통 중엔 없고, 물결과 모든 타가 끝나면 한 번 (SkillMultiHit.finale). 적 넉백 면역(보스·갑옷)은 apply_knockback 배율 그대로.
## 계획(plan)은 순수 계산이라 따로 시험한다.

var ctx: SkillContext
var dir: Vector2 = Vector2.UP
## 이 물결의 계획: 적마다 타별 피해·밀기 (plan()), 간격(초), 동시에 잡는 적 상한.
var damages := PackedInt32Array()
var pushes := PackedFloat32Array()
var interval: float = 0.065
var max_targets: int = 24
var spray: SkillVfxData
var spray_level: int = 0
var wave_alive: bool = true
## 붙은 물결 (시험·도구가 찾을 때).
var wave: Projectile
var total_hits: int = 0

var _en: Array[Enemy] = []
var _next := PackedFloat32Array()
var _done := PackedInt32Array()
var _age: float = 0.0
var _sound_i: int = 0


## 총 피해·총 넉백을 n타로 나눈다: 앞 타들은 1, 마지막 타는 last_weight 비중. 앞 타 밀기는 push_share를 나눠, 나머지는 마지막에.
## 반환: [피해들(PackedInt32Array, 합 = total), 밀기들(PackedFloat32Array, 합 = knockback)].
static func plan(total: int, n: int, last_weight: float, knockback: float, push_share: float) -> Array:
	n = maxi(n, 1)
	var dmg := PackedInt32Array()
	var push := PackedFloat32Array()
	dmg.resize(n)
	push.resize(n)
	var base := maxi(floori(total / (n - 1 + maxf(last_weight, 1.0))), 1) if n > 1 else total
	var left := total
	for i in n - 1:
		dmg[i] = mini(base, maxi(left - 1, 0))
		left -= dmg[i]
		push[i] = knockback * clampf(push_share, 0.0, 1.0) / (n - 1)
	dmg[n - 1] = left
	push[n - 1] = knockback * (1.0 - clampf(push_share, 0.0, 1.0)) if n > 1 else knockback
	return [dmg, push]


## 물결 p에 붙인다: 첫 타는 물결(HitBox)이 넣고, 나머지는 이 노드가 넣는다.
static func attach(p_ctx: SkillContext, p: Projectile, plan_v: Array, p_interval: float, cap: int) -> WaveRake:
	var r := WaveRake.new()
	r.ctx = p_ctx
	r.dir = p.direction
	r.wave = p
	r.damages = plan_v[0]
	r.pushes = plan_v[1]
	r.interval = p_interval
	r.max_targets = cap
	p.damage = r.damages[0]
	for a in p.actions:  # 이미 트리에 들어가 _ready가 피해 행동을 만들었다
		a.amount = r.damages[0]
	p.knockback = 0.0  # 밀기는 타마다 나눠서
	p.action_applied.connect(r.on_caught)
	p.tree_exiting.connect(r._on_wave_gone)  # 메서드 연결: 긁기가 먼저 사라져도 안전
	p_ctx.add_to_world(r, p.global_position)
	return r


func _on_wave_gone() -> void:
	wave_alive = false


## 물결 앞머리가 적에 닿았다 (첫 타 피해는 이미 들어갔다).
func on_caught(hb: HurtBox2D) -> void:
	var en := hb.get_parent() as Enemy if hb else null
	if en == null or not is_instance_valid(en):
		return
	total_hits += 1
	FxLayer.tag_last_number(en.get_instance_id(), en.global_position)
	en.apply_knockback(dir * pushes[0])
	if damages.size() <= 1:
		return
	if _en.size() >= max_targets:  # 상한: 남은 피해를 한 번에
		var rest := 0
		for i in range(1, damages.size()):
			rest += damages[i]
		ctx.hit(en, rest, false)
		en.apply_knockback(dir * pushes[pushes.size() - 1])
		return
	_en.append(en)
	_next.append(_age + interval)
	_done.append(1)


func _physics_process(delta: float) -> void:
	_age += delta
	var i := _en.size() - 1
	while i >= 0:
		if _next[i] <= _age:
			if not _strike(i):
				_remove(i)
			else:
				_next[i] += interval
				if _done[i] >= damages.size():
					_remove(i)
		i -= 1
	if not wave_alive and _en.is_empty():
		if total_hits > 0:
			SkillMultiHit.finale(ctx)  # 멈춤은 물결이 끝날 때 한 번
		queue_free()


## i번 적에게 다음 타. 반환: 계속할지 (죽었거나 사라졌으면 false).
func _strike(i: int) -> bool:
	var en := _en[i]
	if not is_instance_valid(en) or en.is_queued_for_deletion():
		return false
	var k := _done[i]
	var last := k == damages.size() - 1
	FxLayer.stack_key = en.get_instance_id()
	var ok := ctx.hit(en, damages[k], false)
	FxLayer.stack_key = 0
	if not ok:
		return false
	_done[i] = k + 1
	total_hits += 1
	en.apply_knockback(dir * pushes[k])
	var d := SkillMultiHit.data()
	var from := en.global_position - dir * 200.0
	HitImpact.on_enemy(en, from, HitImpact.data().skill_step if last else d.tick_step, ctx.spark_color())
	if spray:
		Feedback.vfx_burst(spray, en.global_position, dir, spray_level + (1 if last else 0))
	var fb := Feedback.instance
	if fb:
		if last:
			fb.play(d.rake_last_sfx, d.rake_gap)
		else:
			_sound_i += 1
			fb.play(d.rake_sfx, d.rake_gap, minf(d.rake_pitch + d.rake_pitch_step * (k - 1), d.rake_pitch_max))
	return en.health.is_alive()


func _remove(i: int) -> void:
	_en.remove_at(i)
	_next.remove_at(i)
	_done.remove_at(i)


## 물결 p에 붙은 긁기 (없으면 null).
static func of(p: Projectile) -> WaveRake:
	if p == null or not p.is_inside_tree():
		return null
	for n in p.get_parent().get_children():
		if n is WaveRake and (n as WaveRake).wave == p:
			return n
	return null


## 이 물결이 적 하나에 넣는 총 피해·총 밀기.
func total_damage() -> int:
	var t := 0
	for v in damages:
		t += v
	return t


func total_push() -> float:
	var t := 0.0
	for v in pushes:
		t += v
	return t
