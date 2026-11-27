class_name ZoneHopFx
extends RefCounted
## 구역 건너뛰기 뜀·공중·착지 연출 (ZoneHopFxData, ZoneHop이 부른다). 판정·움직임은 건드리지 않는다.
## Feedback이 없으면 아무 일도 안 함 (테스트 안전). 그림은 KillFx(먹 방울·자국, 한 번에 그림)와 입자(vfx_burst)만 쓴다.

var data: ZoneHopFxData
var _trail_left := 0.0
var _splash_i := 0
var _puff_left := 0.0


func _init(d: ZoneHopFxData) -> void:
	data = d


## 도움닫기 끝 (내닫기가 끝나 뛰어오르는 순간): 갑판 먼지·뒤로 먹 튐·발 구름·바람 소리.
func takeoff(pos: Vector2, dir: Vector2) -> void:
	_trail_left = 0.0
	_splash_i = 0
	var fb := Feedback.instance
	if data == null or fb == null:
		return
	_puff_left = 0.0
	if data.takeoff_vfx:
		Feedback.vfx_burst(data.takeoff_vfx, pos, -dir)
	if data.takeoff_puff_vfx:
		Feedback.vfx_burst(data.takeoff_puff_vfx, pos, -dir)
	if fb.kill_fx and data.takeoff_drops > 0:
		fb.kill_fx.drops(pos, -dir, data.takeoff_drops, data.drop_color)
	_play(fb, data.takeoff_stomp_sfx, data.takeoff_stomp_pitch)
	_play(fb, data.takeoff_wind_sfx, data.takeoff_wind_pitch)
	if data.takeoff_trauma > 0.0:
		fb.add_trauma(data.takeoff_trauma, dir)
	_zoom(fb, data.air_zoom, 0.3)


## 공중 (뛰어오름 진행 t 0~1): 그림 자리(art_pos) 뒤로 먹 꼬리, 정해진 몫에 바다 물보라(ground_pos).
func air(t: float, delta: float, ground_pos: Vector2, art_pos: Vector2, dir: Vector2) -> void:
	var fb := Feedback.instance
	if data == null or fb == null:
		return
	_trail_left -= delta
	if _trail_left <= 0.0 and fb.kill_fx and data.trail_drops > 0:
		_trail_left = maxf(data.trail_gap, 0.01)
		fb.kill_fx.drops(art_pos, -dir, data.trail_drops, data.drop_color)
	_puff_left -= delta
	if _puff_left <= 0.0 and data.trail_puff_vfx:
		_puff_left = maxf(data.trail_puff_gap, 0.02)
		Feedback.vfx_burst(data.trail_puff_vfx, art_pos, -dir)
	while _splash_i < data.splash_at.size() and t >= data.splash_at[_splash_i]:
		_splash_i += 1
		if data.splash_vfx:
			Feedback.vfx_burst(data.splash_vfx, ground_pos, Vector2.UP)


## 착지: 큰 먹 번짐·나무 조각·흔들림·짧은 멈춤·진동·착지음과 북.
func land(pos: Vector2, dir: Vector2, tree: SceneTree) -> void:
	var fb := Feedback.instance
	if data == null or fb == null:
		return
	if data.land_ink and fb.kill_fx:
		fb.kill_fx.death_burst(pos, &"smoke", true)
	if data.land_bloom_vfx:
		Feedback.vfx_burst(data.land_bloom_vfx, pos, Vector2.UP)
	if fb.kill_fx and data.land_drops > 0:
		fb.kill_fx.drops(pos, dir, data.land_drops, data.drop_color)
	if data.land_vfx:
		Feedback.vfx_burst(data.land_vfx, pos, Vector2.UP)
	if data.land_trauma > 0.0:
		fb.add_trauma(ImpactFx.capped_trauma(fb.trauma, data.land_trauma, fb.feel.impact_data().trauma_cap), dir)
	if data.land_stop > 0.0 and tree:
		GameTime.stop(tree, data.land_stop, data.land_stop_scale)
	fb.haptic(data.land_haptic_ms, data.land_haptic_amp)
	for k in data.land_sfx:
		_play(fb, StringName(k), data.land_pitch)
	_zoom(fb, 1.0, data.zoom_back)


func _play(fb: Feedback, kind: StringName, pitch: float) -> void:
	if kind != &"":
		fb.play(kind, 0.0, pitch)


## 카메라 줌을 기준(ImpactFx와 같은 base_zoom 메타) × mult로, secs초에 (실제 시간). mult 1 = 기준으로 돌아옴.
func _zoom(fb: Feedback, mult: float, secs: float) -> void:
	if fb.camera == null or (mult == 1.0 and not fb.camera.has_meta(&"base_zoom")):
		return
	var base: Vector2 = fb.camera.get_meta(&"base_zoom", fb.camera.zoom)
	fb.camera.set_meta(&"base_zoom", base)
	var old: Tween = fb.camera.get_meta(&"zoom_tween") if fb.camera.has_meta(&"zoom_tween") else null
	if old and old.is_valid():
		old.kill()
	var tw := fb.camera.create_tween().set_ignore_time_scale(true)
	tw.tween_property(fb.camera, "zoom", base * mult, maxf(secs, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fb.camera.set_meta(&"zoom_tween", tw)
