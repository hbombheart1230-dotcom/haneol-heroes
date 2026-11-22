extends GdUnitTestSuite
## 기술 연출 2차 (벤치마크 1~6): 그림 속 움직임, 판정 크기 맞춤, 큰 기술 컷인, 국악 소리 층, 그려지듯 등장, 프레임 시트.

const HEROES := ["yi_sun_sin", "sejong", "gwanggaeto", "shin_saimdang"]
const BANK := preload("res://data/audio/sfx_bank.tres")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


func after_test() -> void:
	for c in get_children():
		if c is VfxDecals or c is Projectile or c is SkillCutin:
			remove_child(c)
			c.free()
	SkillCutin.reset()
	GameTime.reset()


func _hero(id: String) -> HeroData:
	return load("res://data/heroes/%s.tres" % id)


func _skills(h: HeroData) -> Array[SkillDef]:
	var out: Array[SkillDef] = [h.kit.tap, h.kit.dash, h.kit.charge, h.kit.counter]
	return out


## 가로 cols × 세로 rows 칸마다 다른 색인 시트.
func _sheet(cols: int, rows: int) -> ImageTexture:
	var img := Image.create_empty(cols * 8, rows * 8, false, Image.FORMAT_RGBA8)
	for i in cols * rows:
		img.fill_rect(Rect2i((i % cols) * 8, (i / cols) * 8, 8, 8), Color(float(i) / (cols * rows), 0.5, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


# --- 프레임 시트 ---

func test_sheet_index_plays_then_holds_or_loops() -> void:
	assert_int(VfxSheets.index_at(8, 10.0, 0.0, false)).is_equal(0)
	assert_int(VfxSheets.index_at(8, 10.0, 0.35, false)).is_equal(3)
	assert_int(VfxSheets.index_at(8, 10.0, 5.0, false)).is_equal(7)  # 마지막 장에 멈춤
	assert_int(VfxSheets.index_at(8, 10.0, 0.85, true)).is_equal(0)  # 되풀이
	assert_int(VfxSheets.index_at(1, 10.0, 3.0, true)).is_equal(0)


func test_sheet_cuts_frames_in_reading_order() -> void:
	var sheet := _sheet(4, 2)
	var frames := VfxSheets.frames(sheet, 4, 2, 0)
	assert_int(frames.size()).is_equal(8)
	assert_int((frames[0] as Texture2D).get_width()).is_equal(8)
	var c5 := (frames[5] as Texture2D).get_image().get_pixel(4, 4)  # 두 번째 줄 두 번째 칸
	assert_float(c5.r).is_equal_approx(5.0 / 8.0, 0.01)
	assert_int(VfxSheets.frames(sheet, 4, 2, 6).size()).is_equal(6)  # 쓸 장 수
	assert_bool(VfxSheets.frames(sheet, 4, 2, 0) == frames).is_true()  # 한 번만 자른다 (캐시)


func test_data_with_sheet_draws_frames_instead_of_still() -> void:
	var d := SkillVfxData.new()
	assert_bool(d.has_decal()).is_false()
	d.sheet = _sheet(4, 2)
	d.sheet_fps = 10.0
	assert_bool(d.has_decal()).is_true()
	assert_object(d.decal_at(0.0)).is_not_same(d.decal_at(0.45))
	d.sheet = null
	d.decal = PlaceholderTexture2D.new()
	assert_object(d.decal_at(1.0)).is_same(d.decal)  # 시트 없으면 지금 그림 그대로


func test_haeil_wave_sheet_reaches_projectile() -> void:
	var s: HaeilSkill = _hero("yi_sun_sin").kit.charge.duplicate()
	s.wave_sheet = _sheet(4, 2)
	var p: Projectile = PROJECTILE_SCENE.instantiate()
	s._wave_configure(p, Vector2.RIGHT, 1.0)
	assert_object(p.art_sheet).is_same(s.wave_sheet)
	assert_float(p.flicker).is_greater(0.0)
	add_child(p)
	for i in 3:
		await get_tree().process_frame
	p._physics_process(0.1)


# --- 그림 속 움직임 · 판정 크기 ---

func test_ink_color_packs_flow_channels() -> void:
	var d := SkillVfxData.new()
	d.flicker = 0.8
	d.twist = 2.0
	var c := d.ink_color(1.3, 0.6)
	assert_float(c.r).is_equal_approx(1.3, 0.001)
	assert_float(c.g).is_equal_approx(0.8, 0.001)
	assert_float(c.b).is_equal_approx(0.5, 0.001)  # 감김 / 4
	assert_float(c.a).is_equal_approx(0.6, 0.001)
	var still := SkillVfxData.new().ink_color(1.0, 1.0)
	assert_float(still.g + still.b).is_equal(0.0)  # 움직임 없는 그림은 예전과 같다


func test_fit_to_hit_matches_art_to_radius_and_follows_upgrades() -> void:
	var d := SkillVfxData.new()
	d.decal = PlaceholderTexture2D.new()
	d.art_fill = 0.8
	var r := 300.0
	assert_float(VfxDecals.fit_size(d, 0, r) * d.art_fill * 0.5).is_equal_approx(r, 0.01)  # 칠해진 반지름 = 판정
	assert_float(VfxDecals.fit_size(d, 6, r)).is_equal(VfxDecals.fit_size(d, 0, r))  # 강화 배율은 판정이 대신
	assert_float(VfxDecals.fit_size(d, 0, r * 1.25)).is_greater(VfxDecals.fit_size(d, 0, r))  # 판정이 커지면 그림도
	assert_float(VfxDecals.fit_size(d, 3, 0.0)).is_equal(d.decal_size * d.size_mult(3))  # 반경 모르면 예전대로
	d.fit_to_hit = false
	assert_float(VfxDecals.fit_size(d, 0, r)).is_equal(d.decal_size)


func test_fitted_burst_sizes_pieces() -> void:
	var v: VfxDecals = auto_free(VfxDecals.new())
	var d := SkillVfxData.new()
	d.decal = PlaceholderTexture2D.new()
	d.piece_count = 6
	v.burst(d, Vector2.ZERO, Vector2.RIGHT, 0, 300.0)
	assert_float(float(v.pieces._sets[0]["size"])).is_equal_approx(d.fitted_size(300.0), 0.01)


func test_sundial_plum_canvas_art_no_smaller_than_hit() -> void:
	var sj := _hero("sejong")
	var sa := _hero("shin_saimdang")
	var cases := [[sj.kit.counter, (sj.kit.counter as SundialSkill).radius],
		[sa.kit.counter, (sa.kit.counter as PlumBlossomSkill).radius],
		[sa.kit.charge, (sa.kit.charge as CanvasSkill).max_radius]]
	for c in cases:
		var d: SkillVfxData = (c[0] as SkillDef).vfx_impact
		assert_bool(d.fit_to_hit).is_true()
		assert_float(d.fitted_size(c[1]) * d.art_fill * 0.5).is_greater_equal(float(c[1]) - 0.01)


func test_flowing_skills_have_flow() -> void:
	var yi := _hero("yi_sun_sin")
	assert_float(yi.kit.tap.vfx_impact.flicker).is_greater(0.0)
	assert_float(yi.kit.tap.vfx_impact.twist).is_greater(0.0)
	assert_float(yi.kit.counter.vfx_impact.flicker).is_greater(0.0)
	assert_float(yi.kit.dash.vfx_impact.flicker).is_greater(0.0)
	assert_float((yi.kit.charge as HaeilSkill).wave_flicker).is_greater(0.0)


# --- 컷인 ---

func test_cutin_only_for_big_skills_with_gap() -> void:
	for id in HEROES:
		var h := _hero(id)
		assert_bool(h.kit.counter.cutin).is_true()
		assert_bool(h.kit.tap.cutin or h.kit.dash.cutin or h.kit.charge.cutin).is_false()
	assert_bool(SkillCutin.can_play(10000, 0, 8.0)).is_true()
	assert_bool(SkillCutin.can_play(5000, 0, 8.0)).is_false()
	var counter := _hero("yi_sun_sin").kit.counter
	assert_bool(SkillCutin.play(get_tree(), _hero("yi_sun_sin").kit.tap, null)).is_false()
	assert_bool(SkillCutin.play(get_tree(), counter, _hero("yi_sun_sin"))).is_true()
	assert_bool(SkillCutin.play(get_tree(), counter, _hero("yi_sun_sin"))).is_false()  # 연속 발동에 과하지 않게
	for i in 3:
		await get_tree().process_frame
	_free_cutins()


func _free_cutins() -> void:
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	for c in root.get_children():
		if c is SkillCutin:
			root.remove_child(c)
			c.free()


func test_cutin_names_are_in_the_brush_font() -> void:
	var font: FontFile = UiStyle.TITLE_FONT
	for id in HEROES:
		for ch in _hero(id).kit.counter.display_name:
			if ch != " ":
				assert_bool(font.has_char(ch.unicode_at(0))).override_failure_message("글꼴에 없음: " + ch).is_true()


# --- 소리 층 ---

func test_skill_sound_layers_exist_in_bank() -> void:
	for id in HEROES:
		for s in _skills(_hero(id)):
			for k in s.sfx_layers:
				assert_bool(BANK.has(k)).override_failure_message("%s: %s" % [s.id, k]).is_true()
			for k in [s.impact_sfx, s.hit_layer_sfx]:
				if k != &"":
					assert_bool(BANK.has(k)).override_failure_message("%s: %s" % [s.id, k]).is_true()
			if s.vfx_impact and s.vfx_impact.tick_count > 0:
				assert_bool(BANK.has(s.vfx_impact.tick_sfx)).is_true()
	for k in [&"gugak_buk", &"gugak_jing", &"gugak_pyeon", &"gugak_gaya"]:
		assert_bool(BANK.has(k)).is_true()


# --- 그려지듯 등장 ---

func test_glyphs_write_one_after_another() -> void:
	assert_float(OrbitGlyphs.write_progress(0.0, 0, 0.07, 0.16)).is_equal(0.0)
	assert_float(OrbitGlyphs.write_progress(0.08, 0, 0.07, 0.16)).is_equal_approx(0.5, 0.001)
	assert_float(OrbitGlyphs.write_progress(0.08, 3, 0.07, 0.16)).is_equal(0.0)  # 뒤 글자는 아직
	assert_float(OrbitGlyphs.write_progress(2.0, 5, 0.07, 0.16)).is_equal(1.0)


func test_critter_parts_are_painted_in_order() -> void:
	assert_float(SummonCritter.part_progress(0.05, 0)).is_greater(0.0)
	assert_float(SummonCritter.part_progress(0.05, 2)).is_equal(0.0)
	assert_float(SummonCritter.part_progress(1.0, 3)).is_equal(1.0)


func test_canvas_unrolls_as_scroll_and_draws() -> void:
	var d: SkillVfxData = _hero("shin_saimdang").kit.charge.vfx_impact
	assert_int(d.piece_mode).is_equal(SkillVfxData.PieceMode.SCROLL)
	var v := VfxDecals.new()
	add_child(v)
	v.burst(d, Vector2(100, 100), Vector2.RIGHT, 2, 240.0)
	var flow := SkillVfxData.new()
	flow.decal = PlaceholderTexture2D.new()
	flow.flicker = 1.0
	flow.twist = 2.0
	flow.piece_count = 8
	v.burst(flow, Vector2.ZERO, Vector2.RIGHT, 4)  # 금빛 고리까지 (색 입히는 층)
	for i in 5:
		await get_tree().process_frame
		v._process(0.08)
	assert_int(v.pieces.set_count()).is_greater_equal(1)


# --- B안 부품 그림 슬롯 (비면 지금 그대로) ---

func test_layer_slots_used_when_filled_and_fallback_when_empty() -> void:
	var v := VfxDecals.new()
	add_child(v)
	var d := SkillVfxData.new()
	d.decal = PlaceholderTexture2D.new()
	d.piece_count = 6
	d.sweep_hand = true
	d.ground_time = 1.0
	v.burst(d, Vector2.ZERO, Vector2.RIGHT, 0)
	assert_object(v.ground._items[0]["tex"]).is_null()  # 공용 웅덩이로
	d.ground_art = _sheet(1, 1)
	d.hand_art = _sheet(4, 1)
	v.burst(d, Vector2.ZERO, Vector2.RIGHT, 0)
	assert_object(v.ground._items[1]["tex"]).is_same(d.ground_art)
	for i in 3:
		await get_tree().process_frame
		v._process(0.05)
	assert_int(v.pieces.hand_count()).is_equal(2)


func test_part_art_replaces_particle_shapes() -> void:
	var p := SkillVfx.new()
	add_child(p)
	var d := SkillVfxData.new()
	d.count = 4
	p.burst(d, Vector2.ZERO)
	assert_object(p._parts[0]["tex"]).is_null()
	d.part_art = [_sheet(1, 1), _sheet(2, 1)] as Array[Texture2D]
	p.burst(d, Vector2.ZERO)
	assert_object(p._parts[4]["tex"]).is_same(d.part_art[0])
	assert_object(p._parts[5]["tex"]).is_same(d.part_art[1])
	await get_tree().process_frame
	p.free()


func test_critter_art_slot_reaches_summons() -> void:
	var s: CritterSkill = _hero("shin_saimdang").kit.tap.duplicate()
	assert_object(s.butterfly_art).is_null()  # 지금은 꽃잎 모양 그대로
	var c := SummonCritter.new()
	c.art = _sheet(1, 1)
	c.lifetime = 1.0
	add_child(c)
	await get_tree().process_frame
	c.queue_redraw()
	await get_tree().process_frame
	c.free()
