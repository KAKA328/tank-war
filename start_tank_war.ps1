[CmdletBinding()]
param(
    [switch]$Headless,
    [switch]$Editor,
    [switch]$CheckOnly
)

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe'),
    (Join-Path $env:ProgramFiles 'Godot\Godot_v4.exe'),
    (Join-Path $env:ProgramFiles 'Godot\godot.exe')
)

$godotPath = $godotCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $godotPath) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($godotCommand) {
        $godotPath = $godotCommand.Source
    }
}

if (-not $godotPath) {
    Write-Host '找不到 Godot 4. 请确认 Godot 已安装，或把 godot.exe 加入 PATH。' -ForegroundColor Red
    exit 1
}

if ($CheckOnly) {
    Write-Host "Godot: $godotPath" -ForegroundColor Green
    Write-Host "Project: $projectRoot" -ForegroundColor Green
    exit 0
}

$arguments = @('--path', $projectRoot)
if ($Headless) {
    $arguments += '--headless'
}
if ($Editor) {
    $arguments += '--editor'
}
Write-Host "启动 Tank War: $projectRoot" -ForegroundColor Green
Start-Process -FilePath $godotPath -ArgumentList $arguments -WorkingDirectory $projectRoot
