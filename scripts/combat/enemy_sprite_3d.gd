class_name EnemySprite3D
extends EnemySprite
## 실시간 3D 적 그림 (보스부터, docs/research/live3d_spike.md): 구운 칸 대신 3D 모델을 매 프레임 그린 화면(SubViewport)을
## 적의 2D 스프라이트가 쓴다. 상태·자세·번쩍임·판정은 EnemySprite 그대로 (구운 시트의 칸 수·fps·맞닿는 칸·무기 끝).
## data/live3d/<적 id>.tres와 모델이 있고 hh/art/live3d가 켜져 있을 때만. 아니면 구운 그림 그대로 (EnemySprite).
## 공격 동작은 시트의 칸마다 시각(times)을 따라 예고·회복 진행에 맞춰 원본 시각으로 바로 놓는다:
## 예고 끝 = 맞닿는 칸의 시각 = 피해 순간 (구운 그림의 AttackTiming.enemy_frame과 같은 박자, 칸 없이 부드럽게).
## 3D 클래스는 쓰지 않는다 (리그는 경로로만 부른다: 3D를 끈 엔진에서도 이 파일은 불러올 수 있다).

const RIG_SCRIPT := "res://scripts/art/live3d/live3d_rig.gd"
const SHADER := "res://shaders/enemy_live.gdshader"
const META := &"live3d_rig"
## 영웅 3D 그림의 공용 계산 (시트 길이, 한 칸 SpriteFrames). class_name이 없어 경로로.
const PV3D := preload("res://scripts/player/player_view_3d.gd")


static func data_path(id: StringName) -> String:
	return "res://data/live3d/%s.tres" % id


## 그 적의 3D 설정 (없거나 모델이 없으면 null).
static func live_data(d: EnemyData) -> Live3DHeroData:
	if d == null or d.sprite_sheet == null or not ResourceLoader.exists(data_path(d.id)):
		return null
	var l := load(data_path(d.id)) as Live3DHeroData
	return l if l and ResourceLoader.exists(l.model_path) else null


## EnemySprite.setup 뒤: 켜져 있고 3D가 준비된 적이면 리그를 붙이고 스프라이트를 3D 화면 한 칸으로 바꾼다.
static func attach(e: Enemy) -> bool:
	if not Live3DSwitch.enabled() or e.sprite == null:
		return false
	var d := live_data(e.data)
	if d == null:
		return false
	var rig: Node = (load(RIG_SCRIPT) as GDScript).new()
	rig.name = "Live3DRig"
	e.add_child(rig)
	rig.setup(d, durations(e.data.sprite_sheet, d))
	e.sprite.sprite_frames = PV3D.single_frames(e.data.sprite_sheet, rig.texture())
	e.sprite.material = material_for(e.data, d, e.affix)
	e.set_meta(META, rig)
	return true


static func rig_of(e: Enemy) -> Node:
	return e.get_meta(META) if e.has_meta(META) else null


## 동작 키 → 구운 시트의 한 번 길이(초). 칸마다 시각(times)이 있는 공격은 넣지 않는다 (원본 시각 그대로 두고 직접 놓는다).
static func durations(sheet: SpriteSheetSet, d: Live3DHeroData) -> Dictionary:
	var out := PV3D.durations(sheet)
	for c in d.clips:
		if c.has("times") and c["key"] != "hit":
			out.erase(c["key"])
	return out


## 수묵(Live3DHeroData.ink) + 테두리·망령(EnemyData, EnemyLook과 같은 값). 변종이면 변종 색 테두리.
static func material_for(d: EnemyData, l: Live3DHeroData, affix: EliteAffixData) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	for key in l.ink:
		m.set_shader_parameter(key, l.ink[key])
	if d.rim_color.a > 0.0:
		m.set_shader_parameter("rim_color", affix.rim_color if affix else d.rim_color)
		m.set_shader_parameter("rim_width", d.rim_width + (affix.rim_width_add if affix else 0.0))
	else:
		m.set_shader_parameter("rim_color", Color(0, 0, 0, 0))
	m.set_shader_parameter("body_lift", d.body_lift)
	m.set_shader_parameter("body_contrast", d.body_contrast)
	m.set_shader_parameter("army_tint", d.army_tint)
	m.set_shader_parameter("tint_mix", d.tint_mix)
	m.set_shader_parameter("ghost_color", d.ghost_color)
	m.set_shader_parameter("ghost_body_alpha", d.ghost_body_alpha)
	m.set_shader_parameter("ghost_fade", d.ghost_fade)
	m.set_shader_parameter("halo_alpha", d.rim_halo)
	m.set_shader_parameter("ghost_rim_mix", d.ghost_rim_mix)
	return m


## EnemySprite.update가 고른 동작·방향을 3D에 넘긴다. 공격은 예고·회복 진행 → 원본 시각, 나머지는 스프라이트 속도(멈춤 포함).
static func sync(e: Enemy, anim: String, face: Vector2, frame_driven: bool) -> void:
	var rig := rig_of(e)
	if rig == null:
		return
	var l: Live3DHeroData = rig.data
	var clip := l.clip(anim)
	rig.set_facing(face, e.get_physics_process_delta_time())
	var a := e.attack
	if frame_driven and a and clip.has("times"):
		var t := attack_time(clip["times"], e.data.sprite_sheet.strike_frame(anim),
			a.state == EnemyAttack.State.RECOVER, a.windup_ratio(), a.recover_ratio())
		rig.play_body(anim, false, maxf(t - float(clip.get("start", 0.0)), 0.0), 0.0)
	else:
		rig.play_body(anim, false, -1.0, e.sprite.speed_scale)


## 맞는 동작을 처음부터 (EnemySprite.start_hit 뒤).
static func restart_hit(e: Enemy) -> void:
	var rig := rig_of(e)
	if rig:
		rig.play_body("hit", true, 0.0, e.sprite.speed_scale)


## 예고(0→1)는 첫 칸 시각 → 맞닿는 칸 시각, 회복(0→1)은 맞닿는 칸 → 끝 칸. 칸 사이는 곧게 잇는다 (순수 계산).
static func attack_time(times: Array, strike: int, recovering: bool, windup: float, recover: float) -> float:
	if times.is_empty():
		return 0.0
	var last := times.size() - 1
	var s := clampi(strike, 0, last)
	var f := lerpf(s, last, clampf(recover, 0.0, 1.0)) if recovering else s * clampf(windup, 0.0, 1.0)
	var i := mini(int(f), last)
	var j := mini(i + 1, last)
	return lerpf(float(times[i]), float(times[j]), f - i)
