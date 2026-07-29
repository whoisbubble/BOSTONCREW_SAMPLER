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

            IconButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                side: 32
                iconSize: 16
                iconName: "plus"
                tip: "New slide"
                onClicked: library.backend.createLibrarySlide()
            }
        }

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: slideColumn.height
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                target: flick
                onWheel: (event) => {
                    var dy = event.angleDelta.y
                    flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY - dy))
                }
            }

            Column {
                id: slideColumn

                width: flick.width
                spacing: 9

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
                        required property var mediaHasSamples
                        required property var mediaRepeats
                        required property var mediaBackgroundPaths
                        required property var mediaBackgroundRepeats

                        property bool isExpanded: false

                        readonly property bool selected: library.selectedIndex === row.index
                        readonly property bool matchesSearch: library.slideMatches(row.folderName, row.slideType, row.mediaPaths, row.mediaSampleNames)
                        readonly property bool available: library.backend.librarySlideAvailable(row.index)
                        readonly property int cardHeight: row.mediaCount > 0 && row.isExpanded ? 168 : 94

                        visible: row.matchesSearch
                        width: slideColumn.width
                        height: row.cardHeight
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
                                row.isExpanded = !row.isExpanded
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                spacing: 9

                                Rectangle {
                                    Layout.preferredWidth: 72
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: AppTheme.inputBackground
                                    border.color: AppTheme.inputBorder
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: row.firstMediaUrl
                                        sourceSize.width: width
                                        sourceSize.height: height
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                        visible: source !== ""
                                    }

                                    AppIcon {
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        visible: row.firstMediaUrl === ""
                                        name: row.mediaCount > 0 ? "play" : "image"
                                        lineColor: AppTheme.muted
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.folderName
                                        color: AppTheme.text
                                        font.family: AppTheme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.slideType + " / " + row.mediaCount + (row.hasSample ? " + cues" : "")
                                        color: AppTheme.muted
                                        font.family: AppTheme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        IconButton {
                                            side: 28
                                            iconSize: 14
                                            iconName: "plus"
                                            enabled: row.available
                                            tip: "Add media"
                                            onClicked: library.backend.addMediaToLibrarySlide(row.index)
                                        }

                                        IconButton {
                                            side: 28
                                            iconSize: 14
                                            iconName: "folder"
                                            enabled: row.available
                                            tip: "Open slide folder"
                                            onClicked: library.backend.openLibraryFolder(row.index)
                                        }

                                        IconButton {
                                            side: 28
                                            iconSize: 14
                                            iconName: "grid"
                                            enabled: row.available
                                            tip: "Проводник медиа слайда (отдельное окно)"
                                            onClicked: slideExplorerWindow.openExplorer(row.index, row.folderName, library.Screen.desktopAvailableWidth / 2 - 500, library.Screen.desktopAvailableHeight / 2 - 350)
                                        }

                                        IconButton {
                                            side: 28
                                            iconSize: 14
                                            iconName: "trash"
                                            dangerFill: true
                                            tip: "Delete slide"
                                            onClicked: {
                                                library.selectedIndex = -1
                                                library.backend.deleteLibrarySlide(row.index)
                                            }
                                        }

                                        IconButton {
                                            side: 28
                                            iconSize: 14
                                            iconName: "menu"
                                            tip: "Drag to reorder slide"

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.SizeAllCursor
                                                preventStealing: true

                                                onPositionChanged: (mouse) => {
                                                    if (pressed) {
                                                        var posInCol = mapToItem(slideColumn, mouse.x, mouse.y)
                                                        var targetIdx = -1
                                                        var accumulatedY = 0

                                                        for (var i = 0; i < slideColumn.children.length; ++i) {
                                                            var child = slideColumn.children[i]
                                                            if (child && child.visible !== false && child.height > 0 && child.index !== undefined) {
                                                                if (posInCol.y >= accumulatedY && posInCol.y <= accumulatedY + child.height + slideColumn.spacing) {
                                                                    targetIdx = child.index
                                                                    break
                                                                }
                                                                accumulatedY += child.height + slideColumn.spacing
                                                            }
                                                        }

                                                        if (targetIdx >= 0 && targetIdx !== row.index) {
                                                            library.backend.moveLibrarySlide(row.index, targetIdx)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }

                            Flickable {
                                id: mediaFlick

                                visible: row.mediaCount > 0 && row.isExpanded
                                Layout.fillWidth: true
                                Layout.preferredHeight: 72
                                clip: true
                                contentWidth: mediaRow.width
                                contentHeight: height
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalFlick

                                WheelHandler {
                                    target: mediaFlick
                                    onWheel: (event) => {
                                        var dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                                        mediaFlick.contentX = Math.max(0, Math.min(Math.max(0, mediaFlick.contentWidth - mediaFlick.width), mediaFlick.contentX - dy))
                                    }
                                }

                                Row {
                                    id: mediaRow

                                    height: mediaFlick.height
                                    spacing: 7

                                    Repeater {
                                        model: row.mediaPaths

                                        delegate: Rectangle {
                                            id: mediaTile

                                            required property int index
                                            required property string modelData

                                            readonly property bool isVideo: library.backend ? library.backend.isVideoPath(mediaTile.modelData) : false
                                            readonly property bool hasCue: !!(row.mediaHasSamples && row.mediaHasSamples[mediaTile.index])
                                            readonly property string cueName: row.mediaSampleNames && mediaTile.index < row.mediaSampleNames.length ? row.mediaSampleNames[mediaTile.index] : ""
                                            readonly property bool repeats: !!(row.mediaRepeats && row.mediaRepeats[mediaTile.index])
                                            readonly property bool hasBackground: !!(row.mediaBackgroundPaths && row.mediaBackgroundPaths[mediaTile.index] !== "")
                                            readonly property bool backgroundRepeats: !!(row.mediaBackgroundRepeats && row.mediaBackgroundRepeats[mediaTile.index])
                                            readonly property bool available: library.backend.slideMediaAvailable(row.index, mediaTile.index)

                                            width: 206
                                            height: 66
                                            opacity: mediaTile.available ? 1.0 : 0.45
                                            radius: 8
                                            color: mediaHover.hovered ? AppTheme.tileHover : AppTheme.inputBackground
                                            border.width: 1
                                            border.color: mediaTile.repeats ? AppTheme.success : (mediaTile.hasCue ? AppTheme.accent : AppTheme.inputBorder)
                                            clip: true

                                            HoverHandler {
                                                id: mediaHover
                                            }

                                            MouseArea {
                                                id: mediaDragArea
                                                anchors.fill: parent
                                                anchors.rightMargin: 24
                                                cursorShape: Qt.SizeAllCursor
                                                preventStealing: true

                                                onPositionChanged: (mouse) => {
                                                    if (pressed) {
                                                        var posInRow = mapToItem(mediaRow, mouse.x, mouse.y)
                                                        var targetIdx = -1
                                                        var accumulatedX = 0

                                                        for (var i = 0; i < mediaRow.children.length; ++i) {
                                                            var child = mediaRow.children[i]
                                                            if (child && child.visible !== false && child.width > 0 && child.index !== undefined) {
                                                                if (posInRow.x >= accumulatedX && posInRow.x <= accumulatedX + child.width + mediaRow.spacing) {
                                                                    targetIdx = child.index
                                                                    break
                                                                }
                                                                accumulatedX += child.width + mediaRow.spacing
                                                            }
                                                        }

                                                        if (targetIdx >= 0 && targetIdx !== mediaTile.index) {
                                                            library.backend.moveLibrarySlideMedia(row.index, mediaTile.index, targetIdx)
                                                        }
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 6

                                                Rectangle {
                                                    Layout.preferredWidth: 42
                                                    Layout.fillHeight: true
                                                    radius: 6
                                                    color: AppTheme.surfacePressed
                                                    border.color: AppTheme.border
                                                    border.width: 1
                                                    clip: true

                                                    Image {
                                                        anchors.fill: parent
                                                        anchors.margins: 3
                                                        source: library.backend ? library.backend.thumbnailUrl(mediaTile.modelData) : ""
                                                        sourceSize.width: width
                                                        sourceSize.height: height
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        cache: true
                                                        smooth: true
                                                        visible: source !== ""
                                                    }

                                                    AppIcon {
                                                        anchors.centerIn: parent
                                                        width: 20
                                                        height: 20
                                                        name: mediaTile.isVideo ? "play" : "image"
                                                        lineColor: AppTheme.muted
                                                        visible: mediaTile.isVideo || !library.backend || library.backend.urlForPath(mediaTile.modelData) === ""
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    spacing: 4

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: library.fileName(mediaTile.modelData) + (mediaTile.hasBackground ? " [+фон]" : "")
                                                        color: AppTheme.text
                                                        font.family: AppTheme.fontFamily
                                                        font.pixelSize: 9
                                                        elide: Text.ElideMiddle
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: mediaTile.hasCue ? mediaTile.cueName : "no cue"
                                                        color: mediaTile.hasCue ? AppTheme.accent : AppTheme.muted
                                                        font.family: AppTheme.fontFamily
                                                        font.pixelSize: 9
                                                        elide: Text.ElideRight
                                                    }

                                                    Row {
                                                        spacing: 3

                                                        IconButton {
                                                            width: 20
                                                            height: 20
                                                            side: 20
                                                            iconSize: 14
                                                            iconName: "menu"
                                                            tip: "Настройки медиа"
                                                            onClicked: mediaMenu.open()
                                                            
                                                            Menu {
                                                                id: mediaMenu
                                                                y: 20
                                                                
                                                                MenuItem {
                                                                    text: "Сместить назад"
                                                                    enabled: mediaTile.available && mediaTile.index > 0
                                                                    onTriggered: library.backend.moveLibrarySlideMedia(row.index, mediaTile.index, mediaTile.index - 1)
                                                                }
                                                                MenuItem {
                                                                    text: "Сместить вперёд"
                                                                    enabled: mediaTile.available && mediaTile.index + 1 < row.mediaPaths.length && library.backend.slideMediaAvailable(row.index, mediaTile.index + 1)
                                                                    onTriggered: library.backend.moveLibrarySlideMedia(row.index, mediaTile.index, mediaTile.index + 1)
                                                                }
                                                                MenuItem {
                                                                    text: mediaTile.repeats ? "Выключить цикл" : "Цикл"
                                                                    enabled: mediaTile.available && mediaTile.isVideo
                                                                    onTriggered: library.backend.setLibrarySlideMediaRepeats(row.index, mediaTile.index, !mediaTile.repeats)
                                                                }
                                                                MenuItem {
                                                                    text: mediaTile.hasCue ? "Изменить звук" : "Добавить звук"
                                                                    enabled: mediaTile.available
                                                                    onTriggered: library.backend.addSampleToLibrarySlideMedia(row.index, mediaTile.index)
                                                                }
                                                                MenuItem {
                                                                    text: "Убрать звук"
                                                                    enabled: mediaTile.available && mediaTile.hasCue
                                                                    visible: mediaTile.hasCue
                                                                    onTriggered: library.backend.clearSampleFromLibrarySlideMedia(row.index, mediaTile.index)
                                                                }
                                                                MenuItem {
                                                                    text: "Добавить фон"
                                                                    enabled: mediaTile.available
                                                                    onTriggered: library.backend.setLibrarySlideMediaBackground(row.index, mediaTile.index)
                                                                }
                                                                MenuItem {
                                                                    text: "Убрать фон"
                                                                    visible: mediaTile.hasBackground
                                                                    enabled: mediaTile.available
                                                                    onTriggered: library.backend.clearLibrarySlideMediaBackground(row.index, mediaTile.index)
                                                                }
                                                                MenuItem {
                                                                    text: mediaTile.backgroundRepeats ? "Выключить цикл фона" : "Цикл фона"
                                                                    visible: mediaTile.hasBackground
                                                                    enabled: mediaTile.available
                                                                    onTriggered: library.backend.setLibrarySlideMediaBackgroundRepeats(row.index, mediaTile.index, !mediaTile.backgroundRepeats)
                                                                }
                                                                MenuItem {
                                                                    text: "Удалить"
                                                                    enabled: mediaTile.available
                                                                    onTriggered: library.backend.deleteLibrarySlideMedia(row.index, mediaTile.index)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
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
