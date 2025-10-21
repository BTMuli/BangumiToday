# 读取.env文件
$file = Get-Content .env
# 读取版本号和签名证书的密码
$signPwd = $file | Select-String -Pattern "SIGN_SECRET" | ForEach-Object { $_ -replace "SIGN_SECRET=", "" }
$version = $file | Select-String -Pattern "MSIX_VERSION" | ForEach-Object { $_ -replace "MSIX_VERSION=", "" }
# 在已安装的 msix 应用中查找 BangumiToday
$package = Get-AppxPackage -Name "BangumiToday"
# 如果已安装 BangumiToday 获取版本号
if ($package)
{
    $versionGet = $package.Version
}
else
{
    $versionGet = 0
}
# 如果版本号与 .env 文件中的版本号一致，不构建
if ($version -eq $versionGet)
{
    Write-Output "已安装应用版本与设置版本一致：$version，是否抬升版本号？(y/n)"
    $check = Read-Host
    if ($check -eq "y")
    {
        Write-Output "请输入新的版本号（格式：x.x.x.x）"
        $versionNew = Read-Host
        $version = $versionNew
        (Get-Content .env) -replace "MSIX_VERSION=$versionGet" , "MSIX_VERSION=$version" | Set-Content .env
        Write-Output "版本号已更新为：$version"
    }
    else
    {
        exit
    }
}
# 如果版本号低于已安装的版本号，不构建
$vers = $version -split "\."
$versGet = $versionGet -split "\."
for ($i = 0; $i -lt 4; $i++)
{
    $veri = [int]$vers[$i]
    $verGeti = [int]$versGet[$i]
    if ($veri -gt $verGeti)
    {
        break
    }
    if ($veri -lt $verGeti)
    {
        Write-Output "已安装应用版本高于设置版本：$version，不执行构建"
        exit
    }
}
Write-Output "开始构建应用版本：$version，本地版本: $versionGet"
# 构建命令
$command = "dart run msix:create --version=$version -p $signPwd"
Write-Output "dart run msix:create --version=$version"
Invoke-Expression $command
# 输入 y 自动安装 换行输出
$install = Read-Host "`n是否安装应用？(y/n)"
if ($install -eq "y")
{
    Write-Output "开始安装应用"
    $command = "Add-AppxPackage -Path .\BangumiToday.msix"
    Invoke-Expression $command
    Write-Output "成功安装BangumiToday v$version"
}
else
{
    Write-Output "已构建应用，未安装"
}
