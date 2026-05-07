Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw '请以管理员身份运行 setup.ps1。'
    }
}

function Get-ModeConfig {
    param([string]$ModePath)

    if (-not (Test-Path -LiteralPath $ModePath)) {
        throw "找不到模式文件: $ModePath"
    }

    return Get-Content -LiteralPath $ModePath -Raw | ConvertFrom-Json
}

function New-RandomPassword {
    Add-Type -AssemblyName System.Web
    return [System.Web.Security.Membership]::GeneratePassword(24, 4)
}

function Ensure-LocalUser {
    param(
        [string]$UserName,
        [string]$Password
    )

    $existingUser = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "账户已存在：$UserName"
        return $false
    }

    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    New-LocalUser -Name $UserName -Password $securePassword -AccountNeverExpires | Out-Null
    Write-Host "已创建账户：$UserName"
    return $true
}

function Hide-LocalUser {
    param([string]$UserName)

    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
    if (-not (Test-Path -LiteralPath $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }

    New-ItemProperty -Path $registryPath -Name $UserName -Value 0 -PropertyType DWord -Force | Out-Null
    Write-Host "已隐藏登录界面中的账户：$UserName"
}

function Ensure-Workspace {
    param([string]$Workspace)

    if (-not (Test-Path -LiteralPath $Workspace)) {
        New-Item -ItemType Directory -Path $Workspace -Force | Out-Null
        Write-Host "已创建工作区：$Workspace"
        return
    }

    Write-Host "工作区已存在：$Workspace"
}

function Ensure-UserProfileDirectories {
    param([string]$UserName)

    $profileRoot = Join-Path 'C:\Users' $UserName
    $directories = @(
        $profileRoot,
        (Join-Path $profileRoot 'AppData'),
        (Join-Path $profileRoot 'AppData\Local'),
        (Join-Path $profileRoot 'AppData\Roaming'),
        (Join-Path $profileRoot 'AppData\Local\Temp')
    )

    foreach ($directory in $directories) {
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
    }

    Write-Host "已准备受限用户目录：$profileRoot"
}

function Grant-FullControl {
    param(
        [string]$Path,
        [string]$Identity
    )

    $quotedPath = '"{0}"' -f $Path
    & icacls $quotedPath /grant "$Identity:(OI)(CI)F" /T /C | Out-Null
}

function Deny-ReadAccess {
    param(
        [string]$Path,
        [string]$Identity
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $quotedPath = '"{0}"' -f $Path
    & icacls $quotedPath /deny "$Identity:(OI)(CI)RX" /T /C | Out-Null
}

function Set-WorkspaceAcl {
    param(
        [string]$Workspace,
        [string]$UserName
    )

    Grant-FullControl -Path $Workspace -Identity $UserName
    Write-Host "已授予工作区写权限：$Workspace"
}

function Set-ProfileAcl {
    param([string]$UserName)

    $profileRoot = Join-Path 'C:\Users' $UserName
    Grant-FullControl -Path $profileRoot -Identity $UserName
    Write-Host "已授予用户目录写权限：$profileRoot"
}

function Set-DenyAcl {
    param(
        [array]$Paths,
        [string]$UserName
    )

    foreach ($path in $Paths) {
        Deny-ReadAccess -Path $path -Identity $UserName
        Write-Host "已限制访问：$path"
    }
}

function Save-LauncherCredential {
    param(
        [string]$UserName,
        [string]$Password
    )

    $computerTargets = @('localhost', $env:COMPUTERNAME)
    foreach ($target in $computerTargets) {
        cmdkey /generic:$target /user:$UserName /pass:$Password | Out-Null
    }

    Write-Host '已写入凭据管理器。'
}

function New-DesktopShortcut {
    param(
        [string]$ShortcutName,
        [string]$TargetScriptPath
    )

    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath ("$ShortcutName.lnk")
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = 'powershell.exe'
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$TargetScriptPath`""
    $shortcut.WorkingDirectory = Split-Path -Path $TargetScriptPath -Parent
    $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,44"
    $shortcut.Save()
    Write-Host "已创建桌面快捷方式：$shortcutPath"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$modePath = Join-Path $projectRoot 'modes\xiaolv.json'
$config = Get-ModeConfig -ModePath $modePath
$launchScriptPath = Join-Path $scriptRoot 'launch.ps1'
$passwordFile = Join-Path $projectRoot ("." + $config.username + '.password.txt')

Assert-Administrator
Ensure-Workspace -Workspace $config.workspace

$password = New-RandomPassword
$userCreated = Ensure-LocalUser -UserName $config.username -Password $password

if (-not $userCreated -and (Test-Path -LiteralPath $passwordFile)) {
    $password = Get-Content -LiteralPath $passwordFile -Raw
    $password = $password.Trim()
}

if (-not $password) {
    throw '没有可用的账户密码。若账户已存在但密码文件缺失，请先运行 uninstall.ps1 清理后重试。'
}

Set-Content -LiteralPath $passwordFile -Value $password -Encoding ASCII
Hide-LocalUser -UserName $config.username
Ensure-UserProfileDirectories -UserName $config.username
Set-WorkspaceAcl -Workspace $config.workspace -UserName $config.username
Set-ProfileAcl -UserName $config.username
Set-DenyAcl -Paths $config.deny_access -UserName $config.username
Save-LauncherCredential -UserName $config.username -Password $password
New-DesktopShortcut -ShortcutName $config.terminal_title -TargetScriptPath $launchScriptPath

Write-Host ''
Write-Host '小绿就绪。'
Write-Host ("工作区：{0}" -f $config.workspace)
Write-Host ("受限账户：{0}" -f $config.username)
Write-Host '你现在可以双击桌面上的“小绿安全终端”启动受限终端。'
Write-Host '如果 runas /savecred 首次行为与系统环境不一致，请用 diagnose.ps1 进一步排查。'
