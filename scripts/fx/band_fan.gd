class_name BandFan
extends RefCounted
## 고리 그림 조각을 "띠 두께 고정"으로 그리는 삼각형 차례 (VfxPieces에서 나눔).
## 점 배치: 0 = 가운데, 1..m = 바깥 테(rim), m+1..2m = 안쪽 테. 가운데~안쪽 테는 그림 안쪽 빈 곳, 안쪽~바깥 테는 고리 띠.
## 그림을 판정 끝까지 키워도 띠는 예전 두께 그대로 (해룡참 4타, 사용자 07f0d8f "두께는 그냥 두고 원 둘레 크기를").


## 바깥 테 점 m개짜리 부채꼴의 삼각형 차례.
static func indices(m: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for j in m - 1:
		var o0 := j + 1
		var o1 := j + 2
		var i0 := m + j + 1
		var i1 := m + j + 2
		idx.append_array([0, i0, i1, i0, o0, o1, i0, o1, i1])
	return idx


## 안쪽 테 점: 바깥 테 점 rim(가운데 c에서 off만큼)의 안쪽 thick(px) 자리, uv는 그림의 띠 안쪽 끝 반지름 band_uv.
static func inner(c: Vector2, off: Vector2, thick: float, uv_dir: Vector2, band_uv: float) -> Array:
	var len := off.length()
	var p := c + off * (maxf(len - thick, 0.0) / maxf(len, 0.001))
	return [p, Vector2(0.5, 0.5) + uv_dir * band_uv]
