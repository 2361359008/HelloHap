# 通过 HAP 应用访问 OpenClaw Web UI

## 一、原理

OpenHarmony 自带浏览器强制 HTTPS，无法访问 HTTP 服务。解决方案是利用 HAP 应用内置的 WebView 组件，通过 `mixedMode(MixedMode.All)` 允许加载 HTTP 页面，直接访问设备上运行的 OpenClaw Gateway Web UI。

```
HAP 应用
├── 选择页面（终端 Shell / OpenClaw Web UI）
│
├── 终端 Shell → WebView 加载 terminal.html（本地文件）
│                  ↓ ws://localhost:7681
│                  shell-bridge.js → /bin/sh
│
└── OpenClaw Web UI → WebView 加载 http://localhost:18800/
                       ↓
                       OpenClaw Gateway（设备本机运行）
```

## 二、实现

### 2.1 Index.ets 代码

文件位置：`entry/src/main/ets/pages/Index.ets`

```typescript
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  @State currentMode: string = '';

  build() {
    Column() {
      if (this.currentMode === '') {
        // 选择页面
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
        // WebView 页面
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
              : 'http://localhost:18800/#token=openclaw-rk3568-token-2026',
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

### 2.2 关键配置

**WebView 属性**：

| 属性 | 值 | 说明 |
|------|-----|------|
| `javaScriptAccess` | `true` | 允许 JS 执行 |
| `domStorageAccess` | `true` | 允许 DOM 存储（Web UI 需要） |
| `mixedMode` | `MixedMode.All` | 允许加载 HTTP 内容 |
| `layoutWeight(1)` | - | WebView 占满剩余空间 |

**Gateway URL 格式**：
```
http://localhost:18800/#token=<你的gateway token>
```

URL 中的 `#token=` 会自动完成认证，无需手动输入令牌。

### 2.3 获取 Gateway Token

Token 存储在设备配置文件中：
```powershell
hdc shell "cat /data/local/tmp/.openclaw/openclaw.json"
```

在输出的 JSON 中找到：
```json
"gateway": {
  "auth": {
    "token": "openclaw-rk3568-token-2026"
  }
}
```

如需修改 URL 中的 token，编辑 `Index.ets` 第 73 行的 URL。

## 三、编译部署

```powershell
# 1. DevEco Studio 中 Build → Build Hap(s)

# 2. 安装到设备
hdc install D:\DevEcoProjects\HelloHap\entry\build\default\outputs\default\entry-default-signed.hap

# 3. 启动（或直接在桌面点击图标）
hdc shell aa start -a EntryAbility -b com.openclaw.hellohap
```

## 四、前置条件

确保 OpenClaw Gateway 已在设备上运行（端口 18800）：
```powershell
hdc shell "netstat -tlnp 2>/dev/null | grep 18800"
```

如果 gateway 未运行，参考 openclaw 部署文档启动。

## 五、使用方式

1. 打开"终端" HAP 应用
2. 看到选择页面，点击 **OpenClaw Web UI**
3. 自动加载 gateway 页面并完成认证
4. 点击顶部 **← 返回** 可切回选择页面
