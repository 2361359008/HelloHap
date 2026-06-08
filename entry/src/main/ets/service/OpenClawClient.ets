// OpenClaw 传输/服务层
// 从 pages/Index.ets 抽取的网络客户端：封装 shell-bridge HTTP 取 token、
// 与 OpenClaw 网关的 WebSocket 连接、RPC 收发、会话管理与一轮对话流程。
// UI 状态更新通过 onChatEvent 回调交由页面处理，本类不直接操作组件 @State。

import { http, webSocket } from '@kit.NetworkKit';
import { PendingRequest, OpenClawConnectParams, OpenClawRpcRequest,
  OpenClawEmptyParams, OpenClawCreateSessionParams, OpenClawHistoryParams, OpenClawSendParams,
  OpenClawAbortParams } from '../model/OpenClawTypes';

export class OpenClawClient {
  private ws: webSocket.WebSocket | null = null;
  private pendingRequests: Array<PendingRequest> = [];
  private token: string = '';
  sessionId: string = '';
  sessionKey: string = '';
  // 当前会话绑定的 agent（''=默认 main）。切换 agent 时重建会话，实现身份隔离。
  private currentAgentId: string = '';
  private agentTurnResolve: ((value: string) => void) | null = null;
  private agentTurnReject: ((err: Error) => void) | null = null;
  // 当前在途 run 的 id。用于在「重置课程 / 进入自由发挥」时给网关发 chat.abort，
  // 真正中止那一轮仍在板上跑的长任务（如自动编译 ~100s），而不是任由它空跑。
  private activeRunId: string = '';

  // 流式 chat 事件回调，由页面注入，用于更新对话 UI 状态。
  onChatEvent: (payload: Record<string, Object>) => void = () => {};

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

  async getToken(): Promise<string> {
    let token = await this.requestText('http://127.0.0.1:7681/token', http.RequestMethod.GET);
    token = token.trim();
    if (!token || token.indexOf('error') === 0) {
      throw new Error(token || 'empty token');
    }
    this.token = token;
    return token;
  }

  setupWebSocket(token: string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.ws) {
        resolve();
        return;
      }
      this.ws = webSocket.createWebSocket();
      // 记住本次创建的 socket 实例。reset()/重连后 this.ws 会指向新实例，
      // 旧 socket 仍可能投递上一轮会话的残留事件——用实例比对把它们全部丢弃，
      // 避免「重置后再进自由发挥，旧会话事件污染新会话」的竞态。
      let socket = this.ws;
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
        // 丢弃来自已被取代/关闭的旧 socket 的消息：它们属于上一轮会话，
        // 若放行会错误地解析为当前会话的事件（提前关遮罩、提前结束新轮次）。
        if (socket !== this.ws) {
          return;
        }
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
        // 仅当关闭的是「当前」连接才清状态：旧连接被延迟关闭时不能误清掉新连接/新一轮。
        if (socket !== this.ws) {
          return;
        }
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
        // 同上：旧连接的 error 不能误清当前连接状态。
        if (socket !== this.ws) {
          return;
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

  private handleRpcMessage(raw: string, handshakeResolve: () => void, handshakeReject: (err: Error) => void) {
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
          // 记下网关分配给本轮的 runId，供 abort 使用。
          if (payload['runId']) {
            this.activeRunId = String(payload['runId']);
          }
          this.onChatEvent(payload);
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

  sendRpcRequest(method: string, params: Object): Promise<string> {
    return new Promise(async (resolve, reject) => {
      try {
        let token = await this.getToken();
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

  // 确保已有会话：必要时创建 session，并刷新 sessionId。
  // agentId 用于把会话绑定到指定 agent（''=默认 main）；切换 agent 时重建会话。
  private async ensureSession(agentId: string): Promise<void> {
    if (agentId !== this.currentAgentId) {
      this.currentAgentId = agentId;
      this.sessionKey = '';
      this.sessionId = '';
    }
    if (!this.sessionKey) {
      let createRes = await this.sendRpcRequest('sessions.create', new OpenClawCreateSessionParams(agentId));
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
      this.sessionKey = sKey;
    }

    let histRes = await this.sendRpcRequest('chat.history', new OpenClawHistoryParams(this.sessionKey));
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
    this.sessionId = sessId;
  }

  // 发起一轮对话/任务：连接 -> 建会话 -> 触发占位回调 -> 发送消息。
  // 返回的 Promise 在收到 chat 'final' 事件后由 completeTurn 解析。
  startTurn(message: string, onPlaceholder: () => void, agentId: string = ''): Promise<string> {
    return new Promise(async (resolve, reject) => {
      this.agentTurnResolve = resolve;
      this.agentTurnReject = reject;

      try {
        let token = await this.getToken();
        await this.setupWebSocket(token);
        await this.ensureSession(agentId);

        onPlaceholder();

        let runId = 'run-' + Date.now().toString() + '-' + Math.floor(Math.random() * 1000).toString();
        this.activeRunId = runId;
        let sendParams = new OpenClawSendParams(this.sessionKey, this.sessionId, message, runId);

        let sendRes = await this.sendRpcRequest('chat.send', sendParams);
        // chat.send 的响应里通常带回网关实际使用的 runId，优先用它（与事件里的一致）。
        try {
          let sendPayload = JSON.parse(sendRes) as Record<string, Object>;
          if (sendPayload['runId']) {
            this.activeRunId = String(sendPayload['runId']);
          }
        } catch (parseErr) {
          // 解析失败就保留本地生成的 runId。
        }
      } catch (e) {
        this.agentTurnResolve = null;
        this.agentTurnReject = null;
        reject(e as Error);
      }
    });
  }

  // 由页面在收到 chat 'final' 事件时调用，解析当前对话轮次。
  completeTurn(text: string): void {
    this.activeRunId = '';
    if (this.agentTurnResolve) {
      this.agentTurnResolve(text);
      this.agentTurnResolve = null;
      this.agentTurnReject = null;
    }
  }

  // 由页面在收到 chat 'error'/'aborted' 事件时调用，拒绝当前对话轮次。
  failTurn(err: Error): void {
    this.activeRunId = '';
    if (this.agentTurnReject) {
      this.agentTurnReject(err);
      this.agentTurnResolve = null;
      this.agentTurnReject = null;
    }
  }

  // 在指定连接上给网关发 chat.abort 中止当前在途 run（fire-and-forget：不进 pendingRequests、
  // 不等响应）。用于「重置课程 / 进入自由发挥」前停掉上一轮仍在跑的长任务（如自动编译 ~100s）。
  private abortActiveRun(targetWs: webSocket.WebSocket | null): void {
    let runId = this.activeRunId;
    this.activeRunId = '';
    if (!runId || !targetWs) {
      return;
    }
    try {
      let reqId = 'abort-' + Date.now().toString();
      let req = new OpenClawRpcRequest(reqId, 'chat.abort', new OpenClawAbortParams(runId));
      targetWs.send(JSON.stringify(req), (err: Object) => {
        if (err) {
          console.error('chat.abort send failed: ' + JSON.stringify(err));
        }
      });
    } catch (e) {
      console.error('chat.abort error: ' + (e as Error).message);
    }
  }

  // 重置连接与会话状态（课程重置时调用）。
  reset(): void {
    // 先把旧连接从 this.ws 摘下来：之后 message 守卫会立刻丢弃它的残留事件。
    let oldWs = this.ws;
    this.ws = null;
    // 在仍连着的旧连接上发 chat.abort，停掉仍在跑的上一轮长任务（否则它会在网关上空跑满 ~100s）。
    this.abortActiveRun(oldWs);
    // 稍等让 abort 帧发出后再关旧连接（立刻 close 可能来不及把 abort 送出去）。
    if (oldWs) {
      setTimeout(() => {
        try {
          oldWs.close();
        } catch (e) {
          console.error('Error closing WebSocket: ' + (e as Error).message);
        }
      }, 600);
    }
    this.pendingRequests.forEach(req => req.reject(new Error('Course reset')));
    this.pendingRequests = [];
    this.sessionId = '';
    this.sessionKey = '';
    this.currentAgentId = '';
    // 若重置时正有一轮对话在途，必须显式 reject 它，让等待 startTurn 的调用方
    // （如 initFreeDevIdentity）解开挂起、复位 openClawBusy；否则会留下「卡在上一轮」的僵态。
    let pendingReject = this.agentTurnReject;
    this.agentTurnResolve = null;
    this.agentTurnReject = null;
    if (pendingReject) {
      pendingReject(new Error('Course reset'));
    }
  }
}
