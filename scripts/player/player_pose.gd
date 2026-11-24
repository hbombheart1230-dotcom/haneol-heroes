class_name PlayerPose
extends RefCounted
## 영웅 그림 자세 (PlayerView에서 나눔): 착지 눌림·앞쏠림·연타 내딛기 유지. 판정·이동은 그대로, 상태는 PlayerView에.


## 착지: 눌림·멈춤 시간과 먹 방울·흔들림·밀림.
static func land(v: PlayerView) -> void:
	var h := v.player.hero if v.player else null
	if h == null:
		return
	v._land_left = h.land_time
	v._land_hold_left = h.land_hold
	var fb := Feedback.instance
	if fb == null:
		return
	var dir := v.player.get_dash_direction()
	if fb.kill_fx and h.land_drops > 0:
		fb.kill_fx.drops(v.player.global_position, dir, h.land_drops)
	if h.land_trauma > 0.0:
		fb.add_trauma(ImpactFx.capped_trauma(fb.trauma, h.land_trauma, fb.feel.impact_data().trauma_cap), dir)
	if h.land_kick_px > 0.0:
		fb.kick(dir, h.land_kick_px)


## 그림 자세 (무게감, 판정·이동은 그대로): 착지 눌림 + 멈출 때 앞쏠림. 발(원점)은 제자리.
static func tick(v: PlayerView, delta: float) -> void:
	var h := v.player.hero
	v._land_left = maxf(v._land_left - delta, 0.0)
	v._land_hold_left = maxf(v._land_hold_left - delta, 0.0)
	var has_input := v.player.move_input.length() > 0.1
	var walk := v.player.walk_velocity()
	if v._had_input and not has_input and walk.length() > v.player.move_speed * 0.5 and h.stop_slide_time > 0.0:
		v._slide_left = h.stop_slide_time
		v._slide_dir = walk.normalized()
	v._had_input = has_input
	v._slide_left = maxf(v._slide_left - delta, 0.0)
	var k := v._land_left / maxf(h.land_time, 0.001)
	var sq := Vector2.ONE.lerp(h.land_squash, k * k)
	v._sprite.scale = Vector2.ONE * h.sprite_scale * sq
	var lean := v._slide_dir * h.stop_slide_px * sin(PI * (1.0 - v._slide_left / maxf(h.stop_slide_time, 0.001))) 		if v._slide_left > 0.0 else Vector2.ZERO
	v._sprite.position = Vector2(h.sprite_offset.x, h.sprite_offset.y * sq.y) + lean
	if v._lunge != Vector2.ZERO or v._lunge_now != Vector2.ZERO:  # 내딛기 0인 타에서도 남은 위치는 돌아온다
		v._lunge_t += delta
		if v.is_moving():
			v._lunge = Vector2.ZERO
			v._lunge_now = Vector2.ZERO
		elif Feedback.feel_data().lunge_hold_combo and (v._oneshot_left > 0.0 or v._hold_left > 0.0):
			v._lunge_now = v._lunge_from.lerp(v._lunge, PlayerView.lunge_curve(v._lunge_t, v._lunge_out, INF))  # 나가서 연타 동안 유지
		else:  # 연타가 끝나면 제자리로
			v._lunge_now = v._lunge_now.move_toward(Vector2.ZERO, maxf(v._lunge.length(), v._lunge_now.length()) / maxf(v._lunge_back, 0.001) * delta)
			if v._lunge_now == Vector2.ZERO:
				v._lunge = Vector2.ZERO
		v._sprite.position += v._lunge_now
	v._sprite.position += v.player.bite.jitter()  # 칼이 박혀 멈춘 동안 잔떨림 (2D·3D 같은 _sprite)
	if v._land_hold_left > 0.0:
		v._sprite.speed_scale = 0.0
