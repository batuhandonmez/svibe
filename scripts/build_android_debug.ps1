param(
    [string]$JunctionPath = "C:\svibe_ascii",
    [string]$LanIp = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$mobilePath = Join-Path $repoRoot "mobile"

if (-not $LanIp) {
    $LanIp = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.PrefixOrigin -ne "WellKnown"
        } |
        Sort-Object InterfaceMetric, InterfaceAlias |
        Select-Object -First 1 -ExpandProperty IPAddress
}
if (-not $LanIp) {
    throw "Could not find a LAN IPv4 address. Pass -LanIp manually."
}
$apiBaseUrl = "http://${LanIp}:8000"

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
    flutter build apk --debug --dart-define "API_BASE_URL=$apiBaseUrl"
} finally {
    Pop-Location
}

Write-Output "APK: $junctionMobile\build\app\outputs\flutter-apk\app-debug.apk"
Write-Output "API: $apiBaseUrl"
