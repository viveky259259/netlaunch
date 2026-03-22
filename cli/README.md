# NetLaunch CLI

Deploy static sites in seconds. Zero config, instant URLs.

```bash
npx netlaunch deploy -s my-app -f ./dist.zip
# → https://my-app.web.app
```

## Install

```bash
npm install -g netlaunch
```

Or use directly with `npx`:

```bash
npx netlaunch deploy -s my-app -f ./dist.zip
```

## Quick Start

### 1. Login with Google

```bash
netlaunch login
```

Opens your browser for Google Sign-In. Credentials are stored locally at `~/.netlaunch/credentials.json`.

### 2. Deploy

```bash
netlaunch deploy --site my-app --file ./dist.zip
```

That's it. Your site is live at `https://my-app.web.app`.

## Commands

| Command | Description |
|---------|-------------|
| `netlaunch login` | Sign in with Google (opens browser) |
| `netlaunch logout` | Remove stored credentials |
| `netlaunch whoami` | Show current logged-in user |
| `netlaunch deploy` | Deploy a ZIP archive |

## Deploy Options

| Flag | Short | Description |
|------|-------|-------------|
| `--site` | `-s` | Site name / subdomain (3-30 chars, lowercase) |
| `--file` | `-f` | Path to ZIP archive |
| `--key` | `-k` | API key — optional if logged in |

## Examples

```bash
# Login first (one-time)
netlaunch login

# Deploy a site
netlaunch deploy -s portfolio -f ./build.zip

# Deploy with explicit API key (no login needed)
netlaunch deploy -k fk_abc123 -s my-app -f ./dist.zip

# Use environment variable for CI/CD
export NETLAUNCH_KEY=fk_your_key
netlaunch deploy -s my-app -f ./dist.zip
```

## How It Works

1. Your ZIP file is uploaded to the NetLaunch cloud
2. Files are extracted and validated (must contain `index.html`)
3. Site is deployed to Firebase Hosting with its own subdomain
4. Live URL is returned: `https://<site-name>.web.app`

## CI/CD

Set `NETLAUNCH_KEY` environment variable in your CI pipeline:

```yaml
# GitHub Actions
- name: Deploy
  env:
    NETLAUNCH_KEY: ${{ secrets.NETLAUNCH_KEY }}
  run: npx netlaunch deploy -s my-app -f ./dist.zip
```

## Requirements

- Node.js >= 18
- A ZIP file with `index.html` at root (or in a subdirectory)

## License

MIT
