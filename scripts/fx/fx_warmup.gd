class_name FxWarmup
extends RefCounted
## 효과 첫 사용 멈칫 없애기 (예열): 판을 시작할 때(무대 제목 띠 동안, 첫 물결 전) 그 판에 쓰일 영웅 기술·평타·피격·적 효과가
## 처음 쓸 때 하던 일을 미리 한다. 무엇을 할지는 데이터에서 모은다 (영웅 데이터·무대 적 목록·효과 설정을 따라 내려가며),
## 그래서 기술·적이 늘어도 목록을 손으로 고치지 않는다. 측정·원인: docs/research/fx_warmup.md, tools/perf/first_use_perf.gd.
##   1. 시트 자르기 (VfxSheets: 압축 풀기 + 장마다 텍스처) — 기술 그림 시트, 탄 시트 (<이름>_sheet + <이름>_sheet_grid)
##   2. 코드로 만드는 입자 그림 (VfxTextures, 픽셀마다 계산)
##   3. 잡음 텍스처를 만드는 재질 (Projectile.flow_material)
##   4. 늦게 불러오는 효과 설정 (…Data.get_default)
##   5. 그리기 한 번 (FxWarmupLayer): 모은 그림을 효과 재질(셰이더·더하기 섞기)로 거의 투명하게 — 셰이더·텍스처 첫 사용, 글꼴 크기

## 측정 도구가 끌 수 있다 (전/후 비교).
static var enabled: bool = true
## 마지막 예열에 걸린 시간(ms, 그리기 한 번 제외)과 모은 수 (측정 보고용).
static var last_ms: float = 0.0
## 원인 나누기 (측정 도구): 건너뛸 부분 — "sheets" 시트 자르기, "shapes" 입자 그림, "flow" 잡음 재질, "draw" 그리기 한 번.
static var skip: PackedStringArray = PackedStringArray()
static var last_counts: String = ""
## 따라 내려갈 깊이 상한 (영웅 → 기술 → 효과 → 그림이면 충분).
const MAX_DEPTH := 6


## 이 판 예열: 모으고, 미리 만들고, 그리기 한 번을 parent 밑에 건다. 반환: 모은 것 (없으면 빈 사전).
static func run(parent: Node, hero: HeroData, stage: StageTheme) -> Dictionary:
	if not enabled or parent == null:
		return {}
	var t0 := Time.get_ticks_usec()
	var found := collect(roots(hero, stage))
	prepare(found)
	if not skip.has("draw"):
		var layer := FxWarmupLayer.new()
		layer.textures = found["textures"]
		layer.words = found["words"]
		parent.add_child(layer)
	last_ms = (Time.get_ticks_usec() - t0) / 1000.0
	last_counts = "%s textures %d vfx %d sheets %d words %d" % [hero.id if hero else &"-", found["textures"].size(),
		found["vfx"].size(), found["sheets"].size(), found["words"].size()]
	return found


## 따라 내려갈 시작점: 영웅, 무대 적(물결·표·정예·보스), 늦게 불러오는 효과 설정들.
static func roots(hero: HeroData, stage: StageTheme) -> Array:
	var out: Array = [hero, stage, Feedback.feel_data(), RangedFeelData.get_default(), DeathStyleData.get_default(),
		BrushFlickData.get_default(), SkillHitFeelData.get_default(), SkillStageFeel.get_default()]
	return out.filter(func(r: Variant) -> bool: return r != null)


## 자원 그래프를 따라가며 모은다: textures (Texture2D), vfx (SkillVfxData), sheets ([시트, 칸 수(Vector2i), 장 수]),
## words (기술 이름 — 컷인 글씨). 순수 계산 (그리기·만들기 없음).
static func collect(start: Array) -> Dictionary:
	var found := {"textures": [], "vfx": [], "sheets": [], "words": PackedStringArray()}
	var seen := {}
	for r in start:
		_walk(r, found, seen, 0)
	return found


static func _walk(v: Variant, found: Dictionary, seen: Dictionary, depth: int) -> void:
	if depth > MAX_DEPTH:
		return
	if v is Array:
		for x in v:
			_walk(x, found, seen, depth + 1)
		return
	if v is Dictionary:
		for x in (v as Dictionary).values():
			_walk(x, found, seen, depth + 1)
		return
	if not (v is Resource) or v is Script or v is Shader or v is PackedScene or v is AudioStream or v is Font:
		return
	var r := v as Resource
	var id := r.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	if r is Texture2D:
		if not (r is NoiseTexture2D):
			found["textures"].append(r)
		return
	if r is SpriteFrames:  # 몸 그림 (영웅·적 시트): 장면이 이미 그리므로 따라가지 않는다
		return
	if r is SkillVfxData:
		found["vfx"].append(r)
	if r is SkillDef and String((r as SkillDef).display_name) != "":
		found["words"].append(String((r as SkillDef).display_name))
	for p in r.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var n := String(p["name"])
		var val: Variant = r.get(n)
		if n.ends_with("_sheet") and val is Texture2D and (n + "_grid") in r:  # 탄 시트 (해일검기 물결 등)
			var g: Vector2i = r.get(n + "_grid")
			var cnt: int = int(r.get(n + "_count")) if (n + "_count") in r else 0
			found["sheets"].append([val, g, cnt])
		if val is Resource or val is Array or val is Dictionary:
			_walk(val, found, seen, depth + 1)


## 처음 쓸 때 CPU가 하던 일을 지금: 시트 자르기, 입자 그림, 잡음 재질.
static func prepare(found: Dictionary) -> void:
	if not skip.has("sheets"):
		for v in found.get("vfx", []):
			var d := v as SkillVfxData
			d.decal_at(0.0)
			d.strip_at(0.0)
		for s in found.get("sheets", []):
			VfxSheets.frames(s[0], (s[1] as Vector2i).x, (s[1] as Vector2i).y, int(s[2]))
	if not skip.has("shapes"):
		for shape in SkillVfxData.Shape.values():
			VfxTextures.get_texture(shape)
	if not skip.has("flow"):
		Projectile.flow_material()
