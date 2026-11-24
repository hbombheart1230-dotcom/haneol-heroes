class_name BossFinaleFx
extends RefCounted
## 보스 처치 연출 (BossStaging.play_finale): 정예 마무리(ImpactFx.finisher)보다 한 단계 크게.
## 카메라 확대가 들어가 머물렀다 돌아오고, 한지색 번짐이 진하게 덮였다 천천히 빠진다 (실제 시간).
## 화면 흔들림은 더하지 않는다 (마무리 일격이 이미 한 번 흔든다: 큰 순간에만 한 번).
## Feedback이 없으면(테스트) 아무 일도 안 함.


static func play(fb: Feedback, f: BossFeelData) -> void:
	if fb == null or not fb.is_inside_tree() or f == null:
		return
	if fb.camera and f.finale_zoom > 1.0:
		var base: Vector2 = fb.camera.get_meta(&"base_zoom", fb.camera.zoom)
		var old: Tween = fb.camera.get_meta(&"zoom_tween") if fb.camera.has_meta(&"zoom_tween") else null
		if old and old.is_valid():
			old.kill()  # 정예용 짧은 확대 대신 길게
		var tw := fb.camera.create_tween().set_ignore_time_scale(true)
		tw.tween_property(fb.camera, "zoom", base * f.finale_zoom, f.finale_zoom_in) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(f.finale_zoom_hold)
		tw.tween_property(fb.camera, "zoom", base, f.finale_zoom_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fb.camera.set_meta(&"zoom_tween", tw)
	if f.finale_flash_alpha > 0.0:
		var rect := ImpactFx.flash_rect(fb)
		rect.color = fb.feel.impact_data().finisher_flash_color  # 한지색
		rect.modulate.a = f.finale_flash_alpha
		var ft := rect.create_tween().set_ignore_time_scale(true)
		ft.tween_property(rect, "modulate:a", 0.0, f.finale_flash_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fb.haptic(fb.feel.haptic_finisher_ms * 3, 1.0)  # 길게 한 번 (흔들림 대신 손에)
