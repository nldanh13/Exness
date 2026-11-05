# DongBo.ps1 - Dong bo code bot tu thu muc nay sang MT5 va compile
#   Chay 1 lan:        powershell -ExecutionPolicy Bypass -File .\DongBo.ps1
#   Tu dong khi luu:   powershell -ExecutionPolicy Bypass -File .\DongBo.ps1 -Watch
# Bot dang chay tren bieu do MT5 se tu nap lai ban moi sau khi compile.

param([switch]$Watch)
$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ProjectDir "MT5Common.ps1")

function Deploy([string]$file, $mt5) {
    $stamp = Get-Date -Format "HH:mm:ss"
    $r = Invoke-BotCompile $mt5 $file
    if ($r.Ok) {
        Write-Host "[$stamp] $($r.Name) : OK, da cap nhat vao MT5  $($r.Summary)" -ForegroundColor Green
        $r.Warnings | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    } else {
        Write-Host "[$stamp] $($r.Name) : COMPILE LOI" -ForegroundColor Red
        $r.Errors | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        [console]::Beep(400, 300)
    }
}

try { $mt5 = Find-MT5 } catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }
Write-Host "MT5 Experts: $($mt5.Experts)" -ForegroundColor Cyan

$files = Get-ChildItem $ProjectDir -Filter *.mq5
if (-not $files) { Write-Host "Khong co file .mq5 nao trong $ProjectDir" -ForegroundColor Yellow }
foreach ($f in $files) { Deploy $f.FullName $mt5 }
if (-not $Watch) { exit 0 }

Write-Host ""
Write-Host "Dang theo doi $ProjectDir ... Sua va luu file .mq5 la bot tu cap nhat. Ctrl+C de dung." -ForegroundColor Cyan
$watcher = New-Object IO.FileSystemWatcher $ProjectDir, "*.mq5"
$watcher.NotifyFilter = [IO.NotifyFilters]'LastWrite, FileName'
$lastRun = @{}
while ($true) {
    $change = $watcher.WaitForChanged([IO.WatcherChangeTypes]'Changed, Created, Renamed', 1000)
    if ($change.TimedOut) { continue }
    $path = Join-Path $ProjectDir $change.Name
    if (-not (Test-Path $path)) { continue }
    $now = Get-Date
    if ($lastRun[$path] -and ($now - $lastRun[$path]).TotalSeconds -lt 2) { continue }  # bo qua su kien trung
    Start-Sleep -Milliseconds 400                                                      # cho editor ghi xong
    $lastRun[$path] = Get-Date
    try { Deploy $path $mt5 } catch { Write-Host "LOI: $_" -ForegroundColor Red }
}
