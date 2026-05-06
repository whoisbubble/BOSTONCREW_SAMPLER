pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: dialog

    required property var backend

    property int sampleIndex: -1
    property string sampleName: ""
    property real sampleVolume: 1.0
    property bool sampleStopSounds: false
    property color sampleColor: "#d1495b"

    function openEditor(index, name, volume, stopSounds, colorValue) {
        sampleIndex = index
        sampleName = name
        sampleVolume = volume
        sampleStopSounds = stopSounds
        sampleColor = colorValue
        open()
    }

    modal: true
    focus: true
    width: Math.min(430, parent ? parent.width - 40 : 430)
    height: 374
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: AppModalOverlay {}

    background: AppPanel {
        padding: 0
        panelColor: AppTheme.surfaceRaised
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Sample"
            color: AppTheme.text
            font.family: AppTheme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        AppTextField {
            Layout.fillWidth: true
            text: dialog.sampleName
            placeholderText: "Name"
            onTextChanged: dialog.sampleName = text
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Volume"
                    color: AppTheme.muted
                    font.family: AppTheme.fontFamily
                    font.pixelSize: 11
                }

                Text {
                    text: Math.round(dialog.sampleVolume * 100) + "%"
                    color: AppTheme.text
                    font.family: AppTheme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Item {
                id: volumeSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                function setVolumeFromX(pixel) {
                    dialog.sampleVolume = Math.max(0, Math.min(1, pixel / Math.max(1, track.width)))
                }

                Rectangle {
                    id: track
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    color: AppTheme.inputBackground
                    border.color: AppTheme.inputBorder
                    border.width: 1

                    Rectangle {
                        width: dialog.sampleVolume * parent.width
                        height: parent.height
                        radius: 3
                        color: AppTheme.accent
                    }
                }

                Rectangle {
                    id: handle
                    x: Math.max(0, Math.min(parent.width - width, dialog.sampleVolume * (parent.width - width)))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: sliderMouse.pressed || sliderMouse.containsMouse ? AppTheme.text : AppTheme.muted
                    border.color: sliderMouse.pressed || sliderMouse.containsMouse ? AppTheme.accentHover : AppTheme.accent
                    border.width: 1
                }

                MouseArea {
                    id: sliderMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(mouse) { volumeSlider.setVolumeFromX(mouse.x) }
                    onPositionChanged: function(mouse) {
                        if (pressed)
                            volumeSlider.setVolumeFromX(mouse.x)
                    }
                }
            }
        }

        AppCheckBox {
            id: stopSoundsCheck
            text: "Stop other sounds"
            checked: dialog.sampleStopSounds
            onToggled: dialog.sampleStopSounds = stopSoundsCheck.checked
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: ["#d1495b", "#f5e9eb", "#8b1e2d", "#ff4d5e", "#d69e2e", "#2f9e73"]

                delegate: Rectangle {
                    id: colorChip

                    required property string modelData

                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: colorChip.modelData
                    border.width: dialog.sampleColor === colorChip.modelData ? 3 : 1
                    border.color: dialog.sampleColor === colorChip.modelData ? AppTheme.text : AppTheme.border

                    MouseArea {
                        anchors.fill: parent
                        onClicked: dialog.sampleColor = colorChip.modelData
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                side: 32
                iconSize: 16
                iconName: "file"
                tip: "File"
                onClicked: dialog.backend.changeSampleFile(dialog.sampleIndex)
            }

            IconButton {
                side: 32
                iconSize: 16
                iconName: "trash"
                tip: "Delete"
                dangerFill: true
                onClicked: {
                    dialog.backend.deleteSample(dialog.sampleIndex)
                    dialog.close()
                }
            }

            Item { Layout.fillWidth: true }

            TextButton {
                text: "Cancel"
                onClicked: dialog.close()
            }

            TextButton {
                text: "Save"
                accentFill: true
                onClicked: {
                    dialog.backend.updateSample(
                        dialog.sampleIndex,
                        dialog.sampleName,
                        dialog.sampleVolume,
                        dialog.sampleStopSounds,
                        dialog.sampleColor)
                    dialog.close()
                }
            }
        }
    }
}
