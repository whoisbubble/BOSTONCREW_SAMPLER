pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ListView {
    id: strip

    required property var backend

    signal editSampleRequested(int index, string sampleName, real volume, bool stopSounds, var sampleColor)

    orientation: ListView.Horizontal
    spacing: 10
    clip: true
    model: strip.backend.samples
    boundsBehavior: Flickable.StopAtBounds

    delegate: Rectangle {
        id: chip

        required property int index
        required property string sampleName
        required property bool isPlaying
        required property color foreColor
        required property real sampleVolume
        required property bool sampleStopSounds

        width: 118
        height: Math.max(46, strip.height - 2)
        radius: AppTheme.tileRadius
        color: chipMouse.pressed
            ? AppTheme.tilePressed
            : (chip.isPlaying
                ? AppTheme.primary
                : (chipMouse.containsMouse ? AppTheme.tileHover : AppTheme.tile))
        border.width: 1
        border.color: chip.isPlaying ? AppTheme.accent : AppTheme.border
        clip: true

        Rectangle {
            width: 5
            height: parent.height - 18
            radius: 3
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            color: chip.foreColor
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 9
            anchors.topMargin: 7
            anchors.bottomMargin: 7
            text: chip.sampleName
            color: AppTheme.text
            font.family: AppTheme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (strip.backend.settingsMode) {
                    strip.editSampleRequested(
                        chip.index,
                        chip.sampleName,
                        chip.sampleVolume,
                        chip.sampleStopSounds,
                        chip.foreColor)
                    return
                }

                strip.backend.playSample(chip.index, mouse.button === Qt.RightButton)
            }
        }

        ToolTip.visible: chipMouse.containsMouse
        ToolTip.delay: 650
        ToolTip.timeout: 6500
        ToolTip.text: strip.backend.settingsMode
            ? "Edit mode: click to edit sample"
            : "Left: play sample\nRight: play + next media"
    }
}
