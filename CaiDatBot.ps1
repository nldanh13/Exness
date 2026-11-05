# CaiDatBot.ps1 - Tu dong cai bot BTC_EMA_Pullback_v2 vao MT5 va chay backtest
# Chay trong terminal PowerShell (VS Code): .\CaiDatBot.ps1  (cung thu muc voi BTC_EMA_Pullback_v2.mq5)

$ErrorActionPreference = "Stop"
$BotName   = "BTC_EMA_Pullback_v2"
$Symbol    = "BTCUSDm"
$Deposit   = 3000
$Leverage  = "1:100"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source    = Join-Path $ScriptDir "$BotName.mq5"

function Fail($msg) {
    Write-Host ""
    Write-Host "LOI: $msg" -ForegroundColor Red
    exit 1
}

Write-Host "=== Cai dat bot $BotName ===" -ForegroundColor Cyan

if (-not (Test-Path $Source)) { Fail "Khong thay file $BotName.mq5 trong thu muc $ScriptDir. Hay tai file .mq5 de cung thu muc voi script nay." }

# 1) Tim noi cai MT5 (uu tien ban Exness)
Write-Host "[1/5] Tim MetaTrader 5..."
$roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs") | Where-Object { $_ -and (Test-Path $_) }
$terminals = foreach ($r in $roots) {
    Get-ChildItem -Path $r -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "terminal64.exe" } |
        Where-Object { Test-Path $_ }
}
if (-not $terminals) { Fail "Khong tim thay terminal64.exe. MT5 da duoc cai chua?" }
$terminal = ($terminals | Where-Object { $_ -match "(?i)exness" } | Select-Object -First 1)
if (-not $terminal) { $terminal = $terminals | Select-Object -First 1 }
$installDir = Split-Path -Parent $terminal
$editor     = Join-Path $installDir "metaeditor64.exe"
if (-not (Test-Path $editor)) { Fail "Khong thay metaeditor64.exe trong $installDir" }
Write-Host "      MT5: $installDir"

# 2) Tim thu muc du lieu tuong ung
Write-Host "[2/5] Tim thu muc du lieu MT5..."
$base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
if (-not (Test-Path $base)) { Fail "Khong thay $base. Hay mo MT5 it nhat 1 lan roi chay lai." }
$dataDir = $null
foreach ($d in Get-ChildItem $base -Directory) {
    $origin = Join-Path $d.FullName "origin.txt"
    if (Test-Path $origin) {
        $o = (Get-Content $origin -Raw).Trim().TrimEnd('\')
        if ($o -ieq $installDir.TrimEnd('\')) { $dataDir = $d.FullName; break }
    }
}
if (-not $dataDir) {
    $dataDir = Get-ChildItem $base -Directory | Where-Object { Test-Path (Join-Path $_.FullName "MQL5\Experts") } |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $dataDir) { Fail "Khong tim thay thu muc MQL5\Experts." }
$experts = Join-Path $dataDir "MQL5\Experts"
Write-Host "      Du lieu: $dataDir"

# 3) Chep bot
Write-Host "[3/5] Chep bot vao MQL5\Experts..."
$target = Join-Path $experts "$BotName.mq5"
Copy-Item $Source $target -Force

# 4) Compile
Write-Host "[4/5] Compile bot..."
$log = Join-Path $env:TEMP "$BotName-compile.log"
if (Test-Path $log) { Remove-Item $log -Force }
$ex5 = Join-Path $experts "$BotName.ex5"
if (Test-Path $ex5) { Remove-Item $ex5 -Force }
Start-Process -FilePath $editor -ArgumentList "/compile:`"$target`"", "/log:`"$log`"" -Wait
if (Test-Path $log) {
    $result = Get-Content $log | Where-Object { $_ -match "(?i)error|warning|result" }
    $result | ForEach-Object { Write-Host "      $_" }
}
if (-not (Test-Path $ex5)) { Fail "Compile that bai. Xem file log: $log (chup man hinh gui lai de sua)." }
Write-Host "      Compile thanh cong." -ForegroundColor Green

# 5) Tao cau hinh backtest va mo MT5
Write-Host "[5/5] Mo MT5 va chay backtest..."
$running = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $terminal }
if ($running) {
    Write-Host "      MT5 dang mo. Can dong MT5 de chay backtest tu dong." -ForegroundColor Yellow
    $ans = Read-Host "      Dong MT5 ngay bay gio? (y/n)"
    if ($ans -ne "y") {
        Write-Host "Bot da cai xong. Ban co the tu mo Tester trong MT5." -ForegroundColor Green
        exit 0
    }
    $running | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 5
    Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $terminal } | Stop-Process -Force
}

$to   = (Get-Date).AddDays(-1).ToString("yyyy.MM.dd")
$from = (Get-Date).AddYears(-1).ToString("yyyy.MM.dd")
$ini  = Join-Path $dataDir "$BotName-tester.ini"
@"
[Tester]
Expert=$BotName.ex5
Symbol=$Symbol
Period=H1
Model=4
ExecutionMode=100
Optimization=0
FromDate=$from
ToDate=$to
ForwardMode=0
Deposit=$Deposit
Currency=USD
Leverage=$Leverage
ProfitInPips=0
Visual=0
Report=$BotName-report
ReplaceReport=1
ShutdownTerminal=0
"@ | Set-Content -Path $ini -Encoding Unicode

Start-Process -FilePath $terminal -ArgumentList "/config:`"$ini`""
Write-Host ""
Write-Host "XONG! MT5 dang mo va tu chay backtest $from -> $to tren $Symbol H1." -ForegroundColor Green
Write-Host "Lan dau MT5 can tai du lieu tick, co the mat vai phut."
Write-Host "Ket qua: xem tab Backtest / Bieu do trong Tester. Bao cao HTML luu tai: $dataDir\$BotName-report.htm"
