import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool hideIfNoDeviceConnected: pluginApi?.mainInstance?.hideIfNoDeviceConnected ?? (pluginApi?.pluginSettings?.hideIfNoDeviceConnected ?? false)
  property string iconColor: cfg.iconColor ?? defaults.iconColor ?? "none"
  property string phoneClickAction: cfg.phoneClickAction ?? defaults.phoneClickAction ?? "wake-up"
  property string scrcpyCommand: cfg.scrcpyCommand ?? defaults.scrcpyCommand ?? "scrcpy"
  property bool scrcpyStopOnPanelClose: cfg.scrcpyStopOnPanelClose ?? defaults.scrcpyStopOnPanelClose ?? true
  property bool embeddedMirrorEnabled: cfg.embeddedMirrorEnabled ?? defaults.embeddedMirrorEnabled ?? true
  property string embeddedScrcpyCommand: cfg.embeddedScrcpyCommand ?? defaults.embeddedScrcpyCommand ?? "scrcpy --no-audio --capture-orientation=@0"
  property string mirrorPerformancePreset: cfg.mirrorPerformancePreset ?? defaults.mirrorPerformancePreset ?? "balanced"
  property string embeddedVideoEncoder: cfg.embeddedVideoEncoder ?? defaults.embeddedVideoEncoder ?? ""
  property string embeddedVideoCodecOptions: cfg.embeddedVideoCodecOptions ?? defaults.embeddedVideoCodecOptions ?? ""
  property bool mirrorReduceBackgroundPolling: cfg.mirrorReduceBackgroundPolling ?? defaults.mirrorReduceBackgroundPolling ?? true
  property bool mirrorDebugOverlayEnabled: cfg.mirrorDebugOverlayEnabled ?? defaults.mirrorDebugOverlayEnabled ?? false
  property string embeddedVideoDevice: cfg.embeddedVideoDevice ?? defaults.embeddedVideoDevice ?? "/dev/video10"
  property string embeddedVideoLabel: cfg.embeddedVideoLabel ?? defaults.embeddedVideoLabel ?? "scrcpy-panel"
  property string adbDeviceSerial: cfg.adbDeviceSerial ?? defaults.adbDeviceSerial ?? ""
  property bool wirelessAdbEnabled: cfg.wirelessAdbEnabled ?? defaults.wirelessAdbEnabled ?? true
  property string wirelessAdbCommand: cfg.wirelessAdbCommand ?? defaults.wirelessAdbCommand ?? "adb tcpip 5555"
  property int phoneSizePresetIndex: Math.max(0, Math.min(2, Number(cfg.phoneSizePresetIndex ?? defaults.phoneSizePresetIndex ?? 0)))

  spacing: Style.marginL

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NToggle {
        label: pluginApi?.tr("settings.no-device-connected-hide.label")
        description: pluginApi?.tr("settings.no-device-connected-hide.description")

        checked: root.hideIfNoDeviceConnected
        onToggled: function(checked) {
            root.hideIfNoDeviceConnected = checked
        }
    }

    NColorChoice {
      label: pluginApi?.tr("settings.iconColor.label")
      description: pluginApi?.tr("settings.iconColor.desc")
      currentKey: root.iconColor
      onSelected: key => root.iconColor = key
    }

    NComboBox {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.phone-action.label") || "Phone Click Action"
      description: pluginApi?.tr("settings.phone-action.description") || "Choose whether the phone tile wakes the device or launches scrcpy"
      model: [
        {
          "key": "wake-up",
          "name": pluginApi?.tr("settings.phone-action.options.wake-up") || "Wake device"
        },
        {
          "key": "scrcpy",
          "name": pluginApi?.tr("settings.phone-action.options.scrcpy") || "Launch scrcpy"
        }
      ]
      currentKey: root.phoneClickAction
      onSelected: key => root.phoneClickAction = key
    }

    NTextInput {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy"
      label: pluginApi?.tr("settings.scrcpy-command.label") || "scrcpy Command"
      description: pluginApi?.tr("settings.scrcpy-command.description") || "Shell command to run when the phone tile is clicked. Example: scrcpy -s <serial>"
      placeholderText: "scrcpy"
      text: root.scrcpyCommand
      onTextChanged: root.scrcpyCommand = text
    }

    NToggle {
      visible: root.phoneClickAction === "scrcpy"
      label: pluginApi?.tr("settings.scrcpy-stop-on-close.label") || "Stop scrcpy on Panel Close"
      description: pluginApi?.tr("settings.scrcpy-stop-on-close.description") || "Terminate the scrcpy process when this panel closes"
      checked: root.scrcpyStopOnPanelClose
      onToggled: checked => root.scrcpyStopOnPanelClose = checked
    }

    NToggle {
      visible: root.phoneClickAction === "scrcpy"
      label: pluginApi?.tr("settings.embedded-mirror-enabled.label") || "Embed Mirror in Panel"
      description: pluginApi?.tr("settings.embedded-mirror-enabled.description") || "Start scrcpy in no-window mode and render it inside the panel through a V4L2 loopback feed."
      checked: root.embeddedMirrorEnabled
      onToggled: checked => root.embeddedMirrorEnabled = checked
    }

    NTextInput {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.embedded-scrcpy-command.label") || "Embedded scrcpy Command"
      description: pluginApi?.tr("settings.embedded-scrcpy-command.description") || "Base scrcpy command for the in-panel mirror. The plugin appends --no-window and the V4L2 sink automatically."
      placeholderText: "scrcpy --no-audio --capture-orientation=@0"
      text: root.embeddedScrcpyCommand
      onTextChanged: root.embeddedScrcpyCommand = text
    }

    NComboBox {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.mirror-performance-preset.label") || "Mirror Performance Preset"
      description: pluginApi?.tr("settings.mirror-performance-preset.description") || "Tune the embedded mirror for lower latency or higher quality. Existing explicit scrcpy flags still win."
      model: [
        {
          "key": "balanced",
          "name": pluginApi?.tr("settings.mirror-performance-preset.options.balanced") || "Balanced"
        },
        {
          "key": "latency",
          "name": pluginApi?.tr("settings.mirror-performance-preset.options.latency") || "Low latency"
        },
        {
          "key": "quality",
          "name": pluginApi?.tr("settings.mirror-performance-preset.options.quality") || "Higher quality"
        }
      ]
      currentKey: root.mirrorPerformancePreset
      onSelected: key => root.mirrorPerformancePreset = key
    }

    NTextInput {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.embedded-video-device.label") || "Loopback Video Device"
      description: pluginApi?.tr("settings.embedded-video-device.description") || "Path to the v4l2loopback device scrcpy writes to, for example /dev/video10."
      placeholderText: "/dev/video10"
      text: root.embeddedVideoDevice
      onTextChanged: root.embeddedVideoDevice = text
    }

    NTextInput {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.embedded-video-label.label") || "Loopback Device Label"
      description: pluginApi?.tr("settings.embedded-video-label.description") || "Camera name fragment used by Qt Multimedia to match that loopback feed, for example scrcpy-panel."
      placeholderText: "scrcpy-panel"
      text: root.embeddedVideoLabel
      onTextChanged: root.embeddedVideoLabel = text
    }

    NTextInput {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.embedded-video-encoder.label") || "Pinned Video Encoder"
      description: pluginApi?.tr("settings.embedded-video-encoder.description") || "Optional scrcpy encoder override for this phone, for example c2.qti.avc.encoder."
      placeholderText: "c2.qti.avc.encoder"
      text: root.embeddedVideoEncoder
      onTextChanged: root.embeddedVideoEncoder = text
    }

    NTextInput {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.embedded-video-codec-options.label") || "Video Codec Options"
      description: pluginApi?.tr("settings.embedded-video-codec-options.description") || "Optional scrcpy video codec options passed through to Android's encoder."
      placeholderText: "priority:int=0"
      text: root.embeddedVideoCodecOptions
      onTextChanged: root.embeddedVideoCodecOptions = text
    }

    NTextInput {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.adb-device-serial.label") || "ADB Device Serial"
      description: pluginApi?.tr("settings.adb-device-serial.description") || "Optional. Leave empty to use the default adb device, or the saved Wireless ADB host and port if wireless fallback is enabled."
      placeholderText: "192.168.1.113:43901"
      text: root.adbDeviceSerial
      onTextChanged: root.adbDeviceSerial = text
    }

    NToggle {
      visible: root.phoneClickAction === "scrcpy"
      label: pluginApi?.tr("settings.wireless-adb-enabled.label") || "Enable Wireless ADB"
      description: pluginApi?.tr("settings.wireless-adb-enabled.description") || "Show Wireless ADB tools and allow the plugin to reuse the saved phone IP and port. Disable this for cable-only ADB."
      checked: root.wirelessAdbEnabled
      onToggled: checked => root.wirelessAdbEnabled = checked
    }

    NToggle {
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.mirror-reduce-background-polling.label") || "Reduce Background Polling While Mirroring"
      description: pluginApi?.tr("settings.mirror-reduce-background-polling.description") || "Slow KDE Connect refreshes while the embedded mirror is active to free a bit of headroom."
      checked: root.mirrorReduceBackgroundPolling
      onToggled: checked => root.mirrorReduceBackgroundPolling = checked
    }

    NToggle {
      visible: root.phoneClickAction === "scrcpy" && root.embeddedMirrorEnabled
      label: pluginApi?.tr("settings.mirror-debug-overlay-enabled.label") || "Enable Mirror Debug Overlay"
      description: pluginApi?.tr("settings.mirror-debug-overlay-enabled.description") || "Show a compact performance pill in the panel and append --print-fps to scrcpy for extra logs."
      checked: root.mirrorDebugOverlayEnabled
      onToggled: checked => root.mirrorDebugOverlayEnabled = checked
    }

    NTextInput {
      Layout.fillWidth: true
      visible: root.phoneClickAction === "scrcpy" && root.wirelessAdbEnabled
      label: pluginApi?.tr("settings.wireless-adb-command.label") || "ADB TCP/IP Helper Command"
      description: pluginApi?.tr("settings.wireless-adb-command.description") || "Legacy helper command available inside the panel's Wireless ADB dialog. The default uses adb tcpip 5555 for an already authorized ADB device; it does not toggle Android's Wireless debugging switch."
      placeholderText: "adb tcpip 5555"
      text: root.wirelessAdbCommand
      onTextChanged: root.wirelessAdbCommand = text
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("KDEConnect", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.hideIfNoDeviceConnected = root.hideIfNoDeviceConnected;
    pluginApi.pluginSettings.iconColor = root.iconColor;
    pluginApi.pluginSettings.phoneClickAction = root.phoneClickAction;
    pluginApi.pluginSettings.scrcpyCommand = root.scrcpyCommand;
    pluginApi.pluginSettings.scrcpyStopOnPanelClose = root.scrcpyStopOnPanelClose;
    pluginApi.pluginSettings.embeddedMirrorEnabled = root.embeddedMirrorEnabled;
    pluginApi.pluginSettings.embeddedScrcpyCommand = root.embeddedScrcpyCommand;
    pluginApi.pluginSettings.mirrorPerformancePreset = root.mirrorPerformancePreset;
    pluginApi.pluginSettings.embeddedVideoEncoder = root.embeddedVideoEncoder;
    pluginApi.pluginSettings.embeddedVideoCodecOptions = root.embeddedVideoCodecOptions;
    pluginApi.pluginSettings.mirrorReduceBackgroundPolling = root.mirrorReduceBackgroundPolling;
    pluginApi.pluginSettings.mirrorDebugOverlayEnabled = root.mirrorDebugOverlayEnabled;
    pluginApi.pluginSettings.embeddedVideoDevice = root.embeddedVideoDevice;
    pluginApi.pluginSettings.embeddedVideoLabel = root.embeddedVideoLabel;
    pluginApi.pluginSettings.adbDeviceSerial = root.adbDeviceSerial;
    pluginApi.pluginSettings.wirelessAdbEnabled = root.wirelessAdbEnabled;
    pluginApi.pluginSettings.wirelessAdbCommand = root.wirelessAdbCommand;
    pluginApi.pluginSettings.phoneSizePresetIndex = root.phoneSizePresetIndex;
    pluginApi.saveSettings();

    Logger.d("KDEConnect", "Settings saved successfully");
  }
}
