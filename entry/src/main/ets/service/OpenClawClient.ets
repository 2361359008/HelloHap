// OpenClaw 传输/服务层
// 从 pages/Index.ets 抽取的网络客户端：封装 shell-bridge HTTP 取 token、
// 与 OpenClaw 网关的 WebSocket 连接、RPC 收发、会话管理与一轮对话流程。
// UI 状态更新通过 onChatEvent 回调交由页面处理，本类不直接操作组件 @State。

import { http, webSocket } from '@kit.NetworkKit';
import { PendingRequest, OpenClawConnectParams, OpenClawRpcRequest,
  OpenClawEmptyParams, OpenClawCreateSessionParams, OpenClawHistoryParams, OpenClawSendParams } from '../model/OpenClawTypes';

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
        let sendParams = new OpenClawSendParams(this.sessionKey, this.sessionId, message, runId);

        await this.sendRpcRequest('chat.send', sendParams);
      } catch (e) {
        this.agentTurnResolve = null;
        this.agentTurnReject = null;
        reject(e as Error);
      }
    });
  }

  // 由页面在收到 chat 'final' 事件时调用，解析当前对话轮次。
  completeTurn(text: string): void {
    if (this.agentTurnResolve) {
      this.agentTurnResolve(text);
      this.agentTurnResolve = null;
      this.agentTurnReject = null;
    }
  }

  // 由页面在收到 chat 'error'/'aborted' 事件时调用，拒绝当前对话轮次。
  failTurn(err: Error): void {
    if (this.agentTurnReject) {
      this.agentTurnReject(err);
      this.agentTurnResolve = null;
      this.agentTurnReject = null;
    }
  }

  // 重置连接与会话状态（课程重置时调用）。
  reset(): void {
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
    this.sessionId = '';
    this.sessionKey = '';
    this.currentAgentId = '';
    this.agentTurnResolve = null;
    this.agentTurnReject = null;
  }
}
