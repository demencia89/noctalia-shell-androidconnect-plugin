# AndroidConnect

`AndroidConnect` is a Noctalia plugin for Android device status, quick actions, file transfer, and embedded `scrcpy` control inside the panel.

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

Current plugin version: `1.2.4`

The plugin is now feed-only: the embedded phone view always uses the live `scrcpy` -> `v4l2loopback` feed path.

Current behavior:
- Embedded mirror launches automatically when the panel is ready
- Audio can be toggled from the panel header
- Android nav buttons stay visible below the phone preview
- Status and error messages stay hidden during the initial grace period, then appear only if the feed or input path is still not ready
- Opening the panel while `scrcpy` is already connected sends unlock-only, not Home

## Features

- KDE Connect device list, state, battery, signal, and notification summary
- Wake device, browse files, send files, and ring phone from the panel
- Embedded in-panel Android mirror
- Live V4L2 feed for the embedded mirror
- Optional embedded audio toggle, off by default
- ADB tap, swipe, text, key, and Android navigation input
- Wireless ADB pairing and reconnect helpers

## Dependencies

Required for the base plugin:
- Noctalia `>= 4.4.0`
- KDE Connect desktop app and a running `kdeconnectd`
- `busctl` from `systemd`

Required for mirror and Android input features:
- `scrcpy`
- `adb` from Android platform-tools
- Qt Multimedia runtime for your distro, for example `qt6-multimedia`

Required for embedded live `Feed` mode:
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
4. Create the V4L2 loopback device used by the embedded live feed.
5. Open the panel.

If ADB or the loopback feed is not ready, the plugin will now stay in setup/error state and tell you what is missing instead of blindly launching a broken mirror session.

## Base Setup

If you only want device status and KDE Connect actions:

1. Confirm `kdeconnectd` is running.
2. Enable the relevant KDE Connect phone-side plugins for battery, notifications, browse files, and remote actions.

## Embedded Mirror Setup

If you want the phone rendered inside the panel:

1. Create a V4L2 loopback device.
   Example:

```bash
sudo modprobe v4l2loopback video_nr=10 card_label=scrcpy-panel exclusive_caps=1
```

2. Make sure `/dev/video10` exists and `scrcpy-panel` is visible to Qt Multimedia.
3. Open the panel and wait for the embedded mirror to start.
4. Use the speaker button in the header if you want embedded audio.

Notes:
- The embedded mirror always uses the feed path.
- If the feed is unavailable, verify that the loopback device exists, is writable, and matches the configured label.
- If the phone is already mirrored when you open the plugin, AndroidConnect sends unlock-only and does not send Home.

## Wireless ADB Setup

Wireless ADB is optional, but it improves embedded input when USB is not available.

1. Open Android's `Wireless debugging` screen.
2. Use either:
   - `Pair with QR code`
   - `Pair with code`
3. Open the Wi-Fi button in the panel header.
4. After pairing, connect using the ADB port shown on the phone.

The plugin can remember the last successful host and port for later reconnects.

Notes:
- Wireless ADB is optional. USB ADB is still the simplest and most reliable first setup path.

## Browse Files Notes

The Browse Files action depends on KDE Connect's SFTP support.

If it fails:
- Check that the KDE Connect SFTP feature is enabled on the phone.
- Make sure `sshfs` and FUSE support are installed.
- If your file manager is sandboxed, it may not be able to access the mounted path.

## Development Notes

- This repository is intended to host the plugin in a downloadable state for other users.
- Local machine state should not be committed.
- The plugin still uses KDE Connect as its transport and device integration backend. `AndroidConnect` is a renamed and extended plugin package built on top of that foundation.
