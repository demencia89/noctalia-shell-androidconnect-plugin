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
    property int mediaDevicesReloadDelayMs: 80
    property bool mirrorFeedAttachDelayActive: false
    property bool nativeProbeReady: false
    property bool nativeProbePending: false
    property bool nativeCameraRebindPending: false
    property bool nativeZeroRectObserved: false
    property bool nativeZeroRectRecoveryScheduled: false
    property int nativeProbeRetryCount: 0
    property double nativeAttachStartedAtMs: 0
    property int nativeAttachRecoveryAttempts: 0
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
    readonly property real frameShadowRadius: 34 * phoneRoot.scaleFactor
    readonly property real statusCardRadius: 14 * phoneRoot.scaleFactor
    readonly property real statusCardMargin: 10 * phoneRoot.scaleFactor
    readonly property real statusCardSpacing: 6 * phoneRoot.scaleFactor
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
    readonly property color frameShadowColor: Qt.alpha(Color.mOutline, 0.26)
    readonly property color screenIdleBaseColor: Qt.alpha(Color.mSurface, 0.94)
    readonly property color screenIdleTopColor: Qt.alpha(Color.mSurfaceVariant, 0.96)
    readonly property color screenIdleMidColor: Qt.alpha(Color.mSurface, 0.92)
    readonly property color screenIdleBottomColor: Qt.alpha(Color.mPrimaryContainer, 0.52)
    readonly property color overlayFadeTopColor: Qt.alpha(Color.mSurface, 0.08)
    readonly property color overlayFadeMidColor: Qt.alpha(Color.mSurface, 0.32)
    readonly property color overlayFadeBottomColor: Qt.alpha(Color.mSurface, 0.58)
    readonly property color overlayCardColor: Qt.alpha(Color.mSurfaceVariant, 0.9)
    readonly property color overlayCardBorderColor: Qt.alpha(Color.mOutline, 0.34)
    readonly property color overlayTitleColor: Color.mOnSurface
    readonly property color overlaySubtitleColor: Color.mOnSurfaceVariant
    readonly property color homeIndicatorColor: Qt.alpha(Color.mOnSurface, 0.66)
    readonly property string normalizedIdMatch: (mirrorDeviceIdMatch || "").trim().toLowerCase()
    readonly property string normalizedDescriptionMatch: (mirrorDeviceDescriptionMatch || "").trim().toLowerCase()
    readonly property string trimmedMirrorDevicePath: String(mirrorDeviceIdMatch || "").trim()
    readonly property var mediaDevicesRef: mediaDevicesLoader.item
    readonly property var mediaVideoInputs: (mediaDevicesRef && mediaDevicesRef.videoInputs) ? mediaDevicesRef.videoInputs : []
    readonly property string availableVideoInputsSummary: videoInputsSummary(mediaVideoInputs)
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
        && nativeProbeReady
        && !nativeCameraRebindPending
        && !mirrorFeedAttachDelayActive
    readonly property bool mirrorFeedHasRenderedFrame: mirrorFeedFrameCount > 0
    readonly property bool mirrorFeedHasSourceRect: {
        const rect = mirrorVideoOutput ? mirrorVideoOutput.sourceRect : null;
        return Boolean(rect) && Number(rect.width || 0) > 0 && Number(rect.height || 0) > 0;
    }
    readonly property bool mirrorDisplayVisible: shouldActivateMirrorCamera
        && mirrorFeedError === ""
        && (mirrorFeedFrameLive || mirrorFeedHasRenderedFrame || mirrorFeedHasSourceRect)
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
    signal recentsRequested()

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

    function videoInputsSummary(inputs) {
        const list = inputs || [];
        if (!list.length)
            return "none";

        const parts = [];
        for (let i = 0; i < list.length; ++i)
            parts.push(videoInputSummary(list[i]));

        return parts.join(", ");
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
            nativeZeroRectObserved = activeSourceRectSummary === "0x0";
            debugLog("frame first sourceRect=" + activeSourceRectSummary);
            if (nativeZeroRectObserved
                    && shouldActivateMirrorCamera
                    && !nativeZeroRectRecoveryScheduled
                    && nativeAttachRecoveryAttempts === 0) {
                nativeZeroRectRecoveryScheduled = true;
                debugLog("nativeZeroRectRecovery scheduled");
                nativeZeroRectRecoveryTimer.restart();
            }
        }
    }

    function beginNativeAttachWindow(reason) {
        if (!mirrorFeedEnabled)
            return;

        nativeAttachStartedAtMs = Date.now();
        mirrorFeedAttachDelayActive = true;
        mirrorFeedAttachDelayTimer.restart();
        if (String(reason || "").trim() !== "")
            debugLog("nativeAttachWindow reason=" + String(reason || "") + " selectedInput=" + selectedVideoInputSummary);
    }

    function scheduleNativeCameraRebind(reason) {
        if (!mirrorFeedEnabled || !mirrorFeedAvailable || nativeCameraRebindPending)
            return;

        nativeCameraRebindPending = true;
        nativeZeroRectRecoveryScheduled = false;
        resetMirrorState();
        debugLog("nativeCameraRebind reason=" + String(reason || ""));
        nativeCameraRebindTimer.restart();
    }

    function resetMirrorState() {
        mirrorFeedError = "";
        mirrorFeedLastFrameAtMs = 0;
        mirrorFeedFrameLive = false;
        mirrorFeedFrameCount = 0;
        mirrorFirstFrameLogged = false;
        nativeZeroRectObserved = false;
    }

    function reloadMediaDevices(delayMs) {
        if (mediaDevicesReloadPending)
            return;

        mediaDevicesReloadDelayMs = Math.max(80, Math.round(Number(delayMs || 0)) || 80);
        mediaDevicesReloadPending = true;
        debugLog("reloadMediaDevices delayMs=" + mediaDevicesReloadDelayMs
            + " selectedInput=" + selectedVideoInputSummary
            + " inputs=" + availableVideoInputsSummary);
        mediaDevicesLoader.active = false;
        mediaDevicesReloadCommitTimer.interval = mediaDevicesReloadDelayMs;
        mediaDevicesReloadCommitTimer.restart();
    }

    function probeNativeLoopback() {
        if (!mirrorFeedEnabled)
            return;

        nativeProbePending = true;
        nativeProbeRetryCount = 0;
        nativeAttachRecoveryAttempts = 0;
        nativeAttachStartedAtMs = 0;
        resetMirrorState();
        debugLog("probeNativeLoopback selectedInput=" + selectedVideoInputSummary);
        reloadMediaDevices(180);
        nativeProbeRetryTimer.interval = 220;
        nativeProbeRetryTimer.restart();
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
        mediaDevicesReloadDelayMs = 80;
        mediaDevicesLoader.active = false;
        nativeProbeReady = false;
        nativeProbePending = false;
        nativeCameraRebindPending = false;
        nativeZeroRectObserved = false;
        nativeZeroRectRecoveryScheduled = false;
        nativeProbeRetryCount = 0;
        nativeAttachStartedAtMs = 0;
        nativeAttachRecoveryAttempts = 0;
        mirrorFeedAttachDelayActive = mirrorFeedEnabled;
        resetMirrorState();
        debugLog("mirrorFeedEnabled=" + mirrorFeedEnabled
            + " devicePath=" + trimmedMirrorDevicePath
            + " descriptionMatch=" + String(mirrorDeviceDescriptionMatch || ""));
        if (mirrorFeedEnabled) {
            mirrorFeedAttachDelayTimer.restart();
        } else {
            mirrorFeedAttachDelayTimer.stop();
        }
    }

    onAvailableVideoInputsSummaryChanged: {
        if (mirrorFeedEnabled)
            debugLog("availableVideoInputs=" + availableVideoInputsSummary);
    }

    onSelectedVideoInputSummaryChanged: {
        if (mirrorFeedEnabled)
            debugLog("selectedInput=" + selectedVideoInputSummary + " available=" + mirrorFeedAvailable);
    }

    onMirrorFeedAvailableChanged: {
        if (!mirrorFeedEnabled)
            return;

        resetMirrorState();
        if (mirrorFeedAvailable) {
            if (nativeProbePending || !nativeProbeReady) {
                nativeProbePending = false;
                nativeProbeReady = true;
                nativeProbeRetryCount = 0;
                debugLog("nativeProbeReady=true selectedInput=" + selectedVideoInputSummary);
                beginNativeAttachWindow("video-input-ready");
            }
            return;
        }

        nativeProbeReady = false;
        if (nativeProbePending && nativeProbeRetryCount < 6) {
            nativeProbeRetryCount += 1;
            nativeProbeRetryTimer.interval = nativeProbeRetryCount <= 2 ? 160 : 280;
            nativeProbeRetryTimer.restart();
        }
    }

    onMirrorFeedErrorChanged: {
        if (mirrorFeedEnabled && String(mirrorFeedError || "").trim() !== "")
            debugLog("mirrorFeedError=" + String(mirrorFeedError || ""));
    }

    Loader {
        id: mediaDevicesLoader

        active: false
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
            phoneRoot.debugLog("mediaDevicesReloadCommit selectedInput=" + phoneRoot.selectedVideoInputSummary
                + " inputs=" + phoneRoot.availableVideoInputsSummary);
        }
    }

    Timer {
        id: mirrorFeedAttachDelayTimer

        interval: 500
        repeat: false
        onTriggered: {
            phoneRoot.mirrorFeedAttachDelayActive = false;
        }
    }

    Timer {
        id: nativeCameraRebindTimer

        interval: 140
        repeat: false
        onTriggered: {
            if (!phoneRoot.mirrorFeedEnabled || !phoneRoot.mirrorFeedAvailable) {
                phoneRoot.nativeCameraRebindPending = false;
                return;
            }

            phoneRoot.nativeCameraRebindPending = false;
            phoneRoot.beginNativeAttachWindow("camera-rebind");
        }
    }

    Timer {
        id: nativeZeroRectRecoveryTimer

        interval: 180
        repeat: false
        onTriggered: {
            if (!phoneRoot.shouldActivateMirrorCamera
                    || !phoneRoot.nativeZeroRectObserved
                    || phoneRoot.mirrorFeedHasSourceRect
                    || phoneRoot.nativeAttachRecoveryAttempts > 0) {
                phoneRoot.nativeZeroRectRecoveryScheduled = false;
                return;
            }

            phoneRoot.nativeAttachRecoveryAttempts = 1;
            phoneRoot.debugLog("nativeAttachRecovery attempt=1 selectedInput="
                + phoneRoot.selectedVideoInputSummary
                + " sourceRect=" + phoneRoot.activeSourceRectSummary
                + " fastPath=true");
            phoneRoot.scheduleNativeCameraRebind("zero-source-rect");
        }
    }

    Timer {
        id: mediaDevicesRetryTimer

        interval: 1200
        repeat: true
        running: phoneRoot.mirrorFeedEnabled
            && (phoneRoot.nativeProbePending || phoneRoot.nativeProbeReady)
            && !phoneRoot.mirrorFeedAvailable
            && !phoneRoot.mediaDevicesReloadPending
        onTriggered: {
            phoneRoot.debugLog("mediaDevicesRetry selectedInput=" + phoneRoot.selectedVideoInputSummary
                + " inputs=" + phoneRoot.availableVideoInputsSummary);
            phoneRoot.reloadMediaDevices(220);
        }
    }

    Timer {
        id: nativeProbeRetryTimer

        interval: 180
        repeat: false
        onTriggered: {
            if (!phoneRoot.mirrorFeedEnabled
                    || !phoneRoot.nativeProbePending
                    || phoneRoot.mirrorFeedAvailable
                    || phoneRoot.mediaDevicesReloadPending)
                return;

            phoneRoot.debugLog("nativeProbeRetry attempt=" + phoneRoot.nativeProbeRetryCount);
            phoneRoot.reloadMediaDevices(phoneRoot.nativeProbeRetryCount <= 2 ? 180 : 260);
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

    Timer {
        id: nativeAttachRecoveryTimer

        interval: 700
        repeat: true
        running: phoneRoot.mirrorFeedEnabled
        onTriggered: {
            if (!phoneRoot.shouldActivateMirrorCamera
                    || phoneRoot.mirrorFeedError !== ""
                    || phoneRoot.mirrorFeedHasSourceRect
                    || phoneRoot.nativeAttachStartedAtMs <= 0)
                return;

            const attachAgeMs = Date.now() - phoneRoot.nativeAttachStartedAtMs;
            const recoveryDelayMs = phoneRoot.nativeZeroRectObserved ? 900 : 1400;
            if (attachAgeMs < recoveryDelayMs)
                return;

            if (phoneRoot.nativeAttachRecoveryAttempts >= 2)
                return;

            phoneRoot.nativeAttachRecoveryAttempts += 1;
            phoneRoot.debugLog("nativeAttachRecovery attempt=" + phoneRoot.nativeAttachRecoveryAttempts
                + " selectedInput=" + phoneRoot.selectedVideoInputSummary
                + " sourceRect=" + phoneRoot.activeSourceRectSummary);

            if (phoneRoot.nativeAttachRecoveryAttempts === 1) {
                phoneRoot.scheduleNativeCameraRebind("stalled-first-frame");
                return;
            }

            phoneRoot.nativeProbePending = true;
            phoneRoot.nativeProbeRetryCount = 0;
            phoneRoot.beginNativeAttachWindow("stalled-first-frame");
            phoneRoot.reloadMediaDevices(220);
            nativeProbeRetryTimer.interval = 220;
            nativeProbeRetryTimer.restart();
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
            if (active) {
                phoneRoot.resetMirrorState();
            } else {
                phoneRoot.mirrorFeedFrameLive = false;
            }
        }
        onCameraDeviceChanged: phoneRoot.resetMirrorState()
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
        radius: phoneRoot.frameShadowRadius
        blur: 24
        spread: 0.08
        color: phoneRoot.frameShadowColor
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
            color: phoneRoot.screenIdleBaseColor
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
                opacity: phoneRoot.mirrorDisplayVisible ? 0 : 1

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: phoneRoot.screenIdleTopColor
                    }

                    GradientStop {
                        position: 0.55
                        color: phoneRoot.screenIdleMidColor
                    }

                    GradientStop {
                        position: 1
                        color: phoneRoot.screenIdleBottomColor
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                id: videoFrame

                anchors.centerIn: parent
                width: phoneRoot.videoFrameWidth
                height: phoneRoot.videoFrameHeight
                radius: phoneRoot.videoFrameRadius
                color: "transparent"
                antialiasing: true
                visible: phoneRoot.mirrorFeedEnabled
                clip: true
                layer.enabled: videoFrame.visible && mirrorVideoReveal.visible

                Rectangle {
                    id: videoFrameBed

                    anchors.fill: parent
                    color: phoneRoot.screenIdleBaseColor
                    opacity: mirrorVideoReveal.opacity

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    id: mirrorVideoReveal

                    anchors.fill: parent
                    visible: phoneRoot.shouldActivateMirrorCamera || opacity > 0.001
                    opacity: phoneRoot.mirrorDisplayVisible ? 1 : 0
                    scale: phoneRoot.mirrorDisplayVisible ? 1 : 0.9875
                    y: phoneRoot.mirrorDisplayVisible ? 0 : (8 * phoneRoot.scaleFactor)
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }

                    VideoOutput {
                        id: mirrorVideoOutput

                        anchors.fill: parent
                        visible: phoneRoot.shouldActivateMirrorCamera || parent.opacity > 0.001
                        fillMode: VideoOutput.Stretch
                        onSourceRectChanged: {
                            if (sourceRect.width > 0 && sourceRect.height > 0) {
                                phoneRoot.nativeAttachStartedAtMs = 0;
                                phoneRoot.nativeZeroRectRecoveryScheduled = false;
                                phoneRoot.debugLog("videoOutput sourceRect=" + activeSourceRectSummary);
                            } else if (phoneRoot.shouldActivateMirrorCamera
                                    && phoneRoot.nativeZeroRectObserved
                                    && !phoneRoot.nativeZeroRectRecoveryScheduled
                                    && phoneRoot.nativeAttachRecoveryAttempts === 0) {
                                phoneRoot.nativeZeroRectRecoveryScheduled = true;
                                phoneRoot.debugLog("nativeZeroRectRecovery scheduled");
                                nativeZeroRectRecoveryTimer.restart();
                            }
                        }
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
                        case Qt.Key_Home:
                            phoneRoot.homeRequested();
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
                            phoneRoot.recentsRequested();
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
                color: "transparent"
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
                            color: phoneRoot.overlayFadeTopColor
                        }

                        GradientStop {
                            position: 0.55
                            color: phoneRoot.overlayFadeMidColor
                        }

                        GradientStop {
                            position: 1
                            color: phoneRoot.overlayFadeBottomColor
                        }
                    }
                }

                Rectangle {
                    id: statusCard

                    anchors.centerIn: parent
                    width: parent.width - (22 * phoneRoot.scaleFactor)
                    implicitHeight: statusContent.implicitHeight + (20 * phoneRoot.scaleFactor)
                    radius: phoneRoot.statusCardRadius
                    color: phoneRoot.overlayCardColor
                    border.width: Math.max(1, Math.round(1 * phoneRoot.scaleFactor))
                    border.color: phoneRoot.overlayCardBorderColor

                    ColumnLayout {
                        id: statusContent

                        anchors.fill: parent
                        anchors.margins: phoneRoot.statusCardMargin
                        spacing: phoneRoot.statusCardSpacing

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
                            color: phoneRoot.overlayTitleColor
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
                            color: phoneRoot.overlaySubtitleColor
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
            color: phoneRoot.homeIndicatorColor
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
