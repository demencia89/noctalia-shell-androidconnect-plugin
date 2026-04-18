# AndroidConnect

`AndroidConnect` is a Noctalia plugin for Android device status, quick actions, file transfer, and embedded `scrcpy` control inside the panel.

## Support

If you want to support ongoing work on AndroidConnect and the surrounding Noctalia projects, sponsor the work through GitHub Sponsors at [@demencia89](https://github.com/sponsors/demencia89).

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

Current plugin version: `1.2.2`

The plugin is currently shaped for real user installs, not just local experimentation.

Current first-run defaults:
- `Phone Click Action` defaults to `Launch scrcpy`
- Embedded mirror defaults to enabled
- Wireless ADB defaults to enabled
- Embedded audio defaults to off

Known-good behavior currently preserved:
- Live `Feed` mode works.
- Manual `Fallback` mode is ADB screenshot mode, timer-driven at 80 ms.
- The `Fallback` / `Feed` toggle persists across panel close and reopen.
- The `Fallback` / `Feed` toggle is the left-most button in the top header row.
- The embedded audio toggle is present in the top header row, to the left of the Wi-Fi button.
- Opening the plugin while `scrcpy` is already connected sends unlock-only, not Home.
- The bottom Android nav row is hidden while `scrcpy` is connected.
- The status/error card hides completely when there is nothing to show.

Recent release-polish changes:
- Added first-time setup guidance in plugin settings.
- The panel now stays in setup/error state instead of trying to auto-start `scrcpy` when ADB is missing, unauthorized, offline, or the loopback feed is not ready.
- Removed the destructive V4L2 consumer-kill recovery path.
- Hardened command execution so configured `scrcpy` and ADB helper commands run as parsed argv instead of through a shell wrapper.
- Made mirror snapshot and Wireless ADB QR temp files instance-scoped in `/tmp`.
- Made ADB snapshot writes atomic to avoid stale or partially-written preview frames.
- Matched the mobile network icon to the actual reported radio type, including distinct `LTE`, `4G`, and `5G` states.
- Added user-facing notifications when Browse Files or Send File actions fail, so failures are visible instead of disappearing silently.
- Suppressed transient status, warning, and error surfaces for the first 5 seconds after the drawer opens.
- Delayed the embedded mirror fallback suggestion until the drawer has been open for 8 seconds and the live feed is still failing.
- Kept the supported fallback path as snapshot mode only. Overlay fallback was not reintroduced.

## Features

- KDE Connect device list, state, battery, signal, and notification summary
- Wake device, browse files, send files, and ring phone from the panel
- Launch plain `scrcpy`
- Embedded in-panel Android mirror
- Live V4L2 `Feed` mode for the embedded mirror
- Manual snapshot `Fallback` mode for unstable feed environments
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

If you want the current default experience, which is embedded `scrcpy` inside the panel:

1. Install `scrcpy`, `adb`, Qt Multimedia, and `v4l2loopback`.
2. On the phone, enable Developer options and USB debugging.
3. Connect the phone over USB once, unlock it, and accept the USB debugging prompt for this computer.
4. Create the V4L2 loopback device used by the embedded live feed.
5. Open plugin settings and confirm:
   - `Phone Click Action` is `Launch scrcpy`
   - `Embed Mirror in Panel` is enabled
   - `Loopback Video Device` matches your loopback node, for example `/dev/video10`
   - `Loopback Device Label` matches the loopback label, for example `scrcpy-panel`
6. Open the panel.

If ADB or the loopback feed is not ready, the plugin will now stay in setup/error state and tell you what is missing instead of blindly launching a broken mirror session.

## Base Setup

If you only want device status and KDE Connect actions:

1. Confirm `kdeconnectd` is running.
2. Enable the relevant KDE Connect phone-side plugins for battery, notifications, browse files, and remote actions.
3. In plugin settings, change `Phone Click Action` to `Wake device` if you do not want `scrcpy`.

## scrcpy Setup

If you want panel-launched `scrcpy`:

1. Install `scrcpy` and `adb`.
2. Leave `Phone Click Action` on `Launch scrcpy`. This is the current default.
3. Leave `scrcpy Command` as `scrcpy` or set your own command, for example a serial-specific launch command.
4. Make sure the phone is authorized in `adb` before expecting panel control or unlock behavior.

## Embedded Mirror Setup

If you want the phone rendered inside the panel:

1. Keep `Phone Click Action` on `Launch scrcpy`.
2. Keep `Embed Mirror in Panel` enabled. This is the current default.
3. Create a V4L2 loopback device.
   Example:

```bash
sudo modprobe v4l2loopback video_nr=10 card_label=scrcpy-panel exclusive_caps=1
```

4. In plugin settings, set:
   - `Loopback Video Device` to `/dev/video10`
   - `Loopback Device Label` to `scrcpy-panel`
   - `Embedded scrcpy Command` to a working base command, usually `scrcpy --no-audio --capture-orientation=@0`
   - Leave embedded audio off unless you want it. You can toggle it from the speaker button in the panel header.
5. Open the panel and start the mirror.

Notes:
- `Feed` is the preferred live mode.
- `Fallback` is the supported manual snapshot mode.
- The `Fallback` / `Feed` toggle is persistent across panel reopen.
- If the feed is unavailable, verify that the loopback device exists, is writable, and matches the configured label.
- If the phone is already mirrored when you open the plugin, AndroidConnect sends unlock-only and does not send Home.

## Wireless ADB Setup

Wireless ADB is optional, but it improves embedded input when USB is not available.

1. Keep `Enable Wireless ADB` enabled in plugin settings.
2. Open Android's `Wireless debugging` screen.
3. Use either:
   - `Pair with QR code`
   - `Pair with code`
4. Open the Wi-Fi button in the panel header.
5. After pairing, connect using the ADB port shown on the phone.

The plugin can remember the last successful host and port for later reconnects.

Notes:
- Wireless ADB is optional. USB ADB is still the simplest and most reliable first setup path.
- The Wireless ADB popup also has a cable-only mode if you want this plugin to avoid wireless fallback entirely.

## Browse Files Notes

The Browse Files action depends on KDE Connect's SFTP support.

If it fails:
- Check that the KDE Connect SFTP feature is enabled on the phone.
- Make sure `sshfs` and FUSE support are installed.
- If your file manager is sandboxed, it may not be able to access the mounted path.
- AndroidConnect now also shows a notification when Browse Files or Send File fails so the error stays visible while debugging.

## Plugin Manager Sync

This repository includes a GitHub Actions workflow at `.github/workflows/sync-plugin-manager.yml`.

When you publish a GitHub release, it syncs this repository into:

- repository: `demencia89/noctalia-plugins`
- branch: `add-androidconnect-plugin`
- path: `androidconnect/`

That branch is intended to stay aligned with the plugin-manager submission, so pushes to it update the existing pull request automatically if one is already open.

Required repository secret:

- `NOCTALIA_PLUGINS_SYNC_TOKEN`

Recommended token shape:

- Fine-grained personal access token
- Repository access limited to `demencia89/noctalia-plugins`
- Repository permissions:
  - `Contents: Read and write`

The workflow runs on published releases and can also be triggered manually with `workflow_dispatch`.

## Development Notes

- This repository is intended to host the plugin in a downloadable state for other users.
- Local machine state should not be committed.
- The plugin still uses KDE Connect as its transport and device integration backend. `AndroidConnect` is a renamed and extended plugin package built on top of that foundation.
