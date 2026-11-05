# Chay.ps1 - Diem vao duy nhat cho cac nut trong VS Code (Terminal > Run Task).
# Moi lan bam: tu lay code moi nhat tu GitHub (git pull), roi moi lam viec duoc chon.
#   -Viec sosanh           : so sanh 7 cau hinh, che do nhanh
#   -Viec sosanh-chinhxac  : so sanh 7 cau hinh, tick that (cham)
#   -Viec capnhat          : compile ban moi vao MT5
#   -Viec theodoi          : compile + tu compile lai moi khi luu file (chay khi mo VS Code, khong git pull)
#   -Viec backtest         : backtest 1 lan voi cai dat mac dinh
param([ValidateSet('sosanh', 'sosanh-chinhxac', 'capnhat', 'theodoi', 'backtest')][string]$Viec = 'sosanh')
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1) Lay code moi (khong bat buoc: loi mang hay chua cai git thi van chay ban dang co)
# "theodoi" tu chay khi mo VS Code nen KHONG tu lay code: chi compile code dang co tren may.
if ($Viec -eq 'theodoi') { }
elseif ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $ProjectDir ".git"))) {
    Write-Host "Dang lay code moi tu GitHub..." -ForegroundColor Cyan
    $out = & git -C $ProjectDir pull --ff-only 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "  $($out | Select-Object -Last 1)" -ForegroundColor Green }
    else {
        Write-Host "  Khong lay duoc code moi, se chay ban dang co tren may:" -ForegroundColor Yellow
        $out | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    }
} else {
    Write-Host "Khong thay git, bo qua buoc lay code moi (hay bam Sync trong VS Code)." -ForegroundColor Yellow
}

# 2) Chay viec duoc chon trong mot tien trinh moi, de dung dung ban script vua tai ve
$job = switch ($Viec) {
    'sosanh'          { @('ChayThuNghiem.ps1') }
    'sosanh-chinhxac' { @('ChayThuNghiem.ps1', '-ChinhXac') }
    'capnhat'         { @('DongBo.ps1') }
    'theodoi'         { @('DongBo.ps1', '-Watch') }
    'backtest'        { @('CaiDatBot.ps1') }
}
$script = Join-Path $ProjectDir $job[0]
$rest   = @($job | Select-Object -Skip 1)
& powershell -NoProfile -ExecutionPolicy Bypass -File $script @rest
exit $LASTEXITCODE
