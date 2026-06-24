$script:VBookDefineKeys = @(
  "GOOGLE_DRIVE_API_KEY",
  "GOOGLE_DRIVE_FOLDER_URL",
  "GOOGLE_DRIVE_FOLDER_URLS",
  "FIREBASE_API_KEY",
  "FIREBASE_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_PROJECT_ID",
  "FIREBASE_AUTH_DOMAIN",
  "FIREBASE_STORAGE_BUCKET",
  "FIREBASE_MEASUREMENT_ID",
  "FIREBASE_IOS_BUNDLE_ID",
  "VBOOK_ADMIN_EMAILS"
)

function Resolve-VBookPath {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $Path
  }

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }

  $fromCwd = Join-Path (Get-Location) $Path
  if (Test-Path -LiteralPath $fromCwd) {
    return $fromCwd
  }

  $projectRoot = Split-Path -Parent $PSScriptRoot
  return Join-Path $projectRoot $Path
}

function Read-VBookEnvFile {
  param([string]$Path = "release.env")

  $resolvedPath = Resolve-VBookPath -Path $Path
  $values = @{}
  if (-not (Test-Path -LiteralPath $resolvedPath)) {
    return $values
  }

  foreach ($line in Get-Content -LiteralPath $resolvedPath) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
      continue
    }

    $parts = $trimmed -split "=", 2
    if ($parts.Count -ne 2) {
      continue
    }

    $key = $parts[0].Trim()
    $value = $parts[1].Trim().Trim('"').Trim("'")
    if ($key.Length -gt 0 -and $value.Length -gt 0) {
      $values[$key] = $value
    }
  }

  return $values
}

function Set-VBookValueIfMissing {
  param(
    [hashtable]$Values,
    [string]$Key,
    [object]$Value
  )

  if ($null -eq $Value) {
    return
  }

  $text = $Value.ToString().Trim()
  if ($text.Length -eq 0) {
    return
  }

  if (-not $Values.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace($Values[$Key])) {
    $Values[$Key] = $text
  }
}

function Import-VBookEnvironmentValues {
  param(
    [hashtable]$Values,
    [string[]]$Keys = $script:VBookDefineKeys
  )

  foreach ($key in $Keys) {
    Set-VBookValueIfMissing -Values $Values -Key $key -Value ([Environment]::GetEnvironmentVariable($key))
  }
}

function Import-VBookGoogleServicesConfig {
  param(
    [hashtable]$Values,
    [string]$Path = "android/app/google-services.json"
  )

  $resolvedPath = Resolve-VBookPath -Path $Path
  if (-not (Test-Path -LiteralPath $resolvedPath)) {
    return
  }

  try {
    $json = Get-Content -LiteralPath $resolvedPath -Raw | ConvertFrom-Json
    $projectInfo = $json.project_info
    $client = @($json.client)[0]
    $apiKey = @($client.api_key)[0].current_key
    $appId = $client.client_info.mobilesdk_app_id
    $projectId = $projectInfo.project_id

    Set-VBookValueIfMissing -Values $Values -Key "FIREBASE_API_KEY" -Value $apiKey
    Set-VBookValueIfMissing -Values $Values -Key "FIREBASE_APP_ID" -Value $appId
    Set-VBookValueIfMissing -Values $Values -Key "FIREBASE_MESSAGING_SENDER_ID" -Value $projectInfo.project_number
    Set-VBookValueIfMissing -Values $Values -Key "FIREBASE_PROJECT_ID" -Value $projectId
    Set-VBookValueIfMissing -Values $Values -Key "FIREBASE_STORAGE_BUCKET" -Value $projectInfo.storage_bucket
    if (-not [string]::IsNullOrWhiteSpace($projectId)) {
      Set-VBookValueIfMissing -Values $Values -Key "FIREBASE_AUTH_DOMAIN" -Value "$projectId.firebaseapp.com"
    }

    Set-VBookValueIfMissing -Values $Values -Key "GOOGLE_DRIVE_API_KEY" -Value $apiKey
  } catch {
    Write-Warning "Khong doc duoc android/app/google-services.json: $($_.Exception.Message)"
  }
}

function Resolve-VBookConfigValues {
  param(
    [string]$ConfigPath = "release.env",
    [string]$GoogleServicesPath = "android/app/google-services.json"
  )

  $values = Read-VBookEnvFile -Path $ConfigPath
  Import-VBookEnvironmentValues -Values $values
  Import-VBookGoogleServicesConfig -Values $values -Path $GoogleServicesPath

  if (
    (-not $values.ContainsKey("GOOGLE_DRIVE_API_KEY") -or [string]::IsNullOrWhiteSpace($values["GOOGLE_DRIVE_API_KEY"])) -and
    $values.ContainsKey("FIREBASE_API_KEY")
  ) {
    Set-VBookValueIfMissing -Values $values -Key "GOOGLE_DRIVE_API_KEY" -Value $values["FIREBASE_API_KEY"]
  }

  return $values
}

function Require-VBookKey {
  param(
    [hashtable]$Values,
    [string]$Key
  )

  if (-not $Values.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace($Values[$Key])) {
    throw "Thieu $Key. Hay dien release.env, dat bien moi truong, hoac kiem tra android/app/google-services.json."
  }
}

function Add-VBookDartDefineArgs {
  param(
    [ref]$TargetArgs,
    [hashtable]$Values,
    [string[]]$Keys = $script:VBookDefineKeys
  )

  foreach ($key in $Keys) {
    if ($Values.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($Values[$key])) {
      $TargetArgs.Value += "--dart-define=$key=$($Values[$key])"
    }
  }
}

function Write-VBookDartDefinesFile {
  param(
    [hashtable]$Values,
    [string]$OutputPath = ".vscode/dart_defines.json",
    [string[]]$Keys = $script:VBookDefineKeys
  )

  $resolvedOutputPath = Resolve-VBookPath -Path $OutputPath
  $directory = Split-Path -Parent $resolvedOutputPath
  if (-not [string]::IsNullOrWhiteSpace($directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $defines = [ordered]@{}
  foreach ($key in $Keys) {
    if ($Values.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($Values[$key])) {
      $defines[$key] = $Values[$key].ToString()
    }
  }

  $json = $defines | ConvertTo-Json -Depth 4
  Set-Content -LiteralPath $resolvedOutputPath -Value $json -Encoding UTF8
  return $resolvedOutputPath
}
