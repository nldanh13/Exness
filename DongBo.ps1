# DongBo.ps1 - Dong bo code bot tu thu muc cua ban sang MT5 va compile
#   Chay 1 lan:        powershell -ExecutionPolicy Bypass -File .\DongBo.ps1
#   Tu dong khi luu:   powershell -ExecutionPolicy Bypass -File .\DongBo.ps1 -Watch
# Moi file .mq5 trong thu muc nay se duoc chep vao MQL5\Experts va compile.
# Bot dang chay tren bieu do MT5 se tu nap lai ban moi sau khi compile.

param([switch]$Watch)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-MT5 {
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs") |
             Where-Object { $_ -and (Test-Path $_) }
    $terminals = foreach ($r in $roots) {
        Get-ChildItem -Path $r -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "terminal64.exe" } |
            Where-Object { Test-Path $_ }
    }
    if (-not $terminals) { throw "Khong tim thay terminal64.exe. MT5 da duoc cai chua?" }
    $terminal = $terminals | Where-Object { $_ -match "(?i)exness" } | Select-Object -First 1
    if (-not $terminal) { $terminal = $terminals | Select-Object -First 1 }
    $installDir = Split-Path -Parent $terminal

    $base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    $dataDir = $null
    foreach ($d in Get-ChildItem $base -Directory -ErrorAction SilentlyContinue) {
        $origin = Join-Path $d.FullName "origin.txt"
        if ((Test-Path $origin) -and ((Get-Content $origin -Raw).Trim().TrimEnd('\') -ieq $installDir.TrimEnd('\'))) {
            $dataDir = $d.FullName; break
        }
    }
    if (-not $dataDir) {
        $dataDir = Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
                   Where-Object { Test-Path (Join-Path $_.FullName "MQL5\Experts") } |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $dataDir) { throw "Khong tim thay thu muc du lieu MT5. Hay mo MT5 it nhat 1 lan." }

    [pscustomobject]@{
        Editor  = Join-Path $installDir "metaeditor64.exe"
        Experts = Join-Path $dataDir "MQL5\Experts"
    }
}

function Deploy([string]$file, $mt5) {
    $name   = [IO.Path]::GetFileNameWithoutExtension($file)
    $target = Join-Path $mt5.Experts "$name.mq5"
    $log    = Join-Path $env:TEMP "$name-compile.log"
    $stamp  = Get-Date -Format "HH:mm:ss"

    Copy-Item $file $target -Force
    if (Test-Path $log) { Remove-Item $log -Force }
    Start-Process -FilePath $mt5.Editor -ArgumentList "/compile:`"$target`"", "/log:`"$log`"" -Wait

    $lines  = if (Test-Path $log) { Get-Content $log } else { @() }
    $errors = $lines | Where-Object { $_ -match "(?i):\s*error\s" }
    $warns  = $lines | Where-Object { $_ -match "(?i):\s*warning\s" }
    $summary = $lines | Where-Object { $_ -match "(?i)result|errors" } | Select-Object -Last 1

    if ($errors) {
        Write-Host "[$stamp] $name : COMPILE LOI" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        [console]::Beep(400, 300)
    } else {
        Write-Host "[$stamp] $name : OK, da cap nhat vao MT5  $summary" -ForegroundColor Green
        $warns | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
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
