class_name ImpactFx
extends RefCounted
## 던파식 연출 (feedback.gd가 400줄을 넘지 않게 나눔): 근접 무기 타격음 (B9), 3타째 강타의 흔들림·소리 (B4),
## 정예·보스 마무리 일격의 카메라 확대·한지색 번짐 (B7). Feedback이 없으면 아무 일도 안 함 → 테스트 안전.

const FLASH_NAME := &"FinisherFlash"
## 마지막으로 반격·뒤치기 글자를 띄운 시각 (화면 전체 간격 제한).
static var _last_label: float = -INF


## 반격·뒤치기 글자 + 그 색 먹 튐 (붓글씨 글자와 같은 결). label_min_gap보다 자주면 생략. 띄웠으면 true.
static func hit_label(fb: Feedback, pos: Vector2, bonus: int) -> bool:
	if fb == null or fb.fx == null:
		return false
	var im := fb.feel.impact_data()
	var lab := HitBonus.label(bonus, im)
	var now := Time.get_ticks_msec() / 1000.0
	if lab[0] == "" or now - _last_label < im.label_min_gap:
		return false
	_last_label = now
	fb.fx.add_label(pos, lab[0], lab[1])
	fb.fx.add_spark(pos + Vector2(0, -34), lab[1])
	return true


## 근접이 맞았을 때 무기 소리 (영웅마다 BasicAttackData.melee_hit_sfx), 강타면 강타 겹·흔들림·진동.
static func melee_hit(pos: Vector2, dir: Vector2, d: BasicAttackData, heavy: bool) -> void:
	var fb := Feedback.instance
	if fb == null or d == null:
		return
	if d.melee_hit_sfx != &"":
		fb.play(d.melee_hit_sfx)
	if not heavy:
		return
	var im := fb.feel.impact_data()
	if d.heavy_hit_sfx != &"":
		fb.play(d.heavy_hit_sfx, 0.0)
	fb.add_trauma(capped_trauma(fb.trauma, im.heavy_trauma, im.trauma_cap), dir)  # 겹친 흔들림 상한
	fb.kick(dir, im.heavy_kick_px)
	heavy_slow(fb.get_tree(), im)  # 칼 박힘 중에도 3타 늦은 감속 (박힘은 그림만 세우고, 감속은 그 뒤 시간 전체: 하데스처럼 닿고 조금 뒤)
	if im.heavy_gugak != &"":
		fb.play(im.heavy_gugak, im.heavy_gugak_gap)  # 꽹과리 한 타
	fb.haptic(fb.feel.haptic_impact_ms, fb.feel.haptic_impact_amp)
	if fb.kill_fx:
		fb.kill_fx.drops(pos, dir, fb.feel.hit_drops_heavy)


## 3타 강타의 늦은 감속: 닿고 heavy_slow_delay초(실제 시간) 뒤 GameTime으로 (겹침 규칙은 GameTime이 맡는다).
static func heavy_slow(tree: SceneTree, im: ImpactFeelData) -> void:
	if tree == null or im.heavy_slow_hold <= 0.0:
		return
	var go := func() -> void: GameTime.stop(tree, im.heavy_slow_hold + im.heavy_slow_back, im.heavy_slow_scale, im.heavy_slow_back)
	if im.heavy_slow_delay <= 0.0:
		go.call()
	else:
		tree.create_timer(im.heavy_slow_delay, true, false, true).timeout.connect(go)


## 지금 흔들림 now에 amount를 더하되 cap을 넘기지 않게 줄인 양.
static func capped_trauma(now: float, amount: float, cap: float) -> float:
	return clampf(minf(amount, cap - now), 0.0, amount)


## 마무리 일격: 카메라를 잠깐 당겼다 놓고 화면을 한지색으로 번지게. 슬로모션 중에도 실제 시간으로.
static func finisher(fb: Feedback) -> void:
	if fb == null or not fb.is_inside_tree():
		return
	var im := fb.feel.impact_data()
	if fb.camera and im.finisher_zoom > 1.0:
		var base: Vector2 = fb.camera.get_meta(&"base_zoom", fb.camera.zoom)
		fb.camera.set_meta(&"base_zoom", base)
		var old: Tween = fb.camera.get_meta(&"zoom_tween") if fb.camera.has_meta(&"zoom_tween") else null
		if old and old.is_valid():
			old.kill()
		var tw := fb.camera.create_tween().set_ignore_time_scale(true)
		tw.tween_property(fb.camera, "zoom", base * im.finisher_zoom, im.finisher_zoom_in) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(fb.camera, "zoom", base, im.finisher_zoom_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fb.camera.set_meta(&"zoom_tween", tw)
	if im.finisher_flash_alpha > 0.0:
		var rect := flash_rect(fb)
		rect.color = im.finisher_flash_color  # 한지색 번짐
		rect.modulate.a = im.finisher_flash_alpha
		var ft := rect.create_tween().set_ignore_time_scale(true)
		ft.tween_property(rect, "modulate:a", 0.0, im.finisher_flash_time)


## 화면 전체 번짐 막 (처음 한 번 만든다). 누르기는 막지 않는다.
static func flash_rect(fb: Feedback) -> ColorRect:
	var layer := fb.get_node_or_null(NodePath(FLASH_NAME)) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = FLASH_NAME
		layer.layer = 40
		var r := ColorRect.new()
		r.color = Color.WHITE
		r.modulate.a = 0.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(r)
		fb.add_child(layer)
	return layer.get_child(0) as ColorRect


## 결정타 국악 (꽹과리): 넷째 탭 마무리·반격·완전 충전 기술이 맞혔을 때만 (ImpactFeelData.accent_gugak).
static func skill_accent(fb: Feedback, slot: SkillCaster.Slot, hits: int, charge: float) -> void:
	var im := fb.feel.impact_data()
	if hits <= 0 or im.accent_gugak == &"":
		return
	var full := slot == SkillCaster.Slot.CHARGE and charge >= 0.999
	if slot == SkillCaster.Slot.TAP or slot == SkillCaster.Slot.COUNTER or full:
		fb.play(im.accent_gugak, im.accent_gugak_gap)
