import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtMultimedia

Rectangle {
  id: phoneRoot

  property bool showStatusOverlay: false
  property string statusTitle: ""
  property string statusSubtitle: ""
  property bool busy: false
  property bool mirrorFeedEnabled: false
  property bool interactiveScreen: false
  property string mirrorDeviceIdMatch: ""
  property string mirrorDeviceDescriptionMatch: ""
  property int mirrorContentWidth: 0
  property int mirrorContentHeight: 0
  property int mirrorSourceWidth: 0
  property int mirrorSourceHeight: 0
  property string mirrorFeedError: ""
  property bool mirrorFeedRestarting: false
  property bool mediaDevicesReloadPending: false
  property bool mirrorFeedAttachDelayActive: false
  property double mirrorFeedLastFrameAtMs: 0
  property bool mirrorFeedFrameLive: false
  property int mirrorFeedInvalidFrameCount: 0
  property bool mirrorFeedRecoveryRecommended: false

  readonly property real deviceArtWidth: 597
  readonly property real deviceArtHeight: 1241
  readonly property rect deviceArtCropRect: Qt.rect(586, 27, 597, 1241)
  readonly property real screenInsetLeftRatio: 25 / deviceArtWidth
  readonly property real screenInsetRightRatio: 34 / deviceArtWidth
  readonly property real screenInsetTopRatio: 26 / deviceArtHeight
  readonly property real screenInsetBottomRatio: 25 / deviceArtHeight

  signal clicked
  signal tapRequested(real x, real y)
  signal swipeRequested(real x1, real y1, real x2, real y2, int durationMs)
  signal scrollRequested(real x, real y, real deltaX, real deltaY)
  signal textRequested(string text)
  signal keyRequested(int keyCode)
  signal homeRequested

  height: parent ? parent.height : 235
  width: parent ? parent.width : (height / deviceArtHeight) * deviceArtWidth

  readonly property real scaleFactor: Math.min(width / deviceArtWidth, height / deviceArtHeight)
  readonly property real contentAspectRatio: {
    if (mirrorSourceWidth > 0 && mirrorSourceHeight > 0)
      return mirrorSourceWidth / mirrorSourceHeight;
    if (mirrorContentWidth > 0 && mirrorContentHeight > 0)
      return mirrorContentWidth / mirrorContentHeight;
    return screen.width / Math.max(1, screen.height);
  }
  readonly property real videoFrameWidth: Math.min(screen.width, screen.height * contentAspectRatio)
  readonly property real videoFrameHeight: Math.min(screen.height, screen.width / Math.max(0.001, contentAspectRatio))
  readonly property real videoFrameLocalX: phoneRect.x + screen.x + videoFrame.x
  readonly property real videoFrameLocalY: phoneRect.y + screen.y + videoFrame.y
  readonly property real videoFrameGlobalX: phoneRoot.mapToGlobal(videoFrameLocalX, videoFrameLocalY).x
  readonly property real videoFrameGlobalY: phoneRoot.mapToGlobal(videoFrameLocalX, videoFrameLocalY).y
  readonly property real videoFrameGlobalWidth: videoFrame.width
  readonly property real videoFrameGlobalHeight: videoFrame.height
  readonly property real screenRadius: 44.3 * phoneRoot.scaleFactor
  readonly property real videoFrameRadius: 52 * phoneRoot.scaleFactor
  readonly property string normalizedIdMatch: (mirrorDeviceIdMatch || "").trim().toLowerCase()
  readonly property string normalizedDescriptionMatch: (mirrorDeviceDescriptionMatch || "").trim().toLowerCase()
  readonly property var mediaDevicesRef: mediaDevicesLoader.item
  readonly property var mediaVideoInputs: (mediaDevicesRef && mediaDevicesRef.videoInputs) ? mediaDevicesRef.videoInputs : []
  readonly property string availableVideoInputsSummary: {
    const inputs = mediaVideoInputs || [];
    if (inputs.length === 0)
      return "";

    return inputs.map(device => {
      const description = String(device.description || "").trim();
      const id = String(device.id || "").trim();
      if (description !== "" && id !== "")
        return description + " [" + id + "]";
      return description !== "" ? description : id;
    }).join(", ");
  }
  readonly property var selectedVideoInput: {
    const inputs = mediaVideoInputs || [];
    const exactDescriptionMatch = normalizedDescriptionMatch;
    const exactIdMatch = normalizedIdMatch;

    for (let i = 0; i < inputs.length; ++i) {
      const device = inputs[i];
      const deviceId = String(device.id || "").toLowerCase();
      const deviceDescription = String(device.description || "").toLowerCase();

      if (exactDescriptionMatch !== "" && deviceDescription === exactDescriptionMatch)
        return device;

      if (exactIdMatch !== "" && deviceId === exactIdMatch)
        return device;
    }

    for (let i = 0; i < inputs.length; ++i) {
      const device = inputs[i];
      const deviceId = String(device.id || "").toLowerCase();
      const deviceDescription = String(device.description || "").toLowerCase();

      if (exactDescriptionMatch !== "" && deviceDescription.indexOf(exactDescriptionMatch) !== -1)
        return device;

      if (exactIdMatch !== "" && deviceId.indexOf(exactIdMatch) !== -1)
        return device;
    }

    if (exactDescriptionMatch !== "") {
      for (let i = 0; i < inputs.length; ++i) {
        const device = inputs[i];
        const deviceDescription = String(device.description || "").toLowerCase();
        const deviceId = String(device.id || "").toLowerCase();
        if (deviceDescription.indexOf("scrcpy") !== -1
            || deviceId.indexOf("scrcpy") !== -1
            || deviceDescription.indexOf("loopback") !== -1)
          return device;
      }
    }

    if (exactIdMatch === "" && exactDescriptionMatch === "") {
      if (inputs.length === 1)
        return inputs[0];

      if (mediaDevicesRef && mediaDevicesRef.defaultVideoInput && !mediaDevicesRef.defaultVideoInput.isNull)
        return mediaDevicesRef.defaultVideoInput;
    }

    return undefined;
  }
  readonly property bool mirrorFeedAvailable: selectedVideoInput !== undefined
    && selectedVideoInput !== null
    && !selectedVideoInput.isNull
  readonly property var preferredCameraFormat: {
    const device = selectedVideoInput;
    const formats = device && device.videoFormats ? device.videoFormats : [];
    let preferredFormat = undefined;

    for (let i = 0; i < formats.length; ++i) {
      const candidate = formats[i];
      if (candidate === undefined || candidate === null)
        continue;

      if (phoneRoot.isBetterCameraFormat(candidate, preferredFormat))
        preferredFormat = candidate;
    }

    return preferredFormat !== undefined ? preferredFormat : (formats.length > 0 ? formats[0] : undefined);
  }
  readonly property bool shouldActivateMirrorCamera: mirrorFeedEnabled
    && mirrorFeedAvailable
    && !mirrorFeedRestarting
    && !mirrorFeedAttachDelayActive
  readonly property bool mirrorDisplayVisible: shouldActivateMirrorCamera
    && mirrorFeedError === ""
    && mirrorFeedFrameLive
    && mirrorFeedHasValidSourceSize()
  radius: 0
  color: "transparent"
  border.width: 0
  border.color: "transparent"
  clip: false

  function formatResolutionWidth(format) {
    const resolution = format && format.resolution ? format.resolution : null;
    return resolution ? Number(resolution.width || 0) : 0;
  }

  function formatResolutionHeight(format) {
    const resolution = format && format.resolution ? format.resolution : null;
    return resolution ? Number(resolution.height || 0) : 0;
  }

  function formatArea(format) {
    return formatResolutionWidth(format) * formatResolutionHeight(format);
  }

  function hasMirrorContentSize() {
    return mirrorContentWidth > 0 && mirrorContentHeight > 0;
  }

  function mirrorFeedHasKnownSourceSize() {
    return mirrorSourceWidth > 0 && mirrorSourceHeight > 0;
  }

  function mirrorFeedHasValidSourceSize() {
    return mirrorFeedHasUsableFrameSize(mirrorSourceWidth, mirrorSourceHeight);
  }

  function mirrorFeedHasUsableFrameSize(width, height) {
    const normalizedWidth = Math.max(0, Math.round(Number(width || 0)));
    const normalizedHeight = Math.max(0, Math.round(Number(height || 0)));
    return normalizedWidth >= 16
      && normalizedHeight >= 16
      && (normalizedWidth * normalizedHeight) >= 4096;
  }

  function resetMirrorFeedFrameTracking() {
    mirrorSourceWidth = 0;
    mirrorSourceHeight = 0;
    mirrorFeedLastFrameAtMs = 0;
    mirrorFeedFrameLive = false;
    mirrorFeedInvalidFrameCount = 0;
    mirrorFeedRecoveryRecommended = false;
  }

  function mirrorFrameSizeString(width, height) {
    const normalizedWidth = Math.max(0, Math.round(Number(width || 0)));
    const normalizedHeight = Math.max(0, Math.round(Number(height || 0)));
    return normalizedWidth + "x" + normalizedHeight;
  }

  function readVideoFrameMetric(source, functionName, propertyName) {
    if (!source)
      return 0;

    try {
      if (functionName && typeof source[functionName] === "function")
        return Math.max(0, Math.round(Number(source[functionName]())));
    } catch (error) {
    }

    try {
      if (propertyName && source[propertyName] !== undefined)
        return Math.max(0, Math.round(Number(source[propertyName])));
    } catch (error) {
    }

    return 0;
  }

  function extractMirrorFrameSize(frame) {
    const directWidth = readVideoFrameMetric(frame, "width", "width");
    const directHeight = readVideoFrameMetric(frame, "height", "height");
    if (directWidth > 0 && directHeight > 0)
      return { width: directWidth, height: directHeight };

    const surfaceFormat = frame
      ? (typeof frame.surfaceFormat === "function" ? frame.surfaceFormat() : frame.surfaceFormat)
      : null;
    const formatWidth = readVideoFrameMetric(surfaceFormat, "frameWidth", "frameWidth");
    const formatHeight = readVideoFrameMetric(surfaceFormat, "frameHeight", "frameHeight");
    if (formatWidth > 0 && formatHeight > 0)
      return { width: formatWidth, height: formatHeight };

    const frameSize = surfaceFormat
      ? (typeof surfaceFormat.frameSize === "function" ? surfaceFormat.frameSize() : surfaceFormat.frameSize)
      : null;
    const frameSizeWidth = readVideoFrameMetric(frameSize, "width", "width");
    const frameSizeHeight = readVideoFrameMetric(frameSize, "height", "height");
    if (frameSizeWidth > 0 && frameSizeHeight > 0)
      return { width: frameSizeWidth, height: frameSizeHeight };

    return { width: 0, height: 0 };
  }

  function updateMirrorSourceSize(width, height) {
    const normalizedWidth = Math.max(0, Math.round(Number(width || 0)));
    const normalizedHeight = Math.max(0, Math.round(Number(height || 0)));
    if (normalizedWidth <= 0 || normalizedHeight <= 0)
      return false;

    const changed = mirrorSourceWidth !== normalizedWidth || mirrorSourceHeight !== normalizedHeight;
    mirrorSourceWidth = normalizedWidth;
    mirrorSourceHeight = normalizedHeight;
    return changed;
  }

  function syncMirrorSourceSizeFromVideoOutput() {
    if (!mirrorVideoOutput)
      return false;

    const sourceRect = mirrorVideoOutput.sourceRect;
    if (!sourceRect)
      return false;

    return updateMirrorSourceSize(sourceRect.width, sourceRect.height);
  }

  function invalidateMirrorFeedForSourceSize(width, height) {
    const normalizedWidth = Math.max(0, Math.round(Number(width || 0)));
    const normalizedHeight = Math.max(0, Math.round(Number(height || 0)));
    if (normalizedWidth <= 0 || normalizedHeight <= 0)
      return;

    mirrorFeedLastFrameAtMs = 0;
    mirrorFeedFrameLive = false;
    mirrorFeedInvalidFrameCount += 1;
    mirrorFeedError = "invalid video frame size " + mirrorFrameSizeString(normalizedWidth, normalizedHeight);
    if (mirrorFeedInvalidFrameCount >= 3)
      mirrorFeedRecoveryRecommended = true;
  }

  function evaluateMirrorSourceState() {
    if (!mirrorFeedHasKnownSourceSize())
      return;

    if (mirrorFeedHasValidSourceSize()) {
      mirrorFeedInvalidFrameCount = 0;
      mirrorFeedRecoveryRecommended = false;
      if (mirrorFeedError.indexOf("invalid video frame size ") === 0)
        mirrorFeedError = "";
      return;
    }

    invalidateMirrorFeedForSourceSize(mirrorSourceWidth, mirrorSourceHeight);
  }

  function formatAspectError(format) {
    const width = formatResolutionWidth(format);
    const height = formatResolutionHeight(format);
    if (width <= 0 || height <= 0)
      return Number.MAX_VALUE;

    if (!hasMirrorContentSize())
      return 0;

    const expectedAspect = Number(mirrorContentWidth) / Math.max(1, Number(mirrorContentHeight));
    const directError = Math.abs((width / height) - expectedAspect);
    const rotatedError = Math.abs((height / width) - expectedAspect);
    return Math.min(directError, rotatedError);
  }

  function formatMatchesPreferredOrientation(format) {
    const width = formatResolutionWidth(format);
    const height = formatResolutionHeight(format);
    if (width <= 0 || height <= 0)
      return false;

    if (!hasMirrorContentSize())
      return height >= width;

    return (width >= height) === (mirrorContentWidth >= mirrorContentHeight);
  }

  function formatIsLegacyPreferred(format) {
    const width = formatResolutionWidth(format);
    const height = formatResolutionHeight(format);
    return (width === 576 && height === 1280) || (width === 1280 && height === 576);
  }

  function isBetterCameraFormat(candidate, currentBest) {
    if (!candidate)
      return false;

    if (!currentBest)
      return true;

    const candidateAspectError = formatAspectError(candidate);
    const bestAspectError = formatAspectError(currentBest);
    if (Math.abs(candidateAspectError - bestAspectError) > 0.0001)
      return candidateAspectError < bestAspectError;

    const candidateOrientationMatch = formatMatchesPreferredOrientation(candidate);
    const bestOrientationMatch = formatMatchesPreferredOrientation(currentBest);
    if (candidateOrientationMatch !== bestOrientationMatch)
      return candidateOrientationMatch;

    const candidateLegacyPreferred = formatIsLegacyPreferred(candidate);
    const bestLegacyPreferred = formatIsLegacyPreferred(currentBest);
    if (candidateLegacyPreferred !== bestLegacyPreferred)
      return candidateLegacyPreferred;

    return formatArea(candidate) > formatArea(currentBest);
  }

  function requestMirrorFeedReattach() {
    if (!mirrorFeedEnabled)
      return;

    mirrorFeedError = "";
    resetMirrorFeedFrameTracking();
    mirrorFeedAttachDelayActive = true;
    mirrorFeedAttachDelayTimer.restart();
  }

  function noteMirrorFrameDelivered(frame) {
    syncMirrorSourceSizeFromVideoOutput();
    if (!mirrorFeedHasKnownSourceSize()) {
      const extractedFrameSize = extractMirrorFrameSize(frame);
      updateMirrorSourceSize(extractedFrameSize.width, extractedFrameSize.height);
    }

    if (mirrorFeedHasKnownSourceSize() && !mirrorFeedHasValidSourceSize()) {
      invalidateMirrorFeedForSourceSize(mirrorSourceWidth, mirrorSourceHeight);
      return;
    }

    mirrorFeedLastFrameAtMs = Date.now();
    mirrorFeedFrameLive = true;
    mirrorFeedInvalidFrameCount = 0;
    mirrorFeedRecoveryRecommended = false;
    if (mirrorFeedError.indexOf("invalid video frame size ") === 0)
      mirrorFeedError = "";
  }

  function reloadMediaDevices() {
    if (mediaDevicesReloadPending)
      return;

    mediaDevicesReloadPending = true;
    mirrorFeedRestarting = true;
    mediaDevicesLoader.active = false;
    mediaDevicesReloadCommitTimer.restart();
  }

  Loader {
    id: mediaDevicesLoader
    active: true
    sourceComponent: mediaDevicesComponent
  }

  Component {
    id: mediaDevicesComponent

    MediaDevices {}
  }

  Timer {
    id: mediaDevicesReloadCommitTimer
    interval: 80
    repeat: false
    onTriggered: {
      mediaDevicesLoader.active = true;
      phoneRoot.mediaDevicesReloadPending = false;
      phoneRoot.mirrorFeedRestarting = false;
      phoneRoot.mirrorFeedError = "";
    }
  }

  Timer {
    id: mirrorFeedAttachDelayTimer
    interval: 1800
    repeat: false
    onTriggered: {
      phoneRoot.mirrorFeedAttachDelayActive = false;
    }
  }

  Timer {
    id: mirrorFeedFrameWatchdog
    interval: 450
    repeat: true
    running: phoneRoot.mirrorFeedEnabled
    onTriggered: {
      if (!phoneRoot.shouldActivateMirrorCamera) {
        phoneRoot.mirrorFeedFrameLive = false;
        return;
      }

      const lastFrameAt = Number(phoneRoot.mirrorFeedLastFrameAtMs || 0);
      phoneRoot.mirrorFeedFrameLive = lastFrameAt > 0 && (Date.now() - lastFrameAt) <= 1200;
    }
  }

  CaptureSession {
    id: mirrorCaptureSession
    camera: phoneRoot.shouldActivateMirrorCamera ? mirrorCamera : null
    videoOutput: phoneRoot.shouldActivateMirrorCamera ? mirrorVideoOutput : null
  }

  Camera {
    id: mirrorCamera
    active: phoneRoot.shouldActivateMirrorCamera
    cameraDevice: phoneRoot.selectedVideoInput
    cameraFormat: phoneRoot.preferredCameraFormat

    onActiveChanged: {
      if (active) {
        phoneRoot.mirrorFeedError = "";
        phoneRoot.resetMirrorFeedFrameTracking();
      } else {
        phoneRoot.resetMirrorFeedFrameTracking();
        phoneRoot.mirrorFeedFrameLive = false;
      }
    }

    onCameraDeviceChanged: {
      phoneRoot.mirrorFeedError = "";
      phoneRoot.resetMirrorFeedFrameTracking();
    }

    onErrorOccurred: (error, errorString) => {
      phoneRoot.resetMirrorFeedFrameTracking();
      phoneRoot.mirrorFeedFrameLive = false;
      phoneRoot.mirrorFeedError = errorString !== "" ? errorString : ("camera error " + error);
    }
  }

  onMirrorFeedEnabledChanged: {
    mirrorFeedError = "";
    mirrorFeedRestarting = false;
    mediaDevicesReloadPending = false;
    resetMirrorFeedFrameTracking();
    mirrorFeedAttachDelayActive = mirrorFeedEnabled;
    if (mirrorFeedEnabled)
      mirrorFeedAttachDelayTimer.restart();
    else
      mirrorFeedAttachDelayTimer.stop();
  }

  onMirrorFeedAvailableChanged: {
    if (mirrorFeedAvailable) {
      mirrorFeedError = "";
      resetMirrorFeedFrameTracking();
    } else {
      mirrorFeedRestarting = false;
      resetMirrorFeedFrameTracking();
    }
  }

  onPreferredCameraFormatChanged: {
    if (mirrorFeedAvailable)
      requestMirrorFeedReattach();
  }

  onMirrorContentWidthChanged: {
    if (mirrorContentWidth > 0 && mirrorContentHeight > 0)
      requestMirrorFeedReattach();
  }

  onMirrorContentHeightChanged: {
    if (mirrorContentWidth > 0 && mirrorContentHeight > 0)
      requestMirrorFeedReattach();
  }

  RectangularShadow {
    anchors.fill: phoneFrameImage
    radius: 34 * phoneRoot.scaleFactor
    blur: 24
    spread: 0.08
    color: "#42000000"
  }

  Item {
    id: phoneRect

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: !phoneRoot.interactiveScreen

      onClicked: phoneRoot.clicked()
    }

    anchors.fill: parent

    Image {
      id: phoneFrameImage
      anchors.fill: parent
      source: "Celu.png"
      sourceClipRect: phoneRoot.deviceArtCropRect
      fillMode: Image.Stretch
      smooth: true
      mipmap: true
    }

    Rectangle {
      id: screen
      anchors {
        fill: parent
        leftMargin: phoneRect.width * phoneRoot.screenInsetLeftRatio
        rightMargin: phoneRect.width * phoneRoot.screenInsetRightRatio
        topMargin: phoneRect.height * phoneRoot.screenInsetTopRatio
        bottomMargin: phoneRect.height * phoneRoot.screenInsetBottomRatio
      }
      radius: phoneRoot.screenRadius
      color: "#040506"
      antialiasing: true
      clip: true
      layer.enabled: !phoneRoot.mirrorDisplayVisible
      layer.effect: OpacityMask {
        maskSource: Rectangle {
          width: screen.width
          height: screen.height
          radius: screen.radius
          antialiasing: true
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: !phoneRoot.mirrorDisplayVisible
        gradient: Gradient {
          GradientStop { position: 0.0; color: "#161d2a" }
          GradientStop { position: 0.55; color: "#111825" }
          GradientStop { position: 1.0; color: "#07090d" }
        }
      }

      Rectangle {
        id: videoFrame
        anchors.centerIn: parent
        width: phoneRoot.videoFrameWidth
        height: phoneRoot.videoFrameHeight
        radius: phoneRoot.videoFrameRadius
        color: "black"
        antialiasing: true
        visible: phoneRoot.mirrorFeedEnabled
        clip: true
        layer.enabled: videoFrame.visible
        layer.effect: OpacityMask {
          maskSource: Rectangle {
            width: videoFrame.width
            height: videoFrame.height
            radius: videoFrame.radius
            antialiasing: true
          }
        }

        VideoOutput {
          id: mirrorVideoOutput
          anchors.fill: parent
          visible: phoneRoot.shouldActivateMirrorCamera
          opacity: phoneRoot.mirrorDisplayVisible ? 1 : 0
          fillMode: VideoOutput.Stretch

          onSourceRectChanged: {
            phoneRoot.syncMirrorSourceSizeFromVideoOutput();
            phoneRoot.evaluateMirrorSourceState();
          }
        }

        Connections {
          target: mirrorVideoOutput.videoSink
          enabled: target !== null && target !== undefined

          function onVideoFrameChanged(frame) {
            phoneRoot.noteMirrorFrameDelivered(frame);
          }
        }

        MouseArea {
          id: touchSurface
          anchors.fill: parent
          enabled: phoneRoot.interactiveScreen
          hoverEnabled: true
          activeFocusOnTab: phoneRoot.interactiveScreen
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

          property real startXNorm: 0
          property real startYNorm: 0
          property real endXNorm: 0
          property real endYNorm: 0
          property real startLocalX: 0
          property real startLocalY: 0
          property real wheelXNorm: 0.5
          property real wheelYNorm: 0.5
          property real wheelAccumX: 0
          property real wheelAccumY: 0
          property bool moved: false
          property double pressTimestamp: 0
          property int activeButton: Qt.NoButton

          function clampNorm(value, maxValue) {
            if (maxValue <= 0)
              return 0;
            return Math.max(0, Math.min(1, value / maxValue));
          }

          function forwardSpecialKey(key) {
            switch (key) {
              case Qt.Key_Backspace:
                phoneRoot.keyRequested(67);
                return true;
              case Qt.Key_Return:
              case Qt.Key_Enter:
                phoneRoot.keyRequested(66);
                return true;
              case Qt.Key_Tab:
                phoneRoot.keyRequested(61);
                return true;
              case Qt.Key_Delete:
                phoneRoot.keyRequested(112);
                return true;
              case Qt.Key_Escape:
                phoneRoot.keyRequested(111);
                return true;
              case Qt.Key_Left:
                phoneRoot.keyRequested(21);
                return true;
              case Qt.Key_Right:
                phoneRoot.keyRequested(22);
                return true;
              case Qt.Key_Up:
                phoneRoot.keyRequested(19);
                return true;
              case Qt.Key_Down:
                phoneRoot.keyRequested(20);
                return true;
              default:
                return false;
            }
          }

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: event => {
            if (!phoneRoot.interactiveScreen)
              return;

            let handled = forwardSpecialKey(event.key);
            const hasCommandModifier = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0;

            if (!handled && !hasCommandModifier) {
              const text = String(event.text || "");
              if (text !== "" && text >= " ") {
                phoneRoot.textRequested(text);
                handled = true;
              }
            }

            if (handled)
              event.accepted = true;
          }

          onPressed: mouse => {
            touchSurface.forceActiveFocus();

            activeButton = mouse.button;
            if (mouse.button === Qt.RightButton) {
              phoneRoot.keyRequested(4);
              return;
            }

            if (mouse.button === Qt.MiddleButton) {
              phoneRoot.homeRequested();
              return;
            }

            startLocalX = mouse.x;
            startLocalY = mouse.y;
            startXNorm = clampNorm(mouse.x, width);
            startYNorm = clampNorm(mouse.y, height);
            endXNorm = startXNorm;
            endYNorm = startYNorm;
            moved = false;
            pressTimestamp = Date.now();
          }

          onPositionChanged: mouse => {
            if (activeButton !== Qt.LeftButton || !(mouse.buttons & Qt.LeftButton))
              return;

            endXNorm = clampNorm(mouse.x, width);
            endYNorm = clampNorm(mouse.y, height);

            if (!moved) {
              moved = Math.abs(mouse.x - startLocalX) > 8 || Math.abs(mouse.y - startLocalY) > 8;
            }
          }

          onReleased: mouse => {
            if (activeButton !== Qt.LeftButton) {
              activeButton = Qt.NoButton;
              return;
            }

            const releaseXNorm = clampNorm(mouse.x, width);
            const releaseYNorm = clampNorm(mouse.y, height);
            const durationMs = Math.max(80, Math.min(1200, Math.round(Date.now() - pressTimestamp)));

            if (moved) {
              phoneRoot.swipeRequested(startXNorm, startYNorm, releaseXNorm, releaseYNorm, durationMs);
            } else {
              phoneRoot.tapRequested(releaseXNorm, releaseYNorm);
            }

            activeButton = Qt.NoButton;
          }

          onCanceled: {
            activeButton = Qt.NoButton;
          }

          onWheel: wheel => {
            if (!phoneRoot.interactiveScreen)
              return;

            const rawDeltaX = wheel.pixelDelta.x !== 0
              ? wheel.pixelDelta.x / 24
              : wheel.angleDelta.x / 120;
            const rawDeltaY = wheel.pixelDelta.y !== 0
              ? wheel.pixelDelta.y / 24
              : wheel.angleDelta.y / 120;

            if (rawDeltaX === 0 && rawDeltaY === 0)
              return;

            wheelXNorm = clampNorm(wheel.x, width);
            wheelYNorm = clampNorm(wheel.y, height);
            wheelAccumX += rawDeltaX;
            wheelAccumY += rawDeltaY;
            wheelDispatchTimer.restart();
            wheel.accepted = true;
          }

          Timer {
            id: wheelDispatchTimer
            interval: 40
            repeat: false
            onTriggered: {
              if (touchSurface.wheelAccumX === 0 && touchSurface.wheelAccumY === 0)
                return;

              phoneRoot.scrollRequested(
                touchSurface.wheelXNorm,
                touchSurface.wheelYNorm,
                touchSurface.wheelAccumX,
                touchSurface.wheelAccumY
              );
              touchSurface.wheelAccumX = 0;
              touchSurface.wheelAccumY = 0;
            }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "#00000000"
        visible: phoneRoot.showStatusOverlay
          && (phoneRoot.statusTitle !== ""
              || phoneRoot.statusSubtitle !== ""
              || phoneRoot.busy)
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity {
          NumberAnimation { duration: 120 }
        }

        MouseArea {
          anchors.fill: parent
          enabled: visible && !phoneRoot.interactiveScreen && !phoneRoot.busy
          hoverEnabled: enabled
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: phoneRoot.clicked()
        }

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#14000000" }
            GradientStop { position: 0.55; color: "#4d000000" }
            GradientStop { position: 1.0; color: "#8a000000" }
          }
        }

        Rectangle {
          id: statusCard
          anchors.centerIn: parent
          width: parent.width - (22 * phoneRoot.scaleFactor)
          implicitHeight: statusContent.implicitHeight + (20 * phoneRoot.scaleFactor)
          radius: 14 * phoneRoot.scaleFactor
          color: "#bb12161d"
          border.width: Math.max(1, Math.round(1 * phoneRoot.scaleFactor))
          border.color: "#26ffffff"

          ColumnLayout {
            id: statusContent
            anchors.fill: parent
            anchors.margins: 10 * phoneRoot.scaleFactor
            spacing: 6 * phoneRoot.scaleFactor

            BusyIndicator {
              Layout.alignment: Qt.AlignHCenter
              running: phoneRoot.busy
              visible: phoneRoot.busy
              implicitWidth: 18 * phoneRoot.scaleFactor
              implicitHeight: 18 * phoneRoot.scaleFactor
            }

            Text {
              visible: phoneRoot.statusTitle !== ""
              text: phoneRoot.statusTitle
              color: "white"
              textFormat: Text.PlainText
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              font.pixelSize: Math.max(11, Math.round(18 * phoneRoot.scaleFactor))
              font.weight: Font.DemiBold
              lineHeight: 1.08
              lineHeightMode: Text.ProportionalHeight
              maximumLineCount: 2
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              visible: phoneRoot.statusSubtitle !== ""
              text: phoneRoot.statusSubtitle
              color: "#E8E8E8"
              textFormat: Text.PlainText
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              font.pixelSize: Math.max(10, Math.round(14 * phoneRoot.scaleFactor))
              lineHeight: 1.14
              lineHeightMode: Text.ProportionalHeight
              maximumLineCount: 5
              elide: Text.ElideRight
              Layout.topMargin: phoneRoot.statusTitle !== "" ? 4 * phoneRoot.scaleFactor : 0
              Layout.fillWidth: true
            }
          }
        }
      }
    }

    Rectangle {
      anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: parent.bottom
        bottomMargin: 35 * phoneRoot.scaleFactor
      }
      width: 183 * phoneRoot.scaleFactor
      height: 4.8 * phoneRoot.scaleFactor
      radius: height / 2
      color: "white"
      opacity: 0.66
      visible: true
    }
  }
}
