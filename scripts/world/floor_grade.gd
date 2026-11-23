class_name FloorGrade
extends RefCounted
## shaders/floor_grade.gdshader의 fragment()를 그대로 옮긴 순수 계산 (테스트·도구용: 무대 바닥 명암·색 확인).

const LUMA := Vector3(0.2126, 0.7152, 0.0722)


static func luma(c: Color) -> float:
	return c.r * LUMA.x + c.g * LUMA.y + c.b * LUMA.z


static func apply(c: Color, l: StageLook) -> Color:
	var y := luma(c)
	var v := Vector3(c.r, c.g, c.b)
	v = Vector3(y, y, y).lerp(v, l.saturation) * l.value_mult
	v = ((v - Vector3.ONE * l.pivot) * l.contrast + Vector3.ONE * l.pivot).max(Vector3.ZERO)
	var y2 := v.dot(LUMA)
	var t := clampf((y2 - l.tint_split * 0.4) / (l.tint_split * 1.4), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var tc := l.shadow_tint.lerp(l.light_tint, t)
	var tv := Vector3(tc.r, tc.g, tc.b) * (y2 / maxf(luma(tc), 0.02))
	v = v.lerp(tv, l.tint_mix)
	return Color(v.x, v.y, v.z)


## 무대 배경 그림을 n×n으로 줄여 보정한 뒤 [평균 밝기, 밝기 편차, 평균 채도, 평균 색(Color)].
static func stats(st: StageTheme, n: int = 64) -> Array:
	var img := (load(st.background_path) as Texture2D).get_image()
	img.resize(n, n)
	var sum := 0.0
	var sq := 0.0
	var sat := 0.0
	var avg := Color(0, 0, 0)
	for y in n:
		for x in n:
			var g := apply(img.get_pixel(x, y), st.look)
			var l := luma(g)
			sum += l
			sq += l * l
			sat += g.s
			avg += g
	var k := float(n * n)
	var mean := sum / k
	return [mean, sqrt(maxf(sq / k - mean * mean, 0.0)), sat / k, Color(avg.r / k, avg.g / k, avg.b / k)]
