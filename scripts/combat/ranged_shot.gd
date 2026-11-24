class_name RangedShot
extends RefCounted
## 원거리 평타의 탄 (AutoAttack에서 나눔): 손을 떠나는 순간 다시 겨누기, 연타 번호대로 여러 발·큰 글자, 탄 만들기.
## 상태(손에 든 탄·글자 순서)는 AutoAttack에 그대로.


## 원거리 연타 번호대로 탄 여러 개(퍼짐)·큰 글자 (세종: 하나 → 둘 → 큰 하나).
static func spawn_step(a: AutoAttack, from: Vector2, dir: Vector2, d: BasicAttackData) -> void:
	var n := maxi(roundi(ComboSteps.at(d.ranged_step_count, a._release_step, 1.0)), 1)
	var k := ComboSteps.at(d.ranged_step_scale, a._release_step, 1.0)
	var dd := d
	if not is_equal_approx(k, 1.0):
		dd = d.duplicate()
		dd.glyph_px = roundi(d.glyph_px * k)
		dd.proj_size = d.proj_size * k
		dd.ranged_damage = roundi(d.ranged_damage * k)
	for i in n:
		var off := (i - (n - 1) * 0.5) * deg_to_rad(d.ranged_step_spread)
		spawn(a, from, dir.rotated(off), dd)


## 손을 떠나는 순간: 가장 가까운 적으로 다시 겨눈다. 그사이 적이 다 사라졌으면 던지지 않는다.
static func release(a: AutoAttack, enemy_list: Array) -> void:
	var d := a._release_data
	a._release_data = null
	if d == null or a._release_src != a.data:  # 영웅·데이터가 바뀌었으면 손에 든 탄은 버린다
		return
	var from := a.player.global_position
	var nearest: Node2D = null
	var best := d.ranged_range * d.ranged_range
	for n in enemy_list:  # 막 죽어 아직 지워지기 전인 적은 겨누지 않는다 (Codex 88d3160)
		var node := n as Node2D
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var h := node.get_node_or_null("Health") as Health
		if h and not h.is_alive():
			continue
		var d2 := from.distance_squared_to(node.global_position)
		if d2 <= best:
			best = d2
			nearest = node
	if nearest == null:
		return
	var to := nearest.global_position - from
	var dir := to.normalized() if to.length_squared() > 1.0 else a._release_dir
	var hand := from + a.release_point(dir, d)
	var aim := nearest.global_position - hand  # 손에서 적으로 (바로 앞 적 위로 날아가지 않게), 나가는 자리는 그대로 손
	var to_aim := aim.normalized() if aim.length_squared() > 1.0 else dir
	spawn_step(a, hand - a.release_point(to_aim, d), to_aim, d)


static func spawn(a: AutoAttack, from: Vector2, dir: Vector2, d: BasicAttackData) -> void:
	if a.projectile_scene == null:
		return
	var p := a.projectile_scene.instantiate() as Projectile
	p.direction = dir
	p.damage = d.ranged_damage
	p.speed = d.ranged_speed
	p.lifetime = d.ranged_lifetime
	p.knockback = d.ranged_knockback
	p.art = d.proj_art
	p.art_size = d.proj_size
	p.glyph_px = d.glyph_px
	p.trail_color = d.proj_trail_color
	p.trail_len = d.proj_trail_len
	if d.ranged_glyphs != "":
		p.glyph = d.ranged_glyphs[a._glyph_i % d.ranged_glyphs.length()]
		a._glyph_i += 1
	p.global_position = from + a.release_point(dir, d)  # 손·무기 끝에서
	var parent := a.projectile_parent if a.projectile_parent else a.player.get_parent()
	parent.add_child(p)
	a.projectile_fired.emit(p)
