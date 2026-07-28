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
    readonly property string requestedBackgroundUrl: stage.backend.stageActive ? stage.backend.currentBackgroundUrl : ""
    readonly property bool requestedBackgroundRepeats: stage.backend.stageActive && stage.backend.currentBackgroundRepeats

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
            activeSurface.backgroundRepeats = stage.requestedBackgroundRepeats
            return
        }

        var loadingIndex = stage.activeSurfaceIndex === 0 ? 1 : 0
        var loadingSurface = stage.surfaceAt(loadingIndex)
        loadingSurface.loadMedia(targetUrl, stage.requestedMediaIsVideo, stage.requestedMediaRepeats, stage.layoutGeneration, stage.requestedBackgroundUrl, stage.requestedBackgroundRepeats, stage.requestedMediaCrossfade)
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
        candidate.backgroundRepeats = stage.requestedBackgroundRepeats

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
        property bool mainReady: false
        property bool bgReady: false
        property int loadedGeneration: -1
        property string backgroundUrl: ""
        property bool backgroundRepeats: false

        signal readyForCommit(int surfaceIndex)

        function checkOverallReady() {
            if (surface.frameReady) return;
            var needsBg = surface.backgroundUrl !== "";
            var isBgReady = !needsBg || surface.bgReady;
            var needsMain = surface.mediaUrl !== "";
            var isMainReady = !needsMain || surface.mainReady;

            if (isBgReady && isMainReady) {
                surface.frameReady = true;
                if (surface.isVideo && !surface.active)
                    surfacePlayer.pause();
                
                var bgIsVideo = surface.backgroundUrl.match(/\.(mp4|avi|wmv|mov|mkv|webm)$/i);
                if (bgIsVideo && !surface.active)
                    bgPlayer.pause();

                surface.readyForCommit(surface.surfaceIndex);
            }
        }

        function clearSurface() {
            surface.frameReady = false
            surface.mainReady = false
            surface.bgReady = false
            surface.mediaUrl = ""
            surface.isVideo = false
            surface.repeats = false
            surface.backgroundUrl = ""
            surface.backgroundRepeats = false
            surface.loadedGeneration = -1
            stillImage.source = ""
            surfacePlayer.stop()
            surfacePlayer.source = ""
            bgStillImage.source = ""
            bgPlayer.stop()
            bgPlayer.source = ""
        }

        function loadMedia(url, video, shouldRepeat, generation, bgUrl, bgRepeats) {
            if (surface.mediaUrl === url && surface.isVideo === video && surface.loadedGeneration === generation) {
                surface.repeats = shouldRepeat
                surface.backgroundRepeats = bgRepeats
                if (surface.frameReady)
                    surface.readyForCommit(surface.surfaceIndex)
                return
            }

            surface.frameReady = false
            surface.mainReady = false
            surface.bgReady = false
            surface.mediaUrl = url
            surface.isVideo = video
            surface.repeats = shouldRepeat
            surface.backgroundUrl = bgUrl || ""
            surface.backgroundRepeats = bgRepeats || false
            surface.loadedGeneration = generation

            if (surface.backgroundUrl !== "") {
                var bgIsVideo = surface.backgroundUrl.match(/\.(mp4|avi|wmv|mov|mkv|webm)$/i)
                if (bgIsVideo) {
                    bgStillImage.source = ""
                    bgPlayer.source = surface.backgroundUrl
                    bgPlayer.play()
                } else {
                    bgPlayer.stop()
                    bgPlayer.source = ""
                    bgStillImage.source = surface.backgroundUrl
                    if (bgStillImage.status === Image.Ready || bgStillImage.status === Image.Error)
                        surface.bgReady = true
                }
            } else {
                surface.bgReady = true
                bgPlayer.stop()
                bgPlayer.source = ""
                bgStillImage.source = ""
            }

            if (url === "") {
                surface.clearSurface()
                return
            }

            if (video) {
                stillImage.source = ""
                surfacePlayer.source = url
                surfacePlayer.play()
            } else {
                surfacePlayer.stop()
                surfacePlayer.source = ""
                stillImage.source = url
                if (stillImage.status === Image.Ready || stillImage.status === Image.Error)
                    surface.mainReady = true
            }
            
            surface.checkOverallReady()
        }

        function togglePlayback() {
            if (surface.backgroundUrl !== "" && bgPlayer.source.toString() !== "") {
                if (bgPlayer.playbackState === MediaPlayer.PlayingState)
                    bgPlayer.pause()
                else
                    bgPlayer.play()
            }
            if (!surface.isVideo || surface.mediaUrl === "")
                return
            if (surfacePlayer.playbackState === MediaPlayer.PlayingState)
                surfacePlayer.pause()
            else
                surfacePlayer.play()
        }

        function restartPlayback() {
            if (surface.backgroundUrl !== "" && bgPlayer.source.toString() !== "") {
                bgPlayer.setPosition(0)
                bgPlayer.play()
            }
            if (!surface.isVideo || surface.mediaUrl === "")
                return
            surfacePlayer.setPosition(0)
            surfacePlayer.play()
        }

        anchors.fill: parent
        visible: surface.mediaUrl !== ""
        opacity: surface.active && surface.frameReady ? 1 : 0

        function applyActiveState() {
            if (surface.active) {
                if (surface.isVideo && surface.mediaUrl !== "") surfacePlayer.play()
                if (bgPlayer.source.toString() !== "") bgPlayer.play()
            } else if (surface.frameReady) {
                if (surface.isVideo) surfacePlayer.pause()
                if (bgPlayer.source.toString() !== "") bgPlayer.pause()
            }
        }

        onActiveChanged: applyActiveState()
        onFrameReadyChanged: applyActiveState()
        
        Image {
            id: bgStillImage

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            visible: surface.backgroundUrl !== "" && bgPlayer.source.toString() === ""

            onStatusChanged: {
                var bgIsVideo = surface.backgroundUrl.match(/\.(mp4|avi|wmv|mov|mkv|webm)$/i)
                if (bgIsVideo || source.toString() !== surface.backgroundUrl)
                    return
                if (status === Image.Ready || status === Image.Error) {
                    surface.bgReady = true
                    surface.checkOverallReady()
                }
            }
        }

        MediaPlayer {
            id: bgPlayer

            videoOutput: bgVideo
            audioOutput: AudioOutput {
                muted: !surface.active
            }
            loops: surface.backgroundRepeats ? MediaPlayer.Infinite : 1
            
            onSourceChanged: {
                if (source !== "")
                    play()
            }

            onPositionChanged: {
                if (!surface.backgroundRepeats && duration > 0 && playbackState === MediaPlayer.PlayingState) {
                    var bgThreshold = duration > 400 ? 150 : 50
                    if (position >= duration - bgThreshold) {
                        pause()
                    }
                }
            }

            onMediaStatusChanged: {
                if (mediaStatus === MediaPlayer.EndOfMedia && !surface.backgroundRepeats) {
                    pause()
                }
            }
        }

        VideoOutput {
            id: bgVideo

            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            visible: surface.backgroundUrl !== "" && bgPlayer.source.toString() !== ""
        }

        Connections {
            target: bgVideo.videoSink

            function onVideoFrameChanged() {
                var bgIsVideo = surface.backgroundUrl.match(/\.(mp4|avi|wmv|mov|mkv|webm)$/i)
                if (!bgIsVideo || surface.backgroundUrl === "")
                    return
                if (bgPlayer.source.toString() === surface.backgroundUrl) {
                    surface.bgReady = true
                    surface.checkOverallReady()
                }
            }
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
                if (status === Image.Ready || status === Image.Error) {
                    surface.mainReady = true
                    surface.checkOverallReady()
                }
            }
        }

        MediaPlayer {
            id: surfacePlayer

            videoOutput: surfaceVideo
            audioOutput: AudioOutput {
                muted: !surface.active
            }
            loops: surface.repeats ? MediaPlayer.Infinite : 1

            onSourceChanged: {
                if (source !== "")
                    play()
            }

            onPositionChanged: {
                if (surface.active && surface.isVideo) {
                    stage.backend.updateStageVideoTime(position, duration)
                }
                if (!surface.repeats && duration > 0 && playbackState === MediaPlayer.PlayingState) {
                    var mainThreshold = duration > 400 ? 150 : 50
                    if (position >= duration - mainThreshold) {
                        pause()
                    }
                }
            }

            onDurationChanged: {
                if (surface.active && surface.isVideo) {
                    stage.backend.updateStageVideoTime(position, duration)
                }
            }

            onMediaStatusChanged: {
                if (mediaStatus === MediaPlayer.EndOfMedia && !surface.repeats) {
                    pause()
                }
            }
        }

        VideoOutput {
            id: surfaceVideo

            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            visible: surface.isVideo
            opacity: surface.isVideo && surface.frameReady ? 1 : 0
        }

        Connections {
            target: surfaceVideo.videoSink

            function onVideoFrameChanged() {
                if (!surface.isVideo || surface.mediaUrl === "")
                    return
                if (surfacePlayer.source.toString() === surface.mediaUrl) {
                    surface.mainReady = true
                    surface.checkOverallReady()
                }
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
