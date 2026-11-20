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


## 상태 → 애니메이션 (피격 > 공격 중 > 이동 > 대기), 방향은 대상 쪽.
static func update(e: Enemy, busy: bool) -> void:
	var sheet := e.data.sprite_sheet
	var a := e.attack
	var anim := "idle"
	if e.flash_left() > 0.0 and sheet.has_anim("hit"):
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
	var lift := e.brain.hop_lift() if e.brain else 0.0
	e.sprite.position = e.data.sprite_offset * e.size_mult - Vector2(0, lift)
	e.sprite.modulate = flash_color(e)


## 피격 번쩍임 > 곧 친다는 번쩍임 > 원래 색. 매복 중이면 흐릿하게.
static func flash_color(e: Enemy) -> Color:
	var base := e.data.sprite_tint if e.data else Color.WHITE
	var feel := Feedback.feel_data()
	var f := e.flash_left()
	var c := base
	if f > 0.0:
		var v := 2.6 if f > feel.flash_time - feel.flash_peak_time else 1.8
		c = Color(v, v, v)
	elif e.attack and e.attack.windup_ratio() >= Enemy.ai_data().strike_flash_from:
		c = base * Enemy.ai_data().strike_flash
	c.a = e.brain.alpha() if e.brain else 1.0
	return c
