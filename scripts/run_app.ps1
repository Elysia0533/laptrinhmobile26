param(
  [string]$ConfigPath = "release.env",
  [string]$Device,
  [switch]$Release,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\vbook_config.ps1"

$values = Resolve-VBookConfigValues -ConfigPath $ConfigPath
Require-VBookKey -Values $values -Key "GOOGLE_DRIVE_API_KEY"

$runArgs = @("run")
if ($Release) {
  $runArgs += "--release"
}
if (-not [string]::IsNullOrWhiteSpace($Device)) {
  $runArgs += @("-d", $Device)
}

Add-VBookDartDefineArgs -TargetArgs ([ref]$runArgs) -Values $values
if ($FlutterArgs) {
  $runArgs += $FlutterArgs
}

flutter @runArgs
