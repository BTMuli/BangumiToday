[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RuntimeDirectory)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'playback_inference_assets.psm1') -Force
$lock = Get-PlaybackInferenceLock
$root = (Resolve-Path -LiteralPath $RuntimeDirectory).Path.TrimEnd('\', '/')
if ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Inference runtime root must not be a link'
}
$lockPath = Join-Path $PSScriptRoot '../windows/playback/inference/dependencies.lock.json'
if ((Get-FileHash -LiteralPath (Join-Path $root 'manifest.json') -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash) {
    throw 'Prepared manifest differs from the source dependency lock'
}
$noticePath = Join-Path $PSScriptRoot '../windows/playback/inference/THIRD_PARTY_NOTICES.txt'
if ((Get-FileHash -LiteralPath (Join-Path $root 'THIRD_PARTY_NOTICES.txt') -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $noticePath -Algorithm SHA256).Hash) {
    throw 'Prepared notices differ from the source notices'
}
# Windows components that must not be bundled. Everything an inference DLL
# imports has to be either one of these or a file this package ships.
$systemDlls = @(
    'advapi32.dll', 'avrt.dll', 'bcrypt.dll', 'combase.dll', 'comctl32.dll', 'comdlg32.dll',
    'crypt32.dll', 'd2d1.dll', 'd3d11.dll', 'd3d12.dll', 'dbghelp.dll', 'dcomp.dll',
    'dwmapi.dll', 'dwrite.dll', 'dxgi.dll', 'gdi32.dll', 'imm32.dll', 'kernel32.dll',
    'mf.dll', 'mfplat.dll', 'mfreadwrite.dll', 'msimg32.dll', 'ntdll.dll', 'ole32.dll',
    'oleacc.dll', 'oleaut32.dll', 'opengl32.dll', 'powrprof.dll', 'propsys.dll', 'psapi.dll',
    'rpcrt4.dll', 'secur32.dll', 'setupapi.dll', 'shell32.dll', 'shlwapi.dll', 'urlmon.dll',
    'user32.dll', 'userenv.dll', 'usp10.dll', 'uxtheme.dll', 'version.dll', 'windowscodecs.dll',
    'winhttp.dll', 'wininet.dll', 'winmm.dll', 'winspool.drv', 'wintrust.dll', 'ws2_32.dll',
    'wtsapi32.dll')
$allowed = @{ 'manifest.json' = $true; 'THIRD_PARTY_NOTICES.txt' = $true }
$shipped = @{}
foreach ($file in $lock.files) {
    $path = Get-InferenceTarget -Root $root -RelativePath $file.path
    Assert-InferenceFile -Path $path -Bytes $file.bytes -Sha256 $file.sha256
    $allowed[$file.path] = $true
    $shipped[[IO.Path]::GetFileName($file.path).ToLowerInvariant()] = $true
}
foreach ($entry in Get-ChildItem -LiteralPath $root -Recurse -Force) {
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked inference asset: $($entry.FullName)" }
    if ($entry.PSIsContainer) { continue }
    $relative = $entry.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    if (-not $allowed.ContainsKey($relative)) { throw "Unexpected inference prerequisite: $relative" }
}
# Dependency closure: every import of every shipped binary must resolve to a
# Windows component or to a file inside this prepared runtime.
foreach ($file in $lock.files) {
    if (-not $file.path.EndsWith('.dll', [StringComparison]::OrdinalIgnoreCase)) { continue }
    $path = Get-InferenceTarget -Root $root -RelativePath $file.path
    $imports = @(Get-InferencePeImports -Path $path)
    if (@($imports | Where-Object { $_ -match 'nvcuda|cudart|nvinfer|nvonnx|aji' }).Count -gt 0) {
        throw "Unexpected NVIDIA/aji dependency in the DML prerequisites: $($file.path)"
    }
    foreach ($import in $imports) {
        if ($import.StartsWith('api-ms-win-', [StringComparison]::OrdinalIgnoreCase) -or
            $import -eq 'ucrtbase.dll' -or $systemDlls -contains $import) {
            continue
        }
        if (-not $shipped.ContainsKey($import)) {
            throw "Unresolved dependency of $($file.path): $import"
        }
    }
    Write-Output "$($file.path) PE x64 imports: $($imports -join ', ')"
}
Write-Output 'Verified inference assets, x64 binaries and dependency closure.'
