[CmdletBinding()]
param(
    [string]$EngineRuntimePath,

    [switch]$SkipEngineTests,

    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-DotEnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $line = Get-Content -LiteralPath $Path | Where-Object {
        $_ -match "^\s*$([regex]::Escape($Name))\s*="
    } | Select-Object -Last 1
    if (-not $line) {
        throw "Missing $Name in $Path"
    }

    $value = ($line -replace "^\s*$([regex]::Escape($Name))\s*=", '').Trim()
    if ($value.Length -ge 2 -and
        (($value.StartsWith('"') -and $value.EndsWith('"')) -or
         ($value.StartsWith("'") -and $value.EndsWith("'")))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    if (-not $value) {
        throw "$Name in $Path must not be empty"
    }
    return $value
}

function ConvertTo-MsixVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ($Value -notmatch '^\d+\.\d+\.\d+\.\d+$') {
        throw "Invalid MSIX version '$Value'. Expected x.x.x.x."
    }
    return [version]$Value
}

function Set-DotEnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $content = [IO.File]::ReadAllText($Path)
    $pattern = "(?m)^\s*$([regex]::Escape($Name))\s*=.*$"
    if (-not [regex]::IsMatch($content, $pattern)) {
        throw "Missing $Name in $Path"
    }
    $updated = [regex]::Replace($content, $pattern, "$Name=$Value")
    [IO.File]::WriteAllText(
        $Path,
        $updated,
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Write-Host $Description
    & $FilePath @Arguments | Out-Host
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$Description failed with exit code $exitCode"
    }
}

function Get-VisualStudioPath {
    $vsWherePath = Join-Path ${env:ProgramFiles(x86)} `
        'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vsWherePath -PathType Leaf)) {
        throw 'Visual Studio Installer (vswhere.exe) was not found.'
    }

    $installationPath = & $vsWherePath -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $installationPath) {
        throw 'Visual Studio with Desktop development with C++ was not found.'
    }
    return $installationPath.Trim()
}

function Initialize-MsvcEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VisualStudioPath
    )

    if (Get-Command cl.exe -ErrorAction SilentlyContinue) {
        return
    }

    $vcVarsPath = Join-Path $VisualStudioPath `
        'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path -LiteralPath $vcVarsPath -PathType Leaf)) {
        throw "MSVC environment script was not found: $vcVarsPath"
    }

    $commandLine = "call `"$vcVarsPath`" >nul && set"
    $environmentLines = & "$env:SystemRoot\System32\cmd.exe" `
        /d /s /c $commandLine
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to initialize the MSVC x64 environment.'
    }
    foreach ($line in $environmentLines) {
        if ($line -match '^([^=]+)=(.*)$') {
            Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
        }
    }
}

function Resolve-BuildTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$VisualStudioPath
    )

    $command = Get-Command "$Name.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidate = Join-Path $VisualStudioPath `
        "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\$Name.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return $candidate
    }
    throw "$Name.exe was not found on PATH or in Visual Studio."
}

function Resolve-VcpkgRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VisualStudioPath
    )

    $candidates = @(
        $env:VCPKG_ROOT,
        $env:VCPKG_INSTALLATION_ROOT,
        (Join-Path $VisualStudioPath 'VC\vcpkg')
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        $toolchainPath = Join-Path $candidate `
            'scripts\buildsystems\vcpkg.cmake'
        if (Test-Path -LiteralPath $toolchainPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'vcpkg was not found. Set VCPKG_ROOT to a complete vcpkg installation.'
}

function Build-DownloadEngine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EngineSourcePath,

        [Parameter(Mandatory = $true)]
        [string]$CMakePath,

        [Parameter(Mandatory = $true)]
        [string]$CTestPath,

        [Parameter(Mandatory = $true)]
        [bool]$RunTests
    )

    Push-Location $EngineSourcePath
    try {
        Invoke-NativeCommand -FilePath $CMakePath `
            -Arguments @('--preset', 'windows-x64-release') `
            -Description 'Configuring bt_download...'
        Invoke-NativeCommand -FilePath $CMakePath `
            -Arguments @('--build', '--preset', 'windows-x64-release') `
            -Description 'Building bt_download...'
        if ($RunTests) {
            Invoke-NativeCommand -FilePath $CTestPath `
                -Arguments @('--preset', 'windows-x64-release') `
                -Description 'Testing bt_download...'
        }
        Invoke-NativeCommand -FilePath $CMakePath `
            -Arguments @('--install', 'out/build/windows-x64-release') `
            -Description 'Installing the bt_download runtime...'
    }
    finally {
        Pop-Location
    }

    return (Resolve-Path -LiteralPath (Join-Path $EngineSourcePath `
        'out\install\windows-x64-release')).Path
}

$projectRoot = $PSScriptRoot
$envPath = Join-Path $projectRoot '.env'
$engineSourcePath = Join-Path $projectRoot 'repos\bt_download'
$bundlePath = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$verifyScriptPath = Join-Path $projectRoot `
    'scripts\verify_windows_bundle.ps1'
$msixPath = Join-Path $projectRoot 'BangumiToday.msix'

if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
    throw ".env does not exist: $envPath"
}

$signPassword = Get-DotEnvValue -Path $envPath -Name 'SIGN_SECRET'
$version = ConvertTo-MsixVersion (Get-DotEnvValue `
    -Path $envPath -Name 'MSIX_VERSION')

$package = Get-AppxPackage -Name 'BangumiToday'
$installedVersion = if ($package) {
    [version]$package.Version
} else {
    [version]'0.0.0.0'
}

# First check: MSIX_VERSION in .env must not be lower than the installed version
if ($version -lt $installedVersion) {
    Write-Output (
        "MSIX_VERSION $version is lower than the installed version $installedVersion. " +
        'Update MSIX_VERSION in .env before building.'
    )
    exit 1
}

if ($version -eq $installedVersion) {
    $answer = Read-Host `
        "Installed version is already $version. Bump the version? (y/n)"
    if ($answer -ne 'y') {
        Write-Output 'Build cancelled.'
        return
    }

    $newVersionValue = Read-Host 'Enter a new version (x.x.x.x)'
    $version = ConvertTo-MsixVersion $newVersionValue
    Set-DotEnvValue -Path $envPath -Name 'MSIX_VERSION' `
        -Value $version.ToString()
    Write-Output "Updated MSIX_VERSION to $version."
}

if ($version -lt $installedVersion) {
    throw "Installed version $installedVersion is newer than build version $version."
}

Push-Location $projectRoot
try {
    if ($EngineRuntimePath) {
        $resolvedEngineRuntimePath = (Resolve-Path `
            -LiteralPath $EngineRuntimePath).Path
        Write-Output `
            "Using the existing bt_download runtime: $resolvedEngineRuntimePath"
    }
    else {
        if (-not (Test-Path -LiteralPath `
                (Join-Path $engineSourcePath 'CMakeLists.txt') -PathType Leaf)) {
            throw "bt_download submodule is missing. Run: git submodule update --init --recursive"
        }

        $visualStudioPath = Get-VisualStudioPath
        Initialize-MsvcEnvironment -VisualStudioPath $visualStudioPath
        $cmakePath = Resolve-BuildTool -Name 'cmake' `
            -VisualStudioPath $visualStudioPath
        $ctestPath = Resolve-BuildTool -Name 'ctest' `
            -VisualStudioPath $visualStudioPath
        $env:VCPKG_ROOT = Resolve-VcpkgRoot `
            -VisualStudioPath $visualStudioPath

        $resolvedEngineRuntimePath = Build-DownloadEngine `
            -EngineSourcePath $engineSourcePath `
            -CMakePath $cmakePath `
            -CTestPath $ctestPath `
            -RunTests (-not $SkipEngineTests)
    }

    $env:BT_DOWNLOAD_RUNTIME_DIR = $resolvedEngineRuntimePath
    $flutterPath = (Get-Command flutter -ErrorAction Stop).Source
    Invoke-NativeCommand -FilePath $flutterPath `
        -Arguments @('build', 'windows', '--release') `
        -Description "Building BangumiToday $version with bt_download..."

    & $verifyScriptPath -BundlePath $bundlePath `
        -EngineRuntimePath $resolvedEngineRuntimePath

    $dartPath = (Get-Command dart -ErrorAction Stop).Source
    Invoke-NativeCommand -FilePath $dartPath `
        -Arguments @(
            'run',
            'msix:create',
            '--build-windows',
            'false',
            "--version=$version",
            '-p',
            $signPassword
        ) `
        -Description "Creating BangumiToday MSIX $version..."

    if (-not (Test-Path -LiteralPath $msixPath -PathType Leaf)) {
        throw "MSIX output was not created: $msixPath"
    }

    if (-not $SkipInstall) {
        $install = Read-Host 'Install the new package? (y/n)'
        if ($install -eq 'y') {
            Write-Output "Installing BangumiToday $version..."
            Add-AppxPackage -Path $msixPath
            Write-Output "Installed BangumiToday $version."
        }
    }
}
finally {
    Pop-Location
}
