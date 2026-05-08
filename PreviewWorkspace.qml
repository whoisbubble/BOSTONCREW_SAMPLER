pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: workspace

    required property var backend

    readonly property int gridGap: 10
    readonly property int columnCount: Math.max(3, Math.floor((width - 28 + gridGap) / 148))
    readonly property int tileWidth: Math.max(116, Math.min(146, Math.floor((width - 28 - ((columnCount - 1) * gridGap)) / columnCount)))
    readonly property int previewHeight: Math.round(tileWidth * 9 / 16)
    readonly property int tileHeight: previewHeight + 28

    Flickable {
        id: previewFlick

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 18
        anchors.topMargin: 14
        anchors.bottomMargin: statusLine.visible ? 34 : 14
        clip: true
        visible: workspace.backend.stageActive && previewRepeater.count > 0
        contentWidth: width
        contentHeight: Math.max(height, previewGrid.childrenRect.height)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Flow {
            id: previewGrid

            width: previewFlick.width
            height: childrenRect.height
            spacing: workspace.gridGap

            Repeater {
                id: previewRepeater

                model: workspace.backend.previewItems

                delegate: Rectangle {
                    id: tile

                    required property int index
                    required property string fileName
                    required property string fileUrl
                    required property bool isVideo
                    required property bool isCurrent
                    required property bool isDimmed

                    property bool localDimmed: false
                    readonly property bool seen: tile.isDimmed || tile.localDimmed

                    width: workspace.tileWidth
                    height: workspace.tileHeight
                    radius: AppTheme.tileRadius
                    color: tileMouse.pressed
                        ? AppTheme.tilePressed
                        : (tileMouse.containsMouse ? AppTheme.tileHover : AppTheme.tile)
                    border.width: tile.seen ? 2 : 1
                    border.color: tile.seen ? AppTheme.success : (tile.isCurrent ? AppTheme.accent : AppTheme.border)
                    clip: true

                    Rectangle {
                        id: previewFrame

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: workspace.previewHeight
                        color: AppTheme.inputBackground

                        Image {
                            anchors.fill: parent
                            source: tile.isVideo ? "" : tile.fileUrl
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: Math.max(width * 1.5, 160)
                            sourceSize.height: Math.max(height * 1.5, 90)
                            asynchronous: true
                            visible: source !== ""
                        }

                        AppIcon {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            visible: tile.isVideo || tile.fileUrl === ""
                            name: tile.isVideo ? "play" : "image"
                            lineColor: AppTheme.muted
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.44)
                            visible: tile.seen || tileMouse.pressed
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 6
                            width: 22
                            height: 18
                            radius: 5
                            color: tile.seen ? AppTheme.success : AppTheme.alpha(AppTheme.background, 0.72)
                            border.color: tile.seen ? AppTheme.success : (tile.isCurrent ? AppTheme.accent : AppTheme.alpha(AppTheme.border, 0.55))

                            Text {
                                anchors.centerIn: parent
                                text: tile.index + 1
                                color: tile.seen ? "#06170f" : (tile.isCurrent ? AppTheme.accent : AppTheme.text)
                                font.family: AppTheme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 28
                        text: tile.fileName
                        color: tile.seen ? AppTheme.success : AppTheme.text
                        font.family: AppTheme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: tileMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            tile.localDimmed = true
                            if (mouse.button === Qt.LeftButton)
                                workspace.backend.playPreviewMedia(tile.index, 1)
                            else if (mouse.button === Qt.RightButton)
                                workspace.backend.playPreviewMedia(tile.index, 2)
                            else
                                workspace.backend.playPreviewMedia(tile.index, 0)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 7
        width: 3
        height: previewFlick.visible && previewFlick.contentHeight > previewFlick.height
            ? Math.max(28, previewFlick.height * previewFlick.height / previewFlick.contentHeight)
            : 0
        radius: 2
        color: AppTheme.alpha(AppTheme.accent, 0.58)
        y: previewFlick.y + (previewFlick.visible && previewFlick.contentHeight > previewFlick.height
            ? previewFlick.contentY * (previewFlick.height - height) / (previewFlick.contentHeight - previewFlick.height)
            : 0)
        visible: height > 0
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !workspace.backend.stageActive
        spacing: 8

        AppIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            name: "panel"
            lineColor: AppTheme.alpha(AppTheme.muted, 0.36)
        }

        Text {
            text: "No active slide"
            color: AppTheme.alpha(AppTheme.muted, 0.62)
            font.family: AppTheme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    Text {
        id: statusLine

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 10
        text: workspace.backend.statusMessage
        color: AppTheme.muted
        font.family: AppTheme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
        visible: text !== ""
    }
}
