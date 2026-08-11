from pydantic import BaseModel, HttpUrl, ValidationError
import webbrowser
import logging
import subprocess
import sys
import os
import shutil

from .integrations.git import GitIntegration
from .integrations.vscode import VSCodeIntegration
from .integrations.system import SystemIntegration
from .events import EventBus


class OpenUrlPayload(BaseModel):
    url: HttpUrl


class ActionRegistry:
    """Simple allowlisted action registry."""

    def __init__(self):
        self.git = GitIntegration()
        self.vscode = VSCodeIntegration()
        self.system = SystemIntegration()
        self.event_bus = EventBus()
        self._registry = {
            "system.open_url": self._open_url,
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
            "git._switch_branch": self._git_switch_branch,
            "git.pull": self._git_pull,
            "git.push": self._git_push,
            "git.commit": self._git_commit,
        }

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
        path = payload.get("path") if isinstance(payload, dict) else None
        return self.git.status(path)

    def _git_branches(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        return self.git.branches(path)

    def _git_tree(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        max_depth = int(payload.get("max_depth") or 3) if isinstance(payload, dict) else 3
        return self.git.tree(path, max_depth=max_depth)

    def _vscode_workspaces(self, payload: dict):
        return self.vscode.workspaces()

    def _git_pull(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        branch = payload.get("branch") if isinstance(payload, dict) else None
        args = ["pull", "--ff-only"]
        if branch:
            args.append(branch)
        return self.git._run_git_action(path, args)

    def _git_push(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
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
        path = payload.get("path") if isinstance(payload, dict) else None
        return self.git._run_git_action(path, ["checkout", branch])

    def _git_commit(self, payload: dict):
        message = str(payload.get("message") or "") if isinstance(payload, dict) else ""
        if not message.strip():
            return {"ok": False, "error": "commit_message_required"}
        path = payload.get("path") if isinstance(payload, dict) else None
        if not self.git.is_dirty(path):
            return {"ok": False, "error": "nothing_to_commit", "message": "working directory is clean"}
        return self.git.commit(message, path)

    def _volume_up(self, payload: dict):
        return self.system.volume_up()

    def _volume_down(self, payload: dict):
        return self.system.volume_down()

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
