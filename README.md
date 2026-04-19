# AndroidConnect

`AndroidConnect` is a Noctalia plugin for Android device status, quick actions, file transfer, and embedded `scrcpy` control directly inside the panel.

This project is built on top of the original Noctalia `kde-connect` plugin. Credit and thanks to the original Noctalia KDE Connect plugin developers for the base plugin and architecture this work extends.

Upstream base project:
- https://github.com/WerWolv/noctalia-kde-connect

Project repository:
- https://github.com/demencia89/noctalia-shell-androidconnect-plugin

## Screenshots

### Plugin Preview

![AndroidConnect plugin preview](preview.png)

### Panel Overview

![AndroidConnect panel overview](Docs/Screenshots/androidconnect-panel-overview.png)

### Lock Screen View

![AndroidConnect lock screen view](Docs/Screenshots/androidconnect-lock-screen.png)

### Panel Close-up

![AndroidConnect panel close-up](Docs/Screenshots/androidconnect-panel-closeup.png)

## Current Status

Current plugin version: `1.3.0`

The embedded mirror uses a single live feed path:

- `scrcpy` writes into `v4l2loopback`
- Qt Multimedia reads that loopback device inside the panel
- There is no second mirror backend in the normal path

Current behavior:
- Embedded mirror launches automatically when the panel is ready
- Audio can be toggled from the panel header
- Android nav buttons stay visible below the phone preview
- Screenshot and screen recording actions are available from the right-side utility row
- Keep-screen-awake is available from the utility row while the panel is open
- Status and error messages stay hidden during the initial grace period, then appear only if the feed or input path is still not ready
- Opening the panel while `scrcpy` is already connected sends unlock-only, not Home
- Header brand badges use logo assets where available and fall back to icons otherwise

## Features

- KDE Connect device list, state, battery, signal, and notification summary
- Wake device, browse files, send files, and ring phone from the panel
- Embedded in-panel Android mirror
- Live V4L2 feed for the embedded mirror
- Optional embedded audio toggle, off by default
- ADB tap, swipe, text, key, and Android navigation input
- In-panel utility actions for screenshot, screen recording, and keep-screen-awake
- Wireless ADB pairing and reconnect helpers
- Existing plugin toasts are mirrored into notification history
- Screenshot and screen recording save notifications include a link to the output folder

## Dependencies

Required for the base plugin:
- Noctalia `>= 4.4.0`
- KDE Connect desktop app and a running `kdeconnectd`
- `busctl` from `systemd`

Required for mirror and Android input features:
- `scrcpy`
- `adb` from Android platform-tools
- Qt Multimedia runtime for your distro, for example `qt6-multimedia`

Required for the embedded live feed:
- `v4l2loopback`
- A loopback device such as `/dev/video10`
- A loopback label visible to Qt Multimedia, for example `scrcpy-panel`

Required for some optional features:
- `qrencode` for Wireless ADB QR pairing
- `sshfs` and FUSE support for the Browse Files action

Recommended:
- `avahi-browse` for more reliable Wireless ADB service discovery

Not versioned in this repository:
- `settings.json` is local user state and should stay untracked

## Install

1. Copy this plugin directory into your Noctalia plugins directory.
   Example: `~/.config/noctalia/plugins/androidconnect`
2. Reload Noctalia or restart the shell so it picks up the plugin.
3. Enable the plugin in Noctalia.
4. Make sure KDE Connect is installed on both the desktop and phone, then pair the phone normally.

## First-Time Setup

If you want the default experience, which is embedded `scrcpy` inside the panel:

1. Install `scrcpy`, `adb`, Qt Multimedia, and `v4l2loopback`.
2. On the phone, enable Developer options and USB debugging.
3. Connect the phone over USB once, unlock it, and accept the USB debugging prompt for this computer.
4. Create the V4L2 loopback device used by the embedded feed.
5. Open the panel.

If ADB or the loopback feed is not ready, the plugin stays in a setup or error state and tells you what is missing instead of launching a broken mirror session.

## Base Setup

If you only want device status and KDE Connect actions:

1. Confirm `kdeconnectd` is running.
2. Enable the relevant KDE Connect phone-side plugins for battery, notifications, browse files, and remote actions.

## Embedded Mirror Setup

If you want the phone rendered inside the panel:

1. Create a V4L2 loopback device.
   Example:

```bash
sudo modprobe -r v4l2loopback 2>/dev/null || true
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label=scrcpy-panel exclusive_caps=0 max_width=960 max_height=2160
```

2. Make sure `/dev/video10` exists and `scrcpy-panel` is visible to Qt Multimedia.
3. Open the panel and wait for the embedded mirror to start.
4. Use the speaker button in the header if you want embedded audio.

Notes:
- The embedded mirror always uses the feed path.
- If the feed is unavailable, verify that the loopback device exists, matches the configured label, and is not using `exclusive_caps=1`.
- In practice, `exclusive_caps=0` is the expected working setup for `scrcpy` writing and the panel reading the same device.
- If the phone is already mirrored when you open the plugin, AndroidConnect sends unlock-only and does not send Home.

## Panel Controls

### Header Actions

- Device switcher when more than one phone is available
- Phone size toggle
- Embedded audio toggle
- Wireless ADB tools
- Browse files
- Send file
- Find phone

### Mirror Navigation Row

- `Back`
- `Home`
- `Recents`

Mouse and keyboard shortcuts:
- Right click on the phone view sends `Back`
- Middle click on the phone view sends `Recents`
- `Home` key sends `Home`
- Arrow keys, Enter, Tab, Escape, Delete, and Backspace are forwarded to Android when the phone view is focused
- Text typed into the focused phone view is sent to Android input

### Utility Actions

These appear in the utility action row under battery, network, and signal:

- `Take Screenshot`
- `Start / Stop Recording`
- `Keep Screen Awake`

Saved media locations:
- Screenshots: `~/Pictures/AndroidConnect`
- Screen recordings: `~/Videos/AndroidConnect`

When a screenshot or recording finishes, AndroidConnect adds the same event to notification history and includes a link to open the output folder.

## Wireless ADB Setup

Wireless ADB is optional, but it improves embedded input when USB is not available.

1. Open Android's `Wireless debugging` screen.
2. Use either:
   - `Pair with QR code`
   - `Pair with code`
3. Open the Wi-Fi button in the panel header.
4. After pairing, connect using the ADB port shown on the phone.

The plugin remembers the last successful host and port for later reconnects.

Notes:
- Wireless ADB is optional. USB ADB is still the simplest and most reliable first setup path.

## Browse Files Notes

The Browse Files action depends on KDE Connect's SFTP support.

If it fails:
- Check that the KDE Connect SFTP feature is enabled on the phone.
- Make sure `sshfs` and FUSE support are installed.
- If your file manager is sandboxed, it may not be able to access the mounted path.

## Troubleshooting

## Known Issues

- The embedded screen can sometimes remain black even when the rest of the plugin is working. Restarting the shell usually fixes it. In some cases it may take two shell restarts before the screen mirrors correctly again.
- The embedded screen can sometimes appear glitchy or partially broken. Closing the plugin and opening it again usually fixes it. If not, restart the shell.

### Black Screen In The Embedded Mirror

Check the following first:

- `scrcpy`, `adb`, and Qt Multimedia are installed
- `/dev/video10` exists
- the loopback label is visible as `scrcpy-panel`
- `v4l2loopback` was created with `exclusive_caps=0`

Recommended checks:

```bash
v4l2-ctl --get-fmt-video -d /dev/video10
v4l2-ctl --list-formats-ext -d /dev/video10
cat /sys/devices/virtual/video4linux/video10/format
cat /sys/module/v4l2loopback/parameters/exclusive_caps
```

AndroidConnect also writes mirror diagnostics to:

```text
/tmp/androidconnect-preview-debug.log
```

### Loopback Format Notes

The plugin expects a Qt-readable camera format from the loopback device. If the device exists but Qt still renders black, inspect the current loopback format and rebuild the loopback device if needed.

## Development Notes

- This repository is intended to host the plugin in a downloadable state for other users.
- Local machine state should not be committed.
- The plugin still uses KDE Connect as its transport and device integration backend. `AndroidConnect` is a renamed and extended plugin package built on top of that foundation.
