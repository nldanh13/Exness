# ChayThuNghiem.ps1 - Chay lan luot nhieu cau hinh backtest va in bang so sanh
#   powershell -ExecutionPolicy Bypass -File .\ChayThuNghiem.ps1
# Sua danh sach $Runs ben duoi de thu cau hinh khac.

$ErrorActionPreference = "Stop"
$BotName  = "BTC_EMA_Pullback_v2"
$Symbol   = "BTCUSDm"
$Deposit  = 3000
$Leverage = "1:100"
$FromDate = (Get-Date).AddYears(-1).ToString("yyyy.MM.dd")
$ToDate   = (Get-Date).AddDays(-1).ToString("yyyy.MM.dd")

# Moi lan chay: Ten + cac thong so muon doi (cac thong so khac giu mac dinh trong code)
$Base = @{ InpMaxDrawdownPct = 0; InpUsePartial = "false"; InpUseBreakeven = "false"; InpTrailStartR = 1.5; InpATRMult = 2.0 }
function Cfg($extra) { $h = $Base.Clone(); foreach ($k in $extra.Keys) { $h[$k] = $extra[$k] }; $h }
$Runs = @(
    @{ Name = "1-GocKhongDung";  Inputs = @{ InpMaxDrawdownPct = 0 } },
    @{ Name = "2-TatChotHoaVon"; Inputs = @{ InpMaxDrawdownPct = 0; InpUsePartial = "false"; InpUseBreakeven = "false" } },
    @{ Name = "3-SLRongHon";     Inputs = (Cfg @{}) },
    @{ Name = "4-TranhGioMy";    Inputs = (Cfg @{ InpBlock1Start = 13; InpBlock1End = 18 }) },
    @{ Name = "5-GioiHanLenh";   Inputs = (Cfg @{ InpBlock1Start = 13; InpBlock1End = 18; InpMaxTradesPerDay = 2; InpCooldownBars = 3 }) },
    @{ Name = "6-KhungH4";       Inputs = (Cfg @{ InpTF = 16388; InpHTF = 16408 }) }   # 16388 = H4, 16408 = D1
)

Write-Host "Se chay $($Runs.Count) cau hinh, moi cau hinh vai phut." -ForegroundColor Cyan

# --- Tim MT5 ---
$roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs") | Where-Object { $_ -and (Test-Path $_) }
$terminals = foreach ($r in $roots) {
    Get-ChildItem -Path $r -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "terminal64.exe" } | Where-Object { Test-Path $_ }
}
if (-not $terminals) { Write-Host "LOI: Khong tim thay MT5" -ForegroundColor Red; exit 1 }
$terminal = $terminals | Where-Object { $_ -match "(?i)exness" } | Select-Object -First 1
if (-not $terminal) { $terminal = $terminals | Select-Object -First 1 }
$installDir = Split-Path -Parent $terminal

$base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
$dataDir = $null
foreach ($d in Get-ChildItem $base -Directory) {
    $origin = Join-Path $d.FullName "origin.txt"
    if ((Test-Path $origin) -and ((Get-Content $origin -Raw).Trim().TrimEnd('\') -ieq $installDir.TrimEnd('\'))) { $dataDir = $d.FullName; break }
}
if (-not $dataDir) { Write-Host "LOI: Khong tim thay thu muc du lieu MT5" -ForegroundColor Red; exit 1 }

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$experts    = Join-Path $dataDir "MQL5\Experts"
$ex5        = Join-Path $experts "$BotName.ex5"
$compileLog = Join-Path $env:TEMP "$BotName-compile.log"

# --- Luon chep + compile ban moi nhat truoc khi chay ---
$src = Join-Path $ProjectDir "$BotName.mq5"
if (-not (Test-Path $src)) { Write-Host "LOI: Khong thay $src" -ForegroundColor Red; exit 1 }
Copy-Item $src (Join-Path $experts "$BotName.mq5") -Force
if (Test-Path $compileLog) { Remove-Item $compileLog -Force }
if (Test-Path $ex5) { Remove-Item $ex5 -Force }
Start-Process -FilePath (Join-Path $installDir "metaeditor64.exe") `
    -ArgumentList "/compile:`"$(Join-Path $experts "$BotName.mq5")`"", "/log:`"$compileLog`"" -Wait
if (-not (Test-Path $ex5)) {
    Write-Host "LOI: Compile that bai:" -ForegroundColor Red
    if (Test-Path $compileLog) { Get-Content $compileLog | Where-Object { $_ -match "(?i)error" } | Write-Host }
    exit 1
}
Write-Host "Da compile ban moi nhat cua bot." -ForegroundColor Green
if (-not (Select-String -Path $src -Pattern "OnTester" -Quiet)) {
    Write-Host "CANH BAO: file $BotName.mq5 trong $ProjectDir la ban cu (khong co OnTester). Hay chep de ban moi tu goi zip." -ForegroundColor Yellow
}
$startTime = Get-Date

# --- Doc gia tri mac dinh cua tat ca tham so tu file .mq5 ---
$EnumMap = @{ PERIOD_M1 = 1; PERIOD_M5 = 5; PERIOD_M15 = 15; PERIOD_M30 = 30; PERIOD_H1 = 16385; PERIOD_H4 = 16388; PERIOD_D1 = 16408; PERIOD_W1 = 32769 }
$Defaults = [ordered]@{}
$StringInputs = New-Object System.Collections.Generic.HashSet[string]
foreach ($line in Get-Content $src) {
    if ($line -match '^\s*input\s+(?!group\b)(\w+)\s+(\w+)\s*=\s*(.+?);') {
        $type = $Matches[1]; $name = $Matches[2]; $val = $Matches[3].Trim()
        if ($type -eq "string") { [void]$StringInputs.Add($name); $val = $val.Trim('"') }
        elseif ($EnumMap.ContainsKey($val)) { $val = $EnumMap[$val] }
        $Defaults[$name] = [string]$val
    }
}
foreach ($run in $Runs) {
    foreach ($k in $run.Inputs.Keys) {
        if (-not $Defaults.Contains($k)) { Write-Host "LOI: Tham so '$k' trong lan '$($run.Name)' khong co trong bot." -ForegroundColor Red; exit 1 }
    }
}
Write-Host "Doc duoc $($Defaults.Count) tham so mac dinh tu bot." -ForegroundColor Green

$resultFile = Join-Path $base "Common\Files\BTC_EMA_results.csv"
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

# --- Dong MT5 neu dang mo ---
$running = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $terminal }
if ($running) {
    $ans = Read-Host "MT5 dang mo, can dong de chay tu dong. Dong ngay? (y/n)"
    if ($ans -ne "y") { exit 0 }
    $running | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 5
    Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $terminal } | Stop-Process -Force
}

Write-Host "Chay $($Runs.Count) lan backtest $Symbol H1, $FromDate -> $ToDate. Moi lan vai phut, dung tat MT5." -ForegroundColor Cyan
$i = 0
foreach ($run in $Runs) {
    $i++
    Write-Host "[$i/$($Runs.Count)] $($run.Name) ..." -NoNewline
    # Ghi DAY DU moi tham so (MT5 nho gia tri cua lan chay truoc neu bo sot)
    $vals = [ordered]@{}
    foreach ($k in $Defaults.Keys) { $vals[$k] = $Defaults[$k] }
    foreach ($k in $run.Inputs.Keys) { $vals[$k] = [string]$run.Inputs[$k] }
    $vals["InpTestLabel"] = $run.Name
    $inputs = foreach ($k in $vals.Keys) {
        $v = $vals[$k]
        if ($StringInputs.Contains($k)) { "$k=$v" } else { "$k=$v||$v||1||$v||N" }
    }
    $ini = Join-Path $dataDir "$BotName-run$i.ini"
    @"
[Tester]
Expert=$BotName.ex5
Symbol=$Symbol
Period=H1
Model=4
ExecutionMode=100
Optimization=0
FromDate=$FromDate
ToDate=$ToDate
ForwardMode=0
Deposit=$Deposit
Currency=USD
Leverage=$Leverage
Visual=0
Report=$BotName-$($run.Name)
ReplaceReport=1
ShutdownTerminal=1
[TesterInputs]
$($inputs -join "`r`n")
"@ | Set-Content -Path $ini -Encoding Unicode

    $sw = [Diagnostics.Stopwatch]::StartNew()
    Start-Process -FilePath $terminal -ArgumentList "/config:`"$ini`"" -Wait
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
