import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtMultimedia

Rectangle {
  id: phoneRoot

  property string backgroundImage: ""
  property bool showStatusOverlay: false
  property string statusTitle: ""
  property string statusSubtitle: ""
  property bool busy: false
  property bool mirrorFeedEnabled: false
  property bool interactiveScreen: false
  property bool overlayWindowActive: false
  property string mirrorDeviceIdMatch: ""
  property string mirrorDeviceDescriptionMatch: ""
  property int mirrorContentWidth: 0
  property int mirrorContentHeight: 0
  property string mirrorFeedError: ""
  property bool mirrorFeedRestarting: false
  property bool mediaDevicesReloadPending: false
  property bool mirrorFeedAttachDelayActive: false

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
  readonly property bool externalOverlayVisible: phoneRoot.overlayWindowActive && !phoneRoot.mirrorFeedEnabled
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

    for (let i = 0; i < formats.length; ++i) {
      const format = formats[i];
      const resolution = format && format.resolution ? format.resolution : null;
      if (!resolution)
        continue;

      const width = Number(resolution.width);
      const height = Number(resolution.height);
      if (width === 576 && height === 1280)
        return format;
    }

    return formats.length > 0 ? formats[0] : undefined;
  }
  readonly property bool shouldActivateMirrorCamera: mirrorFeedEnabled
    && mirrorFeedAvailable
    && !mirrorFeedRestarting
    && !mirrorFeedAttachDelayActive
  readonly property bool mirrorDisplayVisible: shouldActivateMirrorCamera && mirrorFeedError === ""
  readonly property bool snapshotFrameVisible: backgroundImage !== "" && !externalOverlayVisible

  radius: 0
  color: "transparent"
  border.width: 0
  border.color: "transparent"
  clip: false

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
    interval: 1400
    repeat: false
    onTriggered: {
      phoneRoot.mirrorFeedAttachDelayActive = false;
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
      if (active)
        phoneRoot.mirrorFeedError = "";
    }

    onCameraDeviceChanged: {
      phoneRoot.mirrorFeedError = "";
    }

    onErrorOccurred: (error, errorString) => {
      phoneRoot.mirrorFeedError = errorString !== "" ? errorString : ("camera error " + error);
    }
  }

  onMirrorFeedEnabledChanged: {
    mirrorFeedError = "";
    mirrorFeedRestarting = false;
    mediaDevicesReloadPending = false;
    mirrorFeedAttachDelayActive = mirrorFeedEnabled;
    if (mirrorFeedEnabled)
      mirrorFeedAttachDelayTimer.restart();
    else
      mirrorFeedAttachDelayTimer.stop();
  }

  onMirrorFeedAvailableChanged: {
    if (mirrorFeedAvailable)
      mirrorFeedError = "";
    else
      mirrorFeedRestarting = false;
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
      enabled: !phoneRoot.interactiveScreen && !phoneRoot.externalOverlayVisible

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
      color: phoneRoot.externalOverlayVisible ? "transparent" : "#040506"
      antialiasing: true
      clip: true
      layer.enabled: !phoneRoot.mirrorDisplayVisible || phoneRoot.externalOverlayVisible
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
        visible: !phoneRoot.mirrorDisplayVisible && !phoneRoot.externalOverlayVisible
        gradient: Gradient {
          GradientStop { position: 0.0; color: "#161d2a" }
          GradientStop { position: 0.55; color: "#111825" }
          GradientStop { position: 1.0; color: "#07090d" }
        }
      }

      Image {
        anchors.fill: parent
        source: phoneRoot.backgroundImage
        fillMode: Image.PreserveAspectCrop
        visible: phoneRoot.backgroundImage !== "" && !phoneRoot.mirrorDisplayVisible && !phoneRoot.externalOverlayVisible
      }

      Item {
        anchors.fill: parent
        visible: phoneRoot.externalOverlayVisible

        Rectangle {
          x: 0
          y: 0
          width: parent.width
          height: videoFrame.y
          color: "black"
        }

        Rectangle {
          x: 0
          y: videoFrame.y + videoFrame.height
          width: parent.width
          height: Math.max(0, parent.height - y)
          color: "black"
        }

        Rectangle {
          x: 0
          y: videoFrame.y
          width: videoFrame.x
          height: videoFrame.height
          color: "black"
        }

        Rectangle {
          x: videoFrame.x + videoFrame.width
          y: videoFrame.y
          width: Math.max(0, parent.width - x)
          height: videoFrame.height
          color: "black"
        }
      }

      Rectangle {
        id: videoFrame
        anchors.centerIn: parent
        width: phoneRoot.videoFrameWidth
        height: phoneRoot.videoFrameHeight
        radius: phoneRoot.videoFrameRadius
        color: phoneRoot.externalOverlayVisible ? "transparent" : "black"
        antialiasing: true
        visible: phoneRoot.mirrorFeedEnabled || phoneRoot.externalOverlayVisible || phoneRoot.snapshotFrameVisible
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
          visible: phoneRoot.mirrorDisplayVisible
          fillMode: VideoOutput.Stretch
        }

        Image {
          anchors.fill: parent
          source: phoneRoot.backgroundImage
          fillMode: Image.PreserveAspectCrop
          visible: !phoneRoot.mirrorDisplayVisible
            && !phoneRoot.externalOverlayVisible
            && phoneRoot.backgroundImage !== ""
          smooth: true
          mipmap: true
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
          enabled: visible && !phoneRoot.interactiveScreen && !phoneRoot.busy && !phoneRoot.externalOverlayVisible
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
      visible: !phoneRoot.externalOverlayVisible
    }
  }
}
