import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: manager

    required property var backend
    property real ownerX: 0
    property real ownerY: 0

    function openManager() {
        x = Math.max(40, ownerX + 48)
        y = Math.max(40, ownerY + 48)
        show()
        raise()
        requestActivate()
    }

    width: 760
    height: 520
    minimumWidth: 620
    minimumHeight: 430
    visible: false
    title: "BOSTONCREW SAMPLER / Slides"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    Rectangle {
        id: shell
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
                    onPressed: manager.startSystemMove()
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BOSTONCREW SAMPLER / Slides"
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
                    onClicked: manager.hide()
                }
            }

            AppPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 10
                panelColor: AppTheme.surface

                SlideLibrary {
                    anchors.fill: parent
                    backend: manager.backend
                    onEditSlideRequested: function(index, folderName, slideType) {
                        slideDialog.openEditor(index, folderName, slideType)
                    }
                }
            }
        }
    }

    SlideDialog {
        id: slideDialog
        parent: shell
        backend: manager.backend
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
