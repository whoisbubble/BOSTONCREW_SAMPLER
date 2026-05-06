pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: popup

    required property var backend
    property int quickIndex: -1
    property string searchText: ""

    function openFor(index) {
        quickIndex = index
        open()
    }

    modal: true
    focus: true
    width: Math.min(460, parent ? parent.width - 40 : 460)
    height: Math.min(500, parent ? parent.height - 70 : 500)
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    function slideMatches(folderName, slideType) {
        var query = searchText.trim().toLowerCase()
        if (query === "")
            return true
        return (String(folderName) + " " + String(slideType)).toLowerCase().indexOf(query) !== -1
    }

    Overlay.modal: AppModalOverlay {}

    background: AppPanel {
        padding: 0
        panelColor: AppTheme.surfaceRaised
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 8

            Text {
                Layout.preferredWidth: 92
                text: "Quick slot"
                color: AppTheme.text
                font.family: AppTheme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            AppTextField {
                Layout.fillWidth: true
                placeholderText: "Search"
                text: popup.searchText
                onTextChanged: popup.searchText = text
            }

            IconButton {
                side: 32
                iconSize: 16
                iconName: "plus"
                tip: "New slide"
                onClicked: popup.backend.createLibrarySlide()
            }

            IconButton {
                side: 32
                iconSize: 16
                iconName: "close"
                tip: "Clear"
                dangerFill: true
                onClicked: {
                    popup.backend.clearQuickSlide(popup.quickIndex)
                    popup.close()
                }
            }
        }

        ListView {
            id: slideList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: popup.backend.librarySlides
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row

                required property int index
                required property string folderName
                required property string slideType
                required property int mediaCount
                required property bool hasSample

                readonly property bool matchesSearch: popup.slideMatches(row.folderName, row.slideType)

                width: ListView.view ? ListView.view.width : 380
                height: row.matchesSearch ? 58 : 0
                visible: row.matchesSearch
                radius: AppTheme.tileRadius
                color: rowMouse.containsMouse ? AppTheme.tileHover : AppTheme.tile
                border.color: AppTheme.border
                border.width: 1
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    AppIcon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        name: "projector"
                        lineColor: AppTheme.text
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

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
                            text: row.slideType + " / " + row.mediaCount + (row.hasSample ? " + cue" : "")
                            color: AppTheme.muted
                            font.family: AppTheme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        popup.backend.assignQuickSlide(popup.quickIndex, row.index)
                        popup.close()
                    }
                }
            }
        }
    }
}
