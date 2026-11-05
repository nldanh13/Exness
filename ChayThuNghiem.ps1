# ChayThuNghiem.ps1 - Chay lan luot nhieu cau hinh backtest va in bang so sanh
#   powershell -ExecutionPolicy Bypass -File .\ChayThuNghiem.ps1
# Sua danh sach $Runs ben duoi de thu cau hinh khac.

$ErrorActionPreference = "Stop"
$Symbol   = "BTCUSDm"
$Deposit  = 3000
$Leverage = "1:100"
$FromDate = (Get-Date).AddYears(-1).ToString("yyyy.MM.dd")
$ToDate   = (Get-Date).AddDays(-1).ToString("yyyy.MM.dd")

# Moi lan chay: Ten + cac thong so muon doi (cac thong so khac giu mac dinh trong code)
# Cau hinh co so cho chien luoc breakout: SL rong, khong TP, trailing ATR (chandelier) tu dau
$Base = @{ InpMaxDrawdownPct = 0; InpUsePartial = "false"; InpUseBreakeven = "false" }
$Brk  = @{ InpStrategy = 1; InpTF = 16388; InpHTF = 16408; InpATRMult = 2.5; InpRR = 0; InpUseTrailing = "true";
           InpTrailStartR = 0; InpTrailATRMult = 3.0; InpUseADX = "false"; InpSkipWeekend = "false";
           InpBlock1Start = -1; InpBlock2Start = -1; InpDonchianPeriod = 20 }
function Cfg($a, $b) { $h = $Base.Clone(); foreach ($x in @($a, $b)) { if ($x) { foreach ($k in $x.Keys) { $h[$k] = $x[$k] } } }; $h }
$Runs = @(
    @{ Name = "A-EMA-H4-cu";        Inputs = (Cfg @{ InpTF = 16388; InpHTF = 16408; InpTrailStartR = 1.5; InpATRMult = 2.0 }) },
    @{ Name = "B-Donchian20-H4";    Inputs = (Cfg $Brk) },
    @{ Name = "C-Donchian20-H4-ADX"; Inputs = (Cfg $Brk @{ InpUseADX = "true" }) },
    @{ Name = "D-Donchian55-H4";    Inputs = (Cfg $Brk @{ InpDonchianPeriod = 55 }) },
    @{ Name = "E-Donchian20-D1";    Inputs = (Cfg $Brk @{ InpTF = 16408; InpHTF = 32769 }) },
    @{ Name = "F-Donchian20-H1";    Inputs = (Cfg $Brk @{ InpTF = 16385; InpHTF = 16388 }) }
)
# Ma khung thoi gian: 16385 = H1, 16388 = H4, 16408 = D1, 32769 = W1

Write-Host "Se chay $($Runs.Count) cau hinh, moi cau hinh vai phut." -ForegroundColor Cyan

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ProjectDir "MT5Common.ps1")

try {
    $mt5 = Find-MT5
    $src = Join-Path $ProjectDir "$BotName.mq5"
    if (-not (Test-Path $src)) { throw "Khong thay $src" }
    # Luon chep + compile ban moi nhat truoc khi chay
    $r = Invoke-BotCompile $mt5 $src
    if (-not $r.Ok) { $r.Errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }; throw "Compile that bai." }
    Write-Host "Da compile ban moi nhat cua bot. $($r.Summary)" -ForegroundColor Green
    $Inputs = Get-BotInputs $src
    foreach ($run in $Runs) { foreach ($k in $run.Inputs.Keys) {
        if (-not $Inputs.Defaults.Contains($k)) { throw "Tham so '$k' trong lan '$($run.Name)' khong co trong bot." } } }
    Write-Host "Doc duoc $($Inputs.Defaults.Count) tham so mac dinh tu bot." -ForegroundColor Green
} catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }
$dataDir    = $mt5.DataDir
$compileLog = $r.Log
$startTime  = Get-Date

$resultFile = Join-Path $mt5.CommonFiles "BTC_EMA_results.csv"
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

# --- Dong MT5 neu dang mo ---
if (-not (Stop-MT5 $mt5)) { exit 0 }

Write-Host "Chay $($Runs.Count) lan backtest $Symbol, $FromDate -> $ToDate. Moi lan vai phut, dung tat MT5." -ForegroundColor Cyan
$i = 0
foreach ($run in $Runs) {
    $i++
    Write-Host "[$i/$($Runs.Count)] $($run.Name) ..." -NoNewline
    $ini = Join-Path $dataDir "$BotName-run$i.ini"
    $ov = $run.Inputs.Clone(); $ov["InpTestLabel"] = $run.Name
    New-TesterIni $mt5 $Inputs $ov $ini @{ Symbol = $Symbol; From = $FromDate; To = $ToDate; Deposit = $Deposit;
                                           Leverage = $Leverage; Report = "$BotName-$($run.Name)"; Shutdown = $true }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    Start-Process -FilePath $mt5.Terminal -ArgumentList "/config:`"$ini`"" -Wait
    Write-Host " xong ($([int]$sw.Elapsed.TotalSeconds)s)" -ForegroundColor Green
}

Write-Host ""
$summary = Join-Path $ProjectDir "ket-qua-so-sanh.csv"
if (Test-Path $resultFile) {
    Import-Csv $resultFile | Format-Table -AutoSize | Out-String -Width 250 | Write-Host
    Copy-Item $resultFile $summary -Force
    Write-Host "Da luu bang so sanh: $summary" -ForegroundColor Cyan
} else {
    Write-Host "CANH BAO: Khong co file ket qua tong hop. Van gom bao cao + log de Claude chan doan." -ForegroundColor Yellow
    $summary = $null
}
# Gom tat ca ket qua vao 1 file zip de gui
$outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pack   = Join-Path $env:TEMP "BTC_EMA_ketqua"
if (Test-Path $pack) { Remove-Item $pack -Recurse -Force }
New-Item -ItemType Directory -Path $pack | Out-Null
if ($summary) { Copy-Item $summary $pack }
# Bao cao HTML/PNG cua cac lan chay
Get-ChildItem $dataDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "$BotName-*" -and $_.Extension -in ".htm", ".html", ".png", ".ini" } |
    Copy-Item -Destination $pack -ErrorAction SilentlyContinue
# Log chan doan: compile, nhat ky terminal/tester, nhat ky agent (chi phan moi)
$diag = Join-Path $pack "logs"
New-Item -ItemType Directory -Path $diag | Out-Null
if (Test-Path $compileLog) { Copy-Item $compileLog $diag }
$logDirs = @((Join-Path $dataDir "logs"), (Join-Path $dataDir "Tester\logs"), (Join-Path $env:APPDATA "MetaQuotes\Tester"))
$n = 0
foreach ($ld in $logDirs) {
    if (-not (Test-Path $ld)) { continue }
    Get-ChildItem $ld -Recurse -Filter *.log -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $startTime.AddMinutes(-5) } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 6 | ForEach-Object {
            $n++
            Get-Content $_.FullName -Tail 3000 | Set-Content (Join-Path $diag ("$n-" + $_.Directory.Name + "-" + $_.Name + ".txt"))
        }
}
$zip = Join-Path $outDir ("ket-qua-backtest-" + (Get-Date -Format "yyyyMMdd-HHmm") + ".zip")
Compress-Archive -Path (Join-Path $pack "*") -DestinationPath $zip -Force
Write-Host ""
Write-Host "==> GUI FILE NAY CHO CLAUDE: $zip" -ForegroundColor Yellow
Invoke-Item $outDir
