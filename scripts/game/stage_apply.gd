class_name StageApply
extends RefCounted
## 무대 입히기 (main.gd에서 나눔): 바닥·조명·장애물·부서지는 것·적 구성, 그리고 영웅 난이도 단계. 상태는 main에 그대로
## (main.gd에는 class_name이 없어 m은 타입 없이 받는다).


## 무대 바꾸기: 바닥·소품, 적 구성. 고르기 화면과 시작 때 부른다.
static func stage(m, st: StageTheme) -> void:
	if st == null:
		return
	if m.run_config:
		m.run_config.stage = st
	if m.player:  # 걸을 수 있는 곳 (배 갑판 안·지붕 밖 등, WalkArea)
		m.player.walk_area = st.walk_area
	if m.spawner:
		m.spawner.walk_area = st.walk_area
	var arena := m.get_node_or_null("Arena") as Arena
	if arena:
		arena.apply_theme(st)
		arena.clamp_camera(m.get_node_or_null("Player/Camera2D") as Camera2D)
		if arena.lights:
			arena.lights.follow(m.get_node_or_null("Player") as Node2D)
		if m.spawner and arena.obstacles:
			m.spawner.blocked_check = arena.obstacles.blocks
		if arena.hazards:
			_wire_hazards(m, arena.hazards)
		if m.breakables:
			m.breakables.obstacles = arena.obstacles
			m.breakables.setup(st.breakable, arena.rect.grow(-maxf(st.prop_inset, 160.0)), st.seed)
	if m.spawner and not st.spawn_table.is_empty():
		m.spawner.spawn_table = st.spawn_table
		m.spawner.spawn_weights = st.spawn_weights
		m.spawner.unlock_times = st.unlock_times
	if m.spawner and st.elite:
		m.spawner.elite_data = BossHpScale.for_hero(st.elite, _hero(m))  # 중간 보스면 영웅 배율
	if m.spawner and st.boss:
		m.spawner.boss_data = BossHpScale.for_hero(st.boss, _hero(m))  # 영웅 화력만큼 보스 체력
	if m.spawner:
		m.spawner.set_waves(st.waves)  # 하데스 슬라이스: 물결 모드 (데이터가 없으면 지금 방식)
	difficulty(m, st)
	if m.hud:
		m.hud.stage = st


## 무대 적 구성에 난이도를 입힌다 (적 데이터 사본, 나오는 간격·최대 수). 여러 번 불러도 겹치지 않게 원래 값에서.
static func difficulty(m, st: StageTheme) -> void:
	if m.spawner == null or m.difficulty == null:
		return
	if m._base_spawn.is_empty():
		m._base_spawn = {"start": m.spawner.interval_start, "min": m.spawner.interval_min, "alive": m.spawner.max_alive}
	var tier: int = m.difficulty_tier()
	var table: Array[EnemyData] = []
	for e in (st.spawn_table if not st.spawn_table.is_empty() else m.spawner.spawn_table):
		table.append(m.difficulty.scaled(e, tier))
	m.spawner.spawn_table = table
	var elite: EnemyData = st.elite if st.elite else m.spawner.elite_data
	m.spawner.elite_data = m.difficulty.scaled(BossHpScale.for_hero(elite, _hero(m)) if st.elite else elite, tier)  # 중간 보스면 영웅 배율 × 단계
	var boss: EnemyData = st.boss if st.boss else m.spawner.boss_data
	m.spawner.boss_data = m.difficulty.scaled(BossHpScale.for_hero(boss, _hero(m)) if st.boss else boss, tier)  # 영웅 배율 × 단계
	m.spawner.interval_start = m._base_spawn["start"] * m.difficulty.interval(tier)
	m.spawner.interval_min = m._base_spawn["min"] * m.difficulty.interval(tier)
	m.spawner.max_alive = (st.waves.max_alive if st.waves else m._base_spawn["alive"]) + m.difficulty.alive_add(tier)
	m.spawner.data_scaler = func(e: EnemyData) -> EnemyData: return m.difficulty.scaled(e, tier)
	m.spawner.elite_scaler = func(e: EnemyData) -> EnemyData: return m.difficulty.scaled(BossHpScale.for_hero(e, _hero(m)), tier)


## 무대 장치에 영웅·적·박자 조건을 넣는다: 판 진행 중이고 강화 고르기·길잡이(튜토리얼)가 아닐 때만 박자가 흐른다.
static func _wire_hazards(m, hz: StageHazards) -> void:
	hz.player = m.player
	hz.spawner = m.spawner
	hz.running_check = func() -> bool:
		return m.state != null and m.state.is_playing() and not m.is_choosing() 			and (m.tutorial_director == null or not m.tutorial_director.running())


static func _hero(m) -> HeroData:
	return m.player.hero if m.player else null
