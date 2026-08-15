from __future__ import annotations

import shutil
import subprocess
from typing import Any, Optional


class MediaIntegration:
    """MPRIS media controls via `playerctl`.

    Simple, dependency-light implementation: shells out to playerctl, which
    speaks the freedesktop MPRIS protocol and controls Spotify, VLC, and
    browsers exposing media sessions (Chrome/Chromium/Firefox). No per-app
    APIs needed — one tool covers Spotify, YouTube-in-browser, and local
    media players alike.
    """

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
        rc, out = self._run(["play-pause"], player=player)
        return {"ok": rc == 0, "player": player, "output": out}

    def next(self, player: Optional[str] = None) -> dict[str, Any]:
        rc, out = self._run(["next"], player=player)
        return {"ok": rc == 0, "player": player, "output": out}

    def previous(self, player: Optional[str] = None) -> dict[str, Any]:
        rc, out = self._run(["previous"], player=player)
        return {"ok": rc == 0, "player": player, "output": out}

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
        """Launch the desktop Spotify app if installed, else its web player."""
        binary = shutil.which("spotify")
        if binary:
            try:
                subprocess.Popen([binary], start_new_session=True)
                return {"ok": True, "method": "app", "target": "spotify"}
            except OSError:
                pass
        return {"ok": False, "method": "app_not_found", "fallback": "https://open.spotify.com"}