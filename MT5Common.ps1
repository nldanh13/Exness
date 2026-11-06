# MT5Common.ps1 - Ham dung chung cho DongBo.ps1, CaiDatBot.ps1, ChayThuNghiem.ps1
# Khong chay truc tiep file nay.

$BotName = "BTC_EMA_Pullback_v2"

# Tim MT5: noi cai dat + thu muc du lieu (co buoc du phong neu origin.txt khong khop)
function Find-MT5 {
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs") |
             Where-Object { $_ -and (Test-Path $_) }
    $terminals = foreach ($r in $roots) {
        Get-ChildItem -Path $r -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "terminal64.exe" } | Where-Object { Test-Path $_ }
    }
    if (-not $terminals) { throw "Khong tim thay terminal64.exe. MT5 da duoc cai chua?" }
    $terminal = $terminals | Where-Object { $_ -match "(?i)exness" } | Select-Object -First 1
    if (-not $terminal) { $terminal = $terminals | Select-Object -First 1 }
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
    $log    = Join-Path $env:TEMP "$name-compile.log"
    $bak    = "$ex5.bak"
    Copy-Item $src $target -Force
    if (Test-Path $log) { Remove-Item $log -Force }
    # Giu ban .ex5 cu: compile loi thi tra lai, bot tren chart khong bi mat file chay
    if (Test-Path $ex5) { Move-Item $ex5 $bak -Force }
    Start-Process -FilePath $mt5.Editor -ArgumentList "/compile:`"$target`"", "/log:`"$log`"" -Wait
    $lines = if (Test-Path $log) { Get-Content $log } else { @() }
    $errors = @($lines | Where-Object { $_ -match "(?i):\s*error\s" })
    $ok = (Test-Path $ex5) -and ($errors.Count -eq 0)
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
        if ($inputs.Strings.Contains($k)) { "$k=$v" } else { "$k=$v||$v||1||$v||N" }
    }
    @"
[Tester]
Expert=$BotName.ex5
Symbol=$($opt.Symbol)
Period=H1
Model=$(if ($null -ne $opt.Model) { $opt.Model } else { 4 })
ExecutionMode=100
Optimization=0
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
            Get-Content $file | Where-Object { $_ -match '^\d+,' } | ForEach-Object { $rows.Add($_) }
            if ($rows.Count -gt 0) { $start = [long]($rows[$rows.Count - 1].Split(',')[0]) + 1 }
        }
        $added = 0
        try {
            while ($true) {
                $url  = "https://fapi.binance.com/fapi/v1/fundingRate?symbol=$pair&startTime=$start&limit=1000"
                $data = @(Invoke-RestMethod -Uri $url -TimeoutSec 30)
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

# Dong MT5 (hoi truoc). Tra ve $false neu nguoi dung khong dong y.
function Stop-MT5($mt5) {
    $running = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $mt5.Terminal }
    if (-not $running) { return $true }
    Write-Host "CANH BAO: MT5 dang mo. Dong MT5 se DUNG moi bot dang chay tren no (ke ca tai khoan that)." -ForegroundColor Yellow
    Write-Host "Neu dang chay bot tren tai khoan that, nen backtest bang mot ban MT5 cai rieng." -ForegroundColor Yellow
    $ans = Read-Host "Dong MT5 ngay de chay backtest? (y/n)"
    if ($ans -ne "y") { return $false }
    $running | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 5
    Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $mt5.Terminal } | Stop-Process -Force
    return $true
}
