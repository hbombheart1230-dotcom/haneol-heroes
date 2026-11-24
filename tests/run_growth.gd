class_name RunGrowth
extends RefCounted
## 시뮬레이션 한 판의 성장 (tests/run_sim.gd): main.gd·RunLevels와 같은 길로
##  - 점수: ScoreFeed (처치 = 적 xp × 무대 xp_mult × 점수표, 연타·회피·반격·기술 점수도 같은 신호로)
##  - 레벨업: LevelRules.grants_stats면 영웅 level_up 성장, 모든 기술 모습 단계 = vfx_bonus (#95 판정 크기도 따라감)
##  - 숨 고르기(물결 끝·보스 단계): LevelRules.plan대로 고르기, 정예를 잡았으면 큰 변형 먼저
##  - 패 고르기 규칙 (고정): 게임과 같은 가중치 뽑기(UpgradePool.roll, 씨앗 고정)로 3장을 펼치고 늘 첫 장.

const RUN_PATH := "res://data/runs/default_run.tres"

var progress: RunProgress
var build: RunBuild
var feed: ScoreFeed
var rng := RandomNumberGenerator.new()
var spawner: EnemySpawner
var major_pending: int = 0
var picks: Array[String] = []
var count: int = 3


func begin(player: Player, caster: SkillCaster, atk: AutoAttack, sp: EnemySpawner, seed_value: int, clock: Callable) -> void:
	var cfg := ResourceLoader.load(RUN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as RunConfig
	count = cfg.choice_count
	progress = RunProgress.new(cfg)
	build = RunBuild.new()
	build.begin(player, caster, atk)
	feed = ScoreFeed.new(progress, cfg.score)
	feed.clock = clock
	feed.active = func() -> bool: return true
	feed.connect_to(player, caster)
	rng.seed = seed_value
	spawner = sp
	progress.leveled_up.connect(_on_level_up)
	sp.breather.connect(_on_breather)
	sp.child_entered_tree.connect(func(n: Node) -> void:
		if n is Enemy:
			(n as Enemy).killed.connect(_on_kill))


func _on_kill(e: Enemy) -> void:
	if e.data == null:
		return
	feed.kill(e, spawner.xp_mult())
	if e.data.is_elite:
		major_pending += 1


func _on_level_up(level: int) -> void:
	var r := progress.rules()
	if r == null or build.hero == null:
		return
	if r.grants_stats(level) and build.hero.level_up:
		build.apply(build.hero.level_up)
	build.set_level_vfx(r.vfx_bonus(level))


## 숨 고르기: 큰 변형(정예) 먼저, 그다음 계획된 고르기마다 단계 수만큼.
func _on_breather(_slow: bool) -> void:
	var last := spawner.waves != null and spawner.waves.phase == WaveRunner.Phase.BOSS_WAIT
	feed.new_wave()
	var r := progress.rules()
	var gains: Array[int] = r.plan(progress.pending, last) if r else [1]
	progress.pending = maxi(progress.pending - LevelRules.used(gains), 0)
	while major_pending > 0:
		major_pending -= 1
		var majors := build.hero.major_pool.roll(rng, progress.stacks, count) if build.hero.major_pool else []
		if majors.is_empty():
			major_pending = 0
			break
		var m: UpgradeDef = majors[0]
		build.apply(m)
		progress.stacks[m.id] = int(progress.stacks.get(m.id, 0)) + 1
		picks.append("*" + String(m.id))
	for g in gains:
		var pool := build.hero.upgrade_pool
		var choices: Array[UpgradeDef] = pool.roll(rng, progress.stacks, count) if pool else []
		if choices.is_empty():
			break
		var u: UpgradeDef = choices[0]
		build.apply(u)
		progress.stacks[u.id] = int(progress.stacks.get(u.id, 0)) + 1
		for i in mini(g, u.max_stacks - int(progress.stacks.get(u.id, 0)) + 1) - 1:  # 한 번에 여러 단계 (main과 같은 식)
			build.apply(u)
			progress.stacks[u.id] = int(progress.stacks.get(u.id, 0)) + 1
		picks.append("%s×%d" % [u.id, g])
