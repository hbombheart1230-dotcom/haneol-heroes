extends RefCounted
## 실시간 3D 동작 묶음 만들기: 설정의 동작마다 원본(.glb)에서 꺼내 구간을 자르고 구운 시트와 같은 길이로 맞춘다.
## 같은 영웅은 한 번만 만들어 모든 인스턴스가 나눠 쓴다 (적 8마리가 같은 모델이어도 동작 메모리는 하나).
## 3D 클래스를 쓰므로 3D를 끈 엔진(커스텀 안드로이드 템플릿)에서는 불러오지 않는다.

static var _cache: Dictionary = {}


## durations: 동작 키 → 초 (구운 시트의 칸 수 ÷ fps). 없으면 원본 구간 길이 그대로.
static func get_or_build(d: Live3DHeroData, model: Node, durations: Dictionary) -> AnimationLibrary:
	var key := d.resource_path if d.resource_path != "" else str(d.get_instance_id())
	if _cache.has(key):
		return _cache[key]
	var lib := AnimationLibrary.new()
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var root_track := NodePath("%s:%s" % [d.skeleton_path, d.root_bone])
	var bi := skel.find_bone(d.root_bone)
	var rest := skel.get_bone_rest(bi).origin if bi >= 0 else Vector3.ZERO
	var sources: Dictionary = {}  # 파일 → 동작 (추가 파일은 동작 하나씩)
	for c in d.clips:
		var src := _source(ap, String(c.get("file", "")), String(c.get("src", "")), sources)
		if src == null:
			push_warning("live3d: no clip for %s" % c["key"])
			continue
		var win := ClipSlicer.window(c, src.length)
		var out_len := float(durations.get(c["key"], win.y - win.x))
		# 칸 시각표는 구운 시트 길이로 맞추는 동작(영웅)에만. 적 공격은 원본 시각 그대로 두고 직접 놓는다 (EnemySprite3D).
		var times: Array = c.get("times", []) if durations.has(c["key"]) else []
		lib.add_animation(StringName(c["key"]), ClipSlicer.slice(src, win, out_len, bool(c.get("loop", false)),
			root_track, rest, times))
	_cache[key] = lib
	return lib


static func _source(ap: AnimationPlayer, file: String, src: String, sources: Dictionary) -> Animation:
	if file == "":
		return _find(ap, src)
	if not sources.has(file) and file.get_extension() in ["res", "tres"]:  # 미리 꺼내 둔 동작 (모델·텍스처 없이)
		sources[file] = load(file) as Animation
	if not sources.has(file):
		var other: Node = (load(file) as PackedScene).instantiate()
		var oap := other.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clips := Array(oap.get_animation_list()).filter(func(n: StringName) -> bool: return n != &"RESET")
		sources[file] = oap.get_animation(clips[0]) if clips.size() == 1 else _find(oap, src)
		other.free()
	return sources[file]


## 이름 찾기: 같은 이름 → 영문·숫자만 비교 ("Run 2" = "Run_02"). 굽기 도구의 find_anim과 같은 규칙 (줄인 것).
static func _find(ap: AnimationPlayer, src: String) -> Animation:
	for cand in src.split("|", false):
		for n in ap.get_animation_list():
			if n == cand or norm(n) == norm(cand):
				return ap.get_animation(n)
	return null


static func norm(n: String) -> String:
	var re := RegEx.create_from_string("[a-z]+|[0-9]+")
	var out := ""
	for m in re.search_all(n.to_lower()):
		var part := m.get_string()
		out += str(part.to_int()) if part.is_valid_int() else part
	return out
