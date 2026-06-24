param(
  [string]$ConfigPath = "release.env",
  [string]$OutputPath = ".vscode/dart_defines.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\vbook_config.ps1"

$values = Resolve-VBookConfigValues -ConfigPath $ConfigPath
Require-VBookKey -Values $values -Key "GOOGLE_DRIVE_API_KEY"
$writtenPath = Write-VBookDartDefinesFile -Values $values -OutputPath $OutputPath
Write-Host "Da ghi dart defines vao $writtenPath" -ForegroundColor Green
