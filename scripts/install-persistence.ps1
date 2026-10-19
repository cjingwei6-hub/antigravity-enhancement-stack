# 注册「自动修复」计划任务（持久化）
#
# 做两件事：
#   1. 登录后 1 分钟跑一次（此时 Antigravity 通常还没启动，最安全）
#   2. 之后每 30 分钟静默检查一次（Antigravity 开着就直接跳过，不强杀）
#
# 卸载：powershell -ExecutionPolicy Bypass -File install-persistence.ps1 -Remove

param([switch]$Remove)

$ErrorActionPreference = "Stop"
$TaskName = "AntigravityEnhance\AutoRepair"
$Script   = Join-Path $PSScriptRoot "repair-all.ps1"

function Say($m, $c = "Cyan") { Write-Host $m -ForegroundColor $c }

Say ""
Say "  Antigravity 增强套件 —— 持久化配置" "White"
Say "  ----------------------------------------" "DarkGray"

if ($Remove) {
    $out = & schtasks /Delete /TN $TaskName /F 2>&1
    if ($LASTEXITCODE -eq 0) { Say "`n  已移除计划任务 $TaskName" "Green" }
    else { Say "`n  移除失败（可能本来就不存在）：$out" "Yellow" }
    Read-Host "`n按回车退出" | Out-Null
    exit 0
}

if (-not (Test-Path $Script)) {
    Say "`n  找不到 repair-all.ps1（应与本脚本同目录）" "Red"
    Read-Host "`n按回车退出" | Out-Null
    exit 1
}

# 关键：整个动作要"不弹窗、不抢焦点"
$psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
    $psExe = (Get-Command pwsh.exe).Source
}
$action = '"{0}" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}" -Quiet' -f $psExe, $Script

Say "`n  将注册两个触发器："
Say "    · 登录后 1 分钟（延迟，避开启动高峰）" "Gray"
Say "    · 每 30 分钟（Antigravity 开着会自动跳过）" "Gray"
Say "`n  执行命令：$action" "DarkGray"
Say "  日志：%LOCALAPPDATA%\AntigravityEnhance\repair.log" "DarkGray"

$ok = $true

# 30 分钟周期触发
$r1 = & schtasks /Create /TN $TaskName /SC MINUTE /MO 30 /TR $action /F /RL LIMITED 2>&1
if ($LASTEXITCODE -ne 0) { $ok = $false; Say "`n  周期任务创建失败：$r1" "Red" }

# 登录触发
$r2 = & schtasks /Create /TN "$TaskName-OnLogon" /SC ONLOGON /DELAY 0001:00 /TR $action /F /RL LIMITED 2>&1
if ($LASTEXITCODE -ne 0) { $ok = $false; Say "`n  登录任务创建失败：$r2" "Yellow" }

if ($ok) {
    Say "`n  完成。以后 Antigravity 更新把补丁冲掉，最多 30 分钟会自动修回来。" "Green"
    Say "  （前提：那一刻 Antigravity 没在运行。开着就等下一次。）" "Gray"
    Say "`n  现在先跑一次体检：" "Cyan"
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $Script -DryRun
} else {
    Say "`n  部分任务没建成，见上方提示。" "Yellow"
}

Read-Host "`n按回车退出" | Out-Null
