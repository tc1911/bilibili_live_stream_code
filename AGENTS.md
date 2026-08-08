# AGENTS.md

Desktop app (B站直播工具): Python backend (pywebview window + Qt tray) + Vue 3 frontend (Vite). `main.py` is the entrypoint; the frontend is loaded from `frontend/dist/index.html`, there is no dev server involved in normal runs.

## Build / run

- Frontend must be built before running, and `frontend/dist` is gitignored:
  ```bash
  cd frontend && npm install && npm run build && cd ..
  pip install -r requirements.txt
  python main.py
  ```
- `npm run dev` (vite) alone is useless for backend features: `frontend/src/api/bridge.js` mocks `window.pywebview` and calls fail with "Python 后端未连接".
- There are **no tests, no linter, no typecheck** anywhere. Verification is: build frontend + run `python main.py` and click through the flow. Never claim `npm run test`/`pytest` work here.
- CI (`.github/workflows/release.yml`) builds with Python **3.9** and Node 18 even though `pyproject.toml` declares `>=3.12` — keep code 3.9-compatible or CI breaks.
- `VERSION` file (e.g. `v2.3.17`) is shown in the UI; the release workflow overwrites it on tag push. Bump it when tagging releases.

## Backend ↔ frontend bridge

- Frontend → Python: methods on `ApiService` (`backend/api_service.py`) are exposed as `window.pywebview.api.<method>`. Every call goes through the single wrapper `frontend/src/api/bridge.js` — add new API methods to both places, returning `{"code": 0, ...}` / `{"code": -1, "msg": ...}`.
- Python → frontend: `window_service.send_to_frontend("onXxx", data)` executes `window.onXxx` via `evaluate_js`. Handler names in use: `onBackendLog`, `onDanmuMessage`, `onAppShown`, `onAppHidden`, `onTrayLiveStarted`, `onTrayLiveStopped`, `onTrayNeedFaceVerify`, `onTrayLiveError`.
- Two windows: main window + hidden danmu overlay (`frontend/overlay.html`, vite multi-entry build; second HTML/JS entry). Overlay window is created hidden in `main.py` and shown via `toggle_danmu_overlay`; danmu messages are pushed to it too (`window_service.send_to_window`). Overlay uses its own `OverlayApiProxy` js_api and Linux drag via `startSystemMove` (Wayland: `window.move` is a no-op).
- `start_live` returns codes **60024/60043** = face verification required (frontend shows a QR); `switch_account`/`logout` must stop the danmu WS first (see `api_service.py`).
- Live/danmu state lives in `backend/state.py` (`SessionState`), shared by services. All danmu WS work runs on a dedicated asyncio loop (`api_service.loop`), so other threads must submit via `asyncio.run_coroutine_threadsafe`.

## Generated code — do not hand-edit

`backend/dm_pb2.py` is generated from `backend/dm.proto` (protoc). Regenerate with protoc when `dm.proto` changes. It validates against protobuf runtime 6.31.x at import; a mismatched `protobuf` pip version makes danmu import fail.

## Platform quirks (main.py)

- Env-var setup (Wayland/X11 `QT_QPA_PLATFORM`, `GDK_BACKEND`, `QT_OPENGL`, `QTWEBENGINE_CHROMIUM_FLAGS`) must happen **before `import webview`** — that's why it's at the top of `main.py`. Keep it there.
- Linux forces the Qt backend (`gui='qt'`); set `DISABLE_TRAY=1` to skip tray startup for crash debugging. On non-Windows, exit uses `os._exit(0)` because lingering asyncio threads cause SIGABRT.
- Config/log locations (frozen or not): Linux uses XDG — config `~/.config/BiliLiveTool/config.json` (override with `BILILIVE_CONFIG_HOME`; auto-migrates a legacy `config.json` next to the script), logs `~/.local/share/BiliLiveTool/logs/app.log`. Windows/macOS: next to the executable.
- UI text and code comments are Chinese — keep that convention.

## Releases

Push a `v*` tag on `master` to trigger `release.yml`: builds one-file PyInstaller binaries for Ubuntu 22.04 / macOS / Windows; Linux additionally packages `.deb` / `.rpm` / `.pkg.tar.zst` (shared assets in `packaging/linux/`), auto-generates a DeepSeek changelog (requires `DEEPSEEK_API_KEY` secret), and creates the GitHub release. Manual packaging commands (with `--add-data` flags for `frontend/dist`, `VERSION`, icons, hidden imports) are in `README.md`.
