class_name SpriteSheetSet
extends Resource
## 구워진 8방향 스프라이트 시트 묶음 (tools/bake/bake_sprites.gd가 만든다).
## 시트 하나 = 애니메이션 하나. 행 = 방향(화면 오른쪽부터 시계 방향 45도씩), 열 = 프레임.

@export var frame_size: int = 192
@export var directions: int = 8
@export var anim_names: PackedStringArray = PackedStringArray()
@export var textures: Array[Texture2D] = []
@export var frame_counts: PackedInt32Array = PackedInt32Array()
@export var fps: PackedFloat32Array = PackedFloat32Array()
@export var loops: Array[bool] = []
## 동작마다 맞닿는 프레임 (피해·멈춤·소리가 나는 칸, 없으면 -1). 굽기 작업의 strike(초)에서.
@export var strike_frames: PackedInt32Array = PackedInt32Array()
## 동작마다 무기 끝 위치 (칸 가운데 기준 px, [방향 × 프레임 수 + 프레임]). 공격·던지기만, 나머지는 빈 배열.
@export var tips: Array[PackedVector2Array] = []


## 같은 시트는 SpriteFrames를 한 번만 만든다 (적 30마리가 공유).
static var _cache: Dictionary = {}


func shared_sprite_frames() -> SpriteFrames:
	var key := resource_path if resource_path != "" else str(get_instance_id())
	if not _cache.has(key):
		_cache[key] = build_sprite_frames()
	return _cache[key]


## 되풀이 동작인지 (달리기·돌진 등: 예고 진행으로 칸을 고르지 않고 그냥 돈다).
func is_loop(anim: String) -> bool:
	var i := anim_names.find(anim)
	return i >= 0 and i < loops.size() and loops[i]


func has_anim(anim: String) -> bool:
	return anim_names.has(anim)


func frame_count(anim: String) -> int:
	var i := anim_names.find(anim)
	return frame_counts[i] if i >= 0 else 0


## 맞닿는 프레임 번호. 기록이 없으면 마지막 프레임의 앞 (가운데보다 조금 뒤).
func strike_frame(anim: String) -> int:
	var i := anim_names.find(anim)
	if i < 0:
		return 0
	if i < strike_frames.size() and strike_frames[i] >= 0:
		return strike_frames[i]
	return clampi(int(frame_counts[i] * 0.6), 0, frame_counts[i] - 1)


## 무기 끝 (칸 가운데 기준 px). 기록이 없으면 Vector2.INF.
func tip(anim: String, dir: int, frame: int) -> Vector2:
	var i := anim_names.find(anim)
	if i < 0 or i >= tips.size() or tips[i].is_empty():
		return Vector2.INF
	var k := dir * frame_counts[i] + clampi(frame, 0, frame_counts[i] - 1)
	return tips[i][k] if k >= 0 and k < tips[i].size() else Vector2.INF


## "<anim>_<dir>" 이름의 애니메이션들을 가진 SpriteFrames를 만든다.
func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for i in anim_names.size():
		for d in directions:
			var name := StringName("%s_%d" % [anim_names[i], d])
			sf.add_animation(name)
			sf.set_animation_speed(name, fps[i])
			sf.set_animation_loop(name, loops[i])
			for f in frame_counts[i]:
				var at := AtlasTexture.new()
				at.atlas = textures[i]
				at.region = Rect2(f * frame_size, d * frame_size, frame_size, frame_size)
				sf.add_frame(name, at)
	return sf


## 화면 방향 벡터 → 방향 번호 (0 = 오른쪽, 시계 방향).
func dir_index(v: Vector2) -> int:
	if v.length_squared() < 0.0001:
		return 2  # 아래(정면)
	return posmod(roundi(v.angle() / (TAU / directions)), directions)


## 방향 번호, 단 지금 방향(current)에서 칸 경계를 margin_deg 이상 넘어야 바꾼다.
## 손가락이 경계 근처에서 떨릴 때 두 방향 그림이 번갈아 깜빡이지 않게 (끊겨 보임 방지).
func dir_index_sticky(v: Vector2, current: int, margin_deg: float = 10.0) -> int:
	if v.length_squared() < 0.0001 or current < 0:
		return dir_index(v) if current < 0 else current
	var sector := TAU / directions
	var center := current * sector
	var diff := absf(wrapf(v.angle() - center, -PI, PI))
	if diff <= sector * 0.5 + deg_to_rad(margin_deg):
		return current
	return dir_index(v)
