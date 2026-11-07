# GuiNhatKy.ps1 - Gui nhat ky tai khoan that cho Claude doi chieu (nut 4 trong VS Code)
# Chep 3 file bot ghi trong Common\Files vao ket-qua\thuc-te\ roi day len GitHub (repo rieng tu cua ban):
#   TrendBot_nhatky.csv  : moi giao dich (bot, lenh tay, nap, rut) + cac canh bao ky luat
#   TrendBot_tongket.csv : tong ket moi ngay
#   TrendBot_truotgia.csv: truot gia that cua bot (so voi backtest)
$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ProjectDir "MT5Common.ps1")
try { $mt5 = Find-MT5 } catch { Write-Host "LOI: $_" -ForegroundColor Red; exit 1 }

$dst = Join-Path $ProjectDir "ket-qua\thuc-te"
if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
$names = @("TrendBot_nhatky.csv", "TrendBot_tongket.csv", "TrendBot_truotgia.csv")
$copied = @()
foreach ($n in $names) {
    $src = Join-Path $mt5.CommonFiles $n
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $dst $n) -Force
        $lines = @(Get-Content $src).Count
        Write-Host "  $n : $lines dong" -ForegroundColor Green
        $copied += "ket-qua/thuc-te/$n"
    } else { Write-Host "  Chua co $n (bot chua chay tren tai khoan that / demo, hoac chua co giao dich)." -ForegroundColor Yellow }
}
if ($copied.Count -eq 0) { Write-Host "Khong co gi de gui." -ForegroundColor Yellow; exit 0 }

Write-Host ""
Write-Host "LUU Y QUYEN RIENG TU. Cac file nay chua thong tin tai chinh cua CA TAI KHOAN, khong chi cua bot:" -ForegroundColor Yellow
Write-Host "  - moi lenh (ca lenh ban vao tay, moi ma), lot, gia, lai/lo" -ForegroundColor Yellow
Write-Host "  - moi lan NAP / RUT tien va so tien" -ForegroundColor Yellow
Write-Host "  - SO DU tai khoan sau moi giao dich, tong ket lai/lo moi ngay" -ForegroundColor Yellow
Write-Host "  (KHONG co mat khau, so tai khoan hay ten dang nhap.)" -ForegroundColor Yellow
Write-Host "Neu bam y, chung se nam trong lich su repo GitHub cua ban (repo phai de RIENG TU - Private)." -ForegroundColor Yellow
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
