# Antigravity 增强三件套 —— 自动修复
#
# 顺序铁律：先 CN 汉化，再 BetterGravity。反过来会把 2KB bootstrap 当成"官方原版"备份，两个都坏。
#
# 设计取舍：只在 Antigravity 【未运行】时动手。
#   打补丁必须独占 app.asar，强杀会打断用户正在跑的 agent 任务。宁可晚修，不可打断。
#   CN 引擎也只在"安装前客户端开着"时才自动重启，所以关着修 = 静默无弹窗。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File repair-all.ps1           交互式，有中文提示
#   powershell -ExecutionPolicy Bypass -File repair-all.ps1 -Quiet    静默（给计划任务用）
#   powershell -ExecutionPolicy Bypass -File repair-all.ps1 -DryRun   只体检，不动手

param(
    [switch]$Quiet,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

# 屏蔽 Invoke-WebRequest / Expand-Archive 的进度条 —— 它们会刷出几万字符的噪音
$ProgressPreference = "SilentlyContinue"

# ============ 配置 ============
$AG      = "$env:LOCALAPPDATA\Programs\antigravity"
$AGEXE   = Join-Path $AG "Antigravity.exe"
# ⚠️ 不要用 $RES 作变量名：PowerShell 变量大小写不敏感，
#    下面 $res = & node ... 会把 $RES 覆盖成数组，导致 Join-Path 收不到路径。
$RSRC    = Join-Path $AG "resources"
$CACHE   = "$env:LOCALAPPDATA\BetterGravity\PatcherCache"
$CN_DIR  = "$env:USERPROFILE\antigravity-desktop-cn"
$LOG_DIR = "$env:LOCALAPPDATA\AntigravityEnhance"
$LOG     = Join-Path $LOG_DIR "repair.log"
$BG_RAW  = "https://raw.githubusercontent.com/YashjitPal/BetterGravity/main/apps/installer-windows/Patcher"

$FILES = @("patcher-cli.cjs", "manifest.json", "runtime/main.cjs", "runtime/preload.cjs", "runtime/repair.cjs", "runtime/overlay.html")

# ============ 工具 ============
New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null

function Log([string]$m) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
    $line | Out-File $LOG -Append -Encoding utf8
    if (-not $Quiet) { Write-Host $line }
}

function Say([string]$m, [string]$color = "Cyan") {
    if (-not $Quiet) { Write-Host $m -ForegroundColor $color }
}

function Find-Node {
    foreach ($c in @(
        "$env:USERPROFILE\.workbuddy\binaries\node\versions\22.22.2-3\node.exe",
        "D:\node.exe"
    )) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-AsarState {
    $a = Join-Path $RSRC "app.asar"
    $b = Join-Path $RSRC "_app.asar"
    $k = Join-Path $RSRC "app.asar.bak"
    return [pscustomobject]@{
        AppAsar   = if (Test-Path $a) { (Get-Item $a).Length } else { 0 }
        OrigAsar  = if (Test-Path $b) { (Get-Item $b).Length } else { 0 }
        BakAsar   = if (Test-Path $k) { (Get-Item $k).Length } else { 0 }
        # BetterGravity 装好 = app.asar 是 2KB 级 bootstrap 且 _app.asar 是大文件
        BetterGravity = ((Test-Path $a) -and (Get-Item $a).Length -lt 10000 -and (Test-Path $b) -and (Get-Item $b).Length -gt 1000000)
        # app.asar 是真 asar（没被 bootstrap 顶替）
        RealAsar      = ((Test-Path $a) -and (Get-Item $a).Length -gt 1000000)
    }
}

# CN 引擎在重包时写入一对分隔符，可当作"已注入"的可靠标记。
# 已注入还去重跑，会把翻译代码再套一层（双重注入），并让 .bak 变成已汉化版本。
$CN_MARKER = "__ANTIGRAVITY_CHINESE_LOCALIZATION_START__"

function Test-CnPatched {
    # BG 已装时生效的是 _app.asar；否则是 app.asar。bootstrap 只有 2KB，跳过。
    foreach ($p in @((Join-Path $RSRC "_app.asar"), (Join-Path $RSRC "app.asar"))) {
        if (-not (Test-Path $p)) { continue }
        if ((Get-Item $p).Length -lt 1000000) { continue }
        try {
            # latin1：byte 与 char 一一对应，避免任何编码解码问题
            $txt = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::GetEncoding(28591))
            if ($txt.Contains($CN_MARKER)) { return $true }
        } catch { }
    }
    return $false
}

# ============ 主流程 ============
try {
    Log "===== 开始检查 ====="

    if (-not (Test-Path $AGEXE)) { Log "找不到 Antigravity，退出"; exit 1 }

    $node = Find-Node
    if (-not $node) { Log "找不到 Node.js，退出"; exit 1 }

    $running = @(Get-Process -Name "Antigravity*" -ErrorAction SilentlyContinue).Count
    if ($running -gt 0) {
        Log "Antigravity 正在运行（$running 个进程），跳过本次修复（不强杀）"
        Say "`n  Antigravity 正在运行，已跳过。" "Yellow"
        Say "  关掉它之后再跑一次，或直接双击 repair-all 即可。" "DarkGray"
        exit 0
    }

    $s = Get-AsarState
    Log ("状态: app.asar={0}B  _app.asar={1}B  app.asar.bak={2}B  BetterGravity={3}  真asar={4}" -f `
         $s.AppAsar, $s.OrigAsar, $s.BakAsar, $s.BetterGravity, $s.RealAsar)

    if ($s.BetterGravity) {
        Log "BetterGravity 已就位，无需修复（CN 层因顺序关系必然已先行）"
        Say "`n  ✓ 一切正常，不用管。" "Green"
        exit 0
    }

    if ($DryRun) {
        Log "DryRun：仅体检，不做修改"
        Say "`n  [体检结果]" "Cyan"
        Say "  app.asar      : $($s.AppAsar) 字节" "Gray"
        Say "  _app.asar     : $($s.OrigAsar) 字节" "Gray"
        Say "  app.asar.bak  : $($s.BakAsar) 字节" "Gray"
        Say "  BetterGravity : $(if($s.BetterGravity){'已装'}else{'缺失'})" "Gray"
        Say "  结论: $(if($s.RealAsar){'可修复（app.asar 是官方原版）'}else{'需人工介入（app.asar 不是有效原生包）'})" "Gray"
        exit 0
    }

    if (-not $s.RealAsar) {
        Log "app.asar 不是有效原生包（$($s.AppAsar) 字节），无法自动修复。"
        Say "`n  app.asar 不是有效的原生包，自动修复会把它彻底弄坏，已停止。" "Red"
        Say "  建议：重装 Antigravity，或手动恢复 app.asar.bak。" "Yellow"
        exit 1
    }

    # ---- 步骤 1：CN 汉化 ----
    Say "`n[1/2] 中文汉化（antigravity-desktop-cn）" "Cyan"

    if (Test-CnPatched) {
        Log "CN 注入标记已存在，跳过（避免二次注入）"
    } else {
        # Antigravity 更新会在 resources 留下【上一版本】的 app.asar.bak。
        # CN 把 .bak 当"官方原版"并永远从它重打 —— 留着旧的会打错版本。
        # 只在确认 CN 未注入时才删：此时 app.asar 就是当前官方原版。
        if ($s.BakAsar -gt 0) {
            Log "CN 未注入，但存在残留 app.asar.bak（$($s.BakAsar)B），删除以免 CN 打错版本"
            Remove-Item (Join-Path $RSRC "app.asar.bak") -Force -ErrorAction SilentlyContinue
        }

        if (-not (Test-Path (Join-Path $CN_DIR "localization_engine.js"))) {
            Log "本地没有 CN 仓库，尝试克隆到 $CN_DIR"
            $git = Get-Command git.exe -ErrorAction SilentlyContinue
            if ($git) {
                & $git.Source clone --depth 1 https://github.com/Silas-02/antigravity-desktop-cn.git $CN_DIR 2>&1 | Out-Null
            }
        }

        $engine = Join-Path $CN_DIR "localization_engine.js"
        if (Test-Path $engine) {
        Log "执行 CN 注入"
        Push-Location $CN_DIR
        # CN 引擎输出是 UTF-8；PowerShell 5.1 默认按 GBK 解子进程 stdout，会写成乱码进日志
        $prevEnc = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $cnOut = & $node $engine --brand-title english 2>&1
            $cnCode = $LASTEXITCODE
        } finally {
            [Console]::OutputEncoding = $prevEnc
            Pop-Location
        }
        $cnOut | Out-File $LOG -Append -Encoding utf8
        if ($cnCode -ne 0) { Log "CN 注入失败（exit=$cnCode），继续尝试 BG" }
        else { Log "CN 注入成功" }
        } else {
            Log "CN 引擎不可用（未克隆成功），跳过汉化层"
        }
    }

    # ---- 步骤 2：BetterGravity ----
    Say "`n[2/2] BetterGravity（插件平台）" "Cyan"

    # 先刷新 runtime（缓存可能过期）
    $stage = Join-Path $env:TEMP ("bg-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    $refreshed = $false
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $stage "runtime") | Out-Null
        foreach ($f in $FILES) {
            Invoke-WebRequest -Uri "$BG_RAW/$f" -OutFile (Join-Path $stage ($f -replace "/", "\")) -UseBasicParsing -TimeoutSec 45
        }
        $mf = Get-Content (Join-Path $stage "manifest.json") -Raw | ConvertFrom-Json
        $bad = @()
        foreach ($name in $mf.files.PSObject.Properties.Name) {
            $p = Join-Path $stage ($name -replace "/", "\")
            if (-not (Test-Path $p)) { $bad += $name; continue }
            if ((Get-FileHash $p -Algorithm SHA256).Hash.ToLower() -ne $mf.files.$name.sha256.ToLower()) { $bad += $name }
        }
        if ($bad.Count -eq 0) {
            New-Item -ItemType Directory -Force -Path $CACHE | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $CACHE "runtime") | Out-Null
            foreach ($f in $FILES) { Copy-Item (Join-Path $stage ($f -replace "/", "\")) (Join-Path $CACHE ($f -replace "/", "\")) -Force }
            $refreshed = $true
            Log "runtime 已更新并校验通过（manifest $($mf.generatedAt)）"
        } else {
            Log "runtime 校验失败：$($bad -join ', ')，改用本地缓存"
        }
    } catch {
        Log "拉取 runtime 失败：$($_.Exception.Message)，改用本地缓存"
    } finally {
        Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    }

    $cli = Join-Path $CACHE "patcher-cli.cjs"
    if (-not (Test-Path $cli)) { Log "没有可用的 patcher，BG 步骤跳过"; exit 1 }
    if (-not $refreshed) { Log "注意：用的是本地缓存 runtime，可能不是最新" }

    $agWin = $AG -replace "\\", "/"
    $patchOut = & $node $cli run install $agWin ("$CACHE\runtime" -replace "\\", "/") 2>&1
    $patchOut | Out-File $LOG -Append -Encoding utf8

    $ok = $false
    foreach ($l in $patchOut) {
        try {
            $o = $l.Trim() | ConvertFrom-Json
            if ($o.type -eq "result" -and $o.success) { $ok = $true; Log "BG 补丁成功" }
            elseif ($o.type -eq "result") { Log "BG 失败：$($o.message)" }
        } catch { }
    }

    # ---- 收尾 ----
    $s2 = Get-AsarState
    Log ("修复后: app.asar={0}B  _app.asar={1}B  BetterGravity={2}" -f $s2.AppAsar, $s2.OrigAsar, $s2.BetterGravity)

    if ($s2.BetterGravity) {
        Say "`n  ✓ 修复完成。手动启动 Antigravity 即可。" "Green"
        Say "    （脚本不代为启动，避免和单实例锁冲突）" "DarkGray"
        Log "===== 完成，状态正常 ====="
        exit 0
    } else {
        Say "`n  ✗ 未能完全修复，详见 $LOG" "Red"
        Log "===== 完成，但状态异常 ====="
        exit 1
    }
} catch {
    Log "未捕获异常：$($_.Exception.Message)"
    Say "`n  出错了：$($_.Exception.Message)" "Red"
    exit 1
} finally {
    if (-not $Quiet) { Read-Host "`n按回车退出" | Out-Null }
}
