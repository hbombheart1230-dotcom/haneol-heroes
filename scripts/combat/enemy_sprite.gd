class_name EnemySprite
extends RefCounted
## 적 스프라이트 만들기·고르기·색 (enemy.gd가 400줄을 넘지 않게 나눔).


static func setup(e: Enemy) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = e.data.sprite_sheet.shared_sprite_frames()
	s.scale = Vector2.ONE * e.data.sprite_scale * e.size_mult
	s.position = e.data.sprite_offset
	s.modulate = e.data.sprite_tint
	var shared := EnemyLook.material_for(e.data, e.affix)  # 군대별 테두리·밝기 (잘 보이게)
	s.material = shared.duplicate() if shared else null  # 적마다 하나 (번쩍임 값이 적마다 다르다)
	e.add_child(s)
	e.sprite = s
	EnemySprite3D.attach(e)  # 3D가 준비된 적(보스부터)은 3D 화면 한 칸으로 (끄면·없으면 구운 그림 그대로)
	return s


## 상태 → 애니메이션 (맞는 동작 > 공격 중 > 이동 > 대기), 방향은 대상 쪽.
static func update(e: Enemy, busy: bool) -> void:
	var sheet := e.data.sprite_sheet
	var a := e.attack
	var anim := "idle"
	var down := e.reaction != null and e.reaction.is_down()
	var posed := pose_anim(e)
	if posed != "" and not down:  # 정해진 시간 동안 보이는 동작 (보스 단계 전환 외침 등, BossStaging)
		anim = posed
		busy = false
	elif down:  # 넘어짐 (B8): 넘어짐 동작이 있으면 그것, 없으면 맞는 동작 마지막 칸을 눕힌다 (pose)
		anim = "down" if sheet.has_anim("down") else ("hit" if sheet.has_anim("hit") else "idle")
	elif e.launch and e.launch.active() and sheet.has_anim("fly"):  # 크게 날아가는 동안 (가벼운 적, HitWeightData)
		anim = "fly"
	elif e.reaction and e.reaction.shows_hit_anim() and sheet.has_anim("hit") 			and not (busy and e.reaction.tier != HitReaction.Tier.TRASH):  # 정예·우두머리는 공격 중이면 공격 자세 (맞음은 번쩍임·흔들림만)
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
	if anim == "fly":  # 날아간 만큼 칸을 고른다
		var nf := sheet.frame_count(anim)
		e.sprite.speed_scale = 0.0
		e.sprite.frame = mini(int(e.launch.progress() * nf), nf - 1)
	elif down:
		var n := sheet.frame_count(anim)
		e.sprite.speed_scale = 0.0
		e.sprite.frame = mini(int(e.reaction.down_progress() * n), n - 1) if anim == "down" else n - 1
	elif busy and a and anim != "hit" and not sheet.is_loop(anim):  # 무기와 피해 시점 맞추기 (W2): 예고·회복에 맞춰 칸을 직접 고른다 (돌진처럼 되풀이 동작은 그냥 돈다)
		e.sprite.speed_scale = 0.0
		e.sprite.frame = AttackTiming.enemy_frame(a.state == EnemyAttack.State.RECOVER, a.windup_ratio(),
			a.recover_ratio(), sheet.strike_frame(anim), sheet.frame_count(anim))
	EnemySprite3D.sync(e, anim, face, busy and a != null and anim != "hit" and not sheet.is_loop(anim) and not down)
	pose(e, 0.0)


## 정해진 시간(초, 시뮬 시계도 따르는 EnemyAttack.now_sec) 동안 anim을 보인다 (시트에 있을 때만). 처음부터 튼다.
static func show_pose(e: Enemy, anim: StringName, seconds: float) -> void:
	if e == null or e.data == null or e.data.sprite_sheet == null or not e.data.sprite_sheet.has_anim(String(anim)):
		return
	e.set_meta(&"pose", [String(anim), EnemyAttack.now_sec() + seconds])
	if e.sprite:
		e.sprite.stop()


static func pose_anim(e: Enemy) -> String:
	if not e.has_meta(&"pose"):
		return ""
	var p: Array = e.get_meta(&"pose")
	if EnemyAttack.now_sec() >= float(p[1]):
		e.remove_meta(&"pose")
		return ""
	return p[0]


## 공격 동작의 맞닿는 프레임에서 무기 끝 (월드 좌표). 기록이 없으면 몸 가운데 + 겨눈 방향 × 몸 반경.
static func weapon_tip(e: Enemy, anim: String, dir: Vector2) -> Vector2:
	var fallback := dir.normalized() * e.body_radius * e.size_mult
	if e.sprite == null or e.data == null or e.data.sprite_sheet == null:
		return e.global_position + fallback
	var sheet := e.data.sprite_sheet
	var px := sheet.tip(anim, sheet.dir_index(dir), sheet.strike_frame(anim))
	# 그림 자세(떨림·눌림·젖힘)는 빼고 쉬는 자리에서 (판정은 그대로, pose 머리말): 예고 끝 떨림은 실제 시계라
	# 같은 씨앗 시뮬에서도 탄이 나가는 자리가 달라졌다.
	var rest := Vector2.ONE * e.data.sprite_scale * e.size_mult
	return e.global_position + AttackTiming.tip_offset(px, e.data.sprite_offset * e.size_mult, rest, fallback)


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
	EnemySprite3D.restart_hit(e)


## 그림 자세: 발 기준 눌림·젖힘·기울기 (판정은 그대로) + 멈춤 떨림(shake_px) + 뛰기 높이 + 색.
## 예고 끝 몸 떨림 (px, 번쩍이는 동안만): 맞기 직전임을 몸으로도 알린다.
static func windup_shake(e: Enemy) -> float:
	var ai := Enemy.ai_data()
	if ai.windup_shake_px <= 0.0 or e.attack == null or not e.attack.is_flashing(ai.strike_flash_time):
		return 0.0
	return sin(Time.get_ticks_msec() * 0.001 * TAU * ai.windup_shake_hz) * ai.windup_shake_px


static func pose(e: Enemy, shake_px: float) -> void:
	var r := e.reaction
	var sq := r.squash_mult() if r else Vector2.ONE
	e.sprite.scale = Vector2.ONE * e.data.sprite_scale * e.size_mult * sq
	e.sprite.rotation = r.tilt() if r else 0.0
	if r and e.launch and e.launch.active() and not e.data.sprite_sheet.has_anim("fly"):  # 날아가는 동작이 없으면 그림을 돌린다 (launch_spin_deg)
		e.sprite.rotation += r.launch_spin(e.launch.progress(), e.launch.dir().x)
	if r and r.is_down() and not e.data.sprite_sheet.has_anim("down"):
		e.sprite.rotation = r.down_tilt(Feedback.feel_data().impact_data().down_tilt_deg)
	var off := e.data.sprite_offset * e.size_mult
	off.y *= sq.y  # 발(원점)은 제자리에 두고 몸만 눌린다
	var lift := (e.brain.hop_lift() if e.brain else 0.0) + (r.down_lift() if r else 0.0)
	e.sprite.position = off + (r.lean_offset() if r else Vector2.ZERO) + Vector2(shake_px + windup_shake(e), -lift)
	e.sprite.modulate = flash_color(e)
	if e.sprite.material:
		var feel := Feedback.feel_data()
		var m := e.sprite.material as ShaderMaterial
		m.set_shader_parameter(&"flash", r.flash_amount(e.flash_left(), feel.flash_time, feel.flash_peak_time) if r else 0.0)
		if r:
			m.set_shader_parameter(&"flash_color", r.data.flash_body())
			m.set_shader_parameter(&"flash_rim", r.data.flash_rim())


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
	elif e.attack and e.attack.is_flashing(Enemy.ai_data().strike_flash_time):  # 공통 규칙: 맞기 직전 번쩍
		c = base * Enemy.ai_data().strike_flash
	c.a = e.brain.alpha() if e.brain else 1.0
	return c
