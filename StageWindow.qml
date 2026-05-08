import QtQuick
import QtQuick.Window
import QtMultimedia

Window {
    id: stage

    required property var backend
    property real ownerX: 0
    property real ownerY: 0
    property int activeSurfaceIndex: 0
    property int layoutGeneration: 0
    property bool pendingForceReload: false
    property bool waitingForViewport: false

    readonly property string requestedMediaUrl: stage.backend.stageActive ? stage.backend.currentMediaUrl : ""
    readonly property bool requestedMediaIsVideo: stage.backend.stageActive && stage.backend.currentMediaIsVideo
    readonly property bool requestedMediaRepeats: stage.backend.stageActive && stage.backend.currentMediaRepeats

    function configureWindow() {
        if (stage.backend.stageScreen)
            stage.screen = stage.backend.stageScreen

        if (stage.backend.hasSecondScreen()) {
            x = stage.backend.stageX
            y = stage.backend.stageY
            width = stage.backend.stageWidth
            height = stage.backend.stageHeight
            showFullScreen()
            requestViewportReload()
        } else {
            showNormal()
            x = Math.max(40, stage.ownerX + 40)
            y = Math.max(40, stage.ownerY + 40)
            width = 960
            height = 540
            raise()
            requestActivate()
            scheduleMediaSwitch(false)
        }
    }

    function surfaceAt(index) {
        return index === 0 ? surfaceA : surfaceB
    }

    function scheduleMediaSwitch(forceReload) {
        pendingForceReload = pendingForceReload || !!forceReload
        mediaSwitchTimer.restart()
    }

    function requestViewportReload() {
        waitingForViewport = true
        viewportReloadTimer.restart()
    }

    function clearSurfaces() {
        mediaSwitchTimer.stop()
        viewportReloadTimer.stop()
        pendingForceReload = false
        waitingForViewport = false
        surfaceA.clearSurface()
        surfaceB.clearSurface()
        activeSurfaceIndex = 0
    }

    function queueStageMedia() {
        if (waitingForViewport)
            return

        var targetUrl = stage.requestedMediaUrl
        if (!stage.backend.stageActive || targetUrl === "") {
            stage.clearSurfaces()
            return
        }

        var forceReload = pendingForceReload
        pendingForceReload = false

        var activeSurface = stage.surfaceAt(stage.activeSurfaceIndex)
        if (activeSurface.mediaUrl === targetUrl
                && activeSurface.isVideo === stage.requestedMediaIsVideo
                && activeSurface.loadedGeneration === stage.layoutGeneration
                && !forceReload) {
            activeSurface.repeats = stage.requestedMediaRepeats
            return
        }

        var loadingIndex = stage.activeSurfaceIndex === 0 ? 1 : 0
        var loadingSurface = stage.surfaceAt(loadingIndex)
        loadingSurface.loadMedia(targetUrl, stage.requestedMediaIsVideo, stage.requestedMediaRepeats, stage.layoutGeneration)
    }

    function commitSurface(index) {
        var candidate = stage.surfaceAt(index)
        if (!stage.backend.stageActive
                || candidate.mediaUrl !== stage.requestedMediaUrl
                || candidate.isVideo !== stage.requestedMediaIsVideo
                || candidate.loadedGeneration !== stage.layoutGeneration)
            return

        var previousIndex = stage.activeSurfaceIndex
        stage.activeSurfaceIndex = index
        candidate.repeats = stage.requestedMediaRepeats

        if (previousIndex !== index)
            stage.surfaceAt(previousIndex).clearSurface()
    }

    visible: stage.backend.stageActive
    screen: stage.backend.stageScreen
    x: stage.backend.hasSecondScreen() ? stage.backend.stageX : Math.max(40, stage.ownerX + 40)
    y: stage.backend.hasSecondScreen() ? stage.backend.stageY : Math.max(40, stage.ownerY + 40)
    width: stage.backend.hasSecondScreen() ? stage.backend.stageWidth : 960
    height: stage.backend.hasSecondScreen() ? stage.backend.stageHeight : 540
    minimumWidth: 640
    minimumHeight: 360
    title: "BOSTONCREW SAMPLER / Stage"
    color: "black"
    flags: Qt.Window

    Component.onCompleted: stage.scheduleMediaSwitch(false)

    onClosing: function() {
        stage.backend.closeStage()
    }

    onVisibleChanged: {
        if (!visible) {
            stage.clearSurfaces()
            return
        }

        stage.configureWindow()
    }

    Timer {
        id: mediaSwitchTimer

        interval: 0
        repeat: false
        onTriggered: stage.queueStageMedia()
    }

    Timer {
        id: viewportReloadTimer

        interval: 90
        repeat: false
        onTriggered: {
            stage.waitingForViewport = false
            stage.layoutGeneration += 1
            stage.scheduleMediaSwitch(true)
        }
    }

    component StageSurface: Item {
        id: surface

        property int surfaceIndex: 0
        property string mediaUrl: ""
        property bool isVideo: false
        property bool repeats: false
        property bool active: false
        property bool frameReady: false
        property int loadedGeneration: -1

        signal readyForCommit(int surfaceIndex)

        function completeReady() {
            if (!surface.frameReady) {
                surface.frameReady = true
                if (surface.isVideo && !surface.active)
                    surfacePlayer.pause()
            }
            surface.readyForCommit(surface.surfaceIndex)
        }

        function clearSurface() {
            surface.frameReady = false
            surface.mediaUrl = ""
            surface.isVideo = false
            surface.repeats = false
            surface.loadedGeneration = -1
            stillImage.source = ""
            surfacePlayer.stop()
            surfacePlayer.source = ""
            surfaceVideo.clearOutput()
        }

        function loadMedia(url, video, shouldRepeat, generation) {
            if (surface.mediaUrl === url && surface.isVideo === video && surface.loadedGeneration === generation) {
                surface.repeats = shouldRepeat
                if (surface.frameReady)
                    surface.readyForCommit(surface.surfaceIndex)
                return
            }

            surface.frameReady = false
            surface.mediaUrl = url
            surface.isVideo = video
            surface.repeats = shouldRepeat
            surface.loadedGeneration = generation

            if (url === "") {
                surface.clearSurface()
                return
            }

            if (video) {
                stillImage.source = ""
                surfaceVideo.clearOutput()
                surfacePlayer.source = url
                surfacePlayer.play()
            } else {
                surfacePlayer.stop()
                surfacePlayer.source = ""
                surfaceVideo.clearOutput()
                stillImage.source = url
                if (stillImage.status === Image.Ready)
                    surface.completeReady()
            }
        }

        function togglePlayback() {
            if (!surface.isVideo || surface.mediaUrl === "")
                return
            if (surfacePlayer.playbackState === MediaPlayer.PlayingState)
                surfacePlayer.pause()
            else
                surfacePlayer.play()
        }

        function restartPlayback() {
            if (!surface.isVideo || surface.mediaUrl === "")
                return
            surfacePlayer.setPosition(0)
            surfacePlayer.play()
        }

        anchors.fill: parent
        visible: surface.mediaUrl !== ""
        opacity: surface.active && surface.frameReady ? 1 : 0

        onActiveChanged: {
            if (!surface.isVideo || surface.mediaUrl === "")
                return
            if (surface.active)
                surfacePlayer.play()
            else if (surface.frameReady)
                surfacePlayer.pause()
        }

        Image {
            id: stillImage

            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            visible: !surface.isVideo && surface.frameReady

            onStatusChanged: {
                if (surface.isVideo || source.toString() !== surface.mediaUrl)
                    return
                if (status === Image.Ready || status === Image.Error)
                    surface.completeReady()
            }
        }

        MediaPlayer {
            id: surfacePlayer

            videoOutput: surfaceVideo
            audioOutput: AudioOutput {
                muted: !surface.active
            }
            autoPlay: false
            loops: surface.repeats ? MediaPlayer.Infinite : 1

            onSourceChanged: {
                if (source !== "")
                    play()
            }
        }

        VideoOutput {
            id: surfaceVideo

            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            endOfStreamPolicy: VideoOutput.KeepLastFrame
            visible: surface.isVideo
            opacity: surface.isVideo && surface.frameReady ? 1 : 0
        }

        Connections {
            target: surfaceVideo.videoSink

            function onVideoFrameChanged() {
                if (!surface.isVideo || surface.mediaUrl === "")
                    return
                if (surfacePlayer.source.toString() === surface.mediaUrl)
                    surface.completeReady()
            }
        }
    }

    StageSurface {
        id: surfaceA

        surfaceIndex: 0
        active: stage.activeSurfaceIndex === 0
        z: active ? 2 : 1
        onReadyForCommit: function(surfaceIndex) {
            stage.commitSurface(surfaceIndex)
        }
    }

    StageSurface {
        id: surfaceB

        surfaceIndex: 1
        active: stage.activeSurfaceIndex === 1
        z: active ? 2 : 1
        onReadyForCommit: function(surfaceIndex) {
            stage.commitSurface(surfaceIndex)
        }
    }

    Connections {
        target: stage.backend

        function onStageChanged() {
            stage.scheduleMediaSwitch(false)
        }

        function onScreenGeometryChanged() {
            if (!stage.visible)
                return
            stage.configureWindow()
        }

        function onStageVideoPauseRequested() {
            var activeSurface = stage.surfaceAt(stage.activeSurfaceIndex)
            activeSurface.togglePlayback()
        }

        function onStageVideoRestartRequested() {
            var activeSurface = stage.surfaceAt(stage.activeSurfaceIndex)
            activeSurface.restartPlayback()
        }
    }
}
