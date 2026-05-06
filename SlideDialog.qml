import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: dialog

    required property var backend

    property int slideIndex: -1
    property string slideName: ""
    property string slideType: "Default"

    function openEditor(index, name, type) {
        slideIndex = index
        slideName = name
        slideType = type
        open()
    }

    modal: true
    focus: true
    width: Math.min(420, parent ? parent.width - 40 : 420)
    height: 242
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
            text: "Slide"
            color: AppTheme.text
            font.family: AppTheme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        AppTextField {
            Layout.fillWidth: true
            text: dialog.slideName
            placeholderText: "Folder"
            onTextChanged: dialog.slideName = text
        }

        AppTextField {
            Layout.fillWidth: true
            text: dialog.slideType
            placeholderText: "Type"
            onTextChanged: dialog.slideType = text
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextButton {
                text: "Cancel"
                onClicked: dialog.close()
            }

            Item { Layout.fillWidth: true }

            TextButton {
                text: "Save"
                accentFill: true
                onClicked: {
                    dialog.backend.updateLibrarySlide(dialog.slideIndex, dialog.slideName, dialog.slideType)
                    dialog.close()
                }
            }
        }
    }
}
