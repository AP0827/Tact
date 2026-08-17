"""App/class -> context id and workflow classification maps.

The Context Engine's vocabulary — kept separate so new apps only require
adding a row here (or overriding via the `context.override` action).
"""

from __future__ import annotations

from typing import Optional

# WM_CLASS (lowercased) -> canonical app id
APP_MAP = {
    "code": "vscode",
    "vscodium": "vscode",
    "google-chrome": "chrome",
    "chromium": "chrome",
    "chromium-browser": "chrome",
    "microsoft-edge": "edge",
    "firefox": "firefox",
    "konsole": "terminal",
    "gnome-terminal": "terminal",
    "xterm": "terminal",
    "xterm-256color": "terminal",
    "kitty": "terminal",
    "alacritty": "terminal",
    "wezterm": "terminal",
    "ptyxis": "terminal",
    "spotify": "spotify",
    "teams": "teams",
    "ms-teams": "teams",
    "com.microsoft.teams": "teams",
    "slack": "slack",
    "discord": "discord",
    "figma": "figma",
    "obs": "obs",
}

# canonical app id -> workflow classification
WORKFLOW_MAP = {
    "vscode": "development",
    "terminal": "development",
    "figma": "design",
    "teams": "meeting",
    "slack": "communication",
    "discord": "communication",
    "spotify": "media",
    "chrome": "browsing",
    "edge": "browsing",
    "firefox": "browsing",
}


def map_app(wm_class: str) -> Optional[str]:
    """Map a lowercased WM_CLASS to the canonical app id (or None)."""
    return APP_MAP.get(wm_class.lower())


def classify(app: Optional[str]) -> Optional[str]:
    """Map a canonical app id to a workflow classification."""
    return WORKFLOW_MAP.get(app or "")