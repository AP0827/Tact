from __future__ import annotations

import json
import os
import subprocess
import urllib.parse
from pathlib import Path
from typing import Any, Optional

from ..base import Integration, payload_str


class VSCodeIntegration(Integration):
    name = "vscode"

    def __init__(self, config_dir: Optional[Path] = None):
        self._config_dir_override = config_dir

    def actions(self) -> dict[str, Any]:
        return {
            "open_workspace": lambda p: self.open_workspace(payload_str(p, "path")),
            "status": lambda p: self.status(payload_str(p, "path")),
            "workspaces": lambda p: self.workspaces(),
        }

    def snapshot(self) -> dict[str, Any]:
        workspaces = self.workspaces()
        return {
            "available": workspaces.get("available", False),
            "running": workspaces.get("running", False),
            "command": self.resolve_command(),
            "workspaces": workspaces.get("workspaces", []),
            "count": workspaces.get("count", 0),
        }

    def monitor(self, event_bus) -> None:
        """Emit `vscode.state_changed` when running state changes."""
        current = {
            "running": self.is_running(),
            "available": self.is_available(),
        }
        if current != self._last_state:
            if self._last_state is not None:
                event_bus.emit_simple(
                    "vscode.state_changed",
                    "vscode",
                    "VS Code",
                    "running" if current["running"] else "stopped",
                    current,
                )
            self._last_state = current

    _last_state: dict | None = None

    def resolve_command(self) -> Optional[str]:
        for candidate in ("code", "code-insiders", "codium"):
            if self._which(candidate):
                return candidate
        return None

    def is_available(self) -> bool:
        return self.resolve_command() is not None

    def is_running(self) -> bool:
        names = {"code", "code-insiders", "codium"}
        try:
            import psutil

            for proc in psutil.process_iter(["name", "cmdline"]):
                name = (proc.info.get("name") or "").lower()
                if any(candidate in name for candidate in names):
                    return True
                cmdline = " ".join(proc.info.get("cmdline") or []).lower()
                if any(candidate in cmdline for candidate in names):
                    return True
        except Exception:
            return False
        return False

    def open_workspace(self, path: str | Path | None = None) -> dict[str, Any]:
        workspace_path = Path(path or os.getcwd()).resolve()
        command = self.resolve_command()
        if command is None:
            return {"ok": False, "error": "vscode_not_available", "path": str(workspace_path)}

        try:
            subprocess.Popen([command, str(workspace_path)], start_new_session=True)
            return {"ok": True, "path": str(workspace_path), "command": command}
        except Exception as exc:
            return {"ok": False, "error": str(exc), "path": str(workspace_path), "command": command}

    def status(self, path: str | Path | None = None) -> dict[str, Any]:
        workspace_path = Path(path or os.getcwd()).resolve()
        return {
            "available": self.is_available(),
            "running": self.is_running(),
            "command": self.resolve_command(),
            "workspace": str(workspace_path),
        }

    def config_dir(self) -> Optional[Path]:
        """VS Code user data dir (where workspaceStorage lives)."""
        if self._config_dir_override is not None:
            return self._config_dir_override

        command = self.resolve_command()
        if command == "code-insiders":
            name = "Code - Insiders"
        elif command == "codium":
            name = "VSCodium"
        else:
            name = "Code"

        if os.name == "nt":
            base = Path(os.environ.get("APPDATA", Path.home()))
            return base / name
        if sys_platform() == "darwin":
            return Path.home() / "Library" / "Application Support" / name
        return Path.home() / ".config" / name

    def workspaces(self) -> dict[str, Any]:
        """Detect VS Code workspaces.

        Authoritative source: VS Code's own workspaceStorage. VS Code writes
        one `<hash>/workspace.json` per opened window, each containing the
        folder/workspace URI, and touches the directory whenever that window
        is active. The most recently touched entry is the currently-open
        workspace — far more reliable than scraping process cmdlines (which
        are full of extension/language-server helper args).
        """
        workspaces = self._from_workspace_storage()

        if not workspaces:
            workspaces = self._from_processes()

        return {
            "available": self.is_available(),
            "running": self.is_running(),
            "workspaces": workspaces,
            "count": len(workspaces),
        }

    def _from_workspace_storage(self) -> list[str]:
        config = self.config_dir()
        storage = config / "User" / "workspaceStorage" if config else None
        if storage is None or not storage.is_dir():
            return []

        entries: list[tuple[float, str]] = []
        try:
            for child in storage.iterdir():
                ws_file = child / "workspace.json"
                if not ws_file.is_file():
                    continue
                try:
                    data = json.loads(ws_file.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError):
                    continue
                if not isinstance(data, dict):
                    continue
                uri = data.get("folder") or data.get("workspace")
                if not uri:
                    continue
                path = self._uri_to_path(str(uri))
                if path is None or not path.is_dir():
                    continue
                if not self._is_project_dir(path):
                    continue
                try:
                    mtime = child.stat().st_mtime
                except OSError:
                    mtime = 0
                entries.append((mtime, str(path)))
        except OSError:
            return []

        entries.sort(key=lambda e: e[0], reverse=True)
        return [path for _, path in entries]

    @staticmethod
    def _uri_to_path(uri: str) -> Optional[Path]:
        if not uri:
            return None
        path = uri
        if path.startswith("file://"):
            path = path[len("file://"):]
        path = urllib.parse.unquote(path)
        if not path:
            return None
        return Path(path)

    @staticmethod
    def _is_project_dir(path: Path) -> bool:
        s = str(path)
        if s in ("/", ""):
            return False
        # VS Code's own install / bundled extension dirs.
        if (
            "/usr/share/code/" in s
            or "/resources/app/extensions" in s
            or "/.vscode/extensions" in s
        ):
            return False
        # Language-server caches (e.g. ~/.cache/typescript/6.0) are not
        # developer projects.
        if "/.cache/" in s:
            return False
        return True

    def _from_processes(self) -> list[str]:
        """Fallback: scrape the main VS Code window process only."""
        names = {"code", "code-insiders", "codium"}
        workspaces: list[str] = []
        try:
            import psutil

            seen = set()
            for proc in psutil.process_iter(["pid", "name", "cmdline"]):
                try:
                    name = (proc.info.get("name") or "").lower()
                    cmdline = proc.info.get("cmdline") or []
                    if not any(candidate in name for candidate in names):
                        continue
                    joined = " ".join(cmdline)
                    # Skip helper/child processes (zygote, gpu, renderer,
                    # utility/language-servers). Only the main window process
                    # carries a workspace folder argument.
                    if "--type=" in joined or "/proc/self/exe" in joined:
                        continue
                    for arg in cmdline[1:]:
                        if arg.startswith("-") or arg in names:
                            continue
                        if arg.startswith("file://"):
                            arg = arg[len("file://"):]
                        if arg.startswith("--folder-uri="):
                            arg = arg[len("--folder-uri="):]
                            if arg.startswith("file://"):
                                arg = arg[len("file://"):]
                        p = Path(arg)
                        if p.is_dir() and str(p) not in seen:
                            seen.add(str(p))
                            workspaces.append(str(p))
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
        except Exception:
            pass

        filtered = [p for p in workspaces if Path(p).is_dir()]
        if not filtered:
            fallback = str(Path.cwd())
            if Path(fallback).is_dir():
                filtered.append(fallback)
        return filtered

    def _which(self, command: str) -> Optional[str]:
        from shutil import which

        return which(command)


def sys_platform() -> str:
    import sys

    return sys.platform