from __future__ import annotations

import os
import shutil
import subprocess
import sys
import webbrowser
from pathlib import Path
from typing import Any, Optional

from ..base import Integration, payload_str

try:
    import psutil
except ImportError:  # pragma: no cover
    psutil = None


class SystemIntegration(Integration):
    """Platform-aware system actions with OS isolation."""

    name = "system"

    def actions(self) -> dict[str, Any]:
        return {
            "open_url": lambda p: self.open_url(payload_str(p, "url")),
            "open_terminal": lambda p: self.open_terminal(payload_str(p, "path")),
            "open_project": lambda p: self.open_project(payload_str(p, "path")),
            "volume": lambda p: self.volume(payload_str(p, "value")),
            "volume_up": lambda p: self.volume_up(),
            "volume_down": lambda p: self.volume_down(),
            "mute": lambda p: self.mute(),
            "lock_screen": lambda p: self.lock_screen(),
            "screenshot": lambda p: self.screenshot(),
            "battery": lambda p: self.battery(),
        }

    def snapshot(self) -> dict[str, Any]:
        """CPU / memory / disk / volume / battery for the phone."""
        try:
            cpu = psutil.cpu_percent(interval=None) if psutil else None
        except Exception:
            cpu = None
        try:
            memory = psutil.virtual_memory().percent if psutil else None
        except Exception:
            memory = None
        try:
            disk = (
                psutil.disk_usage(str(Path.cwd())).percent
                if psutil and Path.cwd().exists()
                else None
            )
        except Exception:
            disk = None
        volume = self.volume().get("volume") if self.volume().get("ok") else None
        return {
            "cpu": cpu,
            "memory": memory,
            "disk": disk,
            "volume": volume,
            "battery": self.battery(),
        }

    def open_url(self, url: str) -> dict[str, Any]:
        """Open a URL in the default browser."""
        if not url or not url.startswith(("http://", "https://")):
            return {"ok": False, "error": "invalid_url"}
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
            if shutil.which("gio"):
                try:
                    subprocess.Popen(
                        ["gio", "open", url],
                        stdout=devnull,
                        stderr=devnull,
                        env=env,
                        start_new_session=True,
                    )
                    return {"opened": url, "method": "gio"}
                except Exception:
                    pass

        # Last resort: Python's webbrowser (may use kde-open internally).
        try:
            opened = webbrowser.open(url)
            return {"opened": url, "method": "webbrowser", "reported": bool(opened)}
        except Exception:
            pass
        return {"opened": url, "method": "none"}

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

    def volume(self, value: Optional[int] = None) -> dict[str, Any]:
        """Get the current system volume (0..100), or set it when `value` given."""
        if value is not None:
            pct = max(0, min(100, int(value)))
            result = self._run_platform_command(
                linux=["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{pct}%"],
            )
            if not result.get("ok"):
                return result
        if not shutil.which("pactl"):
            return {"ok": False, "error": "pactl_not_found"}
        try:
            completed = subprocess.run(
                ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
                capture_output=True,
                text=True,
                check=False,
            )
        except OSError:
            return {"ok": False, "error": "pactl_failed"}
        if completed.returncode != 0:
            return {"ok": False, "error": "pactl_failed"}
        # Output looks like: "Volume: front-left: 52404 /  80% / -5.83 dB, ..."
        for token in completed.stdout.split():
            if token.endswith("%"):
                try:
                    return {"ok": True, "volume": int(token[:-1])}
                except ValueError:
                    pass
        return {"ok": False, "error": "unable_to_parse_volume"}

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
        if sys.platform.startswith("linux"):
            # Prefer KDE-native screenshot via KWin DBus to avoid spectacle DBus collisions.
            if shutil.which("qdbus"):
                try:
                    subprocess.run(
                        [
                            "qdbus",
                            "org.kde.kwin",
                            "/KWin",
                            "org.kde.kwin.screenshot",
                            "/tmp/tact-screenshot.png",
                        ],
                        check=True,
                        capture_output=True,
                    )
                    return {"ok": True, "command": "kwin", "path": "/tmp/tact-screenshot.png"}
                except Exception:
                    pass

            kde = ["spectacle", "-b", "-f", "/tmp/tact-screenshot.png"]
            if shutil.which("spectacle"):
                return self._run_platform_command(linux=kde)
            gnome = ["gnome-screenshot", "-f", "/tmp/tact-screenshot.png"]
            if shutil.which("gnome-screenshot"):
                return self._run_platform_command(linux=gnome)
            return {"ok": False, "error": "no_screenshot_tool_found"}
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

    def battery(self) -> dict[str, Any]:
        """Battery level (0..100), charging state, and power plugged in."""
        if psutil is None:
            return {"ok": False, "error": "psutil_not_available"}
        try:
            battery = psutil.sensors_battery()
        except (AttributeError, OSError):
            return {"ok": False, "error": "battery_not_supported"}
        if battery is None:
            return {"ok": False, "error": "no_battery_found"}
        return {
            "ok": True,
            "percent": round(battery.percent, 1),
            "charging": bool(battery.power_plugged),
            "secs_left": battery.secsleft if battery.secsleft != -1 else None,
        }

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
