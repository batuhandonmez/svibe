param(
    [string]$Username = "demo_user",
    [string]$LanIp = "",
    [int]$BackendPort = 8000,
    [int]$WebPort = 8096,
    [switch]$Restart
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$backendDir = Join-Path $root "backend"
$mobileDir = Join-Path $root "mobile"
$python = Join-Path $backendDir "venv\Scripts\python.exe"

function Get-FirstLanIp {
    $addresses = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.PrefixOrigin -ne "WellKnown"
        } |
        Sort-Object InterfaceMetric, InterfaceAlias

    if (-not $addresses) {
        throw "Could not find a LAN IPv4 address. Pass -LanIp manually."
    }

    return $addresses[0].IPAddress
}

function Get-PortPid([int]$Port) {
    $connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($connection) {
        return $connection.OwningProcess
    }
    return $null
}

function Wait-ForHealth([string]$Url) {
    for ($i = 0; $i -lt 20; $i++) {
        try {
            $health = Invoke-RestMethod -Uri $Url -TimeoutSec 2
            if ($health.status -eq "ok") {
                return
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    throw "Backend did not become healthy at $Url"
}

function Wait-ForWeb([string]$Url) {
    for ($i = 0; $i -lt 90; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                return
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    throw "Flutter web did not become reachable at $Url"
}

if (-not (Test-Path $python)) {
    throw "Backend virtualenv Python not found at $python"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter command was not found on PATH."
}

if (-not $LanIp) {
    $LanIp = Get-FirstLanIp
}

$apiBaseUrl = "http://${LanIp}:${BackendPort}"
$webUrl = "http://${LanIp}:${WebPort}"

if ($Restart) {
    foreach ($port in @($BackendPort, $WebPort)) {
        $processId = Get-PortPid $port
        if ($processId) {
            Stop-Process -Id $processId -Force
            Start-Sleep -Milliseconds 500
        }
    }
}

$backendPid = Get-PortPid $BackendPort
if (-not $backendPid) {
    Start-Process `
        -FilePath $python `
        -ArgumentList @("-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "$BackendPort") `
        -WorkingDirectory $backendDir `
        -RedirectStandardOutput (Join-Path $backendDir "uvicorn.out.log") `
        -RedirectStandardError (Join-Path $backendDir "uvicorn.err.log") `
        -WindowStyle Hidden
} else {
    Write-Output "Reusing backend process $backendPid on port $BackendPort"
}

Wait-ForHealth "http://127.0.0.1:${BackendPort}/health"

& $python (Join-Path $root "scripts\seed_local_demo.py") --username $Username --base-url $apiBaseUrl
if ($LASTEXITCODE -ne 0) {
    throw "Local demo seeding failed."
}

$webPid = Get-PortPid $WebPort
if (-not $webPid) {
    $flutter = (Get-Command flutter).Source
    Start-Process `
        -FilePath $flutter `
        -ArgumentList @(
            "run",
            "-d", "web-server",
            "--web-hostname", "0.0.0.0",
            "--web-port", "$WebPort",
            "--dart-define", "API_BASE_URL=$apiBaseUrl"
        ) `
        -WorkingDirectory $mobileDir `
        -RedirectStandardOutput (Join-Path $mobileDir "flutter_web.out.log") `
        -RedirectStandardError (Join-Path $mobileDir "flutter_web.err.log") `
        -WindowStyle Hidden
} else {
    Write-Output "Reusing Flutter web process $webPid on port $WebPort"
}

Wait-ForWeb "http://127.0.0.1:${WebPort}/"

Write-Output ""
Write-Output "Svibe local web demo is ready."
Write-Output "API:  $apiBaseUrl"
Write-Output "Web:  $webUrl"
Write-Output "Demo: $Username / demo12345"
Write-Output ""
Write-Output "If the browser says it cannot reach the API, rerun with -Restart."
