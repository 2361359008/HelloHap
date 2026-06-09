// OpenClaw 数据模型与 RPC 协议类型
// 从 pages/Index.ets 抽取，集中管理对话消息与 OpenClaw 网关 RPC 报文结构。

// 对话消息。kind 决定富展示样式：
//   'text'       普通文本气泡（用户/助手）
//   'thinking'   OpenClaw 思考过程（暗色折叠块）
//   'toolCall'   OpenClaw 调用工具（read/exec 等，显示工具名 + 参数摘要）
//   'toolResult' 工具返回结果（等宽，可折叠，出错标红）
// toolName/toolArgs/isError 仅在工具相关 kind 使用；collapsed 控制长内容默认折叠。
export class ChatMessage {
  sender: string = '';
  text: string = '';
  kind: string = 'text';
  toolName: string = '';
  toolArgs: string = '';
  isError: boolean = false;
  collapsed: boolean = true;
  constructor(sender: string, text: string, kind: string = 'text',
      toolName: string = '', toolArgs: string = '', isError: boolean = false) {
    this.sender = sender;
    this.text = text;
    this.kind = kind;
    this.toolName = toolName;
    this.toolArgs = toolArgs;
    this.isError = isError;
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

// chat.abort 参数：中止指定 runId 的在途对话/任务（如仍在跑的自动编译）。
// 网关要求必须带 sessionKey，否则报 "invalid chat.abort params: must have required property 'sessionKey'"。
export class OpenClawAbortParams {
  sessionKey: string = '';
  runId?: string;

  constructor(sessionKey: string, runId: string = '') {
    this.sessionKey = sessionKey;
    if (runId) {
      this.runId = runId;
    }
  }
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
