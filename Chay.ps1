# Chay.ps1 - Diem vao duy nhat cho cac nut trong VS Code (Terminal > Run Task).
# Moi lan bam: kiem tra code moi tren GitHub, hoi ban truoc khi lay ve, roi moi lam viec duoc chon.
#   -Viec sosanh           : so sanh 7 cau hinh, che do nhanh
#   -Viec sosanh-chinhxac  : so sanh 7 cau hinh, tick that (cham)
#   -Viec capnhat          : compile ban moi vao MT5
#   -Viec theodoi          : compile + tu compile lai moi khi luu file (chay khi mo VS Code, khong git pull)
#   -Viec backtest         : backtest 1 lan voi cai dat mac dinh
param([ValidateSet('sosanh', 'sosanh-chinhxac', 'capnhat', 'theodoi', 'backtest')][string]$Viec = 'sosanh',
      [string]$Nhom = 'file')
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1) Lay code moi - CHI khi ban dong y. Moi nut deu compile lai bot vao MT5 (MT5 nap lai bot dang chay
#    tren bieu do khi file .ex5 doi), nen code moi tu GitHub phai duoc ban xem va bam "y" truoc.
# "theodoi" tu chay khi mo VS Code nen KHONG lay code: chi compile code dang co tren may.
if ($Viec -eq 'theodoi') { }
elseif ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $ProjectDir ".git"))) {
    Write-Host "Dang kiem tra code moi tren GitHub..." -ForegroundColor Cyan
    $null = & git -C $ProjectDir fetch -q origin 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Khong ket noi duoc GitHub, se chay ban dang co tren may." -ForegroundColor Yellow
    } else {
        $new = @(& git -C $ProjectDir log --oneline "HEAD..@{u}" 2>$null)
        if ($new.Count -eq 0) { Write-Host "  Da la ban moi nhat." -ForegroundColor Green }
        else {
            Write-Host "  Co $($new.Count) thay doi moi:" -ForegroundColor Yellow
            $new | Select-Object -First 15 | ForEach-Object { Write-Host "    $_" }
            Write-Host "  Neu MT5 nay dang chay bot tren TAI KHOAN THAT, hay go 'n' (hoac tat bot truoc)." -ForegroundColor Yellow
            # Giao dien (GiaoDien.ps1) tra loi san qua bien TRENDBOT_LAYCODE, khong hoi lai
            if ($env:TRENDBOT_LAYCODE) { $ans = $env:TRENDBOT_LAYCODE; Write-Host "  Tra loi tu giao dien: $ans" }
            else { $ans = Read-Host "  Lay ban moi va compile? (y = co, phim khac = giu ban cu)" }
            if ($ans -match '^(y|yes|c|co)$') {
                $out = & git -C $ProjectDir pull --ff-only 2>&1
                if ($LASTEXITCODE -eq 0) { Write-Host "  $($out | Select-Object -Last 1)" -ForegroundColor Green }
                else {
                    Write-Host "  Khong lay duoc code moi, se chay ban dang co tren may:" -ForegroundColor Yellow
                    $out | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
                }
            } else { Write-Host "  Giu ban dang co tren may." -ForegroundColor Cyan }
        }
    }
} else {
    Write-Host "Khong thay git, bo qua buoc lay code moi (hay bam Sync trong VS Code)." -ForegroundColor Yellow
}

# 2) Chay viec duoc chon trong mot tien trinh moi, de dung dung ban script vua tai ve
# @( ) bat buoc: switch tra ve mang 1 phan tu se bi "mo" thanh chuoi, va $job[0] chi con 1 ky tu
$job = @(switch ($Viec) {
    'sosanh'          { @('ChayThuNghiem.ps1', '-Nhom', ($Nhom -split ' ')[0]) }
    'sosanh-chinhxac' { @('ChayThuNghiem.ps1', '-ChinhXac') }
    'capnhat'         { @('DongBo.ps1') }
    'theodoi'         { @('DongBo.ps1', '-Watch') }
    'backtest'        { @('CaiDatBot.ps1') }
})
$script = Join-Path $ProjectDir $job[0]
$rest   = @($job | Select-Object -Skip 1)
& powershell -NoProfile -ExecutionPolicy Bypass -File $script @rest
exit $LASTEXITCODE
