class_name EnemySprite
extends RefCounted
## 적 스프라이트 만들기·고르기·색 (enemy.gd가 400줄을 넘지 않게 나눔).


static func setup(e: Enemy) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = e.data.sprite_sheet.shared_sprite_frames()
	s.scale = Vector2.ONE * e.data.sprite_scale * e.size_mult
	s.position = e.data.sprite_offset
	s.modulate = e.data.sprite_tint
	s.material = EnemyLook.material_for(e.data, e.affix)  # 군대별 테두리·밝기 (잘 보이게)
	e.add_child(s)
	return s


## 상태 → 애니메이션 (맞는 동작 > 공격 중 > 이동 > 대기), 방향은 대상 쪽.
static func update(e: Enemy, busy: bool) -> void:
	var sheet := e.data.sprite_sheet
	var a := e.attack
	var anim := "idle"
	var down := e.reaction != null and e.reaction.is_down()
	if down:  # 넘어짐 (B8): 넘어짐 동작이 있으면 그것, 없으면 맞는 동작 마지막 칸을 눕힌다 (pose)
		anim = "down" if sheet.has_anim("down") else ("hit" if sheet.has_anim("hit") else "idle")
	elif e.reaction and e.reaction.shows_hit_anim() and sheet.has_anim("hit"):
		anim = "hit"
	elif busy and a and sheet.has_anim(String(a.data.anim)):
		anim = String(a.data.anim)
	elif busy and sheet.has_anim("attack"):
		anim = "attack"
	elif e.velocity.length() > 10.0:
		anim = "run"
	var face := Vector2.DOWN
	if busy and a:
		face = a.aim_dir
	elif e.target and is_instance_valid(e.target):
		face = e.target.global_position - e.global_position
	var name_dir := StringName("%s_%d" % [anim, sheet.dir_index(face)])
	if e.sprite.animation != name_dir:
		e.sprite.play(name_dir)
	e.sprite.speed_scale = 1.0
	if down:
		var n := sheet.frame_count(anim)
		e.sprite.speed_scale = 0.0
		e.sprite.frame = mini(int(e.reaction.down_progress() * n), n - 1) if anim == "down" else n - 1
	elif busy and a and anim != "hit" and anim != "run":  # 무기와 피해 시점 맞추기 (W2): 예고·회복에 맞춰 칸을 직접 고른다
		e.sprite.speed_scale = 0.0
		e.sprite.frame = AttackTiming.enemy_frame(a.state == EnemyAttack.State.RECOVER, a.windup_ratio(),
			a.recover_ratio(), sheet.strike_frame(anim), sheet.frame_count(anim))
	pose(e, 0.0)


## 공격 동작의 맞닿는 프레임에서 무기 끝 (월드 좌표). 기록이 없으면 몸 가운데 + 겨눈 방향 × 몸 반경.
static func weapon_tip(e: Enemy, anim: String, dir: Vector2) -> Vector2:
	var fallback := dir.normalized() * e.body_radius * e.size_mult
	if e.sprite == null or e.data == null or e.data.sprite_sheet == null:
		return e.global_position + fallback
	var sheet := e.data.sprite_sheet
	var px := sheet.tip(anim, sheet.dir_index(dir), sheet.strike_frame(anim))
	return e.global_position + AttackTiming.tip_offset(px, e.sprite.position, e.sprite.scale, fallback)


## 맞는 동작을 첫 프레임부터 (개별 멈춤 동안은 이 프레임에 멈춘 채 떤다).
static func start_hit(e: Enemy) -> void:
	var sheet := e.data.sprite_sheet
	if not sheet.has_anim("hit"):
		return
	var face := Vector2.DOWN
	if e.target and is_instance_valid(e.target):
		face = e.target.global_position - e.global_position
	e.sprite.play(StringName("hit_%d" % sheet.dir_index(face)))
	e.sprite.frame = 0


## 그림 자세: 발 기준 눌림·젖힘·기울기 (판정은 그대로) + 멈춤 떨림(shake_px) + 뛰기 높이 + 색.
static func pose(e: Enemy, shake_px: float) -> void:
	var r := e.reaction
	var sq := r.squash_mult() if r else Vector2.ONE
	e.sprite.scale = Vector2.ONE * e.data.sprite_scale * e.size_mult * sq
	e.sprite.rotation = r.tilt() if r else 0.0
	if r and r.is_down() and not e.data.sprite_sheet.has_anim("down"):
		e.sprite.rotation = r.down_tilt(Feedback.feel_data().impact_data().down_tilt_deg)
	var off := e.data.sprite_offset * e.size_mult
	off.y *= sq.y  # 발(원점)은 제자리에 두고 몸만 눌린다
	var lift := (e.brain.hop_lift() if e.brain else 0.0) + (r.down_lift() if r else 0.0)
	e.sprite.position = off + (r.lean_offset() if r else Vector2.ZERO) + Vector2(shake_px, -lift)
	e.sprite.modulate = flash_color(e)
	if e.sprite.material:
		var feel := Feedback.feel_data()
		e.sprite.set_instance_shader_parameter(&"flash", r.flash_amount(e.flash_left(), feel.flash_time, feel.flash_peak_time) if r else 0.0)


## 피격 번쩍임 > 곧 친다는 번쩍임 > 원래 색. 매복 중이면 흐릿하게.
static func flash_color(e: Enemy) -> Color:
	var base := e.data.sprite_tint if e.data else Color.WHITE
	var feel := Feedback.feel_data()
	var f := e.flash_left()
	var c := base
	if f > 0.0 and e.sprite and e.sprite.material:
		pass  # 셰이더가 흰색을 섞는다 (pose). 곱하기 밝기는 어두운 그림을 하얗게 못 만든다
	elif f > 0.0:
		var v := 2.6 if f > feel.flash_time - feel.flash_peak_time else 1.8
		c = Color(v, v, v)
	elif e.attack and e.attack.windup_ratio() >= Enemy.ai_data().strike_flash_from:
		c = base * Enemy.ai_data().strike_flash
	c.a = e.brain.alpha() if e.brain else 1.0
	return c
