# 한얼: 영웅들 — 크기 최적화 Android 릴리스 내보내기 템플릿용 SCons 프로필 (Godot 4.7.2)
# 사용: scons platform=android target=template_release arch=arm64 profile=<이 파일>
# 근거: 공식 문서 "Optimizing a build for size" + 프로젝트 기능 감사 (README "커스텀 내보내기 템플릿").
# 게임이 새 엔진 기능을 쓰게 되면 (3D, 정규식, ogg 음악, 네트워크 등) 여기서 해당 모듈을 다시 켠다.

# 크기 최적화
production = "yes"
optimize = "size"
# lto=full 도 명령줄로 넘긴다 (production=yes가 프로필 값을 "auto"로 덮어쓴다)
debug_symbols = "no"

# GL Compatibility 렌더러만 쓴다 (project.godot rendering_method[.mobile] = gl_compatibility)
vulkan = "no"
# swappy=no 는 build_templates.ps1이 명령줄로 넘긴다 (production=yes가 명령줄 값만 받는다). Swappy는 Vulkan 드라이버에서만 쓰인다.

# 2D 게임: 3D·내비게이션·XR 제외 (3D는 tools/bake 데스크톱 굽기 도구에서만 쓴다)
disable_3d = "yes"
disable_navigation_2d = "yes"

# 한글은 조합이 끝난 음절(U+AC00–D7A3)만 쓰므로 복잡한 셰이핑(HarfBuzz/ICU)이 필요 없다.
# 기본 글꼴에 없는 글자는 fallback 서버도 OS 글꼴로 대체한다 (allow_system_fallback).
module_text_server_adv_enabled = "no"
module_text_server_fb_enabled = "yes"

# 쓰지 않는 모듈 (공식 문서의 2D 게임 예시 목록에서 noise·svg는 남긴다)
module_astcenc_enabled = "no"
module_basis_universal_enabled = "no"
module_bcdec_enabled = "no"
module_betsy_enabled = "no"
module_bmp_enabled = "no"
module_camera_enabled = "no"
module_csg_enabled = "no"
module_cvtt_enabled = "no"
module_dds_enabled = "no"
module_enet_enabled = "no"
module_etcpak_enabled = "no"
module_fbx_enabled = "no"
module_glslang_enabled = "no"
module_godot_physics_3d_enabled = "no"
module_gltf_enabled = "no"
module_gridmap_enabled = "no"
module_hdr_enabled = "no"
module_interactive_music_enabled = "no"
module_jolt_physics_enabled = "no"
module_jpg_enabled = "no"
module_jsonrpc_enabled = "no"
module_ktx_enabled = "no"
module_lightmapper_rd_enabled = "no"
module_mbedtls_enabled = "no"
module_meshoptimizer_enabled = "no"
module_mobile_vr_enabled = "no"
module_mp3_enabled = "no"
module_msdfgen_enabled = "no"
module_multiplayer_enabled = "no"
module_navigation_2d_enabled = "no"
module_navigation_3d_enabled = "no"
module_objectdb_profiler_enabled = "no"
module_ogg_enabled = "no"
module_openxr_enabled = "no"
module_raycast_enabled = "no"
module_regex_enabled = "no"
module_tga_enabled = "no"
module_theora_enabled = "no"
module_tinyexr_enabled = "no"
module_upnp_enabled = "no"
module_vhacd_enabled = "no"
module_visual_shader_enabled = "no"
module_vorbis_enabled = "no"
module_webrtc_enabled = "no"
module_websocket_enabled = "no"
module_webxr_enabled = "no"
module_xatlas_unwrap_enabled = "no"
module_zip_enabled = "no"

# 남기는 모듈: gdscript, godot_physics_2d, freetype(글꼴), noise(arena.gd NoiseTexture2D),
# webp(무손실 텍스처 .ctex 기본 형식), svg(fallback 텍스트 서버의 선택 의존성, 작다).
