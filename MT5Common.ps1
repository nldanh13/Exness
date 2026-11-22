# MT5Common.ps1 - Ham dung chung cho DongBo.ps1, CaiDatBot.ps1, ChayThuNghiem.ps1
# Khong chay truc tiep file nay.

$BotName = "BTC_EMA_Pullback_v2"

# Tim MT5: noi cai dat + thu muc du lieu (co buoc du phong neu origin.txt khong khop)
# -MoPhong: ban MT5 dung de mo phong (backtest / xep hang). Neu file mt5-mophong.txt (canh script) ghi thu muc cai cua MOT
# BAN MT5 THU HAI, mo phong chay tren ban do va KHONG bao gio dong ban MT5 dang giao dich. Khong co file thi dung ban chinh.
# Thu muc Common\Files dung chung moi ban MT5 tren may, nen bot dang chay doc ngay bang xep hang ban kia vua ghi.
function Get-MoPhongDir {
    $f = Join-Path $PSScriptRoot "mt5-mophong.txt"
    if (-not (Test-Path $f)) { return $null }
    $d = @(Get-Content $f | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ -and -not $_.StartsWith("#") }) | Select-Object -First 1
    if ($d -and (Test-Path (Join-Path $d "terminal64.exe"))) { return $d.TrimEnd('\') }
    if ($d) { Write-Host "CANH BAO: mt5-mophong.txt ghi '$d' nhung khong thay terminal64.exe o do. Dung ban MT5 chinh." -ForegroundColor Yellow }
    return $null
}
function Find-MT5([switch]$MoPhong) {
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs") |
             Where-Object { $_ -and (Test-Path $_) }
    $terminals = foreach ($r in $roots) {
        Get-ChildItem -Path $r -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "terminal64.exe" } | Where-Object { Test-Path $_ }
    }
    $mp = Get-MoPhongDir
    if (-not $terminals -and -not $mp) { throw "Khong tim thay terminal64.exe. MT5 da duoc cai chua?" }
    if ($mp) { $terminals = @($terminals | Where-Object { (Split-Path -Parent $_) -ine $mp }) }   # ban chinh: khong phai ban mo phong
    $terminal = $terminals | Where-Object { $_ -match "(?i)exness" } | Select-Object -First 1
    if (-not $terminal) { $terminal = $terminals | Select-Object -First 1 }
    if ($MoPhong -and $mp) { $terminal = Join-Path $mp "terminal64.exe" }
    if (-not $terminal) { throw "Khong tim thay ban MT5 chinh (ngoai ban mo phong trong mt5-mophong.txt)." }
    $installDir = Split-Path -Parent $terminal
    $editor = Join-Path $installDir "metaeditor64.exe"
    if (-not (Test-Path $editor)) { throw "Khong thay metaeditor64.exe trong $installDir" }

    $base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (-not (Test-Path $base)) { throw "Khong thay $base. Hay mo MT5 it nhat 1 lan." }
    $dataDir = $null
    foreach ($d in Get-ChildItem $base -Directory) {
        $origin = Join-Path $d.FullName "origin.txt"
        if ((Test-Path $origin) -and ((Get-Content $origin -Raw).Trim().TrimEnd('\') -ieq $installDir.TrimEnd('\'))) {
            $dataDir = $d.FullName; break
        }
    }
    if (-not $dataDir) {
        # Du phong: thu muc du lieu co MQL5\Experts duoc dung gan nhat
        $dataDir = Get-ChildItem $base -Directory |
                   Where-Object { Test-Path (Join-Path $_.FullName "MQL5\Experts") } |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $dataDir) { throw "Khong tim thay thu muc du lieu MT5 (MQL5\Experts)." }

    [pscustomobject]@{
        Terminal    = $terminal
        InstallDir  = $installDir
        Editor      = $editor
        DataDir     = $dataDir
        Experts     = Join-Path $dataDir "MQL5\Experts"
        CommonFiles = Join-Path $base "Common\Files"
    }
}

# Chep file .mq5 vao MQL5\Experts va compile. Tra ve ket qua + log.
function Invoke-BotCompile($mt5, [string]$src) {
    $name   = [IO.Path]::GetFileNameWithoutExtension($src)
    $target = Join-Path $mt5.Experts "$name.mq5"
    $ex5    = Join-Path $mt5.Experts "$name.ex5"
    # Moi lan compile dung log RIENG; khong duoc xoa log dang duoc
    # MetaEditor / cua so VS Code khac giu mo.
    $log    = Join-Path $env:TEMP ("{0}-compile-{1}-{2}.log" -f $name, $PID, [guid]::NewGuid().ToString("N"))
    $bak    = "$ex5.bak"
    # Khoa theo duong dan .ex5: watcher va nut cap nhat khong duoc
    # copy module / di chuyen .ex5 cung luc vao mot terminal.
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $key = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($ex5.ToLowerInvariant()))).Replace("-", "")
    } finally { $hash.Dispose() }
    $mutex = [System.Threading.Mutex]::new($false, ("Local\TrendBotCompile_" + $key))
    $locked = $false
    try {
        try { $locked = $mutex.WaitOne(120000) }
        catch [System.Threading.AbandonedMutexException] { $locked = $true }
        if (-not $locked) { throw "Dang co MetaEditor/VS Code khac compile vao $ex5 qua 120 giay; hay dung task trung roi thu lai." }
    Copy-Item $src $target -Force
    # Cac module .mqh (thu muc TrendBot/ canh file .mq5) phai nam canh file .mq5 trong MQL5\Experts
    $modSrc = Join-Path (Split-Path $src -Parent) "TrendBot"
    if (Test-Path $modSrc) {
        $modDst = Join-Path $mt5.Experts "TrendBot"
        if (-not (Test-Path $modDst)) { New-Item -ItemType Directory -Path $modDst | Out-Null }
        Copy-Item (Join-Path $modSrc "*.mqh") $modDst -Force
    }
    # Cai dat san cho tung chien thuat (cai-dat/*.set) -> MQL5\Presets: trong MT5, tab Inputs bam Load de chon
    $setSrc = Join-Path (Split-Path $src -Parent) "cai-dat"
    if (Test-Path $setSrc) {
        $setDst = Join-Path $mt5.DataDir "MQL5\Presets"
        if (-not (Test-Path $setDst)) { New-Item -ItemType Directory -Path $setDst | Out-Null }
        Copy-Item (Join-Path $setSrc "*.set") $setDst -Force
        # Bo cai dat cu (doi ten truoc 5.10.1, hoac da bo): xoa khoi MT5 de danh sach Load khong lan bo cu
        foreach ($old in @("1-Donchian-H4-khuyen-dung", "2-Donchian-M30-khoiLuong", "3-RSI-M15", "4-ORB-M5-phien-My",
                           "5-Luot-song-1trieu-THU-NGHIEM", "6-Donchian-H4-nhoi3", "7-Bao-ve-lenh-tay", "8-Demo-1trieu-tinHieuM5",
                           "9-Demo-1trieu-H4-slM5", "10-Tu-bam-H4-nhoi3",
                           # Bo da bo (11/2026): chi giu 04 va 05 cho von 1 trieu
                           "01-Chuan-Donchian-H4", "02-Tu-bam-lenh-H4", "03-Bao-ve-lenh-tay", "TN1-Donchian-H4-nhoi-3-lop",
                           "TN2-Donchian-M30-khoi-luong", "TN3-RSI-M15", "TN4-ORB-M5-phien-My", "TN5-Wyckoff-M15-von-nho",
                           "TN6-Demo-1-trieu-M5", "TN7-Demo-1-trieu-H4-SL-M5",
                           # Gop thanh 1 bo "01-TrendBot-tat-ca-trong-1-M15" (11/2026)
                           "04-Bao-ve-lenh-tay-von-1-trieu", "05-Tu-vao-lenh-von-1-trieu-THU-NGHIEM", "06-Nhoi-chot-gop-von-1-trieu-THU-NGHIEM", "07-Nhoi-nhanh-von-1-trieu-THU-NGHIEM", "08-Fib-Volume-Profile-H1-THU-NGHIEM", "09-Phan-ky-RSI-CVD-H1-THU-NGHIEM", "10-Big-Trades-H1-THU-NGHIEM", "11-Hop-phan-phoi-H1-THU-NGHIEM", "12-Danh-luoi-H1-THU-NGHIEM", "13-Phong-cach-Scalp-M5-THU-NGHIEM", "14-Phong-cach-Swing-H4-THU-NGHIEM", "15-Khoa-lenh-Hedging-H4-THU-NGHIEM", "16-Gio-cao-diem-London-NewYork-H1-THU-NGHIEM", "17-Dao-roi-nho-lon-giu-H1-THU-NGHIEM", "18-Nhoi-khi-thang-kim-tu-thap-H4-THU-NGHIEM", "19-Order-block-5-phan-ung-H1-THU-NGHIEM", "20-Pha-vo-that-du-3-dieu-H4-THU-NGHIEM", "21-FVG-nen-xac-nhan-H1-THU-NGHIEM", "22-Dow-thuy-trieu-con-song-H4-THU-NGHIEM", "23-VWAP-3-cap-dai-M15-THU-NGHIEM", "24-Vung-Key-Volume-H1-THU-NGHIEM", "25-Ba-cau-hoi-don-gian-H4-THU-NGHIEM", "26-Quet-tin-lon-M15-THU-NGHIEM", "27-Bon-ky-thuat-danh-H4-THU-NGHIEM", "28-Wyckoff-Spring-day-du-H1-THU-NGHIEM", "29-Premium-Discount-D1-H4-THU-NGHIEM", "30-Chuoi-phan-tich-H1-THU-NGHIEM", "31-Tu-dong-1-chart-THU-NGHIEM", "32-Theo-tinh-huong-H1-THU-NGHIEM", "33-Theo-tinh-huong-von-770-nghin-M15-THU-NGHIEM")) {
            $f = Join-Path $setDst "$old.set"
            if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
        }
    }
    # Khong bao gio Remove-Item mot file log chung cua lan compile khac.
    # Giu ban .ex5 cu: compile loi thi tra lai, bot tren chart khong bi mat file chay
    if (Test-Path $ex5) { Move-Item $ex5 $bak -Force }
    try {
        Start-Process -FilePath $mt5.Editor -ArgumentList "/compile:`"$target`"", "/log:`"$log`"" -Wait -ErrorAction Stop
    } catch {
        # Khong de mat .ex5 dang dung neu MetaEditor khong khoi dong duoc.
        if (Test-Path $bak) { Move-Item $bak $ex5 -Force }
        throw
    }
    # Doi MetaEditor nha file log; khong dung ket qua rong / log cu.
    $lines = @()
    $logReadable = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            if (Test-Path $log) {
                $lines = @(Get-Content -LiteralPath $log -ErrorAction Stop)
                if ($lines.Count -gt 0) { $logReadable = $true; break }
            }
        } catch [System.IO.IOException] { }
        Start-Sleep -Milliseconds 200
    }
    $errors = @($lines | Where-Object { $_ -match "(?i):\s*error\s" })
    if (-not $logReadable) {
        $errors += "MetaEditor khong tao/khong doc duoc log compile moi: $log"
    }
    $ok = (Test-Path $ex5) -and $logReadable -and ($errors.Count -eq 0)
    if ($ok) { if (Test-Path $bak) { Remove-Item $bak -Force } }
    elseif (Test-Path $bak) {
        Move-Item $bak $ex5 -Force
        Write-Host "Compile loi: da tra lai ban .ex5 cu, bot tren chart van chay ban cu." -ForegroundColor Yellow
    }
    [pscustomobject]@{
        Name     = $name
        Ok       = $ok
        Errors   = $errors
        Warnings = @($lines | Where-Object { $_ -match "(?i):\s*warning\s" })
        Summary  = ($lines | Where-Object { $_ -match "(?i)result|errors" } | Select-Object -Last 1)
        Log      = $log
    }
    } finally {
        if ($locked) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

# Doc gia tri mac dinh cua MOI tham so input tu file .mq5
function Get-BotInputs([string]$src) {
    $enumMap = @{ STRAT_EMA_PULLBACK = 0; STRAT_DONCHIAN = 1;
                  PERIOD_M1 = 1; PERIOD_M5 = 5; PERIOD_M15 = 15; PERIOD_M30 = 30;
                  PERIOD_H1 = 16385; PERIOD_H4 = 16388; PERIOD_D1 = 16408; PERIOD_W1 = 32769 }
    $defaults = [ordered]@{}
    $strings  = New-Object System.Collections.Generic.HashSet[string]
    foreach ($line in Get-Content $src) {
        if ($line -match '^\s*input\s+(?!group\b)(\w+)\s+(\w+)\s*=\s*(.+?);') {
            $type = $Matches[1]; $name = $Matches[2]; $val = $Matches[3].Trim()
            if ($type -eq "string") { [void]$strings.Add($name); $val = $val.Trim('"') }
            elseif ($enumMap.ContainsKey($val)) { $val = $enumMap[$val] }
            elseif ($val -cmatch '^[A-Z][A-Z0-9_]*$') { throw "Chua biet gia tri so cua '$val' (tham so $name). Them vao enumMap trong MT5Common.ps1." }
            $defaults[$name] = [string]$val
        }
    }
    [pscustomobject]@{ Defaults = $defaults; Strings = $strings }
}

# Tao file .ini cho Tester. LUON ghi day du moi tham so, vi MT5 giu gia tri cua lan chay truoc
# cho tham so nao bi bo sot.
function New-TesterIni($mt5, $inputs, [hashtable]$overrides, [string]$iniPath, [hashtable]$opt) {
    $vals = [ordered]@{}
    foreach ($k in $inputs.Defaults.Keys) { $vals[$k] = $inputs.Defaults[$k] }
    if ($overrides) {
        foreach ($k in $overrides.Keys) {
            if (-not $vals.Contains($k)) { throw "Tham so '$k' khong co trong bot." }
            $vals[$k] = [string]$overrides[$k]
        }
    }
    $lines = foreach ($k in $vals.Keys) {
        $v = $vals[$k]
        if ($opt.OptKey -and $k -eq $opt.OptKey) { "$k=$($opt.OptFrom)||$($opt.OptFrom)||1||$($opt.OptTo)||Y" }   # tham so chay song song
        elseif ($inputs.Strings.Contains($k)) { "$k=$v" } else { "$k=$v||$v||1||$v||N" }
    }
    @"
[Tester]
Expert=$BotName.ex5
Symbol=$($opt.Symbol)
Period=H1
Model=$(if ($null -ne $opt.Model) { $opt.Model } else { 4 })
ExecutionMode=100
Optimization=$(if ($opt.OptKey) { 1 } else { 0 })
OptimizationCriterion=0
FromDate=$($opt.From)
ToDate=$($opt.To)
ForwardMode=0
Deposit=$($opt.Deposit)
Currency=USD
Leverage=$($opt.Leverage)
Visual=0
Report=$($opt.Report)
ReplaceReport=1
ShutdownTerminal=$(if ($opt.Shutdown) { 1 } else { 0 })
[TesterInputs]
$($lines -join "`r`n")
"@ | Set-Content -Path $iniPath -Encoding Unicode
}

# Tai lich su funding rate Binance USDT-M Futures (mien phi, khong can tai khoan) vao Common\Files,
# de bot doc khi backtest. Chi tai phan con thieu. Loi mang thi giu file cu va bao canh bao.
function Update-FundingData($mt5, [string[]]$pairs, [int]$years = 7) {
    foreach ($pair in $pairs) {
        $file = Join-Path $mt5.CommonFiles "funding_$pair.csv"
        $rows = New-Object System.Collections.Generic.List[string]
        $start = [DateTimeOffset]::UtcNow.AddYears(-$years).ToUnixTimeMilliseconds()
        if (Test-Path $file) {
            Get-Content $file | Where-Object { $_ -match '^\d+,-?[\d.eE-]+$' } | ForEach-Object { $rows.Add($_) }
            if ($rows.Count -gt 0) { $start = [long]($rows[$rows.Count - 1].Split(',')[0]) + 1 }
        }
        $added = 0
        try {
            while ($true) {
                $url  = "https://fapi.binance.com/fapi/v1/fundingRate?symbol=$pair&startTime=$start&limit=1000"
                # PowerShell 5.1: @(Invoke-RestMethod ...) boc ca mang JSON thanh 1 phan tu, phai gan vao bien truoc
                $resp = Invoke-RestMethod -Uri $url -TimeoutSec 30
                $data = @($resp)
                if ($data.Count -eq 0) { break }
                foreach ($d in $data) {
                    $rows.Add(("{0},{1}" -f $d.fundingTime, $d.fundingRate)); $added++
                }
                $start = [long]$data[$data.Count - 1].fundingTime + 1
                if ($data.Count -lt 1000) { break }
            }
        } catch {
            Write-Host "  Khong tai duoc funding $pair ($($_.Exception.Message)). Dung du lieu cu neu co." -ForegroundColor Yellow
        }
        if ($rows.Count -gt 0) {
            (@("time_ms,rate") + $rows) | Set-Content -Path $file -Encoding ASCII
            Write-Host "  Funding $pair : $($rows.Count) moc (moi tai $added)." -ForegroundColor Green
        }
    }
}

# Tai Fear & Greed Index (alternative.me, tu 2018) va luot xem Wikipedia theo ngay (tu 2015-07)
# vao Common\Files: fng.csv, wiki_Bitcoin.csv, wiki_Ethereum.csv. Moi dong "unix_giay,gia_tri".
function Update-SentimentData($mt5, [string[]]$articles = @("Bitcoin", "Ethereum")) {
    $ua = @{ "User-Agent" = "BTC-EA-backtest/1.0" }
    try {
        $fng = Invoke-RestMethod -Uri "https://api.alternative.me/fng/?limit=0" -TimeoutSec 60 -Headers $ua
        $rows = @($fng.data | Sort-Object { [long]$_.timestamp } | ForEach-Object { "{0},{1}" -f $_.timestamp, $_.value })
        if ($rows.Count -gt 0) {
            (@("time,value") + $rows) | Set-Content -Path (Join-Path $mt5.CommonFiles "fng.csv") -Encoding ASCII
            Write-Host "  Fear & Greed: $($rows.Count) ngay." -ForegroundColor Green
        }
    } catch {
        Write-Host "  Khong tai duoc Fear & Greed ($($_.Exception.Message)). Dung file cu neu co." -ForegroundColor Yellow
    }
    $end = (Get-Date).ToUniversalTime().ToString("yyyyMMdd")
    foreach ($a in $articles) {
        try {
            $url = "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/en.wikipedia/all-access/user/$a/daily/20150701/$end"
            $res = Invoke-RestMethod -Uri $url -TimeoutSec 60 -Headers $ua
            $rows = @($res.items | ForEach-Object {
                $d = [DateTime]::ParseExact($_.timestamp.Substring(0, 8), "yyyyMMdd", $null)
                "{0},{1}" -f ([DateTimeOffset]::new($d, [TimeSpan]::Zero)).ToUnixTimeSeconds(), $_.views
            })
            if ($rows.Count -gt 0) {
                (@("time,value") + $rows) | Set-Content -Path (Join-Path $mt5.CommonFiles "wiki_$a.csv") -Encoding ASCII
                Write-Host "  Wikipedia $a : $($rows.Count) ngay." -ForegroundColor Green
            }
        } catch {
            Write-Host "  Khong tai duoc luot xem Wikipedia $a ($($_.Exception.Message)). Dung file cu neu co." -ForegroundColor Yellow
        }
    }
}

# Dong MT5 (hoi truoc). Tra ve $false neu nguoi dung khong dong y.
function Stop-MT5($mt5) {
    $running = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $mt5.Terminal }
    if (-not $running) { return $true }
    Write-Host "CANH BAO: MT5 dang mo. Dong MT5 se DUNG moi bot dang chay tren no (ke ca tai khoan that)." -ForegroundColor Yellow
    Write-Host "Neu dang chay bot tren tai khoan that, nen backtest bang mot ban MT5 cai rieng." -ForegroundColor Yellow
    if ($env:TRENDBOT_DONGMT5) { $ans = $env:TRENDBOT_DONGMT5; Write-Host "Tra loi tu giao dien (dong MT5): $ans" }
    else { $ans = Read-Host "Dong MT5 ngay de chay backtest? (y/n)" }
    if ($ans -ne "y") { Write-Host "Khong dong MT5 (chua cho phep dong)." -ForegroundColor Yellow }
    if ($ans -ne "y") { return $false }
    $running | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 5
    Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $mt5.Terminal } | Stop-Process -Force
    return $true
}
