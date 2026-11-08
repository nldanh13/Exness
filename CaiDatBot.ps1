# CaiDatBot.ps1 - Cai bot vao MT5 va chay 1 lan backtest voi tham so mac dinh trong code
#   powershell -ExecutionPolicy Bypass -File .\CaiDatBot.ps1
# Bien moi truong TRENDBOT_SETFILE (giao dien, tab "Thong so" > Backtest): duong dan file .set, ghi de len mac dinh.

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ProjectDir "MT5Common.ps1")

$Symbol   = "BTCUSDm"
$Deposit  = 3000
$Years    = 1
# Giao dien (tab "Thong so") co the chon von va so nam
$d = 0; if ([double]::TryParse([string]$env:TRENDBOT_VON, [ref]$d) -and $d -ge 10) { $Deposit = $d }
$y = 0; if ([int]::TryParse([string]$env:TRENDBOT_SONAM, [ref]$y) -and $y -ge 1 -and $y -le 7) { $Years = $y }
$Leverage = "1:100"

try {
    $src = Join-Path $ProjectDir "$BotName.mq5"
    if (-not (Test-Path $src)) { throw "Khong thay $src" }
    Write-Host "[1/4] Tim MetaTrader 5..."
    $mt5 = Find-MT5
    Write-Host "      Du lieu: $($mt5.DataDir)"

    Write-Host "[2/4] Chep va compile bot..."
    if (Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $mt5.Terminal }) {
        Write-Host "      Luu y: MT5 dang mo, bot dang chay tren chart se tu nap lai ban moi." -ForegroundColor Yellow }
    $r = Invoke-BotCompile $mt5 $src
    if (-not $r.Ok) { $r.Errors | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }; throw "Compile that bai. Log: $($r.Log)" }
    Write-Host "      $($r.Summary)" -ForegroundColor Green

    Write-Host "[3/4] Tao cau hinh backtest (ghi day du moi tham so mac dinh)..."
    $inputs = Get-BotInputs $src
    $over = @{ InpTestLabel = "mac-dinh" }
    $setFile = $env:TRENDBOT_SETFILE
    if ($setFile) {
        if (-not (Test-Path $setFile)) { throw "Khong thay file thong so $setFile" }
        $over.InpTestLabel = [IO.Path]::GetFileNameWithoutExtension($setFile)
        $bo = 0
        foreach ($line in ([IO.File]::ReadAllText($setFile) -split "`r?`n")) {
            if ($line -notmatch '^\s*(Inp\w+)=(.*)$') { continue }
            $k = $Matches[1]; $v = ($Matches[2] -split '\|\|')[0]
            if ($k -in @('InpTestLabel', 'InpPreset')) { continue }
            if (-not $inputs.Defaults.Contains($k)) { $bo++; continue }   # thong so cua ban bot cu / khac
            $over[$k] = $v
        }
        Write-Host "      Dung bo thong so: $setFile ($($over.Count - 1) thong so)" -ForegroundColor Cyan
        if ($bo -gt 0) { Write-Host "      Bo qua $bo thong so khong co trong ban bot nay." -ForegroundColor Yellow }
    }
    $from = (Get-Date).AddYears(-$Years).ToString("yyyy.MM.dd")
    $to   = (Get-Date).AddDays(-1).ToString("yyyy.MM.dd")
    $ini  = Join-Path $mt5.DataDir "$BotName-tester.ini"
    New-TesterIni $mt5 $inputs $over $ini @{
        Symbol = $Symbol; From = $from; To = $to; Deposit = $Deposit; Leverage = $Leverage
        Report = "$BotName-report"; Shutdown = $false }

    Write-Host "[4/4] Mo MT5 va chay backtest..."
    if (-not (Stop-MT5 $mt5)) { Write-Host "Bot da cai xong. Ban co the tu mo Tester trong MT5." -ForegroundColor Green; exit 0 }
    Start-Process -FilePath $mt5.Terminal -ArgumentList "/config:`"$ini`""
    Write-Host ""
    Write-Host "XONG! MT5 dang chay backtest $from -> $to tren $Symbol." -ForegroundColor Green
    Write-Host "Bao cao HTML: $($mt5.DataDir)\$BotName-report.htm"
} catch {
    Write-Host "LOI: $_" -ForegroundColor Red
    exit 1
}
