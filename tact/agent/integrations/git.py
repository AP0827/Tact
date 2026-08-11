from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
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


class GitIntegration:
    def discover_root(self, start_path: str | Path | None = None) -> Optional[Path]:
        candidate = Path(start_path or os.getcwd()).resolve()
        if candidate.is_file():
            candidate = candidate.parent

        while True:
            if (candidate / ".git").exists():
                return candidate
            if candidate.parent == candidate:
                break
            candidate = candidate.parent
        return None

    def is_available(self) -> bool:
        return shutil_which("git") is not None

    def status(self, start_path: str | Path | None = None) -> dict[str, Any]:
        root = self.discover_root(start_path)
        if root is None or not self.is_available():
            return {"available": False, "root": None}

        branch = self._run_git(root, ["branch", "--show-current"])
        commit = self._run_git(root, ["rev-parse", "--short", "HEAD"])
        porcelain = self._run_git(root, ["status", "--porcelain=v1"])
        upstream, ahead, behind = self._upstream_tracking(root)

        changed_files = 0
        if porcelain:
            changed_files = len([line for line in porcelain.splitlines() if line.strip()])

        status = GitStatus(
            root=str(root),
            branch=branch or None,
            commit=commit or None,
            changed_files=changed_files,
            clean=changed_files == 0,
            ahead=ahead,
            behind=behind,
            upstream=upstream,
        )
        data = status.as_dict()
        data["available"] = True
        return data

    def pull(self, start_path: str | Path | None = None) -> dict[str, Any]:
        return self._run_git_action(start_path, ["pull", "--ff-only"])

    def push(self, start_path: str | Path | None = None) -> dict[str, Any]:
        return self._run_git_action(start_path, ["push"])

    def commit(self, message: str, start_path: str | Path | None = None) -> dict[str, Any]:
        return self._run_git_action(start_path, ["commit", "-am", message])

    def _run_git_action(self, start_path: str | Path | None, args: list[str]) -> dict[str, Any]:
        root = self.discover_root(start_path)
        if root is None:
            return {"ok": False, "error": "not_a_git_repository"}
        if not self.is_available():
            return {"ok": False, "error": "git_not_available"}

        completed = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True,
            text=True,
            check=False,
        )
        return {
            "ok": completed.returncode == 0,
            "returncode": completed.returncode,
            "stdout": completed.stdout.strip(),
            "stderr": completed.stderr.strip(),
            "root": str(root),
            "args": args,
        }

    def _run_git(self, root: Path, args: list[str]) -> str:
        completed = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            return ""
        return completed.stdout.strip()

    def _upstream_tracking(self, root: Path) -> tuple[Optional[str], Optional[int], Optional[int]]:
        completed = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            capture_output=True,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            return None, None, None

        upstream = completed.stdout.strip()
        counts = subprocess.run(
            ["git", "-C", str(root), "rev-list", "--left-right", "--count", f"{upstream}...HEAD"],
            capture_output=True,
            text=True,
            check=False,
        )
        if counts.returncode != 0:
            return upstream, None, None

        parts = counts.stdout.strip().split()
        if len(parts) != 2:
            return upstream, None, None

        behind_str, ahead_str = parts
        try:
            behind = int(behind_str)
            ahead = int(ahead_str)
        except ValueError:
            return upstream, None, None
        return upstream, ahead, behind


def shutil_which(command: str) -> Optional[str]:
    from shutil import which

    return which(command)
