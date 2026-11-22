class_name VfxSheets
extends RefCounted
## 프레임 시트(가로 cols × 세로 rows 칸, 왼쪽 위 → 오른쪽, 줄 바꿈)를 장마다 텍스처로 잘라 한 번만 만들어 둔다.
## 장마다 따로 텍스처라서 조각 다각형·셰이더 감김이 정지 그림과 똑같이 쓰인다. 규격은 docs/skill_vfx_sheets.md.

static var _cache: Dictionary = {}


## t초 때 몇 번째 장인지 (순수 계산). loop가 아니면 마지막 장에 멈춘다.
static func index_at(count: int, fps: float, t: float, loop: bool) -> int:
	if count <= 1 or fps <= 0.0:
		return 0
	var i := int(floor(maxf(t, 0.0) * fps))
	return i % count if loop else mini(i, count - 1)


static func frames(sheet: Texture2D, cols: int, rows: int, count: int = 0) -> Array:
	if sheet == null:
		return []
	var key := "%d:%d:%d:%d" % [sheet.get_instance_id(), cols, rows, count]
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	var img := sheet.get_image()
	if img == null or cols <= 0 or rows <= 0:
		_cache[key] = out
		return out
	if img.is_compressed():
		img.decompress()
	var cw := img.get_width() / cols
	var ch := img.get_height() / rows
	var n := cols * rows if count <= 0 else mini(count, cols * rows)
	for i in n:
		var r := img.get_region(Rect2i((i % cols) * cw, (i / cols) * ch, cw, ch))
		out.append(ImageTexture.create_from_image(r))
	_cache[key] = out
	return out


static func frame_at(sheet: Texture2D, cols: int, rows: int, count: int, fps: float, t: float, loop: bool) -> Texture2D:
	var f := frames(sheet, cols, rows, count)
	if f.is_empty():
		return null
	return f[index_at(f.size(), fps, t, loop)]
