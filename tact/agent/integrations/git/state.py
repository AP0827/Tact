"""Git domain types shared within the git integration."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional


@dataclass
class GitStatus:
    root: str
    branch: Optional[str]
    commit: Optional[str]
    changed_files: int
    clean: bool
    ahead: Optional[int] = None
    behind: Optional[int] = None
    upstream: Optional[str] = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "root": self.root,
            "branch": self.branch,
            "commit": self.commit,
            "changed_files": self.changed_files,
            "clean": self.clean,
            "ahead": self.ahead,
            "behind": self.behind,
            "upstream": self.upstream,
        }