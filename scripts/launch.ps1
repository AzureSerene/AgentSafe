Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModeConfig {
    param([string]$ModePath)

    if (-not (Test-Path -LiteralPath $ModePath)) {
        throw "找不到模式文件: $ModePath"
    }

    return Get-Content -LiteralPath $ModePath -Raw | ConvertFrom-Json
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$modePath = Join-Path $projectRoot 'modes\xiaolv.json'
$config = Get-ModeConfig -ModePath $modePath
$terminalTitle = $config.terminal_title
$workspace = $config.workspace
$userName = $config.username

if (-not (Test-Path -LiteralPath $workspace)) {
    throw "工作区不存在：$workspace。请先运行 setup.ps1。"
}

$cmdPayload = "cd /d \"$workspace\" && title $terminalTitle && cmd.exe"
$command = "runas /savecred /user:$userName \"cmd.exe /k $cmdPayload\""

Write-Host ("正在以受限账户启动：{0}" -f $userName)
Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $command | Out-Null
