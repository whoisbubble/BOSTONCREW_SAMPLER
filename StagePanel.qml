pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia

AppPanel {
    id: panel

    required property var backend
    property bool showNextPreview: false
    property bool previewVideoReady: false
    signal previewRequested()

    readonly property string previewUrl: showNextPreview && backend.nextMediaUrl !== ""
        ? backend.nextMediaUrl
        : backend.currentMediaUrl
    readonly property string previewLower: previewUrl.toString().toLowerCase()
    readonly property bool previewIsVideo: previewLower.endsWith(".mp4")
        || previewLower.endsWith(".mov")
        || previewLower.endsWith(".avi")
        || previewLower.endsWith(".mkv")
        || previewLower.endsWith(".webm")
    readonly property string activePreviewVideoUrl: previewIsVideo ? previewUrl : ""

    onActivePreviewVideoUrlChanged: {
        previewVideoReady = false
        if (activePreviewVideoUrl === "") {
            previewPlayer.stop()
            previewVideo.clearOutput()
        } else {
            previewPlayer.play()
        }
    }

    padding: 0
    panelColor: AppTheme.surface

    Rectangle {
        id: previewFrame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        width: Math.min(150, parent.width - 28)
        height: Math.min(90, Math.max(58, parent.height - 70))
        radius: 11
        color: AppTheme.inputBackground
        border.color: AppTheme.inputBorder
        border.width: 2
        clip: true

        AppIcon {
            anchors.centerIn: parent
            width: 28
            height: 28
            name: panel.previewIsVideo ? "play" : "image"
            lineColor: AppTheme.alpha(AppTheme.muted, 0.55)
            visible: panel.previewUrl === "" || (panel.previewIsVideo && !panel.previewVideoReady)
        }

        Image {
            anchors.fill: parent
            anchors.margins: 4
            source: !panel.previewIsVideo ? panel.previewUrl : ""
            fillMode: Image.PreserveAspectFit
            visible: source !== ""
        }

        MediaPlayer {
            id: previewPlayer
            source: panel.activePreviewVideoUrl
            videoOutput: previewVideo
            audioOutput: AudioOutput { muted: true }
            autoPlay: false
            loops: panel.backend.currentMediaRepeats ? MediaPlayer.Infinite : 1
            onSourceChanged: {
                panel.previewVideoReady = false
                if (source !== "")
                    play()
            }
        }

        VideoOutput {
            id: previewVideo
            anchors.fill: parent
            anchors.margins: 4
            fillMode: VideoOutput.PreserveAspectFit
            endOfStreamPolicy: VideoOutput.KeepLastFrame
            visible: panel.previewIsVideo
            opacity: panel.previewVideoReady ? 1 : 0
        }

        Connections {
            target: previewVideo.videoSink

            function onVideoFrameChanged() {
                if (panel.activePreviewVideoUrl !== "")
                    panel.previewVideoReady = true
            }
        }
    }

    Row {
        id: previewControls
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7
        height: 36
        spacing: 7

        IconButton {
            iconSource: "qrc:/assets/icons/prev.svg"
            width: 34
            height: 34
            side: 34
            iconSize: 18
            onClicked: panel.backend.previousSlide()
        }

        IconButton {
            iconSource: "qrc:/assets/icons/next.svg"
            width: 34
            height: 34
            side: 34
            iconSize: 18
            onClicked: panel.backend.nextSlide()
        }

        Rectangle {
            width: 58
            height: 34
            radius: 9
            color: AppTheme.tile
            border.color: AppTheme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: panel.backend.slideCounterText !== "" ? panel.backend.slideCounterText : "--"
                color: AppTheme.text
                font.family: AppTheme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        IconButton {
            iconSource: "qrc:/assets/icons/cue.svg"
            width: 34
            height: 34
            side: 34
            iconSize: 18
            onClicked: panel.previewRequested()
        }

        Rectangle {
            width: 54
            height: 34
            radius: 9
            color: previewToggleMouse.pressed
                ? AppTheme.tilePressed
                : (previewToggleMouse.containsMouse ? AppTheme.tileHover : AppTheme.tile)
            border.color: panel.showNextPreview ? AppTheme.accent : AppTheme.border
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: panel.showNextPreview ? "NEXT" : "CUR"
                color: panel.showNextPreview ? AppTheme.text : AppTheme.muted
                font.family: AppTheme.fontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: previewToggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.showNextPreview = !panel.showNextPreview
            }
        }
    }
}
