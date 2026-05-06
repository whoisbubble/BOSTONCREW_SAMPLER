import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: remoteWindow

    required property var backend
    property real ownerX: 0
    property real ownerY: 0

    function openRemote() {
        x = Math.max(40, ownerX + 92)
        y = Math.max(40, ownerY + 92)
        show()
        raise()
        requestActivate()
    }

    width: 340
    height: 174
    minimumWidth: 300
    minimumHeight: 150
    visible: false
    title: "BOSTONCREW SAMPLER / Remote"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: AppTheme.shellRadius
        color: AppTheme.background
        border.color: AppTheme.border
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    acceptedButtons: Qt.LeftButton
                    onPressed: remoteWindow.startSystemMove()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BOSTONCREW SAMPLER / Remote"
                    color: AppTheme.text
                    font.family: AppTheme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                ChromeButton {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "close"
                    destructive: true
                    onClicked: remoteWindow.hide()
                }
            }

            AppPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 12
                panelColor: AppTheme.surface

                RowLayout {
                    anchors.fill: parent
                    spacing: 12

                    IconButton {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        side: 46
                        iconName: "pause"
                        enabled: remoteWindow.backend.stageActive && remoteWindow.backend.currentMediaIsVideo
                        accentFill: true
                        onClicked: remoteWindow.backend.toggleStageVideoPause()
                    }

                    IconButton {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        side: 46
                        iconName: "restart"
                        enabled: remoteWindow.backend.stageActive && remoteWindow.backend.currentMediaIsVideo
                        onClicked: remoteWindow.backend.restartStageVideo()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: remoteWindow.backend.currentMediaIsVideo ? "Video control" : "No active video"
                            color: remoteWindow.backend.currentMediaIsVideo ? AppTheme.text : AppTheme.muted
                            font.family: AppTheme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: remoteWindow.backend.currentMediaIsVideo
                                ? (remoteWindow.backend.currentMediaRepeats ? "Loop enabled" : "Last frame hold")
                                : (remoteWindow.backend.stageActive ? "Current media is not video" : "Stage is closed")
                            color: AppTheme.muted
                            font.family: AppTheme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
