# 플레이스토어용 릴리스 AAB 빌드 (내보내기 설정 "Android Play (AAB)", gradle 빌드).
# 업로드 서명 키는 저장소 밖 %USERPROFILE%\.haneol-keys\ 에만 둔다 (upload.jks + upload-key.txt).
# 키 정보는 환경 변수로만 Godot에 넘긴다 (export_presets.cfg·로그에 남기지 않는다).
# 처음 한 번: android/build 템플릿을 export_templates\<버전>\android_source.zip에서 풀어 둔다 (README 참고).
#   powershell -ExecutionPolicy Bypass -File tools/build/export_aab.ps1
param([string]$Out = "build/android/haneol-heroes.aab")
$ErrorActionPreference = "Stop"
$keyFile = Join-Path $env:USERPROFILE ".haneol-keys\upload-key.txt"
if (-not (Test-Path $keyFile)) { throw "업로드 키 정보가 없습니다: $keyFile" }
$k = @{}
foreach ($line in Get-Content $keyFile) {
    $i = $line.IndexOf("=")
    if ($i -gt 0) { $k[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim() }
}
try {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $k["path"]
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $k["alias"]
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $k["password"]
    if (-not $env:JAVA_HOME) { $env:JAVA_HOME = Join-Path $env:LOCALAPPDATA "Programs\Temurin\jdk-17.0.21+9" }
    $godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else {
        (Get-ChildItem (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\*Godot*\Godot_v4*_console.exe") | Select-Object -Last 1).FullName
    }
    if (-not $godot) { throw "Godot 콘솔 실행 파일을 찾지 못했습니다 (GODOT_BIN으로 지정)" }
    New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
    & $godot --headless --path . --export-release "Android Play (AAB)" $Out
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Out)) { throw "AAB 빌드 실패 (exit $LASTEXITCODE)" }
}
finally {
    # 실패해도 서명 정보가 이 PowerShell 세션에 남지 않게 지운다 (Codex 지적)
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -ErrorAction SilentlyContinue
}
"{0} ({1:N2} MiB)" -f $Out, ((Get-Item $Out).Length / 1MB)
