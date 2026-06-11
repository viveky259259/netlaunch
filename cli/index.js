#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');
const { exec } = require('child_process');

const DEPLOY_URL = 'https://us-central1-FIREBASE_PROJECT_ID_PLACEHOLDER.cloudfunctions.net/cliDeploy';
const AUTH_PAGE = 'https://FIREBASE_PROJECT_ID_PLACEHOLDER.web.app/cli-auth.html';
const FIREBASE_API_KEY = 'FIREBASE_API_KEY_PLACEHOLDER';
const CREDS_DIR = path.join(require('os').homedir(), '.netlaunch');
const CREDS_FILE = path.join(CREDS_DIR, 'credentials.json');
const CONFIG_FILE = path.join(CREDS_DIR, 'firebase-config.json');
// Global key cache, keyed by projectId — a convenience, never the source of truth.
const KEY_CACHE_DIR = path.join(CREDS_DIR, 'projects');
// Project-local config lives in ./.netlaunch/ (per-folder).
//   config.json          → committed binding (project/site/alias) — no secrets
//   service-account.json → gitignored key
const LOCAL_DIR = path.join(process.cwd(), '.netlaunch');
const LOCAL_SA_FILE = path.join(LOCAL_DIR, 'service-account.json');
const LOCAL_CONFIG_FILE = path.join(LOCAL_DIR, 'config.json');
const CONFIG_VERSION = 1;
const SECRET_FIELDS = ['type', 'private_key', 'private_key_id', 'client_email', 'client_id', 'auth_uri', 'token_uri'];

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
  link <project>     Bind this repo to a Firebase project (writes .netlaunch/config.json)
  config use         Pick a project, mint its key (.netlaunch/) AND write config.json
  config set         Set Firebase config for self-hosted deploys (global)
  config show        Show resolved binding, key source & deploy mode (doctor)
  config remove      Remove this repo's .netlaunch/ binding & key

${bold('DEPLOY OPTIONS')}
  --key,  -k     API key (fk_...) — optional if logged in
  --site, -s     Site name / subdomain — optional if config.json sets it
  --file, -f     Path to ZIP archive
  --target, -t   Target name from a multi-env config.json
  --yes,  -y     Skip the production confirmation prompt (required in CI for prod)
  --hosted       Force deploy to NetLaunch (ignore saved config)

${bold('LINK / CONFIG OPTIONS')}
  --file, -f     Path to service account JSON (config use / set)
  --site, -s     Hosting site id for the binding (link)
  --alias        Friendly label shown in the deploy banner (link)
  --target, -t   Write the binding under a named target (link, multi-env)
  --prod         Mark the binding production (red banner + confirm)
  --sync         Also save config to server (use from dashboard)

${bold('EXAMPLES')}
  netlaunch login
  netlaunch link acme-prod --site acme-www --prod
  netlaunch config use
  netlaunch deploy -f ./dist.zip                 ${dim('# project/site from config.json')}
  netlaunch deploy -t prod -y -f ./dist.zip      ${dim('# CI, multi-env')}
  netlaunch deploy -s my-app -f ./dist.zip --hosted
  netlaunch config show

${bold('ENVIRONMENT')}
  NETLAUNCH_KEY                 API key (alternative to --key flag)
  NETLAUNCH_SA_JSON             Service account JSON (raw) for self-hosted CI deploys
  GOOGLE_APPLICATION_CREDENTIALS  Path to a service account JSON (CI fallback)
`);
}

function parseArgs(args) {
  const opts = {};
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--key' || arg === '-k') opts.key = args[++i];
    else if (arg === '--site' || arg === '-s') opts.site = args[++i];
    else if (arg === '--file' || arg === '-f') opts.file = args[++i];
    else if (arg === '--target' || arg === '-t') opts.target = args[++i];
    else if (arg === '--alias') opts.alias = args[++i];
    else if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg === '--sync') opts.sync = true;
    else if (arg === '--hosted') opts.hosted = true;
    else if (arg === '--prod' || arg === '--production') opts.production = true;
    else if (arg === '--yes' || arg === '-y') opts.yes = true;
    else if (arg === 'config') {
      opts.command = 'config';
      // Next arg is the subcommand
      if (i + 1 < args.length && ['set', 'use', 'show', 'remove'].includes(args[i + 1])) {
        opts.configSub = args[++i];
      }
    }
    else if (['deploy', 'login', 'logout', 'whoami', 'link'].includes(arg)) opts.command = arg;
    // First bare (non-flag) token after `link` is the project id.
    else if (opts.command === 'link' && !opts.project && !arg.startsWith('-')) opts.project = arg;
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
      hostname: 'us-central1-FIREBASE_PROJECT_ID_PLACEHOLDER.cloudfunctions.net',
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
      // Chrome Private Network Access: a public HTTPS origin (the auth page)
      // posting to localhost requires this on the preflight, or it's blocked.
      res.setHeader('Access-Control-Allow-Private-Network', 'true');

      if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
      }

      // Safari blocks an HTTPS page from fetch()-ing http://localhost as mixed
      // content. So the auth page navigates here as a top-level GET with the
      // token in the query string, which every browser allows. The CLI renders
      // the success page.
      if (req.method === 'GET' && req.url.startsWith('/callback')) {
        const q = new URL(req.url, 'http://127.0.0.1').searchParams;
        const idToken = q.get('idToken');
        if (!idToken) {
          res.writeHead(400, { 'Content-Type': 'text/html' });
          res.end('<h2>Missing token. Run <code>netlaunch login</code> again.</h2>');
          return;
        }
        saveCredentials({
          idToken,
          refreshToken: q.get('refreshToken'),
          uid: q.get('uid'),
          email: q.get('email'),
          displayName: q.get('displayName'),
          expiresAt: Date.now() + 3600 * 1000, // 1 hour
        });
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end('<!doctype html><meta charset="utf-8"><title>NetLaunch</title>'
          + '<div style="font-family:-apple-system,sans-serif;text-align:center;margin-top:80px">'
          + '<h1>✅ Login successful</h1>'
          + '<p>You can close this tab and return to the terminal.</p></div>');
        console.log(`\n${green('✔')} ${bold('Logged in as')} ${cyan(q.get('email'))}`);
        if (q.get('displayName')) console.log(`  ${dim(q.get('displayName'))}`);
        console.log(`\n  Credentials saved to ${dim(CREDS_FILE)}`);
        console.log(`  You can now deploy without --key\n`);
        server.close();
        resolve();
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

      res.writeHead(404, { 'Content-Type': 'text/html' });
      res.end('<!doctype html><meta charset="utf-8"><title>NetLaunch</title>'
        + '<div style="font-family:-apple-system,sans-serif;text-align:center;margin-top:80px">'
        + '<h2>NetLaunch</h2><p>Return to your terminal — the CLI may have already captured your '
        + 'login, or it timed out. If needed, re-run <code>netlaunch login</code>.</p></div>');
    });

    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      const authUrl = `${AUTH_PAGE}?port=${port}`;

      console.log(`  Opening browser for Google Sign-In...`);
      console.log(`  ${dim(authUrl)}\n`);
      console.log(`  ${dim('Waiting for authentication...')}`);

      openBrowser(authUrl);

      // Timeout after 10 minutes (Google sign-in + MFA can take a while)
      setTimeout(() => {
        console.error(`\n${red('✘')} Login timed out after 10 minutes. Please run: netlaunch login\n`);
        server.close();
        process.exit(1);
      }, 600000);
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

// `config show` doubles as a doctor: it prints exactly how a deploy here resolves.
function configShow() {
  const dir = process.cwd();
  const disc = discoverRepoConfig(dir);
  console.log(`\n${bold('NetLaunch — resolved config')}`);
  console.log(dim('─'.repeat(40)));
  if (disc) {
    const t = resolveTarget(disc.config, undefined);
    console.log(`  Binding:  ${dim(path.relative(dir, disc.configPath))}`);
    console.log(`  Project:  ${cyan(t.project)}${t.production ? red(' (production)') : (t.alias ? dim(` (${t.alias})`) : '')}`);
    console.log(`  Site:     ${cyan(t.site)}`);
    let keySrc;
    if (process.env.NETLAUNCH_SA_JSON || process.env.GOOGLE_APPLICATION_CREDENTIALS) keySrc = 'env (CI)';
    else if (fs.existsSync(path.join(disc.dir, '.netlaunch', 'service-account.json'))) keySrc = 'repo-local';
    else if (readKeyCache(t.project)) keySrc = 'global cache';
    else keySrc = 'missing';
    console.log(`  Key:      ${keySrc === 'missing' ? yellow(keySrc) : green(keySrc)}`);
    if (keySrc === 'missing') console.log(`            ${dim('run: netlaunch config use')}`);
    console.log(`  Mode:     ${cyan('Self-Hosted')}\n`);
    return;
  }
  const globalCfg = loadLocalConfig();
  if (globalCfg) {
    console.log(`  Binding:  ${dim('global ~/.netlaunch/firebase-config.json')}`);
    console.log(`  Project:  ${cyan(globalCfg.projectId)}`);
    console.log(`  Mode:     ${cyan('Self-Hosted (global)')}\n`);
    return;
  }
  console.log(`  ${dim('No binding found. Deploys go to NetLaunch hosting.')}`);
  console.log(`  Run: ${bold('netlaunch link <project>')} ${dim('or')} ${bold('netlaunch config use')}\n`);
}

function configRemove() {
  const hadRepo = fs.existsSync(LOCAL_SA_FILE) || fs.existsSync(LOCAL_CONFIG_FILE);
  if (hadRepo) {
    try { if (fs.existsSync(LOCAL_SA_FILE)) fs.unlinkSync(LOCAL_SA_FILE); } catch { /* ignore */ }
    try { if (fs.existsSync(LOCAL_CONFIG_FILE)) fs.unlinkSync(LOCAL_CONFIG_FILE); } catch { /* ignore */ }
    try { fs.rmdirSync(LOCAL_DIR); } catch { /* not empty — leave it */ }
    console.log(`\n${green('✔')} Removed this repo's ${dim('.netlaunch/')} binding & key.`);
    console.log(`  ${dim('Global key cache (~/.netlaunch/projects/) left intact.')}`);
    console.log(`  ${dim('Deploys here now use NetLaunch hosting.')}\n`);
    return;
  }
  const globalCfg = loadLocalConfig();
  if (globalCfg) {
    clearLocalConfig();
    console.log(`\n${green('✔')} Global config removed (was: ${globalCfg.projectId})`);
    console.log(`  ${dim('Deploys will use NetLaunch hosting.')}`);
    console.log(`  ${dim('Note: server config (if synced) must be removed from the dashboard.')}\n`);
    return;
  }
  console.log(`\n${dim('No config to remove.')}\n`);
}

// ── Repo binding: discovery, schema, key cache (.netlaunch/) ─────────

const isTTY = () => Boolean(process.stdin.isTTY && process.stdout.isTTY);

// Nearest ancestor containing .git (inclusive). null before crossing $HOME / root.
function findGitRoot(startDir) {
  const home = require('os').homedir();
  let dir = startDir;
  for (;;) {
    if (fs.existsSync(path.join(dir, '.git'))) return dir;
    if (dir === home) return null;          // never cross $HOME
    const parent = path.dirname(dir);
    if (parent === dir) return null;        // filesystem root
    dir = parent;
  }
}

// Find .netlaunch/config.json, bounded to the git repo root (§3.1).
// Returns { dir, configPath, config } or null.
function discoverRepoConfig(cwd = process.cwd()) {
  const at = (dir) => {
    const p = path.join(dir, '.netlaunch', 'config.json');
    return fs.existsSync(p) ? { dir, configPath: p } : null;
  };
  const gitRoot = findGitRoot(cwd);
  if (!gitRoot) {
    const hit = at(cwd);                    // outside a repo: cwd only, no walk-up
    return hit ? { ...hit, config: readRepoConfig(hit.configPath) } : null;
  }
  let dir = cwd;
  for (;;) {
    const hit = at(dir);
    if (hit) return { ...hit, config: readRepoConfig(hit.configPath) };
    if (dir === gitRoot) break;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function readRepoConfig(configPath) {
  let raw;
  try { raw = JSON.parse(fs.readFileSync(configPath, 'utf-8')); }
  catch { console.error(red(`Error: invalid .netlaunch/config.json (${configPath})`)); process.exit(1); }
  const v = raw.version || 1;
  if (v > CONFIG_VERSION) {
    console.error(red(`Error: config.json version ${v} not supported; upgrade netlaunch.`));
    process.exit(1);
  }
  return raw;
}

// Resolve a target → {project, site, alias, production} (§2.1).
// `targets` (if present) wins over top-level fields.
function resolveTarget(config, targetFlag) {
  if (config.targets && typeof config.targets === 'object') {
    const name = targetFlag || config.defaultTarget;
    const avail = Object.keys(config.targets).join(', ');
    if (!name) {
      console.error(red('Error: config.json has multiple targets — pass --target <name>.'));
      console.error(dim(`  Available: ${avail}`)); process.exit(1);
    }
    const t = config.targets[name];
    if (!t) {
      console.error(red(`Error: target "${name}" not found in config.json.`));
      console.error(dim(`  Available: ${avail}`)); process.exit(1);
    }
    return { name, project: t.project, site: t.site || t.project, alias: t.alias || name, production: !!t.production };
  }
  if (!config.project) { console.error(red('Error: config.json has no "project".')); process.exit(1); }
  return { name: null, project: config.project, site: config.site || config.project, alias: config.alias, production: !!config.production };
}

function stripSecretFields(obj) {
  const clean = { ...obj };
  for (const f of SECRET_FIELDS) delete clean[f];
  return clean;
}

// Write/merge .netlaunch/config.json (committed binding). Never writes secrets.
function writeRepoConfig(dir, { project, site, alias, production, target }) {
  const ndir = path.join(dir, '.netlaunch');
  const cpath = path.join(ndir, 'config.json');
  fs.mkdirSync(ndir, { recursive: true });
  let existing = {};
  if (fs.existsSync(cpath)) { try { existing = JSON.parse(fs.readFileSync(cpath, 'utf-8')); } catch { /* ignore */ } }
  const entry = stripSecretFields({ project, ...(site ? { site } : {}), ...(alias ? { alias } : {}), ...(production ? { production: true } : {}) });
  let out;
  if (target) {
    out = { version: CONFIG_VERSION, ...existing };
    out.targets = { ...(existing.targets || {}), [target]: entry };
    if (!out.defaultTarget) out.defaultTarget = target;
    delete out.project; delete out.site; delete out.alias; delete out.production;
  } else {
    out = { version: CONFIG_VERSION, ...entry };
  }
  fs.writeFileSync(cpath, JSON.stringify(out, null, 2) + '\n');
  return cpath;
}

// Global key cache (~/.netlaunch/projects/<projectId>.json) — convenience only.
function keyCachePath(projectId) { return path.join(KEY_CACHE_DIR, `${projectId}.json`); }
function readKeyCache(projectId) {
  try { const p = keyCachePath(projectId); if (fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, 'utf-8')); }
  catch { /* ignore */ }
  return null;
}
function writeKeyCache(parsed) {
  try {
    fs.mkdirSync(KEY_CACHE_DIR, { recursive: true });
    fs.writeFileSync(keyCachePath(parsed.project_id), JSON.stringify(parsed, null, 2), { mode: 0o600 });
  } catch { /* ignore */ }
}

// Find a service-account key for projectId (§3.2). Returns { parsed, source } or null.
async function findKeyForProject(projectId, repoDir) {
  if (process.env.NETLAUNCH_SA_JSON) {
    try { return { parsed: JSON.parse(process.env.NETLAUNCH_SA_JSON), source: 'env' }; } catch { /* ignore */ }
  }
  const gac = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (gac && fs.existsSync(gac)) {
    try { return { parsed: JSON.parse(fs.readFileSync(gac, 'utf-8')), source: 'env' }; } catch { /* ignore */ }
  }
  const localPath = path.join(repoDir, '.netlaunch', 'service-account.json');
  if (fs.existsSync(localPath)) {
    try { return { parsed: JSON.parse(fs.readFileSync(localPath, 'utf-8')), source: 'repo-local' }; } catch { /* ignore */ }
  }
  const cached = readKeyCache(projectId);
  if (cached) {
    if (isTTY()) {
      const ans = (await promptLine(`  Reuse saved credentials for ${cyan(projectId)}? [Y/n] `)).toLowerCase();
      if (ans === '' || ans === 'y' || ans === 'yes') {
        writeProjectServiceAccount(cached, repoDir);
        return { parsed: cached, source: 'cache' };
      }
    } else {
      return { parsed: cached, source: 'cache' };   // non-interactive: reuse silently
    }
  }
  return null;
}

// Ensure the secret key is gitignored and config.json stays committable (§7).
// NEGATION only — never removes a user's existing ignore pattern.
function ensureNetlaunchGitignore(dir) {
  const gi = path.join(dir, '.gitignore');
  let content = '';
  try { content = fs.existsSync(gi) ? fs.readFileSync(gi, 'utf-8') : ''; } catch { /* ignore */ }
  const lines = content.split(/\r?\n/).map((l) => l.trim());
  const has = (s) => lines.includes(s);
  const blanket = has('.netlaunch') || has('.netlaunch/');
  const additions = [];
  if (blanket) {
    // git can't re-include a file whose parent dir is excluded by a blanket.
    // So: re-include the dir, ignore its contents, then re-include only
    // config.json. Any OTHER files in .netlaunch/ stay ignored via `.netlaunch/*`.
    let pushedComment = false;
    for (const line of ['!.netlaunch/', '.netlaunch/*', '!.netlaunch/config.json']) {
      if (!has(line)) {
        if (!pushedComment) { additions.push('# NetLaunch: keep config.json committable, key ignored'); pushedComment = true; }
        additions.push(line);
      }
    }
  } else if (!has('.netlaunch/service-account.json')) {
    additions.push('# NetLaunch service account — secret, do not commit');
    additions.push('.netlaunch/service-account.json');
  }
  if (additions.length) {
    const prefix = content && !content.endsWith('\n') ? '\n' : '';
    try { fs.appendFileSync(gi, `${prefix}\n${additions.join('\n')}\n`); } catch { /* ignore */ }
  }
  warnIfConfigIgnored(dir);
}

// Post-check: warn (don't auto-fix) if config.json would still be git-ignored.
function warnIfConfigIgnored(dir) {
  try {
    const { execSync } = require('child_process');
    const out = execSync('git check-ignore -v .netlaunch/config.json',
      { cwd: dir, encoding: 'utf-8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    if (out) {
      console.log(`  ${yellow('!')} .netlaunch/config.json is still gitignored by: ${dim(out)}`);
      console.log(`    ${dim('Add  !.netlaunch/config.json  so teammates/CI see the target.')}`);
    }
  } catch { /* not ignored, or not a git repo — fine */ }
}

// Banner + confirmation matrix (§4). Aborts on a failed/forbidden prod confirm.
async function confirmDeploy(target, opts) {
  console.log(`\n${bold('Deploying to Firebase')}`);
  const tag = target.production ? red(' (production)') : (target.alias ? dim(` (${target.alias})`) : '');
  console.log(`  Project:  ${target.production ? red(target.project) : cyan(target.project)}${tag}`);
  console.log(`  Site:     ${cyan(target.site)}`);
  if (!target.production || opts.yes) return;
  if (!isTTY()) {
    console.error(`\n${red('✘')} Refusing to deploy to production ${bold(target.project)} without confirmation.`);
    console.error(dim('  Pass --yes in non-interactive environments.\n'));
    process.exit(1);
  }
  const ans = await promptLine(`  ${yellow('Production deploy.')} Type the project id (${cyan(target.project)}) to continue: `);
  if (ans !== target.project) { console.error(`\n${red('✘')} Confirmation did not match. Aborted.\n`); process.exit(1); }
}

// Legacy migration (§7): back-fill config.json from an existing service-account.json.
function migrateLegacyRepo(dir) {
  const sa = path.join(dir, '.netlaunch', 'service-account.json');
  const cfg = path.join(dir, '.netlaunch', 'config.json');
  if (!fs.existsSync(sa) || fs.existsSync(cfg)) return false;
  try {
    const parsed = JSON.parse(fs.readFileSync(sa, 'utf-8'));
    if (!parsed.project_id) return false;
    writeRepoConfig(dir, { project: parsed.project_id });
    ensureNetlaunchGitignore(dir);
    console.log(`  ${green('✔')} Created ${dim('.netlaunch/config.json')} → ${cyan(parsed.project_id)} ${dim('(commit it)')}`);
    return true;
  } catch { return false; }
}

function readServiceAccount(filePath) {
  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) {
    console.error(red(`Error: File not found: ${resolved}`)); process.exit(1);
  }
  let parsed;
  try { parsed = JSON.parse(fs.readFileSync(resolved, 'utf-8')); }
  catch { console.error(red('Error: Invalid JSON file.')); process.exit(1); }
  if (parsed.type !== 'service_account') {
    console.error(red('Error: Not a service account key (type must be "service_account").')); process.exit(1);
  }
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    console.error(red('Error: Missing required fields (project_id, client_email, private_key).')); process.exit(1);
  }
  return parsed;
}

function writeProjectServiceAccount(parsed, dir = process.cwd()) {
  const ndir = path.join(dir, '.netlaunch');
  fs.mkdirSync(ndir, { recursive: true });
  fs.writeFileSync(path.join(ndir, 'service-account.json'), JSON.stringify(parsed, null, 2), { mode: 0o600 });
}

function promptLine(question) {
  return new Promise((resolve) => {
    const rl = require('readline').createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (a) => { rl.close(); resolve(a.trim()); });
  });
}

function hasGcloud() {
  try { require('child_process').execSync('gcloud --version', { stdio: 'ignore' }); return true; }
  catch { return false; }
}

// Interactive: pick a project and mint a key via the gcloud SDK.
async function obtainViaGcloud() {
  const { execSync } = require('child_process');
  let projects;
  try {
    projects = JSON.parse(execSync('gcloud projects list --format=json', { encoding: 'utf-8' }));
  } catch {
    console.error(red('  gcloud failed. Run: gcloud auth login')); return null;
  }
  if (!projects.length) { console.error(red('  No Google Cloud projects found.')); return null; }
  console.log('\n  Select a project:');
  projects.forEach((p, i) => console.log(`   ${bold(String(i + 1))}. ${cyan(p.projectId)} ${dim(p.name || '')}`));
  const idx = parseInt(await promptLine('\n  Number: '), 10) - 1;
  if (isNaN(idx) || idx < 0 || idx >= projects.length) {
    console.error(red('  Invalid selection.')); return null;
  }
  const projectId = projects[idx].projectId;

  let saEmail;
  try {
    const sas = JSON.parse(execSync(
      `gcloud iam service-accounts list --project ${projectId} --format=json`, { encoding: 'utf-8' }));
    const admin = sas.find((s) => s.email.includes('firebase-adminsdk')) || sas[0];
    if (!admin) throw new Error('none');
    saEmail = admin.email;
  } catch {
    console.error(red('  No service account found for that project.')); return null;
  }

  const tmp = path.join(require('os').tmpdir(), `nl-sa-${process.pid}.json`);
  try {
    execSync(`gcloud iam service-accounts keys create "${tmp}" --iam-account="${saEmail}" --project ${projectId}`,
      { stdio: 'ignore' });
  } catch {
    console.error(red('  Key creation failed (need roles/iam.serviceAccountKeyAdmin).')); return null;
  }
  const parsed = JSON.parse(fs.readFileSync(tmp, 'utf-8'));
  try { fs.unlinkSync(tmp); } catch { /* ignore */ }
  return parsed;
}

// netlaunch config use — select a Firebase project, obtain its service-account
// key, store it in ./.netlaunch/, gitignore it, and sync so deploys target it.
async function configUse(opts) {
  console.log(`\n${bold('NetLaunch — connect a Firebase project')}`);
  console.log(dim('─'.repeat(44)));

  let parsed;
  if (opts.file) {
    parsed = readServiceAccount(opts.file);            // bring-your-own
  } else if (hasGcloud()) {
    parsed = await obtainViaGcloud();                  // auto via gcloud
    if (!parsed) process.exit(1);
  } else {
    console.log(`\n  No ${bold('gcloud')} SDK and no ${dim('--file')} given.`);
    console.log(`  Opening the Firebase service-accounts console...`);
    console.log(`\n  ${bold('1.')} Select your project`);
    console.log(`  ${bold('2.')} Click ${cyan('Generate new private key')} → download`);
    console.log(`  ${bold('3.')} Re-run: ${bold('netlaunch config use --file <downloaded>.json')}\n`);
    openBrowser('https://console.firebase.google.com/project/_/settings/serviceaccounts/adminsdk');
    return;
  }

  const dir = process.cwd();
  writeProjectServiceAccount(parsed, dir);          // gitignored secret
  writeKeyCache(parsed);                            // global cache for reuse across repos
  const cpath = writeRepoConfig(dir, {              // committed binding
    project: parsed.project_id, site: opts.site, alias: opts.alias,
    production: opts.production, target: opts.target,
  });
  ensureNetlaunchGitignore(dir);

  console.log(`\n${green('✔')} ${bold('Connected')} ${cyan(parsed.project_id)}`);
  console.log(`  Key:      ${dim(path.relative(dir, LOCAL_SA_FILE))} ${dim('(gitignored)')}`);
  console.log(`  Binding:  ${dim(path.relative(dir, cpath))} ${green('(commit this)')}`);
  console.log(`  Account:  ${dim(parsed.client_email)}`);

  const idToken = await getValidIdToken();
  if (idToken) {
    try {
      await callFirebaseFunction('saveFirebaseConfigFunction',
        { serviceAccountJson: JSON.stringify(parsed) }, idToken);
      console.log(`  ${green('✔')} Synced — deploys from this repo go to ${cyan(parsed.project_id)}.`);
    } catch (err) {
      console.log(`  ${yellow('!')} Saved locally; server sync failed: ${err.message}`);
    }
  } else {
    console.log(`  ${yellow('!')} Not logged in — run ${bold('netlaunch login')}, then re-run to sync.`);
  }
  console.log(`\n  ${dim('Commit .netlaunch/config.json so teammates & CI know the target.')}\n`);
}

// netlaunch link <project> — declare the repo→project binding WITHOUT minting a key.
// For repo authors and teammates; `config use` = link + mint.
function linkCommand(opts) {
  const project = opts.project;
  if (!project) {
    console.error(red('Usage: netlaunch link <projectId> [--site s] [--alias a] [--prod] [--target name]'));
    process.exit(1);
  }
  const dir = process.cwd();
  const cpath = writeRepoConfig(dir, {
    project, site: opts.site, alias: opts.alias, production: opts.production, target: opts.target,
  });
  ensureNetlaunchGitignore(dir);
  console.log(`\n${green('✔')} ${bold('Linked')} this repo to ${cyan(project)}${opts.production ? red(' (production)') : ''}`);
  console.log(`  Binding:  ${dim(path.relative(dir, cpath))} ${green('(commit this)')}`);
  console.log(`  ${dim('No key written. Run `netlaunch config use` (or set NETLAUNCH_SA_JSON in CI) to deploy.')}\n`);
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

async function deploy(apiKey, siteName, filePath, info = {}) {
  if (!fs.existsSync(filePath)) {
    console.error(red(`Error: File not found: ${filePath}`));
    process.exit(1);
  }

  const stat = fs.statSync(filePath);
  const sizeMB = (stat.size / (1024 * 1024)).toFixed(2);

  console.log(`\n${bold('NetLaunch Deploy')}`);
  console.log(dim('─'.repeat(40)));
  console.log(`  Site:  ${cyan(siteName + '.web.app')}`);
  console.log(`  File:  ${path.basename(filePath)} ${dim(`(${sizeMB} MB)`)}`);
  if (info.selfHosted) {
    console.log(`  Mode:  ${cyan('Self-Hosted')} ${dim(`(${info.projectId})`)}`);
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
  if (opts.command === 'link') return linkCommand(opts);
  if (opts.command === 'config') {
    if (opts.configSub === 'use') return configUse(opts);
    if (opts.configSub === 'set') return configSet(opts.file, opts.sync);
    if (opts.configSub === 'show') return configShow();
    if (opts.configSub === 'remove') return configRemove();
    console.log(`Usage: netlaunch config <use|set|show|remove>`);
    process.exit(1);
  }

  // ── Deploy
  if (opts.command === 'deploy') {
    const filePath = opts.file;
    if (!filePath) { console.error(red('Error: Missing --file path.')); process.exit(1); }
    const resolvedPath = path.resolve(filePath);
    if (!fs.existsSync(resolvedPath)) { console.error(red(`Error: File not found: ${resolvedPath}`)); process.exit(1); }

    // Resolve the repo→project binding (unless --hosted forces NetLaunch hosting).
    const dir = process.cwd();
    migrateLegacyRepo(dir);
    const disc = opts.hosted ? null : discoverRepoConfig(dir);

    let selfHosted = null;   // { target, parsed }
    if (disc) {
      const target = resolveTarget(disc.config, opts.target);
      let keyRes = await findKeyForProject(target.project, disc.dir);

      if (!keyRes) {
        // Clone-and-go: binding is known, credentials are not — acquire them now.
        console.log(`\n  This repo is bound to ${cyan(target.project)} ${dim('(.netlaunch/config.json)')}`);
        console.log(`  No local credentials for ${cyan(target.project)}.`);
        let parsed = hasGcloud() ? await obtainViaGcloud() : null;
        if (!parsed) {
          if (!isTTY()) { console.error(red('  No credentials and non-interactive. Set NETLAUNCH_SA_JSON.')); process.exit(1); }
          const p = await promptLine('  Path to service-account JSON (blank to abort): ');
          if (!p) { console.error(red('  Aborted — no credentials.')); process.exit(1); }
          parsed = readServiceAccount(p);
        }
        if (parsed.project_id !== target.project) {
          console.error(red(`\n${red('✘')} Key project (${parsed.project_id}) ≠ config project (${target.project}). Aborted.`));
          process.exit(1);
        }
        writeProjectServiceAccount(parsed, disc.dir);
        writeKeyCache(parsed);
        keyRes = { parsed, source: 'acquired' };
      }

      // Mismatch guard for any non-env credential (§4).
      if (keyRes.source !== 'env' && keyRes.parsed.project_id !== target.project) {
        console.error(`\n${red('✘')} Credential project (${keyRes.parsed.project_id}) ≠ config project (${target.project}). Aborted.\n`);
        process.exit(1);
      }
      selfHosted = { target, parsed: keyRes.parsed };
    }

    // API key for the cliDeploy function (needed in all modes).
    let apiKey = opts.key || process.env.NETLAUNCH_KEY;
    let idToken = null;
    if (!apiKey) {
      idToken = await getValidIdToken();
      if (idToken) {
        console.log(dim('  Generating API key from your login session...'));
        try {
          const result = await callFirebaseFunction('generateApiKeyFunctionCallable', {}, idToken);
          apiKey = result.apiKey;
          console.log(`  ${green('✔')} API key generated`);
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

    // Site: from --site, else the binding's site.
    const siteName = opts.site || (selfHosted ? selfHosted.target.site : null);
    if (!siteName) { console.error(red('Error: Missing --site name (no config.json to infer it).')); process.exit(1); }

    // Self-hosted: sync the key to the server so cliDeploy targets it, then banner + confirm.
    if (selfHosted) {
      await confirmDeploy(selfHosted.target, opts);   // confirm BEFORE any server mutation
      if (!idToken) idToken = await getValidIdToken();
      if (idToken) {
        try {
          await callFirebaseFunction('saveFirebaseConfigFunction',
            { serviceAccountJson: JSON.stringify(selfHosted.parsed) }, idToken);
        } catch { /* best effort — server may already have it */ }
      }
    }

    await deploy(apiKey, siteName, resolvedPath, {
      selfHosted: !!selfHosted,
      projectId: selfHosted ? selfHosted.target.project : null,
    });
  }
}

main();
