import QtQuick
import QtQuick.Window
import QtMultimedia

Window {
    id: stage

    required property var backend
    property real ownerX: 0
    property real ownerY: 0
    property bool videoFrameReady: false
    property string lastStillUrl: ""
    readonly property string activeVideoUrl: stage.backend.currentMediaIsVideo ? stage.backend.currentMediaUrl : ""

    onActiveVideoUrlChanged: {
        videoFrameReady = false
        if (activeVideoUrl === "") {
            stagePlayer.stop()
            stageVideo.clearOutput()
        } else {
            stagePlayer.play()
        }
    }

    visible: stage.backend.stageActive
    x: stage.backend.hasSecondScreen() ? stage.backend.stageX : Math.max(40, stage.ownerX + 40)
    y: stage.backend.hasSecondScreen() ? stage.backend.stageY : Math.max(40, stage.ownerY + 40)
    width: stage.backend.hasSecondScreen() ? stage.backend.stageWidth : 960
    height: stage.backend.hasSecondScreen() ? stage.backend.stageHeight : 540
    minimumWidth: 640
    minimumHeight: 360
    title: "BOSTONCREW SAMPLER / Stage"
    color: "black"
    flags: Qt.Window

    onClosing: function() {
        stage.backend.closeStage()
    }

    onVisibleChanged: {
        if (!visible)
            return

        if (stage.backend.hasSecondScreen()) {
            x = stage.backend.stageX
            y = stage.backend.stageY
            width = stage.backend.stageWidth
            height = stage.backend.stageHeight
            showFullScreen()
        } else {
            x = Math.max(40, stage.ownerX + 40)
            y = Math.max(40, stage.ownerY + 40)
            width = 960
            height = 540
            showNormal()
            raise()
            requestActivate()
        }
    }

    Image {
        anchors.fill: parent
        source: !stage.backend.currentMediaIsVideo
            ? stage.backend.currentMediaUrl
            : (stage.videoFrameReady ? "" : stage.lastStillUrl)
        fillMode: Image.PreserveAspectFit
        visible: source !== ""
        onSourceChanged: {
            if (!stage.backend.currentMediaIsVideo && source !== "")
                stage.lastStillUrl = source
        }
    }

    MediaPlayer {
        id: stagePlayer
        source: stage.activeVideoUrl
        videoOutput: stageVideo
        audioOutput: AudioOutput {}
        autoPlay: false
        loops: stage.backend.currentMediaRepeats ? MediaPlayer.Infinite : 1
        onSourceChanged: {
            stage.videoFrameReady = false
            if (source !== "")
                play()
        }
    }

    VideoOutput {
        id: stageVideo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        endOfStreamPolicy: VideoOutput.KeepLastFrame
        visible: stage.backend.currentMediaIsVideo
        opacity: stage.videoFrameReady ? 1 : 0
    }

    Connections {
        target: stageVideo.videoSink

        function onVideoFrameChanged() {
            if (stage.activeVideoUrl !== "")
                stage.videoFrameReady = true
        }
    }

    Connections {
        target: stage.backend

        function onStageChanged() {
            if (!stage.backend.currentMediaIsVideo && stage.backend.currentMediaUrl !== "")
                stage.lastStillUrl = stage.backend.currentMediaUrl
        }

        function onStageVideoPauseRequested() {
            if (!stage.backend.currentMediaIsVideo)
                return
            if (stagePlayer.playbackState === MediaPlayer.PlayingState)
                stagePlayer.pause()
            else
                stagePlayer.play()
        }

        function onStageVideoRestartRequested() {
            if (!stage.backend.currentMediaIsVideo)
                return
            stagePlayer.setPosition(0)
            stagePlayer.play()
        }
    }
}
