import Qt5Compat.GraphicalEffects
import QtMultimedia
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons

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
    property string mirrorFeedError: ""
    property bool mediaDevicesReloadPending: false
    property bool mirrorFeedAttachDelayActive: false
    property double mirrorFeedLastFrameAtMs: 0
    property bool mirrorFeedFrameLive: false
    property int mirrorFeedFrameCount: 0
    property bool mirrorFirstFrameLogged: false
    property var debugLogQueue: []
    property string debugAppendLine: ""
    readonly property string debugLogPath: "/tmp/androidconnect-preview-debug.log"
    readonly property real deviceArtWidth: 597
    readonly property real deviceArtHeight: 1241
    readonly property rect deviceArtCropRect: Qt.rect(586, 27, 597, 1241)
    readonly property real screenInsetLeftRatio: 25 / deviceArtWidth
    readonly property real screenInsetRightRatio: 34 / deviceArtWidth
    readonly property real screenInsetTopRatio: 26 / deviceArtHeight
    readonly property real screenInsetBottomRatio: 25 / deviceArtHeight
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
    readonly property string normalizedIdMatch: (mirrorDeviceIdMatch || "").trim().toLowerCase()
    readonly property string normalizedDescriptionMatch: (mirrorDeviceDescriptionMatch || "").trim().toLowerCase()
    readonly property string trimmedMirrorDevicePath: String(mirrorDeviceIdMatch || "").trim()
    readonly property var mediaDevicesRef: mediaDevicesLoader.item
    readonly property var mediaVideoInputs: (mediaDevicesRef && mediaDevicesRef.videoInputs) ? mediaDevicesRef.videoInputs : []
    readonly property var selectedVideoInput: {
        const inputs = mediaVideoInputs || [];
        return findMatchingVideoInput(inputs, normalizedDescriptionMatch, "description", true)
            || findMatchingVideoInput(inputs, normalizedIdMatch, "id", true)
            || findMatchingVideoInput(inputs, normalizedDescriptionMatch, "description", false)
            || findMatchingVideoInput(inputs, normalizedIdMatch, "id", false)
            || (normalizedDescriptionMatch !== "" ? findScrcpyVideoInput(inputs) : undefined)
            || defaultVideoInput(inputs);
    }
    readonly property string selectedVideoInputSummary: videoInputSummary(selectedVideoInput)
    readonly property bool mirrorFeedAvailable: hasVideoInput(selectedVideoInput)
    readonly property bool shouldActivateMirrorCamera: mirrorFeedEnabled
        && mirrorFeedAvailable
        && !mirrorFeedAttachDelayActive
    readonly property bool mirrorDisplayVisible: shouldActivateMirrorCamera
        && mirrorFeedError === ""
        && mirrorFeedFrameLive
    readonly property string activeSourceRectSummary: {
        const rect = mirrorVideoOutput ? mirrorVideoOutput.sourceRect : null;
        const width = rect ? Math.round(Number(rect.width || 0)) : 0;
        const height = rect ? Math.round(Number(rect.height || 0)) : 0;
        return width > 0 && height > 0 ? (width + "x" + height) : "0x0";
    }

    signal clicked()
    signal tapRequested(real x, real y)
    signal swipeRequested(real x1, real y1, real x2, real y2, int durationMs)
    signal scrollRequested(real x, real y, real deltaX, real deltaY)
    signal textRequested(string text)
    signal keyRequested(int keyCode)
    signal homeRequested()

    function hasVideoInput(input) {
        return input !== undefined && input !== null && !input.isNull;
    }

    function videoInputSummary(input) {
        if (!hasVideoInput(input))
            return "none";

        const description = String(input.description || "").trim();
        const id = String(input.id || "").trim();
        if (description !== "" && id !== "")
            return description + " [" + id + "]";

        return description !== "" ? description : id;
    }

    function findMatchingVideoInput(inputs, needle, fieldName, exact) {
        if (needle === "")
            return undefined;

        for (let i = 0; i < inputs.length; ++i) {
            const device = inputs[i];
            const fieldValue = normalizeText(device ? device[fieldName] : "");
            if ((exact && fieldValue === needle) || (!exact && fieldValue.indexOf(needle) !== -1))
                return device;
        }

        return undefined;
    }

    function findScrcpyVideoInput(inputs) {
        for (let i = 0; i < inputs.length; ++i) {
            const device = inputs[i];
            const description = normalizeText(device ? device.description : "");
            const id = normalizeText(device ? device.id : "");
            if (description.indexOf("scrcpy") !== -1 || id.indexOf("scrcpy") !== -1 || description.indexOf("loopback") !== -1)
                return device;
        }

        return undefined;
    }

    function defaultVideoInput(inputs) {
        if (normalizedIdMatch !== "" || normalizedDescriptionMatch !== "")
            return undefined;

        if (inputs.length === 1)
            return inputs[0];

        const defaultInput = mediaDevicesRef ? mediaDevicesRef.defaultVideoInput : null;
        return hasVideoInput(defaultInput) ? defaultInput : undefined;
    }

    function normalizeText(value) {
        return String(value || "").trim().toLowerCase();
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\"'\"'") + "'";
    }

    function debugLog(message) {
        const timestamp = new Date().toISOString();
        const line = timestamp + " " + String(message || "");
        Logger.i("AndroidConnectPreview", line);
        const queue = Array.isArray(debugLogQueue) ? debugLogQueue.slice() : [];
        queue.push(line);
        debugLogQueue = queue;
        flushDebugLogQueue();
    }

    function flushDebugLogQueue() {
        if (debugAppendProc.running)
            return;

        const queue = Array.isArray(debugLogQueue) ? debugLogQueue.slice() : [];
        if (queue.length === 0)
            return;

        debugAppendLine = String(queue.shift() || "");
        debugLogQueue = queue;
        debugAppendProc.running = true;
    }

    function normalizeMirrorError(message) {
        const text = String(message || "").trim();
        if (text.indexOf("Device or resource busy") !== -1 || text.indexOf("Camera is in use") !== -1)
            return "Loopback device is busy. Recreate v4l2loopback with exclusive_caps=0 so scrcpy can write and the panel can read it.";

        return text;
    }

    function noteMirrorFrameDelivered() {
        mirrorFeedLastFrameAtMs = Date.now();
        mirrorFeedFrameLive = true;
        mirrorFeedFrameCount += 1;
        if (!mirrorFirstFrameLogged) {
            mirrorFirstFrameLogged = true;
            debugLog("frame first sourceRect=" + activeSourceRectSummary);
        } else if ((mirrorFeedFrameCount % 240) === 0) {
            debugLog("frame count=" + mirrorFeedFrameCount + " sourceRect=" + activeSourceRectSummary);
        }
    }

    function resetMirrorState() {
        mirrorFeedError = "";
        mirrorFeedLastFrameAtMs = 0;
        mirrorFeedFrameLive = false;
        mirrorFeedFrameCount = 0;
        mirrorFirstFrameLogged = false;
    }

    function reloadMediaDevices() {
        if (mediaDevicesReloadPending)
            return;

        mediaDevicesReloadPending = true;
        mediaDevicesLoader.active = false;
        mediaDevicesReloadCommitTimer.restart();
    }

    function probeNativeLoopback() {
        if (!mirrorFeedEnabled)
            return;

        resetMirrorState();
        debugLog("probeNativeLoopback selectedInput=" + selectedVideoInputSummary);
        reloadMediaDevices();
    }

    height: parent ? parent.height : 235
    width: parent ? parent.width : (height / deviceArtHeight) * deviceArtWidth
    radius: 0
    color: "transparent"
    border.width: 0
    border.color: "transparent"
    clip: false

    Component.onCompleted: {
        debugResetProc.running = true;
    }

    onMirrorFeedEnabledChanged: {
        mediaDevicesReloadPending = false;
        mirrorFeedAttachDelayActive = mirrorFeedEnabled;
        resetMirrorState();
        debugLog("mirrorFeedEnabled=" + mirrorFeedEnabled
            + " devicePath=" + trimmedMirrorDevicePath
            + " descriptionMatch=" + String(mirrorDeviceDescriptionMatch || ""));
        if (mirrorFeedEnabled) {
            mirrorFeedAttachDelayTimer.restart();
            Qt.callLater(function() {
                if (phoneRoot.mirrorFeedEnabled)
                    phoneRoot.reloadMediaDevices();
            });
        } else {
            mirrorFeedAttachDelayTimer.stop();
        }
    }

    onMirrorFeedAvailableChanged: {
        if (!mirrorFeedEnabled)
            return;

        debugLog("mirrorFeedAvailable=" + mirrorFeedAvailable
            + " selectedInput=" + selectedVideoInputSummary);
        resetMirrorState();
    }

    onMirrorFeedErrorChanged: {
        if (mirrorFeedEnabled && String(mirrorFeedError || "").trim() !== "")
            debugLog("mirrorFeedError=" + String(mirrorFeedError || ""));
    }

    Loader {
        id: mediaDevicesLoader

        active: true
        sourceComponent: mediaDevicesComponent
    }

    Component {
        id: mediaDevicesComponent

        MediaDevices {
        }
    }

    Timer {
        id: mediaDevicesReloadCommitTimer

        interval: 80
        repeat: false
        onTriggered: {
            mediaDevicesLoader.active = true;
            phoneRoot.mediaDevicesReloadPending = false;
            phoneRoot.debugLog("mediaDevicesReloadCommit active=" + mediaDevicesLoader.active
                + " selectedInput=" + selectedVideoInputSummary);
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

    Timer {
        id: mediaDevicesRetryTimer

        interval: 1200
        repeat: true
        running: phoneRoot.mirrorFeedEnabled
            && !phoneRoot.mirrorFeedAvailable
            && !phoneRoot.mediaDevicesReloadPending
        onTriggered: phoneRoot.reloadMediaDevices()
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
        videoOutput: phoneRoot.shouldActivateMirrorCamera ? mirrorVideoOutput.videoSink : null
    }

    Camera {
        id: mirrorCamera

        active: phoneRoot.shouldActivateMirrorCamera
        onActiveChanged: {
            phoneRoot.debugLog("camera active=" + active
                + " selectedInput=" + selectedVideoInputSummary);
            if (active) {
                phoneRoot.resetMirrorState();
            } else {
                phoneRoot.mirrorFeedFrameLive = false;
            }
        }
        onCameraDeviceChanged: {
            phoneRoot.debugLog("cameraDeviceChanged selectedInput=" + selectedVideoInputSummary);
            phoneRoot.resetMirrorState();
        }
        onErrorOccurred: (error, errorString) => {
            phoneRoot.mirrorFeedFrameLive = false;
            phoneRoot.mirrorFeedError = phoneRoot.normalizeMirrorError(errorString !== "" ? errorString : ("camera error " + error));
        }
    }

    Binding {
        target: mirrorCamera
        property: "cameraDevice"
        when: phoneRoot.shouldActivateMirrorCamera
            && phoneRoot.hasVideoInput(phoneRoot.selectedVideoInput)
        value: phoneRoot.selectedVideoInput
    }

    Binding {
        target: mirrorCamera
        property: "cameraDevice"
        when: !phoneRoot.shouldActivateMirrorCamera
        value: null
    }

    Process {
        id: debugResetProc

        running: false
        command: ["sh", "-lc",
            ": > " + phoneRoot.shellQuote(phoneRoot.debugLogPath)
            + "; printf '%s\\n' "
            + phoneRoot.shellQuote("=== AndroidConnect preview debug session ===")
            + " >> " + phoneRoot.shellQuote(phoneRoot.debugLogPath)
        ]

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: {
            phoneRoot.debugLog("debugLogPath=" + phoneRoot.debugLogPath);
            phoneRoot.debugLog("component completed devicePath=" + trimmedMirrorDevicePath
                + " descriptionMatch=" + String(mirrorDeviceDescriptionMatch || ""));
        }
    }

    Process {
        id: debugAppendProc

        running: false
        command: ["sh", "-lc",
            "line=" + phoneRoot.shellQuote(phoneRoot.debugAppendLine)
            + "; printf '%s\\n' \"$line\" >> " + phoneRoot.shellQuote(phoneRoot.debugLogPath)
        ]

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: phoneRoot.flushDebugLogQueue()
    }

    RectangularShadow {
        anchors.fill: phoneRect
        radius: 34 * phoneRoot.scaleFactor
        blur: 24
        spread: 0.08
        color: "#42000000"
    }

    Item {
        id: phoneRect

        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            enabled: !phoneRoot.interactiveScreen
            onClicked: phoneRoot.clicked()
        }

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

            radius: phoneRoot.screenRadius
            color: "#040506"
            antialiasing: true
            clip: true
            layer.enabled: !phoneRoot.mirrorDisplayVisible

            anchors {
                fill: parent
                leftMargin: phoneRect.width * phoneRoot.screenInsetLeftRatio
                rightMargin: phoneRect.width * phoneRoot.screenInsetRightRatio
                topMargin: phoneRect.height * phoneRoot.screenInsetTopRatio
                bottomMargin: phoneRect.height * phoneRoot.screenInsetBottomRatio
            }

            Rectangle {
                anchors.fill: parent
                visible: !phoneRoot.mirrorDisplayVisible

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#161d2a"
                    }

                    GradientStop {
                        position: 0.55
                        color: "#111825"
                    }

                    GradientStop {
                        position: 1
                        color: "#07090d"
                    }
                }
            }

            Rectangle {
                id: videoFrame

                anchors.centerIn: parent
                width: phoneRoot.videoFrameWidth
                height: phoneRoot.videoFrameHeight
                radius: phoneRoot.videoFrameRadius
                color: phoneRoot.mirrorDisplayVisible ? "black" : "transparent"
                antialiasing: true
                visible: phoneRoot.mirrorFeedEnabled
                clip: true
                layer.enabled: videoFrame.visible && phoneRoot.mirrorDisplayVisible

                VideoOutput {
                    id: mirrorVideoOutput

                    anchors.fill: parent
                    visible: phoneRoot.shouldActivateMirrorCamera
                    opacity: phoneRoot.mirrorDisplayVisible ? 1 : 0
                    fillMode: VideoOutput.Stretch
                    onSourceRectChanged: {
                        if (sourceRect.width > 0 && sourceRect.height > 0)
                            phoneRoot.debugLog("videoOutput sourceRect=" + activeSourceRectSummary);
                    }
                }

                Connections {
                    function onVideoFrameChanged(frame) {
                        phoneRoot.noteMirrorFrameDelivered();
                    }

                    target: mirrorVideoOutput.videoSink
                    enabled: target !== null && target !== undefined
                }

                MouseArea {
                    id: touchSurface

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

                    anchors.fill: parent
                    enabled: phoneRoot.interactiveScreen
                    hoverEnabled: true
                    activeFocusOnTab: phoneRoot.interactiveScreen
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: (event) => {
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
                    onPressed: (mouse) => {
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
                    onPositionChanged: (mouse) => {
                        if (activeButton !== Qt.LeftButton || !(mouse.buttons & Qt.LeftButton))
                            return;

                        endXNorm = clampNorm(mouse.x, width);
                        endYNorm = clampNorm(mouse.y, height);
                        if (!moved)
                            moved = Math.abs(mouse.x - startLocalX) > 8 || Math.abs(mouse.y - startLocalY) > 8;
                    }
                    onReleased: (mouse) => {
                        if (activeButton !== Qt.LeftButton) {
                            activeButton = Qt.NoButton;
                            return;
                        }
                        const releaseXNorm = clampNorm(mouse.x, width);
                        const releaseYNorm = clampNorm(mouse.y, height);
                        const durationMs = Math.max(80, Math.min(1200, Math.round(Date.now() - pressTimestamp)));
                        if (moved)
                            phoneRoot.swipeRequested(startXNorm, startYNorm, releaseXNorm, releaseYNorm, durationMs);
                        else
                            phoneRoot.tapRequested(releaseXNorm, releaseYNorm);
                        activeButton = Qt.NoButton;
                    }
                    onCanceled: {
                        activeButton = Qt.NoButton;
                    }
                    onWheel: (wheel) => {
                        if (!phoneRoot.interactiveScreen)
                            return;

                        const rawDeltaX = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x / 24 : wheel.angleDelta.x / 120;
                        const rawDeltaY = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y / 24 : wheel.angleDelta.y / 120;
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

                            phoneRoot.scrollRequested(touchSurface.wheelXNorm, touchSurface.wheelYNorm, touchSurface.wheelAccumX, touchSurface.wheelAccumY);
                            touchSurface.wheelAccumX = 0;
                            touchSurface.wheelAccumY = 0;
                        }
                    }
                }

                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: videoFrame.width
                        height: videoFrame.height
                        radius: videoFrame.radius
                        antialiasing: true
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#00000000"
                visible: phoneRoot.showStatusOverlay && (phoneRoot.statusTitle !== "" || phoneRoot.statusSubtitle !== "" || phoneRoot.busy)
                opacity: visible ? 1 : 0

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
                        GradientStop {
                            position: 0
                            color: "#14000000"
                        }

                        GradientStop {
                            position: 0.55
                            color: "#4d000000"
                        }

                        GradientStop {
                            position: 1
                            color: "#8a000000"
                        }
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

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }

            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: screen.width
                    height: screen.height
                    radius: screen.radius
                    antialiasing: true
                }
            }
        }

        Rectangle {
            width: 183 * phoneRoot.scaleFactor
            height: 4.8 * phoneRoot.scaleFactor
            radius: height / 2
            color: "white"
            opacity: 0.66
            visible: true

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 35 * phoneRoot.scaleFactor
            }
        }
    }
}
