# GuiNhatKy.ps1 - Gui nhat ky tai khoan that cho Claude doi chieu (nut 4 trong VS Code)
# Chep 3 file bot ghi trong Common\Files vao ket-qua\thuc-te\ roi day len GitHub (repo rieng tu cua ban):
#   TrendBot_nhatky.csv  : moi giao dich (bot, lenh tay, nap, rut) + cac canh bao ky luat
#   TrendBot_tongket.csv : tong ket moi ngay
#   TrendBot_truotgia.csv: truot gia that cua bot (so voi backtest)
# Gioi han du lieu (v5.10.12). Mac dinh gui BAN RUT GON, du de doi chieu voi backtest:
#   - nhatky : bo cac dong NAP / RUT, bo cot SoDuHienTai, che so tien trong dong canh bao (CANHBAO)
#   - tongket: bo cot Nap, Rut, SoDu, Equity
#   - truotgia: giu nguyen (chi co gia vao / truot gia cua lenh bot)
# Muon gui ban day du (vd Claude can doi chieu nap/rut): chay  GuiNhatKy.ps1 -DayDu  hoac dat bien TRENDBOT_NHATKY_DAYDU=y.
param([switch]$DayDu)
$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ProjectDir "MT5Common.ps1")
try { $mt5 = Find-MT5 } catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }

$dst = Join-Path $ProjectDir "ket-qua\thuc-te"
if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
if ($env:TRENDBOT_NHATKY_DAYDU -match '^(y|yes|c|co|1)$') { $DayDu = $true }

# Doc file bot dang ghi (MT5 giu handle FILE_SHARE_READ)
function Read-CsvLines([string]$path) {
    $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
    try { $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::Default); $t = $sr.ReadToEnd() } finally { $fs.Close() }
    return @($t -split "`r?`n" | Where-Object { $_ -ne "" })
}
# Ban rut gon: bo dong co cot Loai thuoc $dropKinds, xoa noi dung cac cot $blankCols, che so trong GhiChu dong CANHBAO
function Get-Reduced([string[]]$lines, [string[]]$dropKinds, [string[]]$blankCols) {
    if ($lines.Count -eq 0) { return @() }
    $head = $lines[0].Split(',')
    $iLoai = [Array]::IndexOf($head, "Loai"); $iNote = [Array]::IndexOf($head, "GhiChu")
    $blank = @($blankCols | ForEach-Object { [Array]::IndexOf($head, $_) } | Where-Object { $_ -ge 0 })
    $out = New-Object Collections.Generic.List[string]
    $out.Add($lines[0])
    foreach ($l in ($lines | Select-Object -Skip 1)) {
        $c = $l.Split(',')
        if ($iLoai -ge 0 -and $iLoai -lt $c.Count -and $dropKinds -contains $c[$iLoai]) { continue }
        foreach ($i in $blank) { if ($i -lt $c.Count) { $c[$i] = "" } }
        if ($iLoai -ge 0 -and $iNote -ge 0 -and $iNote -lt $c.Count -and $c[$iLoai] -eq "CANHBAO") { $c[$iNote] = $c[$iNote] -replace '\d[\d.]*', '#' }
        $out.Add($c -join ',')
    }
    return $out.ToArray()
}
$rules = @{
    "TrendBot_nhatky.csv"  = @{ Drop = @("NAP", "RUT"); Blank = @("SoDuHienTai") }
    "TrendBot_tongket.csv" = @{ Drop = @(); Blank = @("Nap", "Rut", "SoDu", "Equity") }
}

$names = @("TrendBot_nhatky.csv", "TrendBot_tongket.csv", "TrendBot_truotgia.csv")
$copied = @()
Write-Host $(if ($DayDu) { "Che do: DAY DU (ca nap/rut va so du)." } else { "Che do: RUT GON (bo nap/rut, so du). Ban day du: -DayDu." }) -ForegroundColor Cyan
foreach ($n in $names) {
    $src = Join-Path $mt5.CommonFiles $n
    if (Test-Path $src) {
        $all = Read-CsvLines $src
        $keep = if (-not $DayDu -and $rules.ContainsKey($n)) { Get-Reduced $all $rules[$n].Drop $rules[$n].Blank } else { $all }
        [IO.File]::WriteAllLines((Join-Path $dst $n), [string[]]$keep, [Text.Encoding]::Default)
        $lines = $keep.Count
        Write-Host "  $n : $lines dong" -ForegroundColor Green
        $copied += "ket-qua/thuc-te/$n"
    } else { Write-Host "  Chua co $n (bot chua chay tren tai khoan that / demo, hoac chua co giao dich)." -ForegroundColor Yellow }
}
if ($copied.Count -eq 0) { Write-Host "Khong co gi de gui." -ForegroundColor Yellow; exit 0 }

Write-Host ""
Write-Host "LUU Y QUYEN RIENG TU. Cac file nay chua thong tin tai chinh cua CA TAI KHOAN, khong chi cua bot:" -ForegroundColor Yellow
Write-Host "  - moi lenh (ca lenh ban vao tay, moi ma), lot, gia, lai/lo; tong ket lai/lo moi ngay" -ForegroundColor Yellow
if ($DayDu) {
    Write-Host "  - moi lan NAP / RUT tien va so tien" -ForegroundColor Yellow
    Write-Host "  - SO DU tai khoan sau moi giao dich" -ForegroundColor Yellow
} else { Write-Host "  (Ban rut gon: DA BO nap/rut, so du, equity.)" -ForegroundColor Yellow }
Write-Host "  (KHONG co mat khau, so tai khoan hay ten dang nhap.)" -ForegroundColor Yellow
Write-Host "Neu bam y, chung se nam trong LICH SU repo GitHub cua ban (xoa file sau van con trong lich su git)." -ForegroundColor Yellow
Write-Host "Repo phai de RIENG TU (Private), chi minh ban co quyen; khong them nguoi cong tac, khong fork cong khai." -ForegroundColor Yellow
Write-Host "Muon xem truoc: mo thu muc $dst" -ForegroundColor Yellow
if ($env:TRENDBOT_GUINHATKY) { $ans = $env:TRENDBOT_GUINHATKY; Write-Host "Tra loi tu giao dien (day len GitHub): $ans" }
else { $ans = Read-Host "Day len GitHub? (y = co, phim khac = chi mo thu muc de ban tu gui zip)" }
if ($ans -notmatch '^(y|yes|c|co)$') { Invoke-Item $dst; exit 0 }

& git -C $ProjectDir fetch -q 2>&1 | Out-Null
$ahead = [int](& git -C $ProjectDir rev-list --count "@{u}..HEAD" 2>$null)
if ($ahead -gt 0) { Write-Host "May ban co $ahead commit chua day len GitHub, script khong tu day. Hay gui zip." -ForegroundColor Yellow; Invoke-Item $dst; exit 1 }
$out = & git -C $ProjectDir add -f -- $copied 2>&1
if ($LASTEXITCODE -eq 0) { $out = & git -C $ProjectDir commit -q -m "Nhat ky tai khoan that $(Get-Date -Format 'yyyyMMdd-HHmm')" -- $copied 2>&1 }
if ($LASTEXITCODE -eq 0) { $out = & git -C $ProjectDir pull -q --rebase --autostash 2>&1 }
if ($LASTEXITCODE -eq 0) { $out = & git -C $ProjectDir push -q 2>&1 }
if ($LASTEXITCODE -eq 0) { Write-Host "==> Da gui. Nhan Claude 'da gui nhat ky' de doi chieu." -ForegroundColor Green }
else { Write-Host "Khong day duoc, hay gui zip thu muc vua mo:" -ForegroundColor Yellow; $out | ForEach-Object { Write-Host "    $_" }; Invoke-Item $dst }
