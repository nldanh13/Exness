# TaiThanhLy.ps1 - Tai lich su open interest (OI) va ty le long/short BTCUSDT tu kho file mien phi cua Binance
# (data.binance.vision, co tu 12/2021), gop thanh nen 1 gio, nen zip vao du-lieu\ roi day len GitHub
# de Claude thu xem OI / ban do thanh ly uoc tinh co giup chien luoc C khong.
# Khong can MT5, khong can Python. Lan dau mat vai phut; lan sau chi tai them ngay moi (file tam o %TEMP%).
$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Add-Type -AssemblyName System.Net.Http, System.IO.Compression, System.IO.Compression.FileSystem
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Cache = Join-Path $env:TEMP "TrendBot-oi"
if (-not (Test-Path $Cache)) { New-Item -ItemType Directory -Path $Cache | Out-Null }
$Base  = "https://data.binance.vision/data/futures/um/daily/metrics/BTCUSDT/BTCUSDT-metrics-{0}.zip"
$start = Get-Date "2021-12-01"; $end = (Get-Date).Date.AddDays(-2)
$days = @(); for ($d = $start; $d -le $end; $d = $d.AddDays(1)) { $days += $d.ToString("yyyy-MM-dd") }
$need = @($days | Where-Object { -not (Test-Path (Join-Path $Cache "$_.zip")) -and -not (Test-Path (Join-Path $Cache "$_.thieu")) })
Write-Host "Can $($days.Count) ngay du lieu, da co san $($days.Count - $need.Count), se tai $($need.Count)." -ForegroundColor Cyan

$http = New-Object System.Net.Http.HttpClient
$http.Timeout = [TimeSpan]::FromSeconds(60)
$batch = 16; $done = 0; $fail = 0
for ($k = 0; $k -lt $need.Count; $k += $batch) {
    $grp = @($need[$k..([Math]::Min($k + $batch, $need.Count) - 1)])
    $tasks = @($grp | ForEach-Object { $http.GetAsync(($Base -f $_)) })
    try { [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$tasks) } catch { }
    for ($i = 0; $i -lt $grp.Count; $i++) {
        $t = $tasks[$i]
        if ($t.Status -eq 'RanToCompletion' -and $t.Result.IsSuccessStatusCode) {
            [IO.File]::WriteAllBytes((Join-Path $Cache "$($grp[$i]).zip"), $t.Result.Content.ReadAsByteArrayAsync().Result); $done++
        } elseif ($t.Status -eq 'RanToCompletion' -and [int]$t.Result.StatusCode -eq 404) {
            Set-Content (Join-Path $Cache "$($grp[$i]).thieu") "404"   # Binance khong co ngay nay
        } else { $fail++ }
    }
    Write-Host ("  [dot {0}/{1}] da tai {2} ngay" -f ([Math]::Floor($k / $batch) + 1), [Math]::Ceiling($need.Count / $batch), $done)
}
if ($fail -gt 0) { Write-Host "  $fail ngay tai loi (mang). Bam lai lan nua se tai tiep phan con thieu." -ForegroundColor Yellow }
if (-not $need.Count -and -not (Get-ChildItem $Cache -Filter *.zip)) { Write-Host "LOI: khong tai duoc gi tu data.binance.vision." -ForegroundColor Red; exit 1 }

# Gop 5 phut -> 1 gio: giu so lieu cuoi gio, taker = trung binh trong gio
Write-Host "Dang gop thanh nen 1 gio..." -ForegroundColor Cyan
$epoch = [DateTime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
$hours = New-Object 'System.Collections.Generic.SortedDictionary[long,object]'
foreach ($day in $days) {
    $zf = Join-Path $Cache "$day.zip"
    if (-not (Test-Path $zf)) { continue }
    try { $z = [IO.Compression.ZipFile]::OpenRead($zf) } catch { Remove-Item $zf -Force; continue }   # file hong: lan sau tai lai
    try {
        $sr = New-Object IO.StreamReader($z.Entries[0].Open())
        while ($null -ne ($line = $sr.ReadLine())) {
            if ($line.Length -lt 19 -or -not [char]::IsDigit($line[0])) { continue }
            $p = $line.Split(',')
            $ts = [long]([DateTime]::SpecifyKind([DateTime]::ParseExact($p[0].Substring(0, 19), "yyyy-MM-dd HH:mm:ss", $null), 'Utc') - $epoch).TotalSeconds
            $hk = [long]([Math]::Floor($ts / 3600)) * 3600
            $h = $null
            if (-not $hours.TryGetValue($hk, [ref]$h)) { $h = @{ T = -1; V = $null; S = 0.0; N = 0 }; $hours[$hk] = $h }
            if ($ts -gt $h.T) { $h.T = $ts; $h.V = $p }
            $tk = 0.0
            if ($p.Count -gt 7 -and [double]::TryParse($p[7], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$tk)) { $h.S += $tk; $h.N++ }
        }
        $sr.Close()
    } finally { $z.Dispose() }
}
$csv = Join-Path $Cache "binance_oi_BTCUSDT_1h.csv"
$sw = New-Object IO.StreamWriter($csv, $false, [Text.Encoding]::ASCII)
$sw.WriteLine("time,oi_btc,oi_usd,toptrader_acc_ls,toptrader_pos_ls,acc_ls,taker_buy_sell_mean")
foreach ($kv in $hours.GetEnumerator()) {
    $v = $kv.Value.V; $tm = if ($kv.Value.N) { ($kv.Value.S / $kv.Value.N).ToString([Globalization.CultureInfo]::InvariantCulture) } else { "" }
    $sw.WriteLine(("{0},{1},{2},{3},{4},{5},{6}" -f $kv.Key, $v[2], $v[3], $v[4], $v[5], $v[6], $tm))
}
$sw.Close()
Write-Host "  $($hours.Count) gio du lieu." -ForegroundColor Green

# Xem Binance con file lich su thanh ly that khong (thuong la khong)
$probe = foreach ($kind in @(@("um", "BTCUSDT"), @("cm", "BTCUSD_PERP"))) {
    foreach ($d in @("2021-07-01", "2022-06-01", "2023-06-01", "2024-06-01", "2025-06-01")) {
        $u = "https://data.binance.vision/data/futures/$($kind[0])/daily/liquidationSnapshot/$($kind[1])/$($kind[1])-liquidationSnapshot-$d.zip"
        $r = try { [int]$http.SendAsync((New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Head, $u))).Result.StatusCode } catch { -1 }
        "$($kind[0]) $d $r"
    }
}
$probe | Set-Content (Join-Path $Cache "thanh-ly-that.txt") -Encoding ASCII
Write-Host "  Lich su thanh ly that tren Binance: $(@($probe | Where-Object { $_ -match ' 200$' }).Count)/10 ngay mau co file."

$dir = Join-Path $ProjectDir "du-lieu"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$out = Join-Path $dir "oi-BTCUSDT-1h.zip"
if (Test-Path $out) { Remove-Item $out -Force }
Compress-Archive -Path $csv, (Join-Path $Cache "thanh-ly-that.txt") -DestinationPath $out
$rel = "du-lieu/oi-BTCUSDT-1h.zip"
Write-Host "  Da luu $rel ($([Math]::Round((Get-Item $out).Length / 1MB, 1)) MB)." -ForegroundColor Green

# Day len GitHub: chi commit dung file nay, khong day ho commit khac cua ban
$ErrorActionPreference = "Continue"   # git ghi thong bao ra stderr; khong coi do la loi
& git -C $ProjectDir fetch -q 2>&1 | Out-Null
$ahead = [int](& git -C $ProjectDir rev-list --count "@{u}..HEAD" 2>$null)
if ($ahead -gt 0) { Write-Host "May ban co $ahead commit chua day len GitHub, script khong tu day. Hay gui file $out cho Claude." -ForegroundColor Yellow; exit 1 }
$o = & git -C $ProjectDir add -f -- $rel 2>&1
if ($LASTEXITCODE -eq 0) { $o = & git -C $ProjectDir commit -q -m "Du lieu open interest BTCUSDT $(Get-Date -Format 'yyyyMMdd-HHmm')" -- $rel 2>&1 }
if ($LASTEXITCODE -eq 0) { $o = & git -C $ProjectDir pull -q --rebase --autostash 2>&1 }
if ($LASTEXITCODE -eq 0) { $o = & git -C $ProjectDir push -q 2>&1 }
if ($LASTEXITCODE -eq 0) { Write-Host "==> Da day du lieu len GitHub. Nhan Claude 'xong roi' de chay thu." -ForegroundColor Green; exit 0 }
Write-Host "Khong day duoc len GitHub, hay gui file $out cho Claude:" -ForegroundColor Yellow; $o | ForEach-Object { Write-Host "    $_" }
exit 1
