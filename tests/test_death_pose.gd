extends GdUnitTestSuite
## 쓰러지는 죽음 (EnemyDeathPose): 죽는 동작("death")이 있는 적만 몸이 쓰러졌다 사라지고, 없으면 지금처럼 바로 지워진다.
## 죽는 순간의 일(killed·무리 수)은 그 순간 그대로, 기다림은 GameTime 시계로 잰다.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ELITE := "res://data/enemies/waegun_elite.tres"
const SOLDIER := "res://data/enemies/waegun_soldier.tres"
const COMMANDER := "res://data/enemies/waegun_commander.tres"

var player: Player
var sp: EnemySpawner
var now_ms := 0


func before_test() -> void:
	BossSim.reset_globals()
	now_ms = 1000
	GameTime.clock = func() -> int: return now_ms
	player = auto_free(Player.new())
	var h := Health.new()
	h.name = "Health"
	player.add_child(h)
	add_child(player)
	player.set_physics_process(false)
	sp = auto_free(EnemySpawner.new())
	sp.enemy_scene = ENEMY_SCENE
	sp.target = player
	sp.horde_enabled = false
	add_child(sp)
	sp.set_physics_process(false)


func after_test() -> void:
	GameTime.clock = Callable()
	BossSim.reset_globals()


func _load(path: String) -> EnemyData:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyData


func _spawn(d: EnemyData) -> Enemy:
	var e := sp.spawn_at(d, player.global_position + Vector2(300, 0))
	e.set_physics_process(false)
	return e


func test_hold_time_rules() -> void:
	var d := EnemyData.new()
	assert_float(EnemyDeathPose.hold_time(d)).is_equal(0.0)  # 처치 연출이 없으면 자동은 쓰지 않음
	d.boss_feel = BossFeelData.new()
	d.boss_feel.finale_time = 2.6
	d.death_fade = 0.35
	assert_float(EnemyDeathPose.hold_time(d)).is_equal_approx(2.6 - 0.35 - EnemyDeathPose.FINALE_TAIL, 0.001)
	assert_float(EnemyDeathPose.total_time(d)).is_less(2.6)  # 처치 연출(승리·물결 끝) 전에 다 사라진다
	d.death_hold = 0.0
	assert_float(EnemyDeathPose.hold_time(d)).is_equal(0.0)
	d.death_hold = 1.5
	assert_float(EnemyDeathPose.hold_time(d)).is_equal(1.5)


func test_phase_at() -> void:
	assert_vector(EnemyDeathPose.phase_at(0, 1000, 400, 300)).is_equal(Vector2(0, 0))
	assert_vector(EnemyDeathPose.phase_at(500, 1000, 400, 300)).is_equal(Vector2(0.5, 0))
	assert_vector(EnemyDeathPose.phase_at(1200, 1000, 400, 300)).is_equal(Vector2(1, 0))  # 누워 있기
	assert_vector(EnemyDeathPose.phase_at(1550, 1000, 400, 300)).is_equal(Vector2(1, 0.5))
	assert_vector(EnemyDeathPose.phase_at(9000, 1000, 400, 300)).is_equal(Vector2(1, 1))


func test_data_has_death_clips() -> void:
	assert_bool(_load(ELITE).sprite_sheet.has_anim("death")).is_true()  # 정예: 구운 칸
	var live := EnemySprite3D.live_data(_load(COMMANDER))
	if live:  # 대장: 3D 클립만 (구운 시트에는 없다 — 넘어지지 않아 down도 없음)
		assert_bool(live.clip("death").is_empty()).is_false()
	assert_bool(_load(COMMANDER).sprite_sheet.has_anim("death")).is_false()


func test_elite_falls_then_dissolves_on_game_clock() -> void:
	var e := _spawn(_load(ELITE))
	var killed := [false]
	e.killed.connect(func(_e: Enemy) -> void: killed[0] = true)
	e.health.kill()
	assert_bool(killed[0]).is_true()  # 처치 신호는 그 순간
	assert_bool(e.is_queued_for_deletion()).is_false()
	var pose := EnemyDeathPose.of(e)
	assert_object(pose).is_not_null()
	assert_int(sp.alive_count()).is_equal(0)  # 쓰러진 몸은 무리 수에 들지 않는다
	assert_bool(e.is_in_group(Enemy.GROUP)).is_false()
	assert_int(e.collision_layer).is_equal(0)
	assert_bool(e.is_physics_processing()).is_false()
	assert_str(String(e.sprite.animation)).starts_with("death_")
	pose._process(0.0)
	assert_bool(e.is_queued_for_deletion()).is_false()
	now_ms += int(EnemyDeathPose.hold_time(e.data) * 1000.0) - 50
	pose._process(0.0)
	assert_int(e.sprite.frame).is_equal(e.data.sprite_sheet.frame_count("death") - 1)  # 다 쓰러졌다
	assert_float(e.sprite.modulate.a).is_equal(1.0)
	assert_bool(e.is_queued_for_deletion()).is_false()
	now_ms += int(e.data.death_fade * 1000.0) + 100
	pose._process(0.0)
	assert_bool(e.is_queued_for_deletion()).is_true()


func test_enemy_without_death_clip_vanishes_at_once() -> void:
	var e := _spawn(_load(SOLDIER))
	e.health.kill()
	assert_object(EnemyDeathPose.of(e)).is_null()
	assert_bool(e.is_queued_for_deletion()).is_true()


func test_mid_boss_wave_waits_for_the_body() -> void:
	sp.elite_data = _load(ELITE)
	var e := sp.spawn_elite(Vector2(0, -150))
	e.set_physics_process(false)
	assert_object(BossStaging.of(e)).is_not_null()
	e.health.kill()
	var wait := maxf(e.data.boss_feel.finale_time, EnemyDeathPose.total_time(e.data))
	assert_bool(sp.finale_playing()).is_true()
	now_ms += int(wait * 1000.0) - 20
	assert_bool(sp.finale_playing()).is_true()
	now_ms += 40
	assert_bool(sp.finale_playing()).is_false()


## 3D 대장: 리그가 "death" 클립을 시간에 맞춰 놓는다 (재생 속도 0, 판 시각 진행 → 클립 시각). 3D를 끄면(구운 시트엔 death가 없다) 지금처럼 바로.
func test_commander_3d_falls_with_rig_clip() -> void:
	var boss := _commander(true)
	var rig := EnemySprite3D.rig_of(boss)
	assert_object(rig).is_not_null()
	boss.health.kill()
	var pose := EnemyDeathPose.of(boss)
	assert_object(pose).is_not_null()
	assert_str(rig.body_anim()).is_equal("death")
	assert_float(rig.body_speed()).is_equal(0.0)
	var clip: Dictionary = (rig.data as Live3DHeroData).clip("death")
	var len := float(clip["end"]) - float(clip["start"])
	now_ms += int((EnemyDeathPose.hold_time(boss.data) - boss.data.death_rest) * 500.0)  # 쓰러짐 절반
	pose._process(0.0)
	assert_float(rig.last_seek()).is_equal_approx(len * 0.5, 0.05)
	now_ms += 100000
	pose._process(0.0)
	assert_bool(boss.is_queued_for_deletion()).is_true()
	var flat := _commander(false)
	flat.health.kill()
	assert_bool(flat.is_queued_for_deletion()).is_true()


func _commander(live: bool) -> Enemy:
	var was: Variant = ProjectSettings.get_setting(EnemySprite3D.Switch.SETTING, true)
	ProjectSettings.set_setting(EnemySprite3D.Switch.SETTING, live)
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.data = _load(COMMANDER)
	add_child(auto_free(e))
	ProjectSettings.set_setting(EnemySprite3D.Switch.SETTING, was)
	e.set_physics_process(false)
	return e
