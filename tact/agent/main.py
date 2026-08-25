import asyncio
import logging
import secrets
import shutil
import time
import urllib.parse
from pathlib import Path
from typing import Any, Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Form, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, RedirectResponse

from .ws_manager import ConnectionManager
from .actions import ActionRegistry
from .monitoring import StateMonitor
from .events import Event
from .config import Config
from .accounts import AccountStore, AuthSession, ProviderTokenVerifier, AppleWebAuth

logging.basicConfig(level=logging.INFO)
app = FastAPI()
# Browser clients (Flutter web served from a dev server) call the agent
# cross-origin. Auth is OTP + explicit laptop-side approval, so any origin is
# acceptable for this LAN tool.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
manager = ConnectionManager()
actions = ActionRegistry()
monitor = StateMonitor(actions.event_bus, actions.integrations)
config = Config()
accounts = AccountStore()
provider_tokens = ProviderTokenVerifier()
apple_web_auth = AppleWebAuth(provider_tokens)
_oauth_states: dict[str, tuple[str, float]] = {}
_oauth_exchanges: dict[str, tuple[AuthSession, float]] = {}

_otp = config.generate_pairing_token()
_logger = logging.getLogger("tact.startup")
_logger.info("Tact Desktop Agent started")
_logger.info("Client URL: http://%s/client/index.html", "0.0.0.0:8000")
_logger.info("Pairing OTP (valid 5 min): %s", _otp)
_logger.info("To pair a device: open the client URL, enter the OTP, then approve here: http://%s/admin/pair/pending", "0.0.0.0:8000")

app.mount("/client", StaticFiles(directory="client", html=True), name="client")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/")
async def index():
    return RedirectResponse(url="/client/")

@app.get("/index.html")
async def index_html():
    return RedirectResponse(url="/client/")

@app.get("/api/debug/config")
async def debug_config():
    return {
        "paired_devices": [
            {
                "device_id": d.device_id,
                "label": d.label,
                "last_seen": d.last_seen,
            }
            for d in config.list_devices()
        ],
        "pending_pairings": [
            {
                "pending_id": p.get("pending_id"),
                "device_id": p.get("device_id"),
                "label": p.get("label"),
                "created_at": p.get("created_at"),
            }
            for p in config._data.get("pending_pairings", [])
        ],
        "pairing_token_exists": (
            config._data.get("pairing_token") is not None
        ),
        "pairing_token": config._data.get("pairing_token"),
        "pairing_token_expires": (
            config._data.get("pairing_token_expires")
        ),
    }


@app.post("/api/debug/regenerate-otp")
async def regenerate_otp():
    """Generate a new 6-digit pairing OTP."""
    otp = config.generate_pairing_token(ttl_seconds=300)

    _logger.info(
        "Pairing OTP regenerated (valid 5 min): %s",
        otp,
    )

    return {
        "ok": True,
        "pairing_token": otp,
        "pairing_token_expires": (
            config._data.get("pairing_token_expires")
        ),
    }


@app.get("/api/pair/status")
async def pair_status():
    devices = config.list_devices()
    return {
        "paired": len(devices) > 0,
        "devices": [
            {"device_id": d.device_id, "label": d.label, "last_seen": d.last_seen}
            for d in devices
        ],
        "pairing_token": config._data.get("pairing_token") is not None,
    }


@app.get("/api/pair/me")
async def pair_me(device_id: str = ""):
    if not device_id:
        return {"paired": False, "device_id": None}
    devices = config.list_devices()
    device = next((d for d in devices if d.device_id == device_id), None)
    return {
        "paired": device is not None,
        "device_id": device_id,
        "device": {"device_id": device.device_id, "label": device.label, "last_seen": device.last_seen} if device else None,
    }


@app.post("/api/pair/request")
async def pair_request(payload: dict):
    token = payload.get("token")
    device_id = payload.get("device_id")
    label = payload.get("label") or device_id
    if not token or not device_id:
        raise HTTPException(status_code=400, detail="token and device_id required")
    if not config.consume_pairing_token(token):
        raise HTTPException(status_code=400, detail="invalid_or_expired_token")
    pendings = config._data.get("pending_pairings", [])
    config._data["pending_pairings"] = [p for p in pendings if p.get("device_id") != device_id]
    pending = config.create_pending_pairing(token, device_id, label)
    _logger.info(
        "Pairing request from %s (%s). Approve at http://%s/admin/pair/pending",
        label,
        device_id,
        "0.0.0.0:8000",
    )
    return {
        "ok": True,
        "status": "pending",
        "pending_id": pending.pending_id,
        "device_id": pending.device_id,
    }


@app.post("/api/pair/approve")
async def pair_approve(payload: dict):
    pending_id = payload.get("pending_id")
    if not pending_id:
        raise HTTPException(status_code=400, detail="pending_id required")
    device = config.approve_pending_pairing(pending_id)
    if device is None:
        raise HTTPException(status_code=404, detail="pending_not_found_or_expired")
    _logger.info("Pairing approved for %s (%s)", device.label, device.device_id)
    return {"ok": True, "device": {"device_id": device.device_id, "label": device.label}}


@app.post("/api/pair/reject")
async def pair_reject(payload: dict):
    pending_id = payload.get("pending_id")
    if not pending_id:
        raise HTTPException(status_code=400, detail="pending_id required")
    pendings = config._data.get("pending_pairings", [])
    new_pendings = [p for p in pendings if p.get("pending_id") != pending_id]
    if len(new_pendings) == len(pendings):
        raise HTTPException(status_code=404, detail="pending_not_found")
    config._data["pending_pairings"] = new_pendings
    config._save()
    return {"ok": True}


@app.post("/api/pair/reset")
async def pair_reset(payload: dict):
    device_id = payload.get("device_id")
    if not device_id:
        raise HTTPException(status_code=400, detail="device_id required")
    config.unpair_device(device_id)
    pendings = config._data.get("pending_pairings", [])
    config._data["pending_pairings"] = [p for p in pendings if p.get("device_id") != device_id]
    config._save()
    return {"ok": True}

@app.post("/api/pair/reset_all")
async def pair_reset_all():
    config._data["paired_devices"] = []
    config._data["pending_pairings"] = []
    config._save()
    return {"ok": True}


def _account_session(authorization: Optional[str]) -> AuthSession:
    scheme, _, token = (authorization or "").partition(" ")
    if scheme.casefold() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="authentication_required")
    session = accounts.session(token)
    if session is None:
        raise HTTPException(status_code=401, detail="invalid_or_expired_session")
    return session


def _session_response(session: AuthSession) -> dict[str, Any]:
    return {
        "token": session.token,
        "expires_at": session.expires_at,
        "account": {
            "account_id": session.account_id,
            "email": session.email,
            "display_name": session.display_name,
            "provider": session.provider,
        },
    }


def _device_response(device: Any) -> dict[str, Any]:
    return {
        "device_id": device.device_id,
        "label": device.label,
        "platform": device.platform,
        "device_type": device.device_type,
        "model": device.model,
        "host": device.host,
        "port": device.port,
        "last_seen": device.last_seen,
        "active": device.active,
        "can_connect": device.can_connect,
    }


@app.post("/api/auth/register")
async def account_register(payload: dict):
    try:
        session = accounts.register_email(
            str(payload.get("email") or ""),
            str(payload.get("password") or ""),
            str(payload.get("display_name") or ""),
        )
    except ValueError as error:
        detail = str(error)
        status = 409 if detail == "email_already_registered" else 400
        raise HTTPException(status_code=status, detail=detail) from error
    return _session_response(session)


@app.post("/api/auth/login")
async def account_login(payload: dict):
    session = accounts.authenticate_email(
        str(payload.get("email") or ""),
        str(payload.get("password") or ""),
    )
    if session is None:
        raise HTTPException(status_code=401, detail="incorrect_email_or_password")
    return _session_response(session)


@app.post("/api/auth/provider")
async def account_provider_login(payload: dict):
    provider = str(payload.get("provider") or "").strip().lower()
    identity_token = str(payload.get("identity_token") or "").strip()
    if not identity_token:
        raise HTTPException(status_code=400, detail="identity_token_required")
    try:
        claims = await asyncio.to_thread(
            provider_tokens.verify,
            provider,
            identity_token,
        )
        session = accounts.authenticate_provider(provider, claims)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        _logger.warning("Provider token verification failed for %s: %s", provider, error)
        raise HTTPException(status_code=401, detail="invalid_provider_token") from error
    return _session_response(session)


@app.get("/api/auth/apple/start")
async def account_apple_start(redirect_uri: str):
    parsed = urllib.parse.urlparse(redirect_uri)
    if parsed.scheme != "tact" or parsed.netloc != "auth":
        raise HTTPException(status_code=400, detail="invalid_app_redirect")
    state = secrets.token_urlsafe(24)
    _oauth_states[state] = (redirect_uri, time.time() + 300)
    try:
        return RedirectResponse(apple_web_auth.authorization_url(state))
    except ValueError as error:
        _oauth_states.pop(state, None)
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.post("/api/auth/apple/callback")
async def account_apple_callback(
    code: str = Form(default=""),
    state: str = Form(default=""),
    error: str = Form(default=""),
):
    pending = _oauth_states.pop(state, None)
    if pending is None or pending[1] < time.time():
        raise HTTPException(status_code=400, detail="invalid_or_expired_oauth_state")
    redirect_uri = pending[0]
    if error:
        separator = "&" if "?" in redirect_uri else "?"
        return RedirectResponse(
            f"{redirect_uri}{separator}{urllib.parse.urlencode({'error': error})}",
            status_code=303,
        )
    try:
        claims = await asyncio.to_thread(apple_web_auth.exchange, code)
        session = accounts.authenticate_provider("apple", claims)
    except Exception as exchange_error:
        _logger.warning("Apple web authorization failed: %s", exchange_error)
        raise HTTPException(status_code=401, detail="apple_authorization_failed") from exchange_error
    exchange_code = secrets.token_urlsafe(24)
    _oauth_exchanges[exchange_code] = (session, time.time() + 60)
    separator = "&" if "?" in redirect_uri else "?"
    return RedirectResponse(
        f"{redirect_uri}{separator}{urllib.parse.urlencode({'code': exchange_code})}",
        status_code=303,
    )


@app.post("/api/auth/exchange")
async def account_auth_exchange(payload: dict):
    exchange_code = str(payload.get("code") or "")
    pending = _oauth_exchanges.pop(exchange_code, None)
    if pending is None or pending[1] < time.time():
        raise HTTPException(status_code=400, detail="invalid_or_expired_exchange_code")
    return _session_response(pending[0])


@app.get("/api/auth/session")
async def account_session(authorization: Optional[str] = Header(default=None)):
    return _session_response(_account_session(authorization))


@app.post("/api/auth/logout")
async def account_logout(authorization: Optional[str] = Header(default=None)):
    session = _account_session(authorization)
    accounts.revoke_session(session.token)
    return {"ok": True}


@app.get("/api/account/devices")
async def account_devices(authorization: Optional[str] = Header(default=None)):
    session = _account_session(authorization)
    return {
        "devices": [
            _device_response(device)
            for device in accounts.list_devices(session.account_id)
        ]
    }


@app.post("/api/account/devices")
async def account_device_upsert(
    payload: dict,
    authorization: Optional[str] = Header(default=None),
):
    session = _account_session(authorization)
    try:
        device = accounts.upsert_device(
            account_id=session.account_id,
            device_id=str(payload.get("device_id") or ""),
            label=str(payload.get("label") or ""),
            platform=str(payload.get("platform") or "unknown"),
            device_type=str(payload.get("device_type") or ""),
            model=str(payload.get("model") or ""),
            host=str(payload.get("host") or "").strip() or None,
            port=int(payload["port"]) if payload.get("port") is not None else None,
        )
    except (TypeError, ValueError) as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return {"device": _device_response(device)}


@app.delete("/api/account/devices/{device_id}")
async def account_device_remove(
    device_id: str,
    authorization: Optional[str] = Header(default=None),
):
    session = _account_session(authorization)
    if not accounts.remove_device(session.account_id, device_id):
        raise HTTPException(status_code=404, detail="device_not_found")
    config.unpair_device(device_id)
    return {"ok": True}


@app.post("/api/account/devices/connect")
async def account_device_connect(
    payload: dict,
    authorization: Optional[str] = Header(default=None),
):
    session = _account_session(authorization)
    target_id = str(payload.get("target_device_id") or "")
    client_id = str(payload.get("client_device_id") or "")
    client_label = str(payload.get("client_label") or "").strip() or client_id
    if not target_id or not client_id:
        raise HTTPException(
            status_code=400,
            detail="target_device_id_and_client_device_id_required",
        )
    target = accounts.device(session.account_id, target_id)
    if target is None:
        raise HTTPException(status_code=404, detail="device_not_found")
    if not target.can_connect:
        raise HTTPException(status_code=409, detail="device_not_connectable")
    config.pair_device(client_id, client_label)
    return {
        "connection": {
            "host": target.host,
            "port": target.port,
            "websocket_path": "/ws",
            "token": client_id,
            "target_device_id": target.device_id,
            "target_label": target.label,
        }
    }


@app.get("/api/state")
async def get_state():
    return {"state": snapshot_state()}


@app.post("/api/workspace/set")
async def set_workspace(payload: dict):
    path = payload.get("path")
    if not path:
        raise HTTPException(status_code=400, detail="path required")
    p = Path(path)
    if not p.is_dir():
        raise HTTPException(status_code=400, detail="not_a_directory")
    resolved = str(p.resolve())
    app.state.current_workspace = resolved
    actions.set_current_workspace_path(resolved)
    _logger.info("Workspace override set to %s", resolved)
    return {"ok": True, "workspace": resolved}


def _current_workspace_path() -> str:
    override = getattr(app.state, "current_workspace", None)
    if override:
        return override
    actions_override = actions._current_workspace_path
    if actions_override:
        return actions_override
    vscode_workspaces = actions.vscode.workspaces()
    detected = vscode_workspaces.get("workspaces", []) if vscode_workspaces.get("available") else []
    if detected:
        return detected[0]
    return str(Path.cwd())


def _is_state_changing_action(action_id: str) -> bool:
    """Actions that mutate state we snapshot — the phone should refresh after."""
    return action_id.startswith(
        ("git.", "media.", "system.set_workspace", "vscode.open_workspace",
         "docker.", "clipboard.", "context.", "chrome.", "teams.",
         "window.", "project.", "terminal.", "system.brightness", "system.set_sink",
         "system.set_source",
         "system.open_app", "system.focus_app", "system.lock_screen",
         "system.screenshot", "system.volume", "system.mute")
    )


def snapshot_state() -> dict[str, Any]:
    """Compose the state snapshot from every integration's `snapshot()`."""
    workspace_path = _current_workspace_path()
    for integration in actions.integrations:
        if hasattr(integration, "workspace_path"):
            integration.workspace_path = workspace_path
    state: dict[str, Any] = {
        integration.name: integration.snapshot()
        for integration in actions.integrations
    }
    # Project-aware workspace: when the Context Engine resolves a project and
    # no explicit workspace override is set, point the cross-integration
    # git/vscode view — and hence git.* surface actions — at that project.
    context_state = state.get("context") or {}
    project = context_state.get("project")
    explicit_override = (
        getattr(app.state, "current_workspace", None) or actions._current_workspace_path
    )
    if project and not explicit_override:
        workspace_path = project
        for integration in actions.integrations:
            if hasattr(integration, "workspace_path"):
                integration.workspace_path = workspace_path
    current_root = actions.git.discover_root(workspace_path)
    git_status = actions.git.status(current_root) if current_root else {"available": False, "root": None}
    git_branches = actions.git.branches(current_root) if current_root else {"available": False, "branches": [], "current": None}
    git_tree = actions.git.tree(current_root) if current_root else {"available": False, "tree": []}
    git_log = actions.git.log(current_root) if current_root else {"available": False, "commits": []}
    vscode_status = actions.vscode.status(current_root)
    vscode_workspaces = actions.vscode.workspaces()
    terminal_available = bool(shutil.which("gnome-terminal") or shutil.which("konsole") or shutil.which("kitty") or shutil.which("alacritty") or shutil.which("xfce4-terminal"))

    state: dict[str, Any] = {
        integration.name: integration.snapshot()
        for integration in actions.integrations
    }
    # Workspace is a cross-integration view (git + vscode), assembled here.
    state["workspace"] = {
        "cwd": str(Path.cwd()),
        "git_root": git_status.get("root"),
        "vscode": vscode_status,
        "vscode_workspaces": vscode_workspaces,
        "git": git_status,
        "git_branches": git_branches,
        "git_tree": git_tree,
        "git_log": git_log,
        "terminal_available": terminal_available,
        "current_workspace": workspace_path,
    }
    state["actions"] = sorted(actions._registry.keys())
    return state


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    _logger.info("WebSocket connection attempt from %s", websocket.client)
    await websocket.accept()
    _logger.info("WebSocket connection accepted from %s", websocket.client)
    device_id = None
    try:
        auth_msg = await asyncio.wait_for(websocket.receive_json(), timeout=5)
        if not isinstance(auth_msg, dict) or auth_msg.get("type") != "auth":
            _logger.warning("WebSocket auth rejected: missing auth type from %s", websocket.client)
            await websocket.send_json({"type": "error", "message": "auth_required"})
            await websocket.close(code=4001)
            return

        token = auth_msg.get("token")
        device_label = auth_msg.get("label") or "unknown"
        _logger.info("WebSocket auth attempt token=%s label=%s from %s", token, device_label, websocket.client)

        if not token:
            _logger.warning("WebSocket auth rejected: empty token from %s", websocket.client)
            await websocket.send_json({"type": "error", "message": "unauthorized"})
            await websocket.close(code=4003)
            return

        if token in [d.device_id for d in config.list_devices()]:
            device_id = token
            config.update_last_seen(device_id)
            _logger.info("WebSocket auth accepted for paired device %s from %s", device_id, websocket.client)
        elif token == config._data.get("pairing_token"):
            device_id = token
            config.pair_device(device_id, device_label)
            _logger.info("WebSocket auth accepted via OTP for new device %s from %s", device_id, websocket.client)
        else:
            _logger.warning("WebSocket auth rejected: unknown device %s from %s", token, websocket.client)
            await websocket.send_json({"type": "error", "message": "unauthorized"})
            await websocket.close(code=4003)
            return
        telemetry_task = None
        try:
            await websocket.send_json({"type": "init", "payload": snapshot_state()})

            async def telemetry_loop(ws: WebSocket):
                while True:
                    await asyncio.sleep(5)
                    try:
                        # snapshot_state runs subprocesses (git, docker,
                        # playerctl…) — offload so the event loop stays free.
                        payload = await asyncio.to_thread(snapshot_state)
                        await ws.send_json({"type": "telemetry", "payload": payload})
                    except Exception:
                        break

            def on_event(event: Event):
                if websocket in manager.active_connections:
                    try:
                        asyncio.create_task(
                            websocket.send_json({"type": "event", "payload": event.to_json()})
                        )
                    except Exception:
                        pass

            actions.event_bus.subscribe("git.state_changed", on_event)
            actions.event_bus.subscribe("vscode.state_changed", on_event)
            actions.event_bus.subscribe("docker.state_changed", on_event)
            actions.event_bus.subscribe("context.changed", on_event)

            telemetry_task = asyncio.create_task(telemetry_loop(websocket))
            if not hasattr(app.state, "monitor_task") or app.state.monitor_task.done():
                app.state.monitor_task = asyncio.create_task(monitor.monitor_loop(interval=10.0))

            while True:
                data = await websocket.receive_json()
                if not isinstance(data, dict):
                    continue
                message_type = data.get("type")

                if message_type == "ping":
                    await websocket.send_json({
                        "type": "pong",
                        "t": data.get("t"),
                    })
                    continue

                if message_type == "action":
                    action_id = data.get("action_id")
                    request_id = data.get("request_id")
                    payload = data.get("payload") or {}

                    if not action_id:
                        await websocket.send_json({
                            "type": "action_result",
                            "request_id": request_id,
                            "action_id": "",
                            "result": {
                                "ok": False,
                                "error": "action_id_required",
                            },
                        })
                        continue

                    logging.info(
                        "received action from client: %s payload=%s",
                        action_id,
                        payload,
                    )

                    # Offloaded so slow subprocess actions (docker, git,
                    # playerctl) don't block the event loop / other clients.
                    result = await asyncio.to_thread(actions.execute, action_id, payload)

                    logging.info(
                        "action result: %s",
                        result,
                    )

                    await websocket.send_json({
                        "type": "action_result",
                        "request_id": request_id,
                        "action_id": action_id,
                        "result": result,
                    })

                    # Push a fresh snapshot right after state-changing actions so
                    # the phone reflects the result immediately (no manual refresh).
                    if _is_state_changing_action(action_id):
                        payload = await asyncio.to_thread(snapshot_state)
                        await manager.broadcast_json(
                            {"type": "telemetry", "payload": payload}
                        )

        except WebSocketDisconnect:
            logging.info("WebSocket disconnected")
        finally:
            if telemetry_task:
                telemetry_task.cancel()
            manager.disconnect(websocket)

    except asyncio.TimeoutError:
        await websocket.send_json({"type": "error", "message": "auth_timeout"})
        await websocket.close(code=4001)
    except Exception as exc:
        logging.exception("websocket error")
        try:
            await websocket.send_json({"type": "error", "message": str(exc)})
        except Exception:
            pass
        manager.disconnect(websocket)


admin = FastAPI()


@admin.get("/pair/pending")
async def admin_pending():
    pending = config._data.get("pending_pairings", [])
    devices = config.list_devices()
    items = []
    for p in pending:
        pending_id = p.get("pending_id", "")
        label = p.get("label", "")
        device_id = p.get("device_id", "")
        created_at = p.get("created_at", "")
        items.append(
            f"<li><strong>{label}</strong> ({device_id})"
            f"<div style=\"font-size:11px;color:#666;margin-bottom:6px;\">Created: {created_at}</div>"
            f'<form method="POST" action="/admin/pair/approve" style="display:inline;margin-right:6px;">'
            f'<input type="hidden" name="pending_id" value="{pending_id}" />'
            f'<button type="submit" class="approve">Approve</button></form>'
            f'<form method="POST" action="/admin/pair/reject" style="display:inline;">'
            f'<input type="hidden" name="pending_id" value="{pending_id}" />'
            f'<button type="submit" class="reject">Reject</button></form></li>'
        )
    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" />
<title>Tact Pairing Approvals</title>
<meta http-equiv=\"refresh\" content=\"5\" />
<style>
body {{ font-family: sans-serif; background:#f5f5f5; color:#333; padding:24px; }}
.card {{ background:#fff; padding:16px; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,0.1); max-width: 480px; margin: 0 auto; }}
h1 {{ font-size: 18px; margin-bottom: 12px; }}
.approve {{ background:#28a745; color:#fff; border:none; padding:8px 12px; border-radius:4px; cursor:pointer; font-size: 12px; }}
.reject {{ background:#dc3545; color:#fff; border:none; padding:8px 12px; border-radius:4px; cursor:pointer; font-size: 12px; }}
.refresh {{ background:#2d2d2d; color:#fff; border:none; padding:8px 12px; border-radius:4px; cursor:pointer; font-size: 12px; text-decoration:none; display:inline-block; margin-left: 8px; }}
</style>
</head>
<body>
<div class=\"card\">
<h1>Pending Pairing Requests <a href=\"/admin/pair/pending\" class=\"refresh\">Refresh Now</a></h1>
<ul>
{''.join(items) if items else '<li>No pending requests</li>'}
</ul>
<p><strong>Paired devices:</strong> {len(devices)}</p>
<p><a href=\"/\">Back to agent home</a></p>
</div>
</body>
</html>"""
    return HTMLResponse(content=html, headers={"Cache-Control": "no-cache, no-store, must-revalidate"})


async def _admin_approve(pending_id: str):
    if not pending_id:
        raise HTTPException(status_code=400, detail="pending_id required")
    device = config.approve_pending_pairing(pending_id)
    if device is None:
        raise HTTPException(status_code=404, detail="pending_not_found_or_expired")
    _logger.info("Pairing approved for %s (%s)", device.label, device.device_id)
    return HTMLResponse(content=f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Pairing Approved</title>
<style>
body {{ font-family: sans-serif; background:#f5f5f5; color:#333; padding:24px; }}
.card {{ background:#fff; padding:16px; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,0.1); max-width: 480px; margin: 0 auto; }}
a {{ color:#2d2d2d; }}
</style>
</head>
<body>
<div class="card">
<h1>Pairing Approved</h1>
<p>Device <strong>{device.label}</strong> ({device.device_id}) is now paired.</p>
<p><a href="/">Back to agent home</a></p>
</div>
</body>
</html>""")


async def _admin_reject(pending_id: str):
    if not pending_id:
        raise HTTPException(status_code=400, detail="pending_id required")
    pendings = config._data.get("pending_pairings", [])
    new_pendings = [p for p in pendings if p.get("pending_id") != pending_id]
    if len(new_pendings) == len(pendings):
        raise HTTPException(status_code=404, detail="pending_not_found")
    config._data["pending_pairings"] = new_pendings
    config._save()
    return HTMLResponse(content="""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Pairing Rejected</title>
<style>
body {{ font-family: sans-serif; background:#f5f5f5; color:#333; padding:24px; }}
.card {{ background:#fff; padding:16px; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,0.1); max-width: 480px; margin: 0 auto; }}
a {{ color:#2d2d2d; }}
</style>
</head>
<body>
<div class="card">
<h1>Pairing Rejected</h1>
<p>The request has been rejected.</p>
<p><a href="/">Back to agent home</a></p>
</div>
</body>
</html>""")


@admin.get("/pair/approve")
async def admin_approve_get(id: str = ""):
    return await _admin_approve(id)


@admin.post("/pair/approve")
async def admin_approve_post(pending_id: Optional[str] = Form(None), id: Optional[str] = Form(None)):
    pid = pending_id or id or ""
    return await _admin_approve(pid)


@admin.get("/pair/reject")
async def admin_reject_get(id: str = ""):
    return await _admin_reject(id)


@admin.post("/pair/reject")
async def admin_reject_post(pending_id: Optional[str] = Form(None), id: Optional[str] = Form(None)):
    pid = pending_id or id or ""
    return await _admin_reject(pid)


app.mount("/admin", admin)
