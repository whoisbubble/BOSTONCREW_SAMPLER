import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: timer

    property int seconds: 0
    property bool running: false

    function openTimer() {
        show()
        raise()
        requestActivate()
    }

    width: 330
    height: 188
    minimumWidth: 300
    minimumHeight: 170
    visible: false
    title: "BOSTONCREW SAMPLER / Timer"
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Tool

    Timer {
        interval: 1000
        running: timer.running
        repeat: true
        onTriggered: timer.seconds += 1
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: 18
        color: AppTheme.surface
        border.color: AppTheme.border
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: timer.startSystemMove()
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    AppIcon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        name: "clock"
                        lineColor: AppTheme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "BOSTONCREW SAMPLER / Timer"
                        color: AppTheme.text
                        font.family: AppTheme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    ChromeButton {
                        iconName: "close"
                        destructive: true
                        onClicked: timer.hide()
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    var h = Math.floor(timer.seconds / 3600)
                    var m = Math.floor((timer.seconds % 3600) / 60)
                    var s = timer.seconds % 60
                    return (h < 10 ? "0" : "") + h + ":" +
                        (m < 10 ? "0" : "") + m + ":" +
                        (s < 10 ? "0" : "") + s
                }
                color: AppTheme.text
                font.family: AppTheme.fontFamily
                font.pixelSize: 34
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                IconButton {
                    side: 34
                    iconSize: 17
                    iconName: "play"
                    tip: "Start"
                    accentFill: timer.running
                    onClicked: timer.running = true
                }

                IconButton {
                    side: 34
                    iconSize: 17
                    iconName: "pause"
                    tip: "Pause"
                    onClicked: timer.running = false
                }

                IconButton {
                    side: 34
                    iconSize: 17
                    iconName: "close"
                    tip: "Reset"
                    dangerFill: true
                    onClicked: {
                        timer.running = false
                        timer.seconds = 0
                    }
                }
            }
        }
    }
}
