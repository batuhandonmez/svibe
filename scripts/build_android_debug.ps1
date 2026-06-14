param(
    [string]$JunctionPath = "C:\svibe_ascii"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$mobilePath = Join-Path $repoRoot "mobile"

if (-not (Test-Path $mobilePath)) {
    throw "Mobile project not found at $mobilePath"
}

if (-not (Test-Path $JunctionPath)) {
    New-Item -ItemType Junction -Path $JunctionPath -Target $repoRoot | Out-Null
}

$junctionMobile = Join-Path $JunctionPath "mobile"
if (-not (Test-Path $junctionMobile)) {
    throw "Junction mobile path not found at $junctionMobile"
}

Push-Location $junctionMobile
try {
    flutter build apk --debug
} finally {
    Pop-Location
}
