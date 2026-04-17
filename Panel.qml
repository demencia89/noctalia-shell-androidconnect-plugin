import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "./Services"
import Quickshell

// Panel Component
Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // SmartPanel
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool panelAnchorTop: true
  readonly property bool panelAnchorRight: true

  property real contentPreferredWidth: {
    if (phoneSizePresetIndex === 0)
      return 560 * Style.uiScaleRatio;
    if (phoneSizePresetIndex === 1)
      return 620 * Style.uiScaleRatio;
    return 680 * Style.uiScaleRatio;
  }
  property real contentPreferredHeight: deviceData.implicitHeight + (Style.marginM * 2)

  readonly property bool allowAttach: true
  readonly property color panelBackgroundColor: embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning && !embeddedMirrorFeedModeEnabled()
    ? "transparent"
    : Color.mSurface
  readonly property bool blurEnabled: !(embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning && !embeddedMirrorFeedModeEnabled())
  readonly property string phoneClickAction: cfg.phoneClickAction ?? defaults.phoneClickAction ?? "wake-up"
  readonly property string scrcpyCommand: cfg.scrcpyCommand ?? defaults.scrcpyCommand ?? "scrcpy"
  readonly property bool scrcpyStopOnPanelClose: cfg.scrcpyStopOnPanelClose ?? defaults.scrcpyStopOnPanelClose ?? true
  readonly property string wirelessAdbCommand: cfg.wirelessAdbCommand ?? defaults.wirelessAdbCommand ?? "adb tcpip 5555"
  readonly property bool embeddedMirrorEnabled: cfg.embeddedMirrorEnabled ?? defaults.embeddedMirrorEnabled ?? true
  readonly property string embeddedScrcpyCommand: cfg.embeddedScrcpyCommand ?? defaults.embeddedScrcpyCommand ?? "scrcpy --no-audio --capture-orientation=@0"
  readonly property string mirrorPerformancePreset: cfg.mirrorPerformancePreset ?? defaults.mirrorPerformancePreset ?? "balanced"
  readonly property string embeddedVideoEncoder: cfg.embeddedVideoEncoder ?? defaults.embeddedVideoEncoder ?? ""
  readonly property string embeddedVideoCodecOptions: cfg.embeddedVideoCodecOptions ?? defaults.embeddedVideoCodecOptions ?? ""
  readonly property bool mirrorReduceBackgroundPolling: cfg.mirrorReduceBackgroundPolling ?? defaults.mirrorReduceBackgroundPolling ?? true
  readonly property bool mirrorDebugOverlayEnabled: cfg.mirrorDebugOverlayEnabled ?? defaults.mirrorDebugOverlayEnabled ?? false
  readonly property string embeddedVideoDevice: cfg.embeddedVideoDevice ?? defaults.embeddedVideoDevice ?? "/dev/video10"
  readonly property string embeddedVideoLabel: cfg.embeddedVideoLabel ?? defaults.embeddedVideoLabel ?? "scrcpy-panel"
  readonly property int embeddedMirrorSnapshotIntervalMs: Math.max(
    10,
    Math.round(cfg.embeddedMirrorSnapshotIntervalMs ?? defaults.embeddedMirrorSnapshotIntervalMs ?? 80)
  )
  readonly property string adbDeviceSerialOverride: cfg.adbDeviceSerial ?? defaults.adbDeviceSerial ?? ""
  readonly property bool wirelessAdbEnabled: cfg.wirelessAdbEnabled ?? defaults.wirelessAdbEnabled ?? true
  property string wirelessAdbPairHost: cfg.wirelessAdbPairHost ?? defaults.wirelessAdbPairHost ?? ""
  property string wirelessAdbPairPort: cfg.wirelessAdbPairPort ?? defaults.wirelessAdbPairPort ?? ""
  property string wirelessAdbPairingCode: ""
  property string wirelessAdbConnectHost: cfg.wirelessAdbConnectHost ?? defaults.wirelessAdbConnectHost ?? ""
  property string wirelessAdbConnectPort: cfg.wirelessAdbConnectPort ?? defaults.wirelessAdbConnectPort ?? ""
  property string wirelessAdbStatusMessage: ""
  property string wirelessAdbQrInstanceName: ""
  property string wirelessAdbQrSecret: ""
  property bool wirelessAdbQrPendingLaunch: false
  property int wirelessAdbQrImageVersion: 0
  property bool wirelessAdbSessionPreferred: false
  property bool lastKnownUsbTransport: false
  property var cachedDeviceTelemetry: initialCachedDeviceTelemetry()
  readonly property string tempInstanceToken: makeTempInstanceToken()
  readonly property string wirelessAdbQrImagePath: "/tmp/androidconnect-wireless-adb-" + tempInstanceToken + ".png"
  readonly property string embeddedMirrorSnapshotPath: "/tmp/androidconnect-mirror-" + tempInstanceToken + ".jpg"
  readonly property real phoneBaseHeight: 732 * Style.uiScaleRatio
  readonly property real phoneBaseWidth: phoneBaseHeight * (597 / 1241)
  property int phoneSizePresetIndex: initialPhoneSizePresetIndex()
  readonly property real phoneSizeFactor: phoneSizePresetIndex === 0
    ? 0.60
    : (phoneSizePresetIndex === 1 ? 0.75 : 1.0)
  readonly property int phoneSizePercent: phoneSizePresetIndex === 0
    ? 60
    : (phoneSizePresetIndex === 1 ? 75 : 100)
  readonly property string phoneSizeLabel: phoneSizePresetIndex === 0
    ? "Small"
    : (phoneSizePresetIndex === 1 ? "Med" : "Large")
  readonly property real navButtonScaleFactor: phoneSizePresetIndex === 0
    ? 0.82
    : (phoneSizePresetIndex === 1 ? 0.91 : 1.0)
  readonly property var panelResizeBezierCurve: [0.05, 0, 0.133, 0.06, 0.166, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]
  property bool phoneSizeAnimationEnabled: false
  property int phoneSizeStepDirection: initialPhoneSizeStepDirection()

  property bool deviceSwitcherOpen: false
  property var activePhonePreview: null
  property bool embeddedVideoDeviceAccessible: false
  property bool embeddedVideoDeviceCheckKnown: false
  readonly property bool embeddedMirrorDiagnosticsEnabled: mirrorDebugOverlayEnabled
  property bool embeddedMirrorForceSnapshotFallback: Boolean(
    cfg.embeddedMirrorForceSnapshotFallback
    ?? defaults.embeddedMirrorForceSnapshotFallback
    ?? false
  )
  property bool embeddedMirrorPendingSessionRecovery: false
  property var embeddedMirrorRecoveryPreview: null
  property string embeddedMirrorRecoveryReason: ""
  property bool embeddedMirrorUsbRestoreRecoveryPending: false
  property bool panelOpenUnlockPending: false
  property int panelOpenUnlockRetriesRemaining: 0
  readonly property bool passthroughHoleEnabled: embeddedMirrorModeEnabled()
    && KDEConnect.scrcpyRunning
    && KDEConnect.scrcpyWindowReady
    && KDEConnect.scrcpyWindowFloating
    && activePhonePreview !== null
  readonly property point passthroughHolePosition: {
    if (!activePhonePreview)
      return Qt.point(0, 0);

    return activePhonePreview.mapToItem(
      root,
      activePhonePreview.videoFrameLocalX,
      activePhonePreview.videoFrameLocalY
    );
  }
  readonly property real passthroughHoleX: passthroughHolePosition.x
  readonly property real passthroughHoleY: passthroughHolePosition.y
  readonly property real passthroughHoleWidth: activePhonePreview ? activePhonePreview.videoFrameGlobalWidth : 0
  readonly property real passthroughHoleHeight: activePhonePreview ? activePhonePreview.videoFrameGlobalHeight : 0
  readonly property real passthroughHoleRadius: activePhonePreview ? activePhonePreview.videoFrameRadius : 0

  anchors.fill: parent

  Timer {
    id: scrcpyOverlaySyncTimer
    interval: 350
    repeat: true
    running: root.embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning && !root.embeddedMirrorFeedModeEnabled()
    onTriggered: {
      if (root.activePhonePreview)
        root.syncEmbeddedMirrorOverlay(root.activePhonePreview);
    }
  }

  Timer {
    id: scrcpySnapshotTimer
    interval: root.embeddedMirrorSnapshotIntervalMs
    repeat: true
    running: root.embeddedMirrorFeedModeEnabled()
      && KDEConnect.scrcpyRunning
      && (root.embeddedMirrorForceSnapshotFallback
          || !root.activePhonePreview
          || !root.activePhonePreview.mirrorDisplayVisible)
    onTriggered: {
      root.requestEmbeddedMirrorSnapshotFrame();
    }
  }

  Timer {
    id: embeddedMirrorFeedWatchdog
    interval: 2500
    repeat: true
    running: false
    onTriggered: {
      if (!root.embeddedMirrorFeedSessionDegraded(root.activePhonePreview, 4500))
        return;

      root.requestEmbeddedMirrorSessionRecovery(root.activePhonePreview, "qt-no-input");
    }
  }

  Timer {
    id: embeddedMirrorRecoveryTimer
    interval: 220
    repeat: false
    onTriggered: {
      const preview = root.embeddedMirrorRecoveryPreview || root.activePhonePreview;
      root.embeddedMirrorPendingSessionRecovery = false;
      root.embeddedMirrorRecoveryPreview = null;
      Qt.callLater(function() {
        root.ensureEmbeddedMirrorSession(preview);
      });
    }
  }

  Timer {
    id: embeddedMirrorAutoStartTimer
    interval: 180
    repeat: false
    onTriggered: {
      root.attemptEmbeddedMirrorAutoStart();
    }
  }

  Timer {
    id: embeddedMirrorUsbRestoreTimer
    interval: 420
    repeat: false
    onTriggered: {
      root.embeddedMirrorUsbRestoreRecoveryPending = false;

      if (!root.visible || !root.embeddedMirrorModeEnabled())
        return;

      if (root.embeddedMirrorFallbackActive(root.activePhonePreview)) {
        root.requestEmbeddedMirrorSessionRecovery(root.activePhonePreview, "usb-restored-reset");
        return;
      }

      root.scheduleEmbeddedMirrorAutoStart();
    }
  }

  Timer {
    id: panelOpenUnlockTimer
    interval: 240
    repeat: false
    onTriggered: {
      if (!root.panelOpenUnlockPending || !root.visible || !root.embeddedMirrorModeEnabled()) {
        root.panelOpenUnlockPending = false;
        root.panelOpenUnlockRetriesRemaining = 0;
        return;
      }

      if (!KDEConnect.scrcpyRunning || KDEConnect.scrcpyLaunching) {
        if (root.panelOpenUnlockRetriesRemaining > 0) {
          root.panelOpenUnlockRetriesRemaining -= 1;
          restart();
        } else {
          root.panelOpenUnlockPending = false;
        }
        return;
      }

      if (!root.embeddedMirrorTouchActive()) {
        root.refreshEmbeddedMirrorTouchMapping();
        if (root.panelOpenUnlockRetriesRemaining > 0) {
          root.panelOpenUnlockRetriesRemaining -= 1;
          restart();
        } else {
          root.panelOpenUnlockPending = false;
        }
        return;
      }

      root.panelOpenUnlockPending = false;
      root.panelOpenUnlockRetriesRemaining = 0;
      root.sendAndroidUnlockOnly();
    }
  }

  Timer {
    id: adbDevicesRefreshTimer
    interval: 2500
    repeat: true
    running: root.visible && phoneClickAction === "scrcpy"
    onTriggered: {
      KDEConnect.refreshAdbDevices();
    }
  }

  Timer {
    id: mirrorPerfProbeTimer
    interval: 120
    repeat: true
    running: root.mirrorDebugOverlayEnabled
      && root.embeddedMirrorModeEnabled()
      && KDEConnect.scrcpyRunning
      && KDEConnect.scrcpyFirstFrameLatencyMs < 0
    onTriggered: {
      root.captureMirrorFirstFrameLatency();
    }
  }

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("KDEConnect", "Panel initialized");
    }
    root.syncBackgroundRefreshPolicy();
    KDEConnect.refreshAdbDevices();
    Qt.callLater(function() {
      root.refreshEmbeddedVideoDeviceAccess();
    });
  }

  onEmbeddedVideoDeviceChanged: {
    embeddedVideoDeviceCheckKnown = false;
    embeddedVideoDeviceAccessible = false;
    Qt.callLater(function() {
      root.refreshEmbeddedVideoDeviceAccess();
    });
  }

  onPhoneSizePresetIndexChanged: {
    if (root.activePhonePreview
        && root.embeddedMirrorModeEnabled()
        && KDEConnect.scrcpyRunning
        && !root.embeddedMirrorFeedModeEnabled()) {
      Qt.callLater(function() {
        root.syncEmbeddedMirrorOverlay(root.activePhonePreview);
      });
    }
  }

  Connections {
    target: KDEConnect

    function onScrcpyRunningChanged() {
      root.syncBackgroundRefreshPolicy();
      if (!KDEConnect.scrcpyRunning) {
        if (root.embeddedMirrorPendingSessionRecovery
            && root.visible
            && root.embeddedMirrorModeEnabled()
            && root.activePhonePreview) {
          const preview = root.activePhonePreview;
          root.embeddedMirrorRecoveryPreview = preview;
          if (preview.reloadMediaDevices)
            preview.reloadMediaDevices();
          embeddedMirrorRecoveryTimer.restart();
        }
        return;
      }

      if (root.visible && root.panelOpenUnlockPending)
        panelOpenUnlockTimer.restart();

      if (root.visible && root.embeddedMirrorSnapshotFallbackForced())
        Qt.callLater(function() {
          root.requestEmbeddedMirrorSnapshotFrame();
        });

      if (root.embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning && root.activePhonePreview) {
        root.embeddedMirrorRecoveryReason = "";
        Qt.callLater(function() {
          root.refreshEmbeddedMirrorTouchMapping();
          if (!root.embeddedMirrorFeedModeEnabled())
            root.syncEmbeddedMirrorOverlay(root.activePhonePreview);
        });
      }
    }

    function onAdbDevicesRefreshed() {
      const usbTransportLost = root.lastKnownUsbTransport && !KDEConnect.adbHasUsbTransport;
      const usbTransportRestored = !root.lastKnownUsbTransport && KDEConnect.adbHasUsbTransport;
      root.lastKnownUsbTransport = KDEConnect.adbHasUsbTransport;

      if (usbTransportRestored)
        root.wirelessAdbSessionPreferred = false;

      if ((usbTransportLost || usbTransportRestored) && root.embeddedMirrorFeedConfigured()) {
        const preview = root.activePhonePreview;
        if (preview && preview.reloadMediaDevices)
          preview.reloadMediaDevices();

        root.embeddedVideoDeviceCheckKnown = false;
        root.embeddedVideoDeviceAccessible = false;
        Qt.callLater(function() {
          root.refreshEmbeddedVideoDeviceAccess();
        });
      }

      if (usbTransportLost
          && root.embeddedMirrorModeEnabled()
          && KDEConnect.scrcpyRunning
          && KDEConnect.scrcpySessionMode === "feed"
          && KDEConnect.isUsbSelectionSerial(KDEConnect.scrcpyActiveSerial)) {
        Logger.w("KDEConnect", "USB transport lost, stopping embedded feed session");
        KDEConnect.stopScrcpySession();
      }

      if (root.embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning) {
        Qt.callLater(function() {
          root.refreshEmbeddedMirrorTouchMapping();
        });
      }

      if (usbTransportRestored
          && root.visible
          && root.embeddedMirrorModeEnabled()) {
        root.embeddedMirrorUsbRestoreRecoveryPending = true;
        embeddedMirrorUsbRestoreTimer.restart();
      }
    }

    function onDevicesChanged() {
      const devices = KDEConnect.devices || [];
      for (let i = 0; i < devices.length; ++i)
        root.updateCachedTelemetryForDevice(devices[i]);

      root.scheduleEmbeddedMirrorAutoStart();
    }

    function onMainDeviceChanged() {
      if (KDEConnect.mainDevice)
        root.updateCachedTelemetryForDevice(KDEConnect.mainDevice);

      root.scheduleEmbeddedMirrorAutoStart();
    }

    function onScrcpyWindowReadyChanged() {
      if (!root.embeddedMirrorModeEnabled()
          || !KDEConnect.scrcpyRunning
          || !KDEConnect.scrcpyWindowReady
          || !root.activePhonePreview)
        return;

      Qt.callLater(function() {
        root.syncEmbeddedMirrorOverlay(root.activePhonePreview);
      });
    }

    function onScrcpyLaunchErrorChanged() {
      if (!root.embeddedMirrorFeedConfigured()
          || !root.embeddedMirrorFeedModeEnabled()
          || KDEConnect.scrcpyLaunching
          || KDEConnect.scrcpyRunning
          || KDEConnect.scrcpyLaunchError === "")
        return;

      const errorText = String(KDEConnect.scrcpyLaunchError);
      const isFeedFailure = errorText.indexOf("V4L2 sink") !== -1
        || errorText.indexOf("/dev/video") !== -1
        || errorText.indexOf("Failed to open output") !== -1
        || errorText.indexOf("Failed to write header") !== -1
        || errorText.indexOf("Demuxer") !== -1;

      if (!isFeedFailure)
        return;

      root.embeddedVideoDeviceAccessible = false;
      root.embeddedVideoDeviceCheckKnown = true;
      KDEConnect.v4l2SnapshotVersion = 0;
      KDEConnect.v4l2SnapshotError = "";
      Logger.w("KDEConnect", "Feed mode failed for embedded scrcpy:", errorText);
    }

    function onScrcpyLaunchStartedAtMsChanged() {
      if (KDEConnect.scrcpyRunning)
        KDEConnect.scrcpyFirstFrameLatencyMs = -1;
    }

    function onWirelessAdbFinished(success, message) {
      if (success) {
        const usedQrFlow = root.applyWirelessAdbQrSuccess(message);
        if (root.wirelessAdbEnabled)
          root.wirelessAdbSessionPreferred = true;
        KDEConnect.refreshAdbDevices();
        const body = usedQrFlow
          ? root.trSafe("panel.wireless-adb.qr-success-description", "Wireless ADB paired and connected from the QR code.")
          : (message && message !== "ok"
              ? message
              : root.trSafe("panel.wireless-adb.success-description", "ADB over TCP/IP enabled"));
        root.wirelessAdbStatusMessage = body;
        ToastService.showNotice(root.trSafe("panel.wireless-adb.success-title", "Wireless ADB"), body, "wifi");
        Qt.callLater(function() {
          root.refreshEmbeddedMirrorTouchMapping();
        });
      } else {
        const body = message === "missing_command"
          ? root.trSafe("panel.wireless-adb.missing-command-description", "Set a Wireless ADB command in the plugin settings")
          : message === "missing_pair_parameters"
            ? root.trSafe("panel.wireless-adb.missing-pair-parameters-description", "Enter the phone IP, pairing port, and pairing code")
            : message === "missing_connect_parameters"
              ? root.trSafe("panel.wireless-adb.missing-connect-parameters-description", "Enter the phone IP and connect port")
              : message === "missing_qr_parameters"
                ? root.trSafe("panel.wireless-adb.missing-qr-parameters-description", "Generate a fresh Wireless ADB QR code and try again.")
              : message;
        root.wirelessAdbStatusMessage = body;
        ToastService.showWarning(root.trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
      }
    }
  }

  Component.onDestruction: {
    KDEConnect.reduceBackgroundRefresh = false;
    embeddedMirrorUsbRestoreTimer.stop();
    embeddedMirrorAutoStartTimer.stop();
    embeddedMirrorRecoveryTimer.stop();
    panelOpenUnlockTimer.stop();
    root.embeddedMirrorPendingSessionRecovery = false;
    root.embeddedMirrorRecoveryPreview = null;
    root.embeddedMirrorRecoveryReason = "";
    root.embeddedMirrorUsbRestoreRecoveryPending = false;
    root.panelOpenUnlockPending = false;
    root.panelOpenUnlockRetriesRemaining = 0;
    if (scrcpyStopOnPanelClose) {
      KDEConnect.stopScrcpySession();
    }
  }

  onVisibleChanged: {
    root.syncBackgroundRefreshPolicy();
    if (visible) {
      KDEConnect.refreshAdbDevices();
      if (KDEConnect.daemonAvailable)
        KDEConnect.refreshDevices();
      root.panelOpenUnlockPending = root.embeddedMirrorModeEnabled();
      root.panelOpenUnlockRetriesRemaining = 12;
      if (KDEConnect.scrcpyRunning)
        panelOpenUnlockTimer.restart();
      root.scheduleEmbeddedMirrorAutoStart();
    }
    if (!visible) {
      embeddedMirrorUsbRestoreTimer.stop();
      embeddedMirrorAutoStartTimer.stop();
      embeddedMirrorRecoveryTimer.stop();
      panelOpenUnlockTimer.stop();
      root.embeddedMirrorPendingSessionRecovery = false;
      root.embeddedMirrorRecoveryPreview = null;
      root.embeddedMirrorRecoveryReason = "";
      root.embeddedMirrorUsbRestoreRecoveryPending = false;
      root.panelOpenUnlockPending = false;
      root.panelOpenUnlockRetriesRemaining = 0;
    }
    if (!visible && scrcpyStopOnPanelClose)
      KDEConnect.stopScrcpySession();
  }

  onMirrorReduceBackgroundPollingChanged: root.syncBackgroundRefreshPolicy()
  onEmbeddedMirrorEnabledChanged: root.syncBackgroundRefreshPolicy()
  onPhoneClickActionChanged: root.syncBackgroundRefreshPolicy()
  onEmbeddedMirrorForceSnapshotFallbackChanged: root.persistEmbeddedMirrorSnapshotFallbackMode()

  function handlePhoneClick(preview) {
    if (KDEConnect.mainDevice === null)
      return;

    if (phoneClickAction === "scrcpy") {
      if (embeddedMirrorModeEnabled()) {
        if (root.embeddedMirrorFeedSessionDegraded(preview, 1800)) {
          root.requestEmbeddedMirrorSessionRecovery(preview, "manual-retry");
          return;
        }
        ensureEmbeddedMirrorSession(preview);
      } else {
        KDEConnect.toggleScrcpySession(KDEConnect.mainDevice.id, scrcpyCommand);
      }
      return;
    }

    KDEConnect.wakeUpDevice(KDEConnect.mainDevice.id);
  }

  function scheduleEmbeddedMirrorAutoStart() {
    if (!root.visible
        || !embeddedMirrorModeEnabled()
        || KDEConnect.mainDevice === null
        || !KDEConnect.mainDevice.reachable) {
      return;
    }

    embeddedMirrorAutoStartTimer.restart();
  }

  function attemptEmbeddedMirrorAutoStart() {
    if (!root.visible
        || !embeddedMirrorModeEnabled()
        || KDEConnect.mainDevice === null
        || !KDEConnect.mainDevice.reachable
        || !root.activePhonePreview) {
      return;
    }

    root.ensureEmbeddedMirrorSession(root.activePhonePreview);
  }


  function cyclePhoneSizePreset() {
    phoneSizeAnimationEnabled = true;
    if (phoneSizePresetIndex >= 2)
      phoneSizeStepDirection = -1;
    else if (phoneSizePresetIndex <= 0)
      phoneSizeStepDirection = 1;

    phoneSizePresetIndex = Math.max(0, Math.min(2, phoneSizePresetIndex + phoneSizeStepDirection));

    if (phoneSizePresetIndex >= 2)
      phoneSizeStepDirection = -1;
    else if (phoneSizePresetIndex <= 0)
      phoneSizeStepDirection = 1;

    persistPhoneSizePreset();
  }

  function initialPhoneSizePresetIndex() {
    const explicitKey = String(cfg.phoneSizePresetKey ?? defaults.phoneSizePresetKey ?? "").trim().toLowerCase();
    if (explicitKey === "small")
      return 0;
    if (explicitKey === "medium")
      return 1;
    if (explicitKey === "large")
      return 2;

    const legacyIndex = Math.max(0, Math.min(2, Number(cfg.phoneSizePresetIndex ?? defaults.phoneSizePresetIndex ?? 0)));
    if (legacyIndex === 2)
      return 0;
    if (legacyIndex === 1)
      return 1;
    return 2;
  }

  function currentPhoneSizePresetKey() {
    if (phoneSizePresetIndex === 0)
      return "small";
    if (phoneSizePresetIndex === 1)
      return "medium";
    return "large";
  }

  function initialPhoneSizeStepDirection() {
    const storedDirection = Number(cfg.phoneSizeStepDirection ?? defaults.phoneSizeStepDirection ?? 0);
    if (storedDirection === -1 || storedDirection === 1)
      return storedDirection;

    return initialPhoneSizePresetIndex() >= 2 ? -1 : 1;
  }

  function persistPhoneSizePreset() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.phoneSizePresetKey = currentPhoneSizePresetKey();
    pluginApi.pluginSettings.phoneSizePresetIndex = phoneSizePresetIndex;
    pluginApi.pluginSettings.phoneSizeStepDirection = phoneSizeStepDirection;
    pluginApi.saveSettings();
  }

  function persistEmbeddedMirrorSnapshotFallbackMode() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.embeddedMirrorForceSnapshotFallback = embeddedMirrorForceSnapshotFallback;
    pluginApi.saveSettings();
  }

  function phoneStatusTitle() {
    if (phoneClickAction !== "scrcpy")
      return pluginApi?.tr("panel.phone.wake-title") || "Wake Device";

    if (KDEConnect.scrcpyLaunching)
      return pluginApi?.tr("panel.scrcpy.starting-title") || "Starting scrcpy";

    if (KDEConnect.scrcpyRunning)
      return pluginApi?.tr("panel.scrcpy.running-title") || "scrcpy Active";

    if ((scrcpyCommand || "").trim() === "")
      return pluginApi?.tr("panel.scrcpy.not-configured-title") || "scrcpy Not Configured";

    if (KDEConnect.scrcpyLaunchError !== "")
      return pluginApi?.tr("panel.scrcpy.error-title") || "scrcpy Error";

    return pluginApi?.tr("panel.scrcpy.ready-title") || "Launch scrcpy";
  }

  function phoneStatusSubtitle() {
    if (phoneClickAction !== "scrcpy")
      return pluginApi?.tr("panel.phone.wake-description") || "Click to wake the device";

    if (KDEConnect.scrcpyLaunching)
      return pluginApi?.tr("panel.scrcpy.starting-description") || "Preparing the control session";

    if (KDEConnect.scrcpyRunning)
      return pluginApi?.tr("panel.scrcpy.running-description") || "Click the phone tile again to stop the session";

    if ((scrcpyCommand || "").trim() === "")
      return pluginApi?.tr("panel.scrcpy.not-configured-description") || "Set a scrcpy command in the plugin settings";

    if (KDEConnect.scrcpyLaunchError === "missing_command")
      return pluginApi?.tr("panel.scrcpy.missing-command-description") || "Set a scrcpy command in the plugin settings";

    if (KDEConnect.scrcpyLaunchError !== "")
      return KDEConnect.scrcpyLaunchError;

    return pluginApi?.tr("panel.scrcpy.ready-description") || "Click to launch phone control";
  }

  function trSafe(key, fallback) {
    const translated = pluginApi?.tr(key);
    if (translated === undefined || translated === null)
      return fallback;

    const text = String(translated);
    return (text === "" || text.startsWith("!!")) ? fallback : text;
  }

  function initialCachedDeviceTelemetry() {
    const rawValue = cfg.cachedDeviceTelemetry ?? defaults.cachedDeviceTelemetry ?? ({});
    if (rawValue && typeof rawValue === "object")
      return rawValue;

    return ({});
  }

  function telemetryCacheKey(device) {
    return String(device?.id || "").trim();
  }

  function cachedTelemetryForDevice(device) {
    const key = telemetryCacheKey(device);
    if (key === "")
      return null;

    const cache = cachedDeviceTelemetry || ({});
    const entry = cache[key];
    return (entry && typeof entry === "object") ? entry : null;
  }

  function persistCachedDeviceTelemetry() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.cachedDeviceTelemetry = cachedDeviceTelemetry;
    pluginApi.saveSettings();
  }

  function updateCachedTelemetryForDevice(device) {
    const key = telemetryCacheKey(device);
    if (key === "")
      return;

    const current = device || ({});
    const previous = cachedTelemetryForDevice(device) || ({});
    const next = {
      battery: Number(current.battery) >= 0 ? Number(current.battery) : previous.battery,
      charging: Number(current.battery) >= 0 ? Boolean(current.charging) : previous.charging,
      cellularNetworkType: String(current.cellularNetworkType || "").trim() !== ""
        ? String(current.cellularNetworkType).trim()
        : previous.cellularNetworkType,
      cellularNetworkStrength: Number(current.cellularNetworkStrength) >= 0
        ? Number(current.cellularNetworkStrength)
        : previous.cellularNetworkStrength,
      notificationCount: Array.isArray(current.notificationIds)
        ? current.notificationIds.length
        : previous.notificationCount
    };

    const changed = JSON.stringify(previous) !== JSON.stringify(next);
    if (!changed)
      return;

    cachedDeviceTelemetry = Object.assign({}, cachedDeviceTelemetry || ({}), {
      [key]: next
    });
    persistCachedDeviceTelemetry();
  }

  function effectiveBatteryValue(device) {
    const battery = Number(device?.battery);
    if (isFinite(battery) && battery >= 0)
      return battery;

    const cached = cachedTelemetryForDevice(device);
    const cachedBattery = Number(cached?.battery);
    return (isFinite(cachedBattery) && cachedBattery >= 0) ? cachedBattery : -1;
  }

  function effectiveChargingValue(device) {
    const liveBattery = Number(device?.battery);
    if (isFinite(liveBattery) && liveBattery >= 0)
      return Boolean(device?.charging);

    const cached = cachedTelemetryForDevice(device);
    return Boolean(cached?.charging);
  }

  function effectiveNetworkType(device) {
    const liveValue = String(device?.cellularNetworkType || "").trim();
    if (liveValue !== "")
      return liveValue;

    const cached = cachedTelemetryForDevice(device);
    return String(cached?.cellularNetworkType || "").trim();
  }

  function effectiveSignalStrength(device) {
    const liveValue = Number(device?.cellularNetworkStrength);
    if (isFinite(liveValue) && liveValue >= 0)
      return liveValue;

    const cached = cachedTelemetryForDevice(device);
    const cachedValue = Number(cached?.cellularNetworkStrength);
    return (isFinite(cachedValue) && cachedValue >= 0) ? cachedValue : -1;
  }

  function effectiveNotificationCount(device) {
    if (Array.isArray(device?.notificationIds))
      return device.notificationIds.length;

    const cached = cachedTelemetryForDevice(device);
    const cachedValue = Number(cached?.notificationCount);
    return isFinite(cachedValue) && cachedValue >= 0 ? cachedValue : 0;
  }

  function randomTokenFromAlphabet(length, alphabet) {
    const size = Math.max(1, Math.round(length || 1));
    const source = String(alphabet || "0123456789");
    let token = "";

    for (let i = 0; i < size; ++i) {
      token += source.charAt(Math.floor(Math.random() * source.length));
    }

    return token;
  }

  function makeTempInstanceToken() {
    return Date.now().toString(36)
      + "-"
      + randomTokenFromAlphabet(8, "abcdefghijklmnopqrstuvwxyz0123456789");
  }

  function escapeWirelessAdbQrValue(value) {
    return String(value || "").replace(/([\\;,:])/g, "\\$1");
  }

  function wirelessAdbQrPayload() {
    if ((wirelessAdbQrInstanceName || "").trim() === "" || (wirelessAdbQrSecret || "").trim() === "")
      return "";

    return "WIFI:T:ADB;S:"
      + escapeWirelessAdbQrValue(wirelessAdbQrInstanceName)
      + ";P:"
      + escapeWirelessAdbQrValue(wirelessAdbQrSecret)
      + ";;";
  }

  function wirelessAdbQrImageSource() {
    if (wirelessAdbQrImageVersion <= 0)
      return "";

    return "file://" + wirelessAdbQrImagePath + "?v=" + wirelessAdbQrImageVersion;
  }

  function persistWirelessAdbSettings() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.wirelessAdbPairHost = (wirelessAdbPairHost || "").trim();
    pluginApi.pluginSettings.wirelessAdbPairPort = (wirelessAdbPairPort || "").trim();
    pluginApi.pluginSettings.wirelessAdbConnectHost = (wirelessAdbConnectHost || "").trim();
    pluginApi.pluginSettings.wirelessAdbConnectPort = (wirelessAdbConnectPort || "").trim();
    pluginApi.saveSettings();
  }

  function persistWirelessAdbMode(cableOnlyEnabled) {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.wirelessAdbEnabled = !cableOnlyEnabled;
    pluginApi.saveSettings();
  }

  function openWirelessAdbDialog() {
    if ((wirelessAdbConnectHost || "").trim() === "" && (wirelessAdbPairHost || "").trim() !== "")
      wirelessAdbConnectHost = (wirelessAdbPairHost || "").trim();
    if ((wirelessAdbPairHost || "").trim() === "" && (wirelessAdbConnectHost || "").trim() !== "")
      wirelessAdbPairHost = (wirelessAdbConnectHost || "").trim();

    wirelessAdbPairingCode = "";
    wirelessAdbStatusMessage = "";
    wirelessAdbPopup.open();
  }

  function startWirelessAdbPairing() {
    const host = (wirelessAdbPairHost || "").trim();
    const port = (wirelessAdbPairPort || "").trim();
    const pairingCode = (wirelessAdbPairingCode || "").trim();

    if (host === "" || port === "" || pairingCode === "") {
      const body = trSafe("panel.wireless-adb.missing-pair-parameters-description", "Enter the phone IP, pairing port, and pairing code");
      wirelessAdbStatusMessage = body;
      ToastService.showWarning(trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
      return;
    }

    wirelessAdbConnectHost = host;

    wirelessAdbStatusMessage = "";
    persistWirelessAdbSettings();
    KDEConnect.pairWirelessAdb(host, port, pairingCode);
  }

  function startWirelessAdbConnect() {
    const host = (wirelessAdbConnectHost || "").trim() !== ""
      ? (wirelessAdbConnectHost || "").trim()
      : (wirelessAdbPairHost || "").trim();
    const port = (wirelessAdbConnectPort || "").trim();

    if (host === "" || port === "") {
      const body = trSafe("panel.wireless-adb.missing-connect-parameters-description", "Enter the phone IP and connect port");
      wirelessAdbStatusMessage = body;
      ToastService.showWarning(trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
      return;
    }

    wirelessAdbConnectHost = host;
    wirelessAdbStatusMessage = "";
    wirelessAdbSessionPreferred = true;
    persistWirelessAdbSettings();
    KDEConnect.connectWirelessAdb(host, port);
  }

  function beginWirelessAdbQrPairing() {
    if (!wirelessAdbEnabled) {
      const body = trSafe("panel.wireless-adb.disabled-banner-description", "Wireless tools stay visible here for reference, but they are disabled until Wireless ADB is re-enabled in plugin settings.");
      wirelessAdbStatusMessage = body;
      ToastService.showWarning(trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
      return;
    }

    if (KDEConnect.wirelessAdbBusy || wirelessAdbQrEncodeProc.running)
      return;

    wirelessAdbQrInstanceName = "noctalia-" + randomTokenFromAlphabet(10, "abcdefghijklmnopqrstuvwxyz0123456789");
    wirelessAdbQrSecret = randomTokenFromAlphabet(10, "0123456789");
    wirelessAdbStatusMessage = trSafe(
      "panel.wireless-adb.qr-waiting-description",
      "Waiting for the phone to scan the QR code and publish its pairing service."
    );
    wirelessAdbQrPendingLaunch = true;
    wirelessAdbQrEncodeProc.running = true;
  }

  function applyWirelessAdbQrSuccess(message) {
    const match = String(message || "").match(/^QR_OK\s+host=(\S+)\s+pair_port=(\d+)\s+connect_port=(\d+)/);
    if (!match)
      return false;

    wirelessAdbPairHost = match[1];
    wirelessAdbConnectHost = match[1];
    wirelessAdbPairPort = match[2];
    wirelessAdbConnectPort = match[3];
    persistWirelessAdbSettings();
    return true;
  }

  function configuredWirelessAdbSerial() {
    const host = (wirelessAdbConnectHost || "").trim();
    const port = (wirelessAdbConnectPort || "").trim();
    if (host === "" || port === "")
      return "";

    return host + ":" + port;
  }

  function currentMirrorAdbSerial() {
    const activeSerial = String(KDEConnect.scrcpyActiveSerial || "").trim();
    if (KDEConnect.scrcpyRunning && activeSerial !== "")
      return activeSerial;

    return resolvedAdbSerial();
  }

  function startWirelessAdbTcpipHelper() {
    wirelessAdbStatusMessage = "";
    persistWirelessAdbSettings();
    KDEConnect.enableWirelessAdb(wirelessAdbCommand);
  }

  function resolvedAdbSerial() {
    const serialOverride = (adbDeviceSerialOverride || "").trim();
    if (serialOverride !== "")
      return serialOverride;

    if (!wirelessAdbEnabled)
      return KDEConnect.usbSelectionSentinel;

    const usbTransportAvailable = KDEConnect.adbHasUsbTransport;
    if (usbTransportAvailable && !wirelessAdbSessionPreferred)
      return KDEConnect.usbSelectionSentinel;

    const activeWirelessSerial = KDEConnect.adbConnectedSerialForHost((wirelessAdbConnectHost || "").trim());
    if (activeWirelessSerial !== "")
      return activeWirelessSerial;

    const wirelessSerial = configuredWirelessAdbSerial();
    if (wirelessSerial !== "") {
      if (wirelessAdbSessionPreferred)
        return wirelessSerial;

      if (!usbTransportAvailable && KDEConnect.adbDeviceSerialConnected(wirelessSerial))
        return wirelessSerial;
    }

    return KDEConnect.usbSelectionSentinel;
  }

  function syncBackgroundRefreshPolicy() {
    KDEConnect.reduceBackgroundRefresh = root.visible
      && root.mirrorReduceBackgroundPolling
      && root.embeddedMirrorModeEnabled()
      && KDEConnect.scrcpyRunning;
  }

  function captureMirrorFirstFrameLatency() {
    if (!root.activePhonePreview
        || KDEConnect.scrcpyLaunchStartedAtMs <= 0
        || KDEConnect.scrcpyFirstFrameLatencyMs >= 0
        || !root.embeddedMirrorViewActive(root.activePhonePreview))
      return;

    KDEConnect.scrcpyFirstFrameLatencyMs = Math.max(0, Math.round(Date.now() - KDEConnect.scrcpyLaunchStartedAtMs));
  }

  function mirrorPerfSummary() {
    const parts = [];
    const trimmedEncoder = (embeddedVideoEncoder || "").trim();

    if (!wirelessAdbEnabled)
      parts.push("USB");

    if (trimmedEncoder !== "")
      parts.push(trimmedEncoder);
    else
      parts.push(mirrorPerformancePreset);

    if (KDEConnect.scrcpyFirstFrameLatencyMs >= 0)
      parts.push(KDEConnect.scrcpyFirstFrameLatencyMs + "ms first frame");
    else if (KDEConnect.scrcpyRunning)
      parts.push("timing...");

    if (mirrorReduceBackgroundPolling)
      parts.push("poll " + Math.round(KDEConnect.refreshIntervalMs / 1000) + "s");

    return parts.join(" • ");
  }

  function embeddedMirrorModeEnabled() {
    return phoneClickAction === "scrcpy" && embeddedMirrorEnabled;
  }

  function embeddedMirrorFeedConfigured() {
    return embeddedMirrorModeEnabled() && (embeddedVideoDevice || "").trim() !== "";
  }

  function embeddedMirrorFeedModeEnabled() {
    return embeddedMirrorFeedConfigured();
  }

  function embeddedMirrorSnapshotFallbackForced() {
    return embeddedMirrorFeedModeEnabled() && embeddedMirrorForceSnapshotFallback;
  }

  function refreshEmbeddedVideoDeviceAccess() {
    if (!embeddedMirrorFeedConfigured()) {
      embeddedVideoDeviceAccessible = false;
      embeddedVideoDeviceCheckKnown = true;
      return;
    }

    if (embeddedVideoDeviceCheckProc.running)
      return;

    embeddedVideoDeviceAccessible = false;
    embeddedVideoDeviceCheckKnown = false;
    embeddedVideoDeviceCheckProc.running = true;
  }

  function embeddedMirrorFeedSessionDegraded(preview, minimumAgeMs) {
    if (!embeddedMirrorFeedConfigured()
        || !KDEConnect.scrcpyRunning
        || KDEConnect.scrcpySessionMode !== "feed") {
      return false;
    }

    const previewItem = preview || root.activePhonePreview || null;
    const launchStartedAt = Number(KDEConnect.scrcpyLaunchStartedAtMs || 0);
    const launchAgeMs = launchStartedAt > 0 ? (Date.now() - launchStartedAt) : Number.MAX_SAFE_INTEGER;
    const requiredAgeMs = Math.max(0, Number(minimumAgeMs || 0));

    if (previewItem && previewItem.mirrorDisplayVisible)
      return false;

    if (launchAgeMs < requiredAgeMs && KDEConnect.v4l2SnapshotVersion <= 0)
      return false;

    if (!previewItem)
      return true;

    if (!previewItem.mirrorFeedAvailable)
      return true;

    if (previewItem.mirrorFeedError !== "")
      return true;

    return KDEConnect.v4l2SnapshotVersion > 0;
  }

  function requestEmbeddedMirrorSessionRecovery(preview, reason) {
    if (!embeddedMirrorModeEnabled())
      return;

    const recoveryReason = String(reason || "").trim();
    const previewItem = preview || root.activePhonePreview || null;

    root.embeddedMirrorRecoveryPreview = previewItem;
    root.embeddedMirrorRecoveryReason = recoveryReason;

    if (previewItem && previewItem.reloadMediaDevices)
      previewItem.reloadMediaDevices();

    if (KDEConnect.scrcpyRunning) {
      if (root.embeddedMirrorPendingSessionRecovery)
        return;

      root.embeddedMirrorPendingSessionRecovery = true;
      Logger.w("KDEConnect", "Recovering embedded mirror session in feed mode",
        "reason=" + recoveryReason,
        "session=" + KDEConnect.scrcpySessionMode);
      KDEConnect.stopScrcpySession();
      return;
    }

    root.embeddedMirrorPendingSessionRecovery = true;
    embeddedMirrorRecoveryTimer.restart();
  }

  function embeddedMirrorFallbackActive(preview) {
    if (!embeddedMirrorFeedModeEnabled()
        || !KDEConnect.scrcpyRunning
        || KDEConnect.scrcpyLaunching
        || KDEConnect.scrcpySessionMode !== "feed") {
      return false;
    }

    const previewItem = preview || root.activePhonePreview || null;
    if (embeddedMirrorSnapshotFallbackForced())
      return KDEConnect.v4l2SnapshotVersion > 0 || previewItem !== null;

    if (!previewItem)
      return KDEConnect.v4l2SnapshotVersion > 0;

    if (previewItem.mirrorDisplayVisible)
      return false;

    return KDEConnect.v4l2SnapshotVersion > 0
      || !previewItem.mirrorFeedAvailable
      || previewItem.mirrorFeedError !== "";
  }

  function embeddedMirrorPromotionActive(preview) {
    if (!embeddedMirrorFeedModeEnabled()
        || !KDEConnect.scrcpyRunning
        || KDEConnect.scrcpyLaunching
        || KDEConnect.scrcpySessionMode !== "feed"
        || embeddedMirrorPendingSessionRecovery
        || embeddedMirrorSnapshotFallbackForced()) {
      return false;
    }

    const previewItem = preview || root.activePhonePreview || null;
    if (!previewItem || previewItem.mirrorDisplayVisible)
      return false;

    return previewItem.mirrorFeedAvailable
      && previewItem.mirrorFeedError === ""
      && KDEConnect.v4l2SnapshotVersion > 0;
  }

  function retryEmbeddedMirrorFeed(preview) {
    if (!embeddedMirrorFallbackActive(preview) || embeddedMirrorPendingSessionRecovery)
      return;

    requestEmbeddedMirrorSessionRecovery(preview, "fallback-button");
  }

  function toggleEmbeddedMirrorSnapshotFallbackMode(preview) {
    if (!embeddedMirrorModeEnabled() || !embeddedMirrorFeedModeEnabled())
      return;

    const previewItem = preview || root.activePhonePreview || null;
    const enablingSnapshotFallback = !embeddedMirrorForceSnapshotFallback;
    embeddedMirrorForceSnapshotFallback = enablingSnapshotFallback;

    if (previewItem && previewItem.reloadMediaDevices)
      previewItem.reloadMediaDevices();

    if (enablingSnapshotFallback && KDEConnect.scrcpyRunning) {
      Qt.callLater(function() {
        root.requestEmbeddedMirrorSnapshotFrame();
      });
    }

    if (!KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching)
      ensureEmbeddedMirrorSession(previewItem);
  }

  function ensureEmbeddedMirrorSession(preview) {
    if (!embeddedMirrorModeEnabled() || KDEConnect.mainDevice === null)
      return;

    const previewItem = preview || root.activePhonePreview || null;
    const previewX = previewItem ? previewItem.videoFrameGlobalX : 0;
    const previewY = previewItem ? previewItem.videoFrameGlobalY : 0;
    const previewWidth = previewItem ? previewItem.videoFrameGlobalWidth : (360 * Style.uiScaleRatio);
    const previewHeight = previewItem ? previewItem.videoFrameGlobalHeight : (735 * Style.uiScaleRatio);
    const serial = resolvedAdbSerial();
    const feedConfigured = embeddedMirrorFeedConfigured();
    const feedModeEnabled = embeddedMirrorFeedModeEnabled();

    if (feedConfigured && !embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceCheckProc.running) {
      refreshEmbeddedVideoDeviceAccess();
    }

    if (!KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching) {
      let tunedEmbeddedCommand = KDEConnect.applyMirrorPerformancePreset(
        embeddedScrcpyCommand,
        mirrorPerformancePreset,
        feedModeEnabled
      );
      tunedEmbeddedCommand = KDEConnect.applyConfiguredMirrorOptions(
        tunedEmbeddedCommand,
        embeddedVideoEncoder,
        embeddedVideoCodecOptions,
        mirrorDebugOverlayEnabled
      );
      const launchCommand = feedModeEnabled
        ? KDEConnect.buildScrcpyFeedCommand(
            tunedEmbeddedCommand,
            embeddedVideoDevice,
            serial
          )
        : KDEConnect.buildScrcpyOverlayCommand(
            tunedEmbeddedCommand,
            KDEConnect.scrcpyWindowTitle,
            previewX,
            previewY,
            previewWidth,
            previewHeight,
            serial
          );
      Logger.i("KDEConnect", "Launching embedded scrcpy in", feedModeEnabled ? "feed" : "overlay", "mode");
      KDEConnect.launchScrcpySession(
        KDEConnect.mainDevice.id,
        launchCommand
      );
      return;
    }

    if (KDEConnect.scrcpyRunning) {
      refreshEmbeddedMirrorTouchMapping();
      if (!embeddedMirrorFeedModeEnabled())
        syncEmbeddedMirrorOverlay(previewItem);
    }
  }

  function requestEmbeddedMirrorSnapshotFrame() {
    if (!embeddedMirrorFeedModeEnabled()
        || !KDEConnect.scrcpyRunning
        || KDEConnect.scrcpyLaunching) {
      return false;
    }

    if (activePhonePreview && activePhonePreview.mirrorFeedRestarting)
      return false;

    const launchStartedAt = Number(KDEConnect.scrcpyLaunchStartedAtMs || 0);
    if (launchStartedAt > 0 && (Date.now() - launchStartedAt) < 2200)
      return false;

    return KDEConnect.captureAdbFrame(currentMirrorAdbSerial(), embeddedMirrorSnapshotPath);
  }

  function embeddedMirrorViewActive(preview) {
    if (!embeddedMirrorModeEnabled())
      return false;

    if (embeddedMirrorFeedModeEnabled())
      return KDEConnect.scrcpyRunning
        && (preview?.mirrorDisplayVisible || KDEConnect.v4l2SnapshotVersion > 0);

    return KDEConnect.scrcpyRunning
      && KDEConnect.scrcpyWindowReady;
  }

  function embeddedMirrorTouchActive() {
    return embeddedMirrorModeEnabled()
      && KDEConnect.scrcpyRunning
      && KDEConnect.adbDisplayInfoSerial === ""
      && KDEConnect.adbScreenError === ""
      && KDEConnect.adbScreenWidth > 0
      && KDEConnect.adbScreenHeight > 0;
  }

  function embeddedMirrorInputActive() {
    return embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning;
  }

  function refreshEmbeddedMirrorTouchMapping() {
    if (!embeddedMirrorModeEnabled() || !KDEConnect.scrcpyRunning)
      return;

    const serial = currentMirrorAdbSerial();
    const hasValidMapping = KDEConnect.adbScreenWidth > 0
      && KDEConnect.adbScreenHeight > 0
      && KDEConnect.adbScreenError === ""
      && KDEConnect.adbDisplayInfoSerial === ""
      && KDEConnect.adbScreenSerial === serial;

    if (!hasValidMapping)
      KDEConnect.queryAdbDisplayInfo(serial);
  }

  function syncEmbeddedMirrorOverlay(preview) {
    if (!embeddedMirrorModeEnabled() || !preview)
      return;

    KDEConnect.refreshScrcpyWindowState();
    KDEConnect.syncScrcpyOverlayWindow(
      preview.videoFrameGlobalX,
      preview.videoFrameGlobalY,
      preview.videoFrameGlobalWidth,
      preview.videoFrameGlobalHeight
    );
  }

  function embeddedMirrorDrawerStatusVisible(preview) {
    if (!embeddedMirrorModeEnabled())
      return false;

    return String(embeddedMirrorDrawerStatusTitle(preview) || "").trim() !== ""
      || String(embeddedMirrorDrawerStatusSubtitle(preview) || "").trim() !== "";
  }

  function embeddedMirrorPhoneOverlayVisible() {
    if (!embeddedMirrorModeEnabled())
      return true;

    return KDEConnect.scrcpyLaunching;
  }

  function embeddedMirrorPhoneStatusTitle(preview) {
    return embeddedMirrorPhoneOverlayVisible()
      ? embeddedMirrorStatusTitle(preview)
      : "";
  }

  function embeddedMirrorPhoneStatusSubtitle(preview) {
    return embeddedMirrorPhoneOverlayVisible()
      ? embeddedMirrorStatusSubtitle(preview)
      : "";
  }

  function embeddedMirrorDebugSerialLabel(serial) {
    const trimmedSerial = String(serial || "").trim();
    if (trimmedSerial === "")
      return "auto";
    if (trimmedSerial === KDEConnect.usbSelectionSentinel)
      return "usb";
    return trimmedSerial;
  }

  function embeddedMirrorDebugViewState(preview) {
    if (!KDEConnect.scrcpyRunning)
      return "idle";
    if (preview?.mirrorDisplayVisible)
      return "live";
    if (KDEConnect.v4l2SnapshotVersion > 0)
      return "snapshot";
    return "waiting";
  }

  function embeddedMirrorDebugInputLabel(preview) {
    const input = preview?.selectedVideoInput;
    if (!input || input.isNull)
      return "";

    const description = String(input.description || "").trim();
    const id = String(input.id || "").trim();
    if (description !== "" && id !== "")
      return description + " [" + id + "]";
    return description !== "" ? description : id;
  }

  function embeddedMirrorDrawerStatusTitle(preview) {
    const baseTitle = embeddedMirrorStatusTitle(preview);
    if (baseTitle !== "")
      return baseTitle;

    if (!embeddedMirrorModeEnabled())
      return "";

    if (!embeddedMirrorDiagnosticsEnabled)
      return "";

    return KDEConnect.scrcpyRunning
      ? trSafe("panel.embedded-mirror.debug-title", "Mirror Diagnostics")
      : trSafe("panel.embedded-mirror.debug-idle-title", "Mirror Idle");
  }

  function embeddedMirrorDrawerStatusSubtitle(preview) {
    const lines = [];
    const baseSubtitle = embeddedMirrorStatusSubtitle(preview);

    if (!embeddedMirrorModeEnabled())
      return baseSubtitle;

    if (baseSubtitle !== "")
      lines.push(baseSubtitle);

    if (!embeddedMirrorDiagnosticsEnabled)
      return lines.join("\n");

    const scrcpyState = KDEConnect.scrcpyLaunching
      ? "starting"
      : (KDEConnect.scrcpyRunning
          ? "running"
          : (KDEConnect.scrcpyLaunchError !== "" ? "error" : "idle"));
    const scrcpyMode = KDEConnect.scrcpySessionMode !== ""
      ? KDEConnect.scrcpySessionMode
      : (embeddedMirrorFeedModeEnabled() ? "feed" : "overlay");
    const scrcpySerial = embeddedMirrorDebugSerialLabel(
      KDEConnect.scrcpyRunning ? KDEConnect.scrcpyActiveSerial : resolvedAdbSerial()
    );
    const videoState = !embeddedMirrorFeedConfigured()
      ? "not-set"
      : (!embeddedVideoDeviceCheckKnown
          ? "checking"
          : (embeddedVideoDeviceAccessible ? "ok" : "blocked"));
    const qtState = preview?.mirrorFeedAvailable ? "input" : "no-input";

    lines.push("scrcpy: " + scrcpyState
      + " • " + scrcpyMode
      + " • " + scrcpySerial
      + " • usb " + (KDEConnect.adbHasUsbTransport ? "yes" : "no"));
    lines.push("video: " + embeddedVideoDevice
      + " • " + videoState
      + " • view " + embeddedMirrorDebugViewState(preview)
      + " • qt " + qtState);

    if (embeddedMirrorPendingSessionRecovery) {
      const recoveryState = KDEConnect.scrcpyRunning ? "restarting" : "queued";
      const recoveryLabel = embeddedMirrorRecoveryReason !== ""
        ? (" • " + embeddedMirrorRecoveryReason)
        : "";
      lines.push("recovery: " + recoveryState + recoveryLabel);
    }

    const inputLabel = embeddedMirrorDebugInputLabel(preview);
    if (inputLabel !== "")
      lines.push("input: " + inputLabel);

    const diagnosticError = preview?.mirrorFeedError !== ""
      ? ("qt: " + preview.mirrorFeedError)
      : (KDEConnect.scrcpyLaunchError !== ""
          ? ("scrcpy: " + KDEConnect.scrcpyLaunchError)
          : (KDEConnect.v4l2SnapshotError !== ""
              ? ("snapshot: " + KDEConnect.v4l2SnapshotError)
              : (KDEConnect.adbScreenError !== ""
                  ? ("adb: " + KDEConnect.adbScreenError)
                  : "")));
    if (diagnosticError !== "")
      lines.push(diagnosticError);

    return lines.join("\n");
  }

  function embeddedMirrorStatusTitle(preview) {
    if (!embeddedMirrorModeEnabled())
      return phoneStatusTitle();

    if ((embeddedScrcpyCommand || "").trim() === "")
      return trSafe("panel.embedded-mirror.not-configured-title", "Embedded Mirror Not Configured");

    if (embeddedMirrorModeEnabled() && (embeddedVideoDevice || "").trim() === "")
      return trSafe("panel.embedded-mirror.feed-not-configured-title", "Video Feed Not Configured");

    if (embeddedMirrorFeedConfigured() && embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceAccessible)
      return trSafe("panel.embedded-mirror.feed-unavailable-title", "Video Feed Unavailable");

    if (KDEConnect.scrcpyLaunching)
      return trSafe("panel.embedded-mirror.starting-title", "Starting Embedded Mirror");

    if (KDEConnect.scrcpyLaunchError !== "")
      return trSafe("panel.embedded-mirror.error-title", "Mirror Error");

    if (embeddedMirrorPromotionActive(preview))
      return trSafe("panel.embedded-mirror.promoting-title", "Promoting to Live Feed");

    if (embeddedMirrorFallbackActive(preview))
      return trSafe("panel.embedded-mirror.fallback-title", "Fallback Snapshot Active");

    if (embeddedMirrorFeedModeEnabled()
        && KDEConnect.scrcpyRunning
        && preview
        && !preview.mirrorFeedAvailable
        && Number(KDEConnect.scrcpyLaunchStartedAtMs || 0) > 0
        && (Date.now() - Number(KDEConnect.scrcpyLaunchStartedAtMs || 0)) >= 5000)
      return trSafe("panel.embedded-mirror.feed-starting-title", "Waiting for Video Feed");

    if (embeddedMirrorFeedModeEnabled()
        && KDEConnect.scrcpyRunning
        && !embeddedMirrorViewActive(preview)
        && Number(KDEConnect.scrcpyLaunchStartedAtMs || 0) > 0
        && (Date.now() - Number(KDEConnect.scrcpyLaunchStartedAtMs || 0)) >= 5000)
      return trSafe("panel.embedded-mirror.feed-starting-title", "Waiting for Video Feed");

    if (!embeddedMirrorFeedModeEnabled() && KDEConnect.scrcpyRunning && !KDEConnect.scrcpyWindowReady)
      return trSafe("panel.embedded-mirror.syncing-title", "Positioning Mirror");

    if (KDEConnect.scrcpyRunning && KDEConnect.adbScreenError !== "")
      return trSafe("panel.embedded-mirror.touch-error-title", "Touch Input Unavailable");

    if (KDEConnect.scrcpyRunning && !embeddedMirrorTouchActive())
      return trSafe("panel.embedded-mirror.touch-starting-title", "Preparing Touch Input");

    return "";
  }

  function embeddedMirrorStatusSubtitle(preview) {
    if (!embeddedMirrorModeEnabled())
      return phoneStatusSubtitle();

    if ((embeddedScrcpyCommand || "").trim() === "")
      return trSafe("panel.embedded-mirror.not-configured-description", "Set an embedded scrcpy command in the plugin settings.");

    if (embeddedMirrorModeEnabled() && (embeddedVideoDevice || "").trim() === "")
      return trSafe("panel.embedded-mirror.feed-not-configured-description", "Set the V4L2 loopback device path in the plugin settings.");

    if (embeddedMirrorFeedConfigured() && embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceAccessible)
      return trSafe("panel.embedded-mirror.feed-unavailable-description",
        "The V4L2 device cannot be opened. Make sure "
        + embeddedVideoDevice + " exists, is writable, and is backed by the scrcpy loopback device.");

    if (KDEConnect.scrcpyLaunching)
      return trSafe("panel.embedded-mirror.starting-description", "Launching scrcpy and preparing the panel overlay.");

    if (KDEConnect.scrcpyLaunchError !== "")
      return KDEConnect.scrcpyLaunchError;

    if (embeddedMirrorPromotionActive(preview))
      return trSafe("panel.embedded-mirror.promoting-description",
        "Qt has detected the scrcpy video input. Switching from the fallback snapshot to the live feed.");

    if (embeddedMirrorFallbackActive(preview)) {
      if (embeddedMirrorSnapshotFallbackForced())
        return trSafe("panel.embedded-mirror.manual-fallback-description",
          "Manual snapshot fallback is active. Press Feed to return to the live V4L2 feed.");

      const fallbackDetails = preview?.mirrorFeedError !== ""
        ? (" Qt camera failed: " + preview.mirrorFeedError)
        : (preview && !preview.mirrorFeedAvailable && preview.availableVideoInputsSummary !== ""
            ? (" Available inputs: " + preview.availableVideoInputsSummary)
            : "");
      return trSafe("panel.embedded-mirror.fallback-description",
        "The panel is showing the snapshot fallback until the live V4L2 feed is available. Press Fallback if you want to stay on snapshots until you switch back manually.")
        + fallbackDetails;
    }

    if (embeddedMirrorFeedModeEnabled()
        && KDEConnect.scrcpyRunning
        && preview
        && !preview.mirrorFeedAvailable
        && Number(KDEConnect.scrcpyLaunchStartedAtMs || 0) > 0
        && (Date.now() - Number(KDEConnect.scrcpyLaunchStartedAtMs || 0)) >= 5000) {
      const suffix = preview.availableVideoInputsSummary !== ""
        ? (" Available inputs: " + preview.availableVideoInputsSummary)
        : "";
      return trSafe("panel.embedded-mirror.feed-starting-description", "Waiting for the V4L2 video feed to appear in Qt Multimedia.")
        + suffix;
    }

    if (embeddedMirrorFeedModeEnabled()
        && KDEConnect.scrcpyRunning
        && !embeddedMirrorViewActive(preview)
        && Number(KDEConnect.scrcpyLaunchStartedAtMs || 0) > 0
        && (Date.now() - Number(KDEConnect.scrcpyLaunchStartedAtMs || 0)) >= 5000) {
      const feedError = preview && preview.mirrorFeedError !== ""
        ? (" Qt camera failed: " + preview.mirrorFeedError)
        : "";
      return trSafe("panel.embedded-mirror.feed-starting-description", "Waiting for the V4L2 video feed to appear in Qt Multimedia.")
        + feedError;
    }

    if (!embeddedMirrorFeedModeEnabled() && KDEConnect.scrcpyRunning && !KDEConnect.scrcpyWindowReady)
      return trSafe("panel.embedded-mirror.syncing-description", "Waiting for the scrcpy window so it can be aligned to the phone frame.");

    if (KDEConnect.scrcpyRunning && KDEConnect.adbScreenError !== "")
      return KDEConnect.adbScreenError;

    if (KDEConnect.scrcpyRunning && !embeddedMirrorTouchActive())
      return trSafe("panel.embedded-mirror.touch-starting-description", "Querying the Android display size so taps and swipes line up with the mirror.");

    return "";
  }

  function embeddedMirrorSnapshotUrl() {
    if (KDEConnect.v4l2SnapshotVersion <= 0)
      return "";

    return "file://" + embeddedMirrorSnapshotPath + "?v=" + KDEConnect.v4l2SnapshotVersion;
  }

  Process {
    id: embeddedVideoDeviceCheckProc
    running: false
    command: ["sh", "-lc",
      "device=" + KDEConnect.shellQuote(root.embeddedVideoDevice)
      + "; [ -c \"$device\" ] || exit 1"
      + "; [ -w \"$device\" ] || exit 1"
      + "; if command -v udevadm >/dev/null 2>&1; then"
      + " props=$(udevadm info -q property -n \"$device\" 2>/dev/null || true)"
      + "; if printf '%s\\n' \"$props\" | grep -Eq 'ID_V4L_CAPABILITIES=.*:video_(capture|output):'; then"
      + " exit 0"
      + "; fi"
      + "; fi"
      + "; if command -v v4l2-ctl >/dev/null 2>&1; then"
      + " v4l2-ctl -D -d \"$device\" 2>/dev/null | grep -Eq 'Video (Capture|Output)'"
      + "; else"
      + " [ -r \"$device\" ]"
      + "; fi"
    ]

    onExited: (exitCode, exitStatus) => {
      root.embeddedVideoDeviceAccessible = exitCode === 0;
      root.embeddedVideoDeviceCheckKnown = true;

      if (exitCode !== 0) {
        Logger.w("KDEConnect", "Embedded V4L2 device check failed:", root.embeddedVideoDevice);
      }

    }
  }

  Process {
    id: wirelessAdbQrEncodeProc
    running: false
    command: [
      "qrencode",
      "-o", root.wirelessAdbQrImagePath,
      "-s", "10",
      "-m", "1",
      root.wirelessAdbQrPayload()
    ]

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        root.wirelessAdbQrImageVersion += 1;
        if (root.wirelessAdbQrPendingLaunch) {
          root.wirelessAdbQrPendingLaunch = false;
          KDEConnect.pairWirelessAdbByQr(
            root.wirelessAdbQrInstanceName,
            root.wirelessAdbQrSecret,
            90
          );
        }
        return;
      }

      root.wirelessAdbQrPendingLaunch = false;
      const body = root.trSafe("panel.wireless-adb.qr-generate-error-description", "Failed to generate the Wireless ADB QR code.");
      root.wirelessAdbStatusMessage = body;
      ToastService.showWarning(root.trSafe("panel.wireless-adb.error-title", "Wireless ADB"), body, 5000);
    }
  }

  function normalizedToDeviceCoordinate(value, maxValue) {
    if (maxValue <= 0)
      return 0;

    return Math.max(0, Math.min(maxValue - 1, Math.round(value * maxValue)));
  }

  function handleMirrorTap(xNorm, yNorm) {
    if (KDEConnect.adbScreenWidth <= 0 || KDEConnect.adbScreenHeight <= 0)
      return;

    KDEConnect.runAdbTap(
      currentMirrorAdbSerial(),
      normalizedToDeviceCoordinate(xNorm, KDEConnect.adbScreenWidth),
      normalizedToDeviceCoordinate(yNorm, KDEConnect.adbScreenHeight)
    );
  }

  function handleMirrorSwipe(x1Norm, y1Norm, x2Norm, y2Norm, durationMs) {
    if (KDEConnect.adbScreenWidth <= 0 || KDEConnect.adbScreenHeight <= 0)
      return;

    KDEConnect.runAdbSwipe(
      currentMirrorAdbSerial(),
      normalizedToDeviceCoordinate(x1Norm, KDEConnect.adbScreenWidth),
      normalizedToDeviceCoordinate(y1Norm, KDEConnect.adbScreenHeight),
      normalizedToDeviceCoordinate(x2Norm, KDEConnect.adbScreenWidth),
      normalizedToDeviceCoordinate(y2Norm, KDEConnect.adbScreenHeight),
      durationMs
    );
  }

  function handleMirrorScroll(xNorm, yNorm, deltaX, deltaY) {
    if (KDEConnect.adbScreenWidth <= 0 || KDEConnect.adbScreenHeight <= 0)
      return;

    const absDeltaX = Math.abs(deltaX);
    const absDeltaY = Math.abs(deltaY);
    if (absDeltaX === 0 && absDeltaY === 0)
      return;

    const startX = normalizedToDeviceCoordinate(xNorm, KDEConnect.adbScreenWidth);
    const startY = normalizedToDeviceCoordinate(yNorm, KDEConnect.adbScreenHeight);
    const horizontalScroll = absDeltaX > absDeltaY;
    const magnitude = Math.max(0.65, Math.min(2.4, horizontalScroll ? absDeltaX : absDeltaY));

    if (horizontalScroll) {
      const travelX = Math.max(72, Math.round(KDEConnect.adbScreenWidth * 0.075 * magnitude));
      const halfTravelX = Math.max(24, Math.round(travelX / 2));
      const swipeStartX = Math.max(0, Math.min(KDEConnect.adbScreenWidth - 1, startX + (deltaX > 0 ? halfTravelX : -halfTravelX)));
      const swipeEndX = Math.max(0, Math.min(KDEConnect.adbScreenWidth - 1, startX + (deltaX > 0 ? -halfTravelX : halfTravelX)));
      KDEConnect.runAdbSwipe(
        currentMirrorAdbSerial(),
        swipeStartX,
        startY,
        swipeEndX,
        startY,
        115
      );
      return;
    }

    const travelY = Math.max(110, Math.round(KDEConnect.adbScreenHeight * 0.11 * magnitude));
    const halfTravelY = Math.max(32, Math.round(travelY / 2));
    const swipeStartY = Math.max(0, Math.min(KDEConnect.adbScreenHeight - 1, startY + (deltaY < 0 ? halfTravelY : -halfTravelY)));
    const swipeEndY = Math.max(0, Math.min(KDEConnect.adbScreenHeight - 1, startY + (deltaY < 0 ? -halfTravelY : halfTravelY)));
    KDEConnect.runAdbSwipe(
      currentMirrorAdbSerial(),
      startX,
      swipeStartY,
      startX,
      swipeEndY,
      125
    );
  }

  function sendAndroidNavKey(keyCode) {
    KDEConnect.runAdbKeyevent(currentMirrorAdbSerial(), keyCode);
  }

  function sendKeyboardText(text) {
    if (!embeddedMirrorInputActive())
      return;

    KDEConnect.runAdbText(currentMirrorAdbSerial(), text);
  }

  function sendKeyboardKey(keyCode) {
    if (!embeddedMirrorInputActive())
      return;

    KDEConnect.runAdbKeyevent(currentMirrorAdbSerial(), keyCode);
  }

  function sendAndroidHomeOrUnlock() {
    if (!embeddedMirrorInputActive())
      return;

    const serial = currentMirrorAdbSerial();
    KDEConnect.runAdbKeyevent(serial, 224); // WAKEUP
    KDEConnect.runAdbKeyevent(serial, 3); // HOME
  }

  function sendAndroidUnlockOnly() {
    if (!embeddedMirrorInputActive())
      return;

    KDEConnect.runAdbKeyevent(currentMirrorAdbSerial(), 224); // WAKEUP
  }

  component NavActionButton: Rectangle {
    id: navButton

    property string iconName: ""
    property string label: ""
    property bool actionEnabled: true
    property bool circular: false
    property real sizeScale: root.navButtonScaleFactor
    property real circularSize: 46 * Style.uiScaleRatio * sizeScale
    signal pressed

    implicitWidth: circular
      ? circularSize
      : navButtonContent.implicitWidth + (16 * Style.uiScaleRatio * sizeScale)
    implicitHeight: circular
      ? circularSize
      : 36 * Style.uiScaleRatio * sizeScale
    radius: circular ? width / 2 : 13 * Style.uiScaleRatio * sizeScale
    scale: navButton.circular
      ? (navMouse.pressed
          ? 0.94
          : (navMouse.containsMouse ? 1.08 : 1.0))
      : 1.0
    color: circular
      ? (navMouse.containsMouse
          ? Color.mHover
          : Color.mSurfaceVariant)
      : (navMouse.containsMouse
          ? Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.96)
          : Qt.rgba(Color.mSurface.r, Color.mSurface.g, Color.mSurface.b, 0.82))
    border.width: Style.borderS
    border.color: circular
      ? (navMouse.containsMouse
          ? Color.mOutline
          : Color.mOutline)
      : (navMouse.containsMouse
          ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.32)
          : Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.22))
    opacity: actionEnabled ? 1.0 : 0.55

    Behavior on color {
      ColorAnimation { duration: 120 }
    }

    Behavior on scale {
      NumberAnimation {
        duration: 130
        easing.type: Easing.OutCubic
      }
    }

    MouseArea {
      id: navMouse
      anchors.fill: parent
      enabled: navButton.actionEnabled
      hoverEnabled: navButton.actionEnabled
      cursorShape: navButton.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: navButton.pressed()
    }

    RowLayout {
      id: navButtonContent
      anchors.centerIn: parent
      spacing: 5 * Style.uiScaleRatio * navButton.sizeScale

      NIcon {
        icon: navButton.iconName
        pointSize: (navButton.circular ? Style.fontSizeS : Style.fontSizeXS) * navButton.sizeScale
        color: navButton.actionEnabled
          ? (navButton.circular
              ? (navMouse.containsMouse ? Color.mOnHover : Color.mPrimary)
              : Color.mOnSurface)
          : Color.mOnSurfaceVariant
      }

      NText {
        visible: !navButton.circular
        text: navButton.label
        pointSize: Style.fontSizeXXS * navButton.sizeScale
        font.weight: Style.fontWeightMedium
        color: navButton.actionEnabled ? Color.mOnSurface : Color.mOnSurfaceVariant
      }
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: deviceData

      function getBatteryIcon(percentage, isCharging) {
        if (percentage < 0) return "battery-exclamation"
        if (isCharging) return "battery-charging-2"
        if (percentage < 5) return "battery"
        if (percentage < 25) return "battery-1"
        if (percentage < 50) return "battery-2"
        if (percentage < 75) return "battery-3"
        return "battery-4"
      }

      function getCellularTypeIcon(type) {
        switch (type) {
          case "5G":
            return "signal-5g"
          case "LTE":
            return "signal-4g"
          case "HSPA":
            return "signal-h"
          case "UMTS":
            return "signal-3g"
          case "EDGE":
            return "signal-e"
          case "GPRS":
            return "signal-g"
          case "GSM":
            return "signal-2g"
          case "CDMA":
            return "signal-3g"
          case "CDMA2000":
            return "signal-3g"
          case "iDEN":
            return "signal-2g"
          default:
            return "wave-square"
        }
      }

      function getCellularStrengthIcon(strength) {
        switch (strength) {
          case 0:
            return "antenna-bars-1"
          case 1:
            return "antenna-bars-2"
          case 2:
            return "antenna-bars-3"
          case 3:
            return "antenna-bars-4"
          case 4:
            return "antenna-bars-5"
          default:
            return "antenna-bars-off"
        }
      }

      function getSignalStrengthText(strength) {
        switch (strength) {
          case 0:
            return pluginApi?.tr("panel.signal.very-weak")
          case 1:
            return pluginApi?.tr("panel.signal.weak")
          case 2:
            return pluginApi?.tr("panel.signal.fair")
          case 3:
            return pluginApi?.tr("panel.signal.good")
          case 4:
            return pluginApi?.tr("panel.signal.excellent")
          default:
            return pluginApi?.tr("panel.unknown")
        }
      }

      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginM

      Loader {
        Layout.fillWidth: true
        Layout.fillHeight: !(KDEConnect.mainDevice !== null && KDEConnect.mainDevice.paired)
        Layout.alignment: Qt.AlignTop
        active: true
        sourceComponent:  (KDEConnect.busctlCmd === null || KDEConnect.busctlCmd === "")       ? busctlNotFoundCard               :
                          (!KDEConnect.daemonAvailable)                                        ? kdeConnectDaemonNotRunningCard   :
                          (deviceSwitcherOpen)                                                 ? deviceSwitcherCard               :
                          (KDEConnect.mainDevice !== null &&  KDEConnect.mainDevice.paired)    ? deviceConnectedCard              :
                          (KDEConnect.mainDevice !== null && !KDEConnect.mainDevice.paired)    ? noDevicePairedCard               :
                          (KDEConnect.devices.length === 0)                                    ? noDevicesAvailableCard           :
                          null
      }

      Component {
        id: deviceConnectedCard

        Rectangle {
          Layout.fillWidth: true
          color: "transparent"
          radius: Style.radiusL
          implicitHeight: contentLayout.implicitHeight + (Style.marginS * 2)

          ColumnLayout {
            id: contentLayout
            anchors {
              fill: parent
              margins: Style.marginS
            }
            spacing: Style.marginM

            NFilePicker {
              id: shareFilePicker
              title: pluginApi?.tr("panel.send-file-picker")
              selectionMode: "files"
              initialPath: Quickshell.env("HOME")
              nameFilters: ["*"]
              onAccepted: paths => {
                if (paths.length > 0) {
                  for (const path of paths) {
                    KDEConnect.shareFile(KDEConnect.mainDevice.id, path)
                  }
                }
              }
            }

            Loader {
              Layout.fillWidth: true
              Layout.fillHeight: true
              active: KDEConnect.mainDevice !== null
              sourceComponent: deviceStatsWithPhone
            }

          }

          Component {
            id: deviceStatsWithPhone

            ColumnLayout {
              spacing: Style.marginXS
              Layout.fillWidth: true

              Component.onCompleted: {
                root.scheduleEmbeddedMirrorAutoStart();
              }

              Rectangle {
                id: remoteStageCard
                Layout.fillWidth: true
                implicitHeight: remoteStageContent.implicitHeight + (Style.marginS * 2)
                radius: Style.radiusL
                color: "transparent"
                border.width: 0
                border.color: "transparent"

                ColumnLayout {
                  id: remoteStageContent
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  spacing: Style.marginXS

                  NBox {
                    id: headerBox
                    Layout.fillWidth: true
                    implicitHeight: headerContent.implicitHeight + Style.margin2M

                    ColumnLayout {
                      id: headerContent
                      anchors.fill: parent
                      anchors.margins: Style.marginM
                      spacing: Style.marginM

                      RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                          Layout.alignment: Qt.AlignVCenter
                          Layout.preferredWidth: 34 * Style.uiScaleRatio
                          Layout.preferredHeight: 34 * Style.uiScaleRatio
                          radius: 17 * Style.uiScaleRatio
                          color: "#211814"
                          border.width: Style.borderS
                          border.color: "#6c4c3e"

                          NIcon {
                            anchors.centerIn: parent
                            icon: "device-mobile"
                            pointSize: Style.fontSizeS
                            color: "#f4ae89"
                          }
                        }

                        NText {
                          text: KDEConnect.mainDevice.name
                          pointSize: Style.fontSizeL * 1.55
                          font.weight: Style.fontWeightBold
                          color: "#fff5ef"
                          Layout.fillWidth: true
                          elide: Text.ElideRight
                        }

                        RowLayout {
                          Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                          spacing: Style.marginXS

                          NIconButton {
                            visible: root.embeddedMirrorModeEnabled()
                            icon: root.embeddedMirrorForceSnapshotFallback ? "device-mobile-off" : "device-mobile"
                            tooltipText: root.embeddedMirrorForceSnapshotFallback
                              ? root.trSafe("panel.embedded-mirror.feed-button", "Feed")
                              : root.trSafe("panel.embedded-mirror.fallback-button", "Fallback")
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: "#211814"
                            colorFg: "#f4ae89"
                            colorBgHover: "#3a261f"
                            colorFgHover: "#fff4ed"
                            colorBorder: "#6c4c3e"
                            colorBorderHover: "#f4ae89"
                            enabled: !root.embeddedMirrorPendingSessionRecovery
                            onClicked: root.toggleEmbeddedMirrorSnapshotFallbackMode()
                          }

                          NIconButton {
                            readonly property bool multipleDevices: KDEConnect.devices.length > 1
                            icon: "swipe"
                            tooltipText: multipleDevices ? pluginApi?.tr("panel.other-devices") : ""
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: "#211814"
                            colorFg: "#f4ae89"
                            colorBgHover: "#3a261f"
                            colorFgHover: "#fff4ed"
                            colorBorder: "#6c4c3e"
                            colorBorderHover: "#f4ae89"
                            onClicked: {
                              deviceSwitcherOpen = !deviceSwitcherOpen
                            }
                            enabled: KDEConnect.daemonAvailable && multipleDevices
                            opacity: multipleDevices ? 1.0 : 0.0
                          }

                          NIconButton {
                            icon: "zoom-in"
                            tooltipText: root.trSafe("panel.phone-size.tooltip", "Phone size: ")
                              + root.phoneSizeLabel + " (" + root.phoneSizePercent + "%)"
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: "#211814"
                            colorFg: "#f4ae89"
                            colorBgHover: "#3a261f"
                            colorFgHover: "#fff4ed"
                            colorBorder: "#6c4c3e"
                            colorBorderHover: "#f4ae89"
                            onClicked: root.cyclePhoneSizePreset()
                          }

                          NIconButton {
                            icon: "wifi"
                            tooltipText: !root.wirelessAdbEnabled
                              ? root.trSafe("panel.wireless-adb.disabled-tooltip", "Wireless ADB is disabled in settings. Open details.")
                              : KDEConnect.wirelessAdbBusy
                              ? root.trSafe("panel.wireless-adb.busy-tooltip", "Wireless ADB command is running")
                              : root.trSafe("panel.wireless-adb.tooltip", "Open Wireless ADB tools")
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: "#211814"
                            colorFg: "#f4ae89"
                            colorBgHover: "#3a261f"
                            colorFgHover: "#fff4ed"
                            colorBorder: "#6c4c3e"
                            colorBorderHover: "#f4ae89"
                            onClicked: root.openWirelessAdbDialog()
                          }

                          NIconButton {
                            icon: "device-mobile-search"
                            tooltipText: pluginApi?.tr("panel.browse-device")
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: "#211814"
                            colorFg: "#f4ae89"
                            colorBgHover: "#3a261f"
                            colorFgHover: "#fff4ed"
                            colorBorder: "#6c4c3e"
                            colorBorderHover: "#f4ae89"
                            onClicked: KDEConnect.browseFiles(KDEConnect.mainDevice.id)
                          }

                          NIconButton {
                            icon: "device-mobile-share"
                            tooltipText: pluginApi?.tr("panel.send-file")
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: "#211814"
                            colorFg: "#f4ae89"
                            colorBgHover: "#3a261f"
                            colorFgHover: "#fff4ed"
                            colorBorder: "#6c4c3e"
                            colorBorderHover: "#f4ae89"
                            onClicked: shareFilePicker.open()
                          }

                          NIconButton {
                            icon: "radar"
                            tooltipText: pluginApi?.tr("panel.find-device")
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: "#211814"
                            colorFg: "#f4ae89"
                            colorBgHover: "#3a261f"
                            colorFgHover: "#fff4ed"
                            colorBorder: "#6c4c3e"
                            colorBorderHover: "#f4ae89"
                            onClicked: KDEConnect.triggerFindMyPhone(KDEConnect.mainDevice.id)
                          }
                        }
                      }
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Style.marginS

                    ColumnLayout {
                      id: phoneColumn
                      Layout.alignment: Qt.AlignTop
                      spacing: Style.marginXS

                      Item {
                        id: phonePreviewContainer
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.phoneBaseWidth * root.phoneSizeFactor
                        Layout.preferredHeight: root.phoneBaseHeight * root.phoneSizeFactor
                        implicitWidth: Layout.preferredWidth
                        implicitHeight: Layout.preferredHeight

                        Behavior on Layout.preferredWidth {
                          enabled: root.phoneSizeAnimationEnabled
                          NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.panelResizeBezierCurve
                          }
                        }

                        Behavior on Layout.preferredHeight {
                          enabled: root.phoneSizeAnimationEnabled
                          NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.panelResizeBezierCurve
                          }
                        }

                        PhoneDisplay {
                          id: phonePreview
                          anchors.fill: parent
                          backgroundImage: root.embeddedMirrorFeedModeEnabled()
                            ? root.embeddedMirrorSnapshotUrl()
                            : ""
                          mirrorFeedEnabled: root.embeddedMirrorFeedModeEnabled()
                            && KDEConnect.scrcpyRunning
                            && (!root.embeddedMirrorForceSnapshotFallback
                                || KDEConnect.v4l2SnapshotVersion <= 0)
                          overlayWindowActive: !root.embeddedMirrorFeedModeEnabled() && root.passthroughHoleEnabled
                          mirrorDeviceIdMatch: root.embeddedVideoDevice
                          mirrorDeviceDescriptionMatch: root.embeddedVideoLabel
                          mirrorContentWidth: KDEConnect.adbScreenWidth
                          mirrorContentHeight: KDEConnect.adbScreenHeight
                          interactiveScreen: root.embeddedMirrorTouchActive()
                          showStatusOverlay: root.embeddedMirrorModeEnabled()
                            ? root.embeddedMirrorPhoneOverlayVisible()
                            : true
                          statusTitle: root.embeddedMirrorModeEnabled()
                            ? root.embeddedMirrorPhoneStatusTitle(phonePreview)
                            : root.phoneStatusTitle()
                          statusSubtitle: root.embeddedMirrorModeEnabled()
                            ? root.embeddedMirrorPhoneStatusSubtitle(phonePreview)
                            : root.phoneStatusSubtitle()
                          busy: KDEConnect.scrcpyLaunching
                            || (root.embeddedMirrorModeEnabled() && KDEConnect.scrcpyRunning
                                && ((root.embeddedMirrorFeedModeEnabled() && !phonePreview.mirrorFeedAvailable)
                                    || (!root.embeddedMirrorFeedModeEnabled() && !KDEConnect.scrcpyWindowReady)
                                    || KDEConnect.adbDisplayInfoSerial !== ""))

                          Component.onCompleted: {
                            root.activePhonePreview = phonePreview;
                            root.scheduleEmbeddedMirrorAutoStart();
                          }

                          Component.onDestruction: {
                            if (root.activePhonePreview === phonePreview)
                              root.activePhonePreview = null;
                          }

                          onClicked: root.handlePhoneClick(phonePreview)
                          onTapRequested: (x, y) => root.handleMirrorTap(x, y)
                          onSwipeRequested: (x1, y1, x2, y2, durationMs) => root.handleMirrorSwipe(x1, y1, x2, y2, durationMs)
                          onScrollRequested: (x, y, deltaX, deltaY) => root.handleMirrorScroll(x, y, deltaX, deltaY)
                          onTextRequested: text => root.sendKeyboardText(text)
                          onKeyRequested: keyCode => root.sendKeyboardKey(keyCode)
                          onHomeRequested: root.sendAndroidHomeOrUnlock()
                        }
                      }

                      RowLayout {
                        id: navRow
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: phonePreviewContainer.width
                        Layout.fillWidth: false
                        spacing: Style.marginS
                        visible: root.embeddedMirrorModeEnabled() && !KDEConnect.scrcpyRunning

                        Item { Layout.fillWidth: true }

                        NavActionButton {
                          circular: true
                          iconName: "arrow-back"
                          label: root.trSafe("panel.embedded-mirror.nav-back", "Back")
                          actionEnabled: root.embeddedMirrorInputActive()
                          onPressed: root.sendAndroidNavKey(4)
                        }

                        Item { Layout.fillWidth: true }

                        NavActionButton {
                          circular: true
                          iconName: "home"
                          label: root.trSafe("panel.embedded-mirror.nav-home", "Home")
                          actionEnabled: root.embeddedMirrorInputActive()
                          onPressed: root.sendAndroidNavKey(3)
                        }

                        Item { Layout.fillWidth: true }

                        NavActionButton {
                          circular: true
                          iconName: "layout-grid"
                          label: root.trSafe("panel.embedded-mirror.nav-recents", "Recents")
                          actionEnabled: root.embeddedMirrorInputActive()
                          onPressed: root.sendAndroidNavKey(187)
                        }

                        Item { Layout.fillWidth: true }
                      }

                      Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.mirrorDebugOverlayEnabled && root.embeddedMirrorModeEnabled()
                        implicitWidth: debugPerfText.implicitWidth + (Style.marginM * 1.6)
                        implicitHeight: debugPerfText.implicitHeight + (Style.marginXS * 1.4)
                        radius: implicitHeight / 2
                        color: "#24191514"
                        border.width: Style.borderS
                        border.color: "#6c4c3e"

                        NText {
                          id: debugPerfText
                          anchors.centerIn: parent
                          text: root.mirrorPerfSummary()
                          pointSize: Style.fontSizeXXS
                          color: "#d7c4b8"
                        }
                      }
                    }

                    ColumnLayout {
                      id: rightInfoColumn
                      Layout.alignment: Qt.AlignTop
                      Layout.fillWidth: true
                      Layout.topMargin: 12 * Style.uiScaleRatio
                      spacing: Style.marginL * 1.1

                      ColumnLayout {
                        id: deviceSummaryColumn
                        Layout.fillWidth: true
                        spacing: Style.marginL * 1.1

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.marginS

                          NIcon {
                            icon: deviceData.getBatteryIcon(root.effectiveBatteryValue(KDEConnect.mainDevice), root.effectiveChargingValue(KDEConnect.mainDevice))
                            pointSize: Style.fontSizeXL * 1.2075
                            color: "#f4e3b6"
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 38 * Style.uiScaleRatio
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1 * Style.uiScaleRatio

                            NText {
                              text: pluginApi?.tr("panel.card.battery") || "Battery"
                              pointSize: Style.fontSizeS * 1.15
                              color: "#c9b79b"
                            }

                            NText {
                              text: root.effectiveBatteryValue(KDEConnect.mainDevice) < 0
                                ? (pluginApi?.tr("panel.unknown") || "Unknown")
                                : (root.effectiveBatteryValue(KDEConnect.mainDevice) + "%")
                              pointSize: Style.fontSizeL * 1.288
                              font.weight: Style.fontWeightBold
                              color: "#fff5ef"
                            }
                          }
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.marginS

                          NIcon {
                            icon: deviceData.getCellularTypeIcon(root.effectiveNetworkType(KDEConnect.mainDevice))
                            pointSize: Style.fontSizeXL * 1.2075
                            color: "#f4e3b6"
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 38 * Style.uiScaleRatio
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1 * Style.uiScaleRatio

                            NText {
                              text: pluginApi?.tr("panel.card.network") || "Network"
                              pointSize: Style.fontSizeS * 1.15
                              color: "#c9b79b"
                            }

                            NText {
                              text: root.effectiveNetworkType(KDEConnect.mainDevice) || (pluginApi?.tr("panel.unknown") || "Unknown")
                              pointSize: Style.fontSizeL * 1.288
                              font.weight: Style.fontWeightBold
                              color: "#fff5ef"
                            }
                          }
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.marginS

                          NIcon {
                            icon: deviceData.getCellularStrengthIcon(root.effectiveSignalStrength(KDEConnect.mainDevice))
                            pointSize: Style.fontSizeXL * 1.2075
                            color: "#f4e3b6"
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 38 * Style.uiScaleRatio
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1 * Style.uiScaleRatio

                            NText {
                              text: root.trSafe("panel.card.signal", "Signal")
                              pointSize: Style.fontSizeS * 1.15
                              color: "#c9b79b"
                            }

                            NText {
                              text: deviceData.getSignalStrengthText(root.effectiveSignalStrength(KDEConnect.mainDevice))
                                || (pluginApi?.tr("panel.unknown") || "Unknown")
                              pointSize: Style.fontSizeL * 1.288
                              font.weight: Style.fontWeightBold
                              color: "#fff5ef"
                            }
                          }
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.marginS

                          NIcon {
                            icon: "bell"
                            pointSize: Style.fontSizeXL * 1.2075
                            color: "#f4e3b6"
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 38 * Style.uiScaleRatio
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1 * Style.uiScaleRatio

                            NText {
                              text: pluginApi?.tr("panel.card.notifications") || "Notifications"
                              pointSize: Style.fontSizeS * 1.15
                              color: "#c9b79b"
                            }

                            NText {
                              text: String(root.effectiveNotificationCount(KDEConnect.mainDevice))
                              pointSize: Style.fontSizeL * 1.288
                              font.weight: Style.fontWeightBold
                              color: "#fff5ef"
                            }
                          }
                        }
                      }

                      Rectangle {
                        id: embeddedMirrorStatusCard
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: Math.min(
                          implicitHeight,
                          Math.max(
                            (root.phoneSizePresetIndex === 0 ? 104 : (root.phoneSizePresetIndex === 1 ? 118 : 132)) * Style.uiScaleRatio,
                            phonePreviewContainer.height
                              - rightInfoColumn.Layout.topMargin
                              - deviceSummaryColumn.implicitHeight
                              - rightInfoColumn.spacing
                          )
                        )
                        Layout.maximumHeight: Layout.preferredHeight
                        Layout.topMargin: root.embeddedMirrorDrawerStatusVisible(phonePreview) ? Style.marginS : 0
                        visible: root.embeddedMirrorDrawerStatusVisible(phonePreview)
                        implicitHeight: Math.max(
                          drawerStatusContent.implicitHeight + (Style.marginM * 1.8),
                          (root.phoneSizePresetIndex === 0 ? 104 : (root.phoneSizePresetIndex === 1 ? 118 : 132)) * Style.uiScaleRatio
                        )
                        radius: 18 * Style.uiScaleRatio
                        color: "#211814"
                        border.width: Style.borderS
                        border.color: "#6c4c3e"
                        clip: true

                        ColumnLayout {
                          id: drawerStatusContent
                          anchors.fill: parent
                          anchors.margins: Style.marginM
                          spacing: Style.marginXS

                          NText {
                            Layout.fillWidth: true
                            text: root.embeddedMirrorDrawerStatusTitle(phonePreview)
                            pointSize: Style.fontSizeS * (root.phoneSizePresetIndex === 0 ? 1.02 : 1.1)
                            font.weight: Style.fontWeightBold
                            color: "#fff4ed"
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                          }

                          NText {
                            Layout.fillWidth: true
                            text: root.embeddedMirrorDrawerStatusSubtitle(phonePreview)
                            pointSize: Style.fontSizeXS * (root.phoneSizePresetIndex === 0 ? 1.0 : 1.06)
                            color: "#d9c8bb"
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                          }

                          Item {
                            Layout.fillHeight: true
                            visible: true
                          }
                        }
                      }

                      Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.embeddedMirrorDrawerStatusVisible(phonePreview)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      Component {
        id: noDevicePairedCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: implicitHeight
          color: "#1c1517"
          radius: 24 * Style.uiScaleRatio
          implicitHeight: noDevicePairedContent.implicitHeight + (Style.marginL * 2.4)

          ColumnLayout {
            id: noDevicePairedContent
            anchors {
              fill: parent
              margins: Style.marginL * 1.2
            }
            spacing: Style.marginL * 1.1

            RowLayout {
              Layout.fillWidth: true
              NText {
                text: KDEConnect.mainDevice?.name || root.trSafe("panel.unknown", "Unknown")
                pointSize: Style.fontSizeXXL
                font.weight: Style.fontWeightBold
                color: "#fff4ed"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: pairStateColumn.implicitHeight + (Style.marginL * 1.8)
              color: "#241b1d"
              radius: 20 * Style.uiScaleRatio
              border.width: Style.borderS
              border.color: "#6c4c3e"

              ColumnLayout {
                id: pairStateColumn
                anchors.fill: parent
                anchors.margins: Style.marginL * 1.1
                spacing: Style.marginM

                Item {
                  Layout.fillWidth: true
                  implicitHeight: pairHeader.implicitHeight

                  RowLayout {
                    id: pairHeader
                    anchors.centerIn: parent
                    spacing: Style.marginM

                    Rectangle {
                      width: 48 * Style.uiScaleRatio
                      height: width
                      radius: width / 2
                      color: KDEConnect.mainDevice.pairRequested ? "#3a261f" : "#2f231c"
                      border.width: Style.borderS
                      border.color: KDEConnect.mainDevice.pairRequested ? "#f4ae89" : "#6c4c3e"

                      NIcon {
                        anchors.centerIn: parent
                        icon: KDEConnect.mainDevice.pairRequested ? "key" : "device-mobile"
                        pointSize: Style.fontSizeXL
                        color: KDEConnect.mainDevice.pairRequested ? "#ffd7c3" : "#f4ae89"
                      }
                    }

                    ColumnLayout {
                      spacing: 2 * Style.uiScaleRatio

                      NText {
                        text: KDEConnect.mainDevice.pairRequested
                          ? root.trSafe("panel.pair-requested-title", "Pairing Request Sent")
                          : root.trSafe("panel.pair-needed-title", "Pairing Needed")
                        pointSize: Style.fontSizeL * 1.06
                        font.weight: Style.fontWeightBold
                        color: "#fff4ed"
                      }

                      NText {
                        text: KDEConnect.mainDevice.pairRequested
                          ? root.trSafe("panel.pair-requested-subtitle", "Approve the request on the phone to restore controls.")
                          : root.trSafe("panel.pair-needed-subtitle", "KDE Connect reported this device as temporarily unpaired.")
                        pointSize: Style.fontSizeS * 1.02
                        color: "#cdb7ab"
                      }
                    }
                  }
                }

                NText {
                  Layout.fillWidth: true
                  text: KDEConnect.mainDevice.pairRequested
                    ? root.trSafe("panel.pair-requested", "Confirm the pairing request on the phone. The mirror and device actions will come back automatically after approval.")
                    : root.trSafe("panel.pair-description", "This device is temporarily reported as unpaired. Retry pairing here if KDE Connect did not recover on its own after reconnecting.")
                  color: "#d9c8bb"
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                NButton {
                  text: root.trSafe("panel.pair", "Pair with Device")
                  Layout.alignment: Qt.AlignHCenter
                  Layout.minimumWidth: 220 * Style.uiScaleRatio
                  enabled: !KDEConnect.mainDevice.pairRequested
                  icon: "key"
                  onClicked: {
                    KDEConnect.requestPairing(KDEConnect.mainDevice.id)
                    KDEConnect.mainDevice.pairRequested = true
                    KDEConnect.refreshDevices()
                  }
                }

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  visible: KDEConnect.mainDevice.pairRequested && String(KDEConnect.mainDevice.verificationKey || "").trim() !== ""
                  color: "#2e2220"
                  radius: 14 * Style.uiScaleRatio
                  border.width: Style.borderS
                  border.color: "#7d5b4e"
                  implicitWidth: verificationRow.implicitWidth + (Style.marginM * 1.4)
                  implicitHeight: verificationRow.implicitHeight + (Style.marginS * 1.4)

                  RowLayout {
                    id: verificationRow
                    anchors.centerIn: parent
                    spacing: Style.marginS

                    NIcon {
                      icon: "key"
                      pointSize: Style.fontSizeL
                      color: "#f4d0be"
                    }

                    NText {
                      text: KDEConnect.mainDevice.verificationKey
                      pointSize: Style.fontSizeL
                      font.weight: Style.fontWeightBold
                      color: "#fff4ed"
                    }
                  }
                }

                NBusyIndicator {
                  Layout.alignment: Qt.AlignHCenter
                  visible: KDEConnect.mainDevice.pairRequested
                  size: Style.baseWidgetSize * 0.5
                  running: KDEConnect.mainDevice.pairRequested
                }

                NText {
                  Layout.fillWidth: true
                  visible: KDEConnect.mainDevice.pairRequested
                  text: root.trSafe("panel.pair-waiting", "Waiting for the phone to accept the pairing request.")
                  pointSize: Style.fontSizeS
                  color: "#bda99e"
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }
          }
        }
      }

      Component {
        id: noDevicesAvailableCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "device-mobile-off"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.no-devices")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }


      Component {
        id: busctlNotFoundCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "exclamation-circle"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.busctl-error.unavailable-title")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            NText {
              text: pluginApi?.tr("panel.busctl-error.unavailable-desc")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      Component {
        id: kdeConnectDaemonNotRunningCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: emptyState
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            Item {
              Layout.fillHeight: true
            }

            NIcon {
              icon: "exclamation-circle"
              pointSize: 48 * Style.uiScaleRatio
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item {}

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.unavailable-title")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            NText {
              text: pluginApi?.tr("panel.kdeconnect-error.unavailable-desc")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignCenter
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            Item {
              Layout.fillHeight: true
            }
          }
        }
      }

      Component {
        id: deviceSwitcherCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          NScrollView{
            horizontalPolicy: ScrollBar.AlwaysOff
            verticalPolicy: ScrollBar.AsNeeded
            contentWidth: parent.width
            reserveScrollbarSpace: false
            gradientColor: Color.mSurface

            ColumnLayout {
              id: emptyState
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginM

              Repeater {
                model: KDEConnect.devices
                Layout.fillWidth: true

                NButton {
                  required property var modelData
                  text: modelData.name
                  Layout.fillWidth: true
                  backgroundColor: modelData.id === KDEConnect.mainDevice.id ? Color.mSecondary : Color.mPrimary

                  onClicked: {
                    KDEConnect.setMainDevice(modelData.id);
                    deviceSwitcherOpen = false;

                    pluginApi.pluginSettings.mainDeviceId = modelData.id;
                    pluginApi.saveSettings();
                  }
                }
              }

              Item {
                Layout.fillHeight: true
              }
            }
          }
        }
      }
    }
  }

  Popup {
    id: wirelessAdbPopup
    parent: root
    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent
    width: Math.min(620 * Style.uiScaleRatio, root.width - (Style.marginL * 2))
    height: Math.min(wirelessAdbContentColumn.implicitHeight + (padding * 2), root.height - (Style.marginL * 2))
    padding: Style.marginL

    onOpened: {
      Qt.callLater(() => {
        if (pairHostInput.inputItem) {
          pairHostInput.inputItem.forceActiveFocus();
        }
      });
    }

    background: Rectangle {
      color: Color.mSurface
      radius: Style.radiusL
      border.color: Color.mOutline
      border.width: Style.borderM
    }

    contentItem: Flickable {
      id: wirelessAdbFlickable
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: width
      contentHeight: wirelessAdbContentColumn.implicitHeight
      implicitHeight: Math.min(wirelessAdbContentColumn.implicitHeight, root.height - (Style.marginL * 4))

      ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
      }

      ColumnLayout {
        id: wirelessAdbContentColumn
        width: wirelessAdbFlickable.width - Style.marginXS
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true

          NText {
            text: root.trSafe("panel.wireless-adb.dialog-title", "Wireless ADB")
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            onClicked: wirelessAdbPopup.close()
          }
        }

        NText {
          text: root.trSafe("panel.wireless-adb.dialog-description", "Pair once from Android's Wireless debugging screen, then connect with the adb port shown on the phone.")
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        NToggle {
          Layout.fillWidth: true
          label: root.trSafe("panel.wireless-adb.cable-only-label", "Cable-only mode")
          description: root.trSafe("panel.wireless-adb.cable-only-description", "Disable Wireless ADB fallback and force USB-only scrcpy and adb input for this plugin.")
          checked: !root.wirelessAdbEnabled
          onToggled: checked => root.persistWirelessAdbMode(checked)
        }

        Rectangle {
          Layout.fillWidth: true
          visible: !root.wirelessAdbEnabled
          color: "#2b2118"
          radius: Style.radiusM
          border.color: "#d1a06c"
          border.width: Style.borderS
          implicitHeight: usbModeBannerColumn.implicitHeight + (Style.marginM * 2)

          ColumnLayout {
            id: usbModeBannerColumn
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginXS

            NText {
              text: root.trSafe("panel.wireless-adb.disabled-banner-title", "Cable-only mode is active")
              font.weight: Style.fontWeightBold
              color: "#f6ddc2"
              Layout.fillWidth: true
            }

            NText {
              text: root.trSafe("panel.wireless-adb.disabled-banner-description", "Wireless tools stay visible here for reference, but they are disabled until Wireless ADB is re-enabled in plugin settings.")
              color: "#e8ccb0"
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: qrStep.implicitHeight + (Style.marginM * 2)
          opacity: root.wirelessAdbEnabled ? 1.0 : 0.5

          ColumnLayout {
            id: qrStep
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NText {
              text: "1. " + root.trSafe("panel.wireless-adb.qr-section-title", "Pair with QR code")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: root.trSafe("panel.wireless-adb.qr-section-description", "On the phone, open Wireless debugging and choose Pair device with QR code, then scan this image.")
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              Rectangle {
                Layout.preferredWidth: 176 * Style.uiScaleRatio
                Layout.preferredHeight: 176 * Style.uiScaleRatio
                radius: Style.radiusM
                color: "#ffffff"
                border.color: Qt.rgba(Color.mOutline.r, Color.mOutline.g, Color.mOutline.b, 0.5)
                border.width: Style.borderS

                Image {
                  anchors.fill: parent
                  anchors.margins: 12 * Style.uiScaleRatio
                  source: root.wirelessAdbQrImageSource()
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  visible: source !== ""
                }

                NText {
                  anchors.centerIn: parent
                  width: parent.width - (Style.marginM * 2)
                  text: root.trSafe("panel.wireless-adb.qr-placeholder", "Tap Start QR to generate a pairing code.")
                  visible: root.wirelessAdbQrImageSource() === ""
                  color: "#4b5563"
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: root.trSafe("panel.wireless-adb.qr-helper-description", "The plugin will wait for the scan, pair automatically, then connect ADB and save the resolved host and port.")
                  color: Color.mOnSurfaceVariant
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }

                NButton {
                  text: KDEConnect.wirelessAdbBusy
                    ? root.trSafe("panel.wireless-adb.qr-waiting-button", "Waiting for scan...")
                    : (root.wirelessAdbQrImageSource() !== ""
                        ? root.trSafe("panel.wireless-adb.qr-refresh-button", "Refresh QR")
                        : root.trSafe("panel.wireless-adb.qr-button", "Start QR Pairing"))
                  icon: "view-barcode-qr"
                  enabled: root.wirelessAdbEnabled && !wirelessAdbQrEncodeProc.running && !KDEConnect.wirelessAdbBusy
                  onClicked: root.beginWirelessAdbQrPairing()
                }

                NText {
                  text: root.trSafe("panel.wireless-adb.qr-footer-description", "Leave this popup open until the phone finishes the scan.")
                  color: Color.mOnSurfaceVariant
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }
              }
            }
          }
        }

        NTextInput {
          id: pairHostInput
          Layout.fillWidth: true
          enabled: root.wirelessAdbEnabled
          opacity: root.wirelessAdbEnabled ? 1.0 : 0.5
          label: root.trSafe("panel.wireless-adb.host-label", "Phone IP")
          placeholderText: "192.168.1.120"
          text: root.wirelessAdbPairHost
          onTextChanged: {
            root.wirelessAdbPairHost = text;
            root.wirelessAdbConnectHost = text;
          }
          onEditingFinished: root.persistWirelessAdbSettings()
        }

        Rectangle {
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: pairStep.implicitHeight + (Style.marginM * 2)
          opacity: root.wirelessAdbEnabled ? 1.0 : 0.5

          ColumnLayout {
            id: pairStep
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NText {
              text: "2. " + root.trSafe("panel.wireless-adb.pair-section-title", "Pair with code")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: root.trSafe("panel.wireless-adb.pair-section-description", "On the phone, open Wireless debugging and choose Pair device with pairing code.")
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginM

              NTextInput {
                Layout.preferredWidth: 150 * Style.uiScaleRatio
                enabled: root.wirelessAdbEnabled
                label: root.trSafe("panel.wireless-adb.pair-port-label", "Pair port")
                placeholderText: "37099"
                text: root.wirelessAdbPairPort
                onTextChanged: root.wirelessAdbPairPort = text
                onEditingFinished: root.persistWirelessAdbSettings()
              }

              NTextInput {
                Layout.fillWidth: true
                enabled: root.wirelessAdbEnabled
                label: root.trSafe("panel.wireless-adb.pair-code-label", "Pairing code")
                placeholderText: "123456"
                text: root.wirelessAdbPairingCode
                onTextChanged: root.wirelessAdbPairingCode = text
              }
            }

            RowLayout {
              Layout.fillWidth: true

              Item {
                Layout.fillWidth: true
              }

              NButton {
                text: root.trSafe("panel.wireless-adb.pair-button", "Pair")
                icon: "key"
                enabled: root.wirelessAdbEnabled
                  && !KDEConnect.wirelessAdbBusy
                  && (root.wirelessAdbPairHost || "").trim() !== ""
                  && (root.wirelessAdbPairPort || "").trim() !== ""
                  && (root.wirelessAdbPairingCode || "").trim() !== ""
                onClicked: root.startWirelessAdbPairing()
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: connectStep.implicitHeight + (Style.marginM * 2)
          opacity: root.wirelessAdbEnabled ? 1.0 : 0.5

          ColumnLayout {
            id: connectStep
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NText {
              text: "3. " + root.trSafe("panel.wireless-adb.connect-section-title", "Connect after pairing")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: root.trSafe("panel.wireless-adb.connect-section-description", "After pairing, use the adb port shown on the phone. The same phone IP above will be reused.")
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            NTextInput {
              Layout.fillWidth: true
              enabled: root.wirelessAdbEnabled
              label: root.trSafe("panel.wireless-adb.connect-port-label", "ADB port")
              placeholderText: "43127"
              text: root.wirelessAdbConnectPort
              onTextChanged: root.wirelessAdbConnectPort = text
              onEditingFinished: root.persistWirelessAdbSettings()
            }

            RowLayout {
              Layout.fillWidth: true

              NText {
                text: (root.wirelessAdbPairHost || "").trim() !== ""
                  ? (root.trSafe("panel.wireless-adb.host-label", "Phone IP") + ": " + root.wirelessAdbPairHost)
                  : ""
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
                visible: text !== ""
                elide: Text.ElideRight
              }

              NButton {
                text: root.trSafe("panel.wireless-adb.connect-button", "Connect")
                icon: "plug-connected"
                enabled: root.wirelessAdbEnabled
                  && !KDEConnect.wirelessAdbBusy
                  && (((root.wirelessAdbConnectHost || "").trim() !== "") || ((root.wirelessAdbPairHost || "").trim() !== ""))
                  && (root.wirelessAdbConnectPort || "").trim() !== ""
                onClicked: root.startWirelessAdbConnect()
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          visible: root.wirelessAdbStatusMessage !== "" || KDEConnect.wirelessAdbBusy
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: statusColumn.implicitHeight + (Style.marginM * 2)

          ColumnLayout {
            id: statusColumn
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
              text: KDEConnect.wirelessAdbBusy
                ? root.trSafe("panel.wireless-adb.running-status", "Running adb command...")
                : root.trSafe("panel.wireless-adb.status-title", "Last result")
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: KDEConnect.wirelessAdbBusy
                ? root.trSafe("panel.wireless-adb.running-description", "Keep this panel open until adb finishes.")
                : root.wirelessAdbStatusMessage
              color: Color.mOnSurfaceVariant
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }
      }
    }
  }
}
