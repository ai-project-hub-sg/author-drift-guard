# author-drift-guard 安装脚本
# 用法:
#   .\install.ps1                  # 仅挂载技能到各 agent 技能库（junction，免复制）
#   .\install.ps1 -Repo <path>     # 同时把 pre-push 钩子装入该仓库（硬链接优先，回退复制）
#   .\install.ps1 -Uninstall       # 移除各技能库中的挂载点（不动项目目录）
[CmdletBinding()]
param(
    [string]$Repo = '',
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$project   = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillSrc  = Join-Path $project 'skill\author-drift-guard'
$skillName = 'author-drift-guard'
$targets   = @(
    "$env:USERPROFILE\.agents\skills\$skillName",
    "$env:APPDATA\devin\skills\$skillName",
    "$env:USERPROFILE\.codex\skills\$skillName",
    "$env:USERPROFILE\.claude\skills\$skillName"
)

if ($Uninstall) {
    foreach ($t in $targets) {
        if (Test-Path $t) { cmd /c rmdir "$t" 2>$null; Write-Output "removed: $t" }
    }
    return
}

foreach ($t in $targets) {
    $parent = Split-Path -Parent $t
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path $t) {
        $item = Get-Item $t -Force
        if ($item.LinkType) { $item.Delete() }                     # 旧挂载点 → 重建
        elseif (Test-Path "$t\SKILL.md") { Remove-Item $t -Recurse -Force }  # 旧副本 → 移除
        else { Write-Warning "已存在非本技能目录，跳过: $t"; continue }
    }
    New-Item -ItemType Junction -Path $t -Target $skillSrc | Out-Null
    Write-Output "junction: $t -> $skillSrc"
}

if ($Repo) {
    $hookDst = Join-Path $Repo '.git\hooks\pre-push'
    $hookSrc = Join-Path $project 'hooks\pre-push'
    if (-not (Test-Path (Join-Path $Repo '.git'))) { throw "不是 git 仓库: $Repo" }
    if (Test-Path $hookDst) { Write-Warning "pre-push 已存在: $hookDst（未覆盖）" }
    else {
        New-Item -ItemType Directory -Path (Split-Path $hookDst) -Force | Out-Null
        try { New-Item -ItemType HardLink -Path $hookDst -Target $hookSrc | Out-Null; Write-Output "hardlink hook: $hookDst" }
        catch { Copy-Item $hookSrc $hookDst; Write-Output "copy hook: $hookDst" }
    }
}
Write-Output 'done.'
