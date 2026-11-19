extends GdUnitTestSuite
## 3D → 2D 구운 스프라이트: 시트 데이터, 방향 매핑, 플레이어·적 애니메이션 선택.

const HERO := preload("res://data/heroes/yi_sun_sin.tres")
const CHASER := preload("res://data/enemies/chaser.tres")
const BOSS := preload("res://data/enemies/boss_general.tres")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")


func test_sheets_are_assigned_and_complete() -> void:
	for sheet in [HERO.sprite_sheet, CHASER.sprite_sheet, BOSS.sprite_sheet]:
		var s := sheet as SpriteSheetSet
		assert_object(s).is_not_null()
		assert_int(s.directions).is_equal(8)
		assert_int(s.textures.size()).is_equal(s.anim_names.size())
		assert_bool(s.has_anim("idle") and s.has_anim("run") and s.has_anim("attack")).is_true()
		for i in s.textures.size():
			var tex := s.textures[i]
			assert_int(tex.get_width()).is_equal(s.frame_size * s.frame_counts[i])
			assert_int(tex.get_height()).is_equal(s.frame_size * s.directions)


func test_direction_index_mapping() -> void:
	var s: SpriteSheetSet = HERO.sprite_sheet
	assert_int(s.dir_index(Vector2.RIGHT)).is_equal(0)
	assert_int(s.dir_index(Vector2.DOWN)).is_equal(2)
	assert_int(s.dir_index(Vector2.LEFT)).is_equal(4)
	assert_int(s.dir_index(Vector2.UP)).is_equal(6)
	assert_int(s.dir_index(Vector2(1, 1))).is_equal(1)
	assert_int(s.dir_index(Vector2.ZERO)).is_equal(2)


func test_sprite_frames_shared_between_enemies() -> void:
	var a: SpriteFrames = CHASER.sprite_sheet.shared_sprite_frames()
	var b: SpriteFrames = CHASER.sprite_sheet.shared_sprite_frames()
	assert_object(a).is_same(b)
	assert_bool(a.has_animation(&"run_3")).is_true()


func test_player_view_picks_animation_by_state() -> void:
	var p: Player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	p.add_child(h)
	p.hero = HERO
	var v := PlayerView.new()
	v.player = p
	p.add_child(v)
	add_child(p)
	assert_str(v.current_anim()).is_equal("idle")
	p.set_move_input(Vector2.RIGHT)
	assert_str(v.current_anim()).is_equal("run")
	v.play_oneshot("attack", 0.3)
	assert_str(v.current_anim()).is_equal("attack")
	p.request_dash(Vector2.UP)
	assert_str(v.current_anim()).is_equal("dash")
	p.health.kill()
	assert_str(v.current_anim()).is_equal("death")


func test_enemy_uses_sprite_and_faces_target() -> void:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	target.global_position = Vector2(-300, 0)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = CHASER
	e.target = target
	add_child(auto_free(e))
	e.global_position = Vector2.ZERO
	assert_object(e.sprite).is_not_null()
	e._physics_process(1.0 / 60.0)
	assert_str(String(e.sprite.animation)).is_equal("run_4")  # 왼쪽으로 달림


func test_every_hero_skill_has_an_icon() -> void:
	var kit: SkillKit = HERO.kit
	for def in [kit.tap, kit.dash, kit.charge, kit.counter]:
		assert_object((def as SkillDef).icon).is_not_null()


func test_missing_animation_falls_back() -> void:
	var sheet := SpriteSheetSet.new()
	sheet.anim_names = PackedStringArray(["idle", "run"])
	var v: PlayerView = auto_free(PlayerView.new())
	v._sheet = sheet
	assert_str(v.available_anim("run")).is_equal("run")
	assert_str(v.available_anim("dash")).is_equal("run")
	assert_str(v.available_anim("attack")).is_equal("idle")
	assert_str(v.available_anim("death")).is_equal("idle")


func test_empty_sheet_does_not_crash() -> void:
	var v: PlayerView = auto_free(PlayerView.new())
	v._sheet = SpriteSheetSet.new()
	assert_str(v.available_anim("attack")).is_equal("attack")


func test_bake_name_matching_is_word_based() -> void:
	var bake := preload("res://tools/bake/bake_sprites.gd")
	assert_bool(bake.name_matches("Running_A", "run")).is_true()
	assert_bool(bake.name_matches("HitReaction", "hit")).is_true()
	assert_bool(bake.name_matches("Armature|Dying", "dying")).is_true()
	assert_bool(bake.name_matches("1H_Melee_Attack_Chop", "attack")).is_true()
	assert_bool(bake.name_matches("Soldier_Idle", "die")).is_false()
	assert_bool(bake.name_matches("Prerunner", "run")).is_false()
	assert_bool(bake.name_matches("White_Pose", "hit")).is_false()


func test_bake_name_normalisation_matches_import_renames() -> void:
	var bake := preload("res://tools/bake/bake_sprites.gd")
	assert_str(bake.normalize_name("Run_02")).is_equal(bake.normalize_name("Run 2"))
	assert_str(bake.normalize_name("Left_Slash")).is_equal(bake.normalize_name("Left Slash"))
	assert_str(bake.normalize_name("Hit_Reaction")).is_not_equal(bake.normalize_name("Hit Reaction 1"))
