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


class VSCodeIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.vscode.subprocess.Popen")
    @patch.object(VSCodeIntegration, "resolve_command", return_value="code")
    def test_open_workspace_returns_ok(self, mock_resolve, mock_popen):
        integration = VSCodeIntegration()
        result = integration.open_workspace("/tmp/project")

        self.assertTrue(result["ok"])
        self.assertEqual(result["command"], "code")
        mock_popen.assert_called_once()


if __name__ == "__main__":
    unittest.main()
