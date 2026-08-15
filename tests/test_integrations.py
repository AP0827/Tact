from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tact.agent.integrations.git import GitIntegration
from tact.agent.integrations.vscode import VSCodeIntegration


class GitIntegrationTests(unittest.TestCase):
    def test_discover_root_finds_git_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / ".git").mkdir()
            nested = root / "sub" / "dir"
            nested.mkdir(parents=True)

            integration = GitIntegration()
            discovered = integration.discover_root(nested)

            self.assertEqual(discovered, root)

    @patch("tact.agent.integrations.git.subprocess.run")
    @patch("tact.agent.integrations.git.shutil_which", return_value="git")
    def test_status_uses_git_commands(self, mock_which, mock_run):
        def run_side_effect(cmd, capture_output, text, check):
            command = cmd[3:]

            class Result:
                def __init__(self, returncode=0, stdout="", stderr=""):
                    self.returncode = returncode
                    self.stdout = stdout
                    self.stderr = stderr

            if command[:2] == ["status", "--porcelain=v1"]:
                return Result(stdout=" M file.txt\n")
            if command[:2] == ["branch", "--show-current"]:
                return Result(stdout="main\n")
            if command[:3] == ["rev-parse", "--short", "HEAD"]:
                return Result(stdout="abc123\n")
            if command[:3] == ["rev-parse", "--abbrev-ref", "--symbolic-full-name"]:
                return Result(returncode=1)
            return Result()

        mock_run.side_effect = run_side_effect

        integration = GitIntegration()
        with patch.object(GitIntegration, "discover_root", return_value=Path("/repo")):
            status = integration.status("/repo")

        self.assertTrue(status["available"])
        self.assertEqual(status["branch"], "main")
        self.assertEqual(status["commit"], "abc123")
        self.assertEqual(status["changed_files"], 1)
        self.assertFalse(status["clean"])

    @patch("tact.agent.integrations.git.subprocess.run")
    @patch("tact.agent.integrations.git.shutil_which", return_value="git")
    def test_branches_lists_branches(self, mock_which, mock_run):
        def run_side_effect(cmd, capture_output, text, check):
            class Result:
                def __init__(self, returncode=0, stdout="", stderr=""):
                    self.returncode = returncode
                    self.stdout = stdout
                    self.stderr = stderr

            if cmd[3:] == ["branch", "--show-current"]:
                return Result(stdout="main\n")
            if cmd[3:] == ["branch", "-a"]:
                return Result(stdout="  main\n* dev\n  remotes/origin/feature\n")
            return Result()

        mock_run.side_effect = run_side_effect

        integration = GitIntegration()
        with patch.object(GitIntegration, "discover_root", return_value=Path("/repo")):
            branches = integration.branches("/repo")

        self.assertTrue(branches["available"])
        self.assertEqual(branches["current"], "main")
        self.assertIn("main", branches["branches"])
        self.assertIn("dev", branches["branches"])
        self.assertIn("remotes/origin/feature", branches["branches"])

    @patch("tact.agent.integrations.git.subprocess.run")
    @patch("tact.agent.integrations.git.shutil_which", return_value="git")
    def test_tree_returns_file_list(self, mock_which, mock_run):
        def run_side_effect(cmd, capture_output, text, check):
            class Result:
                def __init__(self, returncode=0, stdout="", stderr=""):
                    self.returncode = returncode
                    self.stdout = stdout
                    self.stderr = stderr

            if cmd[3:] == ["ls-tree", "-r", "--name-only", "-z", "HEAD"]:
                return Result(stdout="README.md\0src/main.py\0src/utils/helper.py\0")
            return Result()

        mock_run.side_effect = run_side_effect

        integration = GitIntegration()
        with patch.object(GitIntegration, "discover_root", return_value=Path("/repo")):
            tree = integration.tree("/repo")

        self.assertTrue(tree["available"])
        self.assertEqual(tree["file_count"], 3)

        def collect_names(nodes):
            names = []
            for node in nodes:
                names.append(node["name"])
                if node.get("children"):
                    names.extend(collect_names(node["children"]))
            return names

        names = collect_names(tree["tree"])
        self.assertIn("README.md", names)
        self.assertIn("main.py", names)
        self.assertIn("helper.py", names)


class VSCodeIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.vscode.subprocess.Popen")
    @patch.object(VSCodeIntegration, "resolve_command", return_value="code")
    def test_open_workspace_returns_ok(self, mock_resolve, mock_popen):
        integration = VSCodeIntegration()
        result = integration.open_workspace("/tmp/project")

        self.assertTrue(result["ok"])
        self.assertEqual(result["command"], "code")
        mock_popen.assert_called_once()

    def test_workspaces_detects_open_folders(self):
        import sys
        import types
        from pathlib import Path

        mock_psutil = types.ModuleType("psutil")
        mock_proc = type("Proc", (), {
            "info": {
                "name": "code",
                "cmdline": ["code", "/home/user/project"],
            }
        })()
        mock_psutil.process_iter = lambda *args, **kwargs: [mock_proc]
        mock_psutil.NoSuchProcess = Exception
        mock_psutil.AccessDenied = Exception

        sys.modules["psutil"] = mock_psutil
        try:
            with tempfile.TemporaryDirectory() as tmp:
                project_dir = Path(tmp) / "project"
                project_dir.mkdir()
                mock_proc.info["cmdline"] = ["code", str(project_dir)]

                integration = VSCodeIntegration(config_dir=Path(tmp) / "config")
                integration._which = lambda cmd: cmd == "code" and "/usr/bin/code"

                with patch.object(Path, "is_dir", return_value=True):
                    result = integration.workspaces()

                self.assertTrue(result["available"])
                self.assertEqual(result["count"], 1)
                self.assertIn(str(project_dir), result["workspaces"])
        finally:
            del sys.modules["psutil"]


if __name__ == "__main__":
    unittest.main()

