# 크기 최적화 Android 릴리스 내보내기 템플릿 빌드 (Godot 4.7.2, 프로필: tools/build/engine/haneol_android.py)
# 결과물은 깃에서 제외된 build/templates/ 에만 둔다 (공개 저장소: 바이너리를 커밋하지 않는다).
#   android_release.apk               : 내보내기 설정 "Android" (APK)의 custom_template/release
#   godot-lib.template_release.aar    : 내보내기 설정 "Android Play (AAB)" (gradle)용, export_aab.ps1이 android/build/libs/release/에 넣는다
# 준비 (README "커스텀 내보내기 템플릿"):
#   HANEOL_GODOT_SRC  : Godot 4.7.2-stable 소스 (기본 %LOCALAPPDATA%\haneol-build\godot-4.7.2)
#   ANDROID_HOME      : Android SDK (기본 %LOCALAPPDATA%\Android\Sdk), NDK 29.0.14206865 설치
#   JAVA_HOME         : JDK 17,  SCons: python -m pip install --user scons
#   powershell -ExecutionPolicy Bypass -File tools/build/build_templates.ps1 [-Jobs 6] [-Arches arm64,arm32] [-SkipNative]
#   -SkipNative : scons를 건너뛰고 이미 만든 libs/ 로 gradle 포장만 다시 한다
param([string[]]$Arches = @("arm64", "arm32"), [int]$Jobs = 6, [switch]$SkipNative)
$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"  # 프로필의 한글 주석을 cp949로 읽지 않게
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$sconsProfile = Join-Path $PSScriptRoot "engine\haneol_android.py"
$src = if ($env:HANEOL_GODOT_SRC) { $env:HANEOL_GODOT_SRC } else { Join-Path $env:LOCALAPPDATA "haneol-build\godot-4.7.2" }
if (-not (Test-Path (Join-Path $src "SConstruct"))) { throw "Godot 소스가 없습니다: $src (HANEOL_GODOT_SRC로 지정)" }
if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = Join-Path $env:LOCALAPPDATA "Programs\Temurin\jdk-17.0.21+9" }
$out = Join-Path $repo "build\templates"
New-Item -ItemType Directory -Force $out | Out-Null
# Godot 편집기가 build/ 안을 리소스로 훑지 않게 한다
New-Item -ItemType File -Force (Join-Path $repo "build\.gdignore") | Out-Null

$libs = Join-Path $src "platform\android\java\lib\libs"
# 예전 빌드의 라이브러리가 섞이지 않게 비운다 (gradle은 libs/ 에 있는 ABI를 모두 템플릿에 넣는다)
if (-not $SkipNative -and (Test-Path $libs)) { Remove-Item -Recurse -Force $libs }
Push-Location $src
try {
    foreach ($arch in $(if ($SkipNative) { @() } else { $Arches })) {
        & python -m SCons platform=android target=template_release arch=$arch "profile=$sconsProfile" swappy=no lto=full -j $Jobs
        if ($LASTEXITCODE -ne 0) { throw "scons 실패 ($arch, exit $LASTEXITCODE)" }
    }
    $java = Join-Path $src "platform\android\java"
    # gradle 설정 단계가 PATH에서 scons 실행 파일을 찾는다 (pip --user 설치 위치를 더해 준다)
    $env:PATH = (& python -c "import sysconfig; print(sysconfig.get_path('scripts', 'nt_user'))") + ";" + $env:PATH
    # build.gradle이 lib/libs/ 를 작업 폴더 기준으로 찾으므로 작업 폴더를 명시해서 실행한다.
    # --no-daemon: Start-Process -Wait가 자식인 gradle 데몬까지 기다려 끝나지 않았다 (2026-11-23)
    $g = Start-Process -FilePath (Join-Path $java "gradlew.bat") -ArgumentList "generateGodotTemplates", "--quiet", "--no-daemon" `
        -WorkingDirectory $java -NoNewWindow -Wait -PassThru
    if ($g.ExitCode -ne 0) { throw "gradle 템플릿 생성 실패 (exit $($g.ExitCode))" }
} finally { Pop-Location }

foreach ($f in @("android_release.apk", "godot-lib.template_release.aar")) {
    $p = Join-Path $src "bin\$f"
    if (-not (Test-Path $p)) { throw "산출물이 없습니다: $p" }
    Copy-Item -Force $p (Join-Path $out $f)
}
$hash = (Get-FileHash (Join-Path $src "platform\android\java\lib\libs\release\arm64-v8a\libgodot_android.so")).Hash
"godot 4.7.2-stable, profile haneol_android.py, arches: $($Arches -join ','), arm64 so sha256 $hash" | Set-Content -Encoding utf8 (Join-Path $out "BUILD_INFO.txt")
Get-ChildItem $out | Format-Table Name, Length
