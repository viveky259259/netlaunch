#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');
const { exec } = require('child_process');

const DEPLOY_URL = 'https://us-central1-deployinstantwebapp.cloudfunctions.net/cliDeploy';
const AUTH_PAGE = 'https://deployinstantwebapp.web.app/cli-auth.html';
const FIREBASE_API_KEY = 'AIzaSyCGFdR_W2fIX9bL9TMclqXglqhDj5b0eDc';
const CREDS_DIR = path.join(require('os').homedir(), '.netlaunch');
const CREDS_FILE = path.join(CREDS_DIR, 'credentials.json');
const CONFIG_FILE = path.join(CREDS_DIR, 'firebase-config.json');

// ── Helpers ──────────────────────────────────────────────────────────

function bold(t) { return `\x1b[1m${t}\x1b[0m`; }
function green(t) { return `\x1b[32m${t}\x1b[0m`; }
function red(t) { return `\x1b[31m${t}\x1b[0m`; }
function cyan(t) { return `\x1b[36m${t}\x1b[0m`; }
function dim(t) { return `\x1b[2m${t}\x1b[0m`; }
function yellow(t) { return `\x1b[33m${t}\x1b[0m`; }

function openBrowser(url) {
  const cmd = process.platform === 'darwin' ? 'open'
    : process.platform === 'win32' ? 'start'
    : 'xdg-open';
  exec(`${cmd} "${url}"`);
}

function printUsage() {
  console.log(`
${bold('NetLaunch CLI')} — deploy static sites in seconds

${bold('COMMANDS')}
  login              Sign in with Google (opens browser)
  logout             Remove stored credentials
  whoami             Show current logged-in user
  deploy             Deploy a ZIP archive
  config set         Set Firebase config for self-hosted deploys
  config show        Show current Firebase config
  config remove      Remove Firebase config (use NetLaunch hosting)

${bold('DEPLOY OPTIONS')}
  --key,  -k     API key (fk_...) — optional if logged in
  --site, -s     Site name / subdomain (3-30 chars, lowercase)
  --file, -f     Path to ZIP archive
  --hosted       Force deploy to NetLaunch (ignore saved config)

${bold('CONFIG OPTIONS')}
  --file, -f     Path to service account JSON
  --sync         Also save config to server (use from dashboard)

${bold('EXAMPLES')}
  netlaunch login
  netlaunch deploy -s my-app -f ./dist.zip
  netlaunch config set -f ./service-account.json --sync
  netlaunch config show
  netlaunch deploy -s my-app -f ./dist.zip --hosted

${bold('ENVIRONMENT')}
  NETLAUNCH_KEY   API key (alternative to --key flag)
`);
}

function parseArgs(args) {
  const opts = {};
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--key' || arg === '-k') opts.key = args[++i];
    else if (arg === '--site' || arg === '-s') opts.site = args[++i];
    else if (arg === '--file' || arg === '-f') opts.file = args[++i];
    else if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg === '--sync') opts.sync = true;
    else if (arg === '--hosted') opts.hosted = true;
    else if (arg === 'config') {
      opts.command = 'config';
      // Next arg is the subcommand
      if (i + 1 < args.length && ['set', 'show', 'remove'].includes(args[i + 1])) {
        opts.configSub = args[++i];
      }
    }
    else if (['deploy', 'login', 'logout', 'whoami'].includes(arg)) opts.command = arg;
  }
  return opts;
}

// ── Credentials ─────────────────────────────────────────────────────

function loadCredentials() {
  try {
    if (fs.existsSync(CREDS_FILE)) {
      return JSON.parse(fs.readFileSync(CREDS_FILE, 'utf-8'));
    }
  } catch { /* ignore */ }
  return null;
}

function saveCredentials(creds) {
  fs.mkdirSync(CREDS_DIR, { recursive: true });
  fs.writeFileSync(CREDS_FILE, JSON.stringify(creds, null, 2), { mode: 0o600 });
}

function clearCredentials() {
  try {
    if (fs.existsSync(CREDS_FILE)) fs.unlinkSync(CREDS_FILE);
  } catch { /* ignore */ }
}

// ── Token refresh ───────────────────────────────────────────────────

function refreshIdToken(refreshToken) {
  return new Promise((resolve, reject) => {
    const postData = `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}`;
    const req = https.request({
      hostname: 'securetoken.googleapis.com',
      path: `/v1/token?key=${FIREBASE_API_KEY}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.id_token) {
            resolve({
              idToken: json.id_token,
              refreshToken: json.refresh_token,
              expiresIn: parseInt(json.expires_in, 10),
            });
          } else {
            reject(new Error(json.error?.message || 'Token refresh failed'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function getValidIdToken() {
  const creds = loadCredentials();
  if (!creds || !creds.refreshToken) return null;

  // Check if token is still valid (with 60s buffer)
  if (creds.idToken && creds.expiresAt && Date.now() < creds.expiresAt - 60000) {
    return creds.idToken;
  }

  // Refresh the token
  try {
    const result = await refreshIdToken(creds.refreshToken);
    creds.idToken = result.idToken;
    creds.refreshToken = result.refreshToken;
    creds.expiresAt = Date.now() + result.expiresIn * 1000;
    saveCredentials(creds);
    return creds.idToken;
  } catch (err) {
    console.error(yellow('Session expired. Please run: netlaunch login'));
    return null;
  }
}

// ── Generate API key via callable function ───────────────────────────

function callFirebaseFunction(functionName, data, idToken) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({ data });
    const req = https.request({
      hostname: 'us-central1-deployinstantwebapp.cloudfunctions.net',
      path: `/${functionName}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${idToken}`,
        'Content-Length': Buffer.byteLength(postData),
      },
    }, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          if (json.result) resolve(json.result);
          else if (json.error) reject(new Error(json.error.message || 'Function call failed'));
          else resolve(json);
        } catch {
          reject(new Error(`Unexpected response: ${body}`));
        }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

// ── Login ────────────────────────────────────────────────────────────

async function login() {
  console.log(`\n${bold('NetLaunch Login')}`);
  console.log(dim('─'.repeat(40)));

  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      // CORS for the auth page POST
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

      if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
      }

      if (req.method === 'POST' && req.url === '/callback') {
        let body = '';
        req.on('data', (chunk) => body += chunk);
        req.on('end', () => {
          try {
            const data = JSON.parse(body);

            // Save credentials
            saveCredentials({
              idToken: data.idToken,
              refreshToken: data.refreshToken,
              uid: data.uid,
              email: data.email,
              displayName: data.displayName,
              expiresAt: Date.now() + 3600 * 1000, // 1 hour
            });

            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: true }));

            console.log(`\n${green('✔')} ${bold('Logged in as')} ${cyan(data.email)}`);
            if (data.displayName) console.log(`  ${dim(data.displayName)}`);
            console.log(`\n  Credentials saved to ${dim(CREDS_FILE)}`);
            console.log(`  You can now deploy without --key\n`);

            server.close();
            resolve();
          } catch (err) {
            res.writeHead(400);
            res.end('Invalid data');
          }
        });
        return;
      }

      res.writeHead(404);
      res.end('Not found');
    });

    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      const authUrl = `${AUTH_PAGE}?port=${port}`;

      console.log(`  Opening browser for Google Sign-In...`);
      console.log(`  ${dim(authUrl)}\n`);
      console.log(`  ${dim('Waiting for authentication...')}`);

      openBrowser(authUrl);

      // Timeout after 5 minutes
      setTimeout(() => {
        console.error(`\n${red('✘')} Login timed out. Please try again.\n`);
        server.close();
        process.exit(1);
      }, 300000);
    });

    server.on('error', (err) => {
      console.error(red(`Error starting local server: ${err.message}`));
      reject(err);
    });
  });
}

// ── Logout ──────────────────────────────────────────────────────────

function logout() {
  const creds = loadCredentials();
  clearCredentials();
  if (creds?.email) {
    console.log(`\n${green('✔')} Logged out ${dim(creds.email)}\n`);
  } else {
    console.log(`\n${dim('No active session.')}\n`);
  }
}

// ── Whoami ──────────────────────────────────────────────────────────

function whoami() {
  const creds = loadCredentials();
  if (creds?.email) {
    console.log(`\n${bold('Logged in as:')} ${cyan(creds.email)}`);
    if (creds.displayName) console.log(`  ${dim(creds.displayName)}`);
    console.log(`  ${dim(`UID: ${creds.uid}`)}\n`);
  } else {
    console.log(`\n${dim('Not logged in. Run:')} netlaunch login\n`);
  }
}

// ── Firebase Config ──────────────────────────────────────────────────

function loadLocalConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf-8'));
    }
  } catch { /* ignore */ }
  return null;
}

function saveLocalConfig(config) {
  fs.mkdirSync(CREDS_DIR, { recursive: true });
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2), { mode: 0o600 });
}

function clearLocalConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) fs.unlinkSync(CONFIG_FILE);
  } catch { /* ignore */ }
}

async function configSet(filePath, sync) {
  if (!filePath) {
    console.error(red('Error: Missing --file path to service account JSON.'));
    process.exit(1);
  }

  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) {
    console.error(red(`Error: File not found: ${resolved}`));
    process.exit(1);
  }

  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(resolved, 'utf-8'));
  } catch {
    console.error(red('Error: Invalid JSON file.'));
    process.exit(1);
  }

  if (parsed.type !== 'service_account') {
    console.error(red('Error: File must be a Firebase service account key (type: "service_account").'));
    process.exit(1);
  }

  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    console.error(red('Error: Missing required fields (project_id, client_email, private_key).'));
    process.exit(1);
  }

  // Save locally
  saveLocalConfig({
    projectId: parsed.project_id,
    clientEmail: parsed.client_email,
    privateKey: parsed.private_key,
  });

  console.log(`\n${green('✔')} ${bold('Config saved locally')}`);
  console.log(`  Project:  ${cyan(parsed.project_id)}`);
  console.log(`  Account:  ${dim(parsed.client_email)}`);
  console.log(`  Stored:   ${dim(CONFIG_FILE)}`);

  // Optionally sync to server
  if (sync) {
    const idToken = await getValidIdToken();
    if (!idToken) {
      console.error(yellow('\n  Could not sync: not logged in. Run: netlaunch login'));
      console.log(`  ${dim('Config saved locally only.')}\n`);
      return;
    }

    console.log(dim('\n  Syncing to server...'));
    try {
      const jsonStr = fs.readFileSync(resolved, 'utf-8');
      const result = await callFirebaseFunction('saveFirebaseConfigFunction', { serviceAccountJson: jsonStr }, idToken);
      console.log(`  ${green('✔')} Synced to server — usable from dashboard too.`);
    } catch (err) {
      console.error(red(`  Sync failed: ${err.message}`));
      console.log(`  ${dim('Config saved locally only.')}`);
    }
  } else {
    console.log(`\n  ${dim('Tip: add --sync to also save on the server for dashboard use.')}`);
  }

  console.log(`\n  All future deploys will target ${cyan(parsed.project_id)}.`);
  console.log(`  Use ${dim('--hosted')} flag to override.\n`);
}

function configShow() {
  const config = loadLocalConfig();
  if (config) {
    console.log(`\n${bold('Firebase Config (local)')}`);
    console.log(`  Project:  ${cyan(config.projectId)}`);
    console.log(`  Account:  ${dim(config.clientEmail)}`);
    console.log(`  File:     ${dim(CONFIG_FILE)}\n`);
    console.log(`  ${dim('Deploys go to your Firebase project.')}`);
  } else {
    console.log(`\n${dim('No local Firebase config set.')}`);
    console.log(`  ${dim('Deploys go to NetLaunch hosting.')}`);
    console.log(`  Run: ${bold('netlaunch config set -f ./service-account.json')}\n`);
  }
}

function configRemove() {
  const config = loadLocalConfig();
  clearLocalConfig();
  if (config) {
    console.log(`\n${green('✔')} Local config removed (was: ${config.projectId})`);
    console.log(`  ${dim('Deploys will use NetLaunch hosting.')}`);
    console.log(`  ${dim('Note: server config (if synced) must be removed from the dashboard.')}\n`);
  } else {
    console.log(`\n${dim('No local config to remove.')}\n`);
  }
}

// ── Multipart builder ────────────────────────────────────────────────

function buildMultipart(fields, filePath) {
  const boundary = '----NetLaunch' + Date.now().toString(36);
  const parts = [];

  for (const [name, value] of Object.entries(fields)) {
    parts.push(
      `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="${name}"\r\n\r\n` +
      `${value}\r\n`
    );
  }

  const fileData = fs.readFileSync(filePath);
  const fileName = path.basename(filePath);
  const fileHeader =
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="file"; filename="${fileName}"\r\n` +
    `Content-Type: application/zip\r\n\r\n`;
  const fileFooter = `\r\n--${boundary}--\r\n`;

  const headerBuf = Buffer.from(fileHeader, 'utf-8');
  const footerBuf = Buffer.from(fileFooter, 'utf-8');
  const fieldsBuf = Buffer.from(parts.join(''), 'utf-8');

  const body = Buffer.concat([fieldsBuf, headerBuf, fileData, footerBuf]);

  return { body, contentType: `multipart/form-data; boundary=${boundary}` };
}

// ── Deploy ───────────────────────────────────────────────────────────

async function deploy(apiKey, siteName, filePath, forceHosted) {
  if (!fs.existsSync(filePath)) {
    console.error(red(`Error: File not found: ${filePath}`));
    process.exit(1);
  }

  const stat = fs.statSync(filePath);
  const sizeMB = (stat.size / (1024 * 1024)).toFixed(2);

  // Check for local Firebase config (unless --hosted)
  const localConfig = loadLocalConfig();
  const selfHosted = localConfig && !forceHosted;

  console.log(`\n${bold('NetLaunch Deploy')}`);
  console.log(dim('─'.repeat(40)));
  console.log(`  Site:  ${cyan(siteName + '.web.app')}`);
  console.log(`  File:  ${path.basename(filePath)} ${dim(`(${sizeMB} MB)`)}`);
  if (selfHosted) {
    console.log(`  Mode:  ${cyan('Self-Hosted')} ${dim(`(${localConfig.projectId})`)}`);
  }
  console.log(dim('─'.repeat(40)));
  console.log(`\nUploading and deploying...`);

  const { body, contentType } = buildMultipart(
    { apiKey, siteName },
    filePath,
  );

  const url = new URL(DEPLOY_URL);

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: url.hostname,
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': contentType,
          'Content-Length': body.length,
        },
        timeout: 600000,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            if (res.statusCode >= 200 && res.statusCode < 300 && json.success) {
              console.log(`\n${green('✔')} ${bold('Deployed successfully!')}`);
              console.log(`\n  ${bold('URL:')}  ${cyan(json.url)}`);
              console.log(`  ${bold('ID:')}   ${dim(json.deploymentId)}\n`);
              resolve(json);
            } else {
              console.error(`\n${red('✘')} ${bold('Deployment failed')}`);
              console.error(`  ${json.error || `HTTP ${res.statusCode}`}\n`);
              process.exit(1);
            }
          } catch {
            console.error(`\n${red('✘')} Unexpected response: ${data}\n`);
            process.exit(1);
          }
        });
      },
    );

    req.on('error', (err) => {
      console.error(`\n${red('✘')} Network error: ${err.message}\n`);
      process.exit(1);
    });

    req.on('timeout', () => {
      req.destroy();
      console.error(`\n${red('✘')} Request timed out\n`);
      process.exit(1);
    });

    req.write(body);
    req.end();
  });
}

// ── Main ─────────────────────────────────────────────────────────────

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (opts.help && !opts.command) {
    printUsage();
    process.exit(0);
  }

  if (!opts.command) {
    printUsage();
    process.exit(1);
  }

  // ── Login / Logout / Whoami / Config
  if (opts.command === 'login') return login();
  if (opts.command === 'logout') return logout();
  if (opts.command === 'whoami') return whoami();
  if (opts.command === 'config') {
    if (opts.configSub === 'set') return configSet(opts.file, opts.sync);
    if (opts.configSub === 'show') return configShow();
    if (opts.configSub === 'remove') return configRemove();
    console.log(`Usage: netlaunch config <set|show|remove>`);
    process.exit(1);
  }

  // ── Deploy
  if (opts.command === 'deploy') {
    let apiKey = opts.key || process.env.NETLAUNCH_KEY;

    // If no explicit key, try to auto-generate one from stored credentials
    if (!apiKey) {
      const idToken = await getValidIdToken();
      if (idToken) {
        console.log(dim('  Generating API key from your login session...'));
        try {
          const result = await callFirebaseFunction('generateApiKeyFunctionCallable', {}, idToken);
          apiKey = result.apiKey;
          console.log(`  ${green('✔')} API key generated\n`);
        } catch (err) {
          console.error(red(`  Failed to generate API key: ${err.message}`));
          console.error(dim('  Try: netlaunch login  or  --key <api-key>\n'));
          process.exit(1);
        }
      } else {
        console.error(red('Error: No API key. Use --key, set NETLAUNCH_KEY, or run: netlaunch login'));
        process.exit(1);
      }
    }

    const siteName = opts.site;
    const filePath = opts.file;

    if (!siteName) {
      console.error(red('Error: Missing --site name.'));
      process.exit(1);
    }
    if (!filePath) {
      console.error(red('Error: Missing --file path.'));
      process.exit(1);
    }

    const resolvedPath = path.resolve(filePath);
    await deploy(apiKey, siteName, resolvedPath, opts.hosted);
  }
}

main();
