# OpenHarmony Shell 终端 HAP 应用开发文档

## 一、设计思路

### 1.1 目标

在 OpenHarmony（RK3568 开发板，简化版 4.1.1）上实现一个原生终端应用，用户可以通过 HAP 应用直接在设备上执行 shell 命令，无需依赖 PC 端 `hdc shell`。

### 1.2 架构

```
┌─────────────────────────────────────┐
│          HAP 应用 (终端)              │
│  ┌───────────────────────────────┐  │
│  │   WebView (terminal.html)     │  │
│  │   ├── xterm.js  终端渲染       │  │
│  │   ├── 输入栏 (命令输入+按钮)    │  │
│  │   └── WebSocket 客户端         │  │
│  └──────────┬────────────────────┘  │
│             │ ws://localhost:7681    │
│  ┌──────────▼────────────────────┐  │
│  │  shell-bridge.js (Node.js)    │  │
│  │  ├── WebSocket 服务端          │  │
│  │  ├── child_process.spawn      │  │
│  │  └── /bin/sh -i (交互式Shell)  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

三个核心组件：
- **shell-bridge.js** — Node.js WebSocket 服务，桥接 WebSocket 和设备 Shell
- **terminal.html** — 基于 xterm.js 的终端前端页面
- **Index.ets** — OpenHarmony HAP 页面，用 WebView 加载 terminal.html

### 1.3 通信流程

```
用户输入命令 → 输入栏 → WebSocket.send() → shell-bridge.js → sh.stdin.write()
                                                    ↓
终端显示输出 ← xterm.js ← WebSocket.onmessage() ← sh.stdout/stderr
```

---

## 二、组件详解

### 2.1 shell-bridge.js（设备端 Node.js 脚本）

**文件位置**：`HelloHap/shell-bridge.mjs`（本地开发），部署到设备 `/data/local/tmp/shell-bridge.js`

**核心逻辑**：
```javascript
const { spawn } = require('child_process');
const { WebSocketServer } = require('ws');

const PORT = 7681;
const wss = new WebSocketServer({ host: '0.0.0.0', port: PORT });

wss.on('connection', (ws) => {
  const sh = spawn('/bin/sh', ['-i'], {
    env: {
      ...process.env,
      TERM: 'xterm-256color',
      PS1: '$ ',
      PATH: '/bin:/sbin:/system/bin:/system/sbin:/vendor/bin:/usr/bin:/usr/sbin'
    },
    stdio: ['pipe', 'pipe', 'pipe']
  });

  // Shell 输出 → WebSocket（\n 转 \r\n 适配 xterm.js）
  sh.stdout.on('data', (d) => {
    if (ws.readyState === 1) ws.send(d.toString().replace(/\r?\n/g, '\r\n'));
  });
  sh.stderr.on('data', (d) => {
    if (ws.readyState === 1) ws.send(d.toString().replace(/\r?\n/g, '\r\n'));
  });

  // WebSocket 输入 → Shell
  ws.on('message', (msg) => {
    const data = msg.toString();
    if (data === '\x03') { sh.kill('SIGINT'); return; }
    sh.stdin.write(data);
  });
});
```

**关键设计点**：
| 配置 | 说明 |
|------|------|
| `PS1: '$ '` | 简化提示符，避免转义字符在 pipe 模式下不展开 |
| `PATH` | 设置 OpenHarmony 系统命令路径，否则 `ls` 等命令找不到 |
| `\r?\n → \r\n` | xterm.js 需要 `\r\n` 换行，Shell 输出只有 `\n` |
| `stdio: ['pipe', 'pipe', 'pipe']` | 使用管道模式（非 PTY），简化实现 |
| CommonJS (`require`) | 设备上 `NODE_PATH` 环境变量仅对 CommonJS 生效 |

### 2.2 terminal.html（xterm.js 前端）

**文件位置**：`entry/src/main/resources/rawfile/terminal.html`

**依赖文件**（同目录 rawfile 下）：
- `xterm.js` — xterm.js 库（从 unpkg CDN 下载）
- `xterm.css` — xterm.js 样式

**界面结构**：
```
┌──────────────────────────────┐
│  [状态栏] Connected          │
│                              │
│  xterm.js 终端输出区域        │
│  $ ls                        │
│  bin  sbin  system           │
│                              │
│  ┌────┬────┬──────────┬────┐ │
│  │Tab │C-c │ 命令输入  │Run │ │
│  └────┴────┴──────────┴────┘ │
└──────────────────────────────┘
```

**关键设计点**：
- **disableStdin: true** — 禁用 xterm.js 内部的隐藏 textarea，防止在 OpenHarmony WebView 中劫持键盘和触摸事件
- **pointer-events: none** — xterm 屏幕区域不拦截鼠标/触摸事件
- **独立输入栏** — 因为 OpenHarmony WebView 中 xterm.js 的内置输入不可用，所以用显式的 `<input>` + 按钮
- **不做本地回显** — 交互式 Shell (`sh -i`) 本身会回显输入，前端不需要重复写入
- **自动重连** — 断线后自动重连，最多 10 次

### 2.3 Index.ets（HAP 页面）

**文件位置**：`entry/src/main/ets/pages/Index.ets`

```typescript
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Web({
        src: $rawfile('terminal.html'),
        controller: this.controller
      })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.All)
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1e1e2e')
  }
}
```

**关键配置**：
- `javaScriptAccess(true)` — 允许 JS 执行
- `domStorageAccess(true)` — 允许 DOM 存储
- `mixedMode(MixedMode.All)` — 允许混合内容（WebSocket 连接需要）

### 2.4 HAP 配置

**module.json5** 关键配置：
```json5
{
  "module": {
    "deviceTypes": ["default", "phone"],  // default 兼容 RK3568
    "abilities": [{
      "name": "EntryAbility",
      "icon": "$media:app_icon",          // 单个 PNG 图标
      "label": "$string:EntryAbility_label",
      "exported": true,
      "skills": [{
        "entities": ["entity.system.home"],
        "actions": ["action.system.home", "ohos.want.action.home"]
      }]
    }],
    "requestPermissions": [{
      "name": "ohos.permission.INTERNET"  // WebSocket 需要网络权限
    }]
  }
}
```

**app.json5**：
```json5
{
  "app": {
    "bundleName": "com.openclaw.hellohap",
    "icon": "$media:app_icon",   // 单个 PNG，不用 layered_image
    "label": "$string:app_name"  // "终端"
  }
}
```

---

## 三、部署步骤

### 3.1 前置条件

- RK3568 开发板运行 OpenHarmony 4.1.1 简化版
- 设备上已安装 Node.js (`/data/local/tmp/node`)
- 设备上已安装 ws 包 (`/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules`)
- PC 已安装 hdc 工具
- PC 已安装 DevEco Studio

### 3.2 部署 shell-bridge.js

```powershell
# 推送脚本到设备
hdc file send D:\DevEcoProjects\HelloHap\shell-bridge.mjs /data/local/tmp/shell-bridge.js

# 后台启动
hdc shell "LD_LIBRARY_PATH=/system/lib64 NODE_PATH=/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules nohup /data/local/tmp/node /data/local/tmp/shell-bridge.js > /data/local/tmp/shell-bridge.log 2>&1 &"

# 验证运行
hdc shell "ps -ef | grep shell-bridge"
```

**环境变量说明**：
| 变量 | 值 | 说明 |
|------|-----|------|
| `LD_LIBRARY_PATH` | `/system/lib64` | Node.js 动态链接库路径 |
| `NODE_PATH` | `.../ws@8.19.0/node_modules` | ws 包的 pnpm 实际路径 |

### 3.3 编译安装 HAP

```powershell
# 在 DevEco Studio 中 Build → Build Hap(s)

# 安装到设备
hdc install D:\DevEcoProjects\HelloHap\entry\build\default\outputs\default\entry-default-signed.hap

# 启动应用
hdc shell aa start -a EntryAbility -b com.openclaw.hellohap
```

### 3.4 PC 浏览器调试（可选）

```powershell
# 端口转发
hdc fport tcp:7681 tcp:7681

# 在 rawfile 目录启动 HTTP 服务
npx http-server D:\DevEcoProjects\HelloHap\entry\src\main\resources\rawfile -p 8099

# 浏览器打开 http://localhost:8099/terminal.html
```

### 3.5 开机自启动（推荐）

通过 OpenHarmony init 系统注册 shell-bridge 为系统服务，实现开机自启，用户直接点开 HAP 即可使用，无需每次手动启动。

**步骤 1：创建 init 服务配置文件**

文件 `HelloHap/shell_bridge.cfg`：
```json
{
    "services" : [{
        "name" : "shell_bridge",
        "path" : ["/bin/sh", "-c", "LD_LIBRARY_PATH=/system/lib64 NODE_PATH=/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules /data/local/tmp/node /data/local/tmp/shell-bridge.js >> /data/local/tmp/shell-bridge.log 2>&1"],
        "uid" : "root",
        "gid" : ["root"],
        "disabled" : 0,
        "importance" : 0,
        "start-mode" : "boot",
        "ondemand" : false,
        "critical" : [0, 15, 5]
    }]
}
```

**关键字段**：

| 字段 | 说明 |
|------|------|
| `start-mode: "boot"` | 开机启动 |
| `ondemand: false` | 不等待触发，直接启动 |
| `critical: [0, 15, 5]` | 崩溃后 15 秒内最多重启 5 次 |
| `disabled: 0` | 启用服务 |

**步骤 2：部署到设备**

```powershell
# 1. 推送配置文件到设备临时目录
hdc file send D:\DevEcoProjects\HelloHap\shell_bridge.cfg /data/local/tmp/shell_bridge.cfg

# 2. 重新挂载根分区为可写（/system 是 / 的一部分，无需单独 remount）
hdc shell "mount -o rw,remount /"

# 3. 复制到 init 配置目录
hdc shell "cp /data/local/tmp/shell_bridge.cfg /system/etc/init/shell_bridge.cfg"
hdc shell "chmod 644 /system/etc/init/shell_bridge.cfg"

# 4. 确认文件到位
hdc shell "ls -l /system/etc/init/shell_bridge.cfg"

# 5. 重启生效
hdc shell reboot
```

**步骤 3：验证自启动**

设备启动完成后：
```powershell
hdc shell "ps -ef | grep shell-bridge"
hdc shell "netstat -tlnp | grep 7681"
hdc shell "cat /data/local/tmp/shell-bridge.log"
```

看到 node 进程在运行且 7681 端口监听即自启成功。以后每次开机后直接点开"终端" HAP 就能用。

### 3.6 手动启动（备用方案）

如果没配置自启动，或需要临时重启 shell-bridge：

```powershell
# 先结束旧进程（如有）
hdc shell "pkill -f shell-bridge"

# 启动 shell-bridge
hdc shell "LD_LIBRARY_PATH=/system/lib64 NODE_PATH=/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules nohup /data/local/tmp/node /data/local/tmp/shell-bridge.js > /data/local/tmp/shell-bridge.log 2>&1 &"

# 启动终端 HAP
hdc shell aa start -a EntryAbility -b com.openclaw.hellohap
```

---

## 四、踩坑与优化记录

### 4.1 ws 模块找不到

**问题**：`Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'ws'`

**原因**：ESM 模式（`.mjs`）下 `NODE_PATH` 环境变量不生效。

**解决**：将脚本从 ESM 改为 CommonJS（`.js` + `require()`），并设置 `NODE_PATH` 指向 pnpm 的实际 ws 包路径：
```
NODE_PATH=/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules
```

### 4.2 ls 命令找不到

**问题**：`ls: inaccessible or not found`

**原因**：spawn 的 Shell 没有继承完整的 `PATH`。

**解决**：在 spawn 环境变量中显式设置：
```javascript
PATH: '/bin:/sbin:/system/bin:/system/sbin:/vendor/bin:/usr/bin:/usr/sbin'
```

### 4.3 终端输出排版错乱

**问题**：输出文字没有正确换行，全部堆在一行。

**原因**：Shell 输出 `\n`，但 xterm.js 需要 `\r\n`。

**解决**：在 shell-bridge 中替换换行符：
```javascript
ws.send(d.toString().replace(/\r?\n/g, '\r\n'));
```

### 4.4 命令重复显示（双重回显）

**问题**：输入的命令在终端显示两次。

**原因**：前端 `sendCmd()` 函数中手动写入了 `term.write(cmd)`，而交互式 Shell 本身也会回显输入。

**解决**：删除前端的本地回显，只通过 WebSocket 发送，让 Shell 自行回显。

### 4.5 WebView 中键盘输入不工作

**问题**：在 OpenHarmony WebView 中，xterm.js 的内置键盘输入无法使用。

**原因**：xterm.js 通过隐藏的 textarea 捕获键盘输入，但 OpenHarmony WebView 对此支持不佳。

**解决**：
1. 设置 `disableStdin: true` 禁用 xterm 内置输入
2. 添加显式输入栏：`<input>` + `Run` 按钮 + `Tab` 按钮 + `C-c` 按钮
3. 隐藏 xterm 内部 textarea：`display: none !important`

### 4.6 鼠标光标消失

**问题**：鼠标移到输入框区域后消失。

**原因**：xterm.css 中的样式覆盖了鼠标光标。

**解决**：强制设置光标样式：
```css
html, body { cursor: auto !important; }
#input-bar, #input-bar * { cursor: auto !important; }
#term .xterm-screen { pointer-events: none !important; }
```

### 4.7 鼠标事件干扰

**问题**：xterm.js 终端区域拦截所有触摸/鼠标事件，导致输入框无法获取焦点。

**原因**：xterm 的 screen 层覆盖在输入栏上方，拦截了所有事件。

**解决**：
1. 用 Flexbox 布局替代 `position: fixed`，终端区域和输入栏不重叠
2. 设置 `pointer-events: none` 禁止 xterm 拦截鼠标事件
3. 点击终端区域自动聚焦输入框

### 4.8 桌面图标不显示

**问题**：安装后桌面上看不到应用图标。

**原因**：
1. `layered_image`（分层图标）在 OpenHarmony 4.1 桌面上支持不佳
2. `skills` 中缺少 `action.system.home`（OpenHarmony 4.1 桌面识别的 action）

**解决**：
1. 图标改用单个 PNG 文件 `$media:app_icon`，不用 `$media:layered_image`
2. skills 中同时添加 `action.system.home` 和 `ohos.want.action.home`

### 4.9 HAP 启动失败

**问题**：`error: failed to start ability. error: resolve ability err.`

**原因**：使用了错误的 bundleName（`com.example.hellohap`），实际应为 `com.openclaw.hellohap`。

**解决**：从 `AppScope/app.json5` 确认正确的 bundleName 后使用。

---

## 五、项目文件结构

```
HelloHap/
├── AppScope/
│   ├── app.json5                          # 应用配置（包名、图标、名称）
│   └── resources/base/
│       ├── element/string.json            # app_name: "终端"
│       └── media/
│           └── app_icon.png               # 应用图标（黑底白字"终端"）
├── shell-bridge.mjs                       # Node.js WebSocket桥接脚本（源码）
└── entry/src/main/
    ├── module.json5                       # 模块配置
    ├── ets/
    │   ├── entryability/EntryAbility.ets  # 入口 Ability
    │   └── pages/Index.ets                # WebView 页面
    └── resources/
        ├── base/
        │   ├── element/string.json        # EntryAbility_label: "终端"
        │   └── media/
        │       ├── app_icon.png           # 应用图标
        │       └── startIcon.png          # 启动窗口图标
        └── rawfile/
            ├── terminal.html              # xterm.js 终端页面
            ├── xterm.js                   # xterm.js 库
            └── xterm.css                  # xterm.js 样式
```

---

## 六、使用说明

### 日常使用

1. 确保 shell-bridge 正在运行
2. 打开"终端"应用（或通过 `hdc shell aa start` 启动）
3. 在底部输入框输入命令，点击 **Run** 或按 **Enter** 执行
4. 点击 **Tab** 发送 Tab 补全
5. 点击 **C-c** 发送 Ctrl+C 中断当前命令

### 可执行的命令示例

```bash
ls -la /                   # 列出根目录
cat /etc/os-release        # 查看系统版本
ps -ef                     # 查看进程
netstat -tlnp              # 查看端口监听
mount                      # 查看挂载点

# 启动 openclaw gateway
HOME=/data/local/tmp LD_LIBRARY_PATH=/system/lib64 /data/local/tmp/node /data/local/tmp/openclaw/openclaw.mjs gateway run --bind lan --port 18800 --force
```

> **注意**：所有原来通过 `hdc shell "..."` 执行的命令，去掉外层的 `hdc shell ""`，直接在终端输入即可。
