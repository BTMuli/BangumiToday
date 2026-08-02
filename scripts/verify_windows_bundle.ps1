[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BundlePath,

    [string]$EngineRuntimePath
)

$ErrorActionPreference = 'Stop'

function Resolve-ExistingDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Description does not exist: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/')
}

function Get-RelativeFileMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $result = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File) {
        $relativePath = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
        $result[$relativePath.Replace('\', '/')] = $file.FullName
    }
    return $result
}

$bundleRoot = Resolve-ExistingDirectory -Path $BundlePath -Description 'Windows bundle'
if (-not (Test-Path -LiteralPath (Join-Path $bundleRoot 'bangumi_today.exe') -PathType Leaf)) {
    throw "BangumiToday executable is missing from the Windows bundle: $bundleRoot"
}

$engineRoot = Join-Path $bundleRoot 'bt_download'
$engineRoot = Resolve-ExistingDirectory -Path $engineRoot -Description 'Bundled bt_download runtime'

$requiredFiles = @(
    'bt_download.exe',
    'torrent-rasterbar.dll',
    'libcrypto-3-x64.dll',
    'libssl-3-x64.dll',
    'msvcp140.dll',
    'vcruntime140.dll',
    'sbom.spdx.json',
    'THIRD_PARTY_NOTICES.txt',
    'licenses/boost.txt',
    'licenses/libtorrent.txt',
    'licenses/nlohmann-json.txt',
    'licenses/openssl.txt'
)

$missingFiles = @(
    foreach ($relativePath in $requiredFiles) {
        $candidate = Join-Path $engineRoot $relativePath
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $relativePath
        }
    }
)
if ($missingFiles.Count -gt 0) {
    throw "Bundled bt_download runtime is incomplete. Missing: $($missingFiles -join ', ')"
}

$sbomPath = Join-Path $engineRoot 'sbom.spdx.json'
$sbom = Get-Content -LiteralPath $sbomPath -Raw | ConvertFrom-Json
if ($sbom.spdxVersion -ne 'SPDX-2.3') {
    throw "Unexpected bt_download SBOM version: $($sbom.spdxVersion)"
}

if ($EngineRuntimePath) {
    $sourceRoot = Resolve-ExistingDirectory -Path $EngineRuntimePath -Description 'Source bt_download runtime'
    $sourceFiles = Get-RelativeFileMap -Root $sourceRoot
    $bundledFiles = Get-RelativeFileMap -Root $engineRoot

    $sourceOnly = @($sourceFiles.Keys | Where-Object { -not $bundledFiles.ContainsKey($_) } | Sort-Object)
    $bundleOnly = @($bundledFiles.Keys | Where-Object { -not $sourceFiles.ContainsKey($_) } | Sort-Object)
    if ($sourceOnly.Count -gt 0 -or $bundleOnly.Count -gt 0) {
        $details = @()
        if ($sourceOnly.Count -gt 0) {
            $details += "missing from bundle: $($sourceOnly -join ', ')"
        }
        if ($bundleOnly.Count -gt 0) {
            $details += "unexpected in bundle: $($bundleOnly -join ', ')"
        }
        throw "Bundled bt_download file set differs from the source runtime ($($details -join '; '))"
    }

    $hashMismatches = @(
        foreach ($relativePath in $sourceFiles.Keys) {
            $sourceHash = (Get-FileHash -LiteralPath $sourceFiles[$relativePath] -Algorithm SHA256).Hash
            $bundleHash = (Get-FileHash -LiteralPath $bundledFiles[$relativePath] -Algorithm SHA256).Hash
            if ($sourceHash -ne $bundleHash) {
                $relativePath
            }
        }
    )
    if ($hashMismatches.Count -gt 0) {
        throw "Bundled bt_download files failed SHA-256 comparison: $($hashMismatches -join ', ')"
    }
}

$fileCount = (Get-ChildItem -LiteralPath $engineRoot -Recurse -File).Count
Write-Output "Verified bt_download runtime in '$engineRoot' ($fileCount files, SPDX-2.3 SBOM)."
