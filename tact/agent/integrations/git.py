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

    def add(self, start_path: str | Path | None = None) -> dict[str, Any]:
        return self._run_git_action(start_path, ["add", "-A"])

    def log(self, start_path: str | Path | None = None, limit: int = 40) -> dict[str, Any]:
        root = self.discover_root(start_path)
        if root is None or not self.is_available():
            return {"available": False, "commits": []}
        args = ["log", "--graph", "--oneline", "--decorate=short", "--all", "-n", str(limit)]
        output = self._run_git(root, args)
        if not output:
            return {"available": True, "commits": [], "root": str(root)}
        commits = [line for line in output.splitlines() if line.strip()]
        return {"available": True, "commits": commits, "root": str(root)}

    def pull(self, start_path: str | Path | None = None) -> dict[str, Any]:
        return self._run_git_action(start_path, ["pull", "--ff-only"])

    def push(self, start_path: str | Path | None = None) -> dict[str, Any]:
        return self._run_git_action(start_path, ["push"])

    def commit(self, message: str, start_path: str | Path | None = None) -> dict[str, Any]:
        return self._run_git_action(start_path, ["commit", "-am", message])

    def is_dirty(self, start_path: str | Path | None = None) -> bool:
        """Check if the repository has uncommitted changes."""
        root = self.discover_root(start_path)
        if root is None:
            return False
        status = self.status(root)
        return not status.get("clean", False)

    def has_unpushed_commits(self, start_path: str | Path | None = None) -> bool:
        """Check if there are commits ahead of upstream."""
        root = self.discover_root(start_path)
        if root is None:
            return False
        status = self.status(root)
        return (status.get("ahead") or 0) > 0

    def branches(self, start_path: str | Path | None = None) -> dict[str, Any]:
        root = self.discover_root(start_path)
        if root is None or not self.is_available():
            return {"available": False, "branches": [], "current": None}
        current = self._run_git(root, ["branch", "--show-current"])
        all_branches = self._run_git(root, ["branch", "-a"]).splitlines()
        cleaned = []
        for b in all_branches:
            b = b.strip()
            if not b:
                continue
            if b.startswith("* "):
                b = b[2:]
            cleaned.append(b)
        return {
            "available": True,
            "current": current or None,
            "branches": cleaned,
            "root": str(root),
        }

    def tree(self, start_path: str | Path | None = None, max_depth: int = 3) -> dict[str, Any]:
        root = self.discover_root(start_path)
        if root is None or not self.is_available():
            return {"available": False, "tree": []}
        output = self._run_git(root, ["ls-tree", "-r", "--name-only", "-z", "HEAD"])
        if not output:
            return {"available": True, "tree": [], "root": str(root)}
        files = [f for f in output.split("\0") if f.strip()]
        tree = []
        for f in files:
            parts = Path(f).parts
            current = tree
            for i, part in enumerate(parts):
                if i == len(parts) - 1:
                    current.append({"name": part, "path": f, "type": "file"})
                else:
                    found = next((x for x in current if x.get("name") == part and x.get("type") == "dir"), None)
                    if not found:
                        found = {"name": part, "path": str(Path(*parts[: i + 1])), "type": "dir", "children": []}
                        current.append(found)
                    current = found["children"]
        return {"available": True, "tree": tree, "root": str(root), "file_count": len(files)}

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
