---
name: antigravity-enhancement-stack
description: 给 Windows 上的 Google Antigravity 装齐「增强三件套」——BetterGravity（插件平台）+ 原生插件（antigrative-dashboard）+ 中文汉化（antigravity-desktop-cn），并配好更新后自动修复。当用户要求「装 BetterGravity / 装 Antigravity 插件 / 汉化 Antigravity / Antigravity 汉化没了 / BetterGravity 又消失了」，或需要把这套流程交给另一个 AI 执行时使用。
license: MIT
---

# Antigravity 增强三件套：安装 + 持久化

> 本文所有路径以 cjing 的机器为样本（Windows / ROG）：
> Antigravity 装在 `C:\Users\cjing\AppData\Local\Programs\antigravity`；
> 全局 Python 3.14.3 在 `C:\Users\cjing\AppData\Local\Python\pythoncore-3.14-64\python.exe`。
> 换机器时替换这些路径，**逻辑不变**。

---

## 0. 先理解：三条腿，三种失效方式

Antigravity 每次更新都会替换自己的程序文件。这决定了三件东西里哪些会掉、哪些不会：

| 组件 | 仓库 | 改了宿主的什么 | 更新后 | 装在哪 |
|---|---|---|---|---|
| **Antigravity Desktop CN** | `Silas-02/antigravity-desktop-cn` | **重包 `app.asar`**，向 `preload.js` 注入翻译引擎 | ❌ **掉** | `resources/app.asar`（备份在 `app.asar.bak`） |
| **BetterGravity** | `YashjitPal/BetterGravity` | **替换 `app.asar` 为 bootstrap** + 备份为 `_app.asar` | ❌ **掉** | `resources/` + `%APPDATA%\BetterGravity\` |
| **antigrative-dashboard** | `YOU-SHOULD-KNOW-ME/antigrative-dashboard` | **不动 `app.asar`**，通过 renderer 调试端点挂载 | ✅ **不掉** | `~/.gemini/config/plugins/antigravity-pulse` |

**一句话**：前两个都动 `app.asar`，所以每次更新全灭；第三个在 `~/.gemini/config/`，安然无恙。

### ★★ 最关键的规则：前两个有严格顺序

两者的备份机制**互相不兼容**：

- **CN** 用 `app.asar.bak` 存「官方原版」，并且**永远从 `app.asar.bak` 重打**：
  ```js
  if (!fs.existsSync(bakPath)) fs.copyFileSync(asarPath, bakPath);   // 备份
  const sourceAsar = fs.existsSync(bakPath) ? bakPath : asarPath;    // 永远从备份打
  ```
- **BetterGravity** 用 `_app.asar` 存「被它接手时的 app.asar」，`app.asar` 变成 2KB bootstrap。

所以：

| 顺序 | 结果 |
|---|---|
| **CN → BetterGravity** ✅ | CN 先重包 app.asar；BG 把**已汉化的包**备份成 `_app.asar`，bootstrap 去加载它 → **两者都生效** |
| BetterGravity → CN ❌ | BG 先把 app.asar 换成 2KB bootstrap；CN 会把这个**假 asar** 当成官方原版备份进 `app.asar.bak`，随后重包失败或产出垃圾 → **两个都坏** |

**卸载顺序必须反过来：先卸 BetterGravity，再卸 CN。**

> 记忆口诀：**装：CN 先；卸：BG 先。**

---

## 1. 装机前：摸清基线

```bash
R="$LOCALAPPDATA/Programs/antigravity/resources"

# 宿主版本（最可靠的来源）
powershell -c "(Get-Item '$env:LOCALAPPDATA\Programs\antigravity\Antigravity.exe').VersionInfo.FileVersion"

# 三个 asar 的状态
ls -la "$R" | grep -E "app\.asar|_app\.asar"
```

判读表：

| `app.asar` | `_app.asar` | `app.asar.bak` | 含义 |
|---|---|---|---|
| ~4.5 MB | 无 | 无 | 官方纯净，什么都没装 |
| ~4.5 MB（比官方大） | 无 | ~4.5 MB | **只装了 CN**（app.asar 是被重包的） |
| **~2 KB** | ~4.5 MB | 视情况 | **BetterGravity 已装**；`.bak` 存在则说明底层还压着 CN |
| ~2 KB | 无 | 无 | ⚠️ 异常：bootstrap 没有原版可加载 → 应用起不来，跑一次 `run uninstall` 或重装 |

其余两项：

```bash
ls "$APPDATA/BetterGravity/plugins/"       # BetterGravity 插件（bettergravity-zh / computer-use / pets…）
ls "$HOME/.gemini/config/plugins/"         # 原生插件（antigravity-pulse / gemini-api…）
tasklist | grep -i -E "antigravity|hans|language_server"
```

---

## 2. 装 CN 汉化（必须先装）

仓库：<https://github.com/Silas-02/antigravity-desktop-cn>

### 2.1 它怎么工作

- 内置轻量 ASAR 读写（**不用 npm / 不联网**），把 `preload.js` 重写为带翻译引擎的版本后重包 `app.asar`
- 词典按版本分片（`dicts/v2.24.0.json` 等），**精确全词匹配 + 长句带词边界替换**
- **主动跳过**：已发送的用户消息（`data-testid="user-input-step"`）、输入区、编辑器、终端、代码块
- 支持在任意容器加 `data-ag-localization-skip` 永久排除
- 可无损还原（从 `app.asar.bak` 恢复）

### 2.2 安装

```bash
git clone https://github.com/Silas-02/antigravity-desktop-cn.git
cd antigravity-desktop-cn
```

**Windows**：双击 `双击安装中文汉化.bat`（或等价地跑 `node localization_engine.js --brand-title english`）
**macOS**：`./install.sh`
**Linux**：`./install.sh`

要点：
- 脚本会**自动关闭正在运行的 Antigravity**，装完可自行重启
- 品牌名二选一：`--brand-title english`（默认，左上角保留 Antigravity）或 `--brand-title hidden`
- 装在系统目录才需要提权；用户目录免提权
- **需要 Node.js 16+**（用系统 node，不用 npm）

### 2.3 还原

`双击卸载还原官方英文.bat` / `./uninstall.sh` —— 从 `app.asar.bak` 恢复原包。

> ⚠️ 如果此时 BetterGravity 还装着，**先卸 BG 再卸 CN**，否则会把 BG 的 bootstrap 关系打乱。

---

## 3. 装 BetterGravity（必须后装）

仓库：<https://github.com/YashjitPal/BetterGravity>

### 3.1 ★ 不要用 PatcherCache 里的旧 runtime

`%LOCALAPPDATA%\BetterGravity\PatcherCache` 只在 **GUI 安装器联网时**刷新。装了很久的机器，里面是**当时那个 Antigravity 版本**构建的 runtime，拿去补新版不可靠（实测 9/22 的 runtime 在 2.21.1 上出问题）。

`inspect` 返回的 `nativePatchAvailable: true` **不等于** runtime 是新的 —— 它只校验主版本号。

**从主分支拉最新 runtime 并校验：**

```bash
B="https://raw.githubusercontent.com/YashjitPal/BetterGravity/main/apps/installer-windows/Patcher"
mkdir -p /tmp/bgnew/runtime && cd /tmp/bgnew
for f in patcher-cli.cjs manifest.json; do curl -sL "$B/$f" -o "$f"; done
for f in main.cjs preload.cjs repair.cjs overlay.html; do curl -sL "$B/runtime/$f" -o "runtime/$f"; done

node -e '
const fs=require("fs"),crypto=require("crypto");
const m=JSON.parse(fs.readFileSync("manifest.json","utf8"));
for(const [k,v] of Object.entries(m.files)){
  const h=crypto.createHash("sha256").update(fs.readFileSync(k)).digest("hex");
  if(h!==v.sha256) throw new Error("哈希不符: "+k);
}
console.log("全部通过");'
```

通过了再覆盖缓存（先备份）：

```bash
PC="$LOCALAPPDATA/BetterGravity/PatcherCache"
cp -r "$PC" "$PC-old-$(date +%Y%m%d)" 2>/dev/null
cp patcher-cli.cjs manifest.json "$PC/"
cp runtime/* "$PC/runtime/"
```

### 3.2 关掉 Antigravity（必须）

**patcher CLI 不会自己关 Antigravity**，不关会在 52% 失败：

```
EBUSY: resource busy or locked, unlink '...\resources\app.asar'
```

失败是**安全**的（`app.asar` 仍是原版，编辑器照常用，bootstrap 以 `app.asar.bettergravity-staged` 暂存）。

```bash
for i in 1 2 3; do MSYS_NO_PATHCONV=1 taskkill /IM Antigravity.exe /F >/dev/null 2>&1; done
tasklist | grep -ci antigravity    # 必须是 0
```

### 3.3 打补丁

```bash
NODE=<node 可执行文件>
PC="C:/Users/<你>/AppData/Local/BetterGravity/PatcherCache"   # ⚠️ C:/ 不要 /c/
AG="C:/Users/<你>/AppData/Local/Programs/antigravity"

"$NODE" "$PC/patcher-cli.cjs" inspect "$AG"
"$NODE" "$PC/patcher-cli.cjs" run install "$AG" "$PC/runtime"
"$NODE" "$PC/patcher-cli.cjs" inspect "$AG"
```

成功标志：
```json
{"success":true,"patchState":"patched",
 "antigravityVersion":"2.21.1","betterGravityVersion":"3.0.0"}
```

**路径红线**：node 里必须写 `C:/...`。写 `/c/...` 会被 MSYS 转成 `c:\c\Users\...`，报 `MODULE_NOT_FOUND`（看着像缺依赖，其实是入口文件找不到）。**踩过两次。**

操作名：`detect` / `inspect` / `run install` / `run uninstall`。`run uninstall` 是「补丁装坏了」的安全退路。

---

## 4. 装 antigrative-dashboard（原生插件，随时可装）

仓库：<https://github.com/YOU-SHOULD-KNOW-ME/antigrative-dashboard>

### 4.1 先确认宿主

可能并存三种：**桌面 App** / **CLI（`agy`）** / **独立 IDE**。安装命令不同，**多个并存时必须让用户选**。

```bash
ls "$LOCALAPPDATA/Programs/antigravity/Antigravity.exe"
which agy
ls "$LOCALAPPDATA/Programs/antigravity-ide" 2>/dev/null
```

### 4.2 下载 + 校验 + 解压

```bash
REL="https://github.com/YOU-SHOULD-KNOW-ME/antigrative-dashboard/releases/download/<tag>"
curl -sL "$REL/antigrative-dashboard-<ver>.zip" -o ad.zip
curl -sL "$REL/antigrative-dashboard-<ver>.zip.sha256" -o ad.zip.sha256
sha256sum ad.zip     # 必须与 .sha256 一致，否则停
```

解压后 zip 内**多套一层同名目录**，要压平到 `C:\Users\<你>\antigrative-dashboard\`（**源码目录必须保留**，启停/卸载都靠它）。

### 4.3 安装

```bash
PY="C:/Users/<你>/AppData/Local/Python/pythoncore-3.14-64/python.exe"   # Python 3.10+
cd "$BASE"
"$PY" manage.py status
"$PY" manage.py install
```

**不要加 `--legacy-loader`** —— 那会改 `app.asar`，和 BG / CN 三方打架。默认 `runtime` 模式不动 `app.asar`。

### 4.4 验证

`status` 必须看到 `state: "mounted"`：

```json
{"installed": true, "enabled": true, "integrationMode": "runtime",
 "inlineIntegration": {"state": "mounted", "windows": 1}}
```

**只有 `installed: true` 不算成功** —— 那只是文件拷过去了，没挂上界面。

生命周期：`status` / `enable` / `disable` / `uninstall`。

---

## 5. 持久化：让它别每次都手动重来

### 5.1 为什么必须做

前两个组件**每次 Antigravity 更新必掉** —— 这是设计使然，不是 bug。没有持久化，用户每隔一两周就要重装一次。

### 5.2 方案：登录时 + 定期自检的计划任务

`scripts/repair-all.ps1` 的判定逻辑：

1. 读状态。三项都正常 → **静默退出**（不打扰）
2. **Antigravity 正在运行** → 只写日志，**不强杀**（用户可能正在用），下次再说
3. Antigravity 未运行且缺 CN → 装 CN
4. 未运行且缺 BG → 拉最新 runtime + 打补丁（**CN 必须在 BG 之前**）
5. 写结果到 `%LOCALAPPDATA%\AntigravityEnhance\repair.log`

注册计划任务：

```powershell
schtasks /Create /TN "AntigravityEnhance\AutoRepair" /SC MINUTE /MO 30 ^
  /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\path\repair-all.ps1\" -Quiet" ^
  /F
```

再补一条登录触发（`/SC ONLOGON`，加 `/DELAY 0001:00`）。

### 5.3 为什么不在应用运行时强修

打补丁必须独占 `app.asar`。强杀 Antigravity 会直接打断用户正在跑的 agent 任务。**宁可晚修，不可打断。**

---

## 6. 验收（别只看「装成功了」）

```bash
# ① 文件层
ls -la "$LOCALAPPDATA/Programs/antigravity/resources" | grep -E "app\.asar|_app\.asar"
#   期望：app.asar ≈2KB(bootstrap) + _app.asar ≈4.5MB + app.asar.bak ≈4.5MB

# ② 运行时层（最硬的证据）
tail -20 "$APPDATA/BetterGravity/runtime.log"
#   期望：Activating <bg> on Antigravity <ag> (Electron ...)
#         renderer: started plugin(s): <插件列表>

# ③ 原生插件
cd <dashboard 源码目录> && "$PY" manage.py status
#   期望：state = mounted
```

**`renderer: started plugin(s): ...` 是唯一能确认插件真被加载的证据。**

---

## 7. ★ Agent 的硬边界：启动不了 Antigravity

实测：Bash `run_in_background` 跑 `Antigravity.exe` → 1 秒退出；PowerShell `Start-Process` → 0 进程（偶发能成）。

**做了隔离实验**：怀疑「补丁导致起不来」，于是 `run uninstall` 还原官方原版再启动 —— **原版也起不来**。结论：是沙箱不让启动 GUI，不是补丁的问题。

所以：

- **「补丁能不能真用」只能让用户启动验证，agent 无法自测。**
- 交付时**明说这一点**，不要谎称「已验证可用」。
- 排查启动问题时，**先确认自己能不能启动原版**这个基线，否则会误判成补丁的锅。

---

## 8. 高频失败与对策

| 现象 | 原因 | 对策 |
|---|---|---|
| `EBUSY ... unlink app.asar` | Antigravity 没关 | `taskkill` 三次 + 确认归零，重跑 |
| `MODULE_NOT_FOUND` | 路径写了 `/c/...` | 改用 `C:/...` |
| `patchState: needs-repatch` | 上次补丁中断 | 关掉 Antigravity 直接重跑 `run install` |
| 应用起不来，`app.asar` 只有 2KB 且无 `_app.asar` | bootstrap 丢了原版 | `run uninstall` 或重跑 `run install` |
| CN 装完反而全乱 / 中英混排更严重 | **顺序错了**（BG 先装的） | 卸 BG → 卸 CN → 按 CN→BG 重装 |
| BG 补丁成功但界面没变 | 没重启 / 插件被禁用 | 看 `runtime.log` 的 `started plugin(s)` |
| 只有 BetterGravity 的界面是中文，Antigravity 本体还是英文 | CN 层没装或掉了 | 先装 CN，再重打 BG |
| 只有本体中文，BetterGravity 设置页是英文 | `bettergravity-zh` 没启用 | BetterGravity 设置 → Plugins 打开开关 |

---

## 9. 写 .ps1 脚本时的 BOM 坑

Agent 的 PowerShell 工具是 **5.1**（`OutputEncoding=gb2312`、`ACP=936`），读**无 BOM 的 UTF-8 `.ps1`** 会按 GBK 解，中文直接炸成语法错误，而且**报错信息本身也是乱码**（`寮傚父` = `异常`）。

写完必须转成带 BOM：

```powershell
$t = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($f, $t, (New-Object System.Text.UTF8Encoding($true)))
```

验证 `[System.IO.File]::ReadAllBytes($f)[0..2]` = `239,187,191`。
**每次用 Edit 改过 .ps1 都要重做**（编辑会把 BOM 弄丢）。

`.cmd` 包装器必须是**纯 ASCII** —— cmd.exe 按 OEM 936 解析，文件里写中文一样乱，`chcp 65001` 救不了文件自身。中文全交给 `.ps1` 输出。
