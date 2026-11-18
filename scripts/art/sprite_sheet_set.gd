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
