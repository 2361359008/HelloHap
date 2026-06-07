// OpenClaw 数据模型与 RPC 协议类型
// 从 pages/Index.ets 抽取，集中管理对话消息与 OpenClaw 网关 RPC 报文结构。

export class ChatMessage {
  sender: string = '';
  text: string = '';
  constructor(sender: string, text: string) {
    this.sender = sender;
    this.text = text;
  }
}

export class PendingRequest {
  id: string = '';
  resolve: (value: string) => void = () => {};
  reject: (err: Error) => void = () => {};
  constructor(id: string, resolve: (value: string) => void, reject: (err: Error) => void) {
    this.id = id;
    this.resolve = resolve;
    this.reject = reject;
  }
}

export class OpenClawRpcAuth {
  token: string = '';
  constructor(token: string) {
    this.token = token;
  }
}

export class OpenClawRpcClient {
  id: string = 'openclaw-control-ui';
  version: string = 'control-ui';
  platform: string = 'openharmony';
  mode: string = 'webchat';
  instanceId: string = 'openharmony-hap-tutorial';
}

export class OpenClawConnectParams {
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

export class OpenClawHistoryParams {
  sessionKey: string = '';
  limit: number = 100;
  maxChars: number = 120000;

  constructor(sessionKey: string) {
    this.sessionKey = sessionKey;
  }
}

export class OpenClawSendParams {
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

export class OpenClawRpcRequest {
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

export class OpenClawEmptyParams {
}

// sessions.create 参数：可选 agentId，把会话绑定到指定 agent（多 agent 身份隔离）。
// 留空则由网关使用默认 agent（main）。
export class OpenClawCreateSessionParams {
  agentId?: string;

  constructor(agentId: string) {
    if (agentId) {
      this.agentId = agentId;
    }
  }
}
