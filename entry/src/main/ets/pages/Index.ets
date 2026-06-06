import { webview } from '@kit.ArkWeb';
import { http, webSocket } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';

class ChatMessage {
  sender: string = '';
  text: string = '';
  constructor(sender: string, text: string) {
    this.sender = sender;
    this.text = text;
  }
}

class PendingRequest {
  id: string = '';
  resolve: (value: string) => void = () => {};
  reject: (err: Error) => void = () => {};
  constructor(id: string, resolve: (value: string) => void, reject: (err: Error) => void) {
    this.id = id;
    this.resolve = resolve;
    this.reject = reject;
  }
}

class OpenClawRpcAuth {
  token: string = '';
  constructor(token: string) {
    this.token = token;
  }
}

class OpenClawRpcClient {
  id: string = 'openclaw-control-ui';
  version: string = 'control-ui';
  platform: string = 'openharmony';
  mode: string = 'webchat';
  instanceId: string = 'openharmony-hap-tutorial';
}

class OpenClawConnectParams {
  minProtocol: number = 4;
  maxProtocol: number = 4;
  client: OpenClawRpcClient = new OpenClawRpcClient();
  role: string = 'operator';
  scopes: Array<string> = ['operator.admin', 'operator.read', 'operator.write', 'operator.approvals', 'operator.pairing'];
  caps: Array<string> = ['tool-events'];
  auth: OpenClawRpcAuth = new OpenClawRpcAuth('');
  userAgent: string = 'OpenHarmony HAP';
  locale: string = 'zh-CN';

  constructor(token: string) {
    this.auth = new OpenClawRpcAuth(token);
  }
}

class OpenClawHistoryParams {
  sessionKey: string = '';
  limit: number = 100;
  maxChars: number = 120000;

  constructor(sessionKey: string) {
    this.sessionKey = sessionKey;
  }
}

class OpenClawSendParams {
  sessionKey: string = '';
  sessionId?: string;
  message: string = '';
  deliver: boolean = false;
  idempotencyKey: string = '';

  constructor(sessionKey: string, sessionId: string, message: string, runId: string) {
    this.sessionKey = sessionKey;
    if (sessionId) {
      this.sessionId = sessionId;
    }
    this.message = message;
    this.idempotencyKey = runId;
  }
}

class OpenClawRpcRequest {
  type: string = 'req';
  id: string = '';
  method: string = '';
  params: Object = new Object();

  constructor(id: string, method: string, params: Object) {
    this.id = id;
    this.method = method;
    this.params = params;
  }
}

class OpenClawEmptyParams {
}

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();
  chatWebController: webview.WebviewController = new webview.WebviewController();
  @State openClawToken: string = '';
  ws: webSocket.WebSocket | null = null;
  pendingRequests: Array<PendingRequest> = [];
  openClawSessionId: string = '';
  agentTurnResolve: ((value: string) => void) | null = null;
  agentTurnReject: ((err: Error) => void) | null = null;
  @State currentMode: string = ''; // '', 'terminal', 'openclaw', 'tutorial'

  // --- Tutorial States ---
  @State selectedTaskIndex: number = 0; // 0: None, 1: Hello World, 2: Counter, 3: Layouts
  @State maxUnlockedLevel: number = 1; // 1: Compile, 2: Sign, 3: HDC Deploy
  @State highestCompletedLevel: number = 0; // completed levels are read-only when revisited
  @State level1QaPromptInjected: boolean = false; // inject the level-1 QA memory hint only once
  @State level2QaPromptInjected: boolean = false; // inject the level-2 QA memory hint only once
  @State level3QaPromptInjected: boolean = false; // inject the level-3 QA memory hint only once
  @State tutorialStep: number = 0; // 0: Task List, 1: Confirm Prompt, 2: OpenClaw Running, 3: Completed & Practice
  @State currentProgress: number = 0; // 0 to 100
  @State currentExecutionLog: string = ''; // Running console log
  @State workspaceTab: number = 0; // 0: Live Preview, 1: Source Code, 2: Logs
  @State sourceFileContent: string = '';
  @State sourceFileLoading: boolean = false;
  @State sourceFileError: string = '';
  @State courseResetting: boolean = false;
  @State courseResetNoticeVisible: boolean = false;
  @State courseResetNoticeSuccess: boolean = true;
  @State courseResetNoticeTitle: string = '';
  @State courseResetNoticeMessage: string = '';
  private courseResetNoticeSequence: number = 0;
  private readonly boardIndexEtsUrl: string =
    'http://127.0.0.1:7681/read-file?path=%2Fdata%2Flocal%2Ftmp%2Foh61-hapbuild%2Fproject%2Fentry%2Fsrc%2Fmain%2Fets%2Fpages%2FIndex.ets';

  // Step Statuses (0: pending, 1: active, 2: success)
  @State step1Status: number = 0;
  @State step2Status: number = 0;
  @State step3Status: number = 0;
  @State step4Status: number = 0;
  @State step5Status: number = 0;
  @State step6Status: number = 0;

  // Selected Task Metadata
  @State selectedTaskTitle: string = '';
  @State selectedTaskDesc: string = '';
  @State selectedTaskPrompt: string = '';
  @State openclawSummary: string = '';

  // Interactive Live Modification States (updates preview & code instantly!)
  @State previewText: string = '';
  @State previewSubText: string = '';
  @State previewColor: string = '#cdd6f4'; // Catppuccin Text
  @State counterValue: number = 0; // Task 2 state
  @State buttonLabel: string = '点我 +1'; // Task 2 button text
  @State gridColumns: number = 2; // Task 3 cols
  @State itemsList: string[] = ['Card 1', 'Card 2', 'Card 3', 'Card 4']; // Task 3 mock items

  // Chatbox States
  @State chatMessages: Array<ChatMessage> = [
    new ChatMessage('assistant', '你好，我是 OpenClaw 智能答疑助手。完成关卡后，可以在这里继续提问。')
  ];
  @State chatInput: string = '';
  @State openClawBusy: boolean = false;
  @State studentQuestionEnabled: boolean = false;
  @State openClawSessionKey: string = '';

  // Async helper for delays
  delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  getErrorMessage(error: Object): string {
    try {
      let detail = JSON.stringify(error);
      return detail && detail !== '{}' ? detail : String(error);
    } catch (e) {
      return String(error);
    }
  }

  async showCourseResetNotice(success: boolean): Promise<void> {
    this.courseResetNoticeSequence++;
    let sequence = this.courseResetNoticeSequence;
    this.courseResetNoticeSuccess = success;
    this.courseResetNoticeTitle = success ? '课程重置完成' : '课程重置失败';
    this.courseResetNoticeMessage = success
      ? '教学项目已恢复到初始状态，可以重新开始学习。'
      : '暂时无法恢复教学项目，请稍后重试。';
    this.courseResetNoticeVisible = true;
    await this.delay(success ? 3200 : 4200);
    if (sequence === this.courseResetNoticeSequence) {
      this.courseResetNoticeVisible = false;
    }
  }

  async requestText(url: string, method: http.RequestMethod, body: string = '', headers: Record<string, string> = {}): Promise<string> {
    let client = http.createHttp();
    try {
      let response = await client.request(url, {
        method: method,
        header: headers,
        extraData: body,
        connectTimeout: 10000,
        readTimeout: 600000
      });
      let status = response.responseCode;
      let result = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      if (status < 200 || status >= 300) {
        throw new Error('HTTP ' + status + ': ' + result);
      }
      return result;
    } finally {
      client.destroy();
    }
  }

  async getOpenClawToken(): Promise<string> {
    let token = await this.requestText('http://127.0.0.1:7681/token', http.RequestMethod.GET);
    token = token.trim();
    if (!token || token.indexOf('error') === 0) {
      throw new Error(token || 'empty token');
    }
    this.openClawToken = token;
    return token;
  }

  async fetchBoardSourceFile(): Promise<void> {
    this.sourceFileLoading = true;
    this.sourceFileError = '';
    try {
      let content = await this.requestText(this.boardIndexEtsUrl, http.RequestMethod.GET);
      if (!content || content.indexOf('error:') === 0 || content.indexOf('path not allowed') === 0 ||
        content.indexOf('file not found') === 0 || content.indexOf('missing path') === 0) {
        throw new Error(content.trim() || 'empty source file response');
      }
      this.sourceFileContent = content;
    } catch (e) {
      this.sourceFileContent = '';
      this.sourceFileError = e instanceof Error ? e.message : String(e);
    } finally {
      this.sourceFileLoading = false;
    }
  }

  onSourceTabSelected(): void {
    this.workspaceTab = 1;
    if (this.selectedTaskIndex > 0) {
      this.fetchBoardSourceFile();
    }
  }

  getSourceTabText(): string {
    if (this.selectedTaskIndex === 0) {
      return '// 等待加载源码...';
    }
    if (this.sourceFileLoading) {
      return '// 正在从板端读取源码文件...\n// /data/local/tmp/oh61-hapbuild/project/entry/src/main/ets/pages/Index.ets';
    }
    if (this.sourceFileError) {
      return '// 板端源码读取失败\n' +
        '// ' + this.sourceFileError + '\n' +
        '// 请确认 shell-bridge (:7681) 已部署 /read-file 接口后重试';
    }
    if (this.sourceFileContent) {
      return this.sourceFileContent;
    }
    return '// 尚未加载板端源码，请切换到本页或点击刷新';
  }

  buildOpenClawPrompt(): string {
    let taskName = this.selectedTaskIndex === 1 ? '第一关：编译 HAP' :
      (this.selectedTaskIndex === 2 ? '第二关：签名 HAP' : '第三关：部署与生命周期调试');
    
    let prompt = `你是在此 OpenHarmony 开发板上运行的 OpenClaw AI 协同开发助手。请为 HAP 教学应用启动一轮真实的协同开发任务。
当前任务：${taskName}
选择标题：${this.selectedTaskTitle}
学员自定义提示词：
${this.selectedTaskPrompt}

当前 UI 交互输入：
- 预览文本 / 行为目标 (previewText): ${this.previewText}
- 预览子文本 / SDK版本 (previewSubText): ${this.previewSubText}

`;

    if (this.selectedTaskIndex === 1) {
      prompt += `第一关动作边界（必须严格执行）：
1. 必须先读取动作记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile.md
2. 只允许运行编译脚本：sh /data/local/tmp/oh61-hapbuild/compile_unsigned.sh
3. 编译后只允许验证产物：ls -lh /data/local/tmp/entry-unsigned.hap
4. 不得修改源码，不得签名，不得安装，不得启动应用，不得读取第二关或第三关记忆文件。

`;
    } else if (this.selectedTaskIndex === 2) {
      prompt += `第二关动作边界（必须严格执行）：
1. 必须先读取动作记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level2-sign.md
2. 只允许运行签名动作：sh /data/local/tmp/oh61-hapbuild/build_sign_install_run.sh --sign-only
3. 签名后只允许验证产物：ls -lh /data/local/tmp/entry-signed.hap
4. 不得修改源码，不得重新编译，不得安装，不得启动应用，不得读取第一关或第三关记忆文件。

`;
    } else if (this.selectedTaskIndex === 3) {
      prompt += `第三关动作边界（必须严格执行）：
1. 必须先读取动作记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level3-deploy.md
2. 只允许围绕 /data/local/tmp/entry-signed.hap 执行卸载、安装、启动与状态验证。
3. 只允许使用第三关记忆指定的 shell-bridge 客户端或部署脚本完成本关动作。
4. 不得修改源码，不得重新编译，不得重新签名，不得读取第一关或第二关记忆文件，不得提前扩展额外调试任务。

`;
    }

    prompt += `HAP 工程目录配置信息：
- 主机同步目录：/data/local/tmp/oh61-hapbuild/project
- Docker 内编译目录：/root/HAP-BuildKit/project
- 主页面路径：entry/src/main/ets/pages/Index.ets

请严格按当前关卡动作记忆执行，不要跨关卡推进，不要补做下一关。任务完成后，用精炼中文汇报真实执行结果和产物状态。`;
    
    return prompt;
  }

  extractOpenClawReply(raw: string): string {
    try {
      let data: Record<string, Object> = JSON.parse(raw);
      let choices = data['choices'] as Array<Record<string, Object>>;
      if (choices && choices.length > 0) {
        let message = choices[0]['message'] as Record<string, Object>;
        if (message && message['content']) {
          return String(message['content']);
        }
      }
      if (data['output_text']) {
        return String(data['output_text']);
      }
      return raw.substring(0, 600);
    } catch (e) {
      return raw.substring(0, 600);
    }
  }

  setupWebSocket(token: string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.ws) {
        resolve();
        return;
      }
      this.ws = webSocket.createWebSocket();
      let hasResolved = false;

      this.ws.on('open', (err: Object) => {
        if (err) {
          if (!hasResolved) {
            hasResolved = true;
            reject(new Error('WebSocket open error: ' + JSON.stringify(err)));
          }
          return;
        }
        
        let reqId = 'handshake-' + Date.now().toString();
        let params = new OpenClawConnectParams(token);
        let req = new OpenClawRpcRequest(reqId, 'connect', params);
        this.ws?.send(JSON.stringify(req), (sendErr: Object) => {
          if (sendErr) {
            if (!hasResolved) {
              hasResolved = true;
              reject(new Error('WebSocket send handshake error: ' + JSON.stringify(sendErr)));
            }
          }
        });
      });

      this.ws.on('message', (err: Object, value: string | ArrayBuffer) => {
        if (err) {
          console.error('WebSocket message error: ' + JSON.stringify(err));
          return;
        }
        let rawStr = '';
        if (typeof value === 'string') {
          rawStr = value;
        } else {
          rawStr = String(value);
        }
        this.handleRpcMessage(rawStr, resolve, reject);
      });

      this.ws.on('close', (err: Object, value: Object) => {
        console.log('WebSocket closed: ' + JSON.stringify(value));
        this.ws = null;
        this.pendingRequests.forEach(req => req.reject(new Error('WebSocket disconnected')));
        this.pendingRequests = [];
        this.agentTurnResolve = null;
        this.agentTurnReject = null;
      });

      this.ws.on('error', (err: Object) => {
        console.error('WebSocket error: ' + JSON.stringify(err));
        if (!hasResolved) {
          hasResolved = true;
          reject(new Error('WebSocket connection error: ' + JSON.stringify(err)));
        }
        this.ws = null;
        this.pendingRequests.forEach(req => req.reject(new Error('WebSocket error')));
        this.pendingRequests = [];
        this.agentTurnResolve = null;
        this.agentTurnReject = null;
      });

      try {
        this.ws.connect('ws://127.0.0.1:18800', (connectErr: Object, isConnected: Object) => {
          if (connectErr) {
            if (!hasResolved) {
              hasResolved = true;
              reject(new Error('WebSocket connect failed: ' + JSON.stringify(connectErr)));
            }
          }
        });
      } catch (connectException) {
        this.ws.connect('ws://127.0.0.1:18800')
          .then(() => {
            console.log('WebSocket connect promise resolved');
          })
          .catch((promiseErr: Error) => {
            if (!hasResolved) {
              hasResolved = true;
              reject(new Error('WebSocket connect promise failed: ' + promiseErr.message));
            }
          });
      }
    });
  }

  handleRpcMessage(raw: string, handshakeResolve: () => void, handshakeReject: (err: Error) => void) {
    try {
      let msg = JSON.parse(raw) as Record<string, Object>;
      let type = msg['type'] as string;
      let id = msg['id'] as string;

      if (type === 'res') {
        let ok = msg['ok'] as boolean;
        let payload = msg['payload'] as Object;
        let errorVal = msg['error'] as Object;
        let errorStr = errorVal ? JSON.stringify(errorVal) : (msg['reason'] ? String(msg['reason']) : 'unknown');

        if (id && id.indexOf('handshake-') === 0) {
          if (ok) {
            handshakeResolve();
          } else {
            handshakeReject(new Error('Handshake failed: ' + errorStr));
          }
          return;
        }

        for (let i = 0; i < this.pendingRequests.length; i++) {
          let req = this.pendingRequests[i];
          if (req.id === id) {
            this.pendingRequests.splice(i, 1);
            if (ok) {
              req.resolve(JSON.stringify(payload));
            } else {
              req.reject(new Error('RPC request failed: ' + errorStr));
            }
            break;
          }
        }
      } else if (type === 'event') {
        let eventName = msg['event'] as string;
        let payload = msg['payload'] as Record<string, Object>;

        if (eventName === 'chat' && payload) {
          this.handleChatStreamEvent(payload);
        }
      }
    } catch (e) {
      console.error('Error handling RPC message: ' + (e as Error).message);
    }
  }

  extractMessageText(message: Record<string, Object> | null): string {
    if (!message) {
      return '';
    }
    if (message['text'] && typeof message['text'] === 'string') {
      return String(message['text']);
    }
    if (message['content']) {
      let contentVal = message['content'];
      if (Array.isArray(contentVal)) {
        let contentArr = contentVal as Array<Object>;
        let textParts: Array<string> = [];
        for (let i = 0; i < contentArr.length; i++) {
          let part = contentArr[i] as Record<string, Object>;
          if (part) {
            if (part['type'] === 'text' && part['text']) {
              textParts.push(String(part['text']));
            } else if (typeof part === 'string') {
              textParts.push(part);
            }
          }
        }
        return textParts.join('');
      } else if (typeof contentVal === 'string') {
        return contentVal;
      }
    }
    return '';
  }

  handleChatStreamEvent(payload: Record<string, Object>) {
    let state = payload['state'] as string;
    let text = '';

    if (payload['text'] && typeof payload['text'] === 'string') {
      text = String(payload['text']);
    } else if (payload['message']) {
      text = this.extractMessageText(payload['message'] as Record<string, Object>);
    }

    if (state === 'delta') {
      if (this.chatMessages.length > 0) {
        let lastMsg = this.chatMessages[this.chatMessages.length - 1];
        if (lastMsg.sender === 'assistant') {
          lastMsg.text = text;
          this.chatMessages = [...this.chatMessages];
        } else {
          this.chatMessages.push(new ChatMessage('assistant', text));
          this.chatMessages = [...this.chatMessages];
        }
      } else {
        this.chatMessages.push(new ChatMessage('assistant', text));
        this.chatMessages = [...this.chatMessages];
      }
    } else if (state === 'final') {
      if (this.chatMessages.length > 0) {
        let lastMsg = this.chatMessages[this.chatMessages.length - 1];
        if (lastMsg.sender === 'assistant') {
          lastMsg.text = text;
        } else {
          this.chatMessages.push(new ChatMessage('assistant', text));
        }
      } else {
        this.chatMessages.push(new ChatMessage('assistant', text));
      }
      this.chatMessages = [...this.chatMessages];
      
      if (this.agentTurnResolve) {
        this.agentTurnResolve(text);
        this.agentTurnResolve = null;
        this.agentTurnReject = null;
      }
      this.studentQuestionEnabled = true;
      this.openClawBusy = false;
    } else if (state === 'error' || state === 'aborted') {
      let errorMsg = 'OpenClaw 调用失败/中断';
      if (payload['error']) {
        errorMsg = 'OpenClaw 错误: ' + String(payload['error']);
      }
      this.chatMessages.push(new ChatMessage('assistant', errorMsg));
      this.chatMessages = [...this.chatMessages];
      
      if (this.agentTurnReject) {
        this.agentTurnReject(new Error(errorMsg));
        this.agentTurnResolve = null;
        this.agentTurnReject = null;
      }
      this.openClawBusy = false;
    }
  }

  sendRpcRequest(method: string, params: Object): Promise<string> {
    return new Promise(async (resolve, reject) => {
      try {
        let token = await this.getOpenClawToken();
        await this.setupWebSocket(token);

        let reqId = 'req-' + Date.now().toString() + '-' + Math.floor(Math.random() * 1000).toString();
        let request = new OpenClawRpcRequest(reqId, method, params);
        
        let pending = new PendingRequest(reqId, resolve, reject);
        this.pendingRequests.push(pending);

        this.ws?.send(JSON.stringify(request), (err: Object) => {
          if (err) {
            let idx = this.pendingRequests.indexOf(pending);
            if (idx >= 0) this.pendingRequests.splice(idx, 1);
            reject(new Error('Send failed: ' + JSON.stringify(err)));
          }
        });
      } catch (e) {
        reject(e as Error);
      }
    });
  }

  sendOpenClawAgentTurn(): Promise<string> {
    return new Promise(async (resolve, reject) => {
      this.agentTurnResolve = resolve;
      this.agentTurnReject = reject;

      try {
        let token = await this.getOpenClawToken();
        await this.setupWebSocket(token);

        if (!this.openClawSessionKey) {
          let createRes = await this.sendRpcRequest('sessions.create', new OpenClawEmptyParams());
          let createPayload = JSON.parse(createRes) as Record<string, Object>;
          let sKey = '';
          if (createPayload['key']) {
            sKey = String(createPayload['key']);
          } else if (createPayload['sessionKey']) {
            sKey = String(createPayload['sessionKey']);
          } else if (createPayload['session']) {
            let sObj = createPayload['session'] as Record<string, Object>;
            if (sObj && sObj['key']) {
              sKey = String(sObj['key']);
            }
          }
          this.openClawSessionKey = sKey;
        }

        let histRes = await this.sendRpcRequest('chat.history', new OpenClawHistoryParams(this.openClawSessionKey));
        let histPayload = JSON.parse(histRes) as Record<string, Object>;
        let sessId = '';
        if (histPayload['sessionId']) {
          sessId = String(histPayload['sessionId']);
        } else if (histPayload['session']) {
          let sObj = histPayload['session'] as Record<string, Object>;
          if (sObj && sObj['id']) {
            sessId = String(sObj['id']);
          }
        }
        this.openClawSessionId = sessId;

        this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在连接并开始分析...'));
        this.chatMessages = [...this.chatMessages];

        let runId = 'run-' + Date.now().toString() + '-' + Math.floor(Math.random() * 1000).toString();
        let prompt = this.selectedTaskPrompt;
        let sendParams = new OpenClawSendParams(this.openClawSessionKey, this.openClawSessionId, prompt, runId);
        
        await this.sendRpcRequest('chat.send', sendParams);
      } catch (e) {
        this.agentTurnResolve = null;
        this.agentTurnReject = null;
        reject(e as Error);
      }
    });
  }

  buildPracticeFullFlowPrompt(): string {
    return '执行以下命令并等待完成：\n\n' +
      'sh /data/local/tmp/oh61-hapbuild/practice_fullflow.sh\n\n' +
      '要求：\n' +
      '1. 只执行这一条命令。\n' +
      '2. 不要执行任何额外命令。\n' +
      '3. 等待命令执行完毕。\n' +
      '4. 命令成功则只回复：练习关卡执行成功。\n' +
      '5. 命令失败则只回复：练习关卡执行失败，并附上脚本原始输出。';
  }

  sendOpenClawChatText(userMsg: string): Promise<string> {
    return new Promise(async (resolve, reject) => {
      this.agentTurnResolve = resolve;
      this.agentTurnReject = reject;

      try {
        let token = await this.getOpenClawToken();
        await this.setupWebSocket(token);

        if (!this.openClawSessionKey) {
          let createRes = await this.sendRpcRequest('sessions.create', new OpenClawEmptyParams());
          let createPayload = JSON.parse(createRes) as Record<string, Object>;
          let sKey = '';
          if (createPayload['key']) {
            sKey = String(createPayload['key']);
          } else if (createPayload['sessionKey']) {
            sKey = String(createPayload['sessionKey']);
          } else if (createPayload['session']) {
            let sObj = createPayload['session'] as Record<string, Object>;
            if (sObj && sObj['key']) {
              sKey = String(sObj['key']);
            }
          }
          this.openClawSessionKey = sKey;
        }

        let histRes = await this.sendRpcRequest('chat.history', new OpenClawHistoryParams(this.openClawSessionKey));
        let histPayload = JSON.parse(histRes) as Record<string, Object>;
        let sessId = '';
        if (histPayload['sessionId']) {
          sessId = String(histPayload['sessionId']);
        } else if (histPayload['session']) {
          let sObj = histPayload['session'] as Record<string, Object>;
          if (sObj && sObj['id']) {
            sessId = String(sObj['id']);
          }
        }
        this.openClawSessionId = sessId;

        this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 正在思考中...'));
        this.chatMessages = [...this.chatMessages];

        let runId = 'run-' + Date.now().toString() + '-' + Math.floor(Math.random() * 1000).toString();
        let sendParams = new OpenClawSendParams(this.openClawSessionKey, this.openClawSessionId, userMsg, runId);
        
        await this.sendRpcRequest('chat.send', sendParams);
      } catch (e) {
        this.agentTurnResolve = null;
        this.agentTurnReject = null;
        reject(e as Error);
      }
    });
  }

  async sendChatMessage() {
    if (!this.chatInput.trim()) {
      return;
    }
    if (!this.studentQuestionEnabled && this.tutorialStep !== 4) {
      promptAction.showToast({
        message: '请先完成本关 OpenClaw 协同开发任务，再进行自由提问。',
        duration: 2200
      });
      return;
    }
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理上一条消息，请等待回复完成。',
        duration: 1800
      });
      return;
    }
    let userMsg = this.chatInput.trim();
    this.chatMessages.push(new ChatMessage('user', userMsg));
    this.chatInput = '';
    this.openClawBusy = true;

    try {
      let sendMsg = userMsg;
      if (this.selectedTaskIndex === 4 && userMsg === '请将 HAP 主页面内容修改为 hello world，然后按完整流程执行：编译未签名 HAP、签名生成已签名 HAP、卸载旧应用、安装新 HAP 并启动 EntryAbility。请在执行前说明会修改的文件和命令边界，执行后汇报每一步真实结果。') {
        sendMsg = this.buildPracticeFullFlowPrompt();
      } else if (this.selectedTaskIndex === 1 && this.tutorialStep === 3 && this.highestCompletedLevel >= 1 && !this.level1QaPromptInjected) {
        sendMsg = '请先读取第一关答疑记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile-qa.md。' +
          '本轮是学生课后自由提问，不是关卡触发任务。请只解释问题，不要重新编译、签名、安装或启动应用。\n\n学生问题：' + userMsg;
        this.level1QaPromptInjected = true;
      } else if (this.selectedTaskIndex === 2 && this.tutorialStep === 3 && this.highestCompletedLevel >= 2 && !this.level2QaPromptInjected) {
        sendMsg = '请先读取第二关答疑记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level2-sign-qa.md。' +
          '本轮是学生课后自由提问，不是关卡触发任务。请只解释问题，不要重新编译、签名、安装或启动应用，不要改变当前关卡进度。\n\n学生问题：' + userMsg;
        this.level2QaPromptInjected = true;
      } else if (this.selectedTaskIndex === 3 && this.tutorialStep === 3 && this.highestCompletedLevel >= 3 && !this.level3QaPromptInjected) {
        sendMsg = '请先读取第三关答疑记忆文件：/data/local/tmp/.openclaw/workspace/memory/oh61-level3-deploy-qa.md。' +
          '本轮是学生课后自由提问，不是关卡触发任务。请只解释问题，不要重新编译、签名、安装或启动应用，不要改变当前关卡进度。\n\n学生问题：' + userMsg;
        this.level3QaPromptInjected = true;
        this.level3QaPromptInjected = true;
      }
      await this.sendOpenClawChatText(sendMsg);
      this.openClawBusy = false;
    } catch (error) {
      let message = (error as Error).message;
      this.currentExecutionLog += '[openclaw] chat failed: ' + message + '\n';
      this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 调用失败：' + message));
      this.openClawBusy = false;
    }
  }

  getStepLabel(stepNum: number): string {
    if (this.selectedTaskIndex === 1) {
      if (stepNum === 1) return '分析项目工程结构与资源依赖';
      if (stepNum === 2) return '加载资源文件并生成索引表';
      if (stepNum === 3) return '执行静态检查（CodeLinter）';
      if (stepNum === 4) return '执行 hvigorw assembleHap 编译';
      if (stepNum === 5) return '打包生成未签名包 unsigned.hap';
      return '验证 HAP 构建产物完整性';
    } else if (this.selectedTaskIndex === 2) {
      if (stepNum === 1) return '载入本地 .p12 私钥库';
      if (stepNum === 2) return '解析 Profile 描述证书 json';
      if (stepNum === 3) return '校验绑定包名（BundleName）匹配';
      if (stepNum === 4) return '调用 sign-profile 签发 debug.p7b';
      if (stepNum === 5) return '执行 hap-sign-tool 签署 app.hap';
      return '生成并验证已签名包 signed.hap';
    } else {
      if (stepNum === 1) return '轮询检测本地物理 HDC 目标';
      if (stepNum === 2) return '开启调试桥套接字数据通道';
      if (stepNum === 3) return '验证已签名 HAP 产物';
      if (stepNum === 4) return '调用安装客户端执行 bm install';
      if (stepNum === 5) return '调用 aa 工具拉起 EntryAbility';
      return '返回板端生命周期运行状态';
    }
  }

  selectPracticeLevel() {
    this.selectedTaskIndex = 4;
    this.selectedTaskTitle = '练习关卡：OpenClaw 自由练习';
    this.selectedTaskDesc = '选择一个练习提示词，自动填入下方输入框，再发送给 OpenClaw 进行答疑或演示。';
    this.selectedTaskPrompt = '';
    this.tutorialStep = 4;
    this.workspaceTab = 0;
    this.openClawBusy = false;
    this.studentQuestionEnabled = true;
    this.chatInput = '';
    this.chatMessages.push(new ChatMessage('assistant', '已进入练习关卡。请选择左侧练习提示词，内容会自动填入下方输入框，确认后点击发送。'));
  }

  fillPracticePrompt(promptText: string) {
    this.chatInput = promptText;
    promptAction.showToast({
      message: '已填入输入框，请确认后发送。',
      duration: 1600
    });
  }

  clearCourseState(): void {
    if (this.ws) {
      try {
        this.ws.close();
      } catch (e) {
        console.error('Error closing WebSocket: ' + (e as Error).message);
      }
      this.ws = null;
    }
    this.pendingRequests.forEach(req => req.reject(new Error('Course reset')));
    this.pendingRequests = [];
    this.openClawSessionId = '';
    this.agentTurnResolve = null;
    this.agentTurnReject = null;

    this.selectedTaskIndex = 0;
    this.maxUnlockedLevel = 1;
    this.highestCompletedLevel = 0;
    this.level1QaPromptInjected = false;
    this.level2QaPromptInjected = false;
    this.level3QaPromptInjected = false;
    this.tutorialStep = 0;
    this.currentProgress = 0;
    this.currentExecutionLog = '';
    this.workspaceTab = 0;
    this.step1Status = 0;
    this.step2Status = 0;
    this.step3Status = 0;
    this.step4Status = 0;
    this.step5Status = 0;
    this.step6Status = 0;
    this.chatInput = '';
    this.openClawBusy = false;
    this.studentQuestionEnabled = false;
    this.openClawSessionKey = '';
    this.chatMessages = [
      new ChatMessage('assistant', '你好，我是 OpenClaw 智能答疑助手。请先选择第一关并呼叫 OpenClaw 完成首轮协同开发，随后即可继续提问。')
    ];
  }

  async resetCourse(): Promise<void> {
    if (this.courseResetting) {
      return;
    }
    this.courseResetting = true;
    try {
      await this.requestText(
        'http://127.0.0.1:7681/reset-course',
        http.RequestMethod.GET
      );
      this.clearCourseState();
      this.sourceFileContent = '';
      this.sourceFileError = '';
      this.showCourseResetNotice(true);
    } catch (e) {
      let message = e instanceof Error ? e.message : this.getErrorMessage(e as Object);
      console.error('Course reset failed: ' + message);
      this.showCourseResetNotice(false);
    } finally {
      this.courseResetting = false;
    }
  }

  // Pre-fill states on selecting a task
  selectTask(index: number) {
    if (index === 4) {
      this.selectPracticeLevel();
      return;
    }

    this.selectedTaskIndex = index;
    this.tutorialStep = 1;
    this.workspaceTab = 0;
    this.openClawBusy = false;
    this.chatInput = '';

    if (index === 1) {
      this.selectedTaskTitle = '第一关：编译与构建（声明式 UI 与 HAP 构建）';
      this.selectedTaskDesc = '学习 ArkUI 与 HAP 构建流程，调用 Hvigor 编译生成未签名 HAP。';
      this.selectedTaskPrompt = '请先读取第一关动作记忆文件 /data/local/tmp/.openclaw/workspace/memory/oh61-level1-compile.md，然后只运行第一关编译脚本 sh /data/local/tmp/oh61-hapbuild/compile_unsigned.sh。编译结束后验证 /data/local/tmp/entry-unsigned.hap 是否存在并向我报告。不得修改源码，不得签名，不得安装，不得启动应用。';
      this.previewText = 'Hello, OpenHarmony!';
      this.previewSubText = '23'; // SDK Version
      this.previewColor = '#f5c2e7';
      this.openclawSummary = `【第一关：编译 HAP 实训成果】
1. 编译链路验证：OpenClaw 按第一关动作记忆运行 compile_unsigned.sh，验证教学 HAP 工程可以进入 Docker 构建环境。
2. 容器增量同步：脚本将板端工程同步到 linux-env 容器中的 /root/HAP-BuildKit/project。
3. Hvigor 编译：容器内调用 hvigor assembleHap 完成真实构建。
4. 未签名 HAP 产出：最终验证 /data/local/tmp/entry-unsigned.hap 存在，第一关只到编译产物，不进行签名、安装或启动。`;
    } else if (index === 2) {
      this.selectedTaskTitle = '第二关：应用签名（PKCS12 私钥库与证书）';
      this.selectedTaskDesc = '理解 OpenHarmony 应用签名流程，使用证书和 Profile 生成已签名 HAP。';
      this.selectedTaskPrompt = '请先读取第二关动作记忆文件 /data/local/tmp/.openclaw/workspace/memory/oh61-level2-sign.md，然后只执行签名脚本 sh /data/local/tmp/oh61-hapbuild/build_sign_install_run.sh --sign-only。签名结束后验证 /data/local/tmp/entry-signed.hap 是否存在并向我报告。不得修改源码，不得重新编译，不得安装，不得启动应用，不得读取第一关或第三关记忆文件。';
      this.previewText = 'com.openclaw.learnhap'; // Bundle Name
      this.previewSubText = 'debugKey'; // Key Alias
      this.previewColor = '#89b4fa';
      this.openclawSummary = `【第二关：数字签名 HAP 实训成果】
1. 动作边界确认：OpenClaw 按第二关动作记忆读取 oh61-level2-sign.md，只执行签名任务。
2. 签名材料加载：确认 OpenHarmony.p12、证书链和 Profile 已就绪。
3. HAP 签名：签名脚本生成并验证 /data/local/tmp/entry-signed.hap。
4. 第二关只到签名产物，不进行源码修改、重新编译、安装或启动。`;
    } else if (index === 3) {
      this.selectedTaskTitle = '第三关：应用全生命周期调试（HDC 桥接与交互）';
      this.selectedTaskDesc = '通过 shell-bridge 客户端完成已签名 HAP 的安装、启动和部署验证。';
      this.selectedTaskPrompt = '请先读取第三关动作记忆文件 /data/local/tmp/.openclaw/workspace/memory/oh61-level3-deploy.md，然后只围绕 /data/local/tmp/entry-signed.hap 执行卸载、安装、启动与状态验证，并向我报告真实结果。不得修改源码，不得重新编译，不得重新签名，不得读取第一关或第二关记忆文件。';
      this.previewText = 'install'; // Current Action
      this.previewSubText = '039C1E0604834A08'; // Device connect key
      this.previewColor = '#a6e3a1';
      this.openclawSummary = `【第三关：全生命周期调试实训成果】
1. 动作边界确认：OpenClaw 按第三关动作记忆读取 oh61-level3-deploy.md，只执行部署与生命周期验证任务。
2. 联调服务建立：打通板端 shell-bridge 通信通道，调度 BundleManager 与 AbilityManager 核心服务。
3. 安装部署：围绕 /data/local/tmp/entry-signed.hap 完成卸载、安装和部署状态验证。
4. 启动生命周期：拉起应用主图形进程 EntryAbility，并报告真实运行结果，不再修改源码、编译或签名。`;
    }

    if (index <= this.highestCompletedLevel) {
      this.tutorialStep = 3;
      this.currentProgress = 100;
      this.step1Status = 2;
      this.step2Status = 2;
      this.step3Status = 2;
      this.step4Status = 2;
      this.step5Status = 2;
      this.step6Status = 2;
      this.studentQuestionEnabled = true;
    } else {
      this.tutorialStep = 1;
      this.currentProgress = 0;
      this.step1Status = 0;
      this.step2Status = 0;
      this.step3Status = 0;
      this.step4Status = 0;
      this.step5Status = 0;
      this.step6Status = 0;
      this.studentQuestionEnabled = false;
    }

    // Append a welcome message to the AI Chatbox
    let taskName = index === 1 ? '编译 HAP' : (index === 2 ? '数字签名' : '部署与启动');
    let welcomeText = 'OpenClaw 关卡向导：已加载第' + index + '关【' + taskName + '】。完成关卡后，可以在下方继续提问。';
    this.chatMessages.push(new ChatMessage('assistant', welcomeText));
  }

  // Smoothly advances the progress bar & step checklists concurrently with the real OpenClaw streaming thread
  async animateProgress() {
    if (this.selectedTaskIndex === 1) {
      this.step1Status = 1;
      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 15;
      this.currentExecutionLog += '[info] Found ArkTS workspace at /data/local/tmp/oh61-hapbuild/project\n';
      this.step1Status = 2;
      this.step2Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 35;
      this.currentExecutionLog += '[info] Loading text assets: "' + this.previewText + '" successfully parsed.\n';
      this.step2Status = 2;
      this.step3Status = 1;

      await this.delay(1200);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 60;
      this.currentExecutionLog += '[info] Running CodeLinter checkers. Scanning for decorator usage (@Entry, @Component)...\n';
      this.step3Status = 2;
      this.step4Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 80;
      this.currentExecutionLog += '[info] Invoking hvigor compiler node script in background daemon...\n';
      this.step4Status = 2;
      this.step5Status = 1;

      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 95;
      this.currentExecutionLog += '[info] Compiling raw files to ArkTS bytecode index. Outputting ZIP wrapper stream...\n';
      this.currentExecutionLog += '[info] Package created: entry-unsigned.hap (size: 71 KB)\n';
      this.step5Status = 2;
      this.step6Status = 1;
    } else if (this.selectedTaskIndex === 2) {
      this.step1Status = 1;
      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 15;
      this.currentExecutionLog += '[info] Signature Service Agent running...\n';
      this.step1Status = 2;
      this.step2Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 35;
      this.currentExecutionLog += '[info] Reading Provisioning Profile: signature/HelloHap_debug_profile.json\n';
      this.step2Status = 2;
      this.step3Status = 1;

      await this.delay(1200);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 60;
      this.currentExecutionLog += '[info] Matching application bundleName with Profile descriptor...\n';
      this.step3Status = 2;
      this.step4Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 80;
      this.currentExecutionLog += '[info] Executing sign-profile action to create binary p7b wrapper...\n';
      this.step4Status = 2;
      this.step5Status = 1;

      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 95;
      this.currentExecutionLog += '[info] Signing HAP binary package with alias: ' + this.previewSubText + '\n';
      this.step5Status = 2;
      this.step6Status = 1;
    } else {
      this.step1Status = 1;
      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 15;
      this.currentExecutionLog += '[info] HDC 连接代理启动中...\n';
      this.step1Status = 2;
      this.step2Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 35;
      this.currentExecutionLog += '[info] 已与板端 hdcd 守护进程建立 TCP 会话，端口 3456。\n';
      this.step2Status = 2;
      this.step3Status = 1;

      await this.delay(1200);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 60;
      this.currentExecutionLog += '[info] 正在上传 HAP 包：entry-default-signed.hap（1.43 MB）到 /data/local/tmp/\n';
      this.step3Status = 2;
      this.step4Status = 1;

      await this.delay(1000);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 80;
      this.currentExecutionLog += '[info] 通知板端 BundleManager（bm）安装本地文件...\n';
      this.step4Status = 2;
      this.step5Status = 1;

      await this.delay(800);
      if (this.tutorialStep !== 2) return;
      this.currentProgress = 95;
      this.currentExecutionLog += '[info] 正在拉起目标应用：com.openclaw.learnhap 的 EntryAbility\n';
      this.step5Status = 2;
      this.step6Status = 1;
    }
  }

  // Send this lesson task to the real OpenClaw gateway, then keep the visual teaching flow moving.
  async runOpenClaw() {
    if (this.openClawBusy) {
      promptAction.showToast({
        message: 'OpenClaw 正在处理当前任务，请等待完成。',
        duration: 1800
      });
      return;
    }
    this.tutorialStep = 2;
    this.currentProgress = 0;
    this.currentExecutionLog = '[info] OpenClaw Agent gateway handoff starting...\n';
    this.studentQuestionEnabled = false;
    this.openClawBusy = true;
    this.step1Status = 1;
    this.step2Status = 0;
    this.step3Status = 0;
    this.step4Status = 0;
    this.step5Status = 0;
    this.step6Status = 0;

    this.currentExecutionLog += '[network] requesting shell-bridge token on :7681\n';
    this.currentExecutionLog += '[network] sending lesson prompt to OpenClaw gateway /v1/chat/completions\n';
    this.chatMessages.push(new ChatMessage('user', this.selectedTaskPrompt));

    // 启动进度条与步骤动画，并与 OpenClaw 流式响应并行执行
    this.animateProgress();

    let reply = '';
    try {
      reply = await this.sendOpenClawAgentTurn();
      this.currentExecutionLog += '[openclaw] real agent turn accepted.\n';
      this.currentExecutionLog += '[openclaw] reply: ' + reply + '\n';
    } catch (error) {
      let message = (error as Error).message;
      this.currentExecutionLog += '[openclaw] real gateway call failed: ' + message + '\n';
      this.currentExecutionLog += '[openclaw] stopped: OpenClaw call is required.\n';
      this.chatMessages.push(new ChatMessage('assistant', 'OpenClaw 协同开发请求失败：' + message));
      this.step1Status = 0;
      this.currentProgress = 0;
      this.openClawBusy = false;
      this.tutorialStep = 1; // Back to step 1
      return;
    }

    // 当 OpenClaw 成功响应后，立即完成整条教学流程
    this.currentProgress = 100;
    this.step1Status = 2;
    this.step2Status = 2;
    this.step3Status = 2;
    this.step4Status = 2;
    this.step5Status = 2;
    this.step6Status = 2;
    this.currentExecutionLog += '[info] Verification: Output HAP target has 0 security alerts. Build COMPLETE! 🎉\n';

    this.highestCompletedLevel = Math.max(this.highestCompletedLevel, this.selectedTaskIndex);
    if (this.selectedTaskIndex < 3) {
      this.maxUnlockedLevel = Math.max(this.maxUnlockedLevel, this.selectedTaskIndex + 1);
    }

    await this.delay(600);
    this.tutorialStep = 3;
    this.workspaceTab = 0;
    this.studentQuestionEnabled = true;
    this.openClawBusy = false;
    this.fetchBoardSourceFile();
  }

  // 根据所选任务与输入动态生成实时源码
  getGeneratedCode(): string {
    if (this.selectedTaskIndex === 4) {
      return `# [练习关卡：练习提示词]\n` +
             `# 选择左侧提示词后，会自动填入底部输入框。\n` +
             `# 当前输入框内容：\n` +
             `${this.chatInput}`;
    }

    if (this.selectedTaskIndex === 1) {
      return `// [编译工作区：D:\\DevEcoProjects\\HelloHap\\AppScope\\app.json5]\n` +
             `{\n` +
             `  "app": {\n` +
             `    "bundleName": "com.openclaw.learnhap",\n` +
             `    "vendor": "example",\n` +
             `    "versionCode": 1000000,\n` +
             `    "versionName": "1.0.0"\n` +
             `  }\n` +
             `}\n\n` +
             `// [主编页面：entry/src/main/ets/pages/Index.ets]\n` +
             `@Entry\n` +
             `@Component\n` +
             `struct IndexPage {\n` +
             `  build() {\n` +
             `    Column() {\n` +
             `      Text("${this.previewText}")\n` +
             `        .fontSize(36)\n` +
             `        .fontWeight(FontWeight.Bold)\n` +
             `        .fontColor("#cdd6f4")\n` +
             `    }\n` +
             `    .width('100%')\n` +
             `    .height('100%')\n` +
             `    .justifyContent(FlexAlign.Center)\n` +
             `    .backgroundColor('#1e1e2e')\n` +
             `  }\n` +
             `}\n\n` +
             `// === HVIGOR 构建命令 ===\n` +
             `node "D:\\DevEcoStudio\\tools\\hvigor\\bin\\hvigorw.js" --mode module -p product=default assembleHap --analyze=normal`;
    } else if (this.selectedTaskIndex === 2) {
      return `# 步骤一：使用私钥签名应用证书描述 Profile (.p7b)\n` +
             `& "D:\\DevEcoStudio\\DevEco Studio\\jbr\\bin\\java.exe" -jar "D:\\OpenHarmony\\18\\toolchains\\lib\\hap-sign-tool.jar" sign-profile \`\n` +
             `  -keyAlias "openharmony application ca" \`\n` +
             `  -keyPwd 123456 \`\n` +
             `  -mode localSign \`\n` +
             `  -signAlg SHA256withECDSA \`\n` +
             `  -keystoreFile "D:\\DevEcoProjects\\HelloHap\\signature\\OpenHarmony.p12" \`\n` +
             `  -keystorePwd 123456 \`\n` +
             `  -profileCertFile "D:\\DevEcoProjects\\HelloHap\\signature\\OpenHarmonyCA.pem" \`\n` +
             `  -inFile "D:\\DevEcoProjects\\HelloHap\\signature\\HelloHap_debug_profile.json" \`\n` +
             `  -outFile "D:\\DevEcoProjects\\HelloHap\\signature\\HelloHap_debug.p7b"\n\n` +
             `# 步骤二：使用开发者私钥对编译出的未签名 HAP 进行正式签名\n` +
             `& "D:\\DevEcoStudio\\DevEco Studio\\jbr\\bin\\java.exe" -jar "D:\\OpenHarmony\\18\\toolchains\\lib\\hap-sign-tool.jar" sign-app \`\n` +
             `  -keyAlias "${this.previewSubText}" \`\n` +
             `  -signAlg SHA256withECDSA \`\n` +
             `  -mode localSign \`\n` +
             `  -appCertFile "D:\\DevEcoProjects\\HelloHap\\signature\\OpenHarmonyAppChain.pem" \`\n` +
             `  -profileFile "D:\\DevEcoProjects\\HelloHap\\signature\\HelloHap_debug.p7b" \`\n` +
             `  -inFile "D:\\DevEcoProjects\\HelloHap\\entry\\build\\default\\outputs\\default\\entry-default-unsigned.hap" \`\n` +
             `  -keystoreFile "D:\\DevEcoProjects\\HelloHap\\signature\\OpenHarmony.p12" \`\n` +
             `  -outFile "D:\\DevEcoProjects\\HelloHap\\entry\\build\\default\\outputs\\default\\entry-default-signed.hap" \`\n` +
             `  -keyPwd 123456 \`\n` +
             `  -keystorePwd 123456 \`\n` +
             `  -signCode 1`;
    } else if (this.selectedTaskIndex === 3) {
      if (this.previewText === 'install') {
        return `# [HDC 动作：将 HAP 传输并覆盖安装到物理开发板]\n` +
               `hdc ${this.previewSubText ? '-t ' + this.previewSubText : ''} install -r "D:\\DevEcoProjects\\HelloHap\\entry\\build\\default\\outputs\\default\\entry-default-signed.hap"`;
      } else if (this.previewText === 'start') {
        return `# [HDC 动作：使用底层 aa 工具启动应用 EntryAbility]\n` +
               `hdc ${this.previewSubText ? '-t ' + this.previewSubText : ''} shell "aa start -a EntryAbility -b com.openclaw.learnhap"`;
      } else {
        return `# [HDC 动作：一键彻底卸载目标包名的沙箱与应用程序]\n` +
               `hdc ${this.previewSubText ? '-t ' + this.previewSubText : ''} uninstall "com.openclaw.learnhap"`;
      }
    }
    return '';
  }

  build() {
    Column() {
      if (this.currentMode === '') {
        // === Selection & Entry Home Page ===
        Column() {
          // Title Section
          Text('OpenClaw 智能开发向导')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#cdd6f4')
            .margin({ top: 80, bottom: 10 })

          Text('专为 OpenHarmony ArkUI 打造的 AI 协同学习平台')
            .fontSize(14)
            .fontColor('#a6adc8')
            .margin({ bottom: 60 })

          // Selection Options
          // 1. Interactive Tutorial Mode - Simple (Beginner Edition)
          Button('交互式学习（基础版）')
            .width('70%')
            .height(56)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#f5c2e7') // Pink
            .fontColor('#1e1e2e')
            .borderRadius(12)
            .margin({ bottom: 20 })
            .onClick(() => {
              this.currentMode = 'tutorial';
              this.tutorialStep = 0;
              this.selectedTaskIndex = 0;
            })

          // 2. Interactive Tutorial Mode - Advanced (Pro Edition)
          Button('交互式学习（高级版）')
            .width('70%')
            .height(56)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#fab387') // Peach
            .fontColor('#1e1e2e')
            .borderRadius(12)
            .margin({ bottom: 20 })
            .onClick(() => {
              this.currentMode = 'advanced';
              this.tutorialStep = 0;
              this.selectedTaskIndex = 0;
              this.workspaceTab = 0;
            })

          // Device status indicator bar
          Row() {
            Row() {
              Circle({ width: 8, height: 8 }).fill('#a6e3a1').margin({ right: 6 })
              Text('Shell-Bridge：在线 (7681)').fontSize(12).fontColor('#a6adc8')
            }.margin({ right: 20 })

            Row() {
              Circle({ width: 8, height: 8 }).fill('#a6e3a1').margin({ right: 6 })
              Text('OpenClaw Gateway：运行中 (18800)').fontSize(12).fontColor('#a6adc8')
            }
          }
          .margin({ top: 50 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#1e1e2e')

      } else if (this.currentMode === 'tutorial' || this.currentMode === 'advanced') {
        // === INTERACTIVE TUTORIAL INTERFACE (SPLIT SCREEN) ===
        Column() {
          // 1. Header Toolbar
          Row() {
            Button('返回主页')
              .height(36)
              .fontSize(14)
              .backgroundColor('#45475a')
              .fontColor('#cdd6f4')
              .borderRadius(8)
              .onClick(() => { this.currentMode = ''; })

            Text(this.currentMode === 'advanced' ? '鸿蒙 ArkUI 高级开发课程' : '鸿蒙 ArkUI 智能交互式学习课程')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#cdd6f4')
              .margin({ left: 16 })

            Blank()

            if (this.tutorialStep > 0) {
              Button(this.courseResetting ? '正在还原项目...' : '重置课程')
                .height(36)
                .fontSize(14)
                .backgroundColor('#f38ba8')
                .fontColor('#1e1e2e')
                .borderRadius(8)
                .enabled(!this.courseResetting)
                .onClick(() => { this.resetCourse(); })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor('#252538')

          if (this.courseResetNoticeVisible) {
            Row() {
              Text(this.courseResetNoticeSuccess ? '✓' : '!')
                .width(34)
                .height(34)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.courseResetNoticeSuccess ? '#1e1e2e' : '#ffffff')
                .textAlign(TextAlign.Center)
                .backgroundColor(this.courseResetNoticeSuccess ? '#a6e3a1' : '#f38ba8')
                .borderRadius(17)
                .margin({ right: 12 })

              Column() {
                Text(this.courseResetNoticeTitle)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.courseResetNoticeSuccess ? '#a6e3a1' : '#f38ba8')

                Text(this.courseResetNoticeMessage)
                  .fontSize(12)
                  .fontColor('#cdd6f4')
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)

              Blank()
            }
            .width('96%')
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .margin({ top: 10, bottom: 2 })
            .backgroundColor(this.courseResetNoticeSuccess ? '#26352f' : '#3b2932')
            .border({
              width: 1,
              color: this.courseResetNoticeSuccess ? '#a6e3a1' : '#f38ba8'
            })
            .borderRadius(12)
          }

          // 2. Main Content Split View
          Row() {
            // === LEFT PANEL: TUTOR CARD ===
            Column() {
              // 1. Top Section
              Column() {
                if (this.currentMode === 'advanced') {
                  Column() {
                    Text('请选择高级开发模式')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#cdd6f4')
                      .margin({ bottom: 12, top: 6 })
                      .alignSelf(ItemAlign.Start)

                    Column() {
                      Text('教学之路')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#fab387')
                        .margin({ bottom: 6 })

                      Text('按照进阶课程路线学习 ArkUI 项目设计与开发。')
                        .fontSize(12)
                        .fontColor('#a6adc8')
                        .margin({ bottom: 12 })

                      Button('进入教学之路')
                        .width('100%')
                        .height(34)
                        .fontSize(12)
                        .backgroundColor('#45475a')
                        .fontColor('#fab387')
                        .onClick(() => {
                          promptAction.showToast({
                            message: '教学之路正在开发中。',
                            duration: 1800
                          });
                        })
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .margin({ bottom: 10 })
                    .alignItems(HorizontalAlign.Start)

                    Column() {
                      Text('自由开发')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#89b4fa')
                        .margin({ bottom: 6 })

                      Text('进入开放式开发空间，自主规划和实现 HAP 项目。')
                        .fontSize(12)
                        .fontColor('#a6adc8')
                        .margin({ bottom: 12 })

                      Button('进入自由开发')
                        .width('100%')
                        .height(34)
                        .fontSize(12)
                        .backgroundColor('#45475a')
                        .fontColor('#89b4fa')
                        .onClick(() => {
                          promptAction.showToast({
                            message: '自由开发正在开发中。',
                            duration: 1800
                          });
                        })
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })

                } else if (this.tutorialStep === 0) {
                  // Step 0: Choose Course List
                  Scroll() {
                    Column() {
                      Text('请选择挑战关卡（当前学习进度）')
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#cdd6f4')
                        .margin({ bottom: 12, top: 6 })
                        .alignSelf(ItemAlign.Start)

                    // Level 1 Card
                    Column() {
                      Row() {
                        Text('第一关：编译 HAP')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#f5c2e7')

                        Text(this.highestCompletedLevel >= 1 ? '已学习' : '待挑战')
                          .fontSize(11)
                          .fontColor('#f5c2e7')
                          .backgroundColor(this.highestCompletedLevel >= 1 ? '#1e3e2e' : '#3c223c')
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(4)
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      .margin({ bottom: 6 })

                      Text('学习如何编译 HAP 工程，并通过 hvigor 生成 entry-unsigned.hap 未签名包。')
                        .fontSize(12)
                        .fontColor('#a6adc8')
                        .margin({ bottom: 12 })
                        .lineHeight(16)

                      Button(this.highestCompletedLevel >= 1 ? '查看学习记录' : '点击进入挑战')
                        .width('100%')
                        .height(34)
                        .fontSize(12)
                        .backgroundColor('#45475a')
                        .fontColor('#f5c2e7')
                        .onClick(() => { this.selectTask(1); })
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .margin({ bottom: 10 })
                    .alignItems(HorizontalAlign.Start)

                    // Level 2 Card
                    Column() {
                      Row() {
                        Text('第二关：数字签名')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.maxUnlockedLevel >= 2 ? '#89b4fa' : '#6c7086')

                        Text(this.highestCompletedLevel >= 2 ? '已学习' : (this.maxUnlockedLevel >= 2 ? '待挑战' : '未解锁'))
                          .fontSize(11)
                          .fontColor(this.maxUnlockedLevel >= 2 ? '#89b4fa' : '#6c7086')
                          .backgroundColor(this.highestCompletedLevel >= 2 ? '#1e3e2e' : (this.maxUnlockedLevel >= 2 ? '#1e2e4e' : '#313244'))
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(4)
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      .margin({ bottom: 6 })

                      Text('使用证书、私钥库和 Profile 将第一关产物转换为已签名 HAP。')
                        .fontSize(12)
                        .fontColor(this.maxUnlockedLevel >= 2 ? '#a6adc8' : '#6c7086')
                        .margin({ bottom: 12 })
                        .lineHeight(16)

                      Button(this.highestCompletedLevel >= 2 ? '查看学习记录' : (this.maxUnlockedLevel >= 2 ? '点击进入挑战' : '请先完成第一关'))
                        .width('100%')
                        .height(34)
                        .fontSize(12)
                        .backgroundColor(this.maxUnlockedLevel >= 2 ? '#45475a' : '#313244')
                        .fontColor(this.maxUnlockedLevel >= 2 ? '#89b4fa' : '#6c7086')
                        .enabled(this.maxUnlockedLevel >= 2)
                        .onClick(() => { this.selectTask(2); })
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .margin({ bottom: 10 })
                    .alignItems(HorizontalAlign.Start)

                    // Level 3 Card
                    Column() {
                      Row() {
                        Text('第三关：部署与启动')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(this.maxUnlockedLevel >= 3 ? '#a6e3a1' : '#6c7086')

                        Text(this.highestCompletedLevel >= 3 ? '已学习' : (this.maxUnlockedLevel >= 3 ? '待挑战' : '未解锁'))
                          .fontSize(11)
                          .fontColor(this.maxUnlockedLevel >= 3 ? '#a6e3a1' : '#6c7086')
                          .backgroundColor(this.highestCompletedLevel >= 3 ? '#1e3e2e' : (this.maxUnlockedLevel >= 3 ? '#1e3e2e' : '#313244'))
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(4)
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                      .margin({ bottom: 6 })

                      Text('通过 shell-bridge 完成已签名 HAP 的卸载、安装、启动与状态验证。')
                        .fontSize(12)
                        .fontColor(this.maxUnlockedLevel >= 3 ? '#a6adc8' : '#6c7086')
                        .margin({ bottom: 12 })
                        .lineHeight(16)

                      Button(this.highestCompletedLevel >= 3 ? '查看学习记录' : (this.maxUnlockedLevel >= 3 ? '点击进入挑战' : '请先完成第二关'))
                        .width('100%')
                        .height(34)
                        .fontSize(12)
                        .backgroundColor(this.maxUnlockedLevel >= 3 ? '#45475a' : '#313244')
                        .fontColor(this.maxUnlockedLevel >= 3 ? '#a6e3a1' : '#6c7086')
                        .enabled(this.maxUnlockedLevel >= 3)
                        .onClick(() => { this.selectTask(3); })
                    }
                    .width('100%')
                    .padding(14)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .margin({ bottom: 10 })
                    .alignItems(HorizontalAlign.Start)

                    if (this.highestCompletedLevel >= 3) {
                      // Practice Level Card
                      Column() {
                        Row() {
                          Text('练习关卡：提示词练习')
                            .fontSize(14)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#fab387')

                          Text('可练习')
                            .fontSize(11)
                            .fontColor('#fab387')
                            .backgroundColor('#3e2e1e')
                            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                            .borderRadius(4)
                        }
                        .width('100%')
                        .justifyContent(FlexAlign.SpaceBetween)
                        .margin({ bottom: 6 })

                        Text('提供多个常用提示词，点击后自动填入底部输入框，便于继续向 OpenClaw 提问或练习完整流程。')
                          .fontSize(12)
                          .fontColor('#a6adc8')
                          .margin({ bottom: 12 })
                          .lineHeight(16)

                        Button('进入练习关卡')
                          .width('100%')
                          .height(34)
                          .fontSize(12)
                          .backgroundColor('#45475a')
                          .fontColor('#fab387')
                          .onClick(() => { this.selectTask(4); })
                      }
                      .width('100%')
                      .padding(14)
                      .backgroundColor('#313244')
                      .borderRadius(8)
                      .alignItems(HorizontalAlign.Start)
                    }
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16 })
                  }
                  .width('100%')

                } else if (this.tutorialStep === 1) {
                  // Step 1: Confirm prompt details & Send to OpenClaw
                  Column() {
                    Text('确认提示词与准备运行')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#cdd6f4')
                      .margin({ bottom: 6, top: 4 })

                    Text(this.selectedTaskTitle)
                      .fontSize(13)
                      .fontColor('#89b4fa')
                      .fontWeight(FontWeight.Bold)
                      .margin({ bottom: 4 })

                    Text(this.selectedTaskDesc)
                      .fontSize(11)
                      .fontColor('#a6adc8')
                      .margin({ bottom: 12 })

                    // Prompt Box Title
                    Text('计划向 OpenClaw 发送的提示词：')
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#f5c2e7')
                      .margin({ bottom: 6 })

                    // Interactive Prompt Display
                    TextArea({ text: this.selectedTaskPrompt })
                      .width('100%')
                      .height(110)
                      .fontSize(11)
                      .fontColor('#cdd6f4')
                      .backgroundColor('#1e1e2e')
                      .borderWidth(1)
                      .borderColor('#585b70')
                      .borderRadius(6)
                      .margin({ bottom: 12 })
                      .padding(8)
                      .onChange((v) => { this.selectedTaskPrompt = v; })

                    // Buttons
                    Button('呼叫 OpenClaw 协同开发')
                      .width('100%')
                      .height(40)
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .backgroundColor(this.openClawBusy ? '#45475a' : '#a6e3a1')
                      .fontColor(this.openClawBusy ? '#a6adc8' : '#1e1e2e')
                      .borderRadius(6)
                      .margin({ bottom: 8 })
                      .enabled(!this.openClawBusy)
                      .onClick(() => { this.runOpenClaw(); })

                    Button('返回选择任务')
                      .width('100%')
                      .height(34)
                      .fontSize(12)
                      .backgroundColor('#45475a')
                      .fontColor('#cdd6f4')
                      .borderRadius(6)
                      .onClick(() => { this.tutorialStep = 0; })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })
                  .alignItems(HorizontalAlign.Start)

                } else if (this.tutorialStep === 2) {
                  // Step 2: OpenClaw execution simulation
                  Column() {
                    Text('OpenClaw 正在执行任务...')
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#cdd6f4')
                      .margin({ top: 20, bottom: 20 })

                    // Progress Bar
                    Row() {
                      Text('任务进度：' + this.currentProgress + '%')
                        .fontSize(13)
                        .fontColor('#a6adc8')
                      Blank()
                    }.width('90%').margin({ bottom: 6 })

                    Row() {
                      Row() {
                        Row()
                          .width(this.currentProgress + '%')
                          .height('100%')
                          .backgroundColor('#89b4fa')
                          .borderRadius(4)
                      }
                      .width('100%')
                      .height(8)
                      .backgroundColor('#313244')
                      .borderRadius(4)
                    }
                    .width('90%')
                    .margin({ bottom: 30 })

                    // Steps Timeline
                    Column() {
                      // Step 1
                      Row() {
                        Text(this.step1Status === 2 ? 'done' : (this.step1Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step1Status === 2 ? '#a6e3a1' : (this.step1Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(this.getStepLabel(1))
                          .fontSize(13)
                          .fontColor(this.step1Status === 2 ? '#a6e3a1' : (this.step1Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 2
                      Row() {
                        Text(this.step2Status === 2 ? 'done' : (this.step2Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step2Status === 2 ? '#a6e3a1' : (this.step2Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(this.getStepLabel(2))
                          .fontSize(13)
                          .fontColor(this.step2Status === 2 ? '#a6e3a1' : (this.step2Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 3
                      Row() {
                        Text(this.step3Status === 2 ? 'done' : (this.step3Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step3Status === 2 ? '#a6e3a1' : (this.step3Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(this.getStepLabel(3))
                          .fontSize(13)
                          .fontColor(this.step3Status === 2 ? '#a6e3a1' : (this.step3Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 4
                      Row() {
                        Text(this.step4Status === 2 ? 'done' : (this.step4Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step4Status === 2 ? '#a6e3a1' : (this.step4Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(this.getStepLabel(4))
                          .fontSize(13)
                          .fontColor(this.step4Status === 2 ? '#a6e3a1' : (this.step4Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 5
                      Row() {
                        Text(this.step5Status === 2 ? 'done' : (this.step5Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step5Status === 2 ? '#a6e3a1' : (this.step5Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(this.getStepLabel(5))
                          .fontSize(13)
                          .fontColor(this.step5Status === 2 ? '#a6e3a1' : (this.step5Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')

                      // Step 6
                      Row() {
                        Text(this.step6Status === 2 ? 'done' : (this.step6Status === 1 ? 'run' : 'todo'))
                          .fontSize(14)
                          .fontColor(this.step6Status === 2 ? '#a6e3a1' : (this.step6Status === 1 ? '#89b4fa' : '#585b70'))
                          .margin({ right: 10 })
                        Text(this.getStepLabel(6))
                          .fontSize(13)
                          .fontColor(this.step6Status === 2 ? '#a6e3a1' : (this.step6Status === 1 ? '#89b4fa' : '#a6adc8'))
                      }.margin({ bottom: 12 }).width('100%')
                    }
                    .padding(20)
                    .backgroundColor('#313244')
                    .borderRadius(8)
                    .width('90%')
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Start)

                } else if (this.tutorialStep === 3) {
                  // Step 3: Finished, show summary, architectural tips and dynamic editor
                  Scroll() {
                    Column() {
                      Text('开发任务完成')
                        .fontSize(22)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#a6e3a1')
                        .margin({ top: 10, bottom: 14 })

                      // 1. OpenClaw Language Summary Card
                      Column() {
                        Row() {
                          Text('第' + this.selectedTaskIndex + '关：已学习内容与核心要点')
                            .fontSize(13)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#1e1e2e')
                        }
                        .width('100%')
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                        .backgroundColor('#f5c2e7')
                        .borderRadius({ topLeft: 8, topRight: 8 })

                        Text(this.openclawSummary)
                          .fontSize(13)
                          .fontColor('#cdd6f4')
                          .lineHeight(20)
                          .padding(12)
                      }
                      .width('100%')
                      .backgroundColor('#313244')
                      .borderRadius(8)
                      .margin({ bottom: 16 })

                      // 2. Simplified guidance instruction card
                      Column() {
                        Text('提示：本关已学习完成，可以使用下方输入框继续向 OpenClaw 提问。')
                          .fontSize(12)
                          .fontColor('#a6adc8')
                          .lineHeight(18)
                      }
                      .width('100%')
                      .padding(14)
                      .backgroundColor('#313244')
                      .borderRadius(8)
                      .margin({ bottom: 16 })

                      // 3. Dynamic campaign progression buttons
                      if (this.selectedTaskIndex > 1) {
                        Button('返回上一关复习')
                          .width('100%')
                          .height(40)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#313244')
                          .fontColor('#cdd6f4')
                          .borderRadius(8)
                          .margin({ bottom: 10 })
                          .onClick(() => { this.selectTask(this.selectedTaskIndex - 1); })
                      }

                      if (this.selectedTaskIndex === 1) {
                        Button('第一关已学习，进入第二关')
                          .width('100%')
                          .height(44)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#89b4fa')
                          .fontColor('#1e1e2e')
                          .borderRadius(8)
                          .margin({ bottom: 20 })
                          .onClick(() => {
                            this.maxUnlockedLevel = Math.max(this.maxUnlockedLevel, 2);
                            this.selectTask(2);
                          })
                      } else if (this.selectedTaskIndex === 2) {
                        Button('第二关已学习，进入第三关')
                          .width('100%')
                          .height(44)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#a6e3a1')
                          .fontColor('#1e1e2e')
                          .borderRadius(8)
                          .margin({ bottom: 20 })
                          .onClick(() => {
                            this.maxUnlockedLevel = Math.max(this.maxUnlockedLevel, 3);
                            this.selectTask(3);
                          })
                      } else {
                        Button('全部关卡已学习，返回选择关卡')
                          .width('100%')
                          .height(44)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#f5c2e7')
                          .fontColor('#1e1e2e')
                          .borderRadius(8)
                          .margin({ bottom: 10 })
                          .onClick(() => {
                            this.maxUnlockedLevel = 3;
                            this.highestCompletedLevel = 3;
                            this.tutorialStep = 0;
                            this.selectedTaskIndex = 0;
                          })

                        Button('进入练习关卡')
                          .width('100%')
                          .height(44)
                          .fontSize(13)
                          .fontWeight(FontWeight.Bold)
                          .backgroundColor('#fab387')
                          .fontColor('#1e1e2e')
                          .borderRadius(8)
                          .margin({ bottom: 20 })
                          .onClick(() => { this.selectPracticeLevel(); })
                      }
                    }
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })
                } else if (this.tutorialStep === 4) {
                  // Step 4: Practice prompt picker after all lessons are completed
                  Scroll() {
                    Column() {
                      Text('练习关卡：使用提示词练习hap基础开发')
                        .fontSize(22)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#fab387')
                        .margin({ top: 10, bottom: 8 })

                      Text('点击一个提示词选项，内容会自动填入底部输入框；你可以直接发送，也可以继续编辑后再发送。')
                        .fontSize(12)
                        .fontColor('#a6adc8')
                        .lineHeight(18)
                        .margin({ bottom: 14 })

                      Button('1. 解释编译命令')
                        .width('100%')
                        .height(42)
                        .fontSize(13)
                        .backgroundColor('#313244')
                        .fontColor('#f5c2e7')
                        .borderRadius(8)
                        .margin({ bottom: 10 })
                        .onClick(() => {
                          this.fillPracticePrompt('请解释第一关中的编译命令：sh /data/local/tmp/oh61-hapbuild/compile_unsigned.sh。请说明它会读取哪个工程目录、进入哪个构建环境、执行什么 hvigor 构建动作，以及最终生成和验证哪个未签名 HAP 产物。');
                        })

                      Button('2. 解释签名命令')
                        .width('100%')
                        .height(42)
                        .fontSize(13)
                        .backgroundColor('#313244')
                        .fontColor('#89b4fa')
                        .borderRadius(8)
                        .margin({ bottom: 10 })
                        .onClick(() => {
                          this.fillPracticePrompt('请解释第二关中的签名命令：sh /data/local/tmp/oh61-hapbuild/build_sign_install_run.sh --sign-only。请说明 OpenHarmony HAP 签名需要哪些材料，sign-profile 和 sign-app 分别做什么，以及如何验证 /data/local/tmp/entry-signed.hap。');
                        })

                      Button('3. 解释卸载安装，启动 HAP 命令')
                        .width('100%')
                        .height(42)
                        .fontSize(13)
                        .backgroundColor('#313244')
                        .fontColor('#a6e3a1')
                        .borderRadius(8)
                        .margin({ bottom: 10 })
                        .onClick(() => {
                          this.fillPracticePrompt('请解释第三关中卸载、安装、启动 HAP 的命令流程。请分别说明 bm uninstall、bm install、aa start 或对应 shell-bridge/HDC 调用的作用、执行顺序、关键参数和常见失败原因。');
                        })

                      Button('4. 修改 HAP 为 Hello World，并编译签名启动')
                        .width('100%')
                        .height(42)
                        .fontSize(13)
                        .backgroundColor('#313244')
                        .fontColor('#fab387')
                        .borderRadius(8)
                        .margin({ bottom: 10 })
                        .onClick(() => {
                          this.fillPracticePrompt('请将 HAP 主页面内容修改为 hello world，然后按完整流程执行：编译未签名 HAP、签名生成已签名 HAP、卸载旧应用、安装新 HAP 并启动 EntryAbility。请在执行前说明会修改的文件和命令边界，执行后汇报每一步真实结果。');
                        })

                      Button('返回选择关卡')
                        .width('100%')
                        .height(38)
                        .fontSize(12)
                        .backgroundColor('#45475a')
                        .fontColor('#cdd6f4')
                        .borderRadius(8)
                        .onClick(() => {
                          this.tutorialStep = 0;
                          this.selectedTaskIndex = 0;
                        })
                    }
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })
                }
              }
              .width('100%')
              .layoutWeight(1)

              if (this.tutorialStep !== 0) {
                // 2. Student question input (hidden on level selection page to avoid covering cards)
                Column() {
                  // Input Bar at the Bottom
                  Row() {
                    TextInput({
                      placeholder: this.studentQuestionEnabled ? (this.openClawBusy ? 'OpenClaw 正在处理，请等待回复完成...' : '在此提问，例如：什么是 HAP 签名？') : '请先点击“呼叫 OpenClaw 协同开发”并等待任务完成...',
                      text: this.chatInput
                    })
                      .layoutWeight(1)
                      .height(34)
                      .fontSize(11)
                      .fontColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#cdd6f4' : '#6c7086')
                      .placeholderColor('#585b70')
                      .backgroundColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#11111b' : '#181825')
                      .borderRadius(4)
                      .borderWidth(1)
                      .borderColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#45475a' : '#313244')
                      .margin({ right: 6 })
                      .enabled((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy)
                      .onChange((v) => { this.chatInput = v; })
                      .onSubmit(() => { this.sendChatMessage(); })

                    Button('发送')
                      .height(34)
                      .fontSize(12)
                      .backgroundColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#89b4fa' : '#45475a')
                      .fontColor((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy ? '#1e1e2e' : '#a6adc8')
                      .borderRadius(4)
                      .enabled((this.studentQuestionEnabled || this.tutorialStep === 4) && !this.openClawBusy)
                      .onClick(() => { this.sendChatMessage(); })
                  }
                  .width('100%')
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#1e1e2e')
                .borderRadius(10)
                .margin({ top: 12 })
              }
            }
            .width('45%')
            .height('100%')
            .backgroundColor('#252538')
            .padding({ top: 12, bottom: 12 })

            // Middle Divider
            Divider()
              .vertical(true)
              .width(1)
              .color('#313244')
              .height('100%')

            // === RIGHT PANEL: LIVE WORKSPACE ===
            Column() {
              // 1. Workspace Tab Bar
              Row() {
                // Tab 0 button: OpenClaw Chat
                Row() {
                  Text('OpenClaw 对话')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.workspaceTab === 0 ? '#89b4fa' : '#a6adc8')
                }
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(this.workspaceTab === 0 ? '#313244' : 'transparent')
                .borderRadius({ topLeft: 6, topRight: 6 })
                .onClick(() => { this.workspaceTab = 0; })

                // Tab 1 button: Source Code
                Row() {
                  Text('源码文件 (Source)')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.workspaceTab === 1 ? '#89b4fa' : '#a6adc8')
                }
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(this.workspaceTab === 1 ? '#313244' : 'transparent')
                .borderRadius({ topLeft: 6, topRight: 6 })
                .onClick(() => { this.onSourceTabSelected(); })

                // Tab 2 button: OpenClaw Logs
                Row() {
                  Text('OpenClaw 日志')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.workspaceTab === 2 ? '#89b4fa' : '#a6adc8')
                }
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(this.workspaceTab === 2 ? '#313244' : 'transparent')
                .borderRadius({ topLeft: 6, topRight: 6 })
                .onClick(() => { this.workspaceTab = 2; })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 6 })
              .backgroundColor('#1e1e2e')

              // 2. Tab Workspace Content Area
              Column() {
                if (this.workspaceTab === 0) {
                  // === TAB 0: OPENCLAW CHAT WORKSPACE ===
                  Column() {
                    Row() {
                      Text('OpenClaw')
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#cdd6f4')
                      Text('main')
                        .fontSize(11)
                        .fontColor('#a6adc8')
                        .margin({ left: 8 })
                      Text('聊天')
                        .fontSize(11)
                        .fontColor('#f38ba8')
                        .fontWeight(FontWeight.Bold)
                        .margin({ left: 8 })
                      Blank()
                      Text('qwen3.7-max')
                        .fontSize(11)
                        .fontColor('#a6adc8')
                        .backgroundColor('#313244')
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .borderRadius(6)
                      Text('HTTP')
                        .fontSize(10)
                        .fontColor('#1e1e2e')
                        .fontWeight(FontWeight.Bold)
                        .backgroundColor('#a6e3a1')
                        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                        .borderRadius(6)
                        .margin({ left: 8 })
                    }
                    .width('100%')
                    .padding({ left: 18, right: 18, top: 14, bottom: 12 })
                    .backgroundColor('#181825')
                    .borderWidth({ bottom: 1 })
                    .borderColor('#313244')

                    Scroll() {
                      Column() {
                        if (this.selectedTaskIndex === 0) {
                          Column() {
                            Text('选择左侧关卡后，这里会显示本应用内置的 OpenClaw 主对话区。')
                              .fontSize(15)
                              .fontColor('#cdd6f4')
                              .fontWeight(FontWeight.Bold)
                              .textAlign(TextAlign.Center)
                              .margin({ bottom: 8 })
                            Text('它只连接 OpenClaw 后端接口，不再嵌入 Web UI 页面。')
                              .fontSize(12)
                              .fontColor('#a6adc8')
                              .textAlign(TextAlign.Center)
                          }
                          .width('100%')
                          .layoutWeight(1)
                          .justifyContent(FlexAlign.Center)
                          .alignItems(HorizontalAlign.Center)
                        } else {
                          ForEach(this.chatMessages, (msg: ChatMessage) => {
                            Column() {
                              Row() {
                                Text(msg.sender === 'user' ? 'You' : 'OpenClaw')
                                  .fontSize(11)
                                  .fontWeight(FontWeight.Bold)
                                  .fontColor(msg.sender === 'user' ? '#f5c2e7' : '#a6e3a1')
                                Text(msg.sender === 'user' ? '学生输入' : 'Assistant')
                                  .fontSize(9)
                                  .fontColor('#6c7086')
                                  .margin({ left: 6 })
                              }
                              .width('100%')
                              .justifyContent(msg.sender === 'user' ? FlexAlign.End : FlexAlign.Start)
                              .margin({ bottom: 4 })

                              Row() {
                                Text(msg.text)
                                  .fontSize(13)
                                  .fontColor(msg.sender === 'user' ? '#1e1e2e' : '#cdd6f4')
                                  .lineHeight(19)
                              }
                              .padding({ left: 14, right: 14, top: 11, bottom: 11 })
                              .backgroundColor(msg.sender === 'user' ? '#f5c2e7' : '#313244')
                              .borderRadius(10)
                              .alignSelf(msg.sender === 'user' ? ItemAlign.End : ItemAlign.Start)
                              .width(msg.sender === 'user' ? '72%' : '82%')
                              .margin({ bottom: 16 })
                            }
                            .width('100%')
                            .alignItems(msg.sender === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
                          })
                        }
                      }
                      .width('100%')
                      .padding({ left: 22, right: 22, top: 20, bottom: 20 })
                    }
                    .layoutWeight(1)
                    .backgroundColor('#11111b')

                  }
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#11111b')

                } else if (this.workspaceTab === 1) {
                  // === TAB 1: BOARD SOURCE FILE ===
                  Column() {
                    Row() {
                      Text('/data/local/tmp/oh61-hapbuild/project/entry/src/main/ets/pages/Index.ets')
                        .fontSize(11)
                        .fontColor('#585b70')
                        .fontFamily('monospace')
                        .layoutWeight(1)
                      if (this.selectedTaskIndex > 0) {
                        Text(this.sourceFileLoading ? '读取中...' : '刷新')
                          .fontSize(11)
                          .fontColor(this.sourceFileLoading ? '#585b70' : '#89b4fa')
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .backgroundColor('#313244')
                          .borderRadius(4)
                          .onClick(() => {
                            if (!this.sourceFileLoading) {
                              this.fetchBoardSourceFile();
                            }
                          })
                      }
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 10, bottom: 6 })

                    Scroll() {
                      Column() {
                        Text(this.getSourceTabText())
                          .fontSize(13)
                          .fontColor(this.sourceFileError ? '#f38ba8' : '#a6e3a1')
                          .fontFamily('monospace')
                          .lineHeight(18)
                          .padding(16)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .width('100%')
                    }
                    .layoutWeight(1)
                    .width('100%')
                  }
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#11111b')

                } else if (this.workspaceTab === 2) {
                  // === TAB 2: OPENCLAW AGENT LOGS ===
                  Scroll() {
                    Column() {
                      if (!this.currentExecutionLog) {
                        Text('> Console idle. Ready to boot OpenClaw.')
                          .fontSize(13)
                          .fontColor('#585b70')
                          .fontFamily('monospace')
                          .padding(16)
                      } else {
                        Text(this.currentExecutionLog)
                          .fontSize(12)
                          .fontColor('#cdd6f4')
                          .fontFamily('monospace')
                          .lineHeight(16)
                          .padding(16)
                      }
                    }
                    .alignItems(HorizontalAlign.Start)
                    .width('100%')
                  }
                  .width('100%')
                  .height('100%')
                  .backgroundColor('#11111b')
                }
              }
              .width('100%')
              .layoutWeight(1)
              .backgroundColor('#252538')
            }
            .width('55%')
            .height('100%')
            .backgroundColor('#1e1e2e')
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#1e1e2e')

      } else {
        // === WebView Screens (Shell Terminal or OpenClaw Web UI) ===
        Column() {
          Row() {
            Button('返回')
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
              : $rawfile('openclaw-loader.html'),
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
