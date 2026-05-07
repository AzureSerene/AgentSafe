Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw '请以管理员身份运行 uninstall.ps1。'
    }
}

function Get-ModeConfig {
    param([string]$ModePath)

    if (-not (Test-Path -LiteralPath $ModePath)) {
        throw "找不到模式文件: $ModePath"
    }

    return Get-Content -LiteralPath $ModePath -Raw | ConvertFrom-Json
}

function Remove-DesktopShortcut {
    param([string]$ShortcutName)

    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath ("$ShortcutName.lnk")
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force
        Write-Host "已删除快捷方式：$shortcutPath"
    }
}

function Remove-LauncherCredential {
    cmdkey /delete:localhost | Out-Null
    cmdkey /delete:$env:COMPUTERNAME | Out-Null
    Write-Host '已尝试清理凭据管理器中的相关项。'
}

function Unhide-LocalUser {
    param([string]$UserName)

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
    if (Test-Path -LiteralPath $registryPath) {
        Remove-ItemProperty -Path $registryPath -Name $UserName -ErrorAction SilentlyContinue
        Write-Host "已清理隐藏账户注册表项：$UserName"
    }
}

function Remove-RestrictedUser {
    param([string]$UserName)

    $user = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    if ($user) {
        Remove-LocalUser -Name $UserName
        Write-Host "已删除本地账户：$UserName"
    }
}

Assert-Administrator

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$modePath = Join-Path $projectRoot 'modes\xiaolv.json'
$config = Get-ModeConfig -ModePath $modePath
$passwordFile = Join-Path $projectRoot ("." + $config.username + '.password.txt')

Remove-DesktopShortcut -ShortcutName $config.terminal_title
Remove-LauncherCredential
Unhide-LocalUser -UserName $config.username
Remove-RestrictedUser -UserName $config.username

if (Test-Path -LiteralPath $passwordFile) {
    Remove-Item -LiteralPath $passwordFile -Force
    Write-Host '已删除本地密码缓存文件。'
}

Write-Host ''
Write-Host '小绿已清理完成。'
Write-Host '如需彻底恢复 ACL，请手动检查 E:\安全终端 和主用户目录上的权限项。'
