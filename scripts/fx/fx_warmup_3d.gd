class_name FxWarmup3D
extends RefCounted
## 예열 (FxWarmup)의 3D 갈래: 그 판에 나오는 실시간 3D 적 (data/live3d/<적 id>.tres가 있는 우두머리·정예·무리)을
## 무대 제목 띠 동안 한 번 미리 그린다 — 모델 불러오기·3D 셰이더·먹선 재질(enemy_live) 첫 컴파일을 등장 순간이 아니라 판 시작 때.
## 영웅 3D는 판 시작부터 늘 그려지므로 따로 하지 않는다. 그린 뒤 frames프레임이면 지운다 (모델 자원은 캐시에 남아 등장 때 바로 쓴다).

const RIG_SCRIPT := "res://scripts/art/live3d/live3d_rig.gd"
## 거의 안 보이는 불투명도 (FxWarmupLayer와 같다).
const ALPHA := 0.012


## 그 판에서 3D로 나올 적 (중복 없이).
static func live_enemies(stage: StageTheme) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	if stage == null:
		return out
	var list: Array = [stage.boss, stage.elite]
	if stage.waves:
		for w: WaveData in stage.waves.waves:
			list.append_array(w.elite_group)
	for d in list.duplicate():
		if d is EnemyData:
			for ph: BossPhaseData in (d as EnemyData).phases:
				list.append_array(ph.summon)
	for d in list:
		if d is EnemyData and not out.has(d) and EnemySprite3D.live_data(d) != null:
			out.append(d)
	return out


## parent 아래에 3D 적마다 리그 + 그 화면을 쓰는 스프라이트 (카메라 가운데, 거의 투명)를 frames프레임 둔다. 반환: 둔 수.
static func run(parent: Node, stage: StageTheme, frames: int = 3) -> int:
	if parent == null or not EnemySprite3D.Switch.enabled():
		return 0
	var n := 0
	for d in live_enemies(stage):
		var l := EnemySprite3D.live_data(d)
		var holder := Node2D.new()
		holder.name = "Warmup3D_%s" % d.id
		holder.modulate = Color(1, 1, 1, ALPHA)
		parent.add_child(holder)
		var rig: Node = (load(RIG_SCRIPT) as GDScript).new()
		holder.add_child(rig)
		rig.setup(l, EnemySprite3D.durations(d.sprite_sheet, l))
		var s := Sprite2D.new()
		s.texture = rig.texture()
		s.material = EnemySprite3D.material_for(d, l, null)
		s.scale = Vector2.ONE * 0.05
		holder.add_child(s)
		var cam := parent.get_viewport().get_camera_2d() if parent.is_inside_tree() else null
		holder.global_position = cam.get_screen_center_position() if cam else Vector2.ZERO
		_free_after(holder, frames)
		n += 1
	return n


static func _free_after(node: Node, frames: int) -> void:
	if not node.is_inside_tree():
		node.queue_free()
		return
	var tree := node.get_tree()
	for i in frames:
		await tree.process_frame
	if is_instance_valid(node):
		node.queue_free()
