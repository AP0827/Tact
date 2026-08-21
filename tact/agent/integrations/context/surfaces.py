"""Phase 3.1: surface registry — context id -> surface definition.

A surface is the Context layer of the Tact Surface for one app: a title, a
set of action buttons (every button maps to an allowlisted registry action),
and a state-card kind the phone renders from live snapshot data. Unknown
apps and unavailable window detection get the fallback surface so the
surface is never empty.

Adding a surface for a new app = one registry entry here. Buttons must use
actions already registered in ActionRegistry (Phase 3.2 will grow the
per-app action sets — Run/Debug/Test for VS Code, meeting controls for
Teams — on top of this structure).
"""

from __future__ import annotations

from typing import Any, Optional


class Surface:
    """A context surface definition (static; state comes from the snapshot)."""

    def __init__(
        self,
        id: str,
        title: str,
        icon: str,
        workflow: Optional[str],
        actions: list[dict[str, Any]],
        state_card: Optional[str] = None,
    ):
        self.id = id
        self.title = title
        self.icon = icon
        self.workflow = workflow
        self.actions = actions
        self.state_card = state_card

    def to_json(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "icon": self.icon,
            "workflow": self.workflow,
            "actions": [
                {
                    "id": a["id"],
                    "label": a["label"],
                    "icon": a.get("icon", "bolt"),
                    "prompt": a.get("prompt"),
                }
                for a in self.actions
            ],
            "state_card": self.state_card,
        }


def _browser_surface(browser_id: str, title: str) -> Surface:
    return Surface(
        id=browser_id,
        title=title,
        icon="public",
        workflow="browsing",
        actions=[
            {"id": "chrome.back", "label": "Back", "icon": "arrow_back"},
            {"id": "chrome.forward", "label": "Forward", "icon": "arrow_forward"},
            {"id": "chrome.refresh", "label": "Refresh", "icon": "refresh"},
            {"id": "chrome.new_tab", "label": "New Tab", "icon": "add"},
            {"id": "chrome.copy_url", "label": "Copy URL", "icon": "link"},
            {"id": "system.open_url", "label": "Open URL", "icon": "external_link", "prompt": "url"},
            {"id": "system.screenshot", "label": "Screenshot", "icon": "screenshot"},
            {"id": "system.open_terminal", "label": "Terminal", "icon": "terminal"},
        ],
    )


SURFACES: dict[str, Surface] = {
    "vscode": Surface(
        id="vscode",
        title="VS Code",
        icon="code",
        workflow="development",
        actions=[
            {"id": "vscode.run_task", "label": "Run Task", "icon": "play"},
            {"id": "vscode.debug", "label": "Debug", "icon": "bug"},
            {"id": "vscode.test", "label": "Test", "icon": "test_tube"},
            {"id": "vscode.open_file", "label": "Open File", "icon": "file_open", "prompt": "path"},
            {"id": "system.open_terminal", "label": "Terminal", "icon": "terminal"},
            {"id": "git.pull", "label": "Pull", "icon": "download"},
            {"id": "git.push", "label": "Push", "icon": "upload"},
            {"id": "git.status", "label": "Refresh", "icon": "refresh"},
        ],
        state_card="git",
    ),
    "terminal": Surface(
        id="terminal",
        title="Terminal",
        icon="terminal",
        workflow="development",
        actions=[
            {"id": "system.open_terminal", "label": "New Terminal", "icon": "terminal"},
            {"id": "git.pull", "label": "Pull", "icon": "download"},
            {"id": "git.push", "label": "Push", "icon": "upload"},
            {"id": "git.status", "label": "Refresh", "icon": "refresh"},
        ],
        state_card="git",
    ),
    "chrome": _browser_surface("chrome", "Chrome"),
    "edge": _browser_surface("edge", "Edge"),
    "firefox": _browser_surface("firefox", "Firefox"),
    "teams": Surface(
        id="teams",
        title="Teams",
        icon="groups",
        workflow="meeting",
        actions=[
            {"id": "teams.mute", "label": "Mute", "icon": "mic_off"},
            {"id": "teams.camera", "label": "Camera", "icon": "videocam_off"},
            {"id": "teams.share", "label": "Share", "icon": "screenshot"},
            {"id": "teams.leave", "label": "Leave", "icon": "call_end"},
        ],
    ),
    "spotify": Surface(
        id="spotify",
        title="Spotify",
        icon="music_note",
        workflow="media",
        actions=[
            {"id": "media.play_pause", "label": "Play / Pause", "icon": "play"},
            {"id": "media.previous", "label": "Previous", "icon": "skip_previous"},
            {"id": "media.next", "label": "Next", "icon": "skip_next"},
        ],
        state_card="media",
    ),
    "fallback": Surface(
        id="fallback",
        title="Desktop",
        icon="apps",
        workflow=None,
        actions=[
            {"id": "system.open_url", "label": "Open URL", "icon": "link", "prompt": "url"},
            {"id": "system.open_terminal", "label": "Terminal", "icon": "terminal"},
            {"id": "system.volume_up", "label": "Volume +", "icon": "volume_up"},
            {"id": "system.volume_down", "label": "Volume -", "icon": "volume_down"},
            {"id": "system.mute", "label": "Mute", "icon": "mute"},
            {"id": "system.screenshot", "label": "Screenshot", "icon": "screenshot"},
            {"id": "system.lock_screen", "label": "Lock", "icon": "lock"},
        ],
    ),
}

FALLBACK_ID = "fallback"


def select_surface(app: Optional[str], available: bool) -> dict[str, Any]:
    """Pick the active surface; unknown/unavailable contexts get fallback."""
    if available and app:
        surface = SURFACES.get(app)
        if surface is not None:
            return surface.to_json()
    return SURFACES[FALLBACK_ID].to_json()


def surfaces_meta() -> list[dict[str, Any]]:
    """Lightweight list of registered surfaces (for the phone's switcher)."""
    return [
        {"id": s.id, "title": s.title, "icon": s.icon, "workflow": s.workflow}
        for s in SURFACES.values()
    ]