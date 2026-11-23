extends PlayerView
## 실시간 3D 영웅 그림 (시험, docs/research/live3d_spike.md). PlayerView의 상태·연출은 그대로 쓰고
## (먹 그림자, 대시 색·투명, 피격 번쩍임·깜빡임, 착지 눌림, 내딛기, 역경직 멈춤, 연타 자세 유지)
## 몸 그림만 구운 칸 대신 3D 모델을 매 프레임 그린 화면(SubViewport)으로 바꾼다.
## data/live3d/<영웅 id>.tres가 없거나 모델 파일이 없으면 구운 그림 그대로 (부모와 같다).
## 켜기: 프로젝트 설정 hh/art/live3d = true (Live3DSwitch가 PlayerView를 이 스크립트로 바꾼다).

const RIG_SCRIPT := "res://scripts/art/live3d/live3d_rig.gd"
const INK_SHADER := "res://shaders/ink_live.gdshader"

var live: Live3DHeroData
var rig: Node
## 달리며 공격 (윗몸만): 남은 시간, 동작, 처음부터 다시, 칼이 닿아 멈춘 남은 시간.
var _upper_left: float = 0.0
var _upper_anim: String = ""
var _upper_restart: bool = false
var _upper_stop: float = 0.0


static func data_path(hero_id: StringName) -> String:
	return "res://data/live3d/%s.tres" % hero_id


func _setup_sprite(h: HeroData) -> void:
	super(h)
	_attach_live(h)


func refresh() -> void:
	super()
	if player and player.hero and _sprite:
		_attach_live(player.hero)


func _attach_live(h: HeroData) -> void:
	if rig:
		rig.queue_free()
		rig = null
	live = null
	var path := data_path(h.id)
	if not ResourceLoader.exists(path):
		return
	var d := load(path) as Live3DHeroData
	if d == null or not ResourceLoader.exists(d.model_path):
		return  # 모델이 없는 PC·APK: 구운 그림 그대로
	live = d
	rig = (load(RIG_SCRIPT) as GDScript).new()
	rig.name = "Live3DRig"
	add_child(rig)
	rig.setup(d, durations(_sheet))
	_sprite.sprite_frames = single_frames(_sheet, rig.texture())
	var mat := ShaderMaterial.new()
	mat.shader = load(INK_SHADER)
	for key in d.ink:
		mat.set_shader_parameter(key, d.ink[key])
	_sprite.material = mat


## 동작 키 → 구운 시트의 한 번 길이(초). 같은 길이로 잘라야 피해·멈춤 시점이 그대로다.
static func durations(sheet: SpriteSheetSet) -> Dictionary:
	var out := {}
	if sheet == null:
		return out
	for i in sheet.anim_names.size():
		out[sheet.anim_names[i]] = sheet.frame_counts[i] / maxf(sheet.fps[i], 1.0)
	return out


## 부모 로직이 고르는 "<동작>_<방향>" 이름마다 칸 하나 = 3D 화면 텍스처 (부모 코드를 바꾸지 않으려고).
static func single_frames(sheet: SpriteSheetSet, tex: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for anim in sheet.anim_names:
		for d in sheet.directions:
			var n := StringName("%s_%d" % [anim, d])
			sf.add_animation(n)
			sf.set_animation_loop(n, true)
			sf.add_frame(n, tex)
	return sf


## 구운 칸 번호 → 잘린 동작 시각 (시트 길이 = 칸 수 ÷ fps 로 맞췄으므로 칸 ÷ fps).
func frame_time(anim: String, frame: int) -> float:
	var i := _sheet.anim_names.find(anim) if _sheet else -1
	return frame / maxf(_sheet.fps[i], 1.0) if i >= 0 else 0.0


func _update_sprite(delta: float) -> void:
	if rig == null:
		super(delta)
		return
	var restart := _restart and current_anim() == _oneshot
	var from := _oneshot_from
	super(delta)  # 타이머·색·눌림·내딛기·speed_scale(멈춤 포함)는 부모가 계산한다
	var cur := available_anim(current_anim())
	var seek := frame_time(cur, from) if restart else -1.0
	if _posing:
		seek = 0.0  # 충전: 모으는 자세(첫 칸)에 멈춤
	rig.set_facing(player.facing, delta)
	rig.play_body(cur, restart, seek, _sprite.speed_scale)
	_update_upper(delta, cur)
	if _blend:  # 2D 겹침 그림(AnimBlend)은 끈다: 3D가 진짜로 섞고, 찍어 둔 칸이 살아 있는 화면이라 겹쳐 보인다
		_blend.visible = false


## 달리며 공격: 다리는 달리기, 윗몸은 공격 동작 (구운 그림은 달릴 때 공격 동작을 못 튼다).
func _update_upper(delta: float, cur: String) -> void:
	_upper_left = maxf(_upper_left - delta, 0.0)
	_upper_stop = maxf(_upper_stop - delta, 0.0)
	var on := _upper_left > 0.0 and cur == "run"
	rig.set_upper(_upper_anim, _upper_restart, on, 0.0 if _upper_stop > 0.0 else 1.0, delta)
	_upper_restart = false


## 움직이는 중 공격은 윗몸만 (다리는 달리기 그대로). 부모는 손 평타를 움직이는 중에도 몸 전체로 틀지만(M1),
## 3D는 윗몸 겹치기로 같은 칼질을 보이면서 다리를 멈추지 않는다.
func _on_auto_swing(d: Vector2, h: int) -> void:
	if not (rig and is_moving() and not live.upper_bones.is_empty() and player.hurt_time_left() <= 0.0):  # 맞는 중엔 몸 전체 (M1)
		super(d, h)
	else:
		_upper_anim = _attack.chain_anim() if _attack else "attack"
		_upper_left = anim_seconds(_upper_anim, 0.35) + Feedback.feel_data().combo_hold_time * 0.5
		_upper_restart = true


func _on_melee_contact(d: Vector2, hits: int) -> void:
	super(d, hits)
	if rig and _upper_left > 0.0 and hits > 0 and not GameTime.is_stopped():
		_upper_stop = Feedback.feel_data().impact_data().hero_hitstop(hits, _attack != null and _attack.last_heavy)
