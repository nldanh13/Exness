# ChayThuNghiem.ps1 - Chay lan luot nhieu cau hinh backtest va in bang so sanh
#   powershell -ExecutionPolicy Bypass -File .\ChayThuNghiem.ps1
# Sua danh sach $Runs ben duoi de thu cau hinh khac.

# Mac dinh chay che do NHANH (gia OHLC tung phut, Model=1): nhanh hon nhieu, du dung de loc cau hinh
# cho chien luoc khung H1/H4/D1. Them -ChinhXac de chay tick that (Model=4) cho cau hinh cuoi cung.
# Cac lan chay cung ma / cung khoang ngay / cung von duoc gom thanh 1 dot "Optimization" cua MT5,
# MT5 tu chia cho moi nhan CPU (nhanh gap nhieu lan). Them -TuanTu de chay lan luot tung lan nhu cu.
param([switch]$ChinhXac, [switch]$TuanTu)

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
    @{ Name = "C-lamTronLot1.5";        Inputs = (Cfg $Brk @{ InpUseADX = "true"; InpMaxRiskRoundUp = 1.5 }) },   # vao 0.01 lot neu rui ro that <= 1.5%
    @{ Name = "C-lamTronLot1.5-truoc";  Inputs = (Cfg $Brk @{ InpUseADX = "true"; InpMaxRiskRoundUp = 1.5 }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C-lamTronLot1.5-ETH";    Inputs = (Cfg $Brk @{ InpUseADX = "true"; InpMaxRiskRoundUp = 1.5 }); Symbol = "ETHUSDm" },
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
    # Tranh tin My co lich (FOMC, CPI): khong vao lenh trong 2 gio truoc/sau. Lich o du-lieu/tin_my.csv.
    @{ Name = "C+tranhTin";             Inputs = (Cfg $Brk $Q @{ InpAvoidUSNews = "true" }) },
    @{ Name = "C+tranhTin-truoc";       Inputs = (Cfg $Brk $Q @{ InpAvoidUSNews = "true" }); From = $OOSFrom; To = $FromDate },
    @{ Name = "C+tranhTin-ETH";         Inputs = (Cfg $Brk $Q @{ InpAvoidUSNews = "true" }); Symbol = "ETHUSDm" },
    # Dung y mac dinh cua EA nhu se chay that (co dung han 15%, lo ngay 3%), khong ghi de gi
    @{ Name = "MacDinh-nhu-chay-that";  Inputs = @{} }
)
# Lan doi chieu: chi kiem tra lenh moi giay (nhanh hon) de do sai khac so voi moi tick (mac dinh)
$Runs += @{ Name = "C-moiGiay"; Inputs = (Cfg $Brk $Q @{ InpManageEverySec = 1 }) }
# Luot song ngan (khung M15, M5): cung cau truc C, von 30000 de lot toi thieu khong bo lenh, chi do xem co loi the sau phi khong.
# Lan 2 da loai H1 (kem H4). Tieu chi dat truoc: PF_Truot0.05% >= 1,3 o CA 3 nam gan day lan 3 nam truoc.
# Che do nhanh (M1 OHLC) khong chinh xac cho khung ngan: ma nao dat phai chay lai bang tick that.
foreach ($tf in @(@{ N = "M15"; V = 15 }, @{ N = "M5"; V = 5 })) {
    $Runs += @{ Name = "Ngan-$($tf.N)";       Inputs = (Cfg $Brk $Q @{ InpTF = $tf.V }); Deposit = 30000 }
    $Runs += @{ Name = "Ngan-$($tf.N)-truoc"; Inputs = (Cfg $Brk $Q @{ InpTF = $tf.V }); Deposit = 30000; From = $OOSFrom; To = $FromDate }
}
# Ma khung thoi gian: 16385 = H1, 16388 = H4, 16408 = D1, 32769 = W1

# Che do chinh xac: B va C tren 3 nam gan day, ETH va giai doan truoc do (bo von 30000 vi khong phu thuoc tick). Moi cai ~20 phut, tong ~2 gio.
# Che do chinh xac: tick that rat nang (moi agent nap ca trieu tick vao RAM). Tren may it RAM (vd. 8 GB)
# chay song song 12 agent se treo may, nen chi chay 5 cau hinh can thiet va chay LAN LUOT (1 agent).
if ($ChinhXac) {
    $Runs = @($Runs | Where-Object { $_.Name -in @("C-Donchian20-H4-ADX", "C-moiGiay", "C-truoc-3nam", "C-ETH", "C-von30000") })
    $TuanTu = $true
}
Write-Host "Se chay $($Runs.Count) cau hinh." -ForegroundColor Cyan

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
    Copy-Item (Join-Path $ProjectDir "du-lieu\tin_my.csv") (Join-Path $mt5.CommonFiles "tin_my.csv") -Force   # lich FOMC + CPI
} catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }
$dataDir    = $mt5.DataDir
$compileLog = $r.Log
$startTime  = Get-Date
# Don bao cao cu cua MT5 (htm/png/ini/xml cua cac lan truoc), de zip chi chua lan nay
Get-ChildItem $dataDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "$BotName-*" -and $_.Extension -in ".htm", ".html", ".png", ".ini", ".xml" } |
    Remove-Item -Force -ErrorAction SilentlyContinue

$resultFile = Join-Path $mt5.CommonFiles "BTC_EMA_results.csv"
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }
$resDirMT5 = Join-Path $mt5.CommonFiles "TrendBotRes"
if (Test-Path $resDirMT5) { Remove-Item (Join-Path $resDirMT5 "*") -Force -ErrorAction SilentlyContinue }
else { New-Item -ItemType Directory -Path $resDirMT5 | Out-Null }
$tradeDirMT5 = Join-Path $mt5.CommonFiles "TrendBotTrades"      # dac diem tung lenh (vao dau / giua / muon xu huong)
if (Test-Path $tradeDirMT5) { Remove-Item (Join-Path $tradeDirMT5 "*") -Force -ErrorAction SilentlyContinue }
else { New-Item -ItemType Directory -Path $tradeDirMT5 | Out-Null }

# Gom cac lan chay theo (ma, tu ngay, den ngay, von): moi nhom 1 dot chay song song.
# So thu tu cau hinh (InpPreset) lien tiep trong moi nhom; bot doc cau hinh tu TrendBot_presets.csv.
$groups = [ordered]@{}
foreach ($run in $Runs) {
    $run.Sym = if ($run.Symbol)  { $run.Symbol }  else { $Symbol }
    $run.Dep = if ($run.Deposit) { $run.Deposit } else { $Deposit }
    $run.Frm = if ($run.From)    { $run.From }    else { $FromDate }
    $run.Tod = if ($run.To)      { $run.To }      else { $ToDate }
    $key = "$($run.Sym)|$($run.Frm)|$($run.Tod)|$($run.Dep)"
    if (-not $groups.Contains($key)) { $groups[$key] = New-Object System.Collections.ArrayList }
    [void]$groups[$key].Add($run)
}
$id = 0
$presetLines = foreach ($g in $groups.Values) { foreach ($run in $g) {
    $id++; $run.Id = $id
    (@("$id", $run.Name) + @($run.Inputs.Keys | Sort-Object | ForEach-Object { "$_=$($run.Inputs[$_])" })) -join ";"
} }
$presetLines | Set-Content -Path (Join-Path $mt5.CommonFiles "TrendBot_presets.csv") -Encoding ASCII
$cacheDir = Join-Path $dataDir "Tester\cache"

$cach = if ($TuanTu) { "lan luot tung lan" } else { "song song, $($groups.Count) dot" }
Write-Host "Chay $($Runs.Count) lan backtest ($cach), che do $ModeLabel. Dung tat MT5." -ForegroundColor Cyan
$j = 0
foreach ($g in $groups.Values) {
    $j++
    $first = $g[0]
    $jobs = New-Object System.Collections.ArrayList
    if ($TuanTu) { foreach ($r in $g) { [void]$jobs.Add(@($r)) } } else { [void]$jobs.Add(@($g)) }
    foreach ($job in $jobs) {
        $a = $job[0].Id; $b = $job[$job.Count - 1].Id
        $names = ($job | ForEach-Object { $_.Name }) -join ", "
        Write-Host "[dot $j/$($groups.Count)] $($first.Sym) $($first.Frm)->$($first.Tod) von $($first.Dep): $names ..." -NoNewline
        # Xoa cache toi uu cua MT5, neu khong MT5 lay ket qua cu va bot khong chay lai (khong ghi file ket qua)
        if (Test-Path $cacheDir) { Get-ChildItem $cacheDir -Filter *.opt -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
        $ini = Join-Path $dataDir "$BotName-dot$j-$a.ini"
        $opt = @{ Symbol = $first.Sym; From = $first.Frm; To = $first.Tod; Deposit = $first.Dep; Leverage = $Leverage;
                  Report = "$BotName-dot$j-$a"; Shutdown = $true; Model = $Model }
        if ($a -eq $b) { $ov = @{ InpPreset = $a } } else { $ov = @{}; $opt.OptKey = "InpPreset"; $opt.OptFrom = $a; $opt.OptTo = $b }
        New-TesterIni $mt5 $Inputs $ov $ini $opt
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Start-Process -FilePath $mt5.Terminal -ArgumentList "/config:`"$ini`"" -Wait
        Write-Host " xong ($([int]$sw.Elapsed.TotalSeconds)s)" -ForegroundColor Green
    }
}

# Gom file ket qua tung lan (TrendBotRes\001.csv ...) theo dung thu tu trong $Runs
$rows = New-Object System.Collections.ArrayList
$missing = @()
foreach ($run in $Runs) {
    $f = Join-Path $resDirMT5 ("{0:D3}.csv" -f $run.Id)
    if (Test-Path $f) { foreach ($r in @(Import-Csv $f)) { [void]$rows.Add($r) } } else { $missing += $run.Name }
}
# Thieu bat ky cau hinh nao = dot chay CHUA HOAN THANH: van luu de xem, nhung khong day len GitHub, khong dung de chon.
$incomplete = $missing.Count -gt 0
if ($incomplete) {
    Write-Host "LOI: thieu ket qua cua $($missing.Count)/$($Runs.Count) cau hinh: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Dot chay nay CHUA HOAN THANH: khong day len GitHub. Hay chay lai, hoac gui file zip cho Claude de tim nguyen nhan." -ForegroundColor Red
}
if ($rows.Count -gt 0) { $rows | Export-Csv -Path $resultFile -NoTypeInformation -Encoding ASCII }
$tradeRows = New-Object System.Collections.ArrayList
foreach ($run in $Runs) {
    $f = Join-Path $tradeDirMT5 ("{0:D3}.csv" -f $run.Id)
    if (Test-Path $f) { foreach ($r in @(Import-Csv $f)) { [void]$tradeRows.Add($r) } }
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
# Chi giu 3 file zip moi nhat trong thu muc bot (ket qua da nam tren GitHub, thu muc ket-qua/)
Get-ChildItem $outDir -Filter "ket-qua-backtest-*.zip" -File | Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 3 | Remove-Item -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "==> GUI FILE NAY CHO CLAUDE: $zip" -ForegroundColor Yellow
# Luu bang ket qua vao thu muc ket-qua/ va day len GitHub, de Claude doc thang (khong can gui zip).
# Chi commit dung file nay; khong dung toi thay doi khac cua ban. Loi mang thi van con file zip de gui tay.
if ($summary) {
    $resDir = Join-Path $ProjectDir "ket-qua"
    if (-not (Test-Path $resDir)) { New-Item -ItemType Directory -Path $resDir | Out-Null }
    $tag     = if ($ChinhXac) { "chinhxac" } else { "nhanh" }
    if ($incomplete) { $tag += "-CHUADU" }
    $resName = (Get-Date -Format "yyyyMMdd-HHmm") + "-$tag.csv"
    Copy-Item $summary (Join-Path $resDir $resName) -Force
    $tradeName = $resName -replace '\.csv$', '-lenh.csv'
    if ($tradeRows.Count -gt 0) { $tradeRows | Export-Csv -Path (Join-Path $resDir $tradeName) -NoTypeInformation -Encoding ASCII }
    if ($incomplete) {
        Write-Host "Da luu ban CHUA DU o ket-qua\$resName (chi tren may, khong day len GitHub)." -ForegroundColor Yellow
    } elseif ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $ProjectDir ".git"))) {
        $rel = "ket-qua/$resName"
        $relT = "ket-qua/$tradeName"
        $paths = @($rel); if (Test-Path (Join-Path $ProjectDir $relT)) { $paths += $relT }
        # Neu may ban dang co commit chua day len, KHONG day ho (git push day ca nhanh).
        & git -C $ProjectDir fetch -q 2>&1 | Out-Null
        $ahead = [int](& git -C $ProjectDir rev-list --count "@{u}..HEAD" 2>$null)
        if ($ahead -gt 0) {
            $gitOut = @("May ban co $ahead commit chua day len GitHub. De tranh day nham, script khong tu day ket qua.")
            $LASTEXITCODE = 1
        } else { $gitOut = & git -C $ProjectDir add -- $paths 2>&1 }
        if ($LASTEXITCODE -eq 0) { $gitOut = & git -C $ProjectDir commit -q -m "Ket qua backtest $resName" -- $paths 2>&1 }
        # Trong 35-45 phut chay co the da co commit moi tren GitHub: keo ve truoc roi moi day
        if ($LASTEXITCODE -eq 0) { $gitOut = & git -C $ProjectDir pull -q --rebase --autostash 2>&1 }
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
