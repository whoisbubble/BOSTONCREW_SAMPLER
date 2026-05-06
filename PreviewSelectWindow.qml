import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: previewWindow

    required property var backend
    property real ownerX: 0
    property real ownerY: 0

    function openPreview() {
        x = Math.max(40, ownerX + 64)
        y = Math.max(40, ownerY + 92)
        show()
        raise()
        requestActivate()
    }

    width: 620
    height: 320
    minimumWidth: 460
    minimumHeight: 260
    visible: false
    title: "BOSTONCREW SAMPLER / Slide selection"
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
            anchors.margins: 8
            spacing: 8

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    acceptedButtons: Qt.LeftButton
                    onPressed: previewWindow.startSystemMove()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BOSTONCREW SAMPLER / Cue"
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
                    onClicked: previewWindow.hide()
                }
            }

            AppPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 0
                panelColor: AppTheme.surface

                PreviewWorkspace {
                    anchors.fill: parent
                    backend: previewWindow.backend
                }
            }
        }
    }

    WindowResizeHandle {
        edge: Qt.RightEdge
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: thickness
    }

    WindowResizeHandle {
        edge: Qt.BottomEdge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: thickness
    }

    WindowResizeHandle {
        edge: Qt.RightEdge | Qt.BottomEdge
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: thickness + 6
        height: thickness + 6
    }
}
