# GiaoDien.ps1 - Mo giao dien dieu khien bot tren trinh duyet (http://localhost:8765).
#   Bam dup GiaoDien.cmd, hoac VS Code: Terminal > Run Task > "0. Mo giao dien".
# Giao dien lam dung cac viec cua nut 1/2/3 (goi Chay.ps1), nhung hoi truoc bang nut bam
# (lay code moi? dong MT5?), hien tien trinh + nhat ky, va xem bang ket qua trong ket-qua/.
# Chi nghe tren localhost: may khac trong mang khong vao duoc.
param([int]$Port = 8765, [switch]$KhongMoTrinhDuyet)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WebDir     = Join-Path $ProjectDir "giao-dien"
$ResDir     = Join-Path $ProjectDir "ket-qua"
$WorkDir    = Join-Path $env:TEMP "TrendBot-giaodien"
if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir | Out-Null }
$LogFile    = Join-Path $WorkDir "nhat-ky.txt"
$ErrFile    = Join-Path $WorkDir "loi.txt"

# Viec dang chay (chi 1 viec mot luc, giong cac nut VS Code)
$script:Job = $null          # @{ Proc; Viec; Nhom; Start; End; ExitCode }
$script:Git = @{ Checked = $null; Ok = $false; Behind = 0; Commits = @(); Branch = ""; Error = "" }

function Get-GitStatus([switch]$Fetch) {
    $g = @{ Checked = (Get-Date).ToString("HH:mm:ss"); Ok = $false; Behind = 0; Commits = @(); Branch = ""; Error = "" }
    if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Test-Path (Join-Path $ProjectDir ".git"))) {
        $g.Error = "Khong thay git tren may."; return $g
    }
    $g.Branch = (& git -C $ProjectDir rev-parse --abbrev-ref HEAD 2>$null) -join ""
    if ($Fetch) {
        $null = & git -C $ProjectDir fetch -q origin 2>&1
        if ($LASTEXITCODE -ne 0) { $g.Error = "Khong ket noi duoc GitHub." }
    }
    $new = @(& git -C $ProjectDir log --oneline "HEAD..@{u}" 2>$null)
    $g.Behind  = $new.Count
    $g.Commits = @($new | Select-Object -First 15)
    $g.Ok = ($g.Error -eq "")
    return $g
}

function Test-MT5Running {
    return [bool](Get-Process terminal64 -ErrorAction SilentlyContinue)
}

# Trang thai bot dang chay that / demo: moi chart co bot ghi Common\Files\TrendBot_trangthai_<chart>.txt moi 10 giay
# (TrendBot/Status.mqh, tu v5.4). File cu hon 2 phut = bot da tat hoac MT5 da dong.
function Get-BotStatus {
    $dir = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
    if (-not (Test-Path $dir)) { return @() }
    $now = Get-Date
    return @(Get-ChildItem $dir -File -Filter "TrendBot_trangthai_*.txt" -ErrorAction SilentlyContinue |
        Where-Object { ($now - $_.LastWriteTime).TotalSeconds -lt 120 } | ForEach-Object {
            $o = @{ CapNhat = [int]($now - $_.LastWriteTime).TotalSeconds }
            foreach ($line in @(Get-Content $_.FullName -ErrorAction SilentlyContinue)) {
                $i = $line.IndexOf('=')
                if ($i -gt 0) { $o[$line.Substring(0, $i)] = $line.Substring($i + 1) }
            }
            $o
        })
}

function Read-Shared([string]$path) {
    # Doc file dang duoc tien trinh khac ghi (FileShare.ReadWrite)
    if (-not (Test-Path $path)) { return "" }
    try {
        $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
        try { $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::Default); return $sr.ReadToEnd() } finally { $fs.Close() }
    } catch { return "" }
}

function Read-ListFile([string]$name) {
    $p = Join-Path $ProjectDir $name
    if (-not (Test-Path $p)) { return @() }
    return @(Get-Content $p | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
}

function Get-JobState {
    $j = $script:Job
    if (-not $j) { return @{ Running = $false } }
    $running = -not $j.Proc.HasExited
    if (-not $running -and -not $j.End) {
        $j.End = Get-Date; try { $j.ExitCode = $j.Proc.ExitCode } catch { $j.ExitCode = -1 }
        # Du phong: ma thoat Chay.ps1 tu ghi vao nhat ky (dong "[giao-dien] ma-thoat=N")
        $m = [regex]::Match((Read-Shared $LogFile), '\[giao-dien\] ma-thoat=(-?\d+)')
        if ($m.Success) { $j.ExitCode = [int]$m.Groups[1].Value } elseif ($null -eq $j.ExitCode) { $j.ExitCode = -1 }
        $script:Git = Get-GitStatus   # viec vua xong co the da lay code moi: cap nhat lai "Phien ban bot"
    }
    $endT = if ($j.End) { $j.End } else { Get-Date }
    return @{ Running = $running; Viec = $j.Viec; Nhom = $j.Nhom; Start = $j.Start.ToString("yyyy-MM-dd HH:mm:ss");
              Seconds = [int]($endT - $j.Start).TotalSeconds; ExitCode = $j.ExitCode; Stopped = [bool]$j.Stopped }
}

function Start-BotJob($body) {
    if ($script:Job -and -not $script:Job.Proc.HasExited) { throw "Dang co viec chay. Dung viec do truoc." }
    $viec = [string]$body.viec
    if ($viec -notin @('sosanh', 'sosanh-chinhxac', 'capnhat', 'backtest', 'nhatky', 'thanhly')) { throw "Viec khong hop le: $viec" }
    $nhom = [string]$body.nhom
    if (-not $nhom) { $nhom = 'file' }
    if ($nhom -notin @('file', 'h4', 'luotsong', 'von1tr', 'tatca')) { throw "Nhom khong hop le: $nhom" }
    # Tra loi san cho cac cau hoi y/n cua script (Chay.ps1 va Stop-MT5 doc 2 bien nay thay vi Read-Host)
    $env:TRENDBOT_LAYCODE = if ($body.layCodeMoi) { "y" } else { "n" }
    $env:TRENDBOT_DONGMT5 = if ($body.dongMT5) { "y" } else { "n" }
    $env:TRENDBOT_GUINHATKY = if ($body.guiNhatKy) { "y" } else { "n" }
    $env:TRENDBOT_GIAODIEN = "1"
    foreach ($f in @($LogFile, $ErrFile)) { if (Test-Path $f) { Remove-Item $f -Force } }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $ProjectDir 'Chay.ps1')`"", '-Viec', $viec, '-Nhom', $nhom)
    $sp = @{ FilePath = "powershell"; ArgumentList = $argList; WorkingDirectory = $ProjectDir; PassThru = $true
             RedirectStandardOutput = $LogFile; RedirectStandardError = $ErrFile }
    if ($IsWindows -ne $false) { $sp.WindowStyle = "Hidden" }   # PowerShell 5.1 khong co $IsWindows (= $null)
    $p = Start-Process @sp
    # Giu handle ngay: Windows PowerShell chi doc duoc ExitCode khi da lay Handle truoc luc tien trinh ket thuc
    $null = $p.Handle
    Remove-Item Env:\TRENDBOT_LAYCODE, Env:\TRENDBOT_DONGMT5, Env:\TRENDBOT_GUINHATKY, Env:\TRENDBOT_GIAODIEN -ErrorAction SilentlyContinue
    $script:Job = @{ Proc = $p; Viec = $viec; Nhom = $nhom; Start = Get-Date; End = $null; ExitCode = $null; Stopped = $false }
}

function Stop-BotJob {
    $j = $script:Job
    if (-not $j -or $j.Proc.HasExited) { return }
    # Dung ca cay tien trinh (Chay.ps1 -> ChayThuNghiem.ps1 -> MT5 tester)
    & taskkill /PID $j.Proc.Id /T /F 2>&1 | Out-Null
    $j.Stopped = $true
}

function Get-ResultFiles {
    if (-not (Test-Path $ResDir)) { return @() }
    $all = @(Get-ChildItem $ResDir -File -Filter "*.csv" | Where-Object { $_.Name -notlike "*-lenh.csv" } | Sort-Object Name -Descending)
    return @($all | ForEach-Object {
        $t = $_.Name -replace '\.csv$', '-lenh.csv'
        @{ Ten = $_.Name; Lenh = $(if (Test-Path (Join-Path $ResDir $t)) { $t } else { "" }); Sua = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm") }
    })
}

function Send-Bytes($ctx, [byte[]]$bytes, [string]$type, [int]$code = 200) {
    $res = $ctx.Response
    $res.StatusCode = $code
    $res.ContentType = $type
    $res.Headers.Add("Cache-Control", "no-store")
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.OutputStream.Close()
}
function Send-Json($ctx, $obj, [int]$code = 200) {
    $json = $obj | ConvertTo-Json -Depth 6 -Compress
    Send-Bytes $ctx ([Text.Encoding]::UTF8.GetBytes($json)) "application/json; charset=utf-8" $code
}
function Read-Body($ctx) {
    $sr = New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)
    $t = $sr.ReadToEnd()
    if ($t) { return ($t | ConvertFrom-Json) } else { return @{} }
}

$listener = New-Object Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
try { $listener.Start() } catch {
    Write-Host "Khong mo duoc cong $Port ($($_.Exception.Message)). Co the giao dien da mo san: vao $prefix" -ForegroundColor Yellow
    if (-not $KhongMoTrinhDuyet) { Start-Process $prefix }
    exit 1
}
Write-Host "Giao dien dang chay tai $prefix  (dong cua so nay de tat)" -ForegroundColor Green
$script:Git = Get-GitStatus -Fetch
if (-not $KhongMoTrinhDuyet) { Start-Process $prefix }

$types = @{ ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"; ".css" = "text/css; charset=utf-8"; ".svg" = "image/svg+xml" }
try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $path = $ctx.Request.Url.AbsolutePath
        $method = $ctx.Request.HttpMethod
        try {
            # Chan trang web khac goi API (chi chap nhan yeu cau tu chinh giao dien nay)
            $origin = $ctx.Request.Headers["Origin"]
            if ($method -eq "POST" -and $origin -and $origin.TrimEnd('/') -ne $prefix.TrimEnd('/')) { Send-Json $ctx @{ Loi = "Khong cho phep." } 403; continue }

            if ($path -eq "/api/trangthai") {
                $offset = 0; [void][int]::TryParse($ctx.Request.QueryString["tu"], [ref]$offset)
                $log = Read-Shared $LogFile
                $err = Read-Shared $ErrFile
                if ($offset -gt $log.Length) { $offset = 0 }
                Send-Json $ctx @{
                    Viec = (Get-JobState); Log = $log.Substring($offset); LogLen = $log.Length; Loi = $err;
                    Git = $script:Git; MT5Mo = (Test-MT5Running); Bot = @(Get-BotStatus);
                    ChiChay = @(Read-ListFile "chi-chay.txt"); ChinhXac = @(Read-ListFile "chinh-xac.txt");
                    KetQua = @(Get-ResultFiles)
                }
            }
            elseif ($path -eq "/api/kiemtragit" -and $method -eq "POST") {
                $script:Git = Get-GitStatus -Fetch
                Send-Json $ctx $script:Git
            }
            elseif ($path -eq "/api/chay" -and $method -eq "POST") {
                Start-BotJob (Read-Body $ctx)
                Send-Json $ctx @{ Ok = $true }
            }
            elseif ($path -eq "/api/dung" -and $method -eq "POST") {
                Stop-BotJob
                Send-Json $ctx @{ Ok = $true }
            }
            elseif ($path -like "/ket-qua/*") {
                $name = [Uri]::UnescapeDataString($path.Substring(9))
                $f = Join-Path $ResDir $name
                if ($name -match '^[\w.+-]+\.csv$' -and (Test-Path $f)) { Send-Bytes $ctx ([IO.File]::ReadAllBytes($f)) "text/csv; charset=utf-8" }
                else { Send-Json $ctx @{ Loi = "Khong thay file." } 404 }
            }
            else {
                $rel = if ($path -eq "/") { "index.html" } else { $path.TrimStart('/') }
                $f = Join-Path $WebDir $rel
                $ext = [IO.Path]::GetExtension($f).ToLower()
                if ($rel -match '^[\w.-]+$' -and $types.ContainsKey($ext) -and (Test-Path $f)) { Send-Bytes $ctx ([IO.File]::ReadAllBytes($f)) $types[$ext] }
                else { Send-Json $ctx @{ Loi = "Khong thay trang." } 404 }
            }
        } catch {
            try { Send-Json $ctx @{ Loi = "$($_.Exception.Message)" } 400 } catch { }
        }
    }
} finally {
    $listener.Stop()
}
