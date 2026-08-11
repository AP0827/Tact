from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional


class SystemIntegration:
    """Platform-aware system actions with OS isolation."""

    def _xdg_open(self, target: str) -> dict[str, Any]:
        if sys.platform.startswith("linux"):
            env = dict(os.environ)
            try:
                uid = str(os.getuid())
                fallback = f"/run/user/{uid}"
                if "XDG_RUNTIME_DIR" not in env and os.path.isdir(fallback):
                    env["XDG_RUNTIME_DIR"] = fallback
            except Exception:
                pass

            devnull = subprocess.DEVNULL
            if shutil.which("xdg-open"):
                try:
                    subprocess.Popen(
                        ["xdg-open", target],
                        stdout=devnull,
                        stderr=devnull,
                        env=env,
                        start_new_session=True,
                    )
                    return {"opened": target, "method": "xdg-open"}
                except Exception:
                    pass
            if shutil.which("gio"):
                try:
                    subprocess.Popen(
                        ["gio", "open", target],
                        stdout=devnull,
                        stderr=devnull,
                        env=env,
                        start_new_session=True,
                    )
                    return {"opened": target, "method": "gio"}
                except Exception:
                    pass

        if sys.platform == "darwin":
            try:
                subprocess.Popen(["open", target], start_new_session=True)
                return {"opened": target, "method": "open"}
            except Exception:
                pass

        if sys.platform == "win32":
            try:
                os.startfile(target)  # type: ignore[attr-defined]
                return {"opened": target, "method": "os.startfile"}
            except Exception:
                pass

        return {"opened": target, "method": "none"}

    def open_terminal(self, path: Optional[str] = None) -> dict[str, Any]:
        candidates: list[list[str]] = []
        if sys.platform.startswith("linux"):
            candidates = [
                ["gnome-terminal", "--working-directory", path or os.getcwd()],
                ["konsole", "--workdir", path or os.getcwd()],
                ["xfce4-terminal", "--working-directory", path or os.getcwd()],
                ["xterm", "-e", "bash", "-c", f"cd {shlex.quote(path or os.getcwd())}; exec bash"],
                ["kitty", "--directory", path or os.getcwd()],
                ["alacritty", "--working-directory", path or os.getcwd()],
            ]
        elif sys.platform == "darwin":
            candidates = [["open", "-a", "Terminal", path or os.getcwd()]]
        elif sys.platform == "win32":
            candidates = [["start", "cmd.exe"], ["wt"], ["powershell"]]

        for cmd in candidates:
            if shutil.which(cmd[0]):
                try:
                    subprocess.Popen(cmd, start_new_session=True)
                    return {"opened": "terminal", "command": cmd[0], "method": "subprocess"}
                except Exception:
                    continue
        return {"opened": "terminal", "method": "none", "error": "no_terminal_found"}

    def volume_up(self) -> dict[str, Any]:
        return self._run_platform_command(
            linux=["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"],
            darwin=["osascript", "-e", 'set volume output volume ((output volume of (get volume settings)) + 5)'],
            win32=["powershell", "-Command", "$v = (Get-ComputerInfo).OsName; ..."],
        )

    def volume_down(self) -> dict[str, Any]:
        return self._run_platform_command(
            linux=["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"],
            darwin=["osascript", "-e", 'set volume output volume ((output volume of (get volume settings)) - 5)'],
        )

    def mute(self) -> dict[str, Any]:
        return self._run_platform_command(
            linux=["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"],
            darwin=["osascript", "-e", 'set volume with output muted'],
        )

    def lock_screen(self) -> dict[str, Any]:
        return self._run_platform_command(
            linux=["loginctl", "lock-session"],
            darwin=["pmset", "displaysleepnow"],
            win32=["rundll32.exe", "user32.dll,LockWorkStation"],
        )

    def screenshot(self) -> dict[str, Any]:
        return self._run_platform_command(
            linux=["gnome-screenshot", "-f", "/tmp/tact-screenshot.png"],
            darwin=["screencapture", "-x", "/tmp/tact-screenshot.png"],
        )

    def open_project(self, path: Optional[str] = None) -> dict[str, Any]:
        target = Path(path or os.getcwd()).resolve()
        if not target.is_dir():
            return {"opened": str(target), "ok": False, "error": "not_a_directory"}
        file_manager = "xdg-open" if sys.platform.startswith("linux") else (
            "open" if sys.platform == "darwin" else "explorer"
        )
        if not shutil.which(file_manager):
            return {"opened": str(target), "ok": False, "error": "file_manager_not_found"}
        try:
            subprocess.Popen([file_manager, str(target)], start_new_session=True)
            return {"opened": str(target), "method": file_manager}
        except Exception as exc:
            return {"opened": str(target), "ok": False, "error": str(exc)}

    def _run_platform_command(
        self,
        linux: list[str],
        darwin: Optional[list[str]] = None,
        win32: Optional[list[str]] = None,
    ) -> dict[str, Any]:
        cmd = None
        if sys.platform.startswith("linux"):
            cmd = linux
        elif sys.platform == "darwin" and darwin:
            cmd = darwin
        elif sys.platform == "win32" and win32:
            cmd = win32

        if not cmd or not shutil.which(cmd[0]):
            return {"ok": False, "error": "unsupported_platform_or_command_missing"}

        try:
            subprocess.Popen(cmd, start_new_session=True)
            return {"ok": True, "command": cmd[0]}
        except Exception as exc:
            return {"ok": False, "error": str(exc)}


import shlex
