"""Project workspace (Phase 3.10).

`project.open` is a composite: open the project in VS Code, drop a terminal
at the project path, and open the folder in the file manager — one tap from
the phone starts a full working environment. `project.resources` lists the
per-project buttons (repo/workspace/terminal/browser/folder) that the phone
renders for the active project.
"""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional

from ..base import Integration, payload_str

_RESOURCES = [
    {"id": "repo", "label": "Repo", "url": "https://"},
    {"id": "workspace", "label": "Workspace"},
    {"id": "terminal", "label": "Terminal"},
    {"id": "browser", "label": "Browser"},
    {"id": "folder", "label": "Folder"},
]


class ProjectIntegration(Integration):
    """Composite project-environment launcher + resource listing."""

    name = "project"

    def actions(self) -> dict[str, Any]:
        return {
            "open": lambda p: self.open(payload_str(p, "path")),
            "resources": lambda p: self.resources(payload_str(p, "path")),
        }

    def snapshot(self) -> dict[str, Any]:
        return {"resources": _RESOURCES}

    def _open_terminal_at(self, path: str) -> bool:
        candidates: list[list[str]] = []
        if sys.platform.startswith("linux"):
            candidates = [
                ["gnome-terminal", "--working-directory", path],
                ["konsole", "--workdir", path],
                ["xfce4-terminal", "--working-directory", path],
                ["xterm", "-e", "bash", "-c", f"cd {shlex.quote(path)}; exec bash"],
                ["kitty", "--directory", path],
            ]
        elif sys.platform == "darwin":
            candidates = [["open", "-a", "Terminal", path]]
        else:
            return False
        for cmd in candidates:
            if shutil.which(cmd[0]):
                try:
                    subprocess.Popen(cmd, start_new_session=True)
                    return True
                except OSError:
                    continue
        return False

    def _open_folder(self, path: str) -> bool:
        file_manager = (
            "xdg-open" if sys.platform.startswith("linux") else
            ("open" if sys.platform == "darwin" else "explorer")
        )
        if not shutil.which(file_manager):
            return False
        try:
            subprocess.Popen([file_manager, path], start_new_session=True)
            return True
        except OSError:
            return False

    def open(self, path: Optional[str]) -> dict[str, Any]:
        """Open a full working environment for a project folder."""
        if not path:
            return {"ok": False, "error": "path_required"}
        target = str(Path(path).expanduser().resolve())
        if not Path(target).is_dir():
            return {"ok": False, "error": "not_a_directory"}
        opened: dict[str, bool] = {}
        if shutil.which("code"):
            try:
                subprocess.Popen(
                    ["code", target],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                opened["vscode"] = True
            except OSError:
                opened["vscode"] = False
        else:
            opened["vscode"] = False
        opened["terminal"] = self._open_terminal_at(target)
        opened["folder"] = self._open_folder(target)
        return {"ok": True, "path": target, "opened": opened}

    def resources(self, path: Optional[str]) -> dict[str, Any]:
        """Per-project resource buttons for the phone."""
        target = str(Path(path or os.getcwd()).expanduser().resolve())
        repo_url = ""
        try:
            git = subprocess.run(
                ["git", "-C", target, "remote", "get-url", "origin"],
                capture_output=True,
                text=True,
                check=False,
                timeout=3,
            )
            if git.returncode == 0:
                url = git.stdout.strip()
                if url.startswith("git@"):
                    url = url.replace(":", "/").replace("git@", "https://")
                    url = url.removesuffix(".git")
                repo_url = url
        except (OSError, subprocess.TimeoutExpired):
            pass
        resources = []
        for res in _RESOURCES:
            item = dict(res)
            if res["id"] == "repo" and repo_url:
                item["url"] = repo_url
            resources.append(item)
        return {"ok": True, "path": target, "resources": resources}