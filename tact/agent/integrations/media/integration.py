from __future__ import annotations

import os
import shutil
import subprocess
from typing import Any, Optional

from ..base import Integration, payload_str


class MediaIntegration(Integration):
    """MPRIS media controls via `playerctl`.

    Simple, dependency-light implementation: shells out to playerctl, which
    speaks the freedesktop MPRIS protocol and controls Spotify, VLC, and
    browsers exposing media sessions (Chrome/Chromium/Firefox). No per-app
    APIs needed — one tool covers Spotify, YouTube-in-browser, and local
    media players alike.

    Transport controls additionally fall back to X11 media keys via xdotool
    (XF86AudioPlay/Next/Previous) — snap-packaged apps like Spotify drop
    their MPRIS registration intermittently, and the media keys keep
    working regardless.
    """

    name = "media"

    def actions(self) -> dict[str, Any]:
        return {
            "status": lambda p: self.status(),
            "play_pause": lambda p: self.play_pause(payload_str(p, "player")),
            "next": lambda p: self.next(payload_str(p, "player")),
            "previous": lambda p: self.previous(payload_str(p, "player")),
            "volume": lambda p: self.volume(payload_str(p, "player"), payload_str(p, "value")),
            "seek": lambda p: self.seek(payload_str(p, "player"), payload_str(p, "position")),
        }

    def snapshot(self) -> dict[str, Any]:
        return self.status()

    # -- transport with media-key fallback -------------------------------

    def _media_key(self, key: str) -> dict[str, Any]:
        """Send an X11 media key (works without MPRIS registration)."""
        if not (shutil.which("xdotool") and os.environ.get("DISPLAY")):
            return {"ok": False, "error": "xdotool_unavailable"}
        try:
            subprocess.Popen(["xdotool", "key", key], start_new_session=True)
            return {"ok": True, "method": "xdotool", "key": key}
        except OSError as exc:
            return {"ok": False, "error": str(exc)}

    def _transport(self, playerctl_args: list[str], media_key: str, player: Optional[str]) -> dict[str, Any]:
        rc, out = self._run(playerctl_args, player=player)
        if rc == 0:
            return {"ok": True, "player": player, "method": "playerctl", "output": out}
        fallback = self._media_key(media_key)
        if fallback.get("ok"):
            return {"ok": True, "player": player, "method": "xdotool", "key": media_key}
        return {"ok": False, "player": player, "output": out, "error": fallback.get("error")}

    def _playerctl(self) -> Optional[str]:
        return shutil.which("playerctl")

    def is_available(self) -> bool:
        return self._playerctl() is not None

    def _run(self, args: list[str], player: Optional[str] = None) -> tuple[int, str]:
        binary = self._playerctl()
        if binary is None:
            return 1, ""
        cmd = [binary]
        if player:
            cmd += ["--player", player]
        cmd += args
        try:
            completed = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
            return completed.returncode, completed.stdout.strip()
        except OSError:
            return 1, ""

    def status(self) -> dict[str, Any]:
        binary = self._playerctl()
        if binary is None:
            return {"available": False, "error": "playerctl_not_installed"}

        players = self._list_players()
        details: dict[str, Any] = {}
        active = None
        # Prefer a currently-playing player over a paused one.
        for name in players:
            meta = self._metadata(name)
            details[name] = {"player": name, **meta}
            if meta.get("status") == "Playing" and active is None:
                active = {"player": name, **meta}
        if active is None:
            for name in players:
                meta = details.get(name, {})
                if meta.get("status") == "Paused":
                    active = meta
                    break

        return {
            "available": True,
            "players": players,
            "details": details,
            "active": active,
        }

    def _list_players(self) -> list[str]:
        rc, out = self._run(["-l"])
        if rc != 0:
            return []
        return [line for line in out.splitlines() if line.strip()]

    def _metadata(self, player: str) -> dict[str, Any]:
        fields = {
            "status": "{{status}}",
            "title": "{{title}}",
            "artist": "{{artist}}",
            "album": "{{album}}",
        }
        result: dict[str, Any] = {"status": "Stopped"}
        for key, fmt in fields.items():
            rc, out = self._run(["metadata", "--format", fmt], player=player)
            if rc == 0 and out and out not in ("Unknown", "None"):
                result[key] = out

        # Duration in seconds (mpris:length is in microseconds).
        rc, out = self._run(["metadata", "--format", "{{mpris:length}}"], player=player)
        if rc == 0 and out.isdigit():
            result["length"] = int(out) / 1_000_000
        # Current position in seconds.
        rc, out = self._run(["position"], player=player)
        if rc == 0 and out:
            try:
                result["position"] = float(out)
            except ValueError:
                pass
        # Volume 0..1.
        rc, out = self._run(["volume"], player=player)
        if rc == 0 and out:
            try:
                result["volume"] = float(out)
            except ValueError:
                pass
        return result

    def play_pause(self, player: Optional[str] = None) -> dict[str, Any]:
        return self._transport(["play-pause"], "XF86AudioPlay", player)

    def next(self, player: Optional[str] = None) -> dict[str, Any]:
        return self._transport(["next"], "XF86AudioNext", player)

    def previous(self, player: Optional[str] = None) -> dict[str, Any]:
        return self._transport(["previous"], "XF86AudioPrev", player)

    def volume(self, player: Optional[str] = None, value: Optional[float] = None) -> dict[str, Any]:
        args = ["volume"]
        if value is not None:
            args.append(f"{max(0.0, min(1.0, value)):.2f}")
        rc, out = self._run(args, player=player)
        if rc != 0:
            return {"ok": False, "player": player}
        try:
            current = float(out)
        except ValueError:
            current = None
        return {"ok": True, "player": player, "volume": current}

    def seek(self, player: Optional[str] = None, position: Optional[float] = None) -> dict[str, Any]:
        """Get the current position (seconds), or seek when `position` given."""
        args = ["position"]
        if position is not None:
            args.append(f"{position:.2f}")
        rc, out = self._run(args, player=player)
        if rc != 0:
            return {"ok": False, "player": player}
        try:
            current = float(out)
        except ValueError:
            current = None
        return {"ok": True, "player": player, "position": current}

    def open_spotify(self) -> dict[str, Any]:
        """Launch the desktop Spotify app if installed, else its web player.

        After launching, a detached helper brings the window to the
        foreground (snap apps start behind the current window).
        """
        binary = shutil.which("spotify")
        if binary:
            try:
                subprocess.Popen([binary], start_new_session=True)
                self._focus_window_after_launch()
                return {"ok": True, "method": "app", "target": "spotify"}
            except OSError:
                pass
        return {"ok": False, "method": "app_not_found", "fallback": "https://open.spotify.com"}

    def _focus_window_after_launch(self) -> None:
        """Poll for the Spotify window (up to ~6s) and activate it.

        Detached so the action returns immediately; the focus happens in
        the background once the window exists. Prefers `wmctrl -a` (works
        across virtual desktops); falls back to xdotool windowactivate.
        """
        if not (shutil.which("wmctrl") or shutil.which("xdotool")) or not os.environ.get("DISPLAY"):
            return
        if shutil.which("wmctrl"):
            script = (
                "for i in $(seq 1 40); do "
                "wmctrl -a Spotify 2>/dev/null && exit 0; "
                "sleep 0.3; "
                "done; exit 0"
            )
        else:
            script = (
                "for i in $(seq 1 40); do "
                "id=$(xdotool search --name 'Spotify' 2>/dev/null | tail -1); "
                "[ -n \"$id\" ] && xdotool windowactivate \"$id\" 2>/dev/null && exit 0; "
                "sleep 0.3; "
                "done; exit 0"
            )
        try:
            subprocess.Popen(
                ["bash", "-c", script],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except OSError:
            pass