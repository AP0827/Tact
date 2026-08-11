from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Any, Optional


class VSCodeIntegration:
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

    def workspaces(self) -> dict[str, Any]:
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
                    for arg in cmdline:
                        if arg.startswith("-") or arg in names:
                            continue
                        p = Path(arg)
                        if p.is_dir() and str(p) not in seen:
                            seen.add(str(p))
                            workspaces.append(str(p))
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
        except Exception:
            pass
        return {
            "available": self.is_available(),
            "running": self.is_running(),
            "workspaces": workspaces,
            "count": len(workspaces),
        }

    def _which(self, command: str) -> Optional[str]:
        from shutil import which

        return which(command)
