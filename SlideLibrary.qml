pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: library

    required property var backend
    property int selectedIndex: -1
    property string selectedName: ""
    property string selectedType: ""
    property string searchText: ""

    signal editSlideRequested(int index, string folderName, string slideType)

    function fileName(path) {
        var normalized = String(path).replace(/\\/g, "/")
        var slash = normalized.lastIndexOf("/")
        return slash >= 0 ? normalized.slice(slash + 1) : normalized
    }

    function slideMatches(folderName, slideType, mediaPaths, sampleNames) {
        var query = searchText.trim().toLowerCase()
        if (query === "")
            return true

        var haystack = (String(folderName) + " " + String(slideType)).toLowerCase()
        for (var i = 0; mediaPaths && i < mediaPaths.length; ++i)
            haystack += " " + fileName(mediaPaths[i]).toLowerCase()
        for (var j = 0; sampleNames && j < sampleNames.length; ++j)
            haystack += " " + String(sampleNames[j]).toLowerCase()
        return haystack.indexOf(query) !== -1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8

            AppTextField {
                Layout.fillWidth: true
                placeholderText: "Search"
                text: library.searchText
                onTextChanged: library.searchText = text
            }

            IconButton {
                visible: library.selectedIndex >= 0 && library.backend.librarySlideAvailable(library.selectedIndex)
                Layout.preferredWidth: visible ? 32 : 0
                Layout.preferredHeight: 32
                side: 32
                iconSize: 16
                iconName: "edit"
                tip: "Edit selected slide"
                onClicked: library.editSlideRequested(library.selectedIndex, library.selectedName, library.selectedType)
            }
        }

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: slideFlow.height
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                target: flick
                onWheel: (event) => {
                    var dy = event.angleDelta.y
                    flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY - dy))
                }
            }

            ScrollBar.vertical: AppScrollBar {}

            Flow {
                id: slideFlow

                width: flick.width
                height: Math.max(childrenRect.height, flick.height)
                spacing: 12

                Repeater {
                    model: library.backend.librarySlides

                    delegate: Rectangle {
                        id: row

                        required property int index
                        required property string folderName
                        required property string slideType
                        required property int mediaCount
                        required property bool hasSample
                        required property string firstMediaUrl
                        required property var mediaPaths
                        required property var mediaSampleNames

                        readonly property bool selected: library.selectedIndex === row.index
                        readonly property bool matchesSearch: library.slideMatches(row.folderName, row.slideType, row.mediaPaths, row.mediaSampleNames)
                        readonly property bool available: library.backend.librarySlideAvailable(row.index)

                        visible: row.matchesSearch
                        width: 170
                        height: 170
                        opacity: row.available ? 1.0 : 0.42
                        radius: AppTheme.tileRadius
                        color: row.selected
                            ? AppTheme.surfaceSoft
                            : (rowHover.hovered ? AppTheme.tileHover : AppTheme.tile)
                        border.width: 1
                        border.color: row.selected ? AppTheme.accent : AppTheme.border
                        clip: true

                        HoverHandler {
                            id: rowHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                library.selectedIndex = row.index
                                library.selectedName = row.folderName
                                library.selectedType = row.slideType
                            }
                        }

                        Item {
                            anchors.fill: parent

                            Image {
                                anchors.fill: parent
                                source: {
                                    var dummy = library.backend.thumbnailUpdateCount;
                                    return row.mediaPaths.length > 0 ? library.backend.thumbnailUrl(row.mediaPaths[0]) : ""
                                }
                                sourceSize.width: width
                                sourceSize.height: height
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                visible: source !== ""
                            }

                            AppIcon {
                                anchors.centerIn: parent
                                width: 48
                                height: 48
                                visible: row.firstMediaUrl === ""
                                name: row.mediaCount > 0 ? "play" : "image"
                                lineColor: AppTheme.muted
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 60
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: "#D0000000" }
                                }
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: row.folderName
                                    color: "#FFFFFF"
                                    font.family: AppTheme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    style: Text.Outline
                                    styleColor: "#80000000"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: row.slideType + " / " + row.mediaCount + (row.hasSample ? " + cue" : "")
                                    color: "#DDDDDD"
                                    font.family: AppTheme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                spacing: 4
                                opacity: rowHover.hovered ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                
                                IconButton {
                                    side: 28
                                    iconSize: 14
                                    iconName: "grid"
                                    tip: "Open Explorer"
                                    onClicked: slideExplorerWindow.openExplorer(row.index, row.folderName, Screen.desktopAvailableWidth / 2 - 500, Screen.desktopAvailableHeight / 2 - 350)
                                }

                                IconButton {
                                    side: 28
                                    iconSize: 14
                                    iconName: "trash"
                                    dangerFill: true
                                    tip: "Delete block"
                                    onClicked: {
                                        library.selectedIndex = -1
                                        library.backend.deleteLibrarySlide(row.index)
                                    }
                                }
                            }

                            IconButton {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 6
                                side: 28
                                iconSize: 14
                                iconName: "menu"
                                tip: "Drag to reorder"
                                opacity: rowHover.hovered ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.SizeAllCursor
                                    preventStealing: true

                                    onPositionChanged: (mouse) => {
                                        if (pressed) {
                                            var posInFlow = mapToItem(slideFlow, mouse.x, mouse.y)
                                            var targetIdx = -1

                                            for (var i = 0; i < slideFlow.children.length; ++i) {
                                                var child = slideFlow.children[i]
                                                if (child && child.visible !== false && child.width > 0 && child.hasOwnProperty("index") && typeof child.index === "number") {
                                                    if (posInFlow.x >= child.x && posInFlow.x <= child.x + child.width &&
                                                        posInFlow.y >= child.y && posInFlow.y <= child.y + child.height) {
                                                        targetIdx = child.index
                                                        break
                                                    }
                                                }
                                            }

                                            if (targetIdx >= 0 && targetIdx !== row.index) {
                                                library.backend.moveLibrarySlide(row.index, targetIdx)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 170
                    height: 170
                    radius: AppTheme.tileRadius
                    color: addHover.hovered ? AppTheme.tileHover : AppTheme.tile
                    border.width: 1
                    border.color: AppTheme.border
                    clip: true
                    visible: library.searchText.trim() === ""
                    
                    HoverHandler { id: addHover }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: library.backend.createLibrarySlide()
                        cursorShape: Qt.PointingHandCursor
                    }
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        AppIcon {
                            Layout.alignment: Qt.AlignHCenter
                            width: 48
                            height: 48
                            name: "plus"
                            lineColor: AppTheme.muted
                        }
                        
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "New Block"
                            color: AppTheme.muted
                            font.family: AppTheme.fontFamily
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    SlideMediaExplorerWindow {
        id: slideExplorerWindow
        backend: library.backend
    }
}
