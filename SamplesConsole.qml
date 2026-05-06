pragma ComponentBehavior: Bound

import QtQuick

AppPanel {
    id: samplerConsole

    required property var backend
    property int moveFromIndex: -1

    signal editSampleRequested(int index, string sampleName, real volume, bool stopSounds, var sampleColor)
    signal editSlideRequested(int index, string folderName, string slideType)

    padding: 0
    panelColor: AppTheme.surface

    Rectangle {
        id: sampleSurface
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.bottomMargin: 4
        radius: 10
        color: AppTheme.inputBackground
        border.color: AppTheme.border
        border.width: 1
        clip: true

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 8
            contentWidth: width
            contentHeight: Math.max(sampleFlow.childrenRect.height, height)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Flow {
                id: sampleFlow
                width: flick.width
                height: childrenRect.height
                spacing: 10

                Repeater {
                    model: samplerConsole.backend.samples

                    delegate: Rectangle {
                        id: sampleTile

                        required property int index
                        required property string sampleName
                        required property bool isPlaying
                        required property color foreColor
                        required property real sampleVolume
                        required property bool sampleStopSounds

                        width: 52
                        height: 52
                        radius: 8
                        color: sampleMouse.pressed
                            ? AppTheme.tilePressed
                            : (sampleTile.isPlaying
                                ? AppTheme.primary
                                : (sampleMouse.containsMouse ? AppTheme.tileHover : AppTheme.tile))
                        border.width: samplerConsole.moveFromIndex === sampleTile.index ? 2 : 1
                        border.color: samplerConsole.moveFromIndex === sampleTile.index
                            ? AppTheme.success
                            : (sampleTile.isPlaying ? AppTheme.accent : sampleTile.foreColor)
                        clip: true

                        Text {
                            anchors.fill: parent
                            anchors.margins: 5
                            text: sampleTile.sampleName
                            color: sampleTile.foreColor
                            font.family: AppTheme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            wrapMode: Text.Wrap
                        }

                        Rectangle {
                            visible: sampleTile.sampleStopSounds
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 5
                            width: 6
                            height: 6
                            radius: 3
                            color: AppTheme.warning
                        }

                        MouseArea {
                            id: sampleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.modifiers & Qt.ShiftModifier) {
                                    if (samplerConsole.moveFromIndex < 0) {
                                        samplerConsole.moveFromIndex = sampleTile.index
                                    } else {
                                        samplerConsole.backend.moveSample(samplerConsole.moveFromIndex, sampleTile.index)
                                        samplerConsole.moveFromIndex = -1
                                    }
                                    return
                                }

                                samplerConsole.moveFromIndex = -1
                                if (samplerConsole.backend.settingsMode) {
                                    samplerConsole.editSampleRequested(
                                        sampleTile.index,
                                        sampleTile.sampleName,
                                        sampleTile.sampleVolume,
                                        sampleTile.sampleStopSounds,
                                        sampleTile.foreColor)
                                    return
                                }

                                samplerConsole.backend.playSample(sampleTile.index, mouse.button === Qt.RightButton)
                            }
                        }
                    }
                }

                Rectangle {
                    width: 52
                    height: 52
                    radius: 8
                    color: addMouse.pressed
                        ? AppTheme.tilePressed
                        : (addMouse.containsMouse ? AppTheme.tileHover : AppTheme.tile)
                    border.color: AppTheme.border
                    border.width: 1

                    Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: "qrc:/assets/icons/plus.svg"
                        sourceSize.width: 22
                        sourceSize.height: 22
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: samplerConsole.backend.addSample()
                    }
                }

                Rectangle {
                    width: 52
                    height: 52
                    radius: 8
                    color: settingsMouse.pressed
                        ? AppTheme.tilePressed
                        : (settingsMouse.containsMouse ? AppTheme.tileHover : AppTheme.tile)
                    border.color: samplerConsole.backend.settingsMode ? AppTheme.accent : AppTheme.border
                    border.width: 1

                    Image {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        source: "qrc:/assets/icons/settings.svg"
                        sourceSize.width: 22
                        sourceSize.height: 22
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 5
                        width: 7
                        height: 7
                        radius: 4
                        color: samplerConsole.backend.settingsMode ? AppTheme.success : AppTheme.muted
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: samplerConsole.backend.settingsMode = !samplerConsole.backend.settingsMode
                    }
                }
            }
        }
    }

    Item {
        id: statusRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        height: 22

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 4
            color: samplerConsole.backend.connected ? AppTheme.success : AppTheme.muted
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: modeText.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: samplerConsole.backend.statusMessage !== ""
                ? samplerConsole.backend.statusMessage
                : (samplerConsole.backend.stageActive ? "Stage active" : "Ready")
            color: AppTheme.muted
            font.family: AppTheme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        Text {
            id: modeText
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: samplerConsole.backend.settingsMode ? "EDIT" : "LIVE"
            color: samplerConsole.backend.settingsMode ? AppTheme.accent : AppTheme.muted
            font.family: AppTheme.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }
}
