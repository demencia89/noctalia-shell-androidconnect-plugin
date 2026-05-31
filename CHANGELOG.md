# Changelog

## v1.5.0

- Tie embedded `scrcpy` sessions to the selected KDE Connect device so the panel does not show another phone's mirror.
- Add per-device Wireless ADB profiles keyed by KDE Connect device ID.
- Add Wireless ADB auto-detect for the selected phone's current mDNS connect port.
- Add diagnostics details for selected KDE host, resolved ADB serial, Wireless ADB profile state, and a compact connection verdict.
- Hide the decorative phone home indicator while the live embedded mirror is connected.
- Polish the connected-device switcher selected state.

## v1.4.0

- Stabilize first-run embedded mirror startup with `v4l2loopback exclusive_caps=0`.
- Keep Android navigation, screenshot, screen recording, keep-awake, and embedded audio controls in the panel.
