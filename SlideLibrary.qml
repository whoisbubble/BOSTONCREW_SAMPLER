pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

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
                visible: library.selectedIndex >= 0
                Layout.preferredWidth: visible ? 32 : 0
                Layout.preferredHeight: 32
                side: 32
                iconSize: 16
                iconName: "edit"
                onClicked: library.editSlideRequested(library.selectedIndex, library.selectedName, library.selectedType)
            }

            IconButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                side: 32
                iconSize: 16
                iconName: "plus"
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

                        readonly property bool selected: library.selectedIndex === row.index
                        readonly property bool matchesSearch: library.slideMatches(row.folderName, row.slideType, row.mediaPaths, row.mediaSampleNames)
                        readonly property int cardHeight: row.mediaCount > 0 ? 168 : 94

                        visible: row.matchesSearch
                        width: slideColumn.width
                        height: row.cardHeight
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
                                            iconName: "image"
                                            onClicked: library.backend.addMediaToLibrarySlide(row.index)
                                        }

                                        IconButton {
                                            side: 28
                                            iconSize: 14
                                            iconName: "folder"
                                            onClicked: library.backend.openLibraryFolder(row.index)
                                        }

                                        IconButton {
                                            side: 28
                                            iconSize: 14
                                            iconName: "trash"
                                            dangerFill: true
                                            onClicked: {
                                                library.selectedIndex = -1
                                                library.backend.deleteLibrarySlide(row.index)
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }

                            Flickable {
                                id: mediaFlick

                                visible: row.mediaCount > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 72
                                clip: true
                                contentWidth: mediaRow.width
                                contentHeight: height
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalFlick

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

                                            width: 206
                                            height: 66
                                            radius: 8
                                            color: mediaHover.hovered ? AppTheme.tileHover : AppTheme.inputBackground
                                            border.width: 1
                                            border.color: mediaTile.repeats ? AppTheme.success : (mediaTile.hasCue ? AppTheme.accent : AppTheme.inputBorder)
                                            clip: true

                                            HoverHandler {
                                                id: mediaHover
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
                                                        source: mediaTile.isVideo || !library.backend ? "" : library.backend.urlForPath(mediaTile.modelData)
                                                        sourceSize.width: width
                                                        sourceSize.height: height
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
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
                                                        text: library.fileName(mediaTile.modelData)
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
                                                            iconSize: 11
                                                            iconName: "up"
                                                            enabled: mediaTile.index > 0
                                                            onClicked: library.backend.moveLibrarySlideMedia(row.index, mediaTile.index, mediaTile.index - 1)
                                                        }

                                                        IconButton {
                                                            width: 20
                                                            height: 20
                                                            side: 20
                                                            iconSize: 11
                                                            iconName: "down"
                                                            enabled: mediaTile.index + 1 < row.mediaPaths.length
                                                            onClicked: library.backend.moveLibrarySlideMedia(row.index, mediaTile.index, mediaTile.index + 1)
                                                        }

                                                        IconButton {
                                                            width: 20
                                                            height: 20
                                                            side: 20
                                                            iconSize: 11
                                                            iconName: "repeat"
                                                            enabled: mediaTile.isVideo
                                                            accentFill: mediaTile.repeats
                                                            onClicked: library.backend.setLibrarySlideMediaRepeats(row.index, mediaTile.index, !mediaTile.repeats)
                                                        }

                                                        IconButton {
                                                            width: 20
                                                            height: 20
                                                            side: 20
                                                            iconSize: 11
                                                            iconName: "audio"
                                                            accentFill: mediaTile.hasCue
                                                            onClicked: function(mouse) {
                                                                if (mouse.button === Qt.RightButton && mediaTile.hasCue)
                                                                    library.backend.clearSampleFromLibrarySlideMedia(row.index, mediaTile.index)
                                                                else
                                                                    library.backend.addSampleToLibrarySlideMedia(row.index, mediaTile.index)
                                                            }
                                                        }

                                                        IconButton {
                                                            visible: mediaTile.hasCue
                                                            width: visible ? 20 : 0
                                                            height: 20
                                                            side: 20
                                                            iconSize: 11
                                                            iconName: "close"
                                                            dangerFill: true
                                                            onClicked: library.backend.clearSampleFromLibrarySlideMedia(row.index, mediaTile.index)
                                                        }

                                                        IconButton {
                                                            width: 20
                                                            height: 20
                                                            side: 20
                                                            iconSize: 11
                                                            iconName: "trash"
                                                            dangerFill: true
                                                            onClicked: library.backend.deleteLibrarySlideMedia(row.index, mediaTile.index)
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
