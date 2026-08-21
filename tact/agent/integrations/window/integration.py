"""Window & workspace controls (Phase 3.9).

wmctrl-driven: list/focus/move/minimize/maximize/close windows and apply
static workspace layout presets (Coding / Meeting / Media). Presets are an
allowlist of (app → target desktop + geometry) applied with `wmctrl -r -e`;
safe on EWMH-compliant window managers (same stack the proven `open_spotify`
focus path uses).
"""

from __future__ import annotations

import os
import shutil
import subprocess
import time
from typing import Any

from ..base import Integration, payload_str

_LAYOUTS: dict[str, dict[str, Any]] = {
    "coding": {
        "label": "Coding",
        "windows": [
            {"title": "Visual Studio Code", "desktop": 0, "x": 0, "y": 0, "w": 1280, "h": 1080},
            {"title": "Konsole", "desktop": 0, "x": 1280, "y": 0, "w": 640, "h": 1080},
            {"title": "Google Chrome", "desktop": 0, "x": 0, "y": 0, "w": 1280, "h": 1080},
        ],
    },
    "meeting": {
        "label": "Meeting",
        "windows": [
            {"title": "Microsoft Teams", "desktop": 0, "x": 640, "y": 0, "w": 640, "h": 1080},
            {"title": "Google Chrome", "desktop": 0, "x": 0, "y": 0, "w": 640, "h": 1080},
        ],
    },
    "media": {
        "label": "Media",
        "windows": [
            {"title": "Spotify", "desktop": 0, "x": 0, "y": 0, "w": 640, "h": 1080},
            {"title": "Google Chrome", "desktop": 0, "x": 640, "y": 0, "w": 1280, "h": 1080},
        ],
    },
}


class WindowIntegration(Integration):
    """Window listing, focus, geometry, and workspace layout presets."""

    name = "window"

    def actions(self) -> dict[str, Any]:
        return {
            "list": lambda p: self.list(),
            "focus": lambda p: self.focus(payload_str(p, "title")),
            "move": lambda p: self.move(
                payload_str(p, "title"),
                payload_str(p, "desktop"),
                payload_str(p, "x"),
                payload_str(p, "y"),
                payload_str(p, "w"),
                payload_str(p, "h"),
            ),
            "minimize": lambda p: self.set_state(payload_str(p, "title"), "hidden"),
            "maximize": lambda p: self.set_state(payload_str(p, "title"), "maximized"),
            "close": lambda p: self.close(payload_str(p, "title")),
            "layouts": lambda p: self.layouts(),
            "apply_layout": lambda p: self.apply_layout(payload_str(p, "name")),
        }

    def snapshot(self) -> dict[str, Any]:
        return {"available": self._available(), "windows": self._wmctrl_list()}

    def _available(self) -> bool:
        return bool(shutil.which("wmctrl")) and bool(os.environ.get("DISPLAY"))

    def _wmctrl_list(self) -> list[dict[str, Any]]:
        if not self._available():
            return []
        try:
            completed = subprocess.run(
                ["wmctrl", "-lx"],
                capture_output=True,
                text=True,
                check=False,
                timeout=5,
            )
        except (OSError, subprocess.TimeoutExpired):
            return []
        windows = []
        for line in completed.stdout.splitlines():
            parts = line.split(None, 3)
            if len(parts) < 4:
                continue
            # `wmctrl -lx` columns: id desktop host "title" WM_CLASS
            # (title may contain spaces — the class is the last token).
            title, wm_class = parts[3].rsplit(None, 1)
            windows.append(
                {
                    "id": parts[0],
                    "desktop": int(parts[1]) if parts[1].isdigit() else None,
                    "title": title,
                    "wm_class": wm_class,
                }
            )
        return windows

    def list(self) -> dict[str, Any]:
        return {"ok": True, "windows": self._wmctrl_list()}

    def _run(self, args: list[str]) -> dict[str, Any]:
        if not self._available():
            return {"ok": False, "error": "wmctrl_unavailable"}
        try:
            completed = subprocess.run(
                ["wmctrl"] + args,
                capture_output=True,
                text=True,
                check=False,
                timeout=5,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"ok": False, "error": str(exc)}
        if completed.returncode != 0:
            return {"ok": False, "error": "window_not_found"}
        return {"ok": True, "args": args}

    def focus(self, title: Optional[str]) -> dict[str, Any]:
        if not title:
            return {"ok": False, "error": "title_required"}
        return self._run(["-a", title])

    def move(
        self,
        title: Optional[str],
        desktop: Optional[str] = None,
        x: Optional[str] = None,
        y: Optional[str] = None,
        w: Optional[str] = None,
        h: Optional[str] = None,
    ) -> dict[str, Any]:
        if not title:
            return {"ok": False, "error": "title_required"}
        if desktop is not None:
            if not desktop.isdigit():
                return {"ok": False, "error": "invalid_desktop"}
            self._run(["-r", title, "-e", f"0,{desktop},0,0,0,0"])
        if x is None or y is None or w is None or h is None:
            return {"ok": True, "moved_desktop": desktop}
        for value in (x, y, w, h):
            if not value.isdigit():
                return {"ok": False, "error": "invalid_geometry"}
        return self._run(["-r", title, "-e", f"0,{x},{y},{w},{h}"])

    def set_state(self, title: Optional[str], state: str) -> dict[str, Any]:
        if not title:
            return {"ok": False, "error": "title_required"}
        if state == "maximized":
            prop = "add,maximized_vert,maximized_horz"
        elif state == "hidden":
            prop = "add,hidden"
        else:
            return {"ok": False, "error": "invalid_state"}
        return self._run(["-r", title, "-b", prop])

    def close(self, title: Optional[str]) -> dict[str, Any]:
        if not title:
            return {"ok": False, "error": "title_required"}
        return self._run(["-c", title])

    def layouts(self) -> dict[str, Any]:
        return {
            "ok": True,
            "layouts": [
                {"name": name, "label": meta["label"], "apps": [w["title"] for w in meta["windows"]]}
                for name, meta in _LAYOUTS.items()
            ],
        }

    def apply_layout(self, name: Optional[str]) -> dict[str, Any]:
        if not name:
            return {"ok": False, "error": "layout_required"}
        meta = _LAYOUTS.get(name)
        if not meta:
            return {"ok": False, "error": "unknown_layout"}
        applied, missing = [], []
        for entry in meta["windows"]:
            # geometry + desktop, wmctrl -r <title> -e gravity,desktop,x,y,w,h
            geom = f"0,{entry['desktop']},{entry['x']},{entry['y']},{entry['w']},{entry['h']}"
            result = self._run(["-r", entry["title"], "-e", geom])
            if result.get("ok"):
                applied.append(entry["title"])
            else:
                missing.append(entry["title"])
            time.sleep(0.1)
        return {"ok": True, "applied": applied, "missing": missing, "layout": name}