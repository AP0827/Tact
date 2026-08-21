"""Phase 2: Context Engine.

Detects what the developer is doing right now — active application, project
directory, git branch, and a workflow classification. This is the primary
input to the Tact Surface model (Context Surface / Workspace State / Control
Strip layers, Phase 3+).

File layout (folder-per-app separation):
  * ``apps.py``      — WM_CLASS -> app id map, app id -> workflow map
  * ``detection.py`` — X11 active-window detection (swap for Wayland later)
  * ``integration.py`` — this file: the ContextIntegration itself
"""

from __future__ import annotations

import json
import os
import re
import urllib.parse
from collections import deque
from pathlib import Path
from typing import Any, Optional

from ..base import Integration, payload_str
from .apps import classify, map_app
from .detection import active_window
from .surfaces import select_surface, surfaces_meta
from ..git import GitIntegration


class ContextIntegration(Integration):
    """Active-app / project / workflow detection for the Tact Surface."""

    name = "context"

    def __init__(self):
        # Set by ActionRegistry.set_current_workspace_path.
        self.workspace_path: str | None = None
        self._git = GitIntegration()
        self._override: dict[str, str] = {}
        self._last_key: tuple | None = None
        # Rolling app history for the launcher's "Recent" row (Phase 3.8).
        self._app_history: deque[str] = deque(maxlen=6)

    # -- actions ----------------------------------------------------------

    def actions(self) -> dict[str, Any]:
        return {
            "status": lambda p: self.detect(),
            "override": lambda p: self.set_override(
                payload_str(p, "app"), payload_str(p, "project")
            ),
            "clear_override": lambda p: self.clear_override(),
            "surfaces": lambda p: self.surfaces(),
            "surface": lambda p: self.surface(),
        }

    def snapshot(self) -> dict[str, Any]:
        return self.detect()

    # -- detection --------------------------------------------------------

    def detect(self) -> dict[str, Any]:
        window = active_window()
        available = window is not None or bool(self._override)
        if not available:
            return {
                "available": False,
                "error": "window_detection_unavailable",
                "workflow": None,
                "active_app": None,
                "project": None,
                "branch": None,
                "surface": select_surface(None, available=False),
                "surfaces": surfaces_meta(),
            }

        app_raw = window.get("class") if window else None
        app = map_app(app_raw) if app_raw else None
        title = window.get("title") if window else ""

        if self._override.get("app"):
            app = self._override["app"]
        if app:
            self._remember_app(app)
        project = self._override.get("project") or self._resolve_project(app, title)
        branch = self._project_branch(project)
        docker_running = self._docker_signal()

        return {
            "available": True,
            "active_app": app,
            "active_app_raw": app_raw,
            "window_title": title,
            "project": project,
            "branch": branch,
            "workflow": self._workflow(app, branch, docker_running),
            "signals": {
                "git_active": branch is not None,
                "docker_running": docker_running,
            },
            "override": dict(self._override) or None,
            "recent_apps": list(self._app_history),
            "surface": select_surface(app, available=True),
            "surfaces": surfaces_meta(),
        }

    def surfaces(self) -> dict[str, Any]:
        return {"ok": True, "surfaces": surfaces_meta()}

    def _remember_app(self, app: str) -> None:
        """Keep the most recent distinct apps (most-recent last)."""
        if app in self._app_history:
            self._app_history.remove(app)
        self._app_history.append(app)

    def surface(self) -> dict[str, Any]:
        return {"ok": True, "surface": self.detect().get("surface")}

    # -- workflow signal aggregation (Phase 2) ---------------------------

    def _workflow(
        self,
        app: Optional[str],
        branch: Optional[str],
        docker_running: bool,
    ) -> Optional[str]:
        """Workflow = active-app map first; unknown/neutral apps fall back
        to signal aggregation: an active git repo or running docker
        containers means development is happening."""
        base = classify(app)
        if base:
            return base
        if branch is not None or docker_running:
            return "development"
        return None

    def _docker_signal(self) -> bool:
        """True when docker has at least one running container. Uses the
        shared docker integration instance (wired by ActionRegistry) so the
        state monitor's view stays consistent."""
        docker = getattr(self, "_docker", None)
        if docker is None:
            return False
        try:
            state = docker.containers()
        except Exception:
            return False
        return bool(
            state.get("available")
            and any(c.get("state") == "running" for c in state.get("containers", []))
        )

    def set_override(self, app: Optional[str], project: Optional[str]) -> dict[str, Any]:
        if not app and not project:
            return {"ok": False, "error": "app_or_project_required"}
        if app:
            self._override["app"] = app
        if project:
            self._override["project"] = project
        return {"ok": True, "override": dict(self._override)}

    def clear_override(self) -> dict[str, Any]:
        self._override = {}
        return {"ok": True, "override": None}

    # -- monitor ----------------------------------------------------------

    def monitor(self, event_bus) -> None:
        """Emit `context.changed` when app/project/workflow change."""
        current = self.detect()
        if not current.get("available"):
            return
        key = (
            current.get("active_app"),
            current.get("project"),
            current.get("workflow"),
        )
        if key != self._last_key:
            if self._last_key is not None:
                event_bus.emit_simple(
                    "context.changed",
                    "context",
                    f"{current.get('active_app') or '?'} · "
                    f"{Path(current['project']).name if current.get('project') else '?'}",
                    current.get("workflow") or "unknown",
                    current,
                )
            self._last_key = key

    # -- project resolution -----------------------------------------------

    def _resolve_project(self, app: Optional[str], title: str) -> Optional[str]:
        if app == "terminal":
            path = self._path_from_title(title)
            if path:
                return path
        if app == "vscode":
            path = self._match_vscode_title(title)
            if path:
                return path
        return self.workspace_path

    def _path_from_title(self, title: str) -> Optional[str]:
        """Extract a real path from terminal titles like
        `user@host: ~/Projects/Tact — konsole`."""
        m = re.search(r"(?:^|[: ])(~?/[^\s:\u2014-]+)", title)
        if not m:
            return None
        raw = m.group(1)
        path = str(Path(raw).expanduser())
        if Path(path).is_dir():
            return path
        return None

    def _match_vscode_title(self, title: str) -> Optional[str]:
        """Match `file — Folder` titles against known VS Code workspaces."""
        m = re.search(r"[—\-–]\s*([^—\-–]+?)\s*$", title)
        if not m:
            return None
        folder = m.group(1).strip().strip("[]")
        # VS Code's own workspaceStorage — same source as VSCodeIntegration.
        config = Path.home() / ".config" / "Code" / "User" / "workspaceStorage"
        try:
            if config.is_dir():
                for child in config.iterdir():
                    ws = child / "workspace.json"
                    if not ws.is_file():
                        continue
                    try:
                        data = json.loads(ws.read_text(encoding="utf-8"))
                    except (OSError, json.JSONDecodeError):
                        continue
                    uri = data.get("folder") or data.get("workspace")
                    if not uri or not str(uri).startswith("file://"):
                        continue
                    path = Path(urllib.parse.unquote(str(uri)[len("file://"):]))
                    if path.name == folder and path.is_dir():
                        return str(path)
        except OSError:
            pass
        return None

    def _project_branch(self, project: Optional[str]) -> Optional[str]:
        if not project:
            return None
        root = self._git.discover_root(project)
        if root is None:
            return None
        status = self._git.status(root)
        return status.get("branch") if status.get("available") else None