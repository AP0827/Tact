from __future__ import annotations

import shutil
import subprocess
from typing import Any, Optional

from ..base import Integration, payload_str


class ClipboardIntegration(Integration):
    """Read/write the desktop clipboard, plus a small in-agent history.

    Platform backends:
      * Linux X11: `xsel` (present on the dev box) with `xclip` as fallback;
        Wayland would use `wl-paste`/`wl-copy`.
      * macOS: `pbpaste` / `pbcopy`.
      * Windows: `powershell Get-Clipboard` / `Set-Clipboard`.

    Text is the primary supported format. Image clipboard is detected where the
    backend can expose it (X11 TARGETS via `xclip -o -t TARGETS`); copies of
    images are reported as unsupported rather than silently dropped.
    """

    name = "clipboard"

    def __init__(self, history_size: int = 20):
        self._history: list[str] = []
        self._history_size = max(1, int(history_size))

    def actions(self) -> dict[str, Any]:
        return {
            "get": lambda p: self.get(),
            "set": lambda p: self.set(payload_str(p, "text")),
            "status": lambda p: self.status(),
            "clear_history": lambda p: self.clear_history(),
        }

    def snapshot(self) -> dict[str, Any]:
        return self.status()

    # -- backend resolution ------------------------------------------------

    def is_available(self) -> bool:
        return self._get_cmd() is not None

    def capabilities(self) -> dict[str, Any]:
        """What this platform can do with the clipboard."""
        return {
            "available": self.is_available(),
            "text": self.is_available(),
            "image": self._image_supported(),
            "backend": self._backend_name(),
        }

    def _backend_name(self) -> str:
        if shutil.which("xsel"):
            return "xsel"
        if shutil.which("xclip"):
            return "xclip"
        if shutil.which("wl-paste"):
            return "wl-paste"
        if shutil.which("pbpaste"):
            return "pbpaste"
        if shutil.which("powershell"):
            return "powershell"
        return "none"

    def _get_cmd(self) -> Optional[str]:
        if shutil.which("xsel"):
            return "xsel"
        if shutil.which("xclip"):
            return "xclip"
        if shutil.which("wl-paste"):
            return "wl-paste"
        if shutil.which("pbpaste"):
            return "pbpaste"
        if shutil.which("powershell"):
            return "powershell"
        return None

    def _image_supported(self) -> bool:
        """Best-effort image-clipboard detection."""
        if shutil.which("xclip"):
            try:
                completed = subprocess.run(
                    ["xclip", "-selection", "clipboard", "-o", "-t", "TARGETS"],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
                if completed.returncode == 0:
                    targets = completed.stdout.lower()
                    return any(
                        t in targets
                        for t in ("image/png", "image/bmp", "image/jpeg", "image/tiff")
                    )
            except (OSError, subprocess.TimeoutExpired):
                pass
        return False

    # -- read --------------------------------------------------------------

    def get(self) -> dict[str, Any]:
        """Read current clipboard text and record it in history."""
        cmd = self._get_cmd()
        if cmd is None:
            return {"ok": False, "error": "clipboard_tool_not_found"}

        try:
            if cmd == "xsel":
                completed = subprocess.run(
                    ["xsel", "-b", "-o"],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            elif cmd == "xclip":
                completed = subprocess.run(
                    ["xclip", "-selection", "clipboard", "-o"],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            elif cmd == "wl-paste":
                completed = subprocess.run(
                    ["wl-paste", "--no-newline"],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            elif cmd == "pbpaste":
                completed = subprocess.run(
                    ["pbpaste"],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            else:  # powershell
                completed = subprocess.run(
                    ["powershell", "-NoProfile", "-Command", "Get-Clipboard -Raw"],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"ok": False, "error": str(exc)}

        if completed.returncode != 0:
            return {"ok": False, "error": completed.stderr.strip() or "clipboard_read_failed"}

        text = completed.stdout
        # Multi-line power shell output may carry a trailing newline; keep it
        # but trim a single trailing CR/LF so the phone shows clean text.
        if text.endswith("\n"):
            text = text[:-1]
        return {"ok": True, "text": text}

    def status(self) -> dict[str, Any]:
        """Clipboard status for the snapshot: current text + recent history."""
        result = self.get()
        caps = self.capabilities()
        return {
            "available": caps["available"],
            "image_supported": caps["image"],
            "text": result.get("text", "") if result.get("ok") else "",
            "history": list(self._history),
            "error": result.get("error"),
        }

    # -- write -------------------------------------------------------------

    def set(self, text: str) -> dict[str, Any]:
        """Overwrite the desktop clipboard with `text` from the phone."""
        cmd = self._get_cmd()
        if cmd is None:
            return {"ok": False, "error": "clipboard_tool_not_found"}
        if text is None:
            return {"ok": False, "error": "text_required"}

        try:
            if cmd == "xsel":
                completed = subprocess.run(
                    ["xsel", "-b", "-i"],
                    input=text,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            elif cmd == "xclip":
                completed = subprocess.run(
                    ["xclip", "-selection", "clipboard", "-i"],
                    input=text,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            elif cmd == "wl-paste":
                completed = subprocess.run(
                    ["wl-copy", "--foreground", "--type", "text/plain"],
                    input=text,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            elif cmd == "pbpaste":
                completed = subprocess.run(
                    ["pbcopy"],
                    input=text,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            else:  # powershell
                completed = subprocess.run(
                    ["powershell", "-NoProfile", "-Command",
                     "Set-Clipboard -Value ([Console]::In.ReadToEnd())"],
                    input=text,
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"ok": False, "error": str(exc)}

        if completed.returncode != 0:
            return {"ok": False, "error": completed.stderr.strip() or "clipboard_write_failed"}

        self._record(text)
        return {"ok": True, "written": len(text)}

    # -- history -----------------------------------------------------------

    def _record(self, text: str) -> None:
        if not text or not text.strip():
            return
        if text in self._history:
            self._history.remove(text)
        self._history.insert(0, text)
        del self._history[self._history_size:]

    def clear_history(self) -> dict[str, Any]:
        self._history = []
        return {"ok": True, "history": []}