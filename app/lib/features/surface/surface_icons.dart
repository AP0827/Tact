import 'package:flutter/material.dart';

/// Icon vocabulary shared by surface definitions (agent) and the phone UI.
/// Keep in sync with the icon strings in
/// tact/agent/integrations/context/surfaces.py.
IconData surfaceIcon(String name) => switch (name) {
      'code' => Icons.code,
      'terminal' => Icons.terminal,
      'public' => Icons.public,
      'music_note' => Icons.music_note,
      'apps' => Icons.apps,
      'lock' => Icons.lock,
      'screenshot' => Icons.screenshot,
      'download' => Icons.download,
      'upload' => Icons.upload,
      'refresh' => Icons.refresh,
      'play' => Icons.play_arrow,
      'pause' => Icons.pause,
      'skip_next' => Icons.skip_next,
      'skip_previous' => Icons.skip_previous,
      'mute' => Icons.volume_off,
      'volume_up' => Icons.volume_up,
      'volume_down' => Icons.volume_down,
      'link' => Icons.link,
      'folder_open' => Icons.folder_open,
      'git' => Icons.call_split,
      'arrow_back' => Icons.arrow_back,
      'arrow_forward' => Icons.arrow_forward,
      'add' => Icons.add,
      'external_link' => Icons.open_in_new,
      'bug' => Icons.bug_report,
      'test_tube' => Icons.science,
      'file_open' => Icons.insert_drive_file,
      'mic_off' => Icons.mic_off,
      'videocam_off' => Icons.videocam_off,
      'call_end' => Icons.call_end,
      'groups' => Icons.groups,
      _ => Icons.bolt,
    };