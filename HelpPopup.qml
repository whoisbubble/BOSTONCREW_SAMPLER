pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: popup

    modal: true
    focus: true
    width: Math.min(560, parent ? parent.width - 40 : 560)
    height: Math.min(520, parent ? parent.height - 60 : 520)
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: AppModalOverlay {}

    background: AppPanel {
        padding: 0
        panelColor: AppTheme.surfaceRaised
    }

    component SectionTitle: Text {
        Layout.fillWidth: true
        color: AppTheme.text
        font.family: AppTheme.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    component ShortcutRow: RowLayout {
        id: shortcutRow

        property string keys: ""
        property string detail: ""

        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 132
            Layout.minimumWidth: 112
            Layout.preferredHeight: 28
            radius: 7
            color: AppTheme.inputBackground
            border.color: AppTheme.inputBorder
            border.width: 1

            Text {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                text: shortcutRow.keys
                color: AppTheme.accent
                font.family: AppTheme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.fillWidth: true
            text: shortcutRow.detail
            color: AppTheme.muted
            font.family: AppTheme.fontFamily
            font.pixelSize: 11
            lineHeight: 1.12
            wrapMode: Text.WordWrap
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 10

            AppIcon {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                name: "help"
                lineColor: AppTheme.accent
            }

            Text {
                Layout.fillWidth: true
                text: "Quick help"
                color: AppTheme.text
                font.family: AppTheme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            IconButton {
                side: 32
                iconSize: 16
                iconName: "close"
                tip: "Close"
                dangerFill: true
                onClicked: popup.close()
            }
        }

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn

                width: flick.width
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: quickColumn.implicitHeight + 20
                    radius: AppTheme.tileRadius
                    color: AppTheme.surface
                    border.color: AppTheme.border
                    border.width: 1

                    ColumnLayout {
                        id: quickColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        SectionTitle { text: "Main panel" }
                        ShortcutRow {
                            keys: "Quick slots"
                            detail: "Left click opens the slide. Right click assigns another slide to that slot."
                        }
                        ShortcutRow {
                            keys: "Fixed sounds"
                            detail: "Left click plays the sound. Right click plays it and moves the stage media forward."
                        }
                        ShortcutRow {
                            keys: "Timer button"
                            detail: "Middle click opens the timer window. Left/right click still works as a fixed sound."
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: samplesColumn.implicitHeight + 20
                    radius: AppTheme.tileRadius
                    color: AppTheme.surface
                    border.color: AppTheme.border
                    border.width: 1

                    ColumnLayout {
                        id: samplesColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        SectionTitle { text: "Samples" }
                        ShortcutRow {
                            keys: "Sample tile"
                            detail: "Left click plays. Right click plays and moves the stage media forward."
                        }
                        ShortcutRow {
                            keys: "Settings"
                            detail: "Turn on edit mode, then click a sample to rename it, change volume, color, or file."
                        }
                        ShortcutRow {
                            keys: "Shift + click"
                            detail: "Click the first sample, then the target sample, to move it in the grid."
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: cueColumn.implicitHeight + 20
                    radius: AppTheme.tileRadius
                    color: AppTheme.surface
                    border.color: AppTheme.border
                    border.width: 1

                    ColumnLayout {
                        id: cueColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        SectionTitle { text: "Cue window" }
                        ShortcutRow {
                            keys: "Left click"
                            detail: "Shows selected media and plays the first regular sample."
                        }
                        ShortcutRow {
                            keys: "Right click"
                            detail: "Shows selected media and plays the OK fixed sound."
                        }
                        ShortcutRow {
                            keys: "Wheel click"
                            detail: "Shows only the selected media without an extra sound."
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: slidesColumn.implicitHeight + 20
                    radius: AppTheme.tileRadius
                    color: AppTheme.surface
                    border.color: AppTheme.border
                    border.width: 1

                    ColumnLayout {
                        id: slidesColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        SectionTitle { text: "Slides manager" }
                        ShortcutRow {
                            keys: "Audio button"
                            detail: "Left click assigns a cue sound to media. Right click removes the assigned cue."
                        }
                        ShortcutRow {
                            keys: "Repeat"
                            detail: "Available for video media; it toggles loop playback on the stage."
                        }
                        ShortcutRow {
                            keys: "Mouse wheel"
                            detail: "Scrolls long sample, slide, and cue lists."
                        }
                    }
                }
            }
        }
    }
}
