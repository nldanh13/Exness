# ChayThuNghiem.ps1 - Chay lan luot nhieu cau hinh backtest va in bang so sanh
#   powershell -ExecutionPolicy Bypass -File .\ChayThuNghiem.ps1
# Sua danh sach $Runs ben duoi de thu cau hinh khac.

# Mac dinh chay che do NHANH (gia OHLC tung phut, Model=1): nhanh hon nhieu, du dung de loc cau hinh
# cho chien luoc khung H1/H4/D1. Them -ChinhXac de chay tick that (Model=4) cho cau hinh cuoi cung.
param([switch]$ChinhXac)

$ErrorActionPreference = "Stop"
$Model = if ($ChinhXac) { 4 } else { 1 }
$ModeLabel = if ($ChinhXac) { "tick that (chinh xac)" } else { "OHLC 1 phut (nhanh)" }
$Symbol   = "BTCUSDm"
$Deposit  = 3000
$Leverage = "1:100"
$Years    = 3       # H4/D1 can nhieu nam de du so lenh; MT5 se bat dau tu ngay co du lieu som nhat
$FromDate = (Get-Date).AddYears(-$Years).ToString("yyyy.MM.dd")
$ToDate   = (Get-Date).AddDays(-1).ToString("yyyy.MM.dd")

# Moi lan chay: Ten + cac thong so muon doi (cac thong so khac giu mac dinh trong code)
# $Base: bo loc CHUNG cho moi cau hinh de so sanh cong bang (chi khac nhau o chien luoc / khung)
$Base = @{ InpMaxDrawdownPct = 0; InpUsePartial = "false"; InpUseBreakeven = "false"; InpUseTrailing = "true";
           InpUseADX = "false"; InpSkipWeekend = "false"; InpBlock1Start = -1; InpBlock2Start = -1;
           InpTF = 16388; InpHTF = 16408; InpUseHTF = "true" }
# EMA pullback: SL 2 ATR, TP 2R, trailing tu 1.5R
$Ema  = @{ InpStrategy = 0; InpATRMult = 2.0; InpRR = 2.0; InpTrailStartR = 1.5; InpTrailATRMult = 2.0 }
# Donchian breakout: SL 2.5 ATR, khong TP, trailing 3 ATR tu dau (chandelier)
$Brk  = @{ InpStrategy = 1; InpATRMult = 2.5; InpRR = 0; InpTrailStartR = 0; InpTrailATRMult = 3.0; InpDonchianPeriod = 20 }
# Bo loc cu cua EMA (ADX + bo cuoi tuan + nghi gio tin) de doi chieu
$OldFilters = @{ InpUseADX = "true"; InpSkipWeekend = "true"; InpBlock1Start = 12; InpBlock1End = 14; InpBlock2Start = 18; InpBlock2End = 20 }
function Cfg { $h = $Base.Clone(); foreach ($x in $args) { if ($x) { foreach ($k in $x.Keys) { $h[$k] = $x[$k] } } }; $h }
# Lan 3 (11/2026): kiem tra do ben cua Donchian H4. EMA, D1, H1 da loai o lan 2.
#  - Von 30000: xem lot toi thieu co dang bo bot lenh (so lenh, BoQuaLot, % lai) khong
#  - ETHUSDm: cung tham so tren cap khac (du lieu chua dung de chon)
#  - 2020-2023: giai doan truoc 3 nam da dung de chon (ngoai mau)
# Moi lan co the ghi de: Deposit, Symbol, From, To.
$Q = @{ InpUseADX = "true" }   # C = Donchian20 H4 + ADX
$OOSFrom = (Get-Date).AddYears(-6).ToString("yyyy.MM.dd")
$Runs = @(
    @{ Name = "B-Donchian20-H4";        Inputs = (Cfg $Brk) },
    @{ Name = "C-Donchian20-H4-ADX";    Inputs = (Cfg $Brk @{ InpUseADX = "true" }) },
    @{ Name = "D-Donchian55-H4";        Inputs = (Cfg $Brk @{ InpDonchianPeriod = 55 }) },
    @{ Name = "B-von30000";             Inputs = (Cfg $Brk);                          Deposit = 30000 },
    @{ Name = "C-von30000";             Inputs = (Cfg $Brk @{ InpUseADX = "true" });  Deposit = 30000 },
    @{ Name = "B-ETH";                  Inputs = (Cfg $Brk);                          Symbol = "ETHUSDm" },
    @{ Name = "C-ETH";                  Inputs = (Cfg $Brk @{ InpUseADX = "true" });  Symbol = "ETHUSDm" },
    @{ Name = "B-truoc-3nam";           Inputs = (Cfg $Brk);                          From = $OOSFrom; To = $FromDate },
    @{ Name = "C-truoc-3nam";           Inputs = (Cfg $Brk @{ InpUseADX = "true" });  From = $OOSFrom; To = $FromDate },
    # Chat luong breakout (them vao C): than nen >= 50%, vuot kenh >= 0.25 ATR, cho 1 nen xac nhan.
    # Chi giu bo loc nao tot hon C o CA 3 noi: 3 nam gan day, 3 nam truoc, ETH.
    @{ Name = "C+than50";               Inputs = (Cfg $Brk $Q @{ InpBreakMinBody = 50 }) },
    @{ Name = "C+than50-truoc";         Inputs = (Cfg $Brk $Q @{ InpBreakMinBody = 50 });  From = $OOSFrom; To = $FromDate },
    @{ Name = "C+than50-ETH";           Inputs = (Cfg $Brk $Q @{ InpBreakMinBody = 50 });  Symbol = "ETHUSDm" },
    @{ Name = "C+vuot0.25ATR";          Inputs = (Cfg $Brk $Q @{ InpBreakMinATR = 0.25 }) },
    @{ Name = "C+vuot0.25ATR-truoc";    Inputs = (Cfg $Brk $Q @{ InpBreakMinATR = 0.25 }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+vuot0.25ATR-ETH";      Inputs = (Cfg $Brk $Q @{ InpBreakMinATR = 0.25 }); Symbol = "ETHUSDm" },
    @{ Name = "C+xacnhan";              Inputs = (Cfg $Brk $Q @{ InpBreakConfirm = "true" }) },
    @{ Name = "C+xacnhan-truoc";        Inputs = (Cfg $Brk $Q @{ InpBreakConfirm = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+xacnhan-ETH";          Inputs = (Cfg $Brk $Q @{ InpBreakConfirm = "true" }); Symbol = "ETHUSDm" },
    # Tu tai lieu thanh khoan: cuoi tuan so lenh mong (khoi luong ~1/2 ngay thuong), de bi quet.
    @{ Name = "C+nghiCuoiTuan";         Inputs = (Cfg $Brk $Q @{ InpSkipWeekend = "true" }) },
    @{ Name = "C+nghiCuoiTuan-truoc";   Inputs = (Cfg $Brk $Q @{ InpSkipWeekend = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+nghiCuoiTuan-ETH";     Inputs = (Cfg $Brk $Q @{ InpSkipWeekend = "true" }); Symbol = "ETHUSDm" },
    # Tu tai lieu thanh ly: nen pha vo > 3 ATR thuong la thanh ly day chuyen, vao theo la duoi gia.
    @{ Name = "C+boNenDai3ATR";         Inputs = (Cfg $Brk $Q @{ InpBreakMaxATR = 3 }) },
    @{ Name = "C+boNenDai3ATR-truoc";   Inputs = (Cfg $Brk $Q @{ InpBreakMaxATR = 3 }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+boNenDai3ATR-ETH";     Inputs = (Cfg $Brk $Q @{ InpBreakMaxATR = 3 }); Symbol = "ETHUSDm" },
    # Funding rate Binance: bo Buy khi funding > 0.03%/8h (phe Long qua dong), bo Sell khi < -0.03%.
    @{ Name = "C+funding";              Inputs = (Cfg $Brk $Q @{ InpUseFunding = "true" }) },
    @{ Name = "C+funding-truoc";        Inputs = (Cfg $Brk $Q @{ InpUseFunding = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+funding-ETH";          Inputs = (Cfg $Brk $Q @{ InpUseFunding = "true" }); Symbol = "ETHUSDm" },
    # Tu tai lieu tam ly: bo Buy khi Fear & Greed hom qua >= 76 (tham lam cuc do), bo Sell khi <= 24.
    @{ Name = "C+fearGreed";            Inputs = (Cfg $Brk $Q @{ InpUseFearGreed = "true" }) },
    @{ Name = "C+fearGreed-truoc";      Inputs = (Cfg $Brk $Q @{ InpUseFearGreed = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+fearGreed-ETH";        Inputs = (Cfg $Brk $Q @{ InpUseFearGreed = "true" }); Symbol = "ETHUSDm" },
    # Su chu y (Kristoufek 2013): chi vao lenh khi luot xem Wikipedia TB 7 ngay > TB 30 ngay.
    @{ Name = "C+chuY";                 Inputs = (Cfg $Brk $Q @{ InpUseAttention = "true" }) },
    @{ Name = "C+chuY-truoc";           Inputs = (Cfg $Brk $Q @{ InpUseAttention = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+chuY-ETH";             Inputs = (Cfg $Brk $Q @{ InpUseAttention = "true" }); Symbol = "ETHUSDm" },
    # Tuong quan voi chung khoan My: Buy chi khi USTEC tren EMA200 D1, Sell chi khi duoi.
    @{ Name = "C+nasdaq";               Inputs = (Cfg $Brk $Q @{ InpUseMarketFilter = "true" }) },
    @{ Name = "C+nasdaq-truoc";         Inputs = (Cfg $Brk $Q @{ InpUseMarketFilter = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+nasdaq-ETH";           Inputs = (Cfg $Brk $Q @{ InpUseMarketFilter = "true" }); Symbol = "ETHUSDm" },
    # Dung y mac dinh cua EA nhu se chay that (co dung han 15%, lo ngay 3%), khong ghi de gi
    @{ Name = "MacDinh-nhu-chay-that";  Inputs = @{} }
)
# Ma khung thoi gian: 16385 = H1, 16388 = H4, 16408 = D1, 32769 = W1

# Che do chinh xac: B va C tren 3 nam gan day, ETH va giai doan truoc do (bo von 30000 vi khong phu thuoc tick). Moi cai ~20 phut, tong ~2 gio.
if ($ChinhXac) { $Runs = @($Runs | Where-Object { $_.Name -in @("B-Donchian20-H4", "C-Donchian20-H4-ADX", "B-ETH", "C-ETH", "B-truoc-3nam", "C-truoc-3nam", "MacDinh-nhu-chay-that") }) }
Write-Host "Se chay $($Runs.Count) cau hinh, moi cau hinh vai phut." -ForegroundColor Cyan

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ProjectDir "MT5Common.ps1")

try {
    $mt5 = Find-MT5
    $src = Join-Path $ProjectDir "$BotName.mq5"
    if (-not (Test-Path $src)) { throw "Khong thay $src" }
    $Inputs = Get-BotInputs $src
    foreach ($run in $Runs) { foreach ($k in $run.Inputs.Keys) {
        if (-not $Inputs.Defaults.Contains($k)) { throw "Tham so '$k' trong lan '$($run.Name)' khong co trong bot." } } }
    Write-Host "Doc duoc $($Inputs.Defaults.Count) tham so mac dinh tu bot." -ForegroundColor Green
} catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }

# --- Dong MT5 TRUOC khi compile: compile khi MT5 dang mo se nap lai bot dang chay tren chart ---
if (-not (Stop-MT5 $mt5)) { exit 0 }
try {
    # Luon chep + compile ban moi nhat truoc khi chay
    $r = Invoke-BotCompile $mt5 $src
    if (-not $r.Ok) { $r.Errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }; throw "Compile that bai." }
    Write-Host "Da compile ban moi nhat cua bot. $($r.Summary)" -ForegroundColor Green
    Write-Host "Cap nhat du lieu funding rate tu Binance..." -ForegroundColor Cyan
    Update-FundingData $mt5 @("BTCUSDT", "ETHUSDT")
    Update-SentimentData $mt5
} catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }
$dataDir    = $mt5.DataDir
$compileLog = $r.Log
$startTime  = Get-Date

$resultFile = Join-Path $mt5.CommonFiles "BTC_EMA_results.csv"
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }


Write-Host "Chay $($Runs.Count) lan backtest $Symbol, $FromDate -> $ToDate, che do $ModeLabel. Dung tat MT5." -ForegroundColor Cyan
$i = 0
foreach ($run in $Runs) {
    $i++
    Write-Host "[$i/$($Runs.Count)] $($run.Name) ..." -NoNewline
    $ini = Join-Path $dataDir "$BotName-run$i.ini"
    $ov = $run.Inputs.Clone(); $ov["InpTestLabel"] = $run.Name
    $sym = if ($run.Symbol)  { $run.Symbol }  else { $Symbol }
    $dep = if ($run.Deposit) { $run.Deposit } else { $Deposit }
    $frm = if ($run.From)    { $run.From }    else { $FromDate }
    $tod = if ($run.To)      { $run.To }      else { $ToDate }
    New-TesterIni $mt5 $Inputs $ov $ini @{ Symbol = $sym; From = $frm; To = $tod; Deposit = $dep;
                                           Leverage = $Leverage; Report = "$BotName-$($run.Name)"; Shutdown = $true; Model = $Model }

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
# Luu bang ket qua vao thu muc ket-qua/ va day len GitHub, de Claude doc thang (khong can gui zip).
# Chi commit dung file nay; khong dung toi thay doi khac cua ban. Loi mang thi van con file zip de gui tay.
if ($summary) {
    $resDir = Join-Path $ProjectDir "ket-qua"
    if (-not (Test-Path $resDir)) { New-Item -ItemType Directory -Path $resDir | Out-Null }
    $tag     = if ($ChinhXac) { "chinhxac" } else { "nhanh" }
    $resName = (Get-Date -Format "yyyyMMdd-HHmm") + "-$tag.csv"
    Copy-Item $summary (Join-Path $resDir $resName) -Force
    if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $ProjectDir ".git"))) {
        $rel = "ket-qua/$resName"
        $gitOut = & git -C $ProjectDir add -- $rel 2>&1
        if ($LASTEXITCODE -eq 0) { $gitOut = & git -C $ProjectDir commit -q -m "Ket qua backtest $resName" -- $rel 2>&1 }
        if ($LASTEXITCODE -eq 0) { $gitOut = & git -C $ProjectDir push -q 2>&1 }
        # Kiem tra chac chan file da co tren GitHub (khong chi tin ma thoat cua push)
        $onRemote = $false
        if ($LASTEXITCODE -eq 0) {
            & git -C $ProjectDir fetch -q 2>&1 | Out-Null
            & git -C $ProjectDir cat-file -e "@{u}:$rel" 2>&1 | Out-Null
            $onRemote = ($LASTEXITCODE -eq 0)
        }
        if ($onRemote) {
            Write-Host "==> Da day ket qua len GitHub ($rel). Chi can nhan Claude 'xong roi', khong can gui zip." -ForegroundColor Green
        } else {
            Write-Host "Khong day duoc ket qua len GitHub, hay gui file zip:" -ForegroundColor Yellow
            $gitOut | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
        }
    }
}
Invoke-Item $outDir
