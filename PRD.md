# Render Menu - PRD

## Overview

macOS menu bar app that shows PR preview environments from Render.com workspaces. Click the icon, see active previews with URLs, click to open in browser.

## Problem

Finding PR preview URLs requires navigating the Render dashboard. Developers need instant access to preview environments while reviewing PRs.

## Core Features

### 1. Menu Bar Icon
- Lives in macOS menu bar with a small cloud/deploy icon
- Shows dot indicator when previews are deploying

### 2. Workspace Switcher
- List all workspaces (owners) the API key has access to via `GET /v1/owners`
- Persist selected workspace between launches
- Switch workspace from the menu dropdown

### 3. PR Preview List
For the selected workspace, show all services that are PR preview instances:
- Service name
- Preview URL (clickable - opens in browser)
- Deploy status: live / deploying / failed / suspended
- Status color indicator (green/yellow/red/gray)

**Identification strategy:** Filter services by checking if they have a `parentServer` object (indicates they're a preview instance spawned from a parent service). Services created by the preview environment system are child services linked to their parent.

### 4. Auto-Refresh
- Poll `GET /v1/services?ownerId={id}` every 60s
- Manual refresh via menu item
- Show "last updated" timestamp

### 5. Settings
Minimal settings accessible from the menu:
- **Login:** Enter Render API key on first launch
- **Logout:** Clear API key from Keychain
- **API Key:** Stored in macOS Keychain

### 6. Standard Menu Items
- Refresh
- Settings...
- Quit

## Technical Design

| Aspect | Choice |
|--------|--------|
| Language | Swift |
| UI | SwiftUI + AppKit (`NSStatusItem`) |
| Target | macOS 13+ (Ventura) |
| Auth storage | macOS Keychain (`Security` framework) |
| Build | Swift Package Manager |
| Networking | `URLSession` async/await |

### API Endpoints Used

| Endpoint | Purpose |
|----------|---------|
| `GET /v1/owners` | List workspaces for switcher |
| `GET /v1/services?ownerId={id}&limit=100` | List services, filter for previews client-side |
| `GET /v1/services/{id}/deploys?limit=1` | Get latest deploy status per preview service |

### Data Flow

1. On launch: read API key from Keychain, fetch owners
2. Load selected workspace (or prompt to pick one)
3. Fetch services for workspace, filter for preview services (`parentServer` != nil)
4. For each preview service, show name + URL + suspended status
5. Poll every 60s, update menu

## UI Layout

```
┌──────────────────────────────┐
│  Workspace: Acme Inc     ▸   │  ← submenu with workspace list
├──────────────────────────────┤
│  🟢  my-app-pr-42            │
│      my-app-pr-42.onrender.com│
│                               │
│  🟡  api-server-pr-18        │
│      api-server-pr-18.onre.. │
│                               │
│  🔴  web-client-pr-7         │
│      (deploy failed)          │
├──────────────────────────────┤
│  Last updated: 2 min ago      │
│  ↻ Refresh                    │
├──────────────────────────────┤
│  Settings...                  │
│  Quit                         │
└──────────────────────────────┘
```

## Non-Goals (v1)

- Deploy triggering
- Log viewing
- Push notifications
- Filtering/search within previews
- Multiple API keys

## Unresolved Questions

1. Does `parentServer` reliably identify PR preview services, or do we need another heuristic (e.g. naming pattern, `suspenders` array)?
2. Do preview services include the PR number/title in any field, or only in the auto-generated service name?
