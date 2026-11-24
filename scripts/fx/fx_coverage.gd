class_name FxCoverage
extends RefCounted
## 큰 기술 이펙트가 화면을 얼마나 덮는지 (화면 너비 대비 지름)와 그 상한.
## 판정(피해 범위)은 건드리지 않는다. 그림·빛·바닥 자국만 화면 너비의 SkillStageFeel.screen_cap까지.
## 상한에 걸리면 그림이 판정보다 작아질 수 있다. 그때는 기술의 얇은 판정 고리(FxLayer.add_ring)가 진짜 범위를 보여 준다.

## 카메라가 없을 때 (테스트·도구) 쓰는 화면 너비 (project.godot viewport_width).
const DEFAULT_VIEW_W := 720.0


## 지금 화면에 보이는 세계 너비 (px). 카메라 줌이 크면 (영웅이 크게 보이면) 좁아진다.
static func view_width(node: Node) -> float:
	if node == null or not node.is_inside_tree():
		return DEFAULT_VIEW_W
	var vp := node.get_viewport()
	var w := vp.get_visible_rect().size.x
	var cam := vp.get_camera_2d()
	if cam and cam.zoom.x > 0.0:
		w /= cam.zoom.x
	return w if w > 1.0 else DEFAULT_VIEW_W


## 그림이 수명 동안 커지는 최대 배율. 판정에 맞춘 그림은 거의 안 커진다 (커지면 판정보다 넓어 보임).
static func grow_of(d: SkillVfxData, fitted: bool, st: SkillStageFeel) -> float:
	var g := maxf(d.decal_grow, 1.0)
	return minf(g, maxf(st.fit_grow, 1.0)) if fitted else g


## 처음 그릴 지름 size를, 커진 뒤에도 화면 너비 × screen_cap을 넘지 않게 줄인다.
static func capped(size: float, grow: float, st: SkillStageFeel, view_w: float, cap: float = -1.0) -> float:
	var c := st.screen_cap if cap < 0.0 else cap
	if c <= 0.0:
		return size
	return minf(size, c * view_w / maxf(grow, 1.0))


## 화면 너비의 big_from 이상을 덮는 "큰" 이펙트인지 (빛·시간을 줄이고 가운데를 먼저 비움).
static func is_big(size: float, grow: float, st: SkillStageFeel, view_w: float) -> bool:
	return size * maxf(grow, 1.0) >= st.big_from * view_w


## 그림 대비 배율 want (빛·번쩍)를 화면 상한을 넘지 않게.
static func limit_scale(want: float, size: float, st: SkillStageFeel, view_w: float) -> float:
	if st.screen_cap <= 0.0 or size <= 0.0:
		return want
	return minf(want, st.screen_cap * view_w / size)


## 이 이펙트가 가장 넓게 덮는 지름: 다 커진 그림, 빛(glow_k = 그림 대비), 다 모인 순간 번쩍(flash_k), 바닥 자국 중 큰 것.
static func cover(d: SkillVfxData, size: float, grow: float, glow_k: float, flash_k: float, ground: float) -> float:
	var c := size * maxf(grow, 1.0)
	if d.glow > 0.0:
		c = maxf(c, size * glow_k)
	if d.piece_count > 0 and d.piece_flash > 0.0:
		c = maxf(c, size * flash_k)
	return maxf(c, ground)


## 기술 이펙트 하나를 어떻게 그릴지: 크기(상한 적용), 커지는 배율, 빛·번쩍 배율, 바닥 자국 배율,
## 큰 이펙트면 줄이는 시간·빛, 가운데를 먼저 비우는 세기, 그리고 화면을 덮는 지름(cover)과 그 비율(frac).
static func plan(d: SkillVfxData, level: int, fit_radius: float, st: SkillStageFeel, view_w: float) -> Dictionary:
	var fitted := fit_radius > 0.0 and d.fit_to_hit
	var exact := fitted and d.fit_exact  # 판정 끝 그대로 (상한·커지기 없음)
	var grow := 1.0 if exact else grow_of(d, fitted, st)
	var raw := VfxDecals.fit_size(d, level, fit_radius)
	var size := raw if exact else capped(raw, grow, st, view_w, d.screen_cap_for(level, st.screen_cap))  # 성장 단계면 단계별 상한
	var big := is_big(size, grow, st, view_w)
	var glow_k := limit_scale(d.glow_size, size, st, view_w)
	var flash_k := limit_scale(st.flash_scale * 1.3, size, st, view_w)
	var ground_k := size / maxf(d.decal_size * d.size_mult(level), 1.0)
	var ground := d.ground_size * d.size_mult(level) * ground_k if d.ground_time > 0.0 else 0.0
	if ground > 0.0 and st.screen_cap > 0.0:
		var lim := st.screen_cap * view_w / ground
		if lim < 1.0:
			ground_k *= lim
			ground *= lim
	var c := cover(d, size, grow, glow_k, flash_k, ground)
	return {"size": size, "raw": raw, "grow": grow, "glow_k": glow_k, "flash_k": flash_k, "ground_k": ground_k,
		"big": big, "time": st.big_time if big else 1.0, "light": st.big_light if big else 1.0,
		"core": st.big_core if big else 1.0, "cover": c, "frac": c / maxf(view_w, 1.0), "exact": exact}
