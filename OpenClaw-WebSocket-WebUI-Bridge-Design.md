# 馃 OpenClaw - HAP Native WebSocket & Web UI 橋接設計文檔

本設計文檔詳細記錄並存檔了 OpenHarmony 終端應用（HAP）中，**原生 ArkUI 聊天對話模塊**與 **OpenClaw 後台智能網關（Gateway）**之間的通信、對話創建、會話管理、以及**動態拉起/加載 Web UI** 的全套底層橋接架構與協議規範。

---

## 1. 總體系統架構 (System Architecture)

系統採用 **“原生極簡交互 + 特權後台代理 + 完整 Web 終端切換”** 的雙模架構：

```text
  +-------------------------------------------------------+
  |              HelloHap (HarmonyOS 客户端)              |
  |  +--------------------+       +--------------------+  |
  |  |   Native ArkUI     |       |   Web UI Panel     |  |
  |  |  (极简聊天 / 进度条)  |       | (WebView 完整终端) |  |
  |  +---------+----------+       +---------+----------+  |
  +------------|----------------------------|-------------+
               | (WebSocket RPC)            | (HTTP Redirect with Token)
               v                            v
  +-------------------------------------------------------+
  |               OpenClaw Gateway (:18800)               |
  |  - 负责 Agent 对话生成                                 |
  |  - 提供 Web 编译文件树与集成终端控制                    |
  +-------------------------------------------------------+
```

* **原生對話模式 (Native Chat)**：使用原生 ArkUI 的 `WebSocket` 客戶端與 OpenClaw 網關建立 RPC 連接，負責輕量級的進度條同步、流式（Streaming）消息渲染、和關卡初始化。
* **Web UI 整合模式 (Embedded Web UI)**：在應用內嵌入原生的 `WebView` 組件，加載 OpenClaw 提供的完整 Visual IDE/Terminal Web 界面。
* **雙態會話共享 (Session State Sharing)**：兩者使用**同一個 `sessionKey`** 和 **同一個 `token`**。無論在原生還是 Web 端，AI 都能無縫讀取歷史會話軌跡，狀態 100% 同步。

---

## 2. WebSocket RPC 通信協議規範 (RPC Protocol)

HAP 原生端與 OpenClaw 建立的長連接協議基於 **JSON-RPC 風格**。

### 2.1 連接與安全握手 (Connection & Handshake)
HAP 啟動後，建立到 `ws://127.0.0.1:18800` 的 WebSocket 連接。首個發送的數據包必須是安全握手包，攜帶從板載 `shell-bridge` 獲取的 Gateway 授權憑證。

#### 請求報文 (Request):
```json
{
  "type": "req",
  "id": "handshake-00001",
  "method": "handshake",
  "payload": {
    "token": "oc_gw_tkn_8f3d9b0e271a4c..."
  }
}
```

#### 響應報文 (Response):
```json
{
  "type": "res",
  "id": "handshake-00001",
  "ok": true,
  "payload": {}
}
```

### 2.2 創建/加入對話會話 (Session Joining)
握手成功後，HAP 根據當前實訓關卡，向網關請求加入指定的隔離會話。

#### 請求報文 (Request):
```json
{
  "type": "req",
  "id": "join-session-00002",
  "method": "session.join",
  "payload": {
    "sessionKey": "oh61-level-2"
  }
}
```

#### 響應報文 (Response):
```json
{
  "type": "res",
  "id": "join-session-00002",
  "ok": true,
  "payload": {
    "sessionKey": "oh61-level-2",
    "created": true
  }
}
```

### 2.3 發送對話與 AI 流式回傳 (Chat & Stream)
學員在原生界面發送消息、或者點擊“呼叫 OpenClaw”按鈕時，下發對話請求。網關將以 `event` 機制流式（Chunked Delta）推送 AI 的推理文本。

#### 對話發送請求 (Chat Send Request):
```json
{
  "type": "req",
  "id": "chat-send-00003",
  "method": "chat.send",
  "payload": {
    "sessionKey": "oh61-level-2",
    "message": {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "請幫我執行 sh build_sign_install_run.sh --sign-only 完成簽名"
        }
      ]
    }
  }
}
```

#### 流式 Delta 事件 (Streaming Delta Event) - 多次推送:
```json
{
  "type": "event",
  "event": "chat",
  "payload": {
    "state": "delta",
    "text": "好的，我正在为您读取第二关的签名记忆文档..."
  }
}
```

#### 最終完成事件 (Final Event) - 結束標誌:
```json
{
  "type": "event",
  "event": "chat",
  "payload": {
    "state": "final",
    "text": "好的，我正在为您读取第二关的签名记忆文档... 编译成功并已生成 /data/local/tmp/entry-signed.hap 包！"
  }
}
```

---

## 3. WebView Web UI 喚起與加載機制 (WebView Bridge)

當用戶在 HAP 中點擊 **“📄 實操終端”** 標籤頁時，原生界面將隱藏 ArkUI 聊天模塊，顯示 `Web` 組件並自動跨域、免密加載完整的 OpenClaw 控制台。

```text
  [Index.ets (ArkUI)]
          |
          | 1. 加载本地沙盒原生页面
          v
  [rawfile/openclaw-loader.html (WebView 内)]
          |
          | 2. fetch() 请求特权代理
          v
  [shell-bridge (:7681/get-token)] ----> 返回当前 Gateway 实时 Token
          |
          | 3. window.location.replace()
          v
  [OpenClaw Gateway Web UI (:18800)] ---> 带 Token Hash 完美秒开！
```

### 3.1 本地引導加載器 (openclaw-loader.html)
由於 OpenHarmony 的沙箱 DNS 安全限制，WebView 無法直接跨域獲取 Token。我們設計了一個本地引導頁面 `openclaw-loader.html` 放置在 HAP 的 `rawfile` 中：

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>OpenClaw Connecting...</title>
</head>
<body>
  <div style="text-align:center; padding-top:100px; font-family:sans-serif;">
    <h2>正在連接到物理開發板 OpenClaw 實操終端...</h2>
  </div>
  <script>
    // 1. 通过回环地址请求特权后台 shell-bridge 获取实时登录令牌
    fetch('http://127.0.0.1:7681/get-token')
      .then(res => res.json())
      .then(data => {
        const token = data.token;
        const sessionKey = window.location.search.replace('?session=', '') || 'main';
        // 2. 利用 Hash 路由直接重定向到后端的 Web UI，绕过跨域并完成自动单点登录
        const targetUrl = `http://127.0.0.1:18800/#token=${token}&session=${sessionKey}`;
        window.location.replace(targetUrl);
      })
      .catch(err => {
        document.body.innerHTML = `<h3>連線失敗: ${err.message}</h3>`;
      });
  </script>
</body>
</html>
```

### 3.2 HAP 端 Web 組件動態喚醒 (ArkUI Layout)
在 HAP 的 `Index.ets` 中，我們聲明 `Web` 組件，並在切換時動態傳入當前的 `sessionKey`，實現對話上下文的實時綁定：

```typescript
// 声明 WebView 控制器
webController: WebController = new WebController();

build() {
  Column() {
    if (this.currentTab === 'terminal') {
      // 动态唤起 WebView 加载本地引导页，实现 Web UI 单点登录
      Web({ 
        src: 'resource://rawfile/openclaw-loader.html?session=' + this.selectedTaskSessionKey, 
        controller: this.webController 
      })
      .domStorageAccess(true)
      .imageAccess(true)
      .mixedMode(MixedModeContent.All) // 允许混合加载 HTTP + Local 资源
      .width('100%')
      .layoutWeight(1)
    } else {
      // 渲染原生极简聊天列表及交互按钮
      this.buildNativeChatPanel()
    }
  }
}
```

---

## 4. 安全與容錯設計 (Security & Fault Tolerance)

1. **混合內容加載 (Mixed Mode Content)**：OpenHarmony API 23+ 默認封鎖 HTTP/Local 混合加載。我們必須在 `Web` 組件上顯式啟用 `.mixedMode(MixedModeContent.All)`，以保證 `openclaw-loader.html`（本端）能流暢 `fetch` 重定向到 `18800` 連接。
2. **會話持久化與防混淆**：
   * 原生 RPC 發送時，`payload` 內必須強制攜帶對應關卡的 `sessionKey`；
   * WebView 引導加載時，在 Search 查詢參數中攜帶 `?session=oh61-level-X`；
   * 這保證了用戶在原生聊天時，Web 端對應的文件管理器、終端命令行在後台處於**同一個沙盒**，不會造成跨關卡代碼污染。
3. **特權代理免密綁定**：本機 `shell-bridge` 特權 API 只對 `127.0.0.1` 開放，從物理機制上完全隔絕了外網惡意獲取 Token 的漏洞。

---

## 5. 存檔與變更歷史 (Changelog)

* **2026-05-28 (v1.0)**：首次設計 Native WebSocket RPC 通信與 Web 網關係列消息包結構。
* **2026-06-02 (v1.1)**：修復了 `openclaw-loader.html` 中 `localhost` 無法解析的沙箱 Bug，統一變更為 `127.0.0.1` 物理回環；修復了 ArkTS 流式 Delta 數據包解讀為 `[object Object]` 的富文本提取 Bug。
* **2026-06-03 (v1.2 - 本次版本)**：正式存檔 HAP Native 對話到 Web UI 加載創建的全套設計規範，並寫入專屬關卡考綱對齊。
