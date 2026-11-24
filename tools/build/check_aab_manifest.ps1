# AAB 매니페스트 점검: Play 사전 점검에서 걸린 것을 올리기 전에 잡는다.
#  - 권한은 VIBRATE 만 (INTERNET 등이 붙으면 실패)
#  - android.hardware.screen.portrait 는 선택사항 (세로 고정이 넣는 필수 기능 선언 때문에 기기가 걸러지지 않게)
#  - 필수 하드웨어 기능 목록을 찍는다 (GLES 3.0 은 엔진에 필요해서 필수로 둔다)
# AAB 의 매니페스트는 proto 형식이라 aapt2 가 읽을 수 있게 임시 zip 으로 옮겨 dump badging 한다.
#   powershell -ExecutionPolicy Bypass -File tools/build/check_aab_manifest.ps1 [-Aab build/android/haneol-heroes.aab]
param([string]$Aab = "build/android/haneol-heroes.aab")
$ErrorActionPreference = "Stop"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$aapt2 = (Get-ChildItem (Join-Path $sdk "build-tools\*\aapt2.exe") | Sort-Object FullName | Select-Object -Last 1).FullName
if (-not $aapt2) { throw "aapt2 를 찾지 못했습니다 ($sdk\build-tools)" }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$probe = Join-Path ([System.IO.Path]::GetTempPath()) ("aab_manifest_{0}.zip" -f [guid]::NewGuid().ToString("N"))
$src = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $Aab).Path)
$dst = [System.IO.Compression.ZipFile]::Open($probe, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($e in $src.Entries) {
        $name = $null
        if ($e.FullName -eq "base/manifest/AndroidManifest.xml") { $name = "AndroidManifest.xml" }
        elseif ($e.FullName -eq "base/resources.pb" -or $e.FullName.StartsWith("base/res/")) { $name = $e.FullName.Substring(5) }
        if ($name) {
            $out = $dst.CreateEntry($name).Open(); $in = $e.Open()
            try { $in.CopyTo($out) } finally { $in.Dispose(); $out.Dispose() }
        }
    }
} finally { $dst.Dispose(); $src.Dispose() }
try { $badging = & $aapt2 dump badging $probe 2>&1 | ForEach-Object { "$_" } }
finally { Remove-Item $probe -ErrorAction SilentlyContinue }
$fail = @()
$perms = @($badging | Select-String "^uses-permission: name='([^']+)'" | ForEach-Object { $_.Matches[0].Groups[1].Value })
"권한: " + ($perms -join ", ")
if (($perms | Where-Object { $_ -ne "android.permission.VIBRATE" }).Count -gt 0 -or $perms -notcontains "android.permission.VIBRATE") {
    $fail += "권한이 VIBRATE 하나가 아닙니다"
}
$required = @($badging | Select-String "^\s*uses-feature: name='([^']+)'" | ForEach-Object { $_.Matches[0].Groups[1].Value })
$optional = @($badging | Select-String "^\s*uses-feature-not-required: name='([^']+)'" | ForEach-Object { $_.Matches[0].Groups[1].Value })
$gl = @($badging | Select-String "^\s*uses-gl-es: '([^']+)'" | ForEach-Object { $_.Matches[0].Groups[1].Value })
"필수 기능: " + (($required + ($gl | ForEach-Object { "GLES $_" })) -join ", ")
"선택 기능: " + ($optional -join ", ")
if ($required -contains "android.hardware.screen.portrait" -or $optional -notcontains "android.hardware.screen.portrait") {
    $fail += "android.hardware.screen.portrait 가 선택사항이 아닙니다"
}
($badging | Select-String "^package:").Line
if ($fail.Count -gt 0) { throw ("매니페스트 점검 실패: " + ($fail -join "; ")) }
"매니페스트 점검 통과"
