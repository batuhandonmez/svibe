param(
    [int[]]$Ports = @(8000, 8096)
)

$ErrorActionPreference = "Stop"

foreach ($port in $Ports) {
    $processIds = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique

    if (-not $processIds) {
        Write-Output "No process is listening on port $port."
        continue
    }

    foreach ($processId in $processIds) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $processId -Force
            Write-Output "Stopped $($process.ProcessName) process $processId on port $port."
        }
    }
}
