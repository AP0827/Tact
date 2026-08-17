from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tact.agent.integrations.git import GitIntegration
from tact.agent.integrations.vscode import VSCodeIntegration
from tact.agent.integrations.media import MediaIntegration
from tact.agent.integrations.docker import DockerIntegration
from tact.agent.integrations.clipboard import ClipboardIntegration
from tact.agent.integrations.context import ContextIntegration


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

    @patch("tact.agent.integrations.git.integration.subprocess.run")
    @patch("tact.agent.integrations.git.integration.shutil_which", return_value="git")
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

    @patch("tact.agent.integrations.git.integration.subprocess.run")
    @patch("tact.agent.integrations.git.integration.shutil_which", return_value="git")
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

    @patch("tact.agent.integrations.git.integration.subprocess.run")
    @patch("tact.agent.integrations.git.integration.shutil_which", return_value="git")
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
    @patch("tact.agent.integrations.vscode.integration.subprocess.Popen")
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


class MediaIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value="/usr/bin/playerctl")
    @patch("tact.agent.integrations.media.integration.subprocess.run")
    def test_status_reports_unavailable_when_players_missing(self, mock_run, mock_which):
        class Result:
            def __init__(self, returncode=0, stdout=""):
                self.returncode = returncode
                self.stdout = stdout

        mock_run.return_value = Result()
        integration = MediaIntegration()
        self.assertTrue(integration.is_available())
        status = integration.status()
        self.assertTrue(status["available"])
        self.assertEqual(status["players"], [])
        self.assertIsNone(status["active"])
        self.assertNotIn("hint", status)

    @patch("tact.agent.integrations.media.integration.shutil.which", return_value=None)
    def test_status_reports_not_installed(self, mock_which):
        integration = MediaIntegration()
        self.assertFalse(integration.is_available())
        status = integration.status()
        self.assertFalse(status["available"])
        self.assertIn("error", status)

    @patch("tact.agent.integrations.media.integration.os.environ", {})
    @patch("tact.agent.integrations.media.integration.subprocess.Popen")
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value="/usr/bin/spotify")
    def test_open_spotify_launches_app(self, mock_which, mock_popen):
        integration = MediaIntegration()
        result = integration.open_spotify()
        self.assertTrue(result["ok"])
        self.assertEqual(result["method"], "app")
        launch_call = mock_popen.call_args_list[0]
        self.assertEqual(launch_call[0][0], ["/usr/bin/spotify"])
        mock_popen.assert_called()

    @patch("tact.agent.integrations.media.integration.subprocess.Popen")
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value=None)
    def test_open_spotify_falls_back_when_not_installed(self, mock_which, mock_popen):
        integration = MediaIntegration()
        result = integration.open_spotify()
        self.assertFalse(result["ok"])
        self.assertEqual(result["method"], "app_not_found")
        self.assertIn("fallback", result)

    @patch("tact.agent.integrations.media.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.media.integration.subprocess.Popen")
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value="/usr/bin/xdotool")
    def test_play_pause_falls_back_to_media_key(self, mock_which, mock_popen):
        class Result:
            def __init__(self, returncode=0, stdout="", stderr=""):
                self.returncode = returncode
                self.stdout = stdout
                self.stderr = stderr

        # playerctl fails (player not registered) -> xdotool fallback.
        def run_side_effect(cmd, **kwargs):
            return Result(returncode=1)

        integration = MediaIntegration()
        with patch("tact.agent.integrations.media.integration.subprocess.run", side_effect=run_side_effect):
            result = integration.play_pause()

        self.assertTrue(result["ok"])
        self.assertEqual(result["method"], "xdotool")
        self.assertEqual(result["key"], "XF86AudioPlay")
        args = mock_popen.call_args[0][0]
        self.assertIn("XF86AudioPlay", args)

    @patch("tact.agent.integrations.media.integration.subprocess.Popen")
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value="/usr/bin/playerctl")
    def test_play_pause_uses_playerctl_when_available(self, mock_which, mock_popen):
        class Result:
            def __init__(self, returncode=0, stdout="", stderr=""):
                self.returncode = returncode
                self.stdout = stdout
                self.stderr = stderr

        integration = MediaIntegration()
        with patch("tact.agent.integrations.media.integration.subprocess.run", return_value=Result(returncode=0)):
            result = integration.play_pause("spotify")

        self.assertTrue(result["ok"])
        self.assertEqual(result["method"], "playerctl")
        self.assertEqual(result["player"], "spotify")


class DockerIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.docker.integration.shutil.which", return_value="/usr/bin/docker")
    @patch("tact.agent.integrations.docker.integration.subprocess.run")
    def test_containers_parses_output(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "api\trunning\tpostgres:15\tUp 2 hours\nredis\texited\tredis:7\tExited (0) 5 minutes ago\n"
            stderr = ""

        mock_run.return_value = Result()
        integration = DockerIntegration()
        result = integration.containers()

        self.assertTrue(result["available"])
        self.assertEqual(result["count"], 2)
        self.assertEqual(result["containers"][0]["name"], "api")
        self.assertEqual(result["containers"][0]["state"], "running")
        self.assertEqual(result["containers"][1]["state"], "exited")

    @patch("tact.agent.integrations.docker.integration.shutil.which", return_value="/usr/bin/docker")
    @patch("tact.agent.integrations.docker.integration.subprocess.run")
    def test_permission_denied_reported(self, mock_run, mock_which):
        class Result:
            returncode = 1
            stdout = ""
            stderr = "permission denied while trying to connect to the docker daemon socket"

        mock_run.return_value = Result()
        integration = DockerIntegration()
        result = integration.containers()

        self.assertFalse(result["available"])
        self.assertEqual(result["error"], "docker_permission_denied")

    @patch("tact.agent.integrations.docker.integration.shutil.which", return_value="/usr/bin/docker")
    @patch("tact.agent.integrations.docker.integration.subprocess.run")
    def test_start_requires_name(self, mock_run, mock_which):
        integration = DockerIntegration()
        result = integration.start("")
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "container_name_required")

    @patch("tact.agent.integrations.docker.integration.shutil.which", return_value="/usr/bin/docker")
    @patch("tact.agent.integrations.docker.integration.subprocess.run")
    def test_logs_returns_output(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "line1\nline2\n"
            stderr = ""

        mock_run.return_value = Result()
        integration = DockerIntegration()
        result = integration.logs("api", tail=10)

        self.assertTrue(result["ok"])
        self.assertEqual(result["container"], "api")
        self.assertEqual(result["logs"], "line1\nline2")
        mock_run.assert_called_once()
        self.assertIn("--tail", mock_run.call_args[0][0])


class ClipboardIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.clipboard.integration.shutil.which", return_value="/usr/bin/xsel")
    @patch("tact.agent.integrations.clipboard.integration.subprocess.run")
    def test_get_reads_clipboard(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "copied text\n"
            stderr = ""

        mock_run.return_value = Result()
        integration = ClipboardIntegration()
        result = integration.get()

        self.assertTrue(result["ok"])
        self.assertEqual(result["text"], "copied text")
        mock_run.assert_called_once()
        self.assertIn("-o", mock_run.call_args[0][0])

    @patch("tact.agent.integrations.clipboard.integration.shutil.which", return_value="/usr/bin/xsel")
    @patch("tact.agent.integrations.clipboard.integration.subprocess.run")
    def test_set_writes_and_records_history(self, mock_run, mock_which):
        class Result:
            def __init__(self, returncode=0, stdout="", stderr=""):
                self.returncode = returncode
                self.stdout = stdout
                self.stderr = stderr

        clipboard: dict[str, str] = {"value": ""}

        def run_side_effect(cmd, **kwargs):
            # Read path returns whatever was "written" (the mock clipboard).
            if "-i" in cmd:
                clipboard["value"] = kwargs.get("input") or ""
            return Result(stdout=clipboard["value"])

        mock_run.side_effect = run_side_effect
        integration = ClipboardIntegration()
        result = integration.set("hello from phone")

        self.assertTrue(result["ok"])
        self.assertEqual(result["written"], 16)
        self.assertEqual(integration._history, ["hello from phone"])

        status = integration.status()
        self.assertEqual(status["history"], ["hello from phone"])
        self.assertEqual(status["text"], "hello from phone")

    @patch("tact.agent.integrations.clipboard.integration.shutil.which", return_value=None)
    def test_unavailable_when_no_tool(self, mock_which):
        integration = ClipboardIntegration()
        self.assertFalse(integration.is_available())
        self.assertFalse(integration.get()["ok"])
        self.assertFalse(integration.set("x")["ok"])

    def test_history_deduplicates_and_limits(self):
        integration = ClipboardIntegration(history_size=3)
        for text in ["a", "b", "c", "a", "d"]:
            integration.set(text)
        self.assertEqual(integration._history, ["d", "a", "c"])

    @patch("tact.agent.integrations.clipboard.integration.shutil.which", side_effect=lambda cmd: "/usr/bin/xclip" if cmd == "xclip" else None)
    @patch("tact.agent.integrations.clipboard.integration.subprocess.run")
    def test_image_support_detection(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "TARGETS\nUTF8_STRING\nimage/png\n"
            stderr = ""

        mock_run.return_value = Result()
        integration = ClipboardIntegration()
        caps = integration.capabilities()

        self.assertTrue(caps["image"])
        self.assertEqual(caps["backend"], "xclip")


class ContextIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.context.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.context.detection.subprocess.run")
    def test_detect_maps_active_window_to_app(self, mock_run):
        class Result:
            def __init__(self, returncode=0, stdout="", stderr=""):
                self.returncode = returncode
                self.stdout = stdout
                self.stderr = stderr

        calls = {
            "xprop": [
                Result(stdout="window id # 0x3600004\n"),
                Result(
                    stdout='_NET_WM_NAME(UTF8_STRING) = "main.dart — Tact"\n'
                           'WM_CLASS(STRING) = "code", "Code"\n'
                ),
            ],
        }

        def run_side_effect(cmd, **kwargs):
            if cmd[0] == "xprop":
                return calls["xprop"].pop(0)
            # git commands during branch resolution -> no repo context
            return Result()

        mock_run.side_effect = run_side_effect

        integration = ContextIntegration()
        with patch.object(integration._git, "discover_root", return_value=None):
            result = integration.detect()

        self.assertTrue(result["available"])
        self.assertEqual(result["active_app"], "vscode")
        self.assertEqual(result["active_app_raw"], "code")
        self.assertEqual(result["workflow"], "development")

    @patch("tact.agent.integrations.context.detection.os.environ", {})
    def test_detect_unavailable_without_display(self):
        integration = ContextIntegration()
        result = integration.detect()

        self.assertFalse(result["available"])
        self.assertIn("error", result)

    def test_override_and_clear(self):
        integration = ContextIntegration()
        result = integration.set_override("figma", "/home/user/design")
        self.assertTrue(result["ok"])
        self.assertEqual(integration._override["app"], "figma")

        detected = integration.detect()
        self.assertEqual(detected["active_app"], "figma")
        self.assertEqual(detected["project"], "/home/user/design")
        self.assertEqual(detected["workflow"], "design")

        result = integration.clear_override()
        self.assertTrue(result["ok"])
        self.assertIsNone(result["override"])

    def test_path_from_terminal_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            proj = Path(tmp) / "Tact"
            proj.mkdir()
            integration = ContextIntegration()
            path = integration._path_from_title(f"user@host: {proj} — konsole")
            self.assertEqual(path, str(proj))

    def test_terminal_title_ignores_missing_path(self):
        integration = ContextIntegration()
        path = integration._path_from_title("user@host: ~/does/not/exist")
        self.assertIsNone(path)

    def test_workflow_classification(self):
        from tact.agent.integrations.context.apps import classify

        self.assertEqual(classify("vscode"), "development")
        self.assertEqual(classify("teams"), "meeting")
        self.assertEqual(classify("spotify"), "media")
        self.assertIsNone(classify("unknown-app"))

    def test_monitor_emits_context_changed_on_change(self):
        from tact.agent.events import EventBus

        integration = ContextIntegration()
        window = {"id": "0x1", "class": "code", "title": "main.dart — Tact"}
        with patch("tact.agent.integrations.context.integration.active_window", return_value=window):
            integration.workspace_path = "/home/user/Tact"

            bus = EventBus()
            received = []
            bus.subscribe("context.changed", lambda e: received.append(e))

            integration.monitor(bus)  # first check: no event (baseline)
            self.assertEqual(len(received), 0)

            window["class"] = "spotify"
            window["title"] = "Spotify"
            integration.monitor(bus)  # changed -> event
            self.assertEqual(len(received), 1)
            self.assertEqual(received[0].event_type, "context.changed")
            self.assertEqual(received[0].data["active_app"], "spotify")

            integration.monitor(bus)  # unchanged -> no event
            self.assertEqual(len(received), 1)


if __name__ == "__main__":
    unittest.main()

