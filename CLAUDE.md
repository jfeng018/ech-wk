# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ECH Workers (ech-wk) is a cross-platform proxy client that encrypts the TLS SNI using ECH (Encrypted Client Hello, a TLS 1.3 extension, requires Go 1.23+). It proxies traffic through a Cloudflare Worker and exposes a local SOCKS5 / HTTP CONNECT proxy on a user-configured listening port. The repo is the GitHub-deployed source for the byJoey/ech-wk project, which builds Windows/macOS/Linux desktop and soft-router binaries.

The communication pipeline is: **local client (Go)** — WebSocket tunnel — **Cloudflare Worker (`_worker.js`)**, which relays to the target host through Cloudflare's sockets API.

## Repository Components

The three major components are largely independent:

- **`ech-workers.go`** — the Go core proxy engine (standard library + `github.com/gorilla/websocket`). This is the only real proxy logic. Runs standalone or is spawned as a subprocess by the GUI / soft-router. It is split across three files in the same package: `ech-workers.go` (core + auth), `tproxy_linux.go` (`//go:build linux`, TPROXY via `getsockopt SO_ORIGINAL_DST`), `tproxy_other.go` (`//go:build !linux`, non-Linux stub). **Always build the package (`go build .`), never a single file** — building `ech-workers.go` alone omits the TPROXY files.
- **`gui.py`** — Python/PyQt5 desktop GUI (PyQt5 + PySocks + pystray + Pillow). It is a *launcher/configurator*: it does NOT proxy traffic itself. It manages server configs, spawns `ech-workers` as a subprocess, tails its stdout into a log pane, and sets the OS system proxy.
- **`_worker.js`** — the Cloudflare Worker server side (deployed separately to Workers). Receives WebSocket connections, parses a `CONNECT:host|port` framing protocol, opens outbound sockets via `connect()` from `cloudflare:sockets`, and pumps bytes both ways using `DATA:` / raw ArrayBuffer frames. Ships with CF fallback IPs (`CF_FALLBACK_IPS`) that are tried on Cloudflare connect errors.
- **`softrouter.sh`** — standalone POSIX sh installer/deployer for OpenWrt / systemd / generic Linux soft routers. Detects arch and init system, downloads the matching release artifact from GitHub, installs `ech-workers` to `/usr/bin/ech-workers`, writes config to `/etc/ech-workers.conf`, and manages a service.
- **`luci-app-ech-workers/`** — vendored OpenWrt LuCI app (from [SunshineList/luci-app-ech-workers](https://github.com/SunshineList/luci-app-ech-workers), maintained in-tree). Standard LuCI package: `Makefile`, `luasrc/` (controller/cbi/views), `po/`, `root/etc/` (UCI config, procd init.d with nftables TPROXY rules, uci-defaults that auto-downloads the ech-wk softrouter binary on install). It manages the same `ech-workers` binary — the old `server/echo-worker.go` fork was unified into `ech-workers.go` (TPROXY + auth both live in the one binary).
- **`.github/workflows/build.yml`** — GitHub Actions: Go cross-compile matrix (desktop GUI + CLI soft-router variants incl. armv6/armv7/mips/mipsle via `GOARM`/`GOMIPS`). On tags it also builds the GUI with PyInstaller, the LuCI ipk (OpenWrt SDK), a multi-arch GHCR Docker image, and the native macOS menu bar app. There is no checked-in `go.mod`/`go.sum` — CI runs `go mod init ech-workers && go mod tidy` itself.
- **`macos/EchWorkersBar/`** — native macOS menu-bar app (SwiftUI `MenuBarExtra`, Swift 5.9 SPM package), modeled on [CodexBar](https://github.com/steipete/CodexBar). No Dock icon, menu-bar status dot, start/stop the proxy, recent-log feed, settings window. **Config is shared** with `gui.py` — both read/write `~/Library/Application Support/ECHWorkersClient/config.json`. Build with `cd macos/EchWorkersBar && swift build`. The repo is **multi-GUI**: `gui.py` (PyQt5) for Windows/Linux, `EchWorkersBar` (Swift/SwiftUI) for macOS.

## The Go core (`ech-workers.go`)

The file is organized as sequential sections (see the `// ===...===` banners):

1. **CLI flags** (parsed in `init()`): `-f` server address (required), `-l` listen address (default `127.0.0.1:30000`), `-token`, `-ip` (bypass DNS), `-dns` DoH server (default `dns.alidns.com/dns-query`), `-ech` ECH query domain (default `cloudflare-ech.com`), `-routing` mode, `-username`/`-password` (optional local-proxy auth; setting `-username` enables it), `-tproxy` (Linux TPROXY transparent-proxy listen address).
2. **IP helpers** — `ipToUint32`, `isChinaIP`, `compareIPv6`, binary-search over loaded China IP ranges.
3. **IP list loading** — `downloadIPList` / `loadChinaIPList` / `loadChinaIPV6List` fetch `chn_ip.txt` and `chn_ip_v6.txt` from [mayaxcn/china-ip-list](https://github.com/mayaxcn/china-ip-list) into program dir if missing/empty. Only loaded when routing is `bypass_cn`.
4. **Routing** — `shouldBypassProxy(targetHost)` decides per-destination whether to proxy (based on `routingMode` and resolved IPs).
5. **ECH** — `prepareECH`/`refreshECH`/`buildTLSConfigWithECH` + DoH lookups (`queryHTTPSRecord`/`queryDoH`) fetch the ECH config for the query domain, then build a `tls.Config` carrying it for the WebSocket dial.
6. **WebSocket client** — `dialWebSocketWithECH` connects to the server `-f` host with the ECH-enabled TLS config.
7. **Proxy server** — `runProxyServer`/`handleConnection` demultiplex the first byte: SOCKS5 (`0x05`), HTTP (`G`/P...) and route into `handleSOCKS5` (incl. UDP associate) or `handleHTTP`, ultimately through `handleTunnel` over WebSocket, or `handleDirectConnection` when bypassing.
   - **Optional local auth** (`authEnabled`/`validCredentials`/`validHTTPProxyAuth`): when `-username` is set, SOCKS5 negotiates RFC 1929 username/password (method `0x02`), and HTTP requires `Proxy-Authorization: Basic`. Credentials compare via `crypto/subtle`. The `Proxy-Authorization` header is already stripped before forwarding upstream.
   - **TPROXY** (`-tproxy`, Linux only): `runTProxyServer`/`handleTProxyConnection`/`getOriginalDst` read the original destination via `getsockopt SO_ORIGINAL_DST` and tunnel it (`modeTProxy`). Guarded by `runtime.GOOS` — returns early on non-Linux. Used by the LuCI app's transparent-proxy mode (nftables redirects br-lan 80/443 → tproxy port).

### Wire framing (`_worker.js` protocol)

The WebSocket messages between Go client and Worker:
- `CONNECT:host:port|firstFrame` — open remote socket to host:port and forward initial data.
- `DATA:<payload>` — string-encoded data (used for the initial frame / small payloads).
- Raw `ArrayBuffer` — raw binary tunnel data.
- `CLOSE` — end session; the remote side also sends `CLOSE` and `CONNECTED`/`ERROR:<msg>` status strings.

If you change framing, update both `ech-workers.go` and `_worker.js`.

## The GUI (`gui.py`)

Two key classes:
- `ConfigManager` — JSON config persistence (servers list, current selection, routing). Stored at `%APPDATA%\ECHWorkersClient\config.json`, `~/Library/Application Support/ECHWorkersClient/config.json`, or `~/.config/ECHWorkersClient/config.json` by platform. Each server carries per-server fields (server/listen/token/ip/dns/ech/routing_mode, plus optional `username`/`password` for proxy auth).
- `ProcessThread(QThread)` — finds the compiled `ech-workers` binary (next to the GUI, CWD, or PATH) and runs it, decoding stdout as UTF-8 into the log. Builds the CLI args from the server config, passing `-username`/`-password` only when set.
- `MainWindow(QMainWindow)` — all UI: server CRUD, routing mode combo, start/stop, system proxy set/reset (Windows registry, macOS `networksetup`; Linux has no auto system-proxy), tray icon, and auto-start. System-proxy bypass lists differ per routing mode and platform.

## The macOS menu bar app (`macos/EchWorkersBar/`)

Native SwiftUI menu-bar app for macOS (deprecated `gui.py` PyQt5 path is the Windows/Linux GUI; the macOS GUI is this app). Modeled on CodexBar (no Dock icon, `.accessory` activation policy, dynamic status dot).

- `EchWorkersBarApp.swift` — `@main`, `MenuBarExtra` (green/gray dot = running/stopped), `.menuBarExtraStyle(.window)` popover, plus a `Window(id: "settings")` for settings.
- `ConfigStore.swift` — reads/writes the **same config.json as gui.py** (`~/Library/Application Support/ECHWorkersClient/config.json`), so both GUIs share server setups. Snapshot model: `ServerConfig` (fields mirror gui.py; snake_case identifiers make JSON keys match without `CodingKeys`).
- `ProxyManager.swift` — spawns the `ech-workers` binary via `Process`, captures stdout/stderr into a ring-buffered log (~500 lines). CLI args mirror gui.py (only non-empty/non-default flags).
- `SettingsView.swift` / `MenuBarView.swift` — settings window (server CRUD + editor) and the menu-bar popover (status, start/stop, server switch, recent log).

Build/test: `cd macos/EchWorkersBar && swift build`. `.app` assembly + release is done in the `macos-app` CI job (needs `build`; bundles the darwin `ech-workers` into `Contents/Resources`).

## The LuCI router GUI (`luci-app-ech-workers/`)

Vendored OpenWrt LuCI app. Key integration points:
- `root/etc/config/ech-workers` — UCI config schema (enabled, server_addr, listen_addr, token, **username/password** for auth, best_ip, dns, ech_domain, routing, tproxy_enabled/port).
- `root/etc/init.d/ech-workers` — procd service. Builds the `ech-workers` command line with `procd_append_param`, adding `-username`/`-password` when set and `-tproxy 0.0.0.0:$tproxy_port` when transparent-proxy is enabled. Sets up/tears down nftables TPROXY rules for br-lan 80/443.
- `root/etc/uci-defaults/luci-ech-workers` — on install, auto-downloads `ECHWorkers-linux-<arch>-softrouter.tar.gz` from ech-wk releases and extracts `ech-workers` to `/usr/bin/`.
- `luasrc/model/cbi/ech-workers.lua` — CBI config form (holds the auth `username`/`password` fields and transparent-proxy flag/port).
- There is NO checked-in binary; the ipk is built with the OpenWrt SDK from `Makefile`.

## Build & run commands

Only the Go core needs compilation; it requires Go 1.23+ (for ECH support).

```bash
# Build the CLI proxy core (single static binary)
go mod init ech-workers   # only if go.mod absent (tidy pulls in gorilla/websocket)
go mod tidy
go build -o ech-workers .

# Run it (server address is mandatory)
./ech-workers -f your-worker.workers.dev:443

# Graphical interface (Python deps)
pip install -r requirements.txt   # pystray, Pillow, PyQt5
python gui.py
# or package via PyInstaller (as CI does):
# pyinstaller --onefile --windowed --name ECHWorkersGUI --hidden-import=PyQt5 gui.py
```

There is no test suite in this repo. Verification is manual: run `./ech-workers -f <addr>` and `curl --socks5 127.0.0.1:30000 <url>`, or use the GUI.

## Useful CLI flags (for the soft-router / headless flow)

- `./ech-workers -f host:443 -l 0.0.0.0:30001 -routing bypass_cn` — listen on all interfaces, bypass mainland-China IPs (auto-downloads IP lists).
- `-routing global` (all proxied, default), `bypass_cn` (China direct), `none` (all direct, no proxy).
- `-ip <addr>` pins the server IP to skip DNS resolution.
- `-username <u> -password <p>` — require auth on the local proxy (SOCKS5 RFC 1929 / HTTP Basic). Leave unset for no auth.
- `-tproxy <addr>` — Linux only: start a TPROXY transparent-proxy listener (used by the LuCI app).
