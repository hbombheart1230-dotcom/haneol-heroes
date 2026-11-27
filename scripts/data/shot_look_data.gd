class_name ShotLookData
extends Resource
## 적 탄의 겉모습 (EnemyArrow._draw). EnemyAttackData.shot_look이 비면 화살 그림 (궁수). 판정·속도·피해와는 별개.
## 조총 탄 (테스터 "임진왜란인데 왜 화살 쏘냐, 조총 써야지"): 작은 납탄 + 짧은 불빛 꼬리.

## 납탄 반지름(px)·색, 위쪽 빛 한 점 (둥근 쇠 느낌).
@export var ball_radius: float = 6.0
@export var ball_color: Color = Color(0.22, 0.22, 0.25, 1.0)
@export var ball_rim: Color = Color(0.05, 0.05, 0.06, 1.0)
@export var ball_shine: Color = Color(0.85, 0.85, 0.9, 0.9)
## 뒤로 끌리는 불빛 꼬리: 길이(px)·두께(px)·색. 바깥 번짐은 두께 × glow_mult, 진하기 glow_alpha.
@export var tail_length: float = 54.0
@export var tail_width: float = 4.0
@export var tail_color: Color = Color(1.0, 0.78, 0.35, 0.95)
@export var glow_mult: float = 2.6
@export var glow_alpha: float = 0.3

var _tex: ImageTexture


## 꼬리 + 납탄을 한 장 그림으로 (처음 쓸 때 한 번 만든다): 탄마다 그림 한 장이라 화살처럼 한 번에 그려진다.
## 그림 원점 = 탄 자리 = 그림의 오른쪽 끝에서 pad만큼 안 (texture_rect()로 맞춤).
func texture() -> ImageTexture:
	if _tex == null:
		_tex = ImageTexture.create_from_image(_paint())
	return _tex


## 그릴 사각 (탄 자리 기준, 오른쪽이 진행 방향).
func texture_rect() -> Rect2:
	var h := maxf(ball_radius + 2.0, tail_width * glow_mult * 0.5 + 1.0) * 2.0
	var pad := ball_radius + 2.0
	return Rect2(-tail_length, -h * 0.5, tail_length + pad, h)


func _paint() -> Image:
	var r := texture_rect()
	var w := ceili(r.size.x)
	var h := ceili(r.size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ox := -r.position.x
	var oy := h * 0.5
	for y in h:
		for x in w:
			var px := x + 0.5 - ox
			var py := y + 0.5 - oy
			var c := Color(0, 0, 0, 0)
			if px <= 0.0 and px >= -tail_length:  # 꼬리: 탄 쪽이 진하고 뒤로 옅어진다
				var k := 1.0 + px / tail_length
				var glow_w := tail_width * glow_mult * 0.5 * (0.4 + 0.6 * k)
				var core_w := tail_width * 0.5 * k
				if absf(py) <= glow_w:
					c = Color(tail_color, tail_color.a * glow_alpha * k)
				if absf(py) <= core_w and px >= -tail_length * 0.6:
					c = Color(tail_color, tail_color.a * k)
			var d := Vector2(px, py).length()
			if d <= ball_radius + 1.5:
				c = ball_rim
			if d <= ball_radius:
				c = ball_color
			if Vector2(px + ball_radius * 0.3, py + ball_radius * 0.35).length() <= ball_radius * 0.3:
				c = ball_shine
			img.set_pixel(x, y, c)
	return img
