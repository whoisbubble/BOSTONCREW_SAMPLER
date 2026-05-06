pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: manager

    required property var backend

    signal editSampleRequested(int index, string sampleName, real volume, bool stopSounds, var sampleColor)

    readonly property int columns: width > 760 ? 3 : (width > 480 ? 2 : 1)

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Samples"
                color: AppTheme.text
                font.family: AppTheme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            IconButton {
                side: 32
                iconSize: 16
                iconName: "plus"
                tip: "Add sample"
                onClicked: manager.backend.addSample()
            }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: Math.max(sampleFlow.height, height)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {}

            Flow {
                id: sampleFlow
                width: flick.width
                height: Math.max(childrenRect.height, flick.height)
                spacing: 10

                Repeater {
                    model: manager.backend.samples

                    delegate: Rectangle {
                        id: card

                        required property int index
                        required property string sampleName
                        required property string fileName
                        required property string durationText
                        required property bool isPlaying
                        required property color foreColor
                        required property real sampleVolume
                        required property bool sampleStopSounds

                        width: Math.max(190, (sampleFlow.width - sampleFlow.spacing * (manager.columns - 1)) / manager.columns)
                        height: 112
                        radius: AppTheme.tileRadius
                        color: cardHover.containsMouse ? AppTheme.tileHover : AppTheme.tile
                        border.width: 1
                        border.color: card.isPlaying ? AppTheme.accent : AppTheme.border
                        clip: true

                        Rectangle {
                            width: 5
                            radius: 3
                            color: card.foreColor
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 10
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: card.sampleName
                                color: AppTheme.text
                                font.family: AppTheme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.fileName === "" ? "No file" : card.fileName
                                color: AppTheme.muted
                                font.family: AppTheme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideMiddle
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 7

                                Text {
                                    text: card.durationText
                                    color: AppTheme.muted
                                    font.family: AppTheme.fontFamily
                                    font.pixelSize: 10
                                }

                                Rectangle {
                                    Layout.preferredWidth: 6
                                    Layout.preferredHeight: 6
                                    radius: 3
                                    color: card.sampleStopSounds ? AppTheme.warning : AppTheme.inputBorder
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: Math.round(card.sampleVolume * 100) + "%"
                                    color: AppTheme.muted
                                    font.family: AppTheme.fontFamily
                                    font.pixelSize: 10
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                IconButton {
                                    side: 30
                                    iconSize: 15
                                    iconName: card.isPlaying ? "stop" : "play"
                                    tip: card.isPlaying ? "Stop" : "Play"
                                    onClicked: card.isPlaying
                                        ? manager.backend.stopSample(card.index)
                                        : manager.backend.playSample(card.index, false)
                                }

                                IconButton {
                                    side: 30
                                    iconSize: 15
                                    iconName: "edit"
                                    tip: "Edit"
                                    onClicked: manager.editSampleRequested(
                                        card.index,
                                        card.sampleName,
                                        card.sampleVolume,
                                        card.sampleStopSounds,
                                        card.foreColor)
                                }

                                IconButton {
                                    side: 30
                                    iconSize: 15
                                    iconName: "file"
                                    tip: "File"
                                    onClicked: manager.backend.changeSampleFile(card.index)
                                }

                                IconButton {
                                    side: 30
                                    iconSize: 15
                                    iconName: "trash"
                                    tip: "Delete"
                                    dangerFill: true
                                    onClicked: manager.backend.deleteSample(card.index)
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }

                        MouseArea {
                            id: cardHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }
        }
    }
}
