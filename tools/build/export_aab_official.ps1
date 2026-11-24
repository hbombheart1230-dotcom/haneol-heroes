# 플레이스토어 AAB: 공식 Godot 4.7.2 템플릿 (내보내기 설정 "Android Play (AAB)", gradle).
# export_aab.ps1 은 직접 만든 엔진(build/templates/)용으로 그대로 둔다. 지금 시험판·Play 빌드는 공식 엔진을 쓴다.
# 업로드 서명 키는 저장소 밖 %USERPROFILE%\.haneol-keys\ 에만 둔다 (upload.jks + upload-key.txt).
# 키 정보는 환경 변수로만 Godot에 넘기고 끝나면 지운다 (export_presets.cfg·로그에 남기지 않는다).
# 처음 한 번: android/build 를 android_source.zip 에서 풀어 둔다 (README "플레이스토어 빌드").
#   powershell -ExecutionPolicy Bypass -File tools/build/export_aab_official.ps1
# versionCode 는 Console 에 올리기 직전에만 +1 (versionName 0.4.x 함께). 시험 APK 는 건드리지 않는다.
param([string]$Out = "build/android/haneol-heroes.aab")
$ErrorActionPreference = "Stop"
$started = Get-Date
try {
    $keyFile = Join-Path $env:USERPROFILE ".haneol-keys\upload-key.txt"
    if (-not (Test-Path $keyFile)) { throw "업로드 키 정보가 없습니다: $keyFile" }
    $k = @{}
    foreach ($line in Get-Content $keyFile) {
        $i = $line.IndexOf("=")
        if ($i -gt 0) { $k[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim() }
    }
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $k["path"]
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $k["alias"]
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $k["password"]
    if (-not $env:JAVA_HOME) { $env:JAVA_HOME = Join-Path $env:LOCALAPPDATA "Programs\Temurin\jdk-17.0.21+9" }
    $godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else {
        (Get-ChildItem (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\*Godot*\Godot_v4*_console.exe") | Select-Object -Last 1).FullName
    }
    if (-not $godot) { throw "Godot 콘솔 실행 파일을 찾지 못했습니다 (GODOT_BIN으로 지정)" }
    # gradle 은 android/build/libs/release/ 의 엔진을 쓴다: 직접 만든 엔진이 덮어썼을 수 있으니 공식 것으로 되돌린다
    $libDst = "android/build/libs/release/godot-lib.template_release.aar"
    if (-not (Test-Path (Split-Path $libDst))) { throw "android/build가 없습니다 (README의 gradle 템플릿 설치 참고)" }
    $zipPath = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable\android_source.zip"
    if (-not (Test-Path $zipPath)) { throw "공식 템플릿이 없습니다: $zipPath" }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entry = $zip.GetEntry("libs/release/godot-lib.template_release.aar")
        if (-not $entry) { throw "android_source.zip 에 release aar 가 없습니다" }
        if (-not (Test-Path $libDst) -or (Get-Item $libDst).Length -ne $entry.Length) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Resolve-Path (Split-Path $libDst)).Path + "\" + (Split-Path $libDst -Leaf), $true)
        }
    } finally { $zip.Dispose() }
    New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
    & $godot --headless --path . --export-release "Android Play (AAB)" $Out
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Out)) { throw "AAB 빌드 실패 (exit $LASTEXITCODE)" }
}
finally {
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -ErrorAction SilentlyContinue
}
"{0} ({1:N2} MiB, {2:N0}s)" -f $Out, ((Get-Item $Out).Length / 1MB), ((Get-Date) - $started).TotalSeconds
