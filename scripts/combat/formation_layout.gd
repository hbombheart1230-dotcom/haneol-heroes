class_name FormationLayout
extends RefCounted
## 대형 자리 계산 (순수 로직, FormationData.shape): 가운데 기준 자리 n개. facing = 영웅 쪽 방향 (LINE은 이에 수직으로 늘어선다).


static func offsets(d: FormationData, n: int, facing: Vector2, seed_i: int = 0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if n <= 0:
		return out
	var f := facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	var side := f.orthogonal()
	match d.shape:
		FormationData.Shape.LINE:
			for i in n:
				out.append(side * (i - (n - 1) * 0.5) * d.spacing)
		FormationData.Shape.ARC:  # 영웅 쪽으로 오목 (학익진): 원 중심이 영웅 쪽 radius에 있고, 가운데가 맨 뒤·양 날개가 앞
			var span := deg_to_rad(d.arc_deg) if d.arc_deg > 0.0 else d.spacing * (n - 1) / maxf(d.radius, 1.0)
			var c := f * d.radius
			for i in n:
				var a := (i - (n - 1) * 0.5) * (span / maxf(n - 1, 1))
				out.append(c + (-f).rotated(a) * d.radius)
		FormationData.Shape.RING:
			for i in n:
				out.append(Vector2.RIGHT.rotated(TAU * i / n) * d.radius)
		FormationData.Shape.SCATTER:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_i
			for i in n:
				out.append(Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5)).rotated(f.angle() - PI * 0.5) * d.spacing * sqrt(n))
	return out
