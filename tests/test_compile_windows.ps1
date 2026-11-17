# tests/test_compile_windows.ps1
# Run with Windows PowerShell 5.1. Fake MetaEditor, NOT a native MQL5 compile.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
foreach ($file in @("MT5Common.ps1", "DongBo.ps1", "Chay.ps1")) {
    $tokens = $null; $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $root $file), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell parse error in $file : $($parseErrors | Out-String)"
    }
}
. (Join-Path $root "MT5Common.ps1")
$testDir = Join-Path $env:TEMP ("TrendBot-compile-smoke-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory $testDir -Force | Out-Null
try {
    $srcDir = Join-Path $testDir "src"
    $experts = Join-Path $testDir "experts"
    $dataDir = Join-Path $testDir "data"
    foreach ($d in @($srcDir, $experts, $dataDir)) { New-Item -ItemType Directory $d -Force | Out-Null }
    $source = Join-Path $srcDir "BTC_EMA_Pullback_v2.mq5"
    Set-Content -Path $source -Value "void OnTick() {}" -Encoding ASCII
    $fakeExe = Join-Path $testDir "fake-metaeditor.exe"
    $cs = @'
using System;
using System.IO;
public class FakeMetaEditor {
  public static int Main(string[] args) {
    string compile = "", log = "";
    foreach (string a in args) {
      if (a.StartsWith("/compile:", StringComparison.OrdinalIgnoreCase))
        compile = a.Substring(9).Trim('"');
      if (a.StartsWith("/log:", StringComparison.OrdinalIgnoreCase))
        log = a.Substring(5).Trim('"');
    }
    if (compile.Length == 0 || log.Length == 0) return 3;
    File.WriteAllText(Path.ChangeExtension(compile, ".ex5"), "mock-compiled");
    File.WriteAllText(log, "Mock MetaEditor\r\nResult: 0 errors, 0 warnings\r\n");
    return 0;
  }
}
'@
    Add-Type -TypeDefinition $cs -OutputAssembly $fakeExe -OutputType ConsoleApplication
    $mt5 = [pscustomobject]@{
        Experts = $experts
        DataDir = $dataDir
        Editor = $fakeExe
    }
    # Reproduce user's exact failure: old shared compile.log held open with FileShare.None.
    $legacy = Join-Path $env:TEMP "BTC_EMA_Pullback_v2-compile.log"
    $legacyLock = [System.IO.File]::Open($legacy, [System.IO.FileMode]::OpenOrCreate,
                           [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        $r = Invoke-BotCompile $mt5 $source
        if (-not $r.Ok) { throw "Mock compile failed: $($r.Errors -join '; ')" }
        if ($r.Log -eq $legacy -or -not (Test-Path $r.Log)) { throw "Compile log was not unique" }
        if ((Get-Content (Join-Path $experts "BTC_EMA_Pullback_v2.ex5") -Raw).Trim() -ne "mock-compiled") {
            throw "Compiled EX5 was not written"
        }
    } finally { $legacyLock.Dispose() }
    # A failed Editor launch MUST restore the previous functioning EX5.
    $mt5.Editor = Join-Path $testDir "absent-editor.exe"
    $caught = $false
    try { $null = Invoke-BotCompile $mt5 $source }
    catch { $caught = $true }
    if (-not $caught) { throw "Expected fake MetaEditor launch to fail" }
    if ((Get-Content (Join-Path $experts "BTC_EMA_Pullback_v2.ex5") -Raw).Trim() -ne "mock-compiled") {
        throw "Previous EX5 was lost after failed MetaEditor launch"
    }
    Write-Host "OK: Windows PowerShell parses, shared log locked, unique log works, EX5 rollback works." -ForegroundColor Green
} finally {
    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
}
