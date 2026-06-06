# RK3588 + OpenHarmony 5.1 HAP 迁移部署全流程

> 本文档记录将 OpenClaw 终端 HAP 应用从 **OpenHarmony 4.1.1（RK3568）** 迁移到 **OpenHarmony 5.1（RK3588）** 的完整过程，包含 SDK 升级、签名适配、WebView 白屏修复、Token 认证、开机自启等全部细节。

---

## 一、环境信息

| 项目 | 旧环境 | 新环境 |
|------|--------|--------|
| **开发板** | RK3568 | RK3588 |
| **系统版本** | OpenHarmony 4.1.1 简化版 | OpenHarmony 5.1 |
| **API Level** | 11 | 18 |
| **DevEco Studio** | 已安装 | 已安装（同一台 PC） |
| **SDK 路径** | `D:\OpenHarmony` | `D:\OpenHarmony`（新增 API 18） |
| **项目路径** | `D:\DevEcoProjects\HelloHap` | 同左 |
| **包名** | `com.openclaw.hellohap` | 同左 |

### 1.1 PC 端工具

- DevEco Studio（含 JBR：`D:\DevEcoStudio\DevEco Studio\jbr\bin\java.exe`）
- hdc（OpenHarmony 设备连接工具）
- OpenHarmony 5.1 SDK（API 18）

### 1.2 设备端预置

- Node.js：`/data/local/tmp/node`
- OpenClaw Gateway：`/data/local/tmp/openclaw/openclaw.mjs`
- Shell Bridge：`/data/local/tmp/shell-bridge.js`
- ws 模块：`/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules`

---

## 二、SDK 与构建配置升级

### 2.1 安装 OpenHarmony 5.1 SDK

在 DevEco Studio 中：

1. **File → Settings → OpenHarmony SDK**
2. 选择 **OpenHarmony**（不是 HarmonyOS）
3. 勾选 **API 18** 并安装
4. SDK 安装路径：`D:\OpenHarmony\18`

> 如果网络受限，可手动下载 SDK 后放到 `D:\OpenHarmony\18` 目录。

### 2.2 修改 build-profile.json5

**核心变更**：SDK 版本从字符串格式改为整数格式，`runtimeOS` 改为 `OpenHarmony`。

```json5
// D:\DevEcoProjects\HelloHap\build-profile.json5
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "compileSdkVersion": 18,
        "compatibleSdkVersion": 18,
        "targetSdkVersion": 18,
        "runtimeOS": "OpenHarmony",
        "buildOption": {
          "strictMode": {
            "caseSensitiveCheck": true,
            "useNormalizedOHMUrl": false
          }
        }
      }
    ],
    "buildModeSet": [
      { "name": "debug" },
      { "name": "release" }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        {
          "name": "default",
          "applyToProducts": ["default"]
        }
      ]
    }
  ]
}
```

**关键改动说明**：

| 字段 | 旧值（OH 4.1） | 新值（OH 5.1） | 说明 |
|------|----------------|----------------|------|
| `compileSdkVersion` | `"6.0.2(22)"` | `18` | OH 必须用整数 |
| `compatibleSdkVersion` | `"4.1.0(11)"` | `18` | OH 必须用整数 |
| `targetSdkVersion` | `"6.0.2(22)"` | `18` | OH 必须用整数 |
| `runtimeOS` | `"HarmonyOS"` | `"OpenHarmony"` | 切换运行时 |
| `signingConfigs` | HarmonyOS 证书配置 | `[]`（空数组） | 手动签名 |

> ⚠️ **坑**：如果 SDK 版本写成字符串（如 `"18"`），编译会报错。OpenHarmony 工程**必须用整数**。

### 2.3 修改 app.json5 — 分层图标

OH 5.x 桌面要求使用分层图标（layered image），否则桌面上不显示应用图标。

```json5
// D:\DevEcoProjects\HelloHap\AppScope\app.json5
{
  "app": {
    "bundleName": "com.openclaw.hellohap",
    "vendor": "example",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:layered_image",   // ← 改为 layered_image
    "label": "$string:app_name"
  }
}
```

分层图标定义文件 `AppScope/resources/base/media/layered_image.json`：

```json
{
  "layered-image": {
    "background": "$media:background",
    "foreground": "$media:foreground"
  }
}
```

需要在 `AppScope/resources/base/media/` 下放置：
- `background.png` — 图标背景层
- `foreground.png` — 图标前景层

> **对比 OH 4.1**：旧版使用单个 PNG 图标 `$media:app_icon`，OH 5.x 必须改为分层图标。

### 2.4 修改 module.json5

```json5
// D:\DevEcoProjects\HelloHap\entry\src\main\module.json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "description": "$string:module_desc",
    "mainElement": "EntryAbility",
    "deviceTypes": ["default"],
    "deliveryWithInstall": true,
    "installationFree": false,
    "pages": "$profile:main_pages",
    "metadata": [
      {
        "name": "ohos.net.network_security_config",
        "resource": "$profile:network_config"
      }
    ],
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "$string:EntryAbility_desc",
        "icon": "$media:layered_image",           // ← 分层图标
        "label": "$string:EntryAbility_label",
        "startWindowIcon": "$media:startIcon",
        "startWindowBackground": "$color:start_window_background",
        "exported": true,
        "skills": [
          {
            "entities": ["entity.system.home"],
            "actions": [
              "action.system.home",
              "ohos.want.action.home"
            ]
          }
        ]
      }
    ],
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" }
    ]
  }
}
```

**关键改动**：

| 改动 | 说明 |
|------|------|
| `icon` → `$media:layered_image` | OH 5.x 需要分层图标 |
| 新增 `metadata` → `network_security_config` | 允许 HTTP 明文通信 |
| `skills` 同时包含 `action.system.home` 和 `ohos.want.action.home` | 兼容不同版本桌面 |

### 2.5 添加网络安全配置

OH 5.x 默认禁止 HTTP 明文流量。因为 WebView 需要访问 `http://localhost:18800`，必须添加白名单。

创建文件 `entry/src/main/resources/base/profile/network_config.json`：

```json
{
  "network-security-config": {
    "base-config": {
      "cleartextTraffic": true
    },
    "domain-config": [
      {
        "cleartextTraffic": true,
        "domains": [
          { "include-subdomains": true, "name": "localhost" },
          { "include-subdomains": true, "name": "127.0.0.1" }
        ]
      }
    ]
  }
}
```

---

## 三、签名流程

OH 5.1 不能使用 HarmonyOS 证书签名，需要 OpenHarmony 专用证书。

### 3.1 签名材料准备

`build-profile.json5` 中 `signingConfigs` 留空，编译后手动签名。

签名所需文件（放在 `HelloHap/signature/` 目录）：

| 文件 | 说明 |
|------|------|
| `OpenHarmony.p12` | 密钥库（KeyStore），包含应用私钥 |
| `OpenHarmonyAppChain.pem` | 应用证书链（CA + 中间证书 + 应用证书） |
| `HelloHap_debug.p7b` | 调试签名 Profile |
| `OpenHarmonyCA.pem` | CA 根证书 |
| `OpenHarmonyApplication.pem` | 应用证书 |

### 3.2 生成签名材料（如果没有）

使用 DevEco Studio 内置的 `hap-sign-tool.jar`（位于 `D:\OpenHarmony\18\toolchains\lib\hap-sign-tool.jar`）：

```powershell
$JAVA = "D:\DevEcoStudio\DevEco Studio\jbr\bin\java.exe"
$SIGN_TOOL = "D:\OpenHarmony\18\toolchains\lib\hap-sign-tool.jar"

# 1. 生成密钥对
& $JAVA -jar $SIGN_TOOL generate-keypair `
  -keyAlias "openharmony application release" `
  -keyPwd 123456 `
  -keyAlg ECC -keySize NIST-P-256 `
  -keystoreFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmony.p12" `
  -keystorePwd 123456

# 2. 生成 CSR
& $JAVA -jar $SIGN_TOOL generate-csr `
  -keyAlias "openharmony application release" `
  -keyPwd 123456 `
  -keystoreFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmony.p12" `
  -keystorePwd 123456 `
  -outFile "D:\DevEcoProjects\HelloHap\signature\app.csr"

# 3. 生成 CA 根证书
& $JAVA -jar $SIGN_TOOL generate-ca `
  -keyAlias "openharmony application ca" `
  -keyPwd 123456 `
  -keyAlg ECC -keySize NIST-P-256 `
  -subject "C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application CA" `
  -validity 3650 `
  -keystoreFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmony.p12" `
  -keystorePwd 123456 `
  -outFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmonyCA.pem"

# 4. 生成应用证书
& $JAVA -jar $SIGN_TOOL generate-app-cert `
  -keyAlias "openharmony application release" `
  -keyPwd 123456 `
  -issuer "C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application CA" `
  -issuerKeyAlias "openharmony application ca" `
  -issuerKeyPwd 123456 `
  -subject "C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application Release" `
  -validity 3650 `
  -keystoreFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmony.p12" `
  -keystorePwd 123456 `
  -outFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmonyApplication.pem"

# 5. 合并证书链
Get-Content "D:\DevEcoProjects\HelloHap\signature\OpenHarmonyApplication.pem", `
            "D:\DevEcoProjects\HelloHap\signature\OpenHarmonyCA.pem" |
  Set-Content "D:\DevEcoProjects\HelloHap\signature\OpenHarmonyAppChain.pem" -Encoding ascii

# 6. 生成调试签名 Profile
& $JAVA -jar $SIGN_TOOL sign-profile `
  -keyAlias "openharmony application ca" `
  -keyPwd 123456 `
  -mode localSign `
  -signAlg SHA256withECDSA `
  -keystoreFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmony.p12" `
  -keystorePwd 123456 `
  -inFile "D:\DevEcoProjects\HelloHap\signature\HelloHap_debug_profile.json" `
  -outFile "D:\DevEcoProjects\HelloHap\signature\HelloHap_debug.p7b"
```

其中 `HelloHap_debug_profile.json` 是调试 Profile 模板，需要包含正确的 `bundle-name`（`com.openclaw.hellohap`）和设备 UDID。

### 3.3 编译并签名 HAP

```powershell
# 1. 在 DevEco Studio 中：Build → Build Hap(s)
#    生成未签名 HAP：entry/build/default/outputs/default/entry-default-unsigned.hap

# 2. 手动签名
$JAVA = "D:\DevEcoStudio\DevEco Studio\jbr\bin\java.exe"
$SIGN_TOOL = "D:\OpenHarmony\18\toolchains\lib\hap-sign-tool.jar"

& $JAVA -jar $SIGN_TOOL sign-app `
  -keyAlias "openharmony application release" `
  -signAlg SHA256withECDSA `
  -mode localSign `
  -appCertFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmonyAppChain.pem" `
  -profileFile "D:\DevEcoProjects\HelloHap\signature\HelloHap_debug.p7b" `
  -inFile "D:\DevEcoProjects\HelloHap\entry\build\default\outputs\default\entry-default-unsigned.hap" `
  -keystoreFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmony.p12" `
  -outFile "D:\DevEcoProjects\HelloHap\entry\build\default\outputs\default\entry-default-signed.hap" `
  -keyPwd 123456 `
  -keystorePwd 123456 `
  -signCode 1

# 3. 安装到设备
hdc install -r D:\DevEcoProjects\HelloHap\entry\build\default\outputs\default\entry-default-signed.hap

# 4. 启动
hdc shell aa start -a EntryAbility -b com.openclaw.hellohap
```

---

## 四、WebView 白屏问题排查与修复

### 4.1 现象

HAP 安装启动后，点击"终端 Shell"或"OpenClaw Web UI"，WebView 区域全白，无任何内容渲染。

### 4.2 排查过程

**步骤 1：测试最小 data URL**

将 `Index.ets` 中 WebView src 临时改为：
```typescript
src: 'data:text/html,<h1 style="color:red;font-size:80px">HELLO</h1>'
```
结果：**依然白屏** → 说明不是页面/网络问题，是 WebView 引擎本身无法渲染。

**步骤 2：检查 ArkWebCore**

```bash
hdc shell "ls -la /system/lib64/ | grep arkweb"
hdc shell "bm dump -n com.ohos.arkwebcore"
```
确认 ArkWebCore（Chromium 引擎 HSP）已安装。

**步骤 3：检查 GPU 设备节点**

```bash
hdc shell "ls -la /dev/mali0 /dev/dri/"
```
确认 GPU 设备节点存在（`/dev/mali0`）。

**步骤 4：检查 SELinux 审计日志**

```bash
hdc shell "dmesg | grep denied | grep -i mali"
```

发现大量 SELinux 拒绝日志：
```
avc: denied { read write } for ... path="/dev/mali0" ... scontext=u:r:debug_hap:s0 ...
```

**根因**：SELinux enforcing 模式下，`debug_hap` 域的进程（即调试签名的 HAP）被禁止访问 `/dev/mali0` GPU 设备，导致 Chromium 无法使用 GPU 加速，WebView 完全无法渲染。

### 4.3 解决方案：设置 SELinux 为 permissive

```bash
# 临时生效（设备重启后恢复）
hdc shell setenforce 0

# 验证
hdc shell getenforce
# 输出：Permissive
```

设置后重启 HAP，WebView 立即正常渲染。

> ⚠️ **注意**：这是开发/调试阶段的解决方案。生产环境应编写 SELinux policy 允许 HAP 进程访问 GPU 设备节点，而非关闭 SELinux。

### 4.4 永久生效方案

见第六节"开机自启动脚本"，在开机脚本中加入 `setenforce 0`。

---

## 五、OpenClaw Token 动态认证（设备无关方案）

### 5.1 问题

WebView 直接加载 `http://localhost:18800` 会因为缺少 token 显示 unauthorized。

最初的"快糙猛"方案是把 token 硬编码到 `Index.ets` 的 URL：
```typescript
src: 'http://localhost:18800/#token=085c1c167a9b5486430e9d1aeba3b6292c62ba6da05fab3f'
```

**缺点**：
- token 与具体设备绑定，HAP 无法通用
- token 变更必须重编、重签、重装 HAP
- 多台设备需要做不同版本

### 5.2 动态 Token 方案

**思路**：在设备端用 `shell-bridge` 暴露一个 HTTP `/token` 端点，HAP 端用一个 loader 页面在运行时 fetch token，再带 token 跳转到 gateway。

```
点击 "OpenClaw Web UI"
  ↓
WebView 加载 openclaw-loader.html (本地 rawfile)
  ↓
loader.html JS:  fetch http://localhost:7681/token
  ↓
shell-bridge.js: 读取 /data/local/tmp/.openclaw/openclaw.json → 返回 token
  ↓
loader.html JS:  window.location.replace('http://localhost:18800/#token=' + token)
  ↓
OpenClaw Web UI 认证成功
```

**好处**：
- HAP 不含任何 token，可在任何运行 OpenClaw 的设备上直接使用
- token 变更无需重编 HAP，loader 每次都拿最新值
- token 不进 APK 源码与镜像，安全性更好

### 5.3 修改 shell-bridge.js（设备端）

让 WebSocket 与 HTTP 共用 `:7681` 端口，新增 `GET /token` 端点：

```javascript
// HelloHap/shell-bridge.mjs
const { spawn } = require('child_process');
const { createServer } = require('http');
const { readFileSync } = require('fs');
const { WebSocketServer } = require('ws');

const PORT = 7681;
const OPENCLAW_CONFIG = '/data/local/tmp/.openclaw/openclaw.json';

// HTTP 服务：GET /token 返回实时 gateway token
const server = createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/token') {
    try {
      const config = JSON.parse(readFileSync(OPENCLAW_CONFIG, 'utf8'));
      const token = (config.gateway && config.gateway.auth && config.gateway.auth.token) || '';
      res.writeHead(200, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
      res.end(token);
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
      res.end('error: ' + e.message);
    }
    return;
  }
  res.writeHead(404);
  res.end('Not Found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[shell-bridge] listening on :${PORT} (HTTP + WebSocket)`);
});

// WebSocket 挂在同一个 HTTP server 上
const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  // ... 原有 shell 桥接逻辑不变 ...
});
```

**关键点**：
- `WebSocketServer({ server })` 让 ws 与 http 共用端口
- `/token` 每次请求都重新读 `openclaw.json`，配置文件改了立即生效
- 加 `Access-Control-Allow-Origin: *`，允许 WebView 跨源 fetch

### 5.4 创建 loader 页面

新文件 `entry/src/main/resources/rawfile/openclaw-loader.html`：

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>OpenClaw Loading...</title>
  <style>
    body { background:#1e1e2e; color:#cdd6f4; display:flex; align-items:center;
           justify-content:center; height:100vh; font-family:sans-serif; text-align:center; }
    .spinner { width:40px; height:40px; border:4px solid #313244; border-top:4px solid #89b4fa;
               border-radius:50%; animation:spin 0.8s linear infinite; margin:0 auto 20px; }
    @keyframes spin { to { transform:rotate(360deg); } }
    .error { color:#f38ba8; display:none; }
  </style>
</head>
<body>
<div>
  <div class="spinner" id="spinner"></div>
  <div id="status">正在获取认证信息...</div>
  <div class="error" id="error"></div>
</div>
<script>
var GATEWAY_URL = 'http://localhost:18800/';
var TOKEN_URL   = 'http://localhost:7681/token';
var MAX_RETRY   = 10;
var attempt = 0;

function loadToken() {
  attempt++;
  fetch(TOKEN_URL)
    .then(function(r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.text();
    })
    .then(function(token) {
      token = token.trim();
      if (!token) throw new Error('empty token');
      window.location.replace(GATEWAY_URL + '#token=' + token);
    })
    .catch(function(err) {
      document.getElementById('error').style.display = 'block';
      document.getElementById('error').textContent = '获取 Token 失败: ' + err.message;
      if (attempt < MAX_RETRY) setTimeout(loadToken, 2000);
      else document.getElementById('status').textContent = '请检查 shell-bridge 是否启动';
    });
}
loadToken();
</script>
</body>
</html>
```

带 10 次重试，可优雅处理 shell-bridge 启动慢的情况。

### 5.5 修改 Index.ets

把硬编码 URL 改成 loader 页面：

```typescript
// entry/src/main/ets/pages/Index.ets
Web({
  src: this.currentMode === 'terminal'
    ? $rawfile('terminal.html')
    : $rawfile('openclaw-loader.html'),  // ← 不再写 token
  controller: this.controller
})
```

### 5.6 部署与验证

```powershell
# 1. 推送新版 shell-bridge 并重启
hdc file send D:\DevEcoProjects\HelloHap\shell-bridge.mjs /data/local/tmp/shell-bridge.js
hdc shell "pkill -f shell-bridge; sleep 1"
hdc shell "HOME=/data/local/tmp LD_LIBRARY_PATH=/system/lib64:/vendor/lib64 NODE_PATH=/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules /data/local/tmp/node /data/local/tmp/shell-bridge.js > /data/local/tmp/shell-bridge.log 2>&1 &"

# 2. 验证 token 端点
hdc fport tcp:7681 tcp:7681
Invoke-RestMethod -Uri http://localhost:7681/token
# 预期输出：085c1c167a9b5486430e9d1aeba3b6292c62ba6da05fab3f

# 3. 重新编译 + 签名 + 安装 HAP（最后一次写死改动，以后 token 变了无需重编）
# 见第 3.3 节流程
```

打开 HAP，点击 "OpenClaw Web UI"：
- 短暂显示 loader "正在获取认证信息..."
- 自动跳转到 gateway 完整 UI（已登录）

**注意**：`Index.ets` 改成 loader 后，`shell-bridge.js` 必须随 HAP 一起更新到设备上的新版（含 `/token` 端点），否则 loader 会一直重试失败。两者一起部署即可。

---

## 六、开机自启动脚本

### 6.1 init 服务配置

设备上已有 OpenClaw 的 init 服务配置文件：

```
/system/etc/init/openclaw.cfg
```

内容：
```json
{
    "services" : [{
            "name" : "openclaw",
            "path" : ["/system/bin/sh", "/data/local/tmp/bin/openclaw-boot.sh"],
            "uid" : "root",
            "gid" : ["root"],
            "once" : 1,
            "importance" : 0,
            "start-mode" : "boot",
            "ondemand" : false,
            "sandbox" : 0,
            "disabled" : 0
        }
    ]
}
```

开机时 init 系统会自动执行 `/data/local/tmp/bin/openclaw-boot.sh`。

### 6.2 开机脚本（完整版）

更新后的 `/data/local/tmp/bin/openclaw-boot.sh`，新增了 **SELinux permissive** 和 **shell-bridge 自动启动**：

```bash
#!/system/bin/sh
# OpenClaw 开机自启脚本
# 由 /system/etc/init/openclaw.cfg 触发

# 等待系统关键服务就绪（网络 / 文件系统）
sleep 10

# 环境变量
export HOME=/data/local/tmp
export PATH=/data/local/tmp/bin:/system/bin:/vendor/bin
export LD_LIBRARY_PATH=/system/lib64:/vendor/lib64
export NODE_PATH=/data/local/tmp/openclaw/node_modules/.pnpm/ws@8.19.0/node_modules

LOG=/data/local/tmp/.openclaw/boot.log
mkdir -p /data/local/tmp/.openclaw

# ★ 设置 SELinux 为 permissive（解决 WebView 白屏）
setenforce 0 >> "$LOG" 2>&1

echo "=============================================" >> "$LOG"
echo "$(date) openclaw boot start" >> "$LOG"
echo "$(date) selinux=$(getenforce 2>/dev/null)" >> "$LOG"

# ★ 启动 shell-bridge（终端 Shell 后端，监听 :7681）
if ! netstat -tlnp 2>/dev/null | grep -q ':7681 '; then
    if [ -f /data/local/tmp/shell-bridge.js ]; then
        echo "$(date) starting shell bridge" >> "$LOG"
        /data/local/tmp/node /data/local/tmp/shell-bridge.js >> /data/local/tmp/shell-bridge.log 2>&1 &
    fi
else
    echo "$(date) shell bridge already running on :7681" >> "$LOG"
fi

# 避免重复启动 gateway
if netstat -tlnp 2>/dev/null | grep -q ':18800 '; then
    echo "$(date) openclaw already running on :18800, skip" >> "$LOG"
    exit 0
fi

# ★ 启动 OpenClaw Gateway（Web UI 后端，监听 :18800）
echo "$(date) openclaw starting gateway" >> "$LOG"
exec /data/local/tmp/node /data/local/tmp/openclaw/openclaw.mjs \
    gateway run --bind lan --port 18800 --force \
    >> "$LOG" 2>&1
```

### 6.3 部署开机脚本

```powershell
# 1. 在 PC 上编辑好脚本文件（如 D:\DevEcoProjects\openclaw-boot.sh）

# 2. 备份旧脚本
hdc shell cp /data/local/tmp/bin/openclaw-boot.sh /data/local/tmp/bin/openclaw-boot.sh.bak

# 3. 推送新脚本
hdc file send D:\DevEcoProjects\openclaw-boot.sh /data/local/tmp/bin/openclaw-boot.sh

# 4. 设置执行权限
hdc shell chmod 755 /data/local/tmp/bin/openclaw-boot.sh

# 5. 验证内容
hdc shell cat /data/local/tmp/bin/openclaw-boot.sh

# 6. 重启设备验证
hdc shell reboot
```

### 6.4 验证开机自启

设备启动完成后：

```powershell
# 检查 SELinux 状态
hdc shell getenforce
# 预期输出：Permissive

# 检查 shell-bridge 进程
hdc shell "ps -ef | grep shell-bridge | grep -v grep"
# 预期：node /data/local/tmp/shell-bridge.js

# 检查 gateway 进程
hdc shell "ps -ef | grep gateway | grep -v grep"
# 预期：openclaw-gateway

# 检查端口监听
hdc shell "netstat -tlnp | grep -E ':7681|:18800'"
# 预期：
# tcp  0  0  0.0.0.0:7681   0.0.0.0:*  LISTEN  .../node
# tcp  0  0  0.0.0.0:18800  0.0.0.0:*  LISTEN  .../openclaw-gateway

# 查看启动日志
hdc shell cat /data/local/tmp/.openclaw/boot.log
```

---

## 七、完整 Index.ets 代码

```typescript
// entry/src/main/ets/pages/Index.ets
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  @State currentMode: string = '';

  build() {
    Column() {
      if (this.currentMode === '') {
        Column() {
          Text('OpenClaw 终端')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#cdd6f4')
            .margin({ top: 80, bottom: 60 })

          Button('终端 Shell')
            .width('70%')
            .height(56)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#89b4fa')
            .fontColor('#1e1e2e')
            .borderRadius(12)
            .margin({ bottom: 20 })
            .onClick(() => { this.currentMode = 'terminal'; })

          Button('OpenClaw Web UI')
            .width('70%')
            .height(56)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#a6e3a1')
            .fontColor('#1e1e2e')
            .borderRadius(12)
            .margin({ bottom: 20 })
            .onClick(() => { this.currentMode = 'openclaw'; })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#1e1e2e')
      } else {
        Column() {
          Row() {
            Button('← 返回')
              .height(36)
              .fontSize(14)
              .backgroundColor('#585b70')
              .fontColor('#cdd6f4')
              .borderRadius(8)
              .onClick(() => { this.currentMode = ''; })
          }
          .width('100%')
          .padding({ left: 8, top: 4, bottom: 4 })
          .backgroundColor('#313244')

          Web({
            src: this.currentMode === 'terminal'
              ? $rawfile('terminal.html')
              : 'http://localhost:18800/#token=085c1c167a9b5486430e9d1aeba3b6292c62ba6da05fab3f',
            controller: this.controller
          })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .mixedMode(MixedMode.All)
            .width('100%')
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#1e1e2e')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1e1e2e')
  }
}
```

---

## 八、踩坑记录

### 8.1 SDK 版本格式错误

**问题**：`build-profile.json5` 中 `compileSdkVersion` 写成字符串 `"18"` 导致编译报错。

**解决**：OpenHarmony 工程 SDK 版本必须是**整数**（`18`），不是字符串。HarmonyOS 工程才使用字符串格式（如 `"6.0.2(22)"`）。

### 8.2 签名密码过短

**问题**：`hap-sign-tool.jar` 生成密钥时密码不足 6 位导致错误。

**解决**：密码至少 6 位（如 `123456`）。

### 8.3 Java 命令找不到

**问题**：PowerShell 中直接执行 `java` 找不到命令。

**解决**：使用 DevEco Studio 内置的 JBR：
```
D:\DevEcoStudio\DevEco Studio\jbr\bin\java.exe
```

### 8.4 WebView 白屏（SELinux）

**问题**：OH 5.1 上 WebView 完全白屏，包括最简单的 data URL 也不渲染。

**根因**：SELinux enforcing 模式下 `debug_hap` 域被拒绝访问 `/dev/mali0`（GPU），Chromium 引擎无法使用 GPU 加速。

**解决**：`setenforce 0` 设置 SELinux 为 permissive 模式。已写入开机脚本自动生效。

**审计日志特征**：
```
avc: denied { read write } for ... path="/dev/mali0" ... scontext=u:r:debug_hap:s0
```

### 8.5 HTTP 明文被阻止

**问题**：WebView 无法加载 `http://localhost:18800`。

**解决**：添加 `network_security_config` 允许 localhost 明文通信（见第 2.5 节）。

### 8.6 桌面图标不显示

**问题**：OH 5.x 桌面上看不到应用图标。

**解决**：
1. 图标改为 `$media:layered_image`（分层图标）
2. `skills` 同时包含 `action.system.home` 和 `ohos.want.action.home`

### 8.7 Token 硬编码导致设备绑定

**问题**：把 token 写死在 `Index.ets` 中，HAP 与具体设备绑定，token 变了就要重编。

**解决**：见第五节"动态认证方案"。`shell-bridge` 暴露 `/token` 端点，HAP 用 loader 页面运行时 fetch token 后跳转。HAP 不再含任何 token，可在任何设备直接使用。

### 8.8 Gateway 被 rate limit

**问题**：多次 token 错误后 gateway 触发限流，即使修正 token 也连不上。

**解决**：重启 gateway 进程清除限流状态：
```bash
hdc shell "pkill -f openclaw-gateway"
# 等待开机脚本自动重启，或手动启动：
hdc shell "HOME=/data/local/tmp LD_LIBRARY_PATH=/system/lib64:/vendor/lib64 nohup /data/local/tmp/node /data/local/tmp/openclaw/openclaw.mjs gateway run --bind lan --port 18800 --force > /data/local/tmp/.openclaw/gateway.out 2>&1 &"
```

---

## 九、项目文件结构

```
HelloHap/
├── AppScope/
│   ├── app.json5                                # 应用配置
│   └── resources/base/
│       ├── element/string.json                  # app_name
│       └── media/
│           ├── background.png                   # 分层图标背景
│           ├── foreground.png                   # 分层图标前景
│           └── layered_image.json               # 分层图标定义
├── signature/                                   # OpenHarmony 签名材料
│   ├── OpenHarmony.p12                          # 密钥库
│   ├── OpenHarmonyCA.pem                        # CA 根证书
│   ├── OpenHarmonyApplication.pem               # 应用证书
│   ├── OpenHarmonyAppChain.pem                  # 证书链
│   ├── HelloHap_debug.p7b                       # 调试签名 Profile
│   └── HelloHap_debug_profile.json              # Profile 模板
├── build-profile.json5                          # 构建配置（API 18）
├── shell-bridge.mjs                             # Shell 桥接脚本（源码）
└── entry/src/main/
    ├── module.json5                             # 模块配置
    ├── ets/
    │   ├── entryability/EntryAbility.ets        # 入口 Ability
    │   └── pages/Index.ets                      # 主页面（WebView）
    └── resources/
        ├── base/
        │   ├── element/string.json              # 字符串资源
        │   ├── media/
        │   │   ├── app_icon.png                 # 应用图标
        │   │   ├── background.png               # 分层图标背景
        │   │   ├── foreground.png               # 分层图标前景
        │   │   ├── layered_image.json           # 分层图标定义
        │   │   └── startIcon.png                # 启动窗口图标
        │   └── profile/
        │       └── network_config.json          # 网络安全配置
        └── rawfile/
            ├── terminal.html                    # xterm.js 终端页面
            ├── xterm.js                         # xterm.js 库
            └── xterm.css                        # xterm.js 样式
```

---

## 十、日常操作速查

```powershell
# === 编译签名安装一条龙 ===
# 1. DevEco Studio: Build → Build Hap(s)
# 2. 签名：
& "D:\DevEcoStudio\DevEco Studio\jbr\bin\java.exe" -jar D:\OpenHarmony\18\toolchains\lib\hap-sign-tool.jar sign-app -keyAlias "openharmony application release" -signAlg SHA256withECDSA -mode localSign -appCertFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmonyAppChain.pem" -profileFile "D:\DevEcoProjects\HelloHap\signature\HelloHap_debug.p7b" -inFile "D:\DevEcoProjects\HelloHap\entry\build\default\outputs\default\entry-default-unsigned.hap" -keystoreFile "D:\DevEcoProjects\HelloHap\signature\OpenHarmony.p12" -outFile "D:\DevEcoProjects\HelloHap\entry\build\default\outputs\default\entry-default-signed.hap" -keyPwd 123456 -keystorePwd 123456 -signCode 1
# 3. 安装：
hdc install -r D:\DevEcoProjects\HelloHap\entry\build\default\outputs\default\entry-default-signed.hap
# 4. 启动：
hdc shell aa start -a EntryAbility -b com.openclaw.hellohap

# === 设备状态检查 ===
hdc shell getenforce                                        # SELinux 状态
hdc shell "netstat -tlnp | grep -E ':7681|:18800'"          # 服务端口
hdc shell "ps -ef | grep -E 'shell-bridge|gateway'"         # 服务进程
hdc shell cat /data/local/tmp/.openclaw/boot.log            # 开机日志
hdc shell tail -20 /data/local/tmp/.openclaw/gateway.out    # Gateway 日志

# === 重启 Gateway（清除 rate limit 等） ===
hdc shell "pkill -f openclaw-gateway; sleep 2; HOME=/data/local/tmp LD_LIBRARY_PATH=/system/lib64:/vendor/lib64 nohup /data/local/tmp/node /data/local/tmp/openclaw/openclaw.mjs gateway run --bind lan --port 18800 --force > /data/local/tmp/.openclaw/gateway.out 2>&1 &"

# === 获取 Gateway Token ===
hdc shell cat /data/local/tmp/.openclaw/openclaw.json
```

---

## 十一、与 OH 4.1 的主要差异总结

| 差异点 | OH 4.1 (RK3568) | OH 5.1 (RK3588) |
|--------|------------------|------------------|
| API Level | 11 | 18 |
| SDK 版本格式 | 字符串 `"4.1.0(11)"` | 整数 `18` |
| 图标 | 单个 PNG `$media:app_icon` | 分层图标 `$media:layered_image` |
| HTTP 明文 | 默认允许 | 需 `network_security_config` 白名单 |
| WebView/GPU | 正常渲染 | SELinux 阻止 GPU 访问，需 permissive |
| 签名证书 | HarmonyOS 证书 | OpenHarmony 专用证书 |
| 开机脚本 | 仅启动 Gateway | 增加 setenforce 0 + shell-bridge |
