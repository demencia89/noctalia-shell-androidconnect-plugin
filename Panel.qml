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
  readonly property string embeddedMirrorCommand: "scrcpy --no-audio --capture-orientation=@0"
  readonly property bool reduceBackgroundRefreshWhileMirroring: true
  readonly property string embeddedVideoDevice: "/dev/video10"
  readonly property string embeddedVideoLabel: "scrcpy-panel"
  readonly property int embeddedMirrorSnapshotIntervalMs: Math.max(
    10,
    Math.round(cfg.embeddedMirrorSnapshotIntervalMs ?? defaults.embeddedMirrorSnapshotIntervalMs ?? 80)
  )
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
  readonly property string embeddedMirrorLoopbackSetupCommand: "sudo modprobe v4l2loopback video_nr=10 card_label=scrcpy-panel exclusive_caps=1"
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
  property double embeddedVideoDeviceLastCheckAtMs: 0
  readonly property bool embeddedMirrorDiagnosticsEnabled: false
  property bool embeddedMirrorForceSnapshotFallback: Boolean(
    cfg.embeddedMirrorForceSnapshotFallback
    ?? defaults.embeddedMirrorForceSnapshotFallback
    ?? false
  )
  property bool embeddedMirrorAudioEnabled: Boolean(
    cfg.embeddedMirrorAudioEnabled
    ?? defaults.embeddedMirrorAudioEnabled
    ?? false
  )
  property bool embeddedMirrorPendingSessionRecovery: false
  property var embeddedMirrorRecoveryPreview: null
  property string embeddedMirrorRecoveryReason: ""
  property bool embeddedMirrorUsbRestoreRecoveryPending: false
  property bool embeddedMirrorFallbackSuggestionLatched: false
  property double panelVisibleSinceMs: 0
  property bool panelStatusGraceElapsed: true
  property bool panelOpenUnlockPending: false
  property int panelOpenUnlockRetriesRemaining: 0
  readonly property int panelStatusGraceMs: 5000
  readonly property int embeddedMirrorFallbackSuggestionDelayMs: 8000
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
    running: root.visible
      && root.embeddedMirrorModeEnabled()
      && root.mainDeviceSetupComplete()
      && (root.embeddedMirrorSnapshotFallbackForced()
          || (root.embeddedMirrorFeedModeEnabled()
              && KDEConnect.scrcpyRunning
              && (!root.activePhonePreview
                  || !root.activePhonePreview.mirrorDisplayVisible)))
    onTriggered: {
      root.requestEmbeddedMirrorSnapshotFrame();
    }
  }

  Timer {
    id: embeddedMirrorFeedWatchdog
    interval: 700
    repeat: true
    running: root.visible && root.embeddedMirrorFeedConfigured()
    onTriggered: {
      root.ensureEmbeddedVideoDeviceAccessFresh(root.embeddedVideoDeviceAccessible ? 1800 : 900);
      root.refreshEmbeddedMirrorFallbackSuggestion(root.activePhonePreview);
    }
  }

  Timer {
    id: embeddedMirrorFallbackSuggestionClearTimer
    interval: 1800
    repeat: false
    onTriggered: {
      if (!root.visible || !root.embeddedMirrorFeedModeEnabled()) {
        root.embeddedMirrorFallbackSuggestionLatched = false;
        return;
      }

      if (root.embeddedMirrorFeedStable(root.activePhonePreview)
          && !root.embeddedMirrorShouldSuggestFallback(root.activePhonePreview)) {
        root.embeddedMirrorFallbackSuggestionLatched = false;
        return;
      }

      restart();
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

      if (!root.embeddedMirrorSnapshotFallbackForced()
          && root.embeddedMirrorFallbackActive(root.activePhonePreview)) {
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
    id: panelStatusGraceTimer
    interval: root.panelStatusGraceMs
    repeat: false
    onTriggered: {
      root.panelStatusGraceElapsed = true;
    }
  }

  Timer {
    id: adbDevicesRefreshTimer
    interval: 2500
    repeat: true
    running: root.visible
    onTriggered: {
      KDEConnect.refreshAdbDevices();
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
        if (root.embeddedMirrorSnapshotFallbackForced()) {
          root.embeddedMirrorPendingSessionRecovery = false;
          root.embeddedMirrorRecoveryPreview = null;
          root.embeddedMirrorRecoveryReason = "";
          embeddedMirrorRecoveryTimer.stop();
        }
        root.refreshEmbeddedMirrorFallbackSuggestion(root.activePhonePreview);
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

      root.refreshEmbeddedMirrorFallbackSuggestion(root.activePhonePreview);

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

      if (!KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching)
        root.scheduleEmbeddedMirrorAutoStart();
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
      root.embeddedVideoDeviceCheckKnown = false;
      KDEConnect.v4l2SnapshotVersion = 0;
      KDEConnect.v4l2SnapshotError = "";
      Qt.callLater(function() {
        root.refreshEmbeddedVideoDeviceAccess();
      });
      root.refreshEmbeddedMirrorFallbackSuggestion(root.activePhonePreview);
      Logger.w("KDEConnect", "Feed mode failed for embedded scrcpy:", errorText);
    }

    function onWirelessAdbFinished(success, message) {
      if (success) {
        const usedQrFlow = root.applyWirelessAdbQrSuccess(message);
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
          ? root.trSafe("panel.wireless-adb.missing-command-description", "Wireless ADB could not start the built-in adb tcpip helper.")
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
    KDEConnect.forceStopScrcpyProcesses(root.embeddedVideoDevice);
  }

  onVisibleChanged: {
    root.syncBackgroundRefreshPolicy();
    if (visible) {
      root.panelVisibleSinceMs = Date.now();
      root.panelStatusGraceElapsed = false;
      panelStatusGraceTimer.restart();
      root.embeddedMirrorFallbackSuggestionLatched = false;
      embeddedMirrorFallbackSuggestionClearTimer.stop();
      KDEConnect.refreshAdbDevices();
      if (KDEConnect.daemonAvailable)
        KDEConnect.refreshDevices();
      root.refreshEmbeddedVideoDeviceAccess();
      root.refreshEmbeddedMirrorFallbackSuggestion(root.activePhonePreview);
      root.panelOpenUnlockPending = root.embeddedMirrorModeEnabled();
      root.panelOpenUnlockRetriesRemaining = 12;
      if (KDEConnect.scrcpyRunning)
        panelOpenUnlockTimer.restart();
      root.scheduleEmbeddedMirrorAutoStart();
    }
    if (!visible) {
      root.panelVisibleSinceMs = 0;
      root.panelStatusGraceElapsed = true;
      embeddedMirrorUsbRestoreTimer.stop();
      embeddedMirrorAutoStartTimer.stop();
      embeddedMirrorRecoveryTimer.stop();
      embeddedMirrorFallbackSuggestionClearTimer.stop();
      panelStatusGraceTimer.stop();
      panelOpenUnlockTimer.stop();
      root.embeddedMirrorPendingSessionRecovery = false;
      root.embeddedMirrorRecoveryPreview = null;
      root.embeddedMirrorRecoveryReason = "";
      root.embeddedMirrorUsbRestoreRecoveryPending = false;
      root.embeddedMirrorFallbackSuggestionLatched = false;
      root.panelOpenUnlockPending = false;
      root.panelOpenUnlockRetriesRemaining = 0;
    }
    if (!visible)
      KDEConnect.forceStopScrcpyProcesses(root.embeddedVideoDevice);
  }

  onEmbeddedMirrorForceSnapshotFallbackChanged: {
    root.persistEmbeddedMirrorSnapshotFallbackMode();
    if (root.embeddedMirrorForceSnapshotFallback) {
      embeddedMirrorFallbackSuggestionClearTimer.stop();
      root.embeddedMirrorFallbackSuggestionLatched = false;
    } else {
      root.refreshEmbeddedMirrorFallbackSuggestion(root.activePhonePreview);
    }
  }
  onEmbeddedMirrorAudioEnabledChanged: root.persistEmbeddedMirrorAudioMode()

  function mainDeviceSetupComplete() {
    return KDEConnect.mainDevice !== null
      && Boolean(KDEConnect.mainDevice.paired)
      && Boolean(KDEConnect.mainDevice.reachable);
  }

  function mainDevicePairingInProgress() {
    if (KDEConnect.mainDevice === null || KDEConnect.mainDevice.paired)
      return false;

    return Boolean(KDEConnect.mainDevice.pairRequested)
      || String(KDEConnect.mainDevice.verificationKey || "").trim() !== "";
  }

  function handlePhoneClick(preview) {
    if (KDEConnect.mainDevice === null || !root.mainDeviceSetupComplete())
      return;

    if (!KDEConnect.scrcpyRunning
        && !KDEConnect.scrcpyLaunching
        && !root.scrcpyLaunchPrerequisitesReady()) {
      KDEConnect.refreshAdbDevices();
      return;
    }

    if (!root.embeddedMirrorSnapshotFallbackForced()
        && root.embeddedMirrorFeedSessionDegraded(preview, 1800)) {
      root.requestEmbeddedMirrorSessionRecovery(preview, "manual-retry");
      return;
    }

    ensureEmbeddedMirrorSession(preview);
  }

  function copyTextToClipboard(text, successMessage) {
    const trimmedText = String(text || "").trim();
    if (trimmedText === "")
      return;

    Quickshell.execDetached(["wl-copy", trimmedText]);
    ToastService.showNotice(
      root.trSafe("panel.setup-required.copy-title", "AndroidConnect"),
      successMessage || root.trSafe("panel.setup-required.copy-success", "Copied to clipboard."),
      "copy"
    );
  }

  function triggerMainDevicePairing() {
    if (KDEConnect.mainDevice === null || KDEConnect.mainDevice.paired)
      return;

    KDEConnect.requestPairing(KDEConnect.mainDevice.id);
    KDEConnect.mainDevice.pairRequested = true;
    KDEConnect.refreshDevices();
  }

  function setupRequiredPairingStepText() {
    if (KDEConnect.mainDevice === null) {
      return root.trSafe(
        "panel.setup-required.step-1-discovery",
        "1. Open KDE Connect on the phone and keep it on the same network so the desktop can discover it."
      );
    }

    if (KDEConnect.mainDevice.paired && KDEConnect.mainDevice.reachable) {
      return root.trSafe(
        "panel.setup-required.step-1-ready",
        "1. KDE Connect pairing is ready."
      );
    }

    if (KDEConnect.mainDevice.paired) {
      return root.trSafe(
        "panel.setup-required.step-1-known-paired",
        "1. KDE Connect knows about a paired phone entry, but the phone is not reachable yet."
      );
    }

    return root.trSafe(
      "panel.setup-required.step-1-pair",
      "1. Start KDE Connect pairing here, then approve it on the phone."
    );
  }

  function setupRequiredAdbStepText() {
    if (KDEConnect.mainDevice === null || !KDEConnect.mainDevice.paired) {
      return root.trSafe(
        "panel.setup-required.step-2-after-pair",
        "2. After pairing, enable USB debugging on the phone and authorize this computer once over USB."
      );
    }

    if (!KDEConnect.mainDevice.reachable) {
      return root.trSafe(
        "panel.setup-required.step-2-reachable",
        "2. Keep KDE Connect open on the phone and make sure both devices stay on the same network until the phone becomes reachable."
      );
    }

    const adbIssueSubtitle = root.adbSetupIssueSubtitle();
    if ((adbIssueSubtitle || "").trim() !== "")
      return "2. " + adbIssueSubtitle;

    return root.trSafe(
      "panel.setup-required.step-2-ready",
      "2. USB debugging is ready."
    );
  }

  function setupRequiredLoopbackStepText() {
    if (!root.embeddedVideoDeviceCheckKnown) {
      return root.trSafe(
        "panel.setup-required.step-3-checking",
        "3. Checking the V4L2 loopback device for the embedded live feed."
      );
    }

    if (root.embeddedVideoDeviceAccessible) {
      return root.trSafe(
        "panel.setup-required.step-3-ready",
        "3. V4L2 loopback device detected: "
      ) + root.embeddedVideoDevice;
    }

    return root.trSafe(
      "panel.setup-required.step-3-missing",
      "3. Create the V4L2 loopback device if you want the embedded live feed."
    );
  }

  function setupRequiredLoopbackCommandVisible() {
    return root.embeddedMirrorModeEnabled()
      && root.embeddedMirrorFeedConfigured()
      && root.embeddedVideoDeviceCheckKnown
      && !root.embeddedVideoDeviceAccessible;
  }

  function embeddedMirrorRequiredFeedDeviceStatusText() {
    if (!root.embeddedMirrorFeedConfigured()) {
      return root.trSafe(
        "panel.embedded-mirror.required-device-not-configured",
        "Required V4L2 device is not configured."
      );
    }

    if (!root.embeddedVideoDeviceCheckKnown) {
      return root.trSafe(
        "panel.embedded-mirror.required-device-checking",
        "Checking required V4L2 device: "
      ) + root.embeddedVideoDevice;
    }

    if (root.embeddedVideoDeviceAccessible) {
      return root.trSafe(
        "panel.embedded-mirror.required-device-found",
        "Required V4L2 device found: "
      ) + root.embeddedVideoDevice;
    }

    return root.trSafe(
      "panel.embedded-mirror.required-device-missing",
      "Required V4L2 device not found: "
    ) + root.embeddedVideoDevice;
  }

  function scheduleEmbeddedMirrorAutoStart() {
    if (!root.visible
        || !embeddedMirrorModeEnabled()
        || !root.mainDeviceSetupComplete()
        || !root.scrcpyLaunchPrerequisitesReady()) {
      return;
    }

    embeddedMirrorAutoStartTimer.restart();
  }

  function attemptEmbeddedMirrorAutoStart() {
    if (!root.visible
        || !embeddedMirrorModeEnabled()
        || !root.mainDeviceSetupComplete()
        || !root.activePhonePreview
        || !root.scrcpyLaunchPrerequisitesReady()) {
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

  function persistEmbeddedMirrorAudioMode() {
    if (!pluginApi)
      return;

    pluginApi.pluginSettings.embeddedMirrorAudioEnabled = embeddedMirrorAudioEnabled;
    pluginApi.saveSettings();
  }

  function activateManualSnapshotFallback(preview, reason) {
    if (!embeddedMirrorModeEnabled())
      return;

    const previewItem = preview || root.activePhonePreview || null;
    const alreadyForced = embeddedMirrorForceSnapshotFallback;
    const fallbackReason = String(reason || "").trim();

    embeddedMirrorForceSnapshotFallback = true;
    embeddedMirrorAudioEnabled = false;
    embeddedVideoDeviceCheckKnown = false;
    embeddedVideoDeviceAccessible = false;
    root.embeddedMirrorPendingSessionRecovery = false;
    root.embeddedMirrorRecoveryPreview = null;
    root.embeddedMirrorRecoveryReason = fallbackReason;
    embeddedMirrorRecoveryTimer.stop();
    KDEConnect.scrcpyLaunchError = "";

    if (embeddedMirrorFeedConfigured()) {
      Qt.callLater(function() {
        root.refreshEmbeddedVideoDeviceAccess();
      });
    }

    if (previewItem && previewItem.reloadMediaDevices)
      previewItem.reloadMediaDevices();

    root.refreshEmbeddedMirrorTouchMapping();

    if (KDEConnect.scrcpyRunning)
      KDEConnect.stopScrcpySession();
    else if (!KDEConnect.scrcpyLaunching)
      Qt.callLater(function() {
        root.requestEmbeddedMirrorSnapshotFrame();
      });

    if (!alreadyForced) {
      Logger.w("KDEConnect", "Switching embedded mirror to manual snapshot fallback",
        "reason=" + fallbackReason);
    }
  }

  function phoneStatusTitle() {
    if (KDEConnect.scrcpyLaunching)
      return pluginApi?.tr("panel.scrcpy.starting-title") || "Starting scrcpy";

    if (KDEConnect.scrcpyRunning)
      return pluginApi?.tr("panel.scrcpy.running-title") || "scrcpy Active";

    const adbIssueTitle = adbSetupIssueTitle();
    if (adbIssueTitle !== "")
      return adbIssueTitle;

    if (KDEConnect.scrcpyLaunchError !== "")
      return pluginApi?.tr("panel.scrcpy.error-title") || "scrcpy Error";

    return pluginApi?.tr("panel.scrcpy.ready-title") || "Launch scrcpy";
  }

  function phoneStatusSubtitle() {
    if (KDEConnect.scrcpyLaunching)
      return pluginApi?.tr("panel.scrcpy.starting-description") || "Preparing the control session";

    if (KDEConnect.scrcpyRunning)
      return pluginApi?.tr("panel.scrcpy.running-description") || "Click the phone tile again to stop the session";

    const adbIssueSubtitle = adbSetupIssueSubtitle();
    if (adbIssueSubtitle !== "")
      return adbIssueSubtitle;

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

  function adbDeviceStateEntries() {
    const states = KDEConnect.adbDeviceStates || ({});
    const entries = [];
    for (const serial in states) {
      if (!Object.prototype.hasOwnProperty.call(states, serial))
        continue;

      entries.push({
        serial: String(serial || "").trim(),
        state: String(states[serial] || "").trim()
      });
    }
    return entries;
  }

  function adbSerialsInState(targetState) {
    const desiredState = String(targetState || "").trim();
    if (desiredState === "")
      return [];

    return adbDeviceStateEntries()
      .filter(entry => entry.serial !== "" && entry.state === desiredState)
      .map(entry => entry.serial);
  }

  function connectedWirelessAdbSerial() {
    const configuredSerial = configuredWirelessAdbSerial();
    if (configuredSerial !== "" && KDEConnect.adbDeviceSerialConnected(configuredSerial))
      return configuredSerial;

    return KDEConnect.adbConnectedSerialForHost((wirelessAdbConnectHost || "").trim());
  }

  function adbSetupIssueTitle() {
    if (KDEConnect.scrcpyRunning
        || KDEConnect.scrcpyLaunching
        || !root.mainDeviceSetupComplete())
      return "";

    if (KDEConnect.adbDevicesExitCode !== 0)
      return trSafe("panel.scrcpy.adb-missing-title", "adb Not Available");

    if (adbSerialsInState("unauthorized").length > 0)
      return trSafe("panel.scrcpy.adb-authorize-title", "Authorize USB Debugging");

    if (adbSerialsInState("offline").length > 0)
      return trSafe("panel.scrcpy.adb-offline-title", "Reconnect ADB");

    if (!KDEConnect.adbHasUsbTransport && connectedWirelessAdbSerial() === "")
      return trSafe("panel.scrcpy.adb-setup-title", "Connect ADB First");

    return "";
  }

  function adbSetupIssueSubtitle() {
    const issueTitle = adbSetupIssueTitle();
    if (issueTitle === "")
      return "";

    if (KDEConnect.adbDevicesExitCode !== 0) {
      const stderrText = String(KDEConnect.adbDevicesStderr || "").trim();
      return stderrText !== ""
        ? stderrText
        : trSafe("panel.scrcpy.adb-missing-description", "Install Android platform-tools so the plugin can use adb for mirroring and input.");
    }

    if (adbSerialsInState("unauthorized").length > 0)
      return trSafe("panel.scrcpy.adb-authorize-description", "Enable Developer options and USB debugging on the phone, connect it over USB, unlock it, and accept the USB debugging prompt for this computer.");

    if (adbSerialsInState("offline").length > 0)
      return trSafe("panel.scrcpy.adb-offline-description", "adb can see the phone, but it is not ready yet. Reconnect the cable, unlock the phone, and accept the USB debugging prompt again.");

    if (!KDEConnect.adbHasUsbTransport && connectedWirelessAdbSerial() === "")
      return trSafe("panel.scrcpy.adb-setup-wireless-description", "Enable Developer options and USB debugging on the phone, connect it over USB once and accept the debugging prompt, or pair Wireless ADB from the Wi-Fi button.");

    return "";
  }

  function scrcpyLaunchPrerequisitesReady() {
    if ((adbSetupIssueTitle() || "").trim() !== "")
      return false;

    if (embeddedMirrorModeEnabled()) {
      if (embeddedMirrorSnapshotFallbackForced())
        return true;

      if ((embeddedMirrorCommand || "").trim() === "")
        return false;

      if (embeddedMirrorFeedConfigured()) {
        if (!embeddedVideoDeviceCheckKnown) {
          if (!embeddedVideoDeviceCheckProc.running)
            refreshEmbeddedVideoDeviceAccess();
          return false;
        }

        if (!embeddedVideoDeviceAccessible)
          return false;
      }

      return true;
    }

    return false;
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

  function resolvedAdbSerial() {
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
      && root.reduceBackgroundRefreshWhileMirroring
      && root.embeddedMirrorModeEnabled()
      && KDEConnect.scrcpyRunning;
  }

  function embeddedMirrorModeEnabled() {
    return true;
  }

  function embeddedMirrorFeedConfigured() {
    return embeddedMirrorModeEnabled() && (embeddedVideoDevice || "").trim() !== "";
  }

  function embeddedMirrorFeedModeEnabled() {
    return embeddedMirrorFeedConfigured() && !embeddedMirrorSnapshotFallbackForced();
  }

  function embeddedMirrorSnapshotFallbackForced() {
    return embeddedMirrorModeEnabled() && embeddedMirrorForceSnapshotFallback;
  }

  function refreshEmbeddedVideoDeviceAccess() {
    if (!embeddedMirrorFeedConfigured()) {
      embeddedVideoDeviceAccessible = false;
      embeddedVideoDeviceCheckKnown = true;
      embeddedVideoDeviceLastCheckAtMs = Date.now();
      return;
    }

    if (embeddedVideoDeviceCheckProc.running)
      return;

    if (!embeddedVideoDeviceCheckKnown)
      embeddedVideoDeviceAccessible = false;
    embeddedVideoDeviceCheckProc.running = true;
  }

  function ensureEmbeddedVideoDeviceAccessFresh(maxAgeMs) {
    if (!embeddedMirrorFeedConfigured() || embeddedVideoDeviceCheckProc.running)
      return;

    const maxAge = Math.max(0, Number(maxAgeMs || 0));
    const lastCheckedAt = Number(embeddedVideoDeviceLastCheckAtMs || 0);
    if (maxAge > 0 && lastCheckedAt > 0 && (Date.now() - lastCheckedAt) < maxAge)
      return;

    refreshEmbeddedVideoDeviceAccess();
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

  function embeddedMirrorFeedStable(preview) {
    if (!embeddedMirrorFeedModeEnabled()
        || !KDEConnect.scrcpyRunning
        || KDEConnect.scrcpyLaunching
        || KDEConnect.scrcpySessionMode !== "feed"
        || KDEConnect.scrcpyLaunchError !== "") {
      return false;
    }

    const previewItem = preview || root.activePhonePreview || null;
    return previewItem !== null
      && previewItem.mirrorDisplayVisible
      && previewItem.mirrorFeedError === "";
  }

  function embeddedMirrorShouldSuggestFallback(preview) {
    if (!embeddedMirrorModeEnabled()
        || embeddedMirrorSnapshotFallbackForced()
        || !embeddedMirrorFeedConfigured()) {
      return false;
    }

    if (!visible)
      return false;

    const panelVisibleSince = Number(panelVisibleSinceMs || 0);
    if (panelVisibleSince <= 0)
      return false;

    if ((Date.now() - panelVisibleSince) < embeddedMirrorFallbackSuggestionDelayMs)
      return false;

    if (embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceAccessible)
      return true;

    if (KDEConnect.scrcpyLaunchError !== "")
      return true;

    return embeddedMirrorFeedSessionDegraded(preview, embeddedMirrorFallbackSuggestionDelayMs);
  }

  function refreshEmbeddedMirrorFallbackSuggestion(preview) {
    const shouldSuggest = embeddedMirrorShouldSuggestFallback(preview);
    if (shouldSuggest) {
      embeddedMirrorFallbackSuggestionLatched = true;
      embeddedMirrorFallbackSuggestionClearTimer.stop();
      return;
    }

    if (embeddedMirrorFallbackSuggestionLatched
        && !embeddedMirrorFallbackSuggestionClearTimer.running) {
      embeddedMirrorFallbackSuggestionClearTimer.restart();
    }
  }

  function embeddedMirrorFallbackSuggestionVisible(preview) {
    return embeddedMirrorFallbackSuggestionLatched
      || embeddedMirrorShouldSuggestFallback(preview);
  }

  function requestEmbeddedMirrorSessionRecovery(preview, reason) {
    if (!embeddedMirrorModeEnabled())
      return;

    if (embeddedMirrorSnapshotFallbackForced())
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
    if (!embeddedMirrorModeEnabled() || !embeddedMirrorFeedConfigured())
      return;

    const previewItem = preview || root.activePhonePreview || null;
    const enablingSnapshotFallback = !embeddedMirrorForceSnapshotFallback;
    embeddedMirrorForceSnapshotFallback = enablingSnapshotFallback;

    if (enablingSnapshotFallback) {
      embeddedMirrorAudioEnabled = false;
      embeddedVideoDeviceCheckKnown = false;
      embeddedVideoDeviceAccessible = false;
      root.embeddedMirrorPendingSessionRecovery = false;
      root.embeddedMirrorRecoveryPreview = null;
      root.embeddedMirrorRecoveryReason = "";
      embeddedMirrorRecoveryTimer.stop();
      Qt.callLater(function() {
        root.refreshEmbeddedVideoDeviceAccess();
      });
    }

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

  function toggleEmbeddedMirrorAudioMode(preview) {
    if (!embeddedMirrorModeEnabled())
      return;

    embeddedMirrorAudioEnabled = !embeddedMirrorAudioEnabled;

    if (!KDEConnect.scrcpyRunning || KDEConnect.scrcpyLaunching)
      return;

    const previewItem = preview || root.activePhonePreview || null;
    requestEmbeddedMirrorSessionRecovery(
      previewItem,
      embeddedMirrorAudioEnabled ? "audio-enable" : "audio-disable"
    );
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

    if (embeddedMirrorSnapshotFallbackForced()) {
      refreshEmbeddedMirrorTouchMapping();

      if (KDEConnect.scrcpyRunning)
        KDEConnect.stopScrcpySession();

      if (!KDEConnect.scrcpyLaunching)
        root.requestEmbeddedMirrorSnapshotFrame();

      return;
    }

    if (feedConfigured && !embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceCheckProc.running) {
      refreshEmbeddedVideoDeviceAccess();
    }

    if (!KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching) {
      let tunedEmbeddedCommand = KDEConnect.applyMirrorPerformancePreset(
        embeddedMirrorCommand,
        "quality",
        feedModeEnabled
      );
      tunedEmbeddedCommand = KDEConnect.applyConfiguredMirrorAudioMode(
        tunedEmbeddedCommand,
        embeddedMirrorAudioEnabled
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
    if (!embeddedMirrorModeEnabled()
        || KDEConnect.scrcpyLaunching
        || !root.scrcpyLaunchPrerequisitesReady()) {
      return false;
    }

    const manualSnapshotFallback = embeddedMirrorSnapshotFallbackForced();
    if (!manualSnapshotFallback
        && (!embeddedMirrorFeedModeEnabled() || !KDEConnect.scrcpyRunning)) {
      return false;
    }

    if (!manualSnapshotFallback
        && activePhonePreview
        && activePhonePreview.mirrorFeedRestarting)
      return false;

    const launchStartedAt = Number(KDEConnect.scrcpyLaunchStartedAtMs || 0);
    if (!manualSnapshotFallback
        && launchStartedAt > 0
        && (Date.now() - launchStartedAt) < 2200)
      return false;

    return KDEConnect.captureAdbFrame(currentMirrorAdbSerial(), embeddedMirrorSnapshotPath);
  }

  function embeddedMirrorViewActive(preview) {
    if (!embeddedMirrorModeEnabled())
      return false;

    if (embeddedMirrorSnapshotFallbackForced())
      return KDEConnect.v4l2SnapshotVersion > 0;

    if (embeddedMirrorFeedModeEnabled())
      return KDEConnect.scrcpyRunning
        && (preview?.mirrorDisplayVisible || KDEConnect.v4l2SnapshotVersion > 0);

    return KDEConnect.scrcpyRunning
      && KDEConnect.scrcpyWindowReady;
  }

  function embeddedMirrorTouchActive() {
    return embeddedMirrorModeEnabled()
      && (KDEConnect.scrcpyRunning || embeddedMirrorSnapshotFallbackForced())
      && KDEConnect.adbDisplayInfoSerial === ""
      && KDEConnect.adbScreenError === ""
      && KDEConnect.adbScreenWidth > 0
      && KDEConnect.adbScreenHeight > 0;
  }

  function embeddedMirrorInputActive() {
    return embeddedMirrorModeEnabled()
      && (KDEConnect.scrcpyRunning || embeddedMirrorSnapshotFallbackForced());
  }

  function embeddedMirrorNavRowVisible() {
    return embeddedMirrorModeEnabled();
  }

  function refreshEmbeddedMirrorTouchMapping() {
    if (!embeddedMirrorModeEnabled()
        || (!KDEConnect.scrcpyRunning && !embeddedMirrorSnapshotFallbackForced()))
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

    if (!panelStatusGraceElapsed)
      return false;

    return String(embeddedMirrorDrawerStatusTitle(preview) || "").trim() !== ""
      || String(embeddedMirrorDrawerStatusSubtitle(preview) || "").trim() !== "";
  }

  function embeddedMirrorPhoneOverlayVisible() {
    if (!embeddedMirrorModeEnabled())
      return true;

    if (!panelStatusGraceElapsed)
      return false;

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

    const adbIssueTitle = adbSetupIssueTitle();
    if (adbIssueTitle !== "")
      return adbIssueTitle;

    if (embeddedMirrorSnapshotFallbackForced())
      return trSafe("panel.embedded-mirror.fallback-title", "Fallback Snapshot Active");

    if (embeddedMirrorFeedConfigured() && embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceAccessible)
      return trSafe("panel.embedded-mirror.feed-unavailable-title", "Video Feed Unavailable");

    if (KDEConnect.scrcpyLaunching)
      return trSafe("panel.embedded-mirror.starting-title", "Starting Embedded Mirror");

    if (KDEConnect.scrcpyLaunchError !== "")
      return trSafe("panel.embedded-mirror.error-title", "Mirror Error");

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

    const adbIssueSubtitle = adbSetupIssueSubtitle();
    if (adbIssueSubtitle !== "")
      return adbIssueSubtitle;

    if (embeddedMirrorSnapshotFallbackForced()) {
      return trSafe("panel.embedded-mirror.manual-fallback-description",
        "Manual snapshot fallback is active. Press Feed to return to the live V4L2 feed.")
        + " " + embeddedMirrorRequiredFeedDeviceStatusText();
    }

    if (embeddedMirrorFeedConfigured() && embeddedVideoDeviceCheckKnown && !embeddedVideoDeviceAccessible)
      return trSafe("panel.embedded-mirror.feed-unavailable-description",
        "The V4L2 device cannot be opened. Make sure "
        + embeddedVideoDevice + " exists, is writable, and is backed by the scrcpy loopback device.");

    if (KDEConnect.scrcpyLaunching)
      return trSafe("panel.embedded-mirror.starting-description", "Launching scrcpy and preparing the panel overlay.");

    if (KDEConnect.scrcpyLaunchError !== "")
      return KDEConnect.scrcpyLaunchError;

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
      root.embeddedVideoDeviceLastCheckAtMs = Date.now();

      if (exitCode !== 0) {
        Logger.w("KDEConnect", "Embedded V4L2 device check failed:", root.embeddedVideoDevice);
      }
      if (!KDEConnect.scrcpyRunning && !KDEConnect.scrcpyLaunching)
        root.scheduleEmbeddedMirrorAutoStart();
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
        const normalizedType = String(type || "").trim().toUpperCase();
        if (normalizedType === "")
          return "wave-square";

        if (normalizedType.indexOf("5G") !== -1 || normalizedType.indexOf("NR") !== -1)
          return "signal-5g";

        if (normalizedType.indexOf("LTE") !== -1)
          return "signal-lte";

        if (normalizedType.indexOf("4G") !== -1)
          return "signal-4g";

        if (normalizedType.indexOf("HSPA") !== -1 || normalizedType.indexOf("H+") !== -1 || normalizedType === "H")
          return "signal-h";

        if (normalizedType.indexOf("UMTS") !== -1
            || normalizedType.indexOf("WCDMA") !== -1
            || normalizedType.indexOf("EVDO") !== -1
            || normalizedType.indexOf("CDMA2000") !== -1
            || normalizedType === "CDMA"
            || normalizedType.indexOf("3G") !== -1) {
          return "signal-3g";
        }

        if (normalizedType.indexOf("EDGE") !== -1 || normalizedType === "E")
          return "signal-e";

        if (normalizedType.indexOf("GPRS") !== -1 || normalizedType === "G")
          return "signal-g";

        if (normalizedType.indexOf("GSM") !== -1
            || normalizedType.indexOf("IDEN") !== -1
            || normalizedType.indexOf("2G") !== -1) {
          return "signal-2g";
        }

        return "wave-square";
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
        Layout.fillHeight: !root.mainDeviceSetupComplete()
        Layout.alignment: Qt.AlignTop
        active: true
        sourceComponent:  (KDEConnect.busctlCmd === null || KDEConnect.busctlCmd === "")       ? busctlNotFoundCard               :
                          (!KDEConnect.daemonAvailable)                                        ? kdeConnectDaemonNotRunningCard   :
                          (deviceSwitcherOpen)                                                 ? deviceSwitcherCard               :
                          (root.mainDeviceSetupComplete())                                     ? deviceConnectedCard              :
                          (root.mainDevicePairingInProgress())                                 ? noDevicePairedCard               :
                          (KDEConnect.mainDevice !== null || KDEConnect.devices.length > 0)    ? setupRequiredCard                :
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
                            visible: root.embeddedMirrorModeEnabled()
                            readonly property bool fallbackModeActive: root.embeddedMirrorForceSnapshotFallback
                            icon: root.embeddedMirrorAudioEnabled ? "volume" : "volume-off"
                            tooltipText: fallbackModeActive
                              ? root.trSafe("panel.embedded-mirror.audio-disabled-in-fallback", "Embedded audio is only available in Feed mode.")
                              : root.embeddedMirrorAudioEnabled
                              ? root.trSafe("panel.embedded-mirror.audio-disable", "Disable embedded audio")
                              : root.trSafe("panel.embedded-mirror.audio-enable", "Enable embedded audio")
                            baseSize: Style.baseWidgetSize * 0.8
                            colorBg: fallbackModeActive ? "#1d1a19" : "#211814"
                            colorFg: fallbackModeActive ? "#7f746f" : "#f4ae89"
                            colorBgHover: fallbackModeActive ? "#1d1a19" : "#3a261f"
                            colorFgHover: fallbackModeActive ? "#7f746f" : "#fff4ed"
                            colorBorder: fallbackModeActive ? "#4f4743" : "#6c4c3e"
                            colorBorderHover: fallbackModeActive ? "#4f4743" : "#f4ae89"
                            enabled: !fallbackModeActive && !root.embeddedMirrorPendingSessionRecovery
                            opacity: fallbackModeActive ? 0.72 : 1.0
                            onClicked: root.toggleEmbeddedMirrorAudioMode()
                          }

                          NIconButton {
                            icon: "wifi"
                            tooltipText: KDEConnect.wirelessAdbBusy
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
                          backgroundImage: (root.embeddedMirrorFeedModeEnabled()
                              || root.embeddedMirrorSnapshotFallbackForced())
                            ? root.embeddedMirrorSnapshotUrl()
                            : ""
                          mirrorFeedEnabled: root.embeddedMirrorFeedModeEnabled()
                            && KDEConnect.scrcpyRunning
                            && !root.embeddedMirrorForceSnapshotFallback
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
                                && ((!root.embeddedMirrorSnapshotFallbackForced()
                                     && root.embeddedMirrorFeedModeEnabled()
                                     && !phonePreview.mirrorFeedAvailable)
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
                        visible: root.embeddedMirrorNavRowVisible()

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

                      }

                      Rectangle {
                        id: embeddedMirrorFallbackHintCard
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        visible: root.embeddedMirrorFallbackSuggestionVisible(phonePreview)
                        implicitHeight: fallbackHintContent.implicitHeight + (Style.marginM * 1.8)
                        radius: 18 * Style.uiScaleRatio
                        color: "#2b1d18"
                        border.width: Style.borderS
                        border.color: "#9a6248"
                        clip: true

                        ColumnLayout {
                          id: fallbackHintContent
                          anchors.fill: parent
                          anchors.margins: Style.marginM
                          spacing: Style.marginXS

                          NText {
                            Layout.fillWidth: true
                            text: root.trSafe("panel.embedded-mirror.try-fallback-title", "Try Fallback")
                            pointSize: Style.fontSizeS * (root.phoneSizePresetIndex === 0 ? 1.02 : 1.08)
                            font.weight: Style.fontWeightBold
                            color: "#fff0e7"
                            wrapMode: Text.WordWrap
                          }

                          NText {
                            Layout.fillWidth: true
                            text: root.trSafe(
                              "panel.embedded-mirror.try-fallback-description",
                              "If the live feed keeps failing, use the top-left Fallback toggle to stay on ADB snapshots."
                            )
                            pointSize: Style.fontSizeXS * (root.phoneSizePresetIndex === 0 ? 1.0 : 1.04)
                            color: "#f2c3a4"
                            wrapMode: Text.WordWrap
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

                          Rectangle {
                            Layout.fillWidth: true
                            visible: root.setupRequiredLoopbackCommandVisible()
                            color: "#2b211d"
                            radius: 14 * Style.uiScaleRatio
                            border.width: Style.borderS
                            border.color: "#7d5b4e"
                            implicitHeight: drawerLoopbackCommandColumn.implicitHeight + (Style.marginM * 1.2)

                            ColumnLayout {
                              id: drawerLoopbackCommandColumn
                              anchors.fill: parent
                              anchors.margins: Style.marginM * 0.9
                              spacing: Style.marginXS

                              RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginS

                                NIcon {
                                  icon: "copy"
                                  pointSize: Style.fontSizeM
                                  color: "#f4d0be"
                                }

                                NText {
                                  Layout.fillWidth: true
                                  text: root.trSafe("panel.setup-required.command-label", "Click to copy the loopback setup command")
                                  pointSize: Style.fontSizeS
                                  color: "#f0d8ca"
                                  wrapMode: Text.WordWrap
                                }
                              }

                              NText {
                                Layout.fillWidth: true
                                text: root.embeddedMirrorLoopbackSetupCommand
                                pointSize: Style.fontSizeXS
                                color: "#fff4ed"
                                wrapMode: Text.WrapAnywhere
                                font.family: "monospace"
                              }
                            }

                            MouseArea {
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                root.copyTextToClipboard(
                                  root.embeddedMirrorLoopbackSetupCommand,
                                  root.trSafe("panel.setup-required.command-copied", "Loopback setup command copied.")
                                );
                              }
                            }
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
        id: setupRequiredCard

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: implicitHeight
          color: "#1c1517"
          radius: 24 * Style.uiScaleRatio
          implicitHeight: setupRequiredContent.implicitHeight + (Style.marginL * 2.4)

          ColumnLayout {
            id: setupRequiredContent
            anchors {
              fill: parent
              margins: Style.marginL * 1.2
            }
            spacing: Style.marginL * 1.1

            NText {
              text: root.trSafe("panel.setup-required.phone-name", "Android Phone")
              pointSize: Style.fontSizeXXL
              font.weight: Style.fontWeightBold
              color: "#fff4ed"
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: setupRequiredColumn.implicitHeight + (Style.marginL * 1.8)
              color: "#241b1d"
              radius: 20 * Style.uiScaleRatio
              border.width: Style.borderS
              border.color: "#6c4c3e"

              ColumnLayout {
                id: setupRequiredColumn
                anchors.fill: parent
                anchors.margins: Style.marginL * 1.1
                spacing: Style.marginM

                Item {
                  Layout.fillWidth: true
                  implicitHeight: setupRequiredHeader.implicitHeight

                  RowLayout {
                    id: setupRequiredHeader
                    anchors.centerIn: parent
                    spacing: Style.marginM

                    Rectangle {
                      width: 48 * Style.uiScaleRatio
                      height: width
                      radius: width / 2
                      color: "#2f231c"
                      border.width: Style.borderS
                      border.color: "#6c4c3e"

                      NIcon {
                        anchors.centerIn: parent
                        icon: "device-mobile-off"
                        pointSize: Style.fontSizeXL
                        color: "#f4ae89"
                      }
                    }

                    ColumnLayout {
                      spacing: 2 * Style.uiScaleRatio

                      NText {
                        text: root.trSafe("panel.setup-required.title", "Finish Setup to Connect")
                        pointSize: Style.fontSizeL * 1.06
                        font.weight: Style.fontWeightBold
                        color: "#fff4ed"
                      }

                      NText {
                        text: root.trSafe("panel.setup-required.subtitle", "Link the phone first, then the mirror controls and status will appear here.")
                        pointSize: Style.fontSizeS * 1.02
                        color: "#cdb7ab"
                        wrapMode: Text.WordWrap
                      }
                    }
                  }
                }

                NText {
                  Layout.fillWidth: true
                  text: root.setupRequiredPairingStepText()
                  color: "#d9c8bb"
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                NText {
                  Layout.fillWidth: true
                  text: root.setupRequiredAdbStepText()
                  color: "#d9c8bb"
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                NText {
                  Layout.fillWidth: true
                  text: root.setupRequiredLoopbackStepText()
                  color: "#d9c8bb"
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                NButton {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.minimumWidth: 240 * Style.uiScaleRatio
                  visible: KDEConnect.mainDevice !== null && !KDEConnect.mainDevice.paired
                  enabled: !root.mainDevicePairingInProgress()
                  text: root.trSafe("panel.setup-required.pair-button", "Start KDE Connect Pairing")
                  icon: "key"
                  onClicked: root.triggerMainDevicePairing()
                }

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  visible: root.mainDevicePairingInProgress() && String(KDEConnect.mainDevice?.verificationKey || "").trim() !== ""
                  color: "#2e2220"
                  radius: 14 * Style.uiScaleRatio
                  border.width: Style.borderS
                  border.color: "#7d5b4e"
                  implicitWidth: setupVerificationRow.implicitWidth + (Style.marginM * 1.4)
                  implicitHeight: setupVerificationRow.implicitHeight + (Style.marginS * 1.4)

                  RowLayout {
                    id: setupVerificationRow
                    anchors.centerIn: parent
                    spacing: Style.marginS

                    NIcon {
                      icon: "key"
                      pointSize: Style.fontSizeL
                      color: "#f4d0be"
                    }

                    NText {
                      text: KDEConnect.mainDevice?.verificationKey || ""
                      pointSize: Style.fontSizeL
                      font.weight: Style.fontWeightBold
                      color: "#fff4ed"
                    }
                  }
                }

                NBusyIndicator {
                  Layout.alignment: Qt.AlignHCenter
                  visible: root.mainDevicePairingInProgress()
                  size: Style.baseWidgetSize * 0.5
                  running: root.mainDevicePairingInProgress()
                }

                NText {
                  Layout.fillWidth: true
                  visible: root.mainDevicePairingInProgress()
                  text: root.trSafe("panel.setup-required.pair-waiting", "Approve the KDE Connect pairing request on the phone to continue.")
                  color: "#d9c8bb"
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                }

                Rectangle {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.fillWidth: true
                  visible: root.setupRequiredLoopbackCommandVisible()
                  color: "#2b211d"
                  radius: 14 * Style.uiScaleRatio
                  border.width: Style.borderS
                  border.color: "#7d5b4e"
                  implicitHeight: loopbackCommandColumn.implicitHeight + (Style.marginM * 1.2)

                  ColumnLayout {
                    id: loopbackCommandColumn
                    anchors.fill: parent
                    anchors.margins: Style.marginM * 0.9
                    spacing: Style.marginXS

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginS

                      NIcon {
                        icon: "copy"
                        pointSize: Style.fontSizeM
                        color: "#f4d0be"
                      }

                      NText {
                        Layout.fillWidth: true
                        text: root.trSafe("panel.setup-required.command-label", "Click to copy the loopback setup command")
                        pointSize: Style.fontSizeS
                        color: "#f0d8ca"
                        wrapMode: Text.WordWrap
                      }
                    }

                    NText {
                      Layout.fillWidth: true
                      text: root.embeddedMirrorLoopbackSetupCommand
                      pointSize: Style.fontSizeXS
                      color: "#fff4ed"
                      wrapMode: Text.WrapAnywhere
                      font.family: "monospace"
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.copyTextToClipboard(
                        root.embeddedMirrorLoopbackSetupCommand,
                        root.trSafe("panel.setup-required.command-copied", "Loopback setup command copied.")
                      );
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

        Rectangle {
          Layout.fillWidth: true
          color: Color.mSurfaceVariant
          radius: Style.radiusM
          border.color: Color.mOutline
          border.width: Style.borderS
          implicitHeight: qrStep.implicitHeight + (Style.marginM * 2)

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
                  enabled: !wirelessAdbQrEncodeProc.running && !KDEConnect.wirelessAdbBusy
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
                label: root.trSafe("panel.wireless-adb.pair-port-label", "Pair port")
                placeholderText: "37099"
                text: root.wirelessAdbPairPort
                onTextChanged: root.wirelessAdbPairPort = text
                onEditingFinished: root.persistWirelessAdbSettings()
              }

              NTextInput {
                Layout.fillWidth: true
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
                enabled: !KDEConnect.wirelessAdbBusy
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
                enabled: !KDEConnect.wirelessAdbBusy
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
