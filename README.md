# Render Menu

macOS menu bar app that shows PR preview environments from [Render.com](https://render.com). Click the icon, see active previews, click to open.

## Install

### Homebrew

```bash
brew tap gunnartorfis/render-menu https://github.com/gunnartorfis/render-menu
brew install --cask render-menu
```

### Manual

Download the latest `.zip` from [Releases](https://github.com/gunnartorfis/render-menu/releases), unzip, and move `Render Menu.app` to `/Applications`.

### Build from source

```bash
git clone https://github.com/gunnartorfis/render-menu.git
cd render-menu
swift build
.build/debug/RenderMenu
```

## Setup

1. Click the cloud icon in the menu bar
2. Enter your [Render API key](https://dashboard.render.com/account/api-keys)
3. (Optional) Enter a [GitHub token](https://github.com/settings/tokens) for PR titles and author filtering
4. Select a workspace

## Features

- **PR preview list** — shows all active PR preview environments with deploy status
- **Click to open** — click a preview to open its URL in your browser
- **Workspace switcher** — switch between Render workspaces
- **GitHub integration** — shows PR titles, links to PRs, filters by author
- **"Mine" filter** — default view shows only your PRs (requires GitHub token)
- **Deploy badge** — menu bar icon shows count when deploys go live
- **Auto-refresh** — polls every 60s

## Releasing

Tag a version to trigger a GitHub Actions release:

```bash
git tag v0.2.0
git push origin v0.2.0
```

This builds a universal (arm64 + x86_64) `.app` bundle and publishes it as a GitHub Release.

After the release, update `Casks/render-menu.rb` with the new version and sha256:

```bash
shasum -a 256 .build/app/RenderMenu-0.2.0.zip
```

### Local build

```bash
bash scripts/build-app.sh 0.2.0
open ".build/app/Render Menu.app"
```

## Requirements

- macOS 14 (Sonoma) or later
- Render API key
- GitHub token (optional, for PR titles)
