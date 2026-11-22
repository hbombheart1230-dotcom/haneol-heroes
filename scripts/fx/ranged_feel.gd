class_name RangedFeel
extends RefCounted
## 원거리 평타 한 발의 타격감 (근접 "한 방"과 같은 수준, 값은 RangedFeelData):
## 쏘는 순간 = 무기 끝 섬광·먹 튐·영웅 반동·발사음 / 날아가는 탄 = 약한 빛 /
## 맞는 순간 = 접점 섬광(HitImpact, 탄 방향 줄기)·퍽·진동·탄 방향 밀림·탄이 부서져 흩어짐, 3번째(강타)는 근접 3타와 같은 규칙 /
## 빗나가 사라질 때 = 먹으로 풀림. 적의 번쩍임·젖혀짐·경직·공격 끊기·피해 숫자는 피해를 받는 쪽(Enemy)이 근접과 똑같이 처리한다.
## AutoAttack.projectile_fired에 붙는다 (AutoAttack._ready 한 줄). Feedback이 없으면 그림·소리 없이 밀림만 (테스트 안전).

static var _layer: RangedFxLayer
static var _glow_mat: CanvasItemMaterial


static func data() -> RangedFeelData:
	return RangedFeelData.get_default()


## 그림 층 (Feedback.fx 아래에 처음 쓸 때 한 번 만든다).
static func layer() -> RangedFxLayer:
	var fb := Feedback.instance
	if fb == null or fb.fx == null or not fb.fx.is_inside_tree():
		return null
	if _layer == null or not is_instance_valid(_layer) or _layer.get_parent() != fb.fx:
		_layer = RangedFxLayer.new(data())
		fb.fx.add_child(_layer)
	return _layer


static func attach(a: AutoAttack) -> void:
	if a == null or a.has_meta(&"ranged_feel"):
		return
	a.set_meta(&"ranged_feel", true)
	BrushFlick.attach(a)  # 사임당 중거리 먹 털기 (같은 연결 지점)
	a.projectile_fired.connect(func(p: Projectile) -> void: on_fired(a, p))


## 탄 색 (영웅별 꼬리 색을 불투명하게).
static func color_of(a: AutoAttack) -> Color:
	var c := a.stats().proj_trail_color if a else Color(0.9, 0.9, 1.0)
	return Color(c, 1.0)


## 손을 떠난 순간 (탄은 이미 무기 끝에 놓였다).
static func on_fired(a: AutoAttack, p: Projectile) -> void:
	if p == null:
		return
	var d := data()
	var step := clampi(a._release_step if a else 1, 1, 3)
	var col := color_of(a)
	var dir := p.direction
	p.set_meta(&"ranged_step", step)
	if d.speed_mult > 0.0 and not is_equal_approx(d.speed_mult, 1.0):  # 빠르게, 닿는 거리는 그대로
		p.speed *= d.speed_mult
		p.lifetime /= d.speed_mult
	add_glow(p, d, col)
	var l := layer()
	if l:
		l.muzzle(p.global_position, dir, step, col)
	var fb := Feedback.instance
	if fb:
		if d.launch_sfx != &"":
			fb.play(d.launch_sfx, d.launch_gap, HitImpactData.at_f(d.launch_pitch, step, 1.0))
		if fb.kill_fx:
			fb.kill_fx.drops(p.global_position, dir, HitImpactData.at_i(d.muzzle_drops, step, 2))
	var px := HitImpactData.at_f(d.recoil_px, step, 0.0)
	if a and a.player and px > 0.0:
		a.player.apply_recoil(-dir * px, d.recoil_time)  # 쏜 반대쪽으로 살짝 (근접 lunge의 반대)
	p.action_applied.connect(func(hb: HurtBox2D) -> void: on_hit(p, hb, step, col))
	p.tree_exiting.connect(func() -> void: on_gone(p, col))


## 탄 밑의 약한 더하기 빛 (어두운 바닥에서 읽히게). 탄과 함께 돌고 커진다.
static func add_glow(p: Projectile, d: RangedFeelData, col: Color) -> Sprite2D:
	if d.glow_alpha <= 0.0:
		return null
	if _glow_mat == null:
		_glow_mat = CanvasItemMaterial.new()
		_glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var g := Sprite2D.new()
	g.name = "RangedGlow"
	g.texture = VfxTextures.get_texture(SkillVfxData.Shape.DOT)
	g.material = _glow_mat
	g.show_behind_parent = true
	g.modulate = Color(col, d.glow_alpha)
	var sz := shot_size(p)
	var ts := g.texture.get_size()
	g.scale = Vector2(sz.x * d.glow_scale.x / ts.x, sz.y * d.glow_scale.y / ts.y)
	g.position = Vector2(-sz.x * 0.1, 0.0) if p.art else Vector2.ZERO  # 탄 그림은 앞 40%·뒤 60%
	p.add_child(g)
	return g


## 탄 그림 크기 (글자탄은 글자 칸).
static func shot_size(p: Projectile) -> Vector2:
	return p.art_size if p.art else Vector2.ONE * float(p.glyph_px)


## 적 하나에 닿음 (관통탄은 적마다). 피해는 이미 들어갔다.
static func on_hit(p: Projectile, hb: HurtBox2D, step: int, col: Color) -> void:
	var en := hb.get_parent() as Enemy if hb else null
	if en == null or not is_instance_valid(en):
		return
	var d := data()
	var dir := p.direction
	en.apply_knockback(dir * d.knock_extra(step))  # 탄 방향으로 툭 (BasicAttackData.ranged_knockback에 더함)
	var from := en.global_position - dir * 200.0  # 탄이 온 쪽: 섬광 줄기가 탄 진행 방향으로 튄다
	HitImpact.on_enemy(en, from, step, col)
	var first := p.hits <= 1
	if first:
		HitImpact.on_swing(step)  # 퍽 (연타 번호별 음높이) + 짧은 진동, 한 발에 한 번
	if not p.pierce:
		p.set_meta(&"ranged_burst", true)
		var at := HitImpact.contact_point(en, from) if Feedback.instance else en.global_position
		var l := layer()
		if l:
			l.burst(at, dir, step, col, p.art, shot_size(p) * p.size_scale, p.glyph)
		var fb := Feedback.instance
		if fb and fb.kill_fx:
			fb.kill_fx.drops(at, dir, HitImpactData.at_i(d.burst_drops, step, 3))
	if first and d.is_heavy(step):
		heavy(en, dir)


## 강타 (근접 3타와 같은 규칙): 적 멈춤·잡몹 넘어짐, 흔들림·밀림·늦은 감속·꽹과리·강한 진동.
static func heavy(en: Enemy, dir: Vector2) -> void:
	var fb := Feedback.instance
	var im := fb.feel.impact_data() if fb else ImpactFeelData.new()
	if en and is_instance_valid(en) and en.health and en.health.is_alive():
		en.freeze(im.heavy_freeze)
		EnemyHits.knock_down(en)
	if fb == null:
		return
	fb.add_trauma(ImpactFx.capped_trauma(fb.trauma, im.heavy_trauma, im.trauma_cap), dir)
	fb.kick(dir, im.heavy_kick_px)
	ImpactFx.heavy_slow(fb.get_tree(), im)
	if im.heavy_gugak != &"":
		fb.play(im.heavy_gugak, im.heavy_gugak_gap)
	fb.haptic(fb.feel.haptic_impact_ms, fb.feel.haptic_impact_amp)


## 탄이 사라짐: 맞아서 부서졌으면 아무것도, 수명을 다했으면(빗나감·관통 끝) 먹으로 풀림.
## 장면이 바뀌어 지워지는 탄(수명이 남음)은 그리지 않는다.
static func on_gone(p: Projectile, col: Color) -> void:
	if not should_fizzle(p):
		return
	var d := data()
	var l := layer()
	if l:
		l.fizzle(p.global_position, p.direction, col, p.art, shot_size(p) * p.size_scale, p.glyph)
	var fb := Feedback.instance
	if fb and fb.kill_fx and d.fizzle_drops > 0:
		fb.kill_fx.drops(p.global_position, p.direction, d.fizzle_drops)


static func should_fizzle(p: Projectile) -> bool:
	return p != null and not p.get_meta(&"ranged_burst", false) and p._age >= p.lifetime
