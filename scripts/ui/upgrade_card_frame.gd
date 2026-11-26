class_name UpgradeCardFrame
extends RefCounted
## 강화 패 한 장의 틀 (옻칠 바탕 + 붓 획 테두리)과 종류 띠 색. 쨍한 단색 사각·굵은 같은 색 테두리 대신,
## 채도를 낮춘 종류 색을 먹 번짐 띠(InkPaint.wash_rect)와 붓 획 테두리(InkBatch.stroke)로 쓴다.
## 틀은 InkBatch 한 묶음으로 모아 그리기 호출 한 번 (패 셋의 바탕·테두리가 전에는 패마다 15번).

## 종류 색의 채도·밝기 배율 (순적색은 적 위험 전용이라 처음부터 쓰지 않는다).
const SAT := 0.5
const VAL := 0.8
## 테두리 획 굵기와 안쪽 가는 선, 띠 번짐이 판 밖으로 번지는 만큼.
const EDGE_W := 4.0
const INNER_W := 1.5
const BAND_BLEED := 6.0


## 종류 색을 먹빛으로 낮춘 것 (색 차이는 남기고 쨍함만 뺀다).
static func muted(c: Color) -> Color:
	return Color.from_hsv(c.h, c.s * SAT, c.v * VAL)


## 틀을 batch에 모은다 (flush는 부르는 쪽): 옻칠 바탕, 네 변 붓 획, 안쪽 가는 선.
static func add(batch: InkBatch, r: Rect2, fill: Color, edge: Color) -> void:
	batch.quad(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), fill)
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	var ext := EDGE_W  # 획이 모서리 밖으로 조금 나가야 네 변이 이어져 보인다
	batch.stroke(tl + Vector2(-ext, 0), tr + Vector2(ext, 0), EDGE_W, edge)
	batch.stroke(tr + Vector2(0, -ext), br + Vector2(0, ext), EDGE_W, edge)
	batch.stroke(br + Vector2(ext, 0), bl + Vector2(-ext, 0), EDGE_W, edge)
	batch.stroke(bl + Vector2(0, ext), tl + Vector2(0, -ext), EDGE_W, edge)
	var inner := r.grow(-7.0)
	var ic := Color(edge, edge.a * 0.45)
	batch.line(inner.position, Vector2(inner.end.x, inner.position.y), INNER_W, ic)
	batch.line(Vector2(inner.end.x, inner.position.y), inner.end, INNER_W, ic)
	batch.line(inner.end, Vector2(inner.position.x, inner.end.y), INNER_W, ic)
	batch.line(Vector2(inner.position.x, inner.end.y), inner.position, INNER_W, ic)


## 종류 띠: 낮춘 종류 색의 먹 번짐 (판 폭보다 살짝 넓게 번진다).
static func draw_band(c: CanvasItem, br: Rect2, col: Color, a: float) -> void:
	InkPaint.wash_rect(c, br.grow_individual(BAND_BLEED, BAND_BLEED * 0.5, BAND_BLEED, BAND_BLEED * 0.5), Color(col, a))
