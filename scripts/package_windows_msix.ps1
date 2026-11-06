[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputName,

    [Parameter(Mandatory = $true)]
    [string]$CertificatePath,

    [Parameter(Mandatory = $true)]
    [string]$CertificatePassword,

    [string]$Version
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$bundlePath = Join-Path $projectRoot 'build/windows/x64/runner/Release'
if (-not (Test-Path -LiteralPath $bundlePath -PathType Container)) {
    throw "Windows release bundle not found: $bundlePath"
}

$installerDataDir = 'Msix.AppInstaller.Data'
$installerFile = 'MSIXAppInstallerData.xml'
$installerSource = Join-Path $projectRoot "windows/packaging/msix/$installerDataDir/$installerFile"
$installerDataPath = Join-Path $bundlePath $installerDataDir
$stagedInstaller = Join-Path $installerDataPath $installerFile
$msixArguments = @(
    'run', 'msix:create', '--build-windows', 'false',
    '--output-name', $OutputName,
    '--certificate-path', $CertificatePath,
    '--certificate-password', $CertificatePassword
)
if ($Version) {
    $msixArguments += @('--version', $Version)
}

Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Path $installerDataPath -Force | Out-Null
    Copy-Item -LiteralPath $installerSource -Destination $stagedInstaller -Force
    & dart @msixArguments
    if ($LASTEXITCODE -ne 0) {
        throw "MSIX packaging failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
    if (Test-Path -LiteralPath $stagedInstaller -PathType Leaf) {
        Remove-Item -LiteralPath $stagedInstaller -Force
    }
    if ((Test-Path -LiteralPath $installerDataPath -PathType Container) -and
        -not (Get-ChildItem -LiteralPath $installerDataPath -Force)) {
        [IO.Directory]::Delete($installerDataPath)
    }
}
