// HTTPS → HTTP 反向代理（含 WebSocket 支持）
// 用途：让强制 https 的浏览器能访问 http 的 gateway
// 部署：/data/local/tmp/https-proxy.js
// 证书：/data/local/tmp/proxy-cert.pem, /data/local/tmp/proxy-key.pem
// 启动：LD_LIBRARY_PATH=/system/lib64 /data/local/tmp/node /data/local/tmp/https-proxy.js

const https = require('https');
const http = require('http');
const net = require('net');
const fs = require('fs');

const LISTEN_PORT = 18801;        // HTTPS 对外端口
const TARGET_HOST = '127.0.0.1';
const TARGET_PORT = 18800;        // gateway HTTP/WS 端口

const CERT_FILE = '/data/local/tmp/proxy-cert.pem';
const KEY_FILE = '/data/local/tmp/proxy-key.pem';

const httpsOpts = {
  cert: fs.readFileSync(CERT_FILE),
  key: fs.readFileSync(KEY_FILE)
};

// HTTPS 服务器：处理普通 HTTP 请求
const server = https.createServer(httpsOpts, (req, res) => {
  // 根路径重定向到 canvas
  if (req.url === '/' || req.url === '') {
    res.writeHead(302, { 'Location': '/__openclaw__/canvas/' });
    res.end();
    return;
  }
  const proxyReq = http.request({
    host: TARGET_HOST,
    port: TARGET_PORT,
    method: req.method,
    path: req.url,
    headers: { ...req.headers, host: `${TARGET_HOST}:${TARGET_PORT}` }
  }, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });
  proxyReq.on('error', (e) => {
    console.error('[proxy] http error:', e.message);
    res.writeHead(502); res.end('Bad Gateway: ' + e.message);
  });
  req.pipe(proxyReq);
});

// WebSocket upgrade（wss → ws）
server.on('upgrade', (req, clientSocket, head) => {
  const upstream = net.connect(TARGET_PORT, TARGET_HOST, () => {
    const reqLines = [`${req.method} ${req.url} HTTP/${req.httpVersion}`];
    for (const k of Object.keys(req.headers)) {
      const v = req.headers[k];
      if (Array.isArray(v)) for (const x of v) reqLines.push(`${k}: ${x}`);
      else reqLines.push(`${k}: ${v}`);
    }
    upstream.write(reqLines.join('\r\n') + '\r\n\r\n');
    if (head && head.length) upstream.write(head);
    upstream.pipe(clientSocket);
    clientSocket.pipe(upstream);
  });
  upstream.on('error', (e) => { console.error('[proxy] ws upstream err:', e.message); clientSocket.end(); });
  clientSocket.on('error', (e) => { console.error('[proxy] ws client err:', e.message); upstream.end(); });
});

server.listen(LISTEN_PORT, '0.0.0.0', () => {
  console.log(`[proxy] HTTPS listening on 0.0.0.0:${LISTEN_PORT} -> http://${TARGET_HOST}:${TARGET_PORT}`);
});
