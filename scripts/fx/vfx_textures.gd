class_name VfxTextures
extends RefCounted
## 기술 이펙트 입자 텍스처를 코드로 만든다 (엔진 기본 Image·FastNoiseLite, 외부 이미지 없음 → APK 용량 0).
## 모양마다 한 번만 만들어 공유한다.

const SIZE := 64

static var _cache: Dictionary = {}


static func get_texture(shape: SkillVfxData.Shape) -> Texture2D:
	if not _cache.has(shape):
		_cache[shape] = ImageTexture.create_from_image(make_image(shape))
	return _cache[shape]


static func make_image(shape: SkillVfxData.Shape) -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.9
	for y in SIZE:
		for x in SIZE:
			# -1~1 좌표
			var p := Vector2((x + 0.5) / SIZE * 2.0 - 1.0, (y + 0.5) / SIZE * 2.0 - 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(alpha(shape, p, noise), 0.0, 1.0)))
	return img


## 모양별 불투명도 (p는 -1~1).
static func alpha(shape: SkillVfxData.Shape, p: Vector2, noise: FastNoiseLite) -> float:
	var d := p.length()
	match shape:
		SkillVfxData.Shape.STAR:  # 네 갈래 반짝임
			var arms := maxf(exp(-p.y * p.y * 120.0) * (1.0 - absf(p.x)), exp(-p.x * p.x * 120.0) * (1.0 - absf(p.y)))
			return arms + pow(maxf(1.0 - d * 2.2, 0.0), 1.5)
		SkillVfxData.Shape.PETAL:  # 끝이 가는 꽃잎
			var q := Vector2(p.x / 0.55, p.y)
			var tip := 1.0 - smoothstep(0.75, 1.0, q.length() + maxf(-p.y, 0.0) * 0.25)
			return tip
		SkillVfxData.Shape.SHARD:  # 가로로 긴 불똥·물줄기
			return exp(-p.y * p.y * 12.0) * maxf(1.0 - absf(p.x), 0.0)
		SkillVfxData.Shape.SPLAT:  # 가장자리가 고르지 않은 먹 덩어리
			var edge := 0.62 + 0.28 * noise.get_noise_2d(p.angle() * 3.0, 0.0)
			return 1.0 - smoothstep(edge - 0.12, edge, d)
		_:  # DOT, GLYPH 바탕: 부드러운 점
			return pow(maxf(1.0 - d, 0.0), 1.5)
