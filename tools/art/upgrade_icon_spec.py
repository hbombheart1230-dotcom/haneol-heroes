"""강화마다 어떤 그림으로 아이콘을 만드는지 (make_upgrade_icons.py의 데이터).

키: (영웅, 강화 id). 값:
  base   "icon:<이름>"  assets/ui/icons/<이름>.png 안쪽 그림 (기술 강화는 그 기술의 그림)
         "bg"           영웅 바탕 (영웅 기술 그림을 흐리고 어둡게) — 기술에 안 묶인 강화
         "hero"         지금 모델과 같은 얼굴의 상반신 (새 원화, make_portraits) — 체력 강화. GPT 그림이 있으면 GPT
                        (사용자가 GPT "강건"을 고름, 2026-11-23. 순신·세종 수염은 나중에 GPT로 다시 그릴 때)
  zoom, focus  안쪽 그림을 얼마나 당겨 어디를 보는지 (같은 기술 강화끼리 다른 부분이 보이게)
  tone   "warm"/"cool"/"dark"/"bright"/"gray"/None — 살짝 바꾼 색감
  over   [(vfx 이름, 크기 비율, 중심 x, 중심 y, 회전 도, 불투명도), ...] assets/vfx 그림을 위에 얹는다
  badge  icon_badges.py의 표지 종류
  gpt    True면 기존 그림만으로는 약해 GPT 그림을 받으면 바꿀 것 (docs/upgrade_icon_prompts.md)
"""

# 영웅별: 테두리를 빌려 올 기술 아이콘, 바탕으로 흐릴 아이콘, 영웅 카드에서 상반신 자를 범위 (y0, y1 비율)
HEROES = {
    "yi_sun_sin": {"frame": "haeryong", "bg": "haeil", "bust": (0.04, 0.42), "bust_x": 0.5},
    "gwanggaeto": {"frame": "quake", "bg": "lightning", "bust": (0.03, 0.36), "bust_x": 0.5},
    "sejong": {"frame": "jeongeum", "bg": "meteor", "bust": (0.03, 0.38), "bust_x": 0.52},
    "shin_saimdang": {"frame": "plum", "bg": "ink_bleed", "bust": (0.02, 0.36), "bust_x": 0.5},
}


def _s(base, badge, zoom=1.0, focus=(0.5, 0.5), tone=None, over=(), gpt=False):
    return {"base": base, "badge": badge, "zoom": zoom, "focus": focus, "tone": tone, "over": list(over), "gpt": gpt}


SPEC = {
    # ── 이순신: 바다·칼날, 푸른색 ──
    ("yi_sun_sin", "haeryong_wide"): _s("icon:haeryong", "range", 1.0),
    ("yi_sun_sin", "haeryong_deep"): _s("icon:haeryong", "damage", 1.7, (0.32, 0.6), "warm"),
    ("yi_sun_sin", "haeryong_finish"): _s("icon:haeryong", "finisher", 1.6, (0.75, 0.3), "warm"),
    ("yi_sun_sin", "pado_more"): _s("icon:pado", "count", 1.0),
    ("yi_sun_sin", "pado_long"): _s("icon:pado", "width", 1.5, (0.4, 0.55), "bright"),
    ("yi_sun_sin", "haeil_big"): _s("icon:haeil", "damage", 1.0),
    ("yi_sun_sin", "haeil_fast"): _s("icon:haeil", "charge", 1.6, (0.62, 0.45), "cool"),
    ("yi_sun_sin", "counter_power"): _s("icon:counter", "damage", 1.0),
    ("yi_sun_sin", "counter_window"): _s("icon:counter", "window", 1.7, (0.5, 0.42), "warm"),
    ("yi_sun_sin", "dash_breath"): _s("bg", "cooldown", over=[("dash_spray", 1.15, 0.5, 0.46, 20, 1.0),
                                                                ("foam", 0.45, 0.72, 0.36, 0, 0.8)], gpt=True),
    ("yi_sun_sin", "vitality"): _s("hero", "hp", gpt=True),
    ("yi_sun_sin", "blade"): _s("bg", "damage", over=[("tidal_blade", 1.0, 0.5, 0.48, -15, 1.0)], gpt=True),
    ("yi_sun_sin", "swift"): _s("bg", "speed", tone="bright", over=[("wave_strip", 1.1, 0.5, 0.36, 0, 0.9),
                                                                    ("proj_water", 0.8, 0.45, 0.62, 0, 1.0)], gpt=True),
    ("yi_sun_sin", "major_whirl"): _s("icon:haeryong", "major", 1.25, (0.5, 0.5), "dark",
                                      over=[("wave", 0.95, 0.5, 0.5, 0, 0.95)]),
    ("yi_sun_sin", "major_burst"): _s("icon:pado", "major", 1.25, (0.5, 0.5), "dark",
                                      over=[("foam", 0.9, 0.58, 0.45, 0, 1.0)]),
    ("yi_sun_sin", "major_triple"): _s("icon:haeil", "major", 1.2, (0.5, 0.5), "dark",
                                       over=[("proj_water", 0.7, 0.5, 0.3, -90, 1.0),
                                             ("proj_water", 0.7, 0.25, 0.42, -130, 1.0),
                                             ("proj_water", 0.7, 0.75, 0.42, -50, 1.0)]),
    ("yi_sun_sin", "major_radial"): _s("icon:counter", "major", 1.2, (0.5, 0.5), "dark",
                                       over=[("proj_water", 0.42, 0.5, 0.5, a, 1.0) for a in range(0, 360, 45)]),

    # ── 광개토: 불·벼락, 주황색 ──
    ("gwanggaeto", "quake_wide"): _s("icon:quake", "range", 1.0),
    ("gwanggaeto", "quake_heavy"): _s("icon:quake", "damage", 1.8, (0.5, 0.35), "warm"),
    ("gwanggaeto", "quake_daze"): _s("icon:quake", "stun", 1.6, (0.5, 0.75), "bright"),
    ("gwanggaeto", "quake_finish"): _s("icon:quake", "finisher", 1.5, (0.3, 0.6), "warm"),
    ("gwanggaeto", "trail_power"): _s("icon:thunder_trail", "damage", 1.0),
    ("gwanggaeto", "trail_wide"): _s("icon:thunder_trail", "width", 1.6, (0.4, 0.5), "bright"),
    ("gwanggaeto", "bolt_more"): _s("icon:lightning", "count", 1.0),
    ("gwanggaeto", "bolt_power"): _s("icon:lightning", "damage", 1.7, (0.45, 0.35), "warm"),
    ("gwanggaeto", "bolt_fast"): _s("icon:lightning", "charge", 1.6, (0.65, 0.65), "cool"),
    ("gwanggaeto", "conq_power"): _s("icon:conqueror", "damage", 1.0),
    ("gwanggaeto", "conq_window"): _s("icon:conqueror", "window", 1.8, (0.5, 0.3), "warm"),
    ("gwanggaeto", "dash_breath"): _s("bg", "cooldown", over=[("dash_spark", 1.15, 0.5, 0.46, 20, 1.0),
                                                                ("lightning_strip", 0.8, 0.5, 0.7, 20, 0.7)], gpt=True),
    ("gwanggaeto", "vitality"): _s("hero", "hp", gpt=True),
    ("gwanggaeto", "blade"): _s("bg", "damage", over=[("proj_spear", 1.15, 0.5, 0.48, -40, 1.0),
                                                       ("explosion", 0.5, 0.7, 0.3, 0, 0.7)], gpt=True),
    ("gwanggaeto", "major_aftershock"): _s("icon:quake", "major", 1.2, (0.5, 0.55), "dark",
                                           over=[("quake", 0.95, 0.5, 0.55, 0, 0.75),
                                                 ("quake", 0.6, 0.5, 0.55, 40, 0.9)]),
    ("gwanggaeto", "major_field"): _s("icon:thunder_trail", "major", 1.2, (0.5, 0.5), "dark",
                                      over=[("lightning_strip", 1.1, 0.5, 0.55, 0, 1.0),
                                            ("lightning_strip", 1.0, 0.5, 0.7, 180, 0.8)]),
    ("gwanggaeto", "major_chain"): _s("icon:lightning", "major", 1.2, (0.5, 0.5), "dark",
                                      over=[("lightning", 0.6, 0.28, 0.45, -15, 1.0),
                                            ("lightning", 0.6, 0.72, 0.45, 15, 1.0),
                                            ("lightning_strip", 0.9, 0.5, 0.38, 0, 0.9)]),
    ("gwanggaeto", "major_reign"): _s("icon:conqueror", "major", 1.2, (0.5, 0.55), "dark",
                                      over=[("royal_shock", 0.95, 0.5, 0.6, 0, 1.0)]),

    # ── 세종: 글자·별, 붉은색·금색 ──
    ("sejong", "jeong_dmg"): _s("icon:jeongeum", "damage", 1.0),
    ("sejong", "jeong_wide"): _s("icon:jeongeum", "range", 1.5, (0.5, 0.6), "bright"),
    ("sejong", "jeong_long"): _s("icon:jeongeum", "duration", 1.7, (0.5, 0.35), "warm"),
    ("sejong", "jeong_quick"): _s("icon:jeongeum", "cooldown", 1.6, (0.3, 0.7), "cool"),
    ("sejong", "meteor_dmg"): _s("icon:meteor", "damage", 1.0),
    ("sejong", "meteor_wide"): _s("icon:meteor", "range", 1.6, (0.5, 0.72), "bright"),
    ("sejong", "star_more"): _s("icon:constellation", "count", 1.0),
    ("sejong", "star_dmg"): _s("icon:constellation", "damage", 1.6, (0.55, 0.4), "warm"),
    ("sejong", "star_fast"): _s("icon:constellation", "charge", 1.6, (0.4, 0.65), "cool"),
    ("sejong", "sundial_long"): _s("icon:sundial", "slow", 1.0),
    ("sejong", "sundial_dmg"): _s("icon:sundial", "damage", 1.7, (0.5, 0.4), "warm"),
    ("sejong", "vitality"): _s("hero", "hp", gpt=True),
    ("sejong", "letters"): _s("bg", "damage", over=[("glyphs", 1.0, 0.5, 0.5, 0, 1.0),
                                                     ("dash_spark", 0.8, 0.5, 0.5, -30, 0.9)], gpt=True),
    ("sejong", "swift"): _s("bg", "speed", tone="bright", over=[("dash_glyph", 1.0, 0.5, 0.5, 0, 1.0)], gpt=True),
    ("sejong", "major_double"): _s("icon:jeongeum", "major", 1.2, (0.5, 0.5), "dark",
                                   over=[("glyphs", 1.0, 0.5, 0.5, 0, 0.9), ("glyphs", 0.6, 0.5, 0.5, 180, 0.9)]),
    ("sejong", "major_shower"): _s("icon:meteor", "major", 1.2, (0.5, 0.5), "dark",
                                   over=[("meteor", 0.42, x, y, 0, 1.0) for x, y in
                                         ((0.25, 0.3), (0.75, 0.25), (0.3, 0.72), (0.72, 0.68))]),
    ("sejong", "major_big_dipper"): _s("icon:constellation", "major", 1.2, (0.5, 0.5), "dark",
                                       over=[("constellation", 0.9, 0.5, 0.5, 0, 1.0),
                                             ("explosion", 0.35, 0.3, 0.35, 0, 0.9),
                                             ("explosion", 0.35, 0.7, 0.62, 0, 0.9)]),
    ("sejong", "major_stopped"): _s("icon:sundial", "major", 1.2, (0.5, 0.5), "gray",
                                    over=[("sundial", 0.8, 0.5, 0.5, 0, 0.9)]),

    # ── 신사임당: 먹·붓, 묵색·분홍 ──
    ("shin_saimdang", "critter_more"): _s("icon:critters", "count", 1.0),
    ("shin_saimdang", "critter_dmg"): _s("icon:critters", "damage", 1.8, (0.66, 0.4), "warm"),
    ("shin_saimdang", "critter_long"): _s("icon:critters", "duration", 1.6, (0.35, 0.7), "cool"),
    ("shin_saimdang", "critter_quick"): _s("icon:critters", "cooldown", 1.7, (0.4, 0.3), "bright"),
    ("shin_saimdang", "ink_long"): _s("icon:ink_bleed", "duration", 1.0),
    ("shin_saimdang", "ink_heavy"): _s("icon:ink_bleed", "slow", 1.6, (0.4, 0.6), "gray"),
    ("shin_saimdang", "ink_dmg"): _s("icon:ink_bleed", "damage", 1.6, (0.65, 0.35), "warm"),
    ("shin_saimdang", "canvas_wide"): _s("icon:canvas", "range", 1.0),
    ("shin_saimdang", "canvas_hold"): _s("icon:canvas", "duration", 1.7, (0.35, 0.5), "cool"),
    ("shin_saimdang", "canvas_dmg"): _s("icon:canvas", "damage", 1.6, (0.68, 0.5), "warm"),
    ("shin_saimdang", "plum_heal"): _s("icon:plum", "heal", 1.0),
    ("shin_saimdang", "plum_dmg"): _s("icon:plum", "damage", 1.7, (0.6, 0.35), "warm"),
    ("shin_saimdang", "vitality"): _s("hero", "hp", gpt=True),
    ("shin_saimdang", "brush"): _s("bg", "damage", tone="bright",
                                   over=[("brush_stroke", 1.1, 0.5, 0.5, -30, 0.9), ("proj_ink", 0.9, 0.5, 0.5, -30, 1.0)],
                                   gpt=True),
    ("shin_saimdang", "major_butterflies"): _s("icon:critters", "major", 1.2, (0.5, 0.5), "dark",
                                               over=[("critter_swarm", 0.95, 0.5, 0.5, 0, 1.0)]),
    ("shin_saimdang", "major_cloud"): _s("icon:ink_bleed", "major", 1.2, (0.5, 0.5), "dark",
                                         over=[("ink", 0.8, 0.5, 0.5, 0, 0.9), ("explosion", 0.5, 0.5, 0.5, 0, 0.8)]),
    ("shin_saimdang", "major_screen"): _s("icon:canvas", "major", 1.2, (0.5, 0.5), "dark",
                                          over=[("scroll_unfold", 0.85, 0.5, 0.5, 0, 1.0)]),
    ("shin_saimdang", "major_petals"): _s("icon:plum", "major", 1.2, (0.5, 0.5), "dark",
                                          over=[("plum", 0.95, 0.5, 0.5, 0, 1.0)]),
}
