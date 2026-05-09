pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AppPanel {
    id: panel

    required property var backend
    property bool timerRunning: false

    signal assignQuickSlotRequested(int index)
    signal timerRequested()
    signal managerRequested()

    padding: 0
    panelColor: AppTheme.surface

    Rectangle {
        id: slotSurface
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 0
        height: Math.max(132, parent.height - 54)
        radius: 10
        color: AppTheme.inputBackground
        border.color: AppTheme.border
        border.width: 1
        clip: true

        GridLayout {
            anchors.centerIn: parent
            width: 184
            height: 132
            columns: 4
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: panel.backend.quickSlides

                delegate: Rectangle {
                    id: quickTile

                    required property int index
                    required property string folderName
                    required property bool isDefault
                    required property bool hasSample

                    readonly property bool active: panel.backend.stageActive
                        && panel.backend.currentSlideIndex === quickTile.index
                    readonly property bool available: panel.backend.quickSlideAvailable(quickTile.index)

                    visible: quickTile.index < 12
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    opacity: quickTile.available ? 1.0 : 0.38
                    radius: 7
                    color: quickMouse.pressed
                        ? AppTheme.tilePressed
                        : (quickTile.active
                            ? AppTheme.primary
                            : (quickMouse.containsMouse ? AppTheme.tileHover : AppTheme.tile))
                    border.width: 1
                    border.color: quickTile.active ? AppTheme.accent : AppTheme.border
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.margins: 4
                        text: quickTile.available
                            ? (quickTile.isDefault ? String(quickTile.index + 1) : quickTile.folderName)
                            : "LOCK"
                        color: AppTheme.text
                        font.family: AppTheme.fontFamily
                        font.pixelSize: !quickTile.available ? 8 : (quickTile.isDefault ? 15 : 8)
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        visible: !quickTile.isDefault && quickTile.hasSample
                        width: 5
                        height: 5
                        radius: 3
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 4
                        anchors.bottomMargin: 4
                        color: AppTheme.warning
                    }

                    MouseArea {
                        id: quickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton || panel.backend.settingsMode) {
                                if (quickTile.available)
                                    panel.assignQuickSlotRequested(quickTile.index)
                                else
                                    panel.backend.playQuickSlide(quickTile.index)
                                return
                            }

                            panel.backend.playQuickSlide(quickTile.index)
                        }
                    }

                    ToolTip.visible: quickMouse.containsMouse
                    ToolTip.delay: 650
                    ToolTip.timeout: 6500
                    ToolTip.text: "Left: open slide\nRight: assign slide"
                }
            }
        }

        IconButton {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7
            iconSource: "qrc:/assets/icons/slides.svg"
            showChrome: false
            side: 24
            iconSize: 15
            tip: "Open slides manager"
            onClicked: panel.managerRequested()
        }
    }

    Row {
        id: controlRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7
        height: 34
        spacing: 5

        IconButton {
            width: 34
            height: 34
            iconSource: "qrc:/assets/icons/play.svg"
            side: 34
            iconSize: 18
            tip: "P1 sound\nRight: sound + next media"
            onClicked: function(mouse) { panel.backend.playFixedSample(0, mouse.button === Qt.RightButton) }
        }

        IconButton {
            width: 34
            height: 34
            iconSource: "qrc:/assets/icons/thumb-up.svg"
            side: 34
            iconSize: 18
            tip: "OK sound\nRight: sound + next media"
            onClicked: function(mouse) { panel.backend.playFixedSample(1, mouse.button === Qt.RightButton) }
        }

        IconButton {
            width: 34
            height: 34
            iconSource: "qrc:/assets/icons/thumb-down.svg"
            side: 34
            iconSize: 18
            tip: "NO sound\nRight: sound + next media"
            onClicked: function(mouse) { panel.backend.playFixedSample(2, mouse.button === Qt.RightButton) }
        }

        IconButton {
            width: 34
            height: 34
            iconSource: "qrc:/assets/icons/timer.svg"
            accentFill: panel.timerRunning
            side: 34
            iconSize: 18
            tip: "Timer sound\nMiddle: open timer\nRight: sound + next media"
            onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton) {
                    panel.timerRequested()
                    return
                }

                panel.backend.playFixedSample(3, mouse.button === Qt.RightButton)
            }
        }

        IconButton {
            width: 34
            height: 34
            iconSource: panel.backend.audioPaused
                ? "qrc:/assets/icons/play.svg"
                : "qrc:/assets/icons/pause.svg"
            accentFill: panel.backend.audioPaused
            side: 34
            iconSize: 18
            tip: panel.backend.audioPaused ? "Resume all sounds" : "Pause all sounds"
            onClicked: panel.backend.togglePause()
        }

        IconButton {
            width: 34
            height: 34
            iconSource: "qrc:/assets/icons/stop.svg"
            dangerFill: true
            side: 34
            iconSize: 18
            tip: "Stop all sounds"
            onClicked: panel.backend.stopAllSamples()
        }
    }
}
