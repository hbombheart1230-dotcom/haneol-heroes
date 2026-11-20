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


## 같은 시트는 SpriteFrames를 한 번만 만든다 (적 30마리가 공유).
static var _cache: Dictionary = {}


func shared_sprite_frames() -> SpriteFrames:
	var key := resource_path if resource_path != "" else str(get_instance_id())
	if not _cache.has(key):
		_cache[key] = build_sprite_frames()
	return _cache[key]


func has_anim(anim: String) -> bool:
	return anim_names.has(anim)


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
