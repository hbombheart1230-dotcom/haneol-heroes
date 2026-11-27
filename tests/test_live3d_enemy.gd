extends GdUnitTestSuite
## 실시간 3D 적 (EnemySprite3D, 한산 대장부터): 공격 시각 맞추기, 설정 = 구운 시트와 같은 칸 시각,
## 켜면 대장만 3D·다른 적은 구운 그림, 끄면 예전 그대로, 예고 진행에 맞춰 원본 시각에 놓기.

const Switch := preload("res://scripts/art/live3d/live3d_switch.gd")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const COMMANDER := "res://data/enemies/waegun_commander.tres"
const SOLDIER := "res://data/enemies/waegun_soldier.tres"
const RIM := "res://shaders/enemy_rim.gdshader"


## 예고 0 → 첫 칸 시각, 예고 끝 → 맞닿는 칸 시각 (= 피해 순간), 회복 끝 → 끝 칸 시각. 칸 사이는 곧게.
func test_attack_time_follows_sheet_times() -> void:
	var times := [0.9, 1.45, 1.75, 1.95, 2.35, 2.67]
	assert_float(EnemySprite3D.attack_time(times, 4, false, 0.0, 0.0)).is_equal_approx(0.9, 0.0001)
	assert_float(EnemySprite3D.attack_time(times, 4, false, 1.0, 0.0)).is_equal_approx(2.35, 0.0001)
	assert_float(EnemySprite3D.attack_time(times, 4, false, 0.5, 0.0)).is_equal_approx(1.75, 0.0001)  # 칸 2
	assert_float(EnemySprite3D.attack_time(times, 4, false, 0.125, 0.0)).is_equal_approx(1.175, 0.0001)  # 칸 0과 1 사이
	assert_float(EnemySprite3D.attack_time(times, 4, true, 0.0, 0.0)).is_equal_approx(2.35, 0.0001)
	assert_float(EnemySprite3D.attack_time(times, 4, true, 0.0, 1.0)).is_equal_approx(2.67, 0.0001)
	assert_float(EnemySprite3D.attack_time([], 0, false, 0.5, 0.0)).is_equal(0.0)


## 3D 설정의 칸 시각·구간은 굽기 작업과 같다 (같은 순간이 맞닿는 칸). 모델·동작은 가공 리소스(커밋됨).
func test_commander_data_matches_bake_job() -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/bake/jobs/waegun_commander.json"))
	var d := EnemySprite3D.live_data(load(COMMANDER))
	assert_object(d).is_not_null()
	assert_bool(d.model_path.begins_with("res://assets/live3d/")).is_true()
	assert_int(d.frame).is_equal(int(job["frame"]))
	assert_float(d.ortho_size).is_equal(float(job["ortho_size"]))
	for a in job["anims"]:
		var c := d.clip(String(a["key"]))
		assert_bool(c.is_empty()).override_failure_message(String(a["key"])).is_false()
		assert_bool(ResourceLoader.exists(String(c["file"]))).is_true()
		if a.has("times"):
			assert_array(c["times"]).override_failure_message(String(a["key"])).is_equal(a["times"])
			assert_float(float(c["start"])).is_equal(float(a["times"][0]))
			assert_float(float(c["end"])).is_equal(float(a["times"][-1]))


## 칸 시각으로 직접 놓는 공격은 원본 길이 그대로, 대기·걷기·맞음은 구운 시트 길이.
func test_durations_skip_frame_driven_attacks() -> void:
	var e: EnemyData = load(COMMANDER)
	var d := EnemySprite3D.live_data(e)
	var out := EnemySprite3D.durations(e.sprite_sheet, d)
	assert_bool(out.has("attack")).is_false()
	assert_bool(out.has("attack2")).is_false()
	assert_float(float(out["run"])).is_equal_approx(8.0 / 5.0, 0.0001)
	assert_float(float(out["hit"])).is_equal_approx(3.0 / 12.0, 0.0001)


## 켜면 대장은 3D (수묵 + 테두리 셰이더), 3D가 없는 병사는 구운 그림, 끄면 대장도 구운 그림 그대로.
func test_commander_gets_3d_others_keep_sprites() -> void:
	var boss := _enemy(COMMANDER, true)
	assert_object(EnemySprite3D.rig_of(boss)).is_not_null()
	assert_str((boss.sprite.material as ShaderMaterial).shader.resource_path).is_equal(EnemySprite3D.SHADER)
	assert_int(boss.sprite.sprite_frames.get_frame_count(&"idle_0")).is_equal(1)
	var soldier := _enemy(SOLDIER, true)
	assert_object(EnemySprite3D.rig_of(soldier)).is_null()
	assert_str((soldier.sprite.material as ShaderMaterial).shader.resource_path).is_equal(RIM)
	var off := _enemy(COMMANDER, false)
	assert_object(EnemySprite3D.rig_of(off)).is_null()
	assert_str((off.sprite.material as ShaderMaterial).shader.resource_path).is_equal(RIM)
	assert_int(off.sprite.sprite_frames.get_frame_count(&"idle_0")).is_greater(1)  # 구운 칸


## 예고 진행에 맞춰 원본 시각에 놓는다 (재생 속도 0): 예고 끝 = 맞닿는 칸 시각 − 구간 시작.
func test_windup_seeks_clip_to_strike_time() -> void:
	var boss := _enemy(COMMANDER, true)
	boss.set_physics_process(false)
	var rig := EnemySprite3D.rig_of(boss)
	var a := boss.attack
	var clip: Dictionary = (rig.data as Live3DHeroData).clip(String(a.data.anim))
	if not clip.has("times"):  # 첫 패턴이 돌진(run)이면 걷기 동작: 시각을 놓지 않는다
		EnemySprite3D.sync(boss, "run", Vector2.DOWN, false)
		assert_float(rig.body_speed()).is_equal(boss.sprite.speed_scale)
		return
	a.state = EnemyAttack.State.WINDUP
	a._timer = 0.0  # 예고 끝
	EnemySprite3D.sync(boss, String(a.data.anim), Vector2.DOWN, true)
	var strike: int = boss.data.sprite_sheet.strike_frame(String(a.data.anim))
	assert_float(rig.last_seek()).is_equal_approx(float(clip["times"][strike]) - float(clip["start"]), 0.001)
	assert_float(rig.body_speed()).is_equal(0.0)
	a.state = EnemyAttack.State.READY


## 3D 대장의 시체는 지워질 화면 텍스처가 아니라 구운 칸 (흰 사각형이 날아가지 않게). 구운 적은 지금 칸 그대로.
func test_corpse_texture_is_baked_not_viewport() -> void:
	var boss := _enemy(COMMANDER, true)
	assert_object(boss.sprite.sprite_frames.get_frame_texture(boss.sprite.animation, 0)).is_instanceof(ViewportTexture)
	var tex := EnemySprite3D.corpse_texture(boss)
	assert_object(tex).is_not_null()
	assert_bool(tex is ViewportTexture).is_false()
	var soldier := _enemy(SOLDIER, true)
	assert_object(EnemySprite3D.corpse_texture(soldier)).is_same(
		soldier.sprite.sprite_frames.get_frame_texture(soldier.sprite.animation, soldier.sprite.frame))


func _enemy(path: String, live: bool) -> Enemy:
	var was: Variant = ProjectSettings.get_setting(Switch.SETTING, true)
	ProjectSettings.set_setting(Switch.SETTING, live)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = load(path)
	add_child(auto_free(e))
	ProjectSettings.set_setting(Switch.SETTING, was)
	return e


## 적 셰이더의 varying은 vertex()에서 쓰기 전에 선언 (헤드리스는 셰이더를 컴파일하지 않아 'Unknown identifier'를 못 잡는다 — 실시간 3D 적이 셰이더 없이 그려지던 것).
func test_enemy_shader_varyings_are_declared_before_use() -> void:
	for path in ["res://shaders/enemy_live.gdshader", "res://shaders/enemy_rim.gdshader"]:
		var src := FileAccess.get_file_as_string(path)
		var re := RegEx.create_from_string(r"varying\s+\w+\s+(\w+)\s*;")
		for m in re.search_all(src):
			var name := m.get_string(1)
			var decl := m.get_start()
			assert_int(src.find(name)).override_failure_message("%s: %s used before its varying" % [path, name]).is_greater_equal(decl)  # 처음 나오는 곳이 선언 줄 앞이면 실패
