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
from pathlib import Path
from typing import Any, Optional

from ..base import Integration, payload_str
from .apps import classify, map_app
from .detection import active_window
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

    # -- actions ----------------------------------------------------------

    def actions(self) -> dict[str, Any]:
        return {
            "status": lambda p: self.detect(),
            "override": lambda p: self.set_override(
                payload_str(p, "app"), payload_str(p, "project")
            ),
            "clear_override": lambda p: self.clear_override(),
        }

    def snapshot(self) -> dict[str, Any]:
        return self.detect()

    # -- detection --------------------------------------------------------

    def detect(self) -> dict[str, Any]:
        window = active_window()
        if window is None and not self._override:
            return {
                "available": False,
                "error": "window_detection_unavailable",
                "workflow": None,
                "active_app": None,
                "project": None,
                "branch": None,
            }

        app_raw = window.get("class") if window else None
        app = map_app(app_raw) if app_raw else None
        title = window.get("title") if window else ""

        if self._override.get("app"):
            app = self._override["app"]
        project = self._override.get("project") or self._resolve_project(app, title)

        return {
            "available": window is not None or bool(self._override),
            "active_app": app,
            "active_app_raw": app_raw,
            "window_title": title,
            "project": project,
            "branch": self._project_branch(project),
            "workflow": classify(app),
            "override": dict(self._override) or None,
        }

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