Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModeConfig {
    param([string]$ModePath)

    if (-not (Test-Path -LiteralPath $ModePath)) {
        throw "找不到模式文件: $ModePath"
    }

    return Get-Content -LiteralPath $ModePath -Raw | ConvertFrom-Json
}

function Test-CreateFile {
    param([string]$Directory)

    try {
        $filePath = Join-Path $Directory 'agentsafe_diagnose_write_test.txt'
        Set-Content -LiteralPath $filePath -Value 'ok' -Encoding ASCII
        Remove-Item -LiteralPath $filePath -Force
        return $true
    }
    catch {
        return $false
    }
}

function Test-ReadPath {
    param([string]$Path)

    try {
        Get-ChildItem -LiteralPath $Path -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$modePath = Join-Path $projectRoot 'modes\xiaolv.json'
$config = Get-ModeConfig -ModePath $modePath
$userProfile = [Environment]::GetFolderPath('UserProfile')
$tempPath = [IO.Path]::GetTempPath()
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$firstDeniedPath = $config.deny_access | Select-Object -First 1

Write-Host '=== AgentSafe Diagnose ==='
Write-Host ("当前身份：{0}" -f $currentIdentity)
Write-Host ("当前目录：{0}" -f (Get-Location).Path)
Write-Host ("工作区：{0}" -f $config.workspace)
Write-Host ("用户目录：{0}" -f $userProfile)
Write-Host ("Temp目录：{0}" -f $tempPath)
Write-Host ''

$workspaceExists = Test-Path -LiteralPath $config.workspace
$workspaceWritable = $false
if ($workspaceExists) {
    $workspaceWritable = Test-CreateFile -Directory $config.workspace
}

$tempWritable = Test-CreateFile -Directory $tempPath
$deniedBlocked = $false
if ($firstDeniedPath) {
    $deniedBlocked = -not (Test-ReadPath -Path $firstDeniedPath)
}

Write-Host ("工作区存在：{0}" -f $workspaceExists)
Write-Host ("工作区可写：{0}" -f $workspaceWritable)
Write-Host ("Temp可写：{0}" -f $tempWritable)
if ($firstDeniedPath) {
    Write-Host ("敏感路径受限（{0}）：{1}" -f $firstDeniedPath, $deniedBlocked)
}
Write-Host ''

$agentCommands = @('openclaw', 'claude', 'codex')
foreach ($command in $agentCommands) {
    $result = Get-Command $command -ErrorAction SilentlyContinue
    Write-Host ("命令可见 {0}: {1}" -f $command, [bool]$result)
}
