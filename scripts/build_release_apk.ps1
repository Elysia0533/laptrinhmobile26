param(
  [string]$ConfigPath = "release.env",
  [switch]$SkipChecks,
  [switch]$RequireFirebase
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\vbook_config.ps1"

$values = Resolve-VBookConfigValues -ConfigPath $ConfigPath
Require-VBookKey -Values $values -Key "GOOGLE_DRIVE_API_KEY"

$firebaseKeys = @(
  "FIREBASE_API_KEY",
  "FIREBASE_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_PROJECT_ID"
)

$missingFirebase = @()
foreach ($key in $firebaseKeys) {
  if (-not $values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($values[$key])) {
    $missingFirebase += $key
  }
}

if ($RequireFirebase -and $missingFirebase.Count -gt 0) {
  throw "Thieu cau hinh Firebase: $($missingFirebase -join ', ')"
}

if ($missingFirebase.Count -gt 0) {
  Write-Host "Canh bao: chua du Firebase config, APK se doc Drive/offline nhung dang nhap-chat-dong bo se tam tat." -ForegroundColor Yellow
}

$buildArgs = @("build", "apk", "--release", "--split-per-abi")
Add-VBookDartDefineArgs -TargetArgs ([ref]$buildArgs) -Values $values

flutter clean
flutter pub get

if (-not $SkipChecks) {
  flutter analyze
  flutter test
}

flutter @buildArgs

$apkDir = Join-Path (Get-Location) "build\app\outputs\flutter-apk"
$apkFiles = Get-ChildItem -Path $apkDir -Filter "*-release.apk" -ErrorAction SilentlyContinue
if ($apkFiles.Count -eq 0) {
  throw "Build xong nhung khong tim thay APK tai $apkDir"
}

foreach ($apk in $apkFiles) {
  Write-Host "APK da san sang: $($apk.FullName)" -ForegroundColor Green
  Write-Host "Dung luong: $([Math]::Round($apk.Length / 1MB, 1)) MB" -ForegroundColor Green
}
