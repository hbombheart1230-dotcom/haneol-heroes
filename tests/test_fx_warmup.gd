extends GdUnitTestSuite
## 효과 예열 (FxWarmup): 데이터에서 자동으로 모으고, 처음 쓸 때 하던 일을 미리 하고, 그리기 한 번 뒤 사라진다.

const HEROES := ["yi_sun_sin", "gwanggaeto", "sejong", "shin_saimdang"]


func after_test() -> void:
	FxWarmup.enabled = true
	FxWarmup.skip = PackedStringArray()


func _hero(id: String) -> HeroData:
	return load("res://data/heroes/%s.tres" % id)


func _stage(id: String) -> StageTheme:
	return load("res://data/stages/%s.tres" % id)


## 영웅 기술 넷의 효과(SkillVfxData)와 이름이 다 모인다.
func test_collects_every_skill_effect_and_name() -> void:
	for id in HEROES:
		var h := _hero(id)
		var found := FxWarmup.collect([h])
		for def in [h.kit.tap, h.kit.dash, h.kit.charge, h.kit.counter]:
			assert_bool(found["words"].has(String(def.display_name))).is_true()
			for v in [def.vfx_cast, def.vfx_hit, def.vfx_impact]:
				if v:
					assert_bool(found["vfx"].has(v)).override_failure_message("%s %s" % [id, def.id]).is_true()
		assert_bool(found["textures"].is_empty()).is_false()


## 새 기술·효과가 생겨도 손으로 목록을 고치지 않는다: 기술을 바꾸면 그 효과가 모인다.
func test_new_skill_is_picked_up_from_data() -> void:
	var h := _hero("gwanggaeto").duplicate(true) as HeroData
	var v := SkillVfxData.new()
	var tex := GradientTexture2D.new()
	v.decal = tex
	var def := h.kit.tap.duplicate() as SkillDef
	def.display_name = "새 기술"
	def.vfx_impact = v
	h.kit = h.kit.duplicate() as SkillKit
	h.kit.tap = def
	var found := FxWarmup.collect([h])
	assert_bool(found["vfx"].has(v)).is_true()
	assert_bool(found["textures"].has(tex)).is_true()
	assert_bool(found["words"].has("새 기술")).is_true()


## 무대 적(물결·정예·보스)의 그림도 모인다. 몸 그림(SpriteFrames)은 장면이 그리므로 빼고, 같은 자원은 한 번만.
func test_stage_enemies_collected_once_without_body_sheets() -> void:
	var st := _stage("hansan_1592")
	var found := FxWarmup.collect([st, st])
	assert_bool(found["textures"].is_empty()).is_false()
	var ids := {}
	for t in found["textures"]:
		assert_bool(t is NoiseTexture2D).is_false()
		assert_bool(ids.has(t.get_instance_id())).is_false()
		ids[t.get_instance_id()] = true


## 시트 이름 규칙 (<이름>_sheet + <이름>_sheet_grid)이면 탄 시트도 자른다.
func test_projectile_sheet_convention() -> void:
	var def := HaeilSkill.new()
	var img := Image.create_empty(8, 4, false, Image.FORMAT_RGBA8)
	def.wave_sheet = ImageTexture.create_from_image(img)
	def.wave_sheet_grid = Vector2i(2, 1)
	var found := FxWarmup.collect([def])
	assert_int(found["sheets"].size()).is_equal(1)
	FxWarmup.prepare(found)
	assert_int(VfxSheets.frames(def.wave_sheet, 2, 1).size()).is_equal(2)


## 미리 만들기: 입자 그림 모양 전부, 물결 잡음 재질.
func test_prepare_builds_shapes_and_flow_material() -> void:
	FxWarmup.prepare(FxWarmup.collect([_hero("sejong")]))
	for shape in SkillVfxData.Shape.values():
		assert_bool(VfxTextures._cache.has(shape)).is_true()
	assert_object(Projectile._flow_mat).is_not_null()


## 시작점: 영웅·무대와 늦게 불러오던 효과 설정들.
func test_roots_include_lazy_feel_data() -> void:
	var r := FxWarmup.roots(_hero("sejong"), _stage("gyeongbokgung_1433"))
	assert_bool(r.has(SkillHitFeelData.get_default())).is_true()
	assert_bool(r.has(DeathStyleData.get_default())).is_true()
	assert_bool(r.has(RangedFeelData.get_default())).is_true()
	assert_bool(FxWarmup.roots(null, null).has(null)).is_false()


## 그리기 한 번: 재질 갈래마다 자식 하나, 거의 투명, frames프레임 뒤 스스로 사라진다.
func test_layer_draws_then_frees_itself() -> void:
	var holder: Node2D = auto_free(Node2D.new())
	add_child(holder)
	var found := FxWarmup.run(holder, _hero("yi_sun_sin"), _stage("hansan_1592"))
	assert_bool(found.is_empty()).is_false()
	var layer: FxWarmupLayer = null
	for c in holder.get_children():
		if c is FxWarmupLayer:
			layer = c
	assert_object(layer).is_not_null()
	assert_int(layer.get_child_count()).is_equal(FxWarmupLayer.materials().size())
	assert_float(layer.modulate.a).is_less(0.05)
	for i in layer.frames + 2:
		layer._process(0.016)
	assert_bool(layer.is_queued_for_deletion()).is_true()


## 꺼 두면 아무것도 하지 않는다 (측정 도구의 전/후 비교).
func test_disabled_does_nothing() -> void:
	FxWarmup.enabled = false
	var holder: Node2D = auto_free(Node2D.new())
	add_child(holder)
	assert_bool(FxWarmup.run(holder, _hero("yi_sun_sin"), null).is_empty()).is_true()
	assert_int(holder.get_child_count()).is_equal(0)
