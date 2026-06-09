const { execFile } = require('child_process');
const { createServer } = require('http');
const { readFileSync, existsSync, readdirSync, statSync } = require('fs');

const PORT = 7681;
const OPENCLAW_CONFIG = '/data/local/tmp/.openclaw/openclaw.json';
const DEFAULT_HAP = '/data/local/tmp/entry-signed.hap';
const DEFAULT_BUNDLE = 'com.openclaw.studenthap';
const DEFAULT_ABILITY = 'EntryAbility';
const DEFAULT_MODULE = 'entry';
const COURSE_RESTORE_SCRIPT = '/data/local/tmp/oh61-hapbuild/restore_course_project.sh';
const ADVANCED_RESTORE_SCRIPT = '/data/local/tmp/advanced-hapbuild/restore_advanced_project.sh';
// 进入自由开发/教学时把板上已安装的日程 HAP 还原成最原始基线包（只卸载+安装+启动，不编译不签名）。
// 以前由 OpenClaw 在身份初始化那一轮发提示词让 Agent 执行，慢且依赖 LLM；现改为板端直跑、秒级完成。
const ADVANCED_INSTALL_INITIAL_SCRIPT = '/data/local/tmp/advanced-hapbuild/install_initial_advanced.sh';
// 进入「教学之路」时仅启动（aa start）完整主日程 HAP（bundle=com.openclaw.schedulehap），不卸载/不重装。
// 与自由发挥对称、板端直跑不经 OpenClaw，区别是这里只启动完整主 HAP（非 .lite 分身）。
const TEACHING_INSTALL_INITIAL_SCRIPT = '/data/local/tmp/advanced-hapbuild/install_initial_teaching.sh';
// 多元开发：扫雷工程的还原基线 + 安装初始签名 HAP（卸载+安装+启动 minesweeper-signed.hap）。
const MINESWEEPER_RESTORE_SCRIPT = '/data/local/tmp/minesweeper-hapbuild/restore_minesweeper_project.sh';
const MINESWEEPER_INSTALL_INITIAL_SCRIPT = '/data/local/tmp/minesweeper-hapbuild/install_initial_minesweeper.sh';
// 多元开发：随心（空白）工程的还原基线 + 安装初始签名 HAP（卸载+安装+启动 blank-signed.hap）。
const BLANK_RESTORE_SCRIPT = '/data/local/tmp/blank-hapbuild/restore_blank_project.sh';
const BLANK_INSTALL_INITIAL_SCRIPT = '/data/local/tmp/blank-hapbuild/install_initial_blank.sh';
const HDC_SHELL_GROUPS = [0, 1006, 1007, 2000, 3009];
const ALLOWED_READ_PREFIXES = [
  '/data/local/tmp/oh61-hapbuild/project/',
  '/data/local/tmp/advanced-hapbuild/project/',
  '/data/local/tmp/minesweeper-hapbuild/project/',
  '/data/local/tmp/blank-hapbuild/project/',
  '/data/local/tmp/.openclaw/workspace/memory/',
];
// 允许「目录列举」的根目录（用于源码区浏览整个工程的文件树）。
const ALLOWED_LIST_DIRS = [
  '/data/local/tmp/oh61-hapbuild/project',
  '/data/local/tmp/advanced-hapbuild/project',
  '/data/local/tmp/minesweeper-hapbuild/project',
  '/data/local/tmp/blank-hapbuild/project',
];
// 列举文件树时跳过的目录名（构建产物、依赖、隐藏工程目录等，避免列出海量无关文件）。
const LIST_SKIP_DIRS = new Set([
  'node_modules', 'oh_modules', 'build', '.hvigor', '.git', '.idea',
  '.cxx', '.preview', '.clangd', 'ohosTest', 'test', '.cache',
]);
const LIST_MAX_FILES = 800;

function parseQueryParam(url, key) {
  const q = url.indexOf('?');
  if (q < 0) return '';
  for (const part of url.slice(q + 1).split('&')) {
    const eq = part.indexOf('=');
    if (eq < 0) continue;
    if (decodeURIComponent(part.slice(0, eq)) === key) {
      return decodeURIComponent(part.slice(eq + 1));
    }
  }
  return '';
}

function isAllowedReadPath(filePath) {
  return ALLOWED_READ_PREFIXES.some((prefix) => filePath.startsWith(prefix));
}

function readBoardFile(filePath) {
  if (!filePath) return { ok: false, status: 400, output: 'missing path query parameter\n' };
  if (!isAllowedReadPath(filePath)) return { ok: false, status: 403, output: 'path not allowed: ' + filePath + '\n' };
  if (!existsSync(filePath)) return { ok: false, status: 404, output: 'file not found: ' + filePath + '\n' };
  try {
    return { ok: true, status: 200, output: readFileSync(filePath, 'utf8') };
  } catch (e) {
    return { ok: false, status: 500, output: 'error: ' + e.message + '\n' };
  }
}

function normalizeDir(dirPath) {
  // 去掉结尾的斜杠，便于与白名单根目录比对。
  return dirPath.replace(/\/+$/, '');
}

function isAllowedListDir(dirPath) {
  return ALLOWED_LIST_DIRS.indexOf(normalizeDir(dirPath)) >= 0;
}

// 递归列举 rootDir 下的所有文件，返回相对 rootDir 的路径（正斜杠分隔），已排序。
function collectFiles(rootDir) {
  const results = [];
  const walk = (absDir, relPrefix) => {
    if (results.length >= LIST_MAX_FILES) return;
    let entries;
    try {
      entries = readdirSync(absDir);
    } catch (e) {
      return;
    }
    entries.sort();
    for (const name of entries) {
      if (results.length >= LIST_MAX_FILES) return;
      const abs = absDir + '/' + name;
      const rel = relPrefix ? relPrefix + '/' + name : name;
      let st;
      try {
        st = statSync(abs);
      } catch (e) {
        continue;
      }
      if (st.isDirectory()) {
        if (LIST_SKIP_DIRS.has(name) || name.startsWith('.')) continue;
        walk(abs, rel);
      } else if (st.isFile()) {
        results.push(rel);
      }
    }
  };
  walk(normalizeDir(rootDir), '');
  return results;
}

function listBoardFiles(dirPath) {
  if (!dirPath) return { ok: false, status: 400, output: 'missing path query parameter\n' };
  if (!isAllowedListDir(dirPath)) return { ok: false, status: 403, output: 'path not allowed: ' + dirPath + '\n' };
  if (!existsSync(normalizeDir(dirPath))) return { ok: false, status: 404, output: 'dir not found: ' + dirPath + '\n' };
  try {
    const files = collectFiles(dirPath);
    return { ok: true, status: 200, output: files.join('\n') + '\n' };
  } catch (e) {
    return { ok: false, status: 500, output: 'error: ' + e.message + '\n' };
  }
}

function ensureHdcShellLikeContext() {
  try {
    if (typeof process.setgroups === 'function') {
      process.setgroups(HDC_SHELL_GROUPS);
      console.log('[shell-bridge] supplementary groups set to hdc-shell compatible set: ' + HDC_SHELL_GROUPS.join(','));
    }
  } catch (e) {
    console.error('[shell-bridge] failed to set supplementary groups: ' + e.message);
  }

  process.env.PATH = '/usr/local/bin:/bin:/usr/bin:/system/bin:/vendor/bin:/data/local/bin';
  process.env.HOME = '/data/local/tmp';
}

ensureHdcShellLikeContext();

function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }
function run(cmd, args, timeout = 120000) {
  return new Promise((resolve) => {
    execFile(cmd, args, { timeout }, (error, stdout, stderr) => {
      resolve({
        code: error ? (typeof error.code === 'number' ? error.code : 1) : 0,
        stdout: stdout || '',
        stderr: stderr || '',
        error: error ? error.message : ''
      });
    });
  });
}

async function runFixedScript(scriptPath, timeout = 120000) {
  if (!existsSync(scriptPath)) {
    return { ok: false, output: `missing script: ${scriptPath}\n` };
  }
  const result = await run('/system/bin/sh', [scriptPath], timeout);
  const output = [result.stdout, result.stderr, result.error].filter(Boolean).join('\n');
  return { ok: result.code === 0, output };
}

async function waitDockerReady(steps, maxTries = 30) {
  for (let i = 1; i <= maxTries; i++) {
    const info = await run('/data/local/bin/docker', ['-H', 'unix:///data/docker2/run/docker.sock', 'info'], 10000);
    if (info.code === 0) { steps.push(`[ready] dockerd ready after ${i}x2s`); return true; }
    if (i === 1 || i === maxTries || i % 5 === 0) steps.push(`[ready] waiting dockerd ${i}/${maxTries}: ${info.stderr || info.error || 'not ready'}`);
    await sleep(2000);
  }
  return false;
}

async function dockerPs(steps) {
  const ps = await run('/data/local/bin/dockerc2', ['ps', '--format', '{{.Names}} {{.Status}}'], 30000);
  steps.push('$ dockerc2 ps --format', ps.stdout, ps.stderr, ps.error);
  return ps;
}

function psHasLinuxEnv(ps) {
  return ps.code === 0 && ps.stdout.split('\n').some((line) => line.startsWith('linux-env ') && line.includes('Up'));
}

async function startHap() {
  const start = await run('/bin/aa', ['start', '-a', DEFAULT_ABILITY, '-b', DEFAULT_BUNDLE, '-m', DEFAULT_MODULE]);
  const output = ['$ aa start -a ' + DEFAULT_ABILITY + ' -b ' + DEFAULT_BUNDLE + ' -m ' + DEFAULT_MODULE, start.stdout, start.stderr, start.error].filter(Boolean).join('\n');
  return { ok: start.code === 0, output };
}

async function uninstallHap() {
  const uninstall = await run('/bin/bm', ['uninstall', '-n', DEFAULT_BUNDLE]);
  const output = ['$ bm uninstall -n ' + DEFAULT_BUNDLE, uninstall.stdout, uninstall.stderr, uninstall.error].filter(Boolean).join('\n');
  const notInstalled = /not exist|does not exist|not found|not installed/i.test(output);
  return { ok: uninstall.code === 0 || notInstalled, output };
}

async function installAndStart() {
  if (!existsSync(DEFAULT_HAP)) return { ok: false, output: `missing hap: ${DEFAULT_HAP}\n` };
  const install = await run('/bin/bm', ['install', '-p', DEFAULT_HAP]);
  const started = await startHap();
  const output = ['$ bm install -p ' + DEFAULT_HAP, install.stdout, install.stderr, install.error, started.output].filter(Boolean).join('\n');
  return { ok: install.code === 0 && started.ok, output };
}

async function startLinuxEnv() {
  const steps = [];
  const ready = await waitDockerReady(steps, 30);
  if (!ready) return { ok: false, output: steps.concat('[error] dockerd not ready').filter(Boolean).join('\n') };
  let ps = await dockerPs(steps);
  if (psHasLinuxEnv(ps)) return { ok: true, output: steps.concat('[ok] linux-env already running').filter(Boolean).join('\n') };
  const inspect = await run('/data/local/bin/dockerc2', ['inspect', 'linux-env', '--format', '{{.State.Status}}'], 30000);
  steps.push('$ dockerc2 inspect linux-env', inspect.stdout, inspect.stderr, inspect.error);
  const start = await run('/data/local/bin/dockerc2', ['start', 'linux-env'], 120000);
  steps.push('$ dockerc2 start linux-env', start.stdout, start.stderr, start.error);
  await sleep(3000);
  ps = await dockerPs(steps);
  return { ok: psHasLinuxEnv(ps), output: steps.filter(Boolean).join('\n') };
}

function sendResult(res, result) {
  res.writeHead(result.ok ? 200 : 500, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Access-Control-Allow-Origin': '*'
  });
  res.end(result.output + '\n');
}

const server = createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/token') {
    try {
      const config = JSON.parse(readFileSync(OPENCLAW_CONFIG, 'utf8'));
      const token = config.gateway && config.gateway.auth && config.gateway.auth.token || '';
      res.writeHead(200, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
      res.end(token);
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
      res.end('error: ' + e.message);
    }
    return;
  }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/install-hap') { sendResult(res, await installAndStart()); return; }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/start-hap') { sendResult(res, await startHap()); return; }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/uninstall-hap') { sendResult(res, await uninstallHap()); return; }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/start-linux-env') { sendResult(res, await startLinuxEnv()); return; }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/reset-course') {
    sendResult(res, await runFixedScript(COURSE_RESTORE_SCRIPT, 30000));
    return;
  }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/reset-advanced') {
    sendResult(res, await runFixedScript(ADVANCED_RESTORE_SCRIPT, 30000));
    return;
  }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/install-initial') {
    sendResult(res, await runFixedScript(ADVANCED_INSTALL_INITIAL_SCRIPT, 60000));
    return;
  }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/install-teaching') {
    sendResult(res, await runFixedScript(TEACHING_INSTALL_INITIAL_SCRIPT, 60000));
    return;
  }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/reset-minesweeper') {
    sendResult(res, await runFixedScript(MINESWEEPER_RESTORE_SCRIPT, 30000));
    return;
  }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/install-minesweeper') {
    sendResult(res, await runFixedScript(MINESWEEPER_INSTALL_INITIAL_SCRIPT, 60000));
    return;
  }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/reset-blank') {
    sendResult(res, await runFixedScript(BLANK_RESTORE_SCRIPT, 30000));
    return;
  }
  if ((req.method === 'POST' || req.method === 'GET') && req.url === '/install-blank') {
    sendResult(res, await runFixedScript(BLANK_INSTALL_INITIAL_SCRIPT, 60000));
    return;
  }
  if (req.method === 'GET' && req.url.startsWith('/read-file')) {
    const filePath = parseQueryParam(req.url, 'path');
    const result = readBoardFile(filePath);
    res.writeHead(result.status, { 'Content-Type': 'text/plain; charset=utf-8', 'Access-Control-Allow-Origin': '*' });
    res.end(result.output);
    return;
  }
  if (req.method === 'GET' && req.url.startsWith('/list-files')) {
    const dirPath = parseQueryParam(req.url, 'path');
    const result = listBoardFiles(dirPath);
    res.writeHead(result.status, { 'Content-Type': 'text/plain; charset=utf-8', 'Access-Control-Allow-Origin': '*' });
    res.end(result.output);
    return;
  }
  res.writeHead(404);
  res.end('Not Found');
});

async function autoStartContainerServices() {
  const startupScript = '/data/local/tmp/autostart_houmo.sh';
  if (!existsSync(startupScript)) return;
  console.log('[shell-bridge] Waiting for linux-env to be running before executing autostart...');
  for (let i = 1; i <= 30; i++) {
    const steps = [];
    const ps = await dockerPs(steps);
    if (psHasLinuxEnv(ps)) {
      console.log(`[shell-bridge] linux-env is running! Triggering autostart script: ${startupScript}`);
      const result = await run('/system/bin/sh', [startupScript]);
      console.log(`[shell-bridge] Startup script completed with code: ${result.code}`);
      return;
    }
    await sleep(2000);
  }
  console.error('[shell-bridge] ERROR: linux-env did not start in time. Aborting autostart.');
}

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[shell-bridge] listening on :${PORT} (HTTP only)`);
  autoStartContainerServices();
});
