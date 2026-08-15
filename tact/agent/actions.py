from pydantic import BaseModel, HttpUrl, ValidationError
import webbrowser
import logging
import subprocess
import sys
import os
import shutil
from pathlib import Path

from .integrations.git import GitIntegration
from .integrations.vscode import VSCodeIntegration
from .integrations.system import SystemIntegration
from .integrations.media import MediaIntegration
from .events import EventBus


class OpenUrlPayload(BaseModel):
    url: HttpUrl


class ActionRegistry:
    """Simple allowlisted action registry."""

    def __init__(self, current_workspace_path=None):
        self.git = GitIntegration()
        self.vscode = VSCodeIntegration()
        self.system = SystemIntegration()
        self.media = MediaIntegration()
        self.event_bus = EventBus()
        self._current_workspace_path = current_workspace_path
        self._registry = {
            "system.open_url": self._open_url,
            "system.set_workspace": self._set_workspace,
            "system.volume": self._system_volume,
            "system.volume_up": self._volume_up,
            "system.volume_down": self._volume_down,
            "system.mute": self._mute,
            "system.lock_screen": self._lock_screen,
            "system.screenshot": self._screenshot,
            "system.open_terminal": self._open_terminal,
            "system.open_project": self._open_project,
            "vscode.open_workspace": self._open_workspace,
            "vscode.status": self._vscode_status,
            "vscode.workspaces": self._vscode_workspaces,
            "git.status": self._git_status,
            "git.branches": self._git_branches,
            "git.tree": self._git_tree,
            "git.log": self._git_log,
            "git.add": self._git_add,
            "git._switch_branch": self._git_switch_branch,
            "git.pull": self._git_pull,
            "git.push": self._git_push,
            "git.commit": self._git_commit,
            "media.status": self._media_status,
            "media.play_pause": self._media_play_pause,
            "media.next": self._media_next,
            "media.previous": self._media_previous,
            "media.volume": self._media_volume,
            "media.seek": self._media_seek,
            "media.open_spotify": self._media_open_spotify,
        }

    def set_current_workspace_path(self, path: str):
        self._current_workspace_path = path

    def _resolve_path(self, payload: dict) -> str | None:
        path = payload.get("path") if isinstance(payload, dict) else None
        if path:
            return path
        if self._current_workspace_path:
            return self._current_workspace_path
        return None

    def execute(self, action_id: str, payload: dict):
        handler = self._registry.get(action_id)
        if not handler:
            return {"ok": False, "error": "unknown_action"}
        try:
            result = handler(payload or {})
            logging.info("action executed: %s payload=%s result=%s", action_id, payload, result)
            return {"ok": True, "result": result}
        except ValidationError as e:
            return {"ok": False, "error": e.errors()}
        except Exception as e:
            logging.exception("action execution failed")
            return {"ok": False, "error": str(e)}

    def _set_workspace(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        if not path:
            return {"ok": False, "error": "path_required"}
        p = Path(path)
        if not p.is_dir():
            return {"ok": False, "error": "not_a_directory"}
        resolved = str(p.resolve())
        self.set_current_workspace_path(resolved)
        return {"ok": True, "workspace": resolved}

    def _open_url(self, payload: dict):
        p = OpenUrlPayload(**payload)
        url = str(p.url)
        # On Linux, prefer launching `gio open` (detached) to avoid invoking
        # KDE-specific helpers (kde-open) which may crash and affect our process.
        if sys.platform.startswith("linux"):
            try:
                env = dict(**os.environ)
                try:
                    uid = str(os.getuid())
                    fallback = f"/run/user/{uid}"
                    if "XDG_RUNTIME_DIR" not in env and os.path.isdir(fallback):
                        env["XDG_RUNTIME_DIR"] = fallback
                except Exception:
                    pass

                DEVNULL = subprocess.DEVNULL
                if shutil.which("gio"):
                    subprocess.Popen(["gio", "open", url], stdout=DEVNULL, stderr=DEVNULL, env=env, start_new_session=True)
                    return {"opened": url, "method": "gio"}
            except Exception:
                logging.exception("desktop opener failed to start")

        # As a last resort, use Python's webbrowser (may use kde-open internally).
        try:
            opened = webbrowser.open(url)
            return {"opened": url, "method": "webbrowser", "reported": bool(opened)}
        except Exception:
            logging.exception("webbrowser.open failed")

        return {"opened": url, "method": "none"}

    def _open_workspace(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        return self.vscode.open_workspace(path)

    def _vscode_status(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        return self.vscode.status(path)

    def _vscode_workspaces(self, payload: dict):
        return self.vscode.workspaces()

    def _git_status(self, payload: dict):
        path = self._resolve_path(payload)
        return self.git.status(path)

    def _git_branches(self, payload: dict):
        path = self._resolve_path(payload)
        return self.git.branches(path)

    def _git_tree(self, payload: dict):
        path = self._resolve_path(payload)
        max_depth = int(payload.get("max_depth") or 3) if isinstance(payload, dict) else 3
        return self.git.tree(path, max_depth=max_depth)

    def _git_log(self, payload: dict):
        path = self._resolve_path(payload)
        limit = int(payload.get("limit") or 40) if isinstance(payload, dict) else 40
        return self.git.log(path, limit=limit)

    def _git_add(self, payload: dict):
        path = self._resolve_path(payload)
        return self.git.add(path)

    def _git_pull(self, payload: dict):
        path = self._resolve_path(payload)
        branch = payload.get("branch") if isinstance(payload, dict) else None
        args = ["pull", "--ff-only"]
        if branch:
            args.append(branch)
        return self.git._run_git_action(path, args)

    def _git_push(self, payload: dict):
        path = self._resolve_path(payload)
        branch = payload.get("branch") if isinstance(payload, dict) else None
        args = ["push"]
        if branch:
            args.append("origin")
            args.append(branch)
        return self.git._run_git_action(path, args)

    def _git_switch_branch(self, payload: dict):
        branch = payload.get("branch") if isinstance(payload, dict) else None
        if not branch:
            return {"ok": False, "error": "branch_required"}
        path = self._resolve_path(payload)
        return self.git._run_git_action(path, ["checkout", branch])

    def _git_commit(self, payload: dict):
        message = str(payload.get("message") or "") if isinstance(payload, dict) else ""
        if not message.strip():
            return {"ok": False, "error": "commit_message_required"}
        path = self._resolve_path(payload)
        if not self.git.is_dirty(path):
            return {"ok": False, "error": "nothing_to_commit", "message": "working directory is clean"}
        return self.git.commit(message, path)

    def _volume_up(self, payload: dict):
        return self.system.volume_up()

    def _volume_down(self, payload: dict):
        return self.system.volume_down()

    def _system_volume(self, payload: dict):
        value = payload.get("value") if isinstance(payload, dict) else None
        return self.system.volume(value)

    def _mute(self, payload: dict):
        return self.system.mute()

    def _lock_screen(self, payload: dict):
        return self.system.lock_screen()

    def _screenshot(self, payload: dict):
        return self.system.screenshot()

    def _open_terminal(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        return self.system.open_terminal(path)

    def _open_project(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        return self.system.open_project(path)

    def _media_status(self, payload: dict):
        return self.media.status()

    def _media_play_pause(self, payload: dict):
        player = payload.get("player") if isinstance(payload, dict) else None
        return self.media.play_pause(player)

    def _media_next(self, payload: dict):
        player = payload.get("player") if isinstance(payload, dict) else None
        return self.media.next(player)

    def _media_previous(self, payload: dict):
        player = payload.get("player") if isinstance(payload, dict) else None
        return self.media.previous(player)

    def _media_volume(self, payload: dict):
        player = payload.get("player") if isinstance(payload, dict) else None
        value = payload.get("value") if isinstance(payload, dict) else None
        return self.media.volume(player, value)

    def _media_seek(self, payload: dict):
        player = payload.get("player") if isinstance(payload, dict) else None
        position = payload.get("position") if isinstance(payload, dict) else None
        return self.media.seek(player, position)

    def _media_open_spotify(self, payload: dict):
        result = self.media.open_spotify()
        if not result.get("ok") and result.get("fallback"):
            return self._open_url({"url": result["fallback"]})
        return result
