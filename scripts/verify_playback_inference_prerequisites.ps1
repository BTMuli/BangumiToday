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
$allowed = @{ 'manifest.json' = $true; 'THIRD_PARTY_NOTICES.txt' = $true }
foreach ($file in $lock.files) {
    $path = Get-InferenceTarget -Root $root -RelativePath $file.path
    Assert-InferenceFile -Path $path -Bytes $file.bytes -Sha256 $file.sha256
    $allowed[$file.path] = $true
    if ($path.EndsWith('.dll', [StringComparison]::OrdinalIgnoreCase)) {
        $imports = @(Get-InferencePeImports -Path $path)
        if (@($imports | Where-Object { $_ -match 'nvcuda|cudart|nvinfer|nvonnx|aji' }).Count -gt 0) {
            throw "Unexpected NVIDIA/aji dependency in the DML prerequisites: $($file.path)"
        }
        Write-Output "$($file.path) PE x64 imports: $($imports -join ', ')"
    }
}
foreach ($entry in Get-ChildItem -LiteralPath $root -Recurse -Force) {
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked inference asset: $($entry.FullName)" }
    if ($entry.PSIsContainer) { continue }
    $relative = $entry.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    if (-not $allowed.ContainsKey($relative)) { throw "Unexpected inference prerequisite: $relative" }
}
Write-Output 'Verified P0 prerequisites. These are not a complete app runtime: the frame bridge, custom libmpv and app-local C++ runtime closure remain acceptance gates.'
